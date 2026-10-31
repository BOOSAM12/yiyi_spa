# YiYi Spa — Diseño de arquitectura, stack, harness y swarm

> **Estado:** borrador para aprobación · **Fecha:** 2026-10-26
> **Fuentes:** `Documentacion/` (Requerimientos, Refinación, Diseño de BD v1.0) y el mockup
> "YiYi Spa — Mockup" (https://claude.ai/artifact/BfxFSAxNHkZd3vS7r2vbKw, 26 pantallas).
> Las decisiones marcadas **[Usuario]** las tomó Sergio. Las marcadas **[Claude]** son criterio
> mío y se pueden discutir.

---

## 1. Intención

Construir una plataforma SaaS multi-tenant para administrar **cualquier** negocio tipo spa o
salón de uñas en Colombia: agenda, citas, POS, clientes e historial clínico, personal y
comisiones, inventario, finanzas, bioseguridad, fidelización y un portal público de reservas.
Cada negocio (tenant) es independiente y muchos son **competencia directa entre sí**.

El proyecto lo construye **una sola persona dirigiendo agentes de IA** **[Usuario]**. Por eso
la calidad no puede depender de la memoria del desarrollador ni de la del agente: tiene que
estar en el harness (`.claude/`), en los gates del swarm y, cuando se pueda, en la propia
base de datos.

## 2. Objetivos, no-objetivos y anti-objetivos

**Objetivos**
- Cubrir las 5 superficies del mockup: Panel del negocio (dueño), Recepción, Técnico, Portal
  del cliente y Super Admin.
- Un motor de agenda donde el overbooking sea **imposible**, no solo improbable.
- Aislamiento total entre tenants, verificable automáticamente.
- Un harness y un swarm que permitan a una persona construir los 12 módulos con disciplina.

**No-objetivos (por ahora)**
- Microservicios, Kubernetes, multi-región.
- App móvil nativa (la API queda lista para ella, pero no se construye).
- IA, AR y tours 360 (Fase 4 del roadmap).
- SEO/SSR del portal público (se difiere; ver §10).

**Anti-objetivos (aunque "funcione", sería un fracaso)**
- Que un tenant vea un solo dato de otro tenant.
- Que dos clientes reserven al mismo técnico o a la misma estación en el mismo intervalo.
- Que un valor monetario se calcule o guarde en punto flotante.
- Que el frontend se aleje del design system del mockup.
- Que el harness sea tan grande que cada sesión del agente arranque saturada de contexto.

## 3. Restricciones

- Mercado Colombia: COP sin decimales en la UI, IVA 19 %, facturación electrónica DIAN,
  Ley 1581 de 2012, medios PSE / tarjeta / Nequi / Daviplata.
- Desarrollo en **Windows** (xampp en la máquina, Git Bash disponible). Los scripts del harness
  y del swarm son bash POSIX y deben correr en Git Bash.
- Repositorio en GitHub (`BOOSAM12/yiyi_spa`) → CI en **GitHub Actions**.
- Presupuesto de MVP bajo: infraestructura barata y operable por una persona.

## 4. Decisiones tomadas

| Tema | Decisión | Origen |
|---|---|---|
| Modelo SaaS | Multi-tenant, single DB con `tenant_id` | [Usuario] (doc Refinación) |
| Mercado | Colombia | [Usuario] (doc Refinación) |
| Dinero | `BIGINT` en centavos COP | [Usuario] (doc Diseño BD) |
| Backend | Laravel 13, PHP 8.4 (Pest 5 exige 8.4) | [Usuario] (versión ajustada en el plan del esqueleto) |
| Frontend | **SPA React + API** con Sanctum (cookie para staff) | [Usuario] |
| Base de datos | **PostgreSQL 18** | [Usuario] |
| Equipo | Una persona con agentes; swarm **secuencial**, un solo workspace | [Usuario] |
| Despliegue MVP | **Docker Compose en un VPS** (Hetzner o DigitalOcean) | [Usuario] |
| Roadmap | Fases 1–4 del doc Refinación | [Usuario] |
| Arquitectura | Monolito modular (no microservicios) | [Claude] |
| Defensa de tenant | 3 capas: Global Scope + trait + Row-Level Security | [Claude] |
| Anti-overbooking | Restricción de exclusión en PostgreSQL sobre bloques de ocupación | [Claude] |
| Idioma | Código, tablas y API en inglés; UI en español; harness y docs en español | [Claude] |
| Runtime PHP | php-fpm en el MVP (Octane diferido; ver §11) | [Claude] |
| Pasarela de pago | Se decide en Fase 3 (MercadoPago / Wompi / PlaceToPay) | [Usuario] |

---

## 5. Arquitectura del backend: monolito modular

Con 45 tablas acopladas transaccionalmente (una venta toca cita + inventario + comisión + caja
+ puntos en la misma transacción), partir en servicios obligaría a transacciones distribuidas
sin beneficio. Se construye **un solo Laravel** dividido en módulos con fronteras explícitas.

```
backend/
├── app/
│   ├── Platform/            # Super Admin: tenants, planes, suscripciones, pagos SaaS
│   ├── Modules/
│   │   ├── Identity/        # usuarios, roles, permisos, login social, auditoría
│   │   ├── Business/        # tenant, sucursales, horarios, fechas especiales, políticas, recursos
│   │   ├── Catalog/         # categorías, servicios, precios por sucursal, servicio↔técnico
│   │   ├── Scheduling/      # motor de disponibilidad, citas, bloques de ocupación, lista de espera
│   │   ├── Staff/           # empleados, turnos, ausencias, asistencia, comisiones, propinas
│   │   ├── Customers/       # clientes, alergias, historial clínico, fotos
│   │   ├── Inventory/       # productos, stock por sucursal, lotes, movimientos
│   │   ├── Sales/           # POS, ventas, ítems, sesiones de caja
│   │   ├── Finance/         # transacciones, categorías de gasto, flujo de caja, P&G
│   │   ├── Loyalty/         # puntos, membresías, cupones, retos
│   │   ├── Biosafety/       # checklists pre-servicio, bitácoras de limpieza
│   │   ├── Notifications/   # plantillas, envíos, canales (email; WhatsApp en Fase 3)
│   │   ├── Compliance/      # consentimientos, solicitudes ARCO
│   │   └── Reporting/       # transversal y SOLO LECTURA (consultas/vistas agregadas)
│   └── Shared/              # Money, TenantContext, BelongsToTenant, ValueObjects, base Policies
├── database/migrations/<módulo>/
└── tests/{Unit,Feature,Architecture}/<módulo>/
```

Cada módulo tiene la misma forma interna:

```
Modules/Scheduling/
├── Domain/          # entidades, value objects, reglas puras (sin Eloquent, sin framework)
├── Application/     # casos de uso (BookAppointment, CancelAppointment…) y DTOs
├── Infrastructure/  # modelos Eloquent, repositorios, jobs, listeners
├── Http/            # controllers, FormRequests, API Resources, rutas del módulo
└── Events/          # eventos de dominio públicos (AppointmentBooked, AppointmentCancelled…)
```

**Reglas de dependencia (las hacen cumplir Deptrac y los tests de arquitectura de Pest):**
1. Un módulo **no importa** modelos Eloquent, repositorios ni clases `Infrastructure` de otro.
2. Entre módulos solo se usa: (a) la clase pública `<Módulo>/Application/*Service` o
   (b) eventos de dominio de `<Módulo>/Events`.
3. `Domain/` no depende de Laravel.
4. `Reporting` puede leer tablas de cualquier módulo, pero no escribe en ninguna.
5. `Shared` no depende de ningún módulo.

**Profundidad diferenciada [Claude]:** no todos los módulos merecen el mismo rigor. Dominio
puro y pruebas de mutación para `Scheduling`, `Shared/Money`, `Staff` (comisiones) y `Sales`.
Para módulos que son esencialmente CRUD (`Catalog`, `Biosafety`, `Notifications`) basta un
`Application` delgado + Eloquent; no se fuerza un `Domain/` vacío.

## 6. Multi-tenancy: tres capas de defensa

Los tenants son competencia directa; una fuga es el peor fallo posible del producto.

1. **Global Scope** (`TenantScope`) en todo modelo de negocio: filtra `WHERE tenant_id = ?`.
2. **Trait `BelongsToTenant`**: aplica el scope y rellena `tenant_id` al crear; lanza excepción
   si se intenta crear sin tenant en contexto.
3. **Row-Level Security de PostgreSQL** como red final. Cada tabla con `tenant_id` tiene
   `ENABLE ROW LEVEL SECURITY` + `FORCE ROW LEVEL SECURITY` y una política
   `USING (tenant_id = current_setting('app.tenant_id')::bigint)`. La conexión de la
   aplicación usa un rol **sin** `BYPASSRLS`. El tenant se fija por petición con
   `SET app.tenant_id = …` en un middleware, y por job en un middleware de cola.
   Super Admin y las tareas de plataforma usan una conexión separada con un rol que sí lo omite.

**Resolución del tenant:**
- Staff (dueño, recepción, técnico): desde la **membresía activa** elegida al iniciar sesión
  (§19) y guardada en la sesión. Cada petición valida que el usuario siga teniendo esa membresía.
- Portal público: desde el slug en la URL (`/r/{slug}/…`).
- Jobs en cola: el `tenant_id` viaja en el payload del job; un middleware de job lo restaura.
  Un job de negocio sin tenant falla; nunca corre en modo "global".

**Clientes:** una persona que reserva en dos spas es **un** `users` (con `tenant_id NULL`) y
**dos** filas en `customers` (una por tenant). `customers.user_id` no es único.

**Verificación:** el gate de aislamiento del swarm (§14) crea dos tenants con datos, recorre
cada endpoint autenticado como el tenant A y falla si aparece cualquier identificador del B.

## 7. Motor de agenda (`Scheduling`)

Es el corazón del producto y el único lugar donde un bug cuesta dinero visible.

**Invariante:** un técnico o un recurso físico nunca tiene dos ocupaciones que se solapen.

**Por qué no basta un rango por cita.** Un servicio tiene tres fases (`services`):
`duration_minutes` (trabajo activo: técnico + estación), `processing_minutes` (el esmalte o el
tinte actúa: cliente en la estación, **técnico libre**) y `buffer_minutes` (limpieza y
preparación). El técnico queda ocupado-libre-ocupado dentro de la misma cita, así que un solo
rango `[starts_at, ends_at)` por cita no expresa la realidad.

**Modelo [Claude]: bloques de ocupación materializados.** Al reservar, el caso de uso
`BookAppointment` genera filas en una tabla nueva:

```sql
CREATE TABLE occupancy_blocks (
    id                      BIGSERIAL PRIMARY KEY,
    tenant_id               BIGINT NOT NULL,
    appointment_service_id  BIGINT NOT NULL REFERENCES appointment_services(id) ON DELETE CASCADE,
    subject_type            VARCHAR(10) NOT NULL,          -- 'employee' | 'resource'
    subject_id              BIGINT NOT NULL,               -- employees.id o resources.id
    period                  TSTZRANGE NOT NULL,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE, -- FALSE al cancelar / no-show
    CONSTRAINT no_overlap EXCLUDE USING gist (
        subject_type WITH =, subject_id WITH =, period WITH &&
    ) WHERE (is_active)
);
-- requiere CREATE EXTENSION btree_gist;
```

- Fase activa → bloque del técnico **y** del recurso.
- Fase de procesamiento → bloque solo del recurso.
- Buffer → bloque del recurso (y del técnico si él limpia; ver pregunta abierta en §17).
- Cancelar o marcar no-show pone `is_active = FALSE`: libera el hueco sin borrar historia.
- Dos reservas simultáneas del mismo hueco: PostgreSQL rechaza la segunda con
  `exclusion_violation` (SQLSTATE `23P01`); la aplicación la traduce a "ese horario acaba de
  ocuparse" (HTTP 409).

**Cálculo de disponibilidad.** Función pura en `Scheduling/Domain` que recibe horario de la
sucursal, fechas especiales, turnos y descansos del técnico, ausencias, bloques existentes y
el servicio, y devuelve huecos. Sin Eloquent, testeable con tablas de casos. Redis cachea el
resultado por `(sucursal, día)` y se invalida con los eventos `AppointmentBooked` /
`AppointmentCancelled` / cambios de turno. La caché es una optimización: la restricción de
exclusión es la garantía.

**"Cualquier profesional":** el motor une los huecos de todos los técnicos habilitados para el
servicio (`service_technician`) y asigna al reservar con una regla determinista (el técnico
con menos carga ese día; empate → menor `id`).

**Zona horaria:** todo se guarda en `TIMESTAMPTZ` (UTC); la sucursal define su zona
(`America/Bogota` por defecto) y el cálculo de huecos se hace en la hora local de la sucursal.

## 8. Dinero

- Siempre `BIGINT` en centavos. En PHP, value object `Shared/Money` sobre enteros (o
  `brick/money`); nunca `float`. En TypeScript, `number` entero de centavos y formateo con
  `Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 })`.
- Porcentajes (comisión, IVA) en **puntos básicos** enteros (19 % = 1900) para el cálculo;
  `commission_value DECIMAL(8,4)` del diseño de BD se conserva solo como dato de entrada.
- Redondeo explícito y único: *half-up* al centavo, en un solo lugar (`Money::percentage()`).
- Repartos (propinas entre técnicos, comisiones por niveles) usan asignación por residuo
  (`allocate`) para que la suma de las partes sea exactamente el total.
- Un hook del harness rechaza `FLOAT`, `REAL`, `DOUBLE` o `DECIMAL` en columnas de dinero.

## 9. Ajustes al diseño de BD v1.0 [Claude]

1. **PostgreSQL 18** en lugar de 16. Se puede usar `uuidv7()` nativo para las columnas `uuid`
   (ordenables por tiempo, mejores para índices) en lugar de `gen_random_uuid()`.
2. **Nueva tabla `resources`** (estaciones, sillas, cabinas por sucursal: `branch_id`, `type`,
   `name`, `is_active`). Hoy las estaciones son texto libre (`station_name`), lo que impide
   reservarlas y auditarlas. `station_cleaning_logs` y `biosecurity_checklists` pasan a
   `resource_id`.
3. **Nueva tabla `occupancy_blocks`** (§7).
4. **Fuente de verdad de horarios:** `appointment_services` manda; `appointments.starts_at` y
   `ends_at` son el envolvente calculado (mínimo y máximo de sus servicios).
5. **RLS** en las 41 tablas de negocio (§6) mediante una migración helper reutilizable.
6. `customers.user_id` sin restricción de unicidad (§6).
7. **`users` pasa a ser global** (sin `tenant_id`) y se añade la tabla de membresías
   `tenant_user` (`tenant_id`, `user_id`, `is_active`, `joined_at`; único por par). Los roles
   por tenant van en las tablas de spatie con `team_id = tenant_id` (§12, §19).

## 10. Frontend

**Una sola aplicación Vite** con tres áreas por ruta y carga diferida **[Claude]**:

| Área | Ruta | Roles | Auth |
|---|---|---|---|
| Backoffice | `/app/*` | dueño, recepción, técnico (menú según permisos) | Sanctum cookie |
| Portal público | `/r/{slug}/*` | cliente y visitante | Sanctum cookie de cliente |
| Plataforma | `/admin/*` | Super Admin | Sanctum cookie, conexión de plataforma |

Una sola app para una persona sola es más barata de mantener que tres. Si el portal necesita
SEO más adelante, se extrae a una app con SSR sin tocar el backoffice.

**Stack:** React 19 + TypeScript 6.0 strict (typescript-eslint aún no admite TS 7) + Vite 8 · React Router · **TanStack Query** para estado
del servidor · Zustand solo para estado de UI local · React Hook Form + **Zod** · **Tailwind 4**
· **FullCalendar** (resource timeline, licencia premium) para la agenda · Vitest + Testing
Library · Playwright para E2E.

**Estructura:**

```
frontend/src/
├── app/                 # router, providers, layouts por área
├── design-system/       # tokens + componentes base (Button, Badge, Card, Field, Table, SidePanel…)
├── features/<módulo>/   # un directorio por módulo del backend: api/, components/, routes/, hooks/
├── lib/                 # cliente HTTP, money, fechas, permisos
└── api/generated/       # tipos y cliente generados desde OpenAPI — NUNCA se editan a mano
```

**Design system:** los tokens del mockup (`project/ds/yiyi/tokens.json`: paleta rosa / lavanda /
menta / durazno / cielo con variantes `-soft` y `-strong`, Fraunces + Plus Jakarta Sans,
espaciados, radios y sombras) se traducen 1:1 a `@theme` de Tailwind 4. Regla: ningún color,
radio o sombra literal en un componente; solo tokens. Los colores por tipo de servicio en la
agenda (manicure = rosa, spa = lavanda, pedicure = menta, cejas = durazno, facial = cielo)
salen de los tokens, no de la base de datos.

**Fidelidad al mockup:** cada pantalla se construye leyendo su artboard (`project/<Nombre>.dc.html`).
El comando `/pantalla-desde-mockup` del harness (§13) automatiza esa lectura.

**Accesibilidad:** contraste ya validado en los tokens; controles reales (`<button>`, `<label>`),
foco visible con `focus` (lavender-strong), objetivos táctiles ≥ 44 px (recepción y técnico usan
tablet).

## 11. Contrato de API, entornos e infraestructura

**Contrato:** API REST JSON bajo `/api/v1`. **Scramble** genera el OpenAPI desde el código
Laravel; `openapi-typescript` genera los tipos del frontend. El CI falla si el OpenAPI
commiteado difiere del generado. Errores con formato RFC 9457 (`application/problem+json`).

**Repositorio (monorepo):**

```
yiyi_spa/
├── backend/          # Laravel 13
├── frontend/         # React + Vite
├── docker/           # Dockerfiles y configs (nginx, php-fpm, postgres)
├── docker-compose.yml
├── docs/             # specs, ADRs, runbooks
├── swarm/            # sistema de agentes (§14)
├── .claude/          # harness (§13)
├── CLAUDE.md
└── Documentacion/    # documentos fuente originales (solo lectura)
```

**Desarrollo local (Windows):** Docker Desktop corre PostgreSQL 18, Redis y Mailpit. PHP 8.4
(`C:/xampp3/php`) y Node 24 corren en la máquina, fijados por `scripts/lib/toolchain.sh`. **Los tests usan
PostgreSQL real, nunca SQLite**: las restricciones de exclusión y RLS no existen en SQLite.

**Producción MVP:** VPS con Docker Compose: nginx + php-fpm + worker de colas (Horizon) +
scheduler + PostgreSQL 18 + Redis. Archivos (fotos clínicas, logos) en almacenamiento compatible
con S3 (Hetzner Object Storage o DigitalOcean Spaces), con URLs firmadas para las fotos
clínicas. Backups diarios de PostgreSQL fuera del VPS.

**php-fpm, no Octane, en el MVP [Claude]:** Octane reutiliza el proceso entre peticiones y el
`SET app.tenant_id` de RLS podría filtrarse de una petición a otra. Con php-fpm cada petición
empieza limpia. Si después hace falta Octane, se activa junto con un test que pruebe el
reinicio del contexto de tenant.

**CI (GitHub Actions):** en cada PR: Pint, Larastan, Pest (con servicio PostgreSQL 18),
Deptrac, ESLint, `tsc`, Vitest, verificación de OpenAPI y el gate de aislamiento de tenants.
Playwright y mutación corren en `main` y antes de cada release.

**Observabilidad:** Sentry (back y front), Telescope solo en local, logs estructurados con
`tenant_id` y `request_id` en cada línea.

## 12. Roles, permisos y cumplimiento

- **spatie/laravel-permission** con *teams* = tenant: los roles `owner`, `receptionist` y
  `technician` se asignan por membresía (`team_id = tenant_id`); `customer` y `super_admin`
  son globales (§19).
- Permisos granulares `módulo.acción` (ej. `appointments.reschedule`, `finance.view`). Las
  Policies de cada módulo los consultan; el frontend solo oculta menús, nunca es la defensa.
- El técnico solo ve **su** agenda y las fichas de **sus** clientes del día (Policy explícita).
- Historial clínico, alergias y fotos son datos sensibles (Ley 1581): columnas cifradas con
  los *casts* `encrypted` de Eloquent, acceso registrado en `audit_logs`, fotos con URL firmada
  de vida corta.
- Consentimiento explícito al registrarse y al reservar (`consent_records`); flujo ARCO en
  `Compliance`.

## 13. Harness `.claude/`

Hoy el repositorio no tiene `.claude/`. Principio rector: **el conocimiento del dominio vive en
skills que se cargan cuando hacen falta, no en un `CLAUDE.md` gigante**. El `CLAUDE.md` raíz es
corto (≈ 100 líneas): qué es el proyecto, comandos, reglas duras y un índice de skills.

```
CLAUDE.md                          # corto: qué es, comandos, reglas duras, índice de skills
.claude/
├── settings.json                  # permisos, hooks y env compartidos (se commitea)
├── settings.local.json            # overrides personales (gitignored)
├── agents/
│   ├── tenant-safety-auditor.md   # revisa un diff buscando fugas entre tenants
│   ├── scheduling-specialist.md   # motor de agenda, bloques, edge cases de horario
│   ├── money-auditor.md           # centavos, IVA, comisiones, redondeo, repartos
│   ├── laravel-module-builder.md  # construye un módulo respetando §5
│   ├── react-screen-builder.md    # construye una pantalla desde su artboard
│   └── migration-writer.md        # migraciones PG18 con tenant_id, RLS e índices
├── commands/
│   ├── nuevo-modulo.md            # scaffold completo de un módulo backend + feature frontend
│   ├── pantalla-desde-mockup.md   # lee un artboard del mockup y genera la pantalla
│   ├── revisar-tenant.md          # dispara tenant-safety-auditor sobre el diff actual
│   └── sincronizar-contrato.md    # regenera OpenAPI y tipos TS
├── skills/
│   ├── yiyi-dominio/              # glosario, estados de cita, políticas, roles, reglas de negocio
│   ├── yiyi-backend/              # anatomía de un módulo, reglas de dependencia, patrones
│   ├── yiyi-frontend/             # tokens, componentes base, patrón de pantalla y de panel lateral
│   ├── yiyi-datos/                # convenciones SQL, migraciones, RLS, índices
│   ├── yiyi-dinero/               # Money, IVA, DIAN, comisiones, propinas
│   └── yiyi-testing/              # cómo se escribe un test aquí, fixtures de dos tenants
└── hooks/
    ├── bloquear-float-dinero.sh   # PreToolUse: rechaza FLOAT/DECIMAL en columnas de dinero
    ├── exigir-tenant-id.sh        # PreToolUse: migración de tabla de negocio sin tenant_id → bloquea
    ├── proteger-generados.sh      # PreToolUse: impide editar api/generated/ a mano
    └── formatear.sh               # PostToolUse: Pint / Prettier sobre el archivo tocado
```

**Por qué hooks y no solo reglas escritas:** una regla en un Markdown depende de que el agente
la recuerde; un hook la aplica el harness siempre. Las reglas que no admiten excepción (dinero,
tenant, archivos generados) van como hooks.

**Memoria:** las decisiones de arquitectura se registran como ADRs en `docs/adr/`, no en el
`CLAUDE.md`. Las skills enlazan a los ADRs relevantes.

## 14. Swarm (`/swarm-forge`)

Se genera con el skill `swarm-forge` en `swarm/` (estado en tiempo de ejecución en `.swarm/`,
gitignored). Las decisiones de topología que ese skill pregunta quedan fijadas aquí:

- **Topología:** *six-pack* — specifier → coder → cleaner → architect → hardener → QA. Es un
  sistema de larga vida con dinero, datos de salud y aislamiento entre competidores.
- **Ejecución:** **secuencial en un solo workspace** [Usuario: una persona]. Sin worktrees por
  rol. Los roles de revisión (cleaner, architect, hardener, QA) se despachan con el agente
  `swarm-role` para que revise alguien que no escribió el código.
- **Aprobación humana** después del specifier (Sergio aprueba los escenarios antes de codificar).
- **Idioma:** roles y constitución en español; comandos y código en inglés.

| Rol | Responsabilidad | Gates (bloquean el handoff) |
|---|---|---|
| specifier | Escribe escenarios de aceptación (Pest / Playwright) que fallan | Los tests existen y fallan por la razón correcta + aprobación humana |
| coder | TDD hasta verde, nada más | Pint, Larastan nivel 8, Pest del módulo · ESLint, `tsc`, Vitest |
| cleaner | Refactor sin cambiar comportamiento | Cobertura ≥ 90 % en líneas tocadas, CRAP ≤ 6, duplicación (phpcpd / jscpd) |
| architect | Fronteras y contrato | Deptrac sin violaciones, tests de arquitectura de Pest, OpenAPI sincronizado |
| hardener | Robustez y seguridad | **Aislamiento de tenants**, mutación (Infection, MSI ≥ 80 %) en Scheduling / Money / Staff / Sales, revisión de RLS |
| QA | Verificación de punta a punta | Playwright sobre los flujos críticos |

**Flujos críticos de Playwright (crecen con las fases):** reservar desde el portal, reservar
desde recepción con "cualquier profesional", reprogramar con drag & drop, cancelar respetando
política; en Fase 2: cobrar en POS con venta cruzada, cerrar caja y liquidar comisiones.

**Gate propio del proyecto — aislamiento de tenants** (`swarm/gates/tenant-isolation.sh`):
corre una suite que crea dos tenants con datos, recorre cada ruta autenticada de `/api/v1`
como el tenant A y falla si la respuesta contiene un `uuid` o `id` del tenant B. Además
verifica que toda tabla con `tenant_id` tenga RLS activa y forzada.

## 15. Secuencia de arranque

`swarm-forge` analiza las herramientas reales del proyecto, así que no se ejecuta sobre un
repositorio vacío (generaría solo stubs). El orden es:

1. **Esqueleto** — monorepo, Laravel 13 en `backend/`, Vite + React en `frontend/`,
   `docker-compose.yml` (PG18, Redis, Mailpit), herramientas de calidad instaladas (Pint,
   Larastan, Pest, Deptrac, Infection, ESLint, Vitest, Playwright), CI mínimo en verde.
2. **Fundaciones** — `Shared/Money`, `TenantContext` + `BelongsToTenant` + RLS, rol de BD
   sin `BYPASSRLS`, tokens de Tailwind, componentes base del design system, fixture de dos
   tenants. Son la base de la que dependen todos los gates.
3. **Harness** — `CLAUDE.md`, `.claude/` completo (§13).
4. **Swarm** — `/swarm-forge` con las decisiones de §14, gates conectados a las herramientas
   del paso 1.
5. **Fase 1 por el swarm, módulo a módulo:** Platform mínimo (alta de tenants por Super Admin)
   → Identity (membresías y roles) → Business (incluye `resources`) → Catalog → Staff básico
   (§18) → Scheduling → Customers → Portal → Notifications (email).

Cada paso tendrá su propio plan de implementación.

## 16. Lo que queda a criterio del constructor

- Nombres concretos de clases, eventos y endpoints, dentro de las convenciones de §5 y §11.
- Librerías menores (fechas, iconos, toasts) mientras respeten los tokens.
- Forma exacta de los seeders y de los datos de demostración.
- Umbrales de CRAP / cobertura / mutación pueden ajustarse si un módulo CRUD los vuelve
  absurdos, dejándolo anotado en `swarm/constitution/articles/project.md`.

## 17. Preguntas abiertas

1. **FullCalendar premium** (vista de recursos por técnico) tiene licencia anual de pago. La
   alternativa gratuita es construir la vista de columnas por técnico sobre la vista
   `timeGrid` estándar, con más trabajo propio. **Se decide antes de construir la pantalla de
   Agenda**, no bloquea nada anterior.

## 18. Decisiones derivadas de la revisión [Claude]

**Mockup dentro del repositorio.** En el paso 1 de §15 se exportan los 26 artboards y
`tokens.json` del artefacto a `docs/mockup/` (`docs/mockup/<Nombre>.dc.html`,
`docs/mockup/tokens.json`, `docs/mockup/canvas.json`). Los agentes del swarm y los comandos del
harness leen de ahí, no del artefacto. Si el mockup cambia, se vuelve a exportar con un commit propio.

**Buffer configurable.** Cada sucursal tiene la política `technician_cleans_during_buffer`
(por defecto `true`). Con `true`, el buffer bloquea al técnico y al recurso; con `false`, solo al
recurso. Como la plataforma sirve a cualquier spa, esto se resuelve con configuración en vez de
fijarlo en el código.

**Alcance real de la Fase 1.** Además de lo listado en §15, la Fase 1 incluye la parte de
`Staff` que necesita la agenda: empleados, turnos, descansos, ausencias y la relación
servicio↔técnico. Comisiones, propinas y asistencia se quedan en la Fase 2.

**Multi-sucursal.** El modelo de datos y la API son por sucursal desde el día uno. La UI muestra
el selector de sucursal solo si el tenant tiene más de una; en la Fase 1 basta con una.

**Políticas sin pasarela.** En las Fases 1 y 2 la política de cancelación se aplica solo por
ventana de tiempo (por ejemplo, "no se puede cancelar en línea con menos de 4 h"). Los campos de
depósito existen pero quedan inactivos hasta la Fase 3.

**Estados que ocupan hueco.** `pending`, `confirmed` e `in_progress` ocupan hueco
(`is_active = true`). Sin depósito, la reserva en línea queda `confirmed` al instante y no
caduca. `cancelled` y `no_show` liberan el hueco. **Reprogramar mueve la misma cita**: se
regeneran sus bloques y el cambio queda en `audit_logs`. El estado `rescheduled` deja de usarse.

**Recursos físicos.** Cuando un servicio tiene `requires_resource = true`, el motor asigna
automáticamente una estación libre de su `resource_type` en la sucursal. Si es `false`, solo
bloquea al técnico. `services.max_concurrent` se elimina: la capacidad la da el número de
`resources` activos de ese tipo.

**Unicidad de emails.** Como `users` es global (§19), `email` es único en toda la tabla
(sin distinguir mayúsculas, con `citext` o un índice sobre `lower(email)`).

## 19. Decisiones del usuario tras la revisión [Usuario]

**Una cuenta, varios negocios.** Una persona tiene un solo `users` y una membresía por cada
negocio donde trabaja (`tenant_user`). Si tiene más de una, elige negocio después de iniciar
sesión y puede cambiar desde la TopBar. Su rol puede ser distinto en cada negocio (dueña en uno,
técnica en otro). El Super Admin no tiene membresías: entra por `/admin`.

**Clientes: solo se comparte el login.** La cuenta global del cliente guarda credenciales,
nombre y teléfono **propios**, que solo él edita. Cada spa tiene su `customers` independiente
(historial, notas, alergias, fotos, puntos). Ningún spa ve las fichas ni las citas que el
cliente tiene en otro. Al reservar por primera vez en un spa se crea su `customers` con una copia
de nombre y teléfono, previo consentimiento (`consent_records`). En `/r/{slug}/cuenta` el cliente
ve solo sus citas en ese spa.

**Servicios solo en secuencia.** Una cita con varios servicios los encadena uno tras otro, con
el mismo técnico o con técnicos distintos. El motor busca un hueco donde cada servicio empieza
cuando termina la fase activa y de procesamiento del anterior. Los servicios en paralelo
(mani + pedi a la vez) quedan fuera; si se añaden después, el modelo de `occupancy_blocks` ya los
soporta y solo cambia el cálculo de huecos.

**Alta de negocios por el Super Admin.** En la Fase 1 no hay registro público ni cobro de
suscripción. El Super Admin crea el tenant, su primera sucursal y el usuario dueño (que recibe
un correo para definir su contraseña). El registro propio con periodo de prueba y el asistente
de onboarding se mueven a la Fase 3, junto con las pasarelas de pago.

