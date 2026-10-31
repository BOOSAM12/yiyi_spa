# Mockup de YiYi Spa

Copia de trabajo del mockup de diseño, para que el harness y los agentes del swarm puedan leerlo
sin depender de claude.ai.

- **Fuente:** [YiYi Spa — Mockup](https://claude.ai/artifact/BfxFSAxNHkZd3vS7r2vbKw)
- **Versión exportada:** `1793066531-4ab5` (exportada el 2026-10-26)
- **Design system:** `tokens.json` (copiado de `project/ds/yiyi/tokens.json` del artefacto)

## Solo lectura

Estos archivos **no se editan aquí**. Los cambios de diseño se hacen en el artefacto y después se
vuelve a exportar en un commit propio. `scripts/tests/mockup.test.sh` comprueba que la exportación
esté completa: cada artboard de `canvas.json` tiene su archivo y `tokens.json` es el design system
esperado.

## Qué hay

| Página del canvas | Rol | Artboards |
|---|---|---|
| Panel del negocio | Dueño / Admin | `Main`, `Agenda`, `Citas`, `POS`, `Clientes`, `FichaCliente`, `Fidelizacion`, `Servicios`, `Personal`, `Comisiones`, `Inventario`, `Finanzas`, `Reportes`, `Bioseguridad`, `Notificaciones`, `Configuracion` |
| Recepcionista | Recepción | `Recepcion` |
| Técnico | Técnico / Estilista | `Tecnico` |
| Portal del cliente | Cliente | `PortalLocal`, `PortalReserva`, `PortalCuenta` |
| Super Admin | Plataforma | `SuperAdmin` |
| Piezas compartidas | Todos | `TopBar`, `NavNegocio`, `NavRecepcion`, `PanelNuevaCita` |

`canvas.json` es el índice del canvas: el título de cada artboard, su página y su tamaño.

## Cómo leer un artboard

Cada `*.dc.html` es un componente del editor de diseño. Lo que importa para construir la pantalla:

- el marcado dentro de `<x-dc>` (estructura, textos y estilos en línea);
- los estilos de `<helmet><style>` (clases compartidas como `.card`, `.btn`, `.badge`);
- los datos de ejemplo de `renderVals()` en el `<script type="text/x-dc">`.

`<script src="./support.js">`, `<dc-import>`, `<sc-for>` y `<sc-if>` son propios del editor de
diseño y **no** se usan en el producto. En React se convierten en componentes, `map()` y
condicionales. Los colores literales del mockup corresponden a los tokens de `tokens.json`. En el
frontend siempre se usa el token, nunca el valor hexadecimal.
