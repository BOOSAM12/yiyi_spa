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
