# YiYi Spa

Plataforma SaaS multi-tenant para administrar spas y salones de uñas en Colombia: agenda, citas,
punto de venta, clientes e historial clínico, personal, inventario, finanzas, bioseguridad,
fidelización y un portal público de reservas.

- Diseño de arquitectura: [docs/superpowers/specs/2026-10-26-yiyi-spa-arquitectura-design.md](docs/superpowers/specs/2026-10-26-yiyi-spa-arquitectura-design.md)
- Documentos fuente (solo lectura): [Documentacion/](Documentacion/)

## Requisitos

| Herramienta | Versión | Nota |
|---|---|---|
| PHP | 8.4 | En Windows se usa `C:/xampp3/php/php.exe`; el `php` del PATH no se toca. Extensiones: `pdo_pgsql`, `intl`, `mbstring`. |
| Composer | 2.x | Se ejecuta con el PHP del proyecto a través de `scripts/lib/toolchain.sh`. |
| Node | 24 o superior | |
| pnpm | 11 o superior | |
| Docker Desktop | con Compose v2 | PostgreSQL 18, Redis y Mailpit para desarrollo. |

Para cargar el PHP y el Composer del proyecto en la terminal (Git Bash):

```bash
source scripts/lib/toolchain.sh
```

## Cómo arrancar

Todo en Git Bash, desde la raíz del repositorio.

1. Levantar los servicios de desarrollo (PostgreSQL 18, Redis y Mailpit):

   ```bash
   docker compose up -d --wait
   ```

2. Preparar el backend:

   ```bash
   source scripts/lib/toolchain.sh
   cd backend && composer install && cp .env.example .env && "$PHP" artisan key:generate && "$PHP" artisan migrate
   ```

3. Levantar la API (queda en `http://127.0.0.1:8000`):

   ```bash
   cd backend && "$PHP" artisan serve --port=8000
   ```

4. En otra terminal, el frontend:

   ```bash
   cd frontend && pnpm install && pnpm dev
   ```

5. Abrir `http://localhost:5173`. Vite reenvía `/api`, `/sanctum` y `/up` a la API, así que el
   navegador ve un solo origen.

### Puertos

| Servicio | Puerto en el host | Variable para cambiarlo |
|---|---|---|
| PostgreSQL | `5418` | `YIYI_PG_PORT` |
| Redis | `6380` | `YIYI_REDIS_PORT` |
| Mailpit SMTP | `1026` | `YIYI_MAIL_PORT` |
| Mailpit (bandeja web) | `8026` → `http://127.0.0.1:8026` | `YIYI_MAILPIT_UI_PORT` |

Para cambiarlos, copia `.env.docker.example` a `.env` en la raíz. Si cambias PostgreSQL, Redis o
Mailpit, ajusta también `DB_PORT`, `REDIS_PORT` y `MAIL_PORT` en `backend/.env`.

Las bases son `yiyi` (desarrollo) y `yiyi_testing` (tests). Los tests nunca tocan `yiyi`.

## Antes de commitear

```bash
bash scripts/qa.sh
```

Corre lo mismo que el CI: toolchain, mockup, backend (`composer qa`) y frontend (`pnpm qa`). Con
`--e2e` añade los tests de Playwright. Necesita los servicios de Docker levantados.
