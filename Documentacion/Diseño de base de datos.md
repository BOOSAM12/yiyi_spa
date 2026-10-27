# Diseño de Base de Datos — YiYi Spa (PostgreSQL)

> **Versión**: 1.0  
> **Fecha**: Mayo 2026  
> **Motor**: PostgreSQL 16+  
> **ORM**: Laravel Eloquent (PHP)  
> **Modelo**: Single-Database Multi-Tenant con `tenant_id`  

---

## Tabla de Contenidos

1. [Convenciones Generales](#1-convenciones-generales)
2. [Diagrama ER General](#2-diagrama-er-general)
3. [Módulo 0 — Plataforma y Multi-Tenancy](#3-módulo-0--plataforma-y-multi-tenancy)
4. [Módulo 1 — Autenticación e Identidad](#4-módulo-1--autenticación-e-identidad)
5. [Módulo 2 — Perfil de Negocio y Multilocación](#5-módulo-2--perfil-de-negocio-y-multilocación)
6. [Módulo 3 — Catálogo de Servicios](#6-módulo-3--catálogo-de-servicios)
7. [Módulo 4 — Gestión de Citas (Motor de Reservas)](#7-módulo-4--gestión-de-citas-motor-de-reservas)
8. [Módulo 5 — Gestión de Personal y Nómina](#8-módulo-5--gestión-de-personal-y-nómina)
9. [Módulo 6 — Gestión de Clientes e Historial Clínico](#9-módulo-6--gestión-de-clientes-e-historial-clínico)
10. [Módulo 7 — Inventario y Punto de Venta (POS)](#10-módulo-7--inventario-y-punto-de-venta-pos)
11. [Módulo 8 — Financiero y Reportes](#11-módulo-8--financiero-y-reportes)
12. [Módulo 9 — Portal del Cliente (extensión de tablas)](#12-módulo-9--portal-del-cliente)
13. [Módulo 10 — Notificaciones y Comunicaciones](#13-módulo-10--notificaciones-y-comunicaciones)
14. [Módulo 11 — Fidelización y Membresías](#14-módulo-11--fidelización-y-membresías)
15. [Módulo 12 — Seguridad y Cumplimiento](#15-módulo-12--seguridad-y-cumplimiento)
16. [Índices Estratégicos](#16-índices-estratégicos)
17. [Notas de Implementación con Eloquent](#17-notas-de-implementación-con-eloquent)
18. [Glosario](#18-glosario)

---

## 1. Convenciones Generales

### 1.1 Nomenclatura

| Elemento | Convención | Ejemplo |
|----------|-----------|---------|
| Tablas | Plural, snake_case | `appointments`, `service_categories` |
| Columnas | Singular, snake_case | `first_name`, `tenant_id` |
| Primary Keys | `id` (BIGSERIAL) | `id BIGSERIAL PRIMARY KEY` |
| Foreign Keys | `{tabla_singular}_id` | `tenant_id`, `branch_id`, `user_id` |
| Timestamps | `created_at`, `updated_at`, `deleted_at` | `TIMESTAMPTZ` |
| Booleanos | Prefijo `is_`, `has_`, `requires_` | `is_active`, `requires_deposit` |
| Moneda | BIGINT (centavos COP) | `price BIGINT` → $50.000 COP = 5000000 centavos |
| UUIDs (públicos) | Columna adicional `uuid` | `uuid UUID UNIQUE` |

### 1.2 Columnas estándar en toda tabla

```sql
-- Toda tabla incluye:
id          BIGSERIAL PRIMARY KEY,
created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
deleted_at  TIMESTAMPTZ NULL          -- Soft deletes Laravel
```

### 1.3 Reglas Multi-Tenant

- **Todas** las tablas de datos de negocio (no plataformas) incluyen `tenant_id BIGINT NOT NULL`.
- Se implementará un `Global Scope` en Eloquent que inyecte automáticamente `WHERE tenant_id = ?`.
- Las tablas de plataforma (`tenants`, `subscription_plans`, `tenant_subscriptions`) **NO** tienen `tenant_id`.
- Las tablas de usuarios y autenticación usan `tenant_id NULL` porque un **Super Admin** no pertenece a ningún tenant.

### 1.4 Tipo de dato Moneda

> **Decisión importante**: Los valores monetarios se almacenan en **centavos** como `BIGINT`.
> - COP $50.000 → se almacena como `5000000` (centavos)
> - Esto evita problemas de precisión con `FLOAT`/`DECIMAL`.
> - En la UI se divide entre 100 y se formatea como `$50.000`.
> - PostgreSQL no tiene tipo nativo MONEY (problemático), se usa BIGINT.

---

## 2. Diagrama ER General (Texto)

```
┌─────────────┐       ┌──────────────┐
│   tenants    │──1:N──│   branches   │
│ (plataforma) │       │  (sucursales)│
└──────┬───────┘       └──────┬───────┘
       │                      │
       │ 1:N                  │ 1:N
       ▼                      ▼
┌─────────────┐       ┌──────────────┐
│    users     │──N:N──│   roles      │
│  (usuarios)  │       │  (roles)     │
└──────┬───────┘       └──────────────┘
       │
       │ 1:1 (si es cliente)
       ▼
┌─────────────┐       ┌──────────────────────┐
│  customers   │──1:N──│  clinical_records    │
│  (clientes)  │       │  (historial clínico) │
└──────┬───────┘       └──────────────────────┘
       │
       │ 1:N
       ▼
┌─────────────┐       ┌──────────────────┐
│ appointments │──1:N──│ appointment_svc  │
│  (citas)     │       │ (servicios x cita)│
└──────┬───────┘       └──────────────────┘
       │
       │ 1:N
       ▼
┌─────────────┐       ┌──────────────┐
│    sales     │──1:N──│  sale_items   │
│  (ventas)    │       │(items x venta)│
└─────────────┘       └──────────────┘
```

---

## 3. Módulo 0 — Plataforma y Multi-Tenancy

> Este módulo gestiona los tenants (negocios) a nivel de plataforma SaaS.  
> **No tiene `tenant_id`** — es el nivel raíz.

### 3.1 `tenants` — Negocios registrados en la plataforma

```sql
CREATE TABLE tenants (
    id                  BIGSERIAL PRIMARY KEY,
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name                VARCHAR(255) NOT NULL,                          -- Nombre del negocio
    slug                VARCHAR(100) NOT NULL UNIQUE,                   -- URL: yiyispa.com/{slug}
    logo_path           VARCHAR(500) NULL,                              -- Logo en S3
    description         TEXT NULL,
    email               VARCHAR(255) NOT NULL,
    phone               VARCHAR(30) NULL,
    country_code        CHAR(2) NOT NULL DEFAULT 'CO',                 -- ISO 3166-1
    currency_code       CHAR(3) NOT NULL DEFAULT 'COP',                -- ISO 4217
    timezone            VARCHAR(50) NOT NULL DEFAULT 'America/Bogota',
    language            VARCHAR(5) NOT NULL DEFAULT 'es',
    tax_rate            DECIMAL(5,4) NOT NULL DEFAULT 0.1900,          -- IVA 19% Colombia
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    onboarding_step     VARCHAR(50) NULL,                               -- Paso actual del wizard
    trial_ends_at       TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_tax_rate CHECK (tax_rate >= 0 AND tax_rate <= 1)
);

COMMENT ON TABLE tenants IS 'Negocios (tenants) registrados en la plataforma SaaS';
COMMENT ON COLUMN tenants.tax_rate IS 'Tasa de impuesto por defecto. Colombia IVA = 0.1900 (19%)';
COMMENT ON COLUMN tenants.slug IS 'Identificador URL único para el portal del cliente';
```

### 3.2 `subscription_plans` — Planes de suscripción SaaS

```sql
CREATE TABLE subscription_plans (
    id                  BIGSERIAL PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,                          -- Ej: "Básico", "Pro", "Enterprise"
    slug                VARCHAR(50) NOT NULL UNIQUE,
    description         TEXT NULL,
    price_monthly       BIGINT NOT NULL,                                -- Precio mensual en centavos COP
    price_annual        BIGINT NULL,                                    -- Precio anual en centavos COP (descuento)
    max_branches        INT NOT NULL DEFAULT 1,                         -- Máximo de sucursales
    max_employees       INT NOT NULL DEFAULT 5,                         -- Máximo de empleados
    max_services        INT NOT NULL DEFAULT 50,                        -- Máximo de servicios
    has_pos             BOOLEAN NOT NULL DEFAULT FALSE,
    has_whatsapp        BOOLEAN NOT NULL DEFAULT FALSE,
    has_advanced_reports BOOLEAN NOT NULL DEFAULT FALSE,
    has_loyalty         BOOLEAN NOT NULL DEFAULT FALSE,
    has_api_access      BOOLEAN NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order          INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL
);

COMMENT ON TABLE subscription_plans IS 'Planes de suscripción disponibles en la plataforma SaaS';
```

### 3.3 `tenant_subscriptions` — Suscripciones activas de cada negocio

```sql
CREATE TABLE tenant_subscriptions (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    plan_id             BIGINT NOT NULL REFERENCES subscription_plans(id),
    status              VARCHAR(20) NOT NULL DEFAULT 'active',          -- active, past_due, cancelled, expired, trial
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NULL,                                -- NULL = activa indefinidamente
    cancelled_at        TIMESTAMPTZ NULL,
    cancellation_reason TEXT NULL,
    payment_method      VARCHAR(30) NULL,                                -- credit_card, pse, etc.
    gateway_reference   VARCHAR(255) NULL,                               -- ID de la pasarela de pago
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_status CHECK (status IN ('active', 'past_due', 'cancelled', 'expired', 'trial'))
);

CREATE INDEX idx_tenant_subscriptions_tenant ON tenant_subscriptions(tenant_id);
CREATE INDEX idx_tenant_subscriptions_status ON tenant_subscriptions(status);
```

### 3.4 `tenant_payments` — Historial de pagos de suscripción

```sql
CREATE TABLE tenant_payments (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    subscription_id     BIGINT NULL REFERENCES tenant_subscriptions(id) ON DELETE SET NULL,
    amount              BIGINT NOT NULL,                                 -- Monto en centavos COP
    currency            CHAR(3) NOT NULL DEFAULT 'COP',
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',         -- pending, completed, failed, refunded
    gateway             VARCHAR(50) NOT NULL,                            -- mercadopago, wompi, placetopay
    gateway_id          VARCHAR(255) NULL,                               -- ID transacción en la pasarela
    gateway_response    JSONB NULL,                                      -- Respuesta completa de la pasarela
    invoice_url         VARCHAR(500) NULL,
    paid_at             TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_payment_status CHECK (status IN ('pending', 'completed', 'failed', 'refunded'))
);

CREATE INDEX idx_tenant_payments_tenant ON tenant_payments(tenant_id);
```

---

## 4. Módulo 1 — Autenticación e Identidad

> Tablas para gestión de usuarios, roles, permisos y auditoría.  
> `users` tiene `tenant_id` nullable (Super Admin no pertenece a tenant).

### 4.1 `users` — Usuarios del sistema

```sql
CREATE TABLE users (
    id                  BIGSERIAL PRIMARY KEY,
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    tenant_id           BIGINT NULL REFERENCES tenants(id) ON DELETE CASCADE, -- NULL para Super Admin
    role_id             BIGINT NULL REFERENCES roles(id),                     -- Rol principal (FK hacia roles)
    email               VARCHAR(255) NOT NULL,
    email_verified_at   TIMESTAMPTZ NULL,
    password            VARCHAR(255) NOT NULL,                           -- Hash bcrypt
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    phone               VARCHAR(30) NULL,
    avatar_path         VARCHAR(500) NULL,                               -- Foto de perfil en S3
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at       TIMESTAMPTZ NULL,
    last_login_ip       INET NULL,
    password_changed_at TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT unq_users_email_tenant UNIQUE (email, tenant_id)  -- Mismo email en distintos tenants
);

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role_id);
```

### 4.2 `roles` — Roles del sistema (RBAC)

```sql
CREATE TABLE roles (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NULL REFERENCES tenants(id) ON DELETE CASCADE, -- NULL = roles del sistema
    name                VARCHAR(50) NOT NULL,                             -- super_admin, owner, receptionist, technician, customer
    display_name        VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    is_system           BOOLEAN NOT NULL DEFAULT FALSE,                   -- Roles del sistema no editables
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_roles_name_tenant UNIQUE (name, tenant_id)
);

-- Seed inicial:
-- super_admin, owner, receptionist, technician, customer (is_system = TRUE)
```

### 4.3 `permissions` — Permisos granulares

```sql
CREATE TABLE permissions (
    id                  BIGSERIAL PRIMARY KEY,
    module              VARCHAR(50) NOT NULL,                            -- appointments, inventory, reports, etc.
    action              VARCHAR(50) NOT NULL,                            -- create, read, update, delete, export
    resource            VARCHAR(100) NOT NULL,                           -- Nombre del recurso
    description         TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_permissions UNIQUE (module, action, resource)
);
```

### 4.4 `permission_role` — Asignación permiso ↔ rol (N:N)

```sql
CREATE TABLE permission_role (
    permission_id       BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    role_id             BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (permission_id, role_id)
);
```

### 4.5 `social_accounts` — Login con redes sociales (OAuth)

```sql
CREATE TABLE social_accounts (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider            VARCHAR(30) NOT NULL,                            -- google, facebook, apple
    provider_id         VARCHAR(255) NOT NULL,
    provider_token      TEXT NULL,
    provider_refresh_token TEXT NULL,
    avatar_url          VARCHAR(500) NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_social_provider UNIQUE (provider, provider_id)
);

CREATE INDEX idx_social_accounts_user ON social_accounts(user_id);
```

### 4.6 `password_resets` — Tokens de recuperación de contraseña

```sql
CREATE TABLE password_resets (
    id                  BIGSERIAL PRIMARY KEY,
    email               VARCHAR(255) NOT NULL,
    token               VARCHAR(255) NOT NULL,                           -- Hash del token
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_password_resets_email ON password_resets(email);
```

### 4.7 `audit_logs` — Registro de auditoría de accesos y acciones

```sql
CREATE TABLE audit_logs (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NULL,
    user_id             BIGINT NULL,
    user_type           VARCHAR(50) NULL,                                -- App\Models\User, etc.
    action              VARCHAR(100) NOT NULL,                           -- login, logout, create, update, delete
    module              VARCHAR(50) NULL,                                -- appointments, inventory, etc.
    entity_type         VARCHAR(100) NULL,                               -- Model class
    entity_id           BIGINT NULL,                                     -- ID del registro afectado
    old_values          JSONB NULL,
    new_values          JSONB NULL,
    ip_address          INET NULL,
    user_agent          TEXT NULL,
    url                 VARCHAR(500) NULL,
    method              VARCHAR(10) NULL,                                -- GET, POST, PUT, DELETE
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_tenant ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);
```

---

## 5. Módulo 2 — Perfil de Negocio y Multilocación

### 5.1 `branches` — Sucursales de cada negocio

```sql
CREATE TABLE branches (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name                VARCHAR(255) NOT NULL,
    slug                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    address             TEXT NULL,
    city                VARCHAR(100) NULL,
    state               VARCHAR(100) NULL,                               -- Departamento en Colombia
    country             CHAR(2) NOT NULL DEFAULT 'CO',
    latitude            DECIMAL(10, 8) NULL,
    longitude           DECIMAL(11, 8) NULL,
    phone               VARCHAR(30) NULL,
    email               VARCHAR(255) NULL,
    cover_image_path    VARCHAR(500) NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_main             BOOLEAN NOT NULL DEFAULT FALSE,                   -- Sucursal principal
    sort_order          INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT unq_branch_slug_tenant UNIQUE (slug, tenant_id)
);

CREATE INDEX idx_branches_tenant ON branches(tenant_id);
CREATE INDEX idx_branches_location ON branches(latitude, longitude) WHERE latitude IS NOT NULL;
```

### 5.2 `branch_schedules` — Horarios de apertura por día

```sql
CREATE TABLE branch_schedules (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    day_of_week         SMALLINT NOT NULL,                               -- 0=Domingo, 1=Lunes... 6=Sábado
    opens_at            TIME NOT NULL,                                   -- Ej: 09:00
    closes_at           TIME NOT NULL,                                   -- Ej: 18:00
    is_closed           BOOLEAN NOT NULL DEFAULT FALSE,                  -- TRUE = cerrado ese día
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_day_of_week CHECK (day_of_week BETWEEN 0 AND 6),
    CONSTRAINT chk_time_range CHECK (opens_at < closes_at OR is_closed = TRUE),
    CONSTRAINT unq_branch_day UNIQUE (branch_id, day_of_week)
);

CREATE INDEX idx_branch_schedules_branch ON branch_schedules(branch_id);
```

### 5.3 `branch_special_dates` — Fechas especiales (festivos, horarios extendidos)

```sql
CREATE TABLE branch_special_dates (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    date                DATE NOT NULL,
    name                VARCHAR(100) NOT NULL,                           -- Ej: "Día de la Madre"
    opens_at            TIME NULL,
    closes_at           TIME NULL,
    is_closed           BOOLEAN NOT NULL DEFAULT FALSE,                   -- TRUE = cerrado
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_branch_special_date UNIQUE (branch_id, date)
);

CREATE INDEX idx_branch_special_dates_branch ON branch_special_dates(branch_id);
CREATE INDEX idx_branch_special_dates_date ON branch_special_dates(date);
```

### 5.4 `branch_policies` — Políticas configurables por sucursal

```sql
CREATE TABLE branch_policies (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    cancellation_policy VARCHAR(20) NOT NULL DEFAULT 'flexible',         -- flexible, moderate, strict
    cancellation_hours  INT NOT NULL DEFAULT 24,                         -- Horas mínimas para cancelar gratis
    no_show_fee_percent INT NULL,                                        -- % de cargo por inasistencia (0-100)
    requires_deposit    BOOLEAN NOT NULL DEFAULT FALSE,
    deposit_percent     INT NULL,                                        -- % de depósito requerido
    accepts_tips        BOOLEAN NOT NULL DEFAULT TRUE,
    tip_suggestion_1    INT NULL,                                        -- Monto sugerencia 1 (centavos)
    tip_suggestion_2    INT NULL,
    tip_suggestion_3    INT NULL,
    allow_online_booking BOOLEAN NOT NULL DEFAULT TRUE,
    booking_advance_days INT NOT NULL DEFAULT 30,                        -- Días máximos de anticipación
    min_booking_notice_hours INT NOT NULL DEFAULT 2,                     -- Horas mínimas de anticipación
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_branch_policy UNIQUE (branch_id),
    CONSTRAINT chk_cancellation CHECK (cancellation_policy IN ('flexible', 'moderate', 'strict')),
    CONSTRAINT chk_deposit_pct CHECK (deposit_percent BETWEEN 1 AND 100),
    CONSTRAINT chk_noshow_pct CHECK (no_show_fee_percent BETWEEN 0 AND 100)
);
```

### 5.5 `branch_photos` — Galería de fotos por sucursal

```sql
CREATE TABLE branch_photos (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    path                VARCHAR(500) NOT NULL,                           -- Ruta S3
    caption             VARCHAR(255) NULL,
    sort_order          INT NOT NULL DEFAULT 0,
    is_cover            BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_branch_photos_branch ON branch_photos(branch_id);
```

---

## 6. Módulo 3 — Catálogo de Servicios

### 6.1 `service_categories` — Familias de servicios

```sql
CREATE TABLE service_categories (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                VARCHAR(100) NOT NULL,
    slug                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    icon                VARCHAR(100) NULL,                               -- Nombre del icono
    color               VARCHAR(7) NULL,                                 -- Hex color: #FF5733
    parent_id           BIGINT NULL REFERENCES service_categories(id) ON DELETE SET NULL, -- Subcategorías
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order          INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT unq_category_slug_tenant UNIQUE (slug, tenant_id)
);

CREATE INDEX idx_service_categories_tenant ON service_categories(tenant_id);
CREATE INDEX idx_service_categories_parent ON service_categories(parent_id);
```

### 6.2 `services` — Servicios del catálogo

```sql
CREATE TABLE services (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    category_id         BIGINT NOT NULL REFERENCES service_categories(id) ON DELETE RESTRICT,
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name                VARCHAR(200) NOT NULL,
    slug                VARCHAR(200) NOT NULL,
    description         TEXT NULL,
    base_price          BIGINT NOT NULL,                                 -- Precio base en centavos COP
    duration_minutes    INT NOT NULL,                                    -- Duración del servicio
    processing_minutes  INT NOT NULL DEFAULT 0,                          -- Tiempo de procesamiento (cliente ocupado, técnico libre)
    buffer_minutes      INT NOT NULL DEFAULT 0,                          -- Tiempo de amortiguación entre citas
    requires_resource   BOOLEAN NOT NULL DEFAULT FALSE,                  -- Requiere recurso físico (cabina, silla)
    resource_type       VARCHAR(50) NULL,                                -- Tipo de recurso: chair, cabin, room
    max_concurrent      INT NOT NULL DEFAULT 1,                          -- Cuántos en paralelo (ej: pedicura x 3 sillas)
    gender              VARCHAR(10) NULL,                                -- male, female, unisex (para filtrado)
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_popular          BOOLEAN NOT NULL DEFAULT FALSE,                   -- Destacado en el portal
    sort_order          INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_duration CHECK (duration_minutes > 0),
    CONSTRAINT chk_processing CHECK (processing_minutes >= 0),
    CONSTRAINT chk_buffer CHECK (buffer_minutes >= 0),
    CONSTRAINT chk_gender CHECK (gender IS NULL OR gender IN ('male', 'female', 'unisex')),
    CONSTRAINT unq_service_slug_tenant UNIQUE (slug, tenant_id)
);

CREATE INDEX idx_services_tenant ON services(tenant_id);
CREATE INDEX idx_services_category ON services(category_id);
CREATE INDEX idx_services_active ON services(tenant_id, is_active);
```

### 6.3 `service_branch_price` — Precios dinámicos por sucursal

```sql
CREATE TABLE service_branch_price (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    service_id          BIGINT NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    custom_price        BIGINT NULL,                                     -- NULL = usar precio base del servicio
    is_available        BOOLEAN NOT NULL DEFAULT TRUE,                   -- FALSE = no disponible en esta sucursal
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_service_branch UNIQUE (service_id, branch_id)
);

CREATE INDEX idx_service_branch_price_service ON service_branch_price(service_id);
CREATE INDEX idx_service_branch_price_branch ON service_branch_price(branch_id);
```

### 6.4 `service_technician` — Servicios que cada técnico puede realizar (N:N)

```sql
CREATE TABLE service_technician (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    service_id          BIGINT NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE CASCADE, -- FK al módulo de personal
    custom_duration     INT NULL,                                        -- Duración personalizada para este técnico
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_service_technician UNIQUE (service_id, employee_id)
);

CREATE INDEX idx_service_technician_service ON service_technician(service_id);
CREATE INDEX idx_service_technician_employee ON service_technician(employee_id);
```

---

## 7. Módulo 4 — Gestión de Citas (Motor de Reservas)

### 7.1 `appointments` — Citas agendadas

```sql
CREATE TABLE appointments (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    customer_id         BIGINT NULL REFERENCES customers(id) ON DELETE SET NULL, -- NULL = walk-in
    employee_id         BIGINT NULL REFERENCES employees(id) ON DELETE SET NULL, -- NULL = "cualquier profesional"
    booked_by_user_id   BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,      -- Quién agendó (recepcionista, cliente, sistema)
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',
    source              VARCHAR(20) NOT NULL DEFAULT 'online',           -- online, walk_in, phone, whatsapp
    notes               TEXT NULL,
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NOT NULL,
    total_duration      INT NOT NULL,                                    -- Duración total en minutos (incluye buffer)
    total_price         BIGINT NOT NULL DEFAULT 0,                       -- Precio total en centavos COP
    deposit_amount      BIGINT NULL,                                    -- Monto del depósito pagado
    deposit_paid_at     TIMESTAMPTZ NULL,
    cancellation_reason TEXT NULL,
    cancelled_at        TIMESTAMPTZ NULL,
    cancelled_by        BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
    no_show             BOOLEAN NOT NULL DEFAULT FALSE,
    reminder_sent_at    TIMESTAMPTZ NULL,                                -- Último recordatorio enviado
    confirmed_at        TIMESTAMPTZ NULL,                                -- Confirmación del cliente
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_appt_status CHECK (status IN (
        'pending', 'confirmed', 'in_progress', 'completed', 
        'cancelled', 'no_show', 'rescheduled'
    )),
    CONSTRAINT chk_appt_source CHECK (source IN ('online', 'walk_in', 'phone', 'whatsapp')),
    CONSTRAINT chk_appt_time CHECK (starts_at < ends_at)
);

CREATE INDEX idx_appointments_tenant ON appointments(tenant_id);
CREATE INDEX idx_appointments_branch ON appointments(branch_id);
CREATE INDEX idx_appointments_customer ON appointments(customer_id);
CREATE INDEX idx_appointments_employee ON appointments(employee_id);
CREATE INDEX idx_appointments_status ON appointments(tenant_id, status);
CREATE INDEX idx_appointments_date ON appointments(tenant_id, starts_at);
CREATE INDEX idx_appointments_range ON appointments(employee_id, starts_at, ends_at) WHERE deleted_at IS NULL;
```

### 7.2 `appointment_services` — Servicios incluidos en una cita (N:N)

```sql
CREATE TABLE appointment_services (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    appointment_id      BIGINT NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    service_id          BIGINT NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT, -- Técnico que ejecuta
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    price               BIGINT NOT NULL,                                 -- Precio al momento de la cita
    duration_minutes    INT NOT NULL,                                    -- Duración aplicada
    processing_minutes  INT NOT NULL DEFAULT 0,
    buffer_minutes      INT NOT NULL DEFAULT 0,
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NOT NULL,
    sort_order          INT NOT NULL DEFAULT 0,                          -- Orden de ejecución
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',          -- pending, in_progress, completed, skipped
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_appt_svc_status CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped'))
);

CREATE INDEX idx_appointment_services_appt ON appointment_services(appointment_id);
CREATE INDEX idx_appointment_services_service ON appointment_services(service_id);
CREATE INDEX idx_appointment_services_employee ON appointment_services(employee_id);
CREATE INDEX idx_appt_svc_range ON appointment_services(employee_id, starts_at, ends_at);
```

### 7.3 `waitlist_entries` — Lista de espera

```sql
CREATE TABLE waitlist_entries (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    service_id          BIGINT NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    employee_id         BIGINT NULL REFERENCES employees(id) ON DELETE SET NULL, -- Técnico preferido (NULL = cualquiera)
    preferred_date      DATE NOT NULL,
    preferred_time_start TIME NULL,
    preferred_time_end   TIME NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'waiting',          -- waiting, notified, booked, expired, cancelled
    notified_at         TIMESTAMPTZ NULL,
    expires_at          TIMESTAMPTZ NULL,
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_waitlist_status CHECK (status IN ('waiting', 'notified', 'booked', 'expired', 'cancelled'))
);

CREATE INDEX idx_waitlist_tenant_date ON waitlist_entries(tenant_id, preferred_date);
CREATE INDEX idx_waitlist_status ON waitlist_entries(status);
```

---

## 8. Módulo 5 — Gestión de Personal y Nómina

### 8.1 `employees` — Empleados/técnicos

```sql
CREATE TABLE employees (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id             BIGINT NULL REFERENCES users(id) ON DELETE SET NULL, -- Vínculo con usuario del sistema
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT, -- Sucursal principal
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(255) NULL,
    phone               VARCHAR(30) NULL,
    bio                 TEXT NULL,                                       -- Biografía para el portal del cliente
    specialties         TEXT NULL,                                       -- Especialidades
    avatar_path         VARCHAR(500) NULL,
    hire_date           DATE NULL,
    termination_date    DATE NULL,
    commission_type     VARCHAR(20) NOT NULL DEFAULT 'none',             -- none, fixed, percentage, tiered, parts_and_labor
    commission_value    DECIMAL(8,4) NULL,                               -- Valor de comisión fijo o porcentaje
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    accepts_online_booking BOOLEAN NOT NULL DEFAULT TRUE,                -- Visible en portal de reservas
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_commission_type CHECK (commission_type IN (
        'none', 'fixed', 'percentage', 'tiered', 'parts_and_labor'
    ))
);

CREATE INDEX idx_employees_tenant ON employees(tenant_id);
CREATE INDEX idx_employees_branch ON employees(branch_id);
CREATE INDEX idx_employees_user ON employees(user_id);
CREATE INDEX idx_employees_active ON employees(tenant_id, is_active);
```

### 8.2 `employee_schedules` — Horarios de trabajo por día

```sql
CREATE TABLE employee_schedules (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    day_of_week         SMALLINT NOT NULL,
    starts_at           TIME NOT NULL,
    ends_at             TIME NOT NULL,
    break_starts_at     TIME NULL,
    break_ends_at       TIME NULL,
    is_day_off          BOOLEAN NOT NULL DEFAULT FALSE,
    effective_from      DATE NOT NULL,                                  -- Desde cuándo aplica este horario
    effective_until     DATE NULL,                                      -- NULL = vigente indefinidamente
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_emp_day CHECK (day_of_week BETWEEN 0 AND 6),
    CONSTRAINT chk_emp_time CHECK (starts_at < ends_at OR is_day_off = TRUE),
    CONSTRAINT chk_emp_break CHECK (
        (break_starts_at IS NULL AND break_ends_at IS NULL) OR 
        (break_starts_at IS NOT NULL AND break_ends_at IS NOT NULL AND break_starts_at < break_ends_at)
    )
);

CREATE INDEX idx_emp_schedules_employee ON employee_schedules(employee_id);
CREATE INDEX idx_emp_schedules_branch ON employee_schedules(branch_id);
```

### 8.3 `employee_vacations` — Vacaciones y ausencias

```sql
CREATE TABLE employee_vacations (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    type                VARCHAR(20) NOT NULL,                            -- vacation, sick_leave, personal, holiday
    starts_at           DATE NOT NULL,
    ends_at             DATE NOT NULL,
    notes               TEXT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',          -- pending, approved, rejected
    approved_by         BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_vacation_type CHECK (type IN ('vacation', 'sick_leave', 'personal', 'holiday')),
    CONSTRAINT chk_vacation_status CHECK (status IN ('pending', 'approved', 'rejected')),
    CONSTRAINT chk_vacation_dates CHECK (starts_at <= ends_at)
);

CREATE INDEX idx_emp_vacations_employee ON employee_vacations(employee_id);
CREATE INDEX idx_emp_vacations_dates ON employee_vacations(starts_at, ends_at);
```

### 8.4 `commission_rules` — Reglas de comisión por niveles

```sql
CREATE TABLE commission_rules (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    employee_id         BIGINT NULL REFERENCES employees(id) ON DELETE CASCADE, -- NULL = regla global
    name                VARCHAR(100) NOT NULL,
    type                VARCHAR(20) NOT NULL,                            -- fixed, percentage, tiered, parts_and_labor
    min_amount          BIGINT NULL,                                    -- Mínimo facturado para este nivel (centavos)
    max_amount          BIGINT NULL,                                    -- Máximo facturado para este nivel
    commission_value    DECIMAL(8,4) NOT NULL,                          -- Porcentaje o valor fijo
    applies_to          VARCHAR(20) NOT NULL DEFAULT 'service',         -- service, product, all
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from      DATE NULL,
    effective_until     DATE NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_commission_type CHECK (type IN ('fixed', 'percentage', 'tiered', 'parts_and_labor')),
    CONSTRAINT chk_commission_applies CHECK (applies_to IN ('service', 'product', 'all'))
);

CREATE INDEX idx_commission_rules_employee ON commission_rules(employee_id);
```

### 8.5 `tips` — Registro de propinas

```sql
CREATE TABLE tips (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    appointment_id      BIGINT NULL REFERENCES appointments(id) ON DELETE SET NULL,
    sale_id             BIGINT NULL REFERENCES sales(id) ON DELETE SET NULL,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    amount              BIGINT NOT NULL,                                 -- Monto en centavos COP
    payment_method      VARCHAR(30) NULL,                                -- cash, card, digital
    distributed         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tips_employee ON tips(employee_id);
CREATE INDEX idx_tips_appointment ON tips(appointment_id);
CREATE INDEX idx_tips_date ON tips(tenant_id, created_at);
```

### 8.6 `employee_attendance` — Control de asistencia

```sql
CREATE TABLE employee_attendance (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    date                DATE NOT NULL,
    check_in            TIMESTAMPTZ NULL,
    check_out           TIMESTAMPTZ NULL,
    expected_check_in   TIME NOT NULL,
    expected_check_out  TIME NOT NULL,
    is_late             BOOLEAN NOT NULL DEFAULT FALSE,
    late_minutes        INT NOT NULL DEFAULT 0,
    is_absent           BOOLEAN NOT NULL DEFAULT FALSE,
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_attendance UNIQUE (employee_id, date)
);

CREATE INDEX idx_attendance_employee_date ON employee_attendance(employee_id, date);
```

---

## 9. Módulo 6 — Gestión de Clientes e Historial Clínico

### 9.1 `customers` — Clientes del negocio

```sql
CREATE TABLE customers (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id             BIGINT NULL REFERENCES users(id) ON DELETE SET NULL, -- Vínculo con usuario (si se registra)
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(255) NULL,
    phone               VARCHAR(30) NULL,
    birth_date          DATE NULL,
    gender              VARCHAR(10) NULL,
    address             TEXT NULL,
    city                VARCHAR(100) NULL,
    notes               TEXT NULL,                                       -- Notas generales
    preferences         JSONB NULL,                                      -- Preferencias: { preferred_employee_id, communication_channel, etc. }
    skin_type           VARCHAR(30) NULL,                                -- normal, dry, oily, combination, sensitive
    nail_type           VARCHAR(30) NULL,                                -- normal, brittle, soft, thick
    source              VARCHAR(20) NOT NULL DEFAULT 'walk_in',          -- walk_in, online, referral, social_media
    total_visits        INT NOT NULL DEFAULT 0,
    total_spent         BIGINT NOT NULL DEFAULT 0,                       -- Total gastado en centavos
    last_visit_at       TIMESTAMPTZ NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    marketing_opt_in    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_customer_gender CHECK (gender IS NULL OR gender IN ('male', 'female', 'other', 'prefer_not')),
    CONSTRAINT chk_customer_source CHECK (source IN ('walk_in', 'online', 'referral', 'social_media'))
);

CREATE INDEX idx_customers_tenant ON customers(tenant_id);
CREATE INDEX idx_customers_email ON customers(tenant_id, email);
CREATE INDEX idx_customers_phone ON customers(tenant_id, phone);
CREATE INDEX idx_customers_user ON customers(user_id);
```

### 9.2 `allergies` — Catálogo de alergias/condiciones

```sql
CREATE TABLE allergies (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NULL REFERENCES tenants(id) ON DELETE CASCADE, -- NULL = alergias globales del sistema
    name                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 9.3 `customer_allergies` — Alergias del cliente (N:N)

```sql
CREATE TABLE customer_allergies (
    id                  BIGSERIAL PRIMARY KEY,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    allergy_id          BIGINT NOT NULL REFERENCES allergies(id) ON DELETE CASCADE,
    severity            VARCHAR(20) NULL,                                -- mild, moderate, severe
    notes               TEXT NULL,
    diagnosed_at        DATE NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_allergy_severity CHECK (severity IS NULL OR severity IN ('mild', 'moderate', 'severe')),
    CONSTRAINT unq_customer_allergy UNIQUE (customer_id, allergy_id)
);
```

### 9.4 `clinical_records` — Historial clínico del cliente

```sql
CREATE TABLE clinical_records (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    appointment_id      BIGINT NULL REFERENCES appointments(id) ON DELETE SET NULL,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    record_date         DATE NOT NULL,
    record_type         VARCHAR(30) NOT NULL DEFAULT 'consultation',     -- consultation, follow_up, treatment
    nail_condition       TEXT NULL,                                       -- Estado de la placa ungueal
    cuticle_condition    TEXT NULL,                                      -- Estado de cutículas
    skin_observations    TEXT NULL,                                      -- Observaciones de piel
    treatment_performed  TEXT NULL,                                      -- Tratamiento realizado
    products_used       JSONB NULL,                                     -- [{product_id, product_name, lot_number, exposure_time}]
    recommendations      TEXT NULL,                                     -- Recomendaciones post-servicio
    next_visit_recommendation DATE NULL,                                -- Fecha sugerida próxima visita
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_record_type CHECK (record_type IN ('consultation', 'follow_up', 'treatment'))
);

CREATE INDEX idx_clinical_customer ON clinical_records(customer_id);
CREATE INDEX idx_clinical_appointment ON clinical_records(appointment_id);
CREATE INDEX idx_clinical_date ON clinical_records(tenant_id, record_date);
```

### 9.5 `clinical_record_photos` — Fotos del historial clínico

```sql
CREATE TABLE clinical_record_photos (
    id                  BIGSERIAL PRIMARY KEY,
    clinical_record_id  BIGINT NOT NULL REFERENCES clinical_records(id) ON DELETE CASCADE,
    path                VARCHAR(500) NOT NULL,                           -- Ruta S3
    caption             VARCHAR(255) NULL,
    photo_type          VARCHAR(30) NOT NULL DEFAULT 'before',           -- before, during, after, reference
    sort_order          INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_photo_type CHECK (photo_type IN ('before', 'during', 'after', 'reference'))
);

CREATE INDEX idx_clinical_photos_record ON clinical_record_photos(clinical_record_id);
```

### 9.6 `station_cleaning_logs` — Bitácora de limpieza por estación

```sql
CREATE TABLE station_cleaning_logs (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    station_name        VARCHAR(100) NOT NULL,                           -- Estación de trabajo
    cleaning_type       VARCHAR(30) NOT NULL,                            -- daily, between_clients, deep
    started_at          TIMESTAMPTZ NOT NULL,
    completed_at        TIMESTAMPTZ NULL,
    products_used       JSONB NULL,                                     -- Productos de limpieza utilizados
    checklist_completed BOOLEAN NOT NULL DEFAULT FALSE,
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_cleaning_type CHECK (cleaning_type IN ('daily', 'between_clients', 'deep'))
);

CREATE INDEX idx_cleaning_branch ON station_cleaning_logs(branch_id);
CREATE INDEX idx_cleaning_date ON station_cleaning_logs(tenant_id, started_at);
```

---

## 10. Módulo 7 — Inventario y Punto de Venta (POS)

### 10.1 `product_categories` — Categorías de productos

```sql
CREATE TABLE product_categories (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                VARCHAR(100) NOT NULL,
    slug                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    type                VARCHAR(20) NOT NULL DEFAULT 'retail',           -- retail (venta), supply (insumo profesional)
    parent_id           BIGINT NULL REFERENCES product_categories(id) ON DELETE SET NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order          INT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_product_cat_type CHECK (type IN ('retail', 'supply')),
    CONSTRAINT unq_product_cat_slug UNIQUE (slug, tenant_id)
);

CREATE INDEX idx_product_categories_tenant ON product_categories(tenant_id);
```

### 10.2 `products` — Productos del inventario

```sql
CREATE TABLE products (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    category_id         BIGINT NOT NULL REFERENCES product_categories(id) ON DELETE RESTRICT,
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    sku                 VARCHAR(50) NULL,
    barcode             VARCHAR(100) NULL,
    name                VARCHAR(200) NOT NULL,
    description         TEXT NULL,
    type                VARCHAR(20) NOT NULL DEFAULT 'retail',           -- retail, supply
    brand               VARCHAR(100) NULL,
    cost_price          BIGINT NOT NULL,                                 -- Costo en centavos COP
    sale_price          BIGINT NULL,                                    -- Precio de venta (NULL para insumos)
    unit_of_measure     VARCHAR(20) NOT NULL DEFAULT 'unit',            -- unit, ml, g, piece
    track_inventory     BOOLEAN NOT NULL DEFAULT TRUE,
    low_stock_threshold INT NULL,                                       -- Umbral para alertas
    max_stock           INT NULL,
    requires_lot        BOOLEAN NOT NULL DEFAULT FALSE,                  -- Requiere registro de lote
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    image_path          VARCHAR(500) NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_product_type CHECK (type IN ('retail', 'supply')),
    CONSTRAINT chk_product_uom CHECK (unit_of_measure IN ('unit', 'ml', 'g', 'piece'))
);

CREATE INDEX idx_products_tenant ON products(tenant_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_sku ON products(tenant_id, sku) WHERE sku IS NOT NULL;
CREATE INDEX idx_products_barcode ON products(tenant_id, barcode) WHERE barcode IS NOT NULL;
```

### 10.3 `inventory_stock` — Stock por sucursal

```sql
CREATE TABLE inventory_stock (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id          BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    quantity             INT NOT NULL DEFAULT 0,
    quantity_reserved   INT NOT NULL DEFAULT 0,                          -- Reservado en citas pendientes
    quantity_available  INT GENERATED ALWAYS AS (quantity - quantity_reserved) STORED,
    reorder_point       INT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_inventory_branch_product UNIQUE (product_id, branch_id)
);

CREATE INDEX idx_inventory_branch ON inventory_stock(branch_id);
CREATE INDEX idx_inventory_product ON inventory_stock(product_id);
CREATE INDEX idx_inventory_low_stock ON inventory_stock(tenant_id, quantity_available) WHERE quantity_available <= 5;
```

### 10.4 `inventory_lots` — Lotes de producto y tiempos de exposición

```sql
CREATE TABLE inventory_lots (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id          BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    lot_number          VARCHAR(100) NOT NULL,
    supplier            VARCHAR(200) NULL,
    quantity_received   INT NOT NULL,
    quantity_remaining  INT NOT NULL,
    manufacturing_date  DATE NULL,
    expiration_date     DATE NULL,
    received_at         DATE NOT NULL,
    cost_per_unit       BIGINT NULL,                                    -- Costo unitario en centavos
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_inventory_lots_product ON inventory_lots(product_id);
CREATE INDEX idx_inventory_lots_expiration ON inventory_lots(expiration_date) WHERE expiration_date IS NOT NULL;
```

### 10.5 `stock_movements` — Movimientos de inventario (auditoría)

```sql
CREATE TABLE stock_movements (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id          BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    type                VARCHAR(20) NOT NULL,                            -- in, out, adjustment, transfer, return
    quantity             INT NOT NULL,
    quantity_before     INT NOT NULL,
    quantity_after      INT NOT NULL,
    reference_type      VARCHAR(50) NULL,                               -- sale, appointment, adjustment, transfer
    reference_id        BIGINT NULL,                                    -- ID de la referencia
    reason              TEXT NULL,
    performed_by        BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_movement_type CHECK (type IN ('in', 'out', 'adjustment', 'transfer', 'return'))
);

CREATE INDEX idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX idx_stock_movements_branch ON stock_movements(branch_id);
CREATE INDEX idx_stock_movements_date ON stock_movements(tenant_id, created_at);
```

### 10.6 `sales` — Transacciones POS (ventas)

```sql
CREATE TABLE sales (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    customer_id         BIGINT NULL REFERENCES customers(id) ON DELETE SET NULL,
    employee_id         BIGINT NULL REFERENCES employees(id) ON DELETE SET NULL, -- Quién atendió
    appointment_id      BIGINT NULL REFERENCES appointments(id) ON DELETE SET NULL, -- Venta vinculada a cita
    sale_number         VARCHAR(50) NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'completed',        -- completed, refunded, partially_refunded, voided
    subtotal            BIGINT NOT NULL DEFAULT 0,
    tax_amount          BIGINT NOT NULL DEFAULT 0,
    discount_amount     BIGINT NOT NULL DEFAULT 0,
    tip_amount          BIGINT NOT NULL DEFAULT 0,
    total               BIGINT NOT NULL DEFAULT 0,
    paid_amount         BIGINT NOT NULL DEFAULT 0,
    change_amount       BIGINT NOT NULL DEFAULT 0,
    payment_method      VARCHAR(30) NOT NULL,                            -- cash, card, nequi, daviplata, pse
    payment_reference   VARCHAR(255) NULL,
    notes               TEXT NULL,
    refunded_at         TIMESTAMPTZ NULL,
    cash_register_id    BIGINT NULL REFERENCES cash_register_sessions(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_sale_status CHECK (status IN ('completed', 'refunded', 'partially_refunded', 'voided')),
    CONSTRAINT unq_sale_number UNIQUE (sale_number, tenant_id)
);

CREATE INDEX idx_sales_tenant ON sales(tenant_id);
CREATE INDEX idx_sales_branch ON sales(branch_id);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_date ON sales(tenant_id, created_at);
```

### 10.7 `sale_items` — Items de una venta

```sql
CREATE TABLE sale_items (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    sale_id             BIGINT NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    item_type           VARCHAR(20) NOT NULL,                            -- service, product
    service_id          BIGINT NULL REFERENCES services(id) ON DELETE SET NULL,
    product_id          BIGINT NULL REFERENCES products(id) ON DELETE SET NULL,
    employee_id         BIGINT NULL REFERENCES employees(id) ON DELETE SET NULL,
    item_name           VARCHAR(200) NOT NULL,                           -- Nombre al momento de la venta
    quantity             INT NOT NULL DEFAULT 1,
    unit_price          BIGINT NOT NULL,                                 -- Precio unitario en centavos
    discount_amount     BIGINT NOT NULL DEFAULT 0,
    tax_amount          BIGINT NOT NULL DEFAULT 0,
    total               BIGINT NOT NULL,                                 -- (unit_price * quantity) - discount + tax
    commission_amount   BIGINT NULL,                                    -- Comisión calculada
    lot_number          VARCHAR(100) NULL,                              -- Lote de producto (trazabilidad)
    is_refunded         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_item_type CHECK (item_type IN ('service', 'product'))
);

CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);
CREATE INDEX idx_sale_items_service ON sale_items(service_id);
```

### 10.8 `biosecurity_checklists` — Checklist de bioseguridad pre-servicio

```sql
CREATE TABLE biosecurity_checklists (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    appointment_id      BIGINT NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    employee_id         BIGINT NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    station_name        VARCHAR(100) NOT NULL,
    checklist_data      JSONB NOT NULL,                                 -- [{item: "Sanitización de herramientas", completed: true}, ...]
    all_completed       BOOLEAN NOT NULL DEFAULT FALSE,
    notes               TEXT NULL,
    completed_at        TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_biosecurity_appointment ON biosecurity_checklists(appointment_id);
CREATE INDEX idx_biosecurity_branch ON biosecurity_checklists(branch_id);
```

---

## 11. Módulo 8 — Financiero y Reportes

### 11.1 `cash_register_sessions` — Sesiones de caja

```sql
CREATE TABLE cash_register_sessions (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    user_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT, -- Quién abrió la caja
    opened_at           TIMESTAMPTZ NOT NULL,
    closed_at           TIMESTAMPTZ NULL,
    opening_amount      BIGINT NOT NULL DEFAULT 0,                       -- Monto de apertura en centavos
    closing_amount      BIGINT NULL,                                    -- Monto de cierre real
    expected_amount     BIGINT NULL,                                    -- Monto esperado según sistema
    difference_amount   BIGINT NULL,                                    -- Diferencia (sobrante/faltante)
    total_sales         BIGINT NOT NULL DEFAULT 0,
    total_refunds       BIGINT NOT NULL DEFAULT 0,
    total_tips          BIGINT NOT NULL DEFAULT 0,
    status              VARCHAR(20) NOT NULL DEFAULT 'open',             -- open, closed
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_cash_status CHECK (status IN ('open', 'closed'))
);

CREATE INDEX idx_cash_register_branch ON cash_register_sessions(branch_id);
CREATE INDEX idx_cash_register_user ON cash_register_sessions(user_id);
CREATE INDEX idx_cash_register_date ON cash_register_sessions(tenant_id, opened_at);
```

### 11.2 `expense_categories` — Categorías de gastos

```sql
CREATE TABLE expense_categories (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    is_system           BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_expense_categories_tenant ON expense_categories(tenant_id);
```

### 11.3 `financial_transactions` — Transacciones financieras (ingresos/gastos)

```sql
CREATE TABLE financial_transactions (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id           BIGINT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    type                VARCHAR(20) NOT NULL,                            -- income, expense
    category_id         BIGINT NULL REFERENCES expense_categories(id) ON DELETE SET NULL,
    amount              BIGINT NOT NULL,                                 -- Monto en centavos COP
    description         TEXT NOT NULL,
    reference_type      VARCHAR(50) NULL,                               -- sale, appointment, manual
    reference_id        BIGINT NULL,
    payment_method      VARCHAR(30) NULL,
    transaction_date    DATE NOT NULL,
    recorded_by         BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    is_recurring        BOOLEAN NOT NULL DEFAULT FALSE,
    recurring_period    VARCHAR(20) NULL,                                -- daily, weekly, monthly, yearly
    attachment_path     VARCHAR(500) NULL,
    notes               TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_fin_type CHECK (type IN ('income', 'expense'))
);

CREATE INDEX idx_fin_trans_tenant ON financial_transactions(tenant_id);
CREATE INDEX idx_fin_trans_branch ON financial_transactions(branch_id);
CREATE INDEX idx_fin_trans_date ON financial_transactions(tenant_id, transaction_date);
CREATE INDEX idx_fin_trans_type ON financial_transactions(tenant_id, type);
```

---

## 12. Módulo 9 — Portal del Cliente

> Este módulo no agrega tablas propias — utiliza tablas de otros módulos:
> - `customers` (Módulo 6) para el perfil del cliente
> - `appointments` (Módulo 4) para las citas del cliente
> - `sales` (Módulo 7) para el historial de compras
> - `loyalty_accounts` (Módulo 11) para puntos de lealtad
> - `branches` (Módulo 2) para búsqueda de locales
> - `services` (Módulo 3) para catálogo visible
> - `employees` (Módulo 5) para profesionales disponibles

---

## 13. Módulo 10 — Notificaciones y Comunicaciones

### 13.1 `notification_templates` — Plantillas de notificaciones

```sql
CREATE TABLE notification_templates (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NULL REFERENCES tenants(id) ON DELETE CASCADE, -- NULL = plantilla del sistema
    name                VARCHAR(100) NOT NULL,
    slug                VARCHAR(100) NOT NULL,
    channel             VARCHAR(20) NOT NULL,                            -- email, push, whatsapp, sms
    trigger_event       VARCHAR(100) NOT NULL,                           -- appointment.created, appointment.reminder.24h, etc.
    subject             VARCHAR(255) NULL,                               -- Asunto (email)
    body                TEXT NOT NULL,                                   -- Cuerpo con variables: {{customer_name}}, {{date}}, etc.
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_notification_channel CHECK (channel IN ('email', 'push', 'whatsapp', 'sms')),
    CONSTRAINT unq_notification_template UNIQUE (slug, tenant_id)
);
```

### 13.2 `notifications` — Registro de notificaciones enviadas

```sql
CREATE TABLE notifications (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id             BIGINT NULL REFERENCES users(id) ON DELETE CASCADE,
    customer_id         BIGINT NULL REFERENCES customers(id) ON DELETE CASCADE,
    template_id         BIGINT NULL REFERENCES notification_templates(id) ON DELETE SET NULL,
    channel             VARCHAR(20) NOT NULL,
    subject             VARCHAR(255) NULL,
    body                TEXT NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',          -- pending, sent, delivered, failed, read
    recipient           VARCHAR(255) NOT NULL,                           -- Email, teléfono, device token
    external_id         VARCHAR(255) NULL,                               -- ID del servicio externo (SendGrid, Firebase, etc.)
    error_message       TEXT NULL,
    sent_at             TIMESTAMPTZ NULL,
    delivered_at        TIMESTAMPTZ NULL,
    read_at             TIMESTAMPTZ NULL,
    related_type        VARCHAR(50) NULL,                                -- appointment, sale, etc.
    related_id          BIGINT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_notif_status CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'read')),
    CONSTRAINT chk_notif_channel CHECK (channel IN ('email', 'push', 'whatsapp', 'sms'))
);

CREATE INDEX idx_notifications_tenant ON notifications(tenant_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_customer ON notifications(customer_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_notifications_date ON notifications(tenant_id, created_at);
```

---

## 14. Módulo 11 — Fidelización y Membresías

### 14.1 `loyalty_accounts` — Cuenta de lealtad del cliente

```sql
CREATE TABLE loyalty_accounts (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    points_balance      INT NOT NULL DEFAULT 0,
    points_earned_total INT NOT NULL DEFAULT 0,
    points_redeemed_total INT NOT NULL DEFAULT 0,
    tier                VARCHAR(30) NOT NULL DEFAULT 'bronze',           -- bronze, silver, gold, platinum
    tier_earned_at      TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_loyalty_customer UNIQUE (customer_id),
    CONSTRAINT chk_tier CHECK (tier IN ('bronze', 'silver', 'gold', 'platinum'))
);

CREATE INDEX idx_loyalty_customer ON loyalty_accounts(customer_id);
```

### 14.2 `loyalty_transactions` — Movimientos de puntos

```sql
CREATE TABLE loyalty_transactions (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    loyalty_account_id  BIGINT NOT NULL REFERENCES loyalty_accounts(id) ON DELETE CASCADE,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type                VARCHAR(20) NOT NULL,                            -- earn, redeem, expire, bonus
    points              INT NOT NULL,                                    -- Positivo (earn) o negativo (redeem/expire)
    balance_after       INT NOT NULL,
    source              VARCHAR(50) NOT NULL,                            -- appointment, sale, referral, manual, signup_bonus
    source_id           BIGINT NULL,
    description         TEXT NULL,
    expires_at          TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_loyalty_type CHECK (type IN ('earn', 'redeem', 'expire', 'bonus'))
);

CREATE INDEX idx_loyalty_trans_account ON loyalty_transactions(loyalty_account_id);
CREATE INDEX idx_loyalty_trans_customer ON loyalty_transactions(customer_id);
CREATE INDEX idx_loyalty_trans_date ON loyalty_transactions(tenant_id, created_at);
```

### 14.3 `membership_plans` — Planes de membresía (ej. "Manicura Ilimitada")

```sql
CREATE TABLE membership_plans (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    price_monthly       BIGINT NOT NULL,                                 -- Precio mensual en centavos COP
    duration_months     INT NOT NULL DEFAULT 1,
    included_services   JSONB NULL,                                     -- [{service_id, max_per_month: null}] null = ilimitado
    discount_percent    INT NULL,                                        -- % descuento en servicios no incluidos
    max_bookings_month  INT NULL,                                       -- NULL = ilimitado
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL
);

CREATE INDEX idx_membership_plans_tenant ON membership_plans(tenant_id);
```

### 14.4 `customer_memberships` — Membresías activas de clientes

```sql
CREATE TABLE customer_memberships (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    plan_id             BIGINT NOT NULL REFERENCES membership_plans(id) ON DELETE RESTRICT,
    status              VARCHAR(20) NOT NULL DEFAULT 'active',           -- active, cancelled, expired, paused
    starts_at           DATE NOT NULL,
    ends_at             DATE NOT NULL,
    cancelled_at        DATE NULL,
    auto_renew          BOOLEAN NOT NULL DEFAULT TRUE,
    payment_method      VARCHAR(30) NULL,
    bookings_used       INT NOT NULL DEFAULT 0,
    bookings_limit      INT NULL,                                       -- Copia del límite al momento de la compra
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_cust_mem_status CHECK (status IN ('active', 'cancelled', 'expired', 'paused'))
);

CREATE INDEX idx_customer_memberships_customer ON customer_memberships(customer_id);
CREATE INDEX idx_customer_memberships_plan ON customer_memberships(plan_id);
CREATE INDEX idx_customer_memberships_status ON customer_memberships(status);
```

### 14.5 `coupons` — Cupones y promociones

```sql
CREATE TABLE coupons (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    code                VARCHAR(30) NOT NULL,
    name                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    discount_type       VARCHAR(20) NOT NULL,                            -- percentage, fixed_amount
    discount_value      BIGINT NOT NULL,                                 -- % o monto fijo en centavos
    min_purchase        BIGINT NULL,                                    -- Compra mínima en centavos
    max_uses            INT NULL,                                       -- NULL = ilimitado
    uses_count          INT NOT NULL DEFAULT 0,
    max_uses_per_customer INT NULL,
    applicable_services JSONB NULL,                                     -- NULL = todos los servicios. [service_id, ...]
    applicable_branches JSONB NULL,                                     -- NULL = todas las sucursales
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ NULL,

    CONSTRAINT chk_coupon_type CHECK (discount_type IN ('percentage', 'fixed_amount')),
    CONSTRAINT chk_coupon_value CHECK (discount_value > 0),
    CONSTRAINT chk_coupon_dates CHECK (starts_at < ends_at),
    CONSTRAINT unq_coupon_code UNIQUE (code, tenant_id)
);

CREATE INDEX idx_coupons_tenant ON coupons(tenant_id);
CREATE INDEX idx_coupons_code ON coupons(code);
```

### 14.6 `coupon_redemptions` — Historial de uso de cupones

```sql
CREATE TABLE coupon_redemptions (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    coupon_id           BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    sale_id             BIGINT NULL REFERENCES sales(id) ON DELETE SET NULL,
    appointment_id      BIGINT NULL REFERENCES appointments(id) ON DELETE SET NULL,
    discount_applied    BIGINT NOT NULL,                                 -- Descuento aplicado en centavos
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_coupon_redemptions_coupon ON coupon_redemptions(coupon_id);
CREATE INDEX idx_coupon_redemptions_customer ON coupon_redemptions(customer_id);
```

### 14.7 `gamification_challenges` — Retos de gamificación

```sql
CREATE TABLE gamification_challenges (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name                VARCHAR(100) NOT NULL,
    description         TEXT NULL,
    challenge_type      VARCHAR(50) NOT NULL,                            -- bookings_count, visits_morning, try_new_service, etc.
    target_value        INT NOT NULL,                                   -- Ej: 5 reservas
    reward_type         VARCHAR(20) NOT NULL,                            -- points, free_service, discount_coupon
    reward_value        BIGINT NOT NULL,
    reward_service_id   BIGINT NULL REFERENCES services(id) ON DELETE SET NULL,
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_reward_type CHECK (reward_type IN ('points', 'free_service', 'discount_coupon'))
);
```

### 14.8 `challenge_participations` — Participación de clientes en retos

```sql
CREATE TABLE challenge_participations (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    challenge_id        BIGINT NOT NULL REFERENCES gamification_challenges(id) ON DELETE CASCADE,
    customer_id         BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    progress            INT NOT NULL DEFAULT 0,
    is_completed        BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at        TIMESTAMPTZ NULL,
    reward_claimed      BOOLEAN NOT NULL DEFAULT FALSE,
    reward_claimed_at   TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unq_challenge_participation UNIQUE (challenge_id, customer_id)
);
```

---

## 15. Módulo 12 — Seguridad y Cumplimiento

### 15.1 `consent_records` — Consentimiento del usuario

```sql
CREATE TABLE consent_records (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id             BIGINT NULL REFERENCES users(id) ON DELETE CASCADE,
    customer_id         BIGINT NULL REFERENCES customers(id) ON DELETE CASCADE,
    consent_type        VARCHAR(50) NOT NULL,                            -- terms_of_service, privacy_policy, marketing, data_processing
    version             VARCHAR(20) NOT NULL,                            -- Versión del documento
    granted             BOOLEAN NOT NULL,
    ip_address          INET NULL,
    user_agent          TEXT NULL,
    granted_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at          TIMESTAMPTZ NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_consent_type CHECK (consent_type IN (
        'terms_of_service', 'privacy_policy', 'marketing', 'data_processing', 'clinical_records'
    ))
);

CREATE INDEX idx_consent_user ON consent_records(user_id);
CREATE INDEX idx_consent_customer ON consent_records(customer_id);
CREATE INDEX idx_consent_type ON consent_records(consent_type);
```

### 15.2 `data_subject_requests` — Solicitudes de derechos ARCO

```sql
CREATE TABLE data_subject_requests (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           BIGINT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    requester_email     VARCHAR(255) NOT NULL,
    requester_name      VARCHAR(200) NULL,
    request_type        VARCHAR(30) NOT NULL,                            -- access, rectification, cancellation, opposition, portability
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',          -- pending, in_progress, completed, rejected
    description         TEXT NOT NULL,
    response            TEXT NULL,
    processed_by        BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
    requested_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deadline_at         TIMESTAMPTZ NOT NULL,                            -- Fecha límite legal para responder
    completed_at        TIMESTAMPTZ NULL,
    attachments         JSONB NULL,                                     -- [{path, name}]
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_dsar_type CHECK (request_type IN ('access', 'rectification', 'cancellation', 'opposition', 'portability')),
    CONSTRAINT chk_dsar_status CHECK (status IN ('pending', 'in_progress', 'completed', 'rejected'))
);

CREATE INDEX idx_dsar_tenant ON data_subject_requests(tenant_id);
CREATE INDEX idx_dsar_status ON data_subject_requests(status);
CREATE INDEX idx_dsar_email ON data_subject_requests(requester_email);
```

---

## 16. Índices Estratégicos

### 16.1 Índices compuestos para consultas frecuentes

```sql
-- Citas por sucursal y fecha (calendario)
CREATE INDEX idx_appt_calendar ON appointments(branch_id, starts_at) 
    WHERE deleted_at IS NULL AND status NOT IN ('cancelled');

-- Disponibilidad de empleados por sucursal y día
CREATE INDEX idx_emp_available ON employees(branch_id, is_active) 
    WHERE is_active = TRUE AND deleted_at IS NULL;

-- Búsqueda de clientes por nombre/teléfono
CREATE INDEX idx_customer_search ON customers USING gin(
    to_tsvector('simple', first_name || ' ' || last_name || ' ' || COALESCE(phone, ''))
) WHERE tenant_id IS NOT NULL;

-- Productos con stock bajo
CREATE INDEX idx_low_stock ON inventory_stock(tenant_id, quantity_available) 
    WHERE quantity_available <= 5;

-- Transacciones financieras por período
CREATE INDEX idx_fin_period ON financial_transactions(tenant_id, transaction_date, type);

-- Notificaciones pendientes
CREATE INDEX idx_notif_pending ON notifications(status, channel) 
    WHERE status = 'pending';
```

### 16.2 Índices para el motor de disponibilidad (crítico)

```sql
-- Verificar colisiones de citas rápidamente
CREATE INDEX idx_appt_collision ON appointment_services(employee_id, starts_at, ends_at)
    WHERE tenant_id IS NOT NULL;

-- Horarios de empleados por día
CREATE INDEX idx_emp_sched_lookup ON employee_schedules(employee_id, day_of_week)
    WHERE is_day_off = FALSE;

-- Vacaciones activas de empleados
CREATE INDEX idx_emp_vacation_active ON employee_vacations(employee_id, starts_at, ends_at)
    WHERE status = 'approved';
```

---

## 17. Notas de Implementación con Eloquent

### 17.1 Global Scope Multi-Tenant

```php
// app/Models/Traits/BelongsToTenant.php
trait BelongsToTenant
{
    protected static function bootBelongsToTenant(): void
    {
        static::addGlobalScope('tenant', function (Builder $builder) {
            if ($tenantId = app('current_tenant_id')) {
                $builder->where('tenant_id', $tenantId);
            }
        });

        static::creating(function (Model $model) {
            if ($tenantId = app('current_tenant_id')) {
                $model->tenant_id = $tenantId;
            }
        });
    }
}
```

### 17.2 Columnas encriptadas (Especificar en modelos)

```php
// Las siguientes columnas deben usar $casts con 'encrypted':
// - customers.preferences (JSON encriptado)
// - customers.notes (dato sensible)
// - clinical_records.nail_condition (dato de salud)
// - clinical_records.skin_observations (dato de salud)
// - clinical_records.treatment_performed (dato de salud)
// - users.password (ya hasheado con bcrypt)
// - social_accounts.provider_token (token sensible)
```

### 17.3 Relaciones principales (resumen)

| Modelo | Relación | Modelo Relacionado |
|--------|----------|-------------------|
| `Tenant` | hasMany | `Branch`, `User`, `Service`, `Customer`, `Employee` |
| `Branch` | belongsTo | `Tenant` |
| `Branch` | hasMany | `BranchSchedule`, `Appointment`, `Employee`, `InventoryStock` |
| `User` | belongsTo | `Tenant`, `Role` |
| `User` | hasOne | `Employee` (si es técnico), `Customer` (si es cliente) |
| `Employee` | belongsToMany | `Service` (via `service_technician`) |
| `Customer` | hasMany | `Appointment`, `ClinicalRecord`, `Sale` |
| `Customer` | hasOne | `LoyaltyAccount`, `CustomerMembership` |
| `Appointment` | belongsTo | `Customer`, `Employee`, `Branch` |
| `Appointment` | hasMany | `AppointmentService` |
| `Sale` | hasMany | `SaleItem` |
| `Service` | belongsTo | `ServiceCategory` |
| `Service` | belongsToMany | `Employee`, `Branch` (con precios) |

---

## 18. Glosario

| Término | Definición |
|---------|-----------|
| **tenant_id** | Identificador del negocio (multi-tenancy). Filtra todos los datos de un negocio específico. |
| **COP** | Peso Colombiano. Moneda del sistema. Almacenado en centavos como BIGINT. |
| **Buffer** | Tiempo de amortiguación entre citas para limpieza/preparación. |
| **Processing time** | Tiempo donde el cliente está ocupado (ej: secado de esmalte) pero el técnico puede atender otra cita corta. |
| **Walk-in** | Cliente que llega sin cita previa. |
| **No-show** | Cliente que no asiste a su cita sin cancelar. |
| **POS** | Point of Sale (Punto de Venta). Sistema de checkout integrado. |
| **ARCO** | Acceso, Rectificación, Cancelación, Oposición. Derechos del titular de datos personales. |
| **DIAN** | Dirección de Impuestos y Aduanas Nacionales de Colombia. |
| **PSE** | Producto Servicios Electrónicos. Sistema de pagos débito en Colombia. |

---

## Resumen Estadístico

| Categoría | Cantidad |
|-----------|---------|
| **Total de tablas** | 45 |
| **Tablas de plataforma** (sin tenant_id) | 4 |
| **Tablas de negocio** (con tenant_id) | 41 |
| **Índices estratégicos** | ~50 |
| **Módulos cubiertos** | 12 + Plataforma |
| **Foreign Keys** | ~70 |

---

> **Nota final**: Este diseño es la versión 1.0 y cubre todos los módulos definidos en el documento de requerimientos refinados. Las tablas están diseñadas para PostgreSQL 16+ y son compatibles con Laravel Eloquent ORM. A medida que el proyecto avance, pueden agregarse tablas pivote adicionales o columnas según necesidades específicas detectadas durante el desarrollo.