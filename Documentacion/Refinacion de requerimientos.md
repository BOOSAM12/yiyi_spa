# Análisis Arquitectónico — YiYi Spa (Plataforma SaaS para Gestión de Spa/Salón)

## Contexto

El proyecto es **greenfield** (fase cero). Solo existe un documento de requerimientos detallado en `Documentación/Requerimientos Software Spa_Salón.md`. No hay código fuente, configuraciones, ni scaffolding. El objetivo de este análisis es extraer, organizar y evaluar la información del documento para definir módulos, roles, funciones y sugerencias de mejora antes de comenzar el desarrollo.

---

## 1. Roles del Sistema (RBAC)

El documento define 4 roles explícitos:

| Rol | Alcance | Descripción |
|-----|---------|-------------|
| **Super Admin** | Plataforma | Gestión multi-tenant, configuración global del SaaS, facturación de suscripciones, soporte técnico. *(No mencionado en el doc, pero necesario para un modelo SaaS)* |
| **Dueño / Admin** | Por negocio (tenant) | Acceso total: finanzas, configuración del local, gestión de personal, reportes, inventario, catálogo de servicios |
| **Recepcionista** | Por negocio (tenant) | Gestión de citas, facturación en POS, base de datos de clientes, agenda general |
| **Técnico / Estilista** | Por negocio (tenant) | Visualización de su propia agenda, notas en fichas de clientes, reporte de productos usados |
| **Cliente** | Público | Búsqueda de locales, gestión de sus propias citas, perfil personal, historial, fidelización |

### Jerarquía de permisos sugerida:
```
Super Admin > Dueño/Admin > Recepcionista > Técnico > Cliente
```

---

## 2. Módulos Definidos y sus Funciones

### M2.1 — Módulo de Autenticación e Identidad
**Funciones:**
- Registro/login de usuarios (email, redes sociales)
- Autenticación SPA con Laravel Sanctum (cookies de sesión)
- Recuperación de contraseña
- Verificación de email
- Gestión de roles y permisos (RBAC con Gates/Policies)
- Auditoría de accesos (logs de seguridad)

### M2.2 — Módulo de Perfil de Negocio y Multilocación
**Funciones:**
- Configuración de identidad de marca (nombre, logo, descripción)
- Gestión de múltiples sucursales desde un tablero único
- Horarios de apertura por día de la semana y fechas especiales
- Sincronización de inventarios y personal entre ubicaciones
- Configuración de políticas del local (cancelación, no-show, propinas)

### M2.3 — Módulo de Catálogo de Servicios
**Funciones:**
- CRUD de servicios (nombre, descripción, precio, duración estimada)
- Categorización por familias de servicios
- Tiempos de procesamiento (cliente ocupado, técnico libre)
- Tiempos de amortiguación/buffer entre citas (limpieza/preparación)
- Asignación de servicios a técnicos calificados
- Precios dinámicos por sucursal

### M2.4 — Módulo de Gestión de Citas (Motor de Reservas)
**Funciones:**
- Calendario maestro con vistas (día, semana, mes) por colores
- Algoritmo de disponibilidad en tiempo real (3 factores: local abierto + técnico en turno + sin colisiones)
- Gestión de listas de espera automáticas (notificación por cancelación)
- Reprogramación y cancelación con políticas configurables
- Drag & drop para reasignar citas
- Vista paralela de agendas de múltiples técnicos
- Reserva de múltiples servicios en una sesión
- Opción "cualquier profesional disponible"

### M2.5 — Módulo de Gestión de Personal y Nómina
**Funciones:**
- Perfiles de empleados (habilidades, horarios, descansos, vacaciones)
- Cálculo automático de comisiones (fijas, por niveles, partes y mano de obra)
- Gestión de propinas digitales (distribución y reporte fiscal)
- Asignación de servicios que cada técnico puede realizar
- Control de asistencia y puntualidad

### M2.6 — Módulo de Gestión de Clientes e Historial Clínico
**Funciones:**
- Ficha del cliente (datos personales, contacto, preferencias)
- Historial clínico con fotos de referencia (ficha ungueal, cutículas, tipo de piel)
- Registro de alergias y condiciones preexistentes
- Historial de servicios recibidos
- Historial de productos adquiridos (para recomendaciones)
- Bitácora de limpieza por estación de trabajo

### M2.7 — Módulo de Inventario y Punto de Venta (POS)
**Funciones:**
- Inventario de productos de venta minorista
- Inventario de insumos de uso profesional
- Alertas automáticas de stock crítico (basadas en consumo promedio)
- Punto de venta integrado (checkout fluido)
- Venta cruzada (productos añadidos a cuenta de servicio)
- Registro de lotes de producto y tiempos de exposición
- Checklist de bioseguridad pre-servicio

### M2.8 — Módulo Financiero y Reportes
**Funciones:**
- Registro de ingresos y gastos operativos
- Flujo de caja en tiempo real
- Balance de pérdidas y ganancias
- Cálculo de ROI de campañas de marketing y equipos
- Reportes por sucursal, por empleado, por servicio
- Dashboard financiero con métricas clave

### M2.9 — Módulo del Cliente (Portal Público)
**Funciones:**
- Búsqueda de locales por cercanía, reputación o servicios
- Visualización de información del local (fotos, profesionales, precios, políticas)
- Flujo de reserva en < 3 minutos (servicio → profesional → fecha/hora → pago)
- Pago de depósito o total mediante pasarela de pago
- Perfil personal (citas próximas, historial, facturas)
- Reprogramar/cancelar citas respetando políticas
- Sistema de puntos de lealtad

### M2.10 — Módulo de Notificaciones y Comunicaciones
**Funciones:**
- Recordatorios automáticos (24h y 2h antes de la cita)
- Notificaciones de confirmación/reprogramación
- Alertas de stock bajo
- Notificaciones de lista de espera
- Canal: email + push notifications + WhatsApp (futuro)

### M2.11 — Módulo de Fidelización y Membresías
**Funciones:**
- Sistema de puntos de lealtad
- Membresías/suscripciones mensuales (ej. "Manicura Ilimitada")
- Gamificación (retos y recompensas por hitos)
- Cupones y promociones

### M2.12 — Módulo de Seguridad y Cumplimiento
**Funciones:**
- Encriptación de datos sensibles (Eloquent encrypt)
- Consentimiento en formularios (términos y privacidad)
- Auditoría de acceso y modificaciones de datos personales
- Derechos ARCO (acceso, rectificación, cancelación, oposición)
- Logs de actividad por usuario

---

## 3. Funcionalidades de Valor Agregado (Futuras / Fase 2+)

| Funcionalidad | Descripción | Prioridad |
|--------------|-------------|-----------|
| WhatsApp Chatbot | Reservas vía WhatsApp con consulta de disponibilidad en tiempo real | Alta |
| WhatsApp Recordatorios | Reducción de no-shows hasta 80% | Alta |
| Facturación Digital por WhatsApp | Envío de recibos automáticamente | Media |
| IA — Predicción de Demanda | Análisis histórico para sugerir refuerzo de personal o promociones | Media |
| IA — Recomendaciones Personalizadas | Upselling basado en historial del cliente | Media |
| IA — Análisis de Sentimiento | Procesamiento automático de reseñas | Baja |
| Probador Virtual de Esmaltes (AR) | Previsualización de colores en uñas con cámara del dispositivo | Baja |
| Tours Virtuales 360 | Recorridos inmersivos de las instalaciones | Baja |

---

## 4. Stack Tecnológico Definido en el Documento

| Capa | Tecnología |
|------|-----------|
| Backend | Laravel (PHP) |
| Autenticación | Laravel Sanctum |
| Frontend | React (SPA) |
| Estado Frontend | React Context API o Zustand |
| Calendario UI | FullCalendar React o Bryntum Calendar |
| Base de Datos | MySQL / Amazon RDS Aurora |
| Caché | Redis |
| Colas | Laravel Queues (Redis/SQS) |
| Almacenamiento | Amazon S3 + CloudFront CDN |
| Despliegue | AWS o Laravel Vapor (serverless) |
| Multi-tenancy | Global Scopes de Eloquent con tenant_id |

---

## 5. Sugerencias y Mejoras

### 5.1 — Críticas (problemas arquitectónicos)

1. **Falta un Super Admin / Plataforma**: El documento asume modelo SaaS multi-tenant pero no define quién administra la plataforma misma. Sin este rol, no hay forma de gestionar suscripciones, onboarding de nuevos negocios, ni soporte.

2. **Estrategia de multi-tenancy sin decisión**: Se presentan dos opciones (database-per-tenant vs single-database con tenant_id) pero no se elige una. Esto es una decisión fundamental que impacta TODO el desarrollo. **Recomendación**: Single-database con `tenant_id` + Global Scopes para MVP; migrar a database-per-tenant solo si se requiere aislamiento regulatorio.

3. **No se definen pasarelas de pago**: Se menciona "pasarelas de pago integradas" sin especificar cuáles. En mercados LATAM,MercadoPago/Stripe/PlaceToPay son opciones concretas. Esto impacta el diseño del módulo financiero.

4. **No hay definición de fases (roadmap)**: El documento mezcla funcionalidades core con features de IA y AR sin priorización. Sin un roadmap por fases, el proyecto es inabarcable.

### 5.2 — Mejoras de diseño

5. **Módulo de Bioseguridad como módulo independiente**: El documento lo mezcla con inventario y clientes. Debería ser un módulo propio con checklists configurables, trazabilidad de sanitización, y alertas de cumplimiento.

6. **Definir API contracts antes de codificar**: Falta especificación de endpoints (OpenAPI/Swagger). Esto es esencial para el trabajo en paralelo frontend/backend.

7. **Separar el módulo de Reportes del módulo Financiero**: Reportes cruza múltiples dominios (citas, personal, clientes, finanzas). Debería ser un módulo transversal con datos agregados de otros módulos.

8. **Agregar módulo de Configuración General**: TimeZone, moneda, idioma, formato de facturación, reglas fiscales por país/región.

### 5.3 — Mejoras técnicas

9. **Testing strategy no definida**: No se menciona cómo se validarán las funcionalidades críticas (motor de disponibilidad, cálculo de comisiones, POS).

10. **Monitoreo y observabilidad**: Se menciona 99.9% uptime pero no se definen herramientas de monitoreo (Sentry, Datadog, Laravel Telescope).

11. **CI/CD pipeline**: No se define flujo de integración/despliegue continuo.

12. **El algoritmo de disponibilidad necesita especificación de edge cases**: ¿Qué pasa con citas que cruzan la medianoche? ¿Citas que requieren recursos físicos compartidos? ¿Buffer variable por tipo de servicio?

### 5.4 — Mejoras de producto

13. **Módulo de Marketing básico**: Campañas de email, promociones por temporada, cupones de descuento. Sin esto, la fidelización se queda corta.

14. **Dashboard con KPIs predefinidos**: Tasa de ocupación, ticket promedio, tasa de no-show, cliente recurrente vs nuevo, ingreso por técnico.

15. **Gestión de reseñas integrada**: Solicitar reseñas post-servicio y gestionar respuestas desde la plataforma.

16. **Módulo de Onboarding para nuevos negocios**: Wizard de configuración inicial que guie al dueño paso a paso (datos del local → servicios → personal → horarios → lanzamiento).

---

## 6. Roadmap Sugerido por Fases

### Fase 1 — MVP (Core)
- Autenticación y roles
- Perfil de negocio (single location)
- Catálogo de servicios
- Motor de reservas con disponibilidad
- Gestión básica de clientes
- Portal del cliente (reserva)
- Notificaciones por email

### Fase 2 — Operativo
- Gestión de personal y comisiones
- Inventario y POS
- Módulo financiero y reportes
- Historial clínico del cliente
- Múltiples sucursales

### Fase 3 — Crecimiento
- Fidelización y membresías
- WhatsApp API (recordatorios + chatbot)
- Pasarelas de pago
- Dashboard de KPIs
- Módulo de marketing

### Fase 4 — Escala (IA/AR)
- Predicción de demanda con IA
- Recomendaciones personalizadas
- Probador virtual AR
- Tours virtuales 360

---

---

## 7. Decisiones Tomadas

| Decisión | Opción elegida | Justificación |
|----------|---------------|---------------|
| **Mercado objetivo** | **Colombia** | Impacta pasarela de pago, facturación electrónica DIAN, impuestos (IVA 19%, ICA), moneda (COP) |
| **Multi-tenancy** | **Single DB con tenant_id** | Menor costo, más fácil de escalar, ideal para MVP. Usar Global Scopes de Eloquent para filtrado automático |
| **Pasarela de pago** | **MercadoPago / Wompi / PlaceToPay** | Las 3 más usadas en Colombia para PSE, tarjeta y efectivo. Evaluar cuál integrar primero en Fase 3 |
| **Facturación** | **Facturación electrónica DIAN** | Obligatoria en Colombia. Necesario diseño del módulo fiscal desde Fase 2 |

---

## 8. Consideraciones Específicas para Colombia

- **Moneda**: COP (Pesos colombianos) — sin decimales en UI
- **Impuestos**: IVA 19%, retención en la fuente según régimen
- **Facturación electrónica**: Integración con proveedor DIAN (Siigo, Alegra, o API directa)
- **Métodos de pago**: PSE (débito), tarjeta crédito/débito, efectivo (Efecty/Baloto), neobancos (Nequi, Daviplata)
- **Regulación de datos**: Ley 1581 de 2012 (protección de datos personales en Colombia)

---

## Verificación

Para validar la implementación futura:
1. Confirmar que los módulos cubren todo lo del documento de requerimientos
2. Confirmar roles correctos y completos
3. Priorizar fases del roadmap
4. Revisar plan de base de datos (tablas y relaciones por módulo)
5. Definir endpoints de API (OpenAPI spec) antes de codificar
