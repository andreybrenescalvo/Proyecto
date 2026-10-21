# Biblioteca de patrones de interacción

> **Estado**: Borrador (implementado en código, falta validarlo jugando con amigos)
> **Autor**: dueño del proyecto + ux-designer (patrones) · ui-programmer (notas de implementación)
> **Última actualización**: 2026-10-21
> **Versión**: 1.0
> **Motor**: Godot 4.7 · **Interfaz**: nodos `Control` armados por código (sin escenas `.tscn` de UI)
> **Documentos relacionados**:
> - `design/ux/menus-y-venta.md` — spec de las pantallas que usan estos patrones (§ 9 es el origen de esta lista)
> - `design/accessibility-requirements.md` — todavía no existe; se supone nivel **Básico** (spec § 0.2)
> - `scripts/ui/ui_style.gd` — paleta, `Theme` común y las piezas reutilizables
>
> **Plantilla**: Interaction Pattern Library (`.claude/docs/templates/interaction-pattern-library.md`), versión práctica

---

## Cómo usar esta biblioteca

- **Al diseñar una pantalla:** antes de inventar algo, buscá acá. En la spec escribí "usa el patrón
  Botón etiqueta" en lugar de volver a describir hover, foco y teclado.
- **Al programarla:** cada patrón dice qué pieza de código usar. Todas viven en `UiStyle`
  (`scripts/ui/ui_style.gd`), salvo las de la computadora (`ComputerScreen`) y el cuadro de avisos
  (`NoticeBox`).
- **Al cambiar un patrón:** cambia en todas las pantallas que lo usan. Revisá la lista "Dónde se usa".

## Reglas comunes

| Regla | Valor |
|---|---|
| Paleta | `UiStyle.NIGHT`, `BRAND_ORANGE`, `SIGN_YELLOW`, `MONEY_GREEN`, `CARDBOARD`, `CARDBOARD_EDGE`, `TAPE`, `INK`, `ALERT_RED`, `TEXT_LIGHT`, `TEXT_MUTED` (spec § 0.3) |
| Tintas sobre cartón | `INK_RED`, `INK_GREEN`, `INK_BLUE` (un poco más oscuras que en la spec, para pasar 3:1 con letra grande) |
| Tamaños a 720p | cuerpo 17 · secundario 15 (mínimo) · botones 20 · secciones 22 · pantallas 34 · menú 52 |
| Foco | Siempre visible: borde `SIGN_YELLOW` de 3 px por fuera (en la compu, además punteado negro por dentro) |
| Teclado | Tab / Shift+Tab en ciclo cerrado (`UiStyle.chain_focus`), flechas entre vecinos, Enter y Espacio activan, Esc cierra la capa de arriba |
| Símbolos | ▸ ★ ✓ ⚠ ✕ **no están en la fuente por defecto**: se dibujan (`UiStyle.draw_glyph`, control `UiStyle.Glyph`) |
| Montos | `$%d`, sin separador de miles |
| Textos | Español neutro, trato de tú, juntados en constantes al principio de cada script |

## Catálogo

| Patrón | Pieza de código | Dónde se usa |
|---|---|---|
| Botón etiqueta | `UiStyle.LabelButton` + `Theme` "Button" | Menú, pausa, resultados, confirmaciones de cartón |
| Panel de cartón | `UiStyle.CardboardPanel` | Menú ("Antes de jugar"), pausa, resultados, confirmaciones |
| Título cinta | `UiStyle.TapeTitle` | Título del menú, "Pausa", remito, secciones |
| Cuadro de avisos | `NoticeBox` | HUD (abajo a la izquierda); compu (notificaciones) |
| Ventana de la computadora | `ComputerScreen.RetroWindow` + `RetroButton` | Computadora del Galpón 7 |
| Confirmación | `UiStyle.ConfirmDialog` (cartón); confirmación propia de `ComputerScreen` (sistema viejo) | Salir al menú, cerrar la noche |
| Línea de estado | `UiStyle.StatusLine` | Menú (conectando / error), Mercado (venta fallida), confirmación de cierre |
| Guarda de entrada | Chequeo de tiempo en los botones | Resultados (600 ms), confirmaciones (400 ms) |
| Lista que no se mueve debajo del mouse | Lógica de filas del Mercado (`ComputerScreen._mk_*`) | Mercado del Flaco |
| Tapita de tecla | `UiStyle.key_cap`, `UiStyle.key_text` | Ayuda contextual, controles del menú y de la pausa |
| Renglón con puntos guía | `UiStyle.LeaderRow` | Remito, resumen del Mercado |

---

## Patrones

### Botón etiqueta (`LabelButton`)

- **Cuándo:** toda acción en menús, pausa, resultados y ventanas de cartón. **No** en la compu
  (ahí van botones de sistema viejo).
- **Forma:** etiqueta de caja `BRAND_ORANGE`, esquinas apenas cortadas, borde de tinta de 1 px,
  triángulo ▸ dibujado a la izquierda, texto `INK` 20 px. Alto 44 px (principal: 52 px).
- **Estados:**

| Estado | Aspecto |
|---|---|
| Normal | Naranja con borde de tinta |
| Hover | Naranja 12 % más claro; el triángulo se corre 4 px a la derecha |
| Foco | Borde exterior `SIGN_YELLOW` de 3 px (más el borde de tinta de 1 px de adentro) |
| Presionado | 2 px más abajo, naranja más oscuro |
| Deshabilitado | Cartón gris `Color(0.5, 0.46, 0.4)`, texto `INK` al 70 %, sin triángulo, **con su explicación en texto al lado o debajo** |

- **Teclado:** Enter y Espacio. Siempre `focus_mode` activo.
- **Sonido:** "click" muy bajo al recibir el foco (`Sfx.play_ui`). Falta el sonido de "cinta" al
  activar (a definir por audio).
- **Nunca:** texto blanco sobre naranja (2,7:1, no pasa).

### Panel de cartón (`CardboardPanel`)

- **Cuándo:** contenedor de menús, pausa, resultados y confirmaciones fuera de la compu.
  **No en el HUD** (ahí: panel `NIGHT` translúcido con borde de cartón, `UiStyle.night_style`).
- **Forma:** `CARDBOARD`, borde `CARDBOARD_EDGE` de 2 px, sombra corta, margen interno 16 px y
  canaletas de corrugado dibujadas (líneas verticales al 13 %). Sin textura: si un día existe la
  textura `carton`, se cambia el `StyleBoxFlat` por un `StyleBoxTexture`.
- **Contraste:** sobre cartón solo `INK` o tintas oscuras; nunca `MONEY_GREEN`, `SIGN_YELLOW` ni blanco
  como texto.

### Título cinta (`TapeTitle`)

- **Cuándo:** título de cada pantalla y subtítulos de sección ("MICRÓFONO", "PERSONAL DE LA MUDANZA").
- **Forma:** tira `TAPE` con brillo arriba y dientes en los costados (dibujados), texto `INK` en
  mayúsculas (es un `Label`, nunca parte de una textura). Puede ir girada ±2° como máximo; el giro
  usa `offset_transform_rotation` (los contenedores enderezan `rotation`).
- **Tamaños:** 52 (menú), 34 (pantallas), 28 (remito), 20 (secciones). Un texto chico opcional en la
  misma cinta ("(la noche sigue corriendo)").
- **No es interactivo.**

### Cuadro de avisos (`NoticeBox`)

- **Cuándo:** avisos de la partida y ayuda contextual durante el juego. **Nunca en el centro.**
- **Posición:** abajo a la izquierda, margen 16, 400 px de ancho; crece hacia arriba.
- **Partes:** arriba el aviso actual (hasta 4 líneas, contador "+N" si hay más en fila, línea que se
  acorta con el tiempo); abajo y fija, la ayuda (`Player.prompt`) con las teclas como tapitas.
  Si no hay ni aviso ni ayuda, no se ve.
- **Reglas de la fila:**

| Regla | Valor |
|---|---|
| Duración normal | `clamp(2,5 + letras × 0,04; 3; 7)` s |
| Duración urgente | mínimo 6 s |
| Uno por vez | Sí |
| Urgente | Pasa adelante. Si interrumpe a un normal que se vio menos de 1 s, ese normal vuelve al principio de la fila; si no, se descarta |
| Máximo en espera | 4; un quinto normal descarta al normal más viejo. Los urgentes nunca se descartan |

- **Urgente:** borde `ALERT_RED` de 3 px, ⚠ dibujado, rótulo "URGENTE", **un solo** pulso de opacidad
  (60 % → 100 % en 300 ms) y un sonido. Se distingue en blanco y negro.
- **Origen:** `World.message(text, level)`: `MSG_SMALL` va a la lista de arriba a la derecha (no al
  cuadro); `MSG_NOTICE` es normal; `MSG_URGENT` es urgente.
- **Variante compu:** las mismas reglas, sin ayuda, como notificación arriba a la derecha del monitor
  (abajo taparía "Cerrar la noche").
- **La mira acompaña:** como la ayuda ya no está en el centro, la mira pasa de punto a anillo cuando
  hay algo para usar.

### Ventana de la computadora (`RetroWindow`)

- **Cuándo:** solo dentro de la computadora del galpón (y futuras apps).
- **Forma:** gris de sistema viejo `Color(0.75, 0.75, 0.75)` con relieve, texto casi negro (≈ 11:1),
  barra de título azul con texto blanco y un único ✕ que funciona. Sin minimizar/maximizar falsos.
  Tamaño fijo, centrada, una por vez, sin arrastrar, aparece sin animación.
- **Botones (`RetroButton`):** grises con relieve; el foco es amarillo por fuera y punteado negro
  por dentro (el amarillo solo no se ve sobre el gris).
- **Teclado:** al abrir, foco en el primer control útil; Tab recorre la ventana y después la barra de
  tareas, en ciclo cerrado; el ✕ se alcanza con Tab.
- **Esc no cierra la ventana:** levanta al jugador (con un diálogo abierto, Esc solo cierra el diálogo).
  Las ventanas no recuerdan su estado.

### Confirmación (`ConfirmDialog`)

- **Cuándo:** solo para lo que no tiene vuelta atrás o afecta a todos: cerrar la noche, salir al
  menú. **Nunca** para vender una cosa.
- **Forma:** panel de cartón (o ventana de sistema viejo en la compu) sobre todo oscurecido; título en
  pregunta; la consecuencia en una frase concreta; botones que dicen lo que hacen
  ("Cerrar igual (no cobran nada)", no "Sí").
- **Variante peligrosa:** borde `ALERT_RED` de 3 px, ⚠ dibujado y la advertencia primero, en mayúsculas.
- **Teclado:** foco al abrir en el botón **seguro**; Esc = botón seguro; guarda de entrada de 400 ms.
- **Modal:** bloquea el mouse detrás; el foco no se escapa.

### Línea de estado (`StatusLine`)

- Una línea (o dos) con alto reservado: nada salta cuando aparece.
- "Trabajando..." en `SIGN_YELLOW` (sobre oscuro) o `INK` (sobre cartón o gris).
- Error con ⚠ dibujado + texto en `ALERT_RED` (oscuro) o `INK_RED` (cartón o gris). Se borra con la
  siguiente acción.

### Guarda de entrada (`InputGuard`)

- Las pantallas que aparecen solas durante la acción ignoran los botones al principio:
  resultados 600 ms, confirmaciones 400 ms. Los botones se ven normales mientras tanto.
- En los resultados, cualquier tecla saltea la animación (sello y estrellas) sin activar nada.

### Lista que no se mueve debajo del mouse (`StableList`)

- Lo nuevo se agrega **al final**, con la marca "(recién cargado)".
- Si la fila con foco desaparece, el foco salta a la siguiente (o a la anterior si era la última;
  si no queda ninguna, a "Cerrar la noche").
- Los clics del mouse en la lista se ignoran 300 ms después de cualquier cambio de filas (el teclado
  no: Enter repetido vende de arriba para abajo).
- Cada botón actúa **por id del objeto**, nunca por posición. Mientras espera al servidor, el botón
  dice "Vendiendo..." y está deshabilitado (no se vende dos veces con doble clic). Si en 2 s la cosa
  no se fue, vuelve a normal y la línea de estado explica el error.

### Tapita de tecla (`KeyCap`)

- La tecla dibujada como cajita clara con borde de tinta y la letra (`[E]`, `[W/S]`, `[Espacio]`).
- `UiStyle.key_text(texto)` arma una línea que se ajusta sola y convierte en tapitas las palabras de
  `UiStyle.KEY_WORDS` ("E:", "Clic:", "W/S"...). Así la ayuda que escribe `Player.prompt` sale con
  tapitas sin cambiar el texto.

### Renglón con puntos guía (`LeaderRow`)

- "Cuota ............ $1200": etiqueta a la izquierda, monto a la derecha, puntos en el medio.
- Se le puede agregar un símbolo al final (✓ / ✕ dibujados) para que el estado no dependa del color.

---

## Animación

| Qué | Duración | Notas |
|---|---|---|
| Menú: abrir / ir a la partida | 250 ms | Fundido desde / hacia negro |
| Menú: ciudad de fondo | continua | Deriva lenta (1,5 a 6 px/s según la capa) |
| Pausa | 120 ms aparece · 80 ms se va | Rápido: la noche sigue |
| Resultados | 200 ms oscurecido + 250 ms el remito cae 20 px; sello a los 300 ms; estrellas de a 150 ms | Cualquier tecla lo muestra todo |
| Compu: encender / apagar | 200 ms / 80 ms | Negro con el logo, sin destello blanco |
| Fila vendida | 250 ms "Vendido ✓" + 120 ms la fila de abajo sube | — |
| Aviso urgente | un pulso de 300 ms | Nunca más de un parpadeo por aviso |

No hay todavía opción de "reducir movimiento"; cuando exista, debería detener la deriva de la
ciudad y saltear las animaciones del remito.

## Sonido

| Qué | Sonido (`Sfx`) |
|---|---|
| Foco en un botón etiqueta | "click" a -18 dB |
| Aviso urgente | "clang" a -14 dB |
| Sello del remito | "thud" |
| Venta confirmada | "coin" (lo dispara el anfitrión en el escritorio) |

## Huecos y preguntas abiertas

- **Mando:** fuera de alcance; como todo se navega con foco, sumarlo es mapear botones.
- **Lector de pantalla (AccessKit):** fuera del nivel Básico.
- **Texturas `carton` y `cinta`:** hoy el cartón y la cinta son `StyleBoxFlat` + dibujo; si se agregan a
  `tools/generate_textures.py`, cambiar los estilos en `UiStyle`.
- **Sonido de "cinta" al activar un botón:** a definir por audio.
