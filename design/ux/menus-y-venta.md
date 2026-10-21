# Especificación de UX: menús, resultados, computadora del Galpón 7 y cuadro de avisos

> **Estado**: En diseño
> **Autor**: dueño del proyecto + ux-designer
> **Última actualización**: 2026-10-21
> **Fases del recorrido**: arranque, preparación, partida (casa, ruta, galpón), fin de la noche
> **Pantallas / flujos (identificadores para código y tareas)**: `WelcomeMenu`, `PauseMenu`,
> `NightResults`, `WarehouseComputer` (+ app `FenceMarket`), `NoticeBox`, `HudLayout`
> **Plataforma**: PC (Windows / Linux) y web (exportación "Web"). Teclado y mouse.
> **GDD relacionados**: no hay GDD (el registro de diseño es `design/game-brief.md`);
> `docs/plan-juego-steam.md` § 8 y § 9 (Etapa 1 "La huida": almacén y mercado negro)
> **ADR relacionados**: ninguno
> **Specs de UX relacionadas**: ninguna todavía (este documento es la primera). Los patrones
> nuevos del final van a `design/ux/interaction-patterns.md`.
> **Nivel de accesibilidad**: Básico (**supuesto**, ver § 0.2)
> **Plantilla**: UX Spec (`.claude/docs/templates/ux-spec.md`), adaptada: una sección por pantalla

---

## 0. Reglas comunes a todas las pantallas

### 0.1 Alcance

| Dentro | Fuera de alcance (anotado para más adelante) |
|---|---|
| Teclado y mouse en PC y en el navegador | **Mando** (no se soporta todavía). Igual, todo el diseño se navega con foco, así que sumar mando después es mapear botones, no rediseñar. |
| Navegación de menús con Tab / Shift+Tab, flechas, Enter, Esc | Pantalla táctil |
| Resolución base 1280x720 (`canvas_items` + `expand`: el área visible nunca es más chica que 1280x720 en unidades de la UI; en ventanas más anchas o altas sobra espacio, no falta) | Lector de pantalla (nivel Estándar; Godot 4.5+ trae AccessKit, verificar la API en `docs/engine-reference/godot/` cuando se suba de nivel) |
| Textos en español neutro latinoamericano, trato de **tú** (como el texto actual: "Haz clic", "Escribe la IP") | Otros idiomas (ver § 7) |
| La UI lee datos y **llama funciones / escucha señales** de `World`, `Net` y `Voice`. Nunca cambia el estado del juego por su cuenta. | Guardar los ajustes del micrófono entre sesiones (hoy no se guardan; ver § 8) |

### 0.2 Supuesto de accesibilidad: nivel Básico

`design/accessibility-requirements.md` no existe, así que no hay un nivel comprometido. **Este
documento supone nivel Básico** y lo aplica a todas las pantallas:

1. **Contraste de texto** de al menos 4,5:1 (texto normal) y 3:1 (títulos de 24 px o más).
2. **El color nunca es la única señal**: todo estado con color lleva además texto, ícono o forma
   (por ejemplo "Con golpes (x2)" escrito, "✓ Cuota cumplida" con ícono, borde grueso en lo urgente).
3. **Tamaño mínimo de texto: 15 px a 720p.** Hoy hay textos de 14 px (versión, ayuda de teclas,
   nota de la web): suben a 15.
4. **Todo usable solo con teclado**, con el foco siempre visible.
5. **Sin destellos**: nada parpadea más de 3 veces por segundo; los pulsos son de opacidad (60 % a
   100 %), nunca de blanco a negro.
6. **Subtítulos**: no aplica (no hay diálogo hablado).

Si el dueño elige otro nivel con `/ux-design accessibility`, esta sección se ajusta.

### 0.3 Paleta y tokens (para un `UiStyle` común)

Los cuatro primeros colores ya están en el juego; los demás son **propuestas** que el
art-director puede ajustar, siempre que respeten los contrastes de la tabla.

| Token | Color | Uso |
|---|---|---|
| `NIGHT` | `Color(0.05, 0.06, 0.1)` | Fondo de menús, paneles del HUD |
| `BRAND_ORANGE` | `Color(0.95, 0.5, 0.15)` | Botones etiqueta, títulos sobre fondo oscuro |
| `SIGN_YELLOW` | `Color(1, 0.85, 0.35)` | Foco del teclado, estrellas, destacados |
| `MONEY_GREEN` | `Color(0.55, 1, 0.55)` | Plata (solo sobre fondo oscuro) |
| `CARDBOARD` *(propuesto)* | `Color(0.72, 0.55, 0.36)` | Cara del panel de cartón |
| `CARDBOARD_EDGE` *(propuesto)* | `Color(0.55, 0.4, 0.25)` | Borde y canaletas del corrugado |
| `TAPE` *(propuesto)* | `Color(0.78, 0.55, 0.25)` | Cinta de embalar de los títulos |
| `INK` *(propuesto)* | `Color(0.1, 0.07, 0.04)` | Texto "de fibrón" sobre cartón, cinta y botones naranjas |
| `ALERT_RED` | `Color(1, 0.35, 0.3)` | Lo urgente (ya existe en el HUD) |
| `TEXT_LIGHT` *(propuesto)* | `Color(0.92, 0.93, 0.97)` | Texto normal sobre fondo oscuro |
| `TEXT_MUTED` | `Color(0.6, 0.62, 0.7)` | Texto secundario sobre fondo oscuro |

**Contrastes calculados (WCAG, luminancia relativa):**

| Texto | Fondo | Relación | ¿Pasa? |
|---|---|---|---|
| `INK` | `CARDBOARD` | ≈ 6,1:1 | Sí |
| `INK` | `TAPE` | ≈ 6,4:1 | Sí |
| `INK` | `BRAND_ORANGE` | ≈ 7,0:1 | Sí |
| **Blanco** | `BRAND_ORANGE` | ≈ 2,7:1 | **No**: por eso los botones naranjas llevan texto `INK`, nunca blanco |
| `BRAND_ORANGE` | `NIGHT` | ≈ 7,2:1 | Sí |
| `SIGN_YELLOW` | `NIGHT` | ≈ 13,9:1 | Sí |
| `MONEY_GREEN` | `NIGHT` | ≈ 15,3:1 | Sí |
| `MONEY_GREEN` | `CARDBOARD` | < 2:1 | **No**: sobre cartón la plata va en `INK` |
| `ALERT_RED` | `NIGHT` | ≈ 6,2:1 | Sí |
| `TEXT_MUTED` | `NIGHT` | ≈ 7,2:1 | Sí |
| Versión `Color(0.5, 0.52, 0.6)` | `NIGHT` | ≈ 5,2:1 | Sí |

Sobre el mundo 3D (HUD) el fondo cambia todo el tiempo: el texto del HUD va siempre sobre un panel
`NIGHT` con opacidad de **al menos 0,8** y conserva el contorno negro de 6 px que ya usa
`Hud._label`.

**Tamaños de texto a 720p:** cuerpo 17 px · secundario 15 px (mínimo) · botones 20 px ·
subtítulos de sección 22 px · títulos de pantalla 34 a 52 px.

### 0.4 Fuente y símbolos

- **Recomendación: seguir con la fuente por defecto de Godot** para todo. Es legible, ya tiene
  tildes, ñ, ¡ y ¿, y el estilo "cartón" lo dan la cinta, el cartón y los botones, no la letra.
  Una fuente libre (OFL) tipo esténcil de caja ("FRÁGIL") quedaría linda en los títulos, pero
  sería un archivo externo y la regla del proyecto es "sin assets externos" (ver Bloqueos/Dudas).
- **Símbolos dibujados, no escritos.** `▸`, `★`, `✓`, `⚠` y `✕` puede que no estén en la fuente
  por defecto, y en la web no hay fuentes del sistema de respaldo (saldrían cuadraditos). Se
  dibujan por código (polígonos, como la flecha del GPS) o se verifica con una captura en la
  exportación web antes de usarlos como texto. En este documento aparecen como caracteres solo
  para que se entienda el dibujo.

### 0.5 Teclado: reglas generales

- Al abrir cualquier pantalla, el foco va a un elemento definido (se indica en cada sección) y se
  ve siempre (borde `SIGN_YELLOW` de 3 px; ver patrón Botón etiqueta).
- Tab / Shift+Tab recorren en orden de lectura (de izquierda a derecha y de arriba abajo, una
  columna completa antes de la otra). Las flechas mueven entre vecinos. Enter (y Espacio) activa.
- El foco no se escapa de una pantalla modal (pausa, confirmaciones, computadora, resultados).
- **Esc** cierra o cancela la capa de arriba; nunca cierra el juego.
- Dentro de un campo de texto, ← y → mueven el cursor del texto; para salir del campo se usa Tab,
  ↑ o ↓. En un deslizador, ← y → cambian el valor.
- Clic derecho: no hace nada en ninguna pantalla. La rueda del mouse desplaza las listas.
- Objetivos de clic de al menos 44 px de alto (botones) y 32 px (íconos chicos, casillas).
- **Recomendado para el código:** armar un único `Theme` por código (botón, panel, foco, casilla,
  deslizador, barra de desplazamiento) y aplicarlo a la raíz de cada pantalla, así todos los
  controles quedan iguales sin repetir estilos.

### 0.6 Flujo general

```
Arranque ──► Menú de bienvenida ──(Crear / Unirse / Steam)──► Partida (HUD)
                 ▲                                              │  ▲
                 │                                    Esc       ▼  │ Esc / Seguir
                 │                                         Menú de pausa
                 │                                              │
                 │          ┌── en el Galpón 7, E en el escritorio
                 │          ▼
                 │   Computadora del Galpón 7 ──(Cerrar la noche)──┐
                 │          │ Esc / Levantarse ──► Partida         │
                 │                                                 ▼
                 │   Amanece / llega la policía ─────────► Resultados de la noche
                 │                                                 │
                 └──── Salir al menú (pausa o resultados) ◄────────┤
                                     Otra noche (anfitrión) ──► Partida
```

**Cambio de flujo que introduce la computadora.** Hoy la venta es automática: el camión se queda
parado adentro del galpón un segundo y el Flaco compra todo. Esa venta automática le daba al
grupo **un final instantáneo** ("llegamos = cobramos"). Con la computadora, ese final pasa a ser
una decisión: alguien vende y alguien decide cuándo cerrar. Lo que hacía el paso viejo y dónde
queda ahora:

| Lo que el paso automático le daba al jugador | Dónde queda con la computadora |
|---|---|
| Saber si llegaron a la cuota | Encabezado del Mercado del Flaco (cuota, vendido, faltan) y la confirmación de "Cerrar la noche" |
| El festejo del cobro | Cada "Vender" es un pequeño cobro (sonido de caja + "Vendido ✓"); los demás lo ven en su lista de mensajes |
| Terminar la noche sin hacer nada más | **Ya no existe**: alguien tiene que sentarse y cerrar. Si nadie lo hace y amanece, ¿se pierde todo? Queda como duda para game-designer (§ 8) |
| Que todos estén "en el final" | **Queda flojo**: solo uno ve la pantalla. Se mitiga con avisos a los demás ("Ana le vendió al Flaco: televisor ($400)"); ver § 8 |

---

## 1. Menú de bienvenida (`WelcomeMenu`)

### 1.1 Propósito y contexto

- **Necesidad del jugador:** entrar rápido a jugar con los amigos que ya están en Discord, y
  saber antes de entrar que el micrófono funciona (el juego depende de eso).
- **Meta del jugador:** crear o unirse a una partida en menos de 30 segundos desde que abre el juego.
- **Meta del juego:** que el jugador entienda la premisa (robar sin hacer ruido, el juego escucha)
  y deje el micrófono probado y calibrado.
- **Al llegar:** acaba de abrir el juego (calmo, con ganas) o volvió de una partida, a veces con
  un error ("Se cortó la conexión"). Teme: que el micrófono no ande, no saber qué botón tocar
  para jugar con amigos.
- **Sensación buscada:** "esto es una broma entre amigos, y ya estoy listo para jugar".

### 1.2 Posición, entradas y salidas

Raíz del juego. Pantalla completa, modal (no hay juego detrás). Fondo: la ciudad de noche.

| Entrada | Desde | Datos que recibe |
|---|---|---|
| Arranque del juego | — | `Net.player_name`, `Net.can_play_online()`, `Net.has_steam_peer()`, `Version.text()` |
| `Menu.open(reason)` | Salir al menú, se cortó la partida, falló la conexión | `reason` (texto del error o vacío) |

| Salida | Destino | Qué se dispara |
|---|---|---|
| Crear partida / Jugar | Partida | `Net.host_enet()` → al llegar `Net.session_started`, `Menu.close()` |
| Unirse por IP | Partida | `Net.join_enet(ip)` |
| Crear partida en Steam | Partida | `Net.host_steam()` |
| Salir (solo PC) | Cierra el juego | `get_tree().quit()` |

### 1.3 Fondo: la ciudad de noche

**Recomendación: un horizonte 2D dibujado por código**, como si fueran siluetas de cartón
recortado: cielo `NIGHT` que aclara un poco hacia el horizonte, luna, dos o tres capas de
edificios con ventanas encendidas (amarillo cartel al 40-70 %) y una deriva lateral muy lenta
(unos 6 px/s la capa de adelante, menos las de atrás). Por qué: se ve aunque el mundo 3D todavía
no exista, cuesta casi nada en la web (renderizador Compatibility), no necesita assets externos y
encaja con el estilo de cartón. Semilla de azar fija para que siempre salga igual.

*Alternativa descartada por ahora:* una vista 3D real de la ciudad con cámara lenta. Es más
vistosa pero obliga a construir la ciudad antes del menú y pesa en la web. Se puede probar más
adelante sin cambiar el resto del menú (el fondo es una capa aparte).

### 1.4 Wireframe (1280x720)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  (fondo: siluetas de la ciudad de noche, luna, ventanas encendidas)          │
│                                                                              │
│   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            ┌─ ANTES DE JUGAR ──────────┐  │
│   ▓  MUDANCEROS TRUCHOS            ▓  (cinta)   │ ▓ MICRÓFONO ▓             │  │
│   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            │ [x] Usar micrófono        │  │
│   De día hacen mudanzas. De noche... también,   │ Prueba: susurro           │  │
│   pero sin permiso. El juego escucha tu         │ {████████░░░░░░░░░░░}     │  │
│   micrófono: no despierten a Don Ramón.         │ Sensibilidad [──●─────]   │  │
│                                                 │ Habla normal: la barra    │  │
│   Tu nombre                                     │ debería marcar "normal".  │  │
│   [ Ana_______________________ ]                ├───────────────────────────┤  │
│                                                 │ ▓ CONTROLES ▓             │  │
│   [● ▸ Crear partida (solo o red local / IP)]   │ WASD moverse              │  │
│                                                 │ Shift correr · C agacharse│  │
│   [ 127.0.0.1__________ ] [ ▸ Unirse por IP ]   │ E agarrar / puertas       │  │
│                                                 │ Clic lanzar · F linterna  │  │
│   [ ▸ Crear partida en Steam (invitar amigos) ] │ Esc pausa                 │  │
│   Steam no detectado: se puede jugar por IP     ├───────────────────────────┤  │
│   o en red local (ver README).                  │ Para hablar entre ustedes │  │
│                                                 │ usen Discord (o lo que    │  │
│   ⚠ {línea de estado / error}                   │ usen): el juego solo mide │  │
│                                                 │ qué tan fuerte hablan.    │  │
│   [ ▸ Salir ]                                   └───────────────────────────┘  │
│                                                             Versión: 0.4.2   │
└──────────────────────────────────────────────────────────────────────────────┘
  ● = foco al abrir
```

**Variante web:** "▸ Jugar" en lugar de "Crear partida…"; debajo, la nota "En el navegador se
juega solo. Para jugar con amigos hay que descargar el juego." (texto exacto a revisar con el
dueño; el actual dice "abrir el proyecto en Godot", que no le sirve a un jugador). No aparecen la
fila de IP, el botón de Steam ni "Salir". El micrófono pide permiso al navegador (ver estados).

### 1.5 Zonas y componentes

| Zona | Contenido | Tamaño aprox. | ¿Desplaza? |
|---|---|---|---|
| Fondo | Horizonte 2D animado | Pantalla completa | No |
| Columna de acción (izquierda) | Título, subtítulo, nombre, botones, estado, Salir | x 64–640, alto completo | No (todo entra a 720p) |
| Columna "Antes de jugar" (derecha) | Panel de cartón: micrófono, controles, nota de Discord | 420 x ~560, x 800–1220 | No |
| Pie | Versión (abajo a la derecha) | 1 línea | No |

| Componente | Tipo | Reutiliza |
|---|---|---|
| Título "MUDANCEROS TRUCHOS" | Título cinta (52 px, puede ir en dos tiras levemente giradas, ±2°) | Patrón nuevo |
| Subtítulo | Label 18 px, `TEXT_LIGHT`, ancho máx. 560, ajuste de línea | — |
| "Tu nombre" + campo | Label 15 px + LineEdit (máx. 20 caracteres, 44 px de alto) | — |
| Crear partida / Jugar | Botón etiqueta **principal** (más grande: 52 px de alto) | Patrón nuevo |
| IP + Unirse por IP | LineEdit (placeholder "IP del anfitrión") + Botón etiqueta | Patrón nuevo |
| Crear partida en Steam | Botón etiqueta (deshabilitado con nota si no hay Steam) | Patrón nuevo |
| Línea de estado | Label 17 px, alto reservado de 2 líneas | Patrón nuevo (Línea de estado) |
| Salir | Botón etiqueta secundario, separado 24 px del resto | Patrón nuevo |
| Panel "Antes de jugar" | Panel de cartón con dos subtítulos cinta chicos | Patrón nuevo |
| Panel del micrófono | `Menu.MicPanel` restyleado (se comparte con la pausa) | Sí (`MicPanel`) |
| Ayuda de teclas | Lista con "teclas" dibujadas como tapitas (cajita con la letra) + texto | — |
| Versión | Label 15 px, `Color(0.5, 0.52, 0.6)` | — |

**Por qué este orden:** la columna izquierda es "lo que hago" (identidad y botones para entrar,
de arriba abajo, el principal primero y más grande: ley de Fitts). La derecha es "lo que reviso
una vez" (micrófono y controles). El nombre va arriba de los botones porque es lo que viaja con
la partida; como trae un valor guardado, no es obligatorio tocarlo.

### 1.6 Jerarquía de información

1. Título + premisa (qué es y que el juego escucha).
2. El botón principal para entrar.
3. Otras formas de entrar (IP, Steam).
4. Micrófono (para probar ahora o desde la pausa).
5. Controles, Discord, versión.

### 1.7 Estados

| Estado | Disparador | Qué cambia |
|---|---|---|
| Normal | Abrir el menú sin motivo | Línea de estado vacía (el espacio se reserva para que nada salte) |
| Volvió con motivo | `open(reason)` con texto | Línea de estado con "⚠ " + motivo en `ALERT_RED`. Se borra al tocar otro botón |
| Conectando / creando | Clic en Crear, Unirse o Steam | Línea de estado "Conectando a 192.168.0.5..." en `SIGN_YELLOW`; los tres botones de entrar se deshabilitan; aparece **"▸ Cancelar"** en lugar del botón usado (propuesta: llama a `Net.leave("")`) |
| Falló | `Net.session_failed(reason)` | Vuelve a Normal con el error en la línea de estado; foco al botón que se usó |
| Falta la IP | Unirse con el campo vacío | "Escribe la IP del anfitrión." y el foco va al campo de IP |
| Sin Steam (PC) | `not Net.has_steam_peer()` | Botón deshabilitado + nota de 15 px debajo (siempre visible, no solo como tooltip) |
| Web | `not Net.can_play_online()` | Variante web (§ 1.4) |
| Micrófono apagado | Casilla desmarcada | Barra vacía, texto "Micrófono apagado" |
| Sin micrófono | `not Voice.available` | Texto "No se detectó micrófono: puedes jugar igual, pero tu voz no cuenta." |
| Web: esperando permiso | El navegador todavía no dio permiso | Texto "El navegador te va a pedir permiso para usar el micrófono." (a verificar que `Voice` pueda distinguir este caso; si no, se usa "Sin micrófono") |

### 1.8 Teclado y mouse

| Entrada | Acción |
|---|---|
| Tab / Shift+Tab | Orden: Tu nombre → Crear partida → IP → Unirse por IP → Steam (si está habilitado) → Salir → Usar micrófono → Sensibilidad → (vuelve a Tu nombre) |
| ↑ / ↓ | Mueve dentro de la columna |
| → desde la columna izquierda / ← desde la derecha | Salta a la otra columna (vecinos de foco definidos a mano: Crear partida ↔ Usar micrófono) |
| Enter en "Tu nombre" | Pasa el foco a "Crear partida" (no crea la partida: evita entrar sin querer) |
| Enter en el campo de IP | Equivale a "Unirse por IP" |
| Enter / Espacio en un botón | Lo activa |
| ← / → en Sensibilidad | Cambia el valor de a 0,05 |
| Esc | Si está "Conectando", equivale a Cancelar; si no, no hace nada |
| Mouse | Hover en los botones (ver patrón); la rueda no hace nada |

Foco al abrir: **"Crear partida"** ("Jugar" en la web). Al volver con un error, el botón que se usó.

### 1.9 Datos y eventos

| Dato | Fuente | Cuándo se actualiza | Si falta |
|---|---|---|---|
| Nombre | `Net.player_name` | Al abrir | Campo vacío con placeholder "Mudancero" |
| ¿Online? / ¿Steam? | `Net.can_play_online()`, `Net.has_steam_peer()` | Al abrir | Variante web / botón Steam deshabilitado |
| Nivel de voz | `Voice.level`, `Voice.level_word()` | Cada cuadro | "No se detectó micrófono" |
| Versión | `Version.text()` | Al abrir | Se oculta |

| Acción | Lo que llama / emite | Notas |
|---|---|---|
| Crear partida / Jugar | `Net.player_name = nombre` y `Net.host_enet()` | Hoy ya es así |
| Unirse por IP | `Net.player_name = nombre` y `Net.join_enet(ip)` | Valida campo vacío antes |
| Steam | `Net.host_steam()` | Hoy no aplica el nombre: debería (el nombre de Steam podría reemplazarlo; decide el programador) |
| Cancelar *(nuevo)* | `Net.leave("")` | Corta el intento de conexión |
| Usar micrófono | `Voice.enabled = on` | Ajuste local |
| Sensibilidad | `Voice.sensitivity = v` | Ajuste local |
| Salir | `get_tree().quit()` | Solo PC |
| *(escucha)* | `Net.session_started` → cerrar; `Net.session_failed(reason)` → estado Falló | — |

### 1.10 Transiciones

| Transición | Tipo | Duración |
|---|---|---|
| Abrir el menú | Fundido desde negro | 250 ms |
| Ir a la partida | Fundido a negro, luego la partida | 250 ms |
| Deriva del fondo | Continua, lenta | — (si algún día hay "reducir movimiento", se detiene) |

### 1.11 Criterios de aceptación

- [ ] A 1280x720 no hay textos cortados ni superpuestos en PC (con y sin Steam) ni en la web.
- [ ] Ningún texto mide menos de 15 px; el texto de los botones naranjas es `INK`, no blanco.
- [ ] Solo con teclado se puede: escribir el nombre, crear partida, escribir una IP y unirse,
      prender y apagar el micrófono y mover la sensibilidad.
- [ ] El foco se ve en todo momento; al abrir está en "Crear partida" / "Jugar".
- [ ] Enter en "Tu nombre" no crea la partida.
- [ ] Unirse con la IP vacía muestra "Escribe la IP del anfitrión." y pone el foco en la IP.
- [ ] Mientras se conecta, los botones de entrar están deshabilitados y "Cancelar" corta el intento.
- [ ] El botón de Steam deshabilitado tiene su explicación visible en pantalla (no solo tooltip).
- [ ] Hablando fuerte, el medidor muestra la palabra "fuerte" además del color.
- [ ] En la web no aparecen IP, Steam ni Salir, y `▸`/`★` no salen como cuadraditos.
- [ ] Captura del menú (PC y web) guardada en `production/qa/evidence/`.

---

## 2. Menú de pausa (`PauseMenu`)

### 2.1 Propósito y contexto

- **Necesidad:** ajustar el micrófono, invitar a un amigo o irse, **sin olvidar que la noche
  sigue** (no es una pausa de verdad: los demás siguen jugando).
- **Al llegar:** en plena partida, a veces apurado (el micrófono capta de más, alguien quiere
  entrar). Teme: perder tiempo o que lo agarren mientras está en el menú.
- **Sensación buscada:** "lo arreglo en dos segundos y vuelvo".

### 2.2 Posición, entradas y salidas

Capa sobre el juego **en vivo** (el juego sigue detrás, oscurecido al 55 %). El mudancero
local queda quieto mientras está abierta (como hoy).

| Entrada | Salida |
|---|---|
| Esc durante la partida (no se abre si están los resultados o la computadora) | Esc o "▸ Seguir" → partida (mouse capturado otra vez) |
| | "▸ Salir al menú" → confirmación → menú de bienvenida |

### 2.3 Wireframe

```
┌──────────────────────── (juego oscurecido al 55 %) ─────────────────────────┐
│                  ┌──────────────────────────────────────────┐               │
│                  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ (cinta)      │
│                  │ ▓ PAUSA (la noche sigue corriendo)     ▓ │               │
│                  │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │               │
│                  │ Noche 2 · amanece en 4:12                 │ (en vivo)    │
│                  │                                           │               │
│                  │ [● ▸ Seguir                             ] │               │
│                  │ [  ▸ Invitar amigos de Steam            ] │ (solo Steam) │
│                  │ ┌─ MICRÓFONO ───────────────────────────┐ │               │
│                  │ │ [x] Usar micrófono     Prueba: normal │ │               │
│                  │ │ {██████████░░░░░░░░░░░░}              │ │               │
│                  │ │ Sensibilidad [────●────────]          │ │               │
│                  │ └───────────────────────────────────────┘ │               │
│                  │ WASD moverse · Shift correr · C agacharse │               │
│                  │ E agarrar, soltar, puertas · Clic lanzar  │               │
│                  │ F linterna · Lo pesado se carga entre dos │               │
│                  │                                           │               │
│                  │ [  ▸ Salir al menú                      ] │               │
│                  └──────────────────────────────────────────┘               │
└──────────────────────────────────────────────────────────────────────────────┘
```

Panel de cartón de 560 px de ancho, centrado, alto según contenido (máx. 600). El título en cinta
puede tener dos tamaños: "PAUSA" grande (34 px) y "(la noche sigue corriendo)" en 20 px sobre la
misma cinta.

### 2.4 Componentes y jerarquía

1. Título + reloj en vivo ("Noche 2 · amanece en 4:12"; si viene la policía, una segunda línea
   "⚠ ¡Policía en 1:30!" en `ALERT_RED` con borde, igual que en el HUD).
2. "Seguir" (foco al abrir; el botón principal).
3. "Invitar amigos de Steam" (solo si `Net.mode == Net.Mode.STEAM`; si no, no aparece).
4. Panel del micrófono (el mismo `MicPanel` del menú).
5. Ayuda de teclas (15 px, `INK`).
6. "Salir al menú", separado 24 px, al final (lejos de "Seguir" para no tocarlo sin querer).

El texto del botón "Seguir" puede quedar con el chiste actual: "▸ Seguir robando... digo, mudando".

### 2.5 Estados

| Estado | Qué cambia |
|---|---|
| Normal | Como el wireframe |
| Partida de Steam | Aparece "Invitar amigos de Steam" |
| Policía en camino | Segunda línea urgente bajo el reloj |
| Confirmar salida | Se abre la Confirmación (patrón) encima del panel: **anfitrión**: "¿Salir al menú? Eres el anfitrión: la partida se termina para todos." · **invitado**: "¿Salir al menú? Tus compañeros siguen sin ti." Botones "▸ Salir" y "▸ Volver" (foco en Volver) |
| Termina la noche con la pausa abierta | La pausa se cierra y se muestran los resultados (como hoy) |
| Se corta la partida | Se cierra todo y vuelve al menú con el motivo |

### 2.6 Teclado y eventos

| Entrada | Acción |
|---|---|
| Esc | Con la confirmación abierta: la cierra. Si no: cierra la pausa |
| Tab / ↑ ↓ | Seguir → Invitar → Usar micrófono → Sensibilidad → Salir al menú (ciclo cerrado) |
| Enter | Activa el botón con foco |

| Acción | Lo que llama | Notas |
|---|---|---|
| Seguir / Esc | `Hud._set_paused(false)` | Local, no cambia el juego |
| Invitar | `Net.invite_friends()` | — |
| Salir al menú (confirmado) | `Net.leave("")` | La confirmación es nueva |
| Micrófono | `Voice.enabled`, `Voice.sensitivity` | Igual que en el menú |

Transiciones: aparece en 120 ms (fundido del oscurecido + panel); se va en 80 ms. Rápido a
propósito: la noche sigue.

### 2.7 Criterios de aceptación

- [ ] Esc abre y cierra la pausa; con la confirmación abierta, Esc solo cierra la confirmación.
- [ ] El reloj de la pausa avanza mientras está abierta.
- [ ] "Invitar amigos de Steam" solo aparece en partidas de Steam.
- [ ] "Salir al menú" pide confirmación y el texto distingue anfitrión de invitado.
- [ ] El foco no se escapa del panel con Tab; al abrir está en "Seguir".
- [ ] Captura guardada en `production/qa/evidence/`.

---

## 3. Resultados de la noche (`NightResults`)

### 3.1 Propósito y contexto

- **Necesidad:** saber cómo les fue y **reírse de quién la embarró**. Es el momento social del
  juego: todos miran la misma pantalla y comentan por Discord.
- **Meta del jugador:** entender en 5 segundos si cobraron, cuánto, y por qué; después buscar su
  nombre en la tabla y los premios.
- **Meta del juego:** cerrar la noche con claridad y empujar a "otra noche".
- **Al llegar:** venían en tensión (manejando, o el amanecer encima). Pueden estar apretando
  teclas (E, Espacio, W) en el momento en que aparece la pantalla.
- **Sensación buscada:** "el remito de la mudanza", con sello de goma y la letra del encargado:
  oficial y ridículo a la vez.

### 3.2 Posición, entradas y salidas

Modal sobre el juego (el mundo queda detrás oscurecido al 70 %). No tiene Esc.

| Entrada | Datos |
|---|---|
| `World.night_finished(results)` | `reason`, `night`, `value`, `quota`, `stars`, `fines`, `total`, `bank`, `wakes`, `players[]`, `titles[]`, `sold[]` |

| Salida | Quién | Qué llama |
|---|---|---|
| "▸ Otra noche (Don Ramón duerme más liviano)" | Solo el anfitrión | `world.srv_next_night()` → `World.night_started` cierra la pantalla en todos |
| "▸ Salir al menú" | Todos | `Net.leave("")` (el anfitrión pasa por la Confirmación: "Los demás también vuelven al menú.") |

### 3.3 Wireframe: el remito

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ▓▓ REMITO N° 0007-0003 ▓▓  Mudanzas y Reparaciones · Galpón 7 · Noche 3      │ (cinta)
│ ┌─ RESUMEN ───────────────────────────┐ ┌─ DETALLE DE LA MERCADERÍA ───────┐ │
│ │   ╔═══════════════════════════╗     │ │ Objeto           Estado    Precio│ │
│ │   ║ ¡VENDIDO EN EL GALPÓN 7!  ║(sello)│ │ Televisor        Bien        $400│ │
│ │   ╚═══════════════════════════╝     │ │ Microondas       Con golpes  $150│ │
│ │   ★ ★ ☆   2 de 3 estrellas          │ │ Lámpara          Bien         $60│ │
│ │                                     │ │ Jarrón           Con golpes   $45│ │
│ │ Botín vendido ............. $1450   │ │ ...                              │ │
│ │ Cuota del encargo ......... $1200 ✓ │ │                                  │ │
│ │ Multas (1 se quedó) ....... -$300   │ │                                  │ │
│ │ ─────────────────────────────────   │ │                                  │ │
│ │ GANANCIA DE LA NOCHE ...... $1150   │ │                                  │ │
│ │ Plata acumulada ........... $2900   │ │ 15 cosas · rueda o flechas ↓     │ │
│ │ Don Ramón se despertó 1 vez.        │ └──────────────────────────────────┘ │
│ │ {explicación del motivo, 1-2 líneas}│                                      │
│ └─────────────────────────────────────┘                                      │
│ ┌─ PERSONAL DE LA MUDANZA ─────────────────────────────────────────────────┐ │
│ │ Mudancero          Botín   Ruido   Rotos   Lo echaron   Lo despertó      │ │
│ │ Ana (anfitriona)    $800      12       0            0             0      │ │
│ │ Beto (se quedó)     $650      48       3            1             1      │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│  PREMIOS  [El más ruidoso: Beto] [Manos de mantequilla: Beto] [Empleado ...] │
│                                                                              │
│ [● ▸ Otra noche (Don Ramón duerme más liviano)]        [ ▸ Salir al menú ]   │
└──────────────────────────────────────────────────────────────────────────────┘
```

Panel de cartón de 1200x680 a 1280x720 (márgenes de 40 y 20 px). Columnas: Resumen 520 px,
Detalle 640 px.

### 3.4 Componentes

| Componente | Tipo | Notas |
|---|---|---|
| Encabezado del remito | Título cinta | "REMITO N° 0007-<noche con 4 cifras>"; subtítulo en `INK` 17 px |
| Sello del motivo | Label 30 px dentro de un borde doble, girado -4°, color según motivo | Texto = título del motivo; el color acompaña, no informa solo |
| Estrellas | 3 estrellas dibujadas (llena / vacía con contorno) + texto "2 de 3 estrellas" | Forma + texto, no solo color |
| Renglones de plata | Etiqueta a la izquierda, monto a la derecha, puntos guía | `INK` sobre cartón; montos negativos con signo "-" |
| Marca de cuota | "✓" o "✗" + texto ("✓" junto a la cuota si llegaron; si no, la línea dice "Faltaron $X") | |
| Explicación | Label 17 px, máx. 2 líneas | Textos de § 3.6 |
| Detalle de la mercadería | Lista con desplazamiento (todas las filas, no solo 12) | Encabezado: "Lo que les compró el Flaco" o "Lo que había en el camión" según motivo |
| Tabla del personal | Grilla de 6 columnas, hasta 4 filas, 17 px | "(se quedó)" en texto + ícono de esposas/cartel; color salmón como refuerzo |
| Premios | "Etiquetas" de caja (fondo `TAPE`, texto `INK`, 17 px) en una fila que se ajusta en dos si no entra | Si no hay premios: no se muestra la fila |
| Botones | Botón etiqueta principal (anfitrión) / Línea de estado "Esperando que el anfitrión empiece otra noche..." (invitados) + "Salir al menú" | |

### 3.5 Jerarquía de información

1. **Sello del motivo + estrellas** (¿salió bien o mal?).
2. **Ganancia de la noche y plata acumulada** (¿cuánto?).
3. **Explicación del motivo** (¿por qué?), solo cuando no cobraron o hubo multas.
4. **Personal y premios** (el chiste: ¿quién la embarró?).
5. **Detalle de la mercadería** (para el curioso; se puede desplazar).

### 3.6 Variantes por motivo

| `reason` | Sello | Color del sello | Explicación |
|---|---|---|---|
| `sold` | ¡VENDIDO EN EL GALPÓN 7! | `MONEY_GREEN` oscurecido a tinta verde (sobre cartón usar `Color(0.1, 0.35, 0.12)`) | (ninguna, o "Multas por los que se quedaron atrás: -$X") |
| `cancel` | MISIÓN CANCELADA | Tinta roja `Color(0.55, 0.1, 0.08)` | "Cerraron la noche sin llegar a la cuota: el Flaco no paga nada y el encargo se cancela." |
| `police` | ¡LLEGÓ LA POLICÍA! | Tinta roja | "La policía los agarró con el camión en el barrio: se pierde todo lo cargado." |
| `dawn` | AMANECIÓ... | Tinta azul `Color(0.1, 0.18, 0.4)` | "Amaneció antes de cerrar la noche: hay que devolver todo lo cargado." |

(Las tintas oscuras sobre `CARDBOARD` superan 4,5:1; verificar con captura.) El texto de `cancel`
cambia respecto del actual porque, con la computadora, la cancelación pasa al cerrar la noche.

### 3.7 Estados

| Estado | Qué cambia |
|---|---|
| Anfitrión | Botón "Otra noche" con foco al abrir |
| Invitado | En lugar del botón: "Esperando que el anfitrión empiece otra noche..." (17 px, `INK`). Foco al abrir: la lista del Detalle (no hace nada con Enter; así un Enter suelto no te saca de la partida) |
| Sin mercadería | El Detalle muestra "El camión volvió vacío." |
| 1 jugador | La tabla del personal tiene una fila; los premios igual se dan (es parte del chiste) |
| **Guarda de entrada** | Durante los primeros 600 ms los botones no responden (se ven normales). Evita que una tecla apretada al manejar dispare "Otra noche" o "Salir" |
| El anfitrión se va | `Net.session_ended` → menú con "El anfitrión cerró la partida." |

### 3.8 Teclado

| Entrada | Acción |
|---|---|
| Tab / ← → | Detalle (lista) → Otra noche → Salir al menú (ciclo cerrado) |
| ↑ ↓ con foco en el Detalle | Desplaza la lista de a una fila |
| Enter | Activa el botón con foco (después de la guarda de 600 ms) |
| Esc | No hace nada (la noche ya terminó; no hay pausa) |
| Rueda del mouse | Desplaza el Detalle |

### 3.9 Transiciones

| Transición | Tipo | Duración |
|---|---|---|
| Aparición | Oscurecido 200 ms; el remito "se apoya" (cae 20 px y aparece) 250 ms | 450 ms en total |
| Sello | Aparece de golpe con un "tunc" de sello, 300 ms después del remito | Sin rebote largo |
| Estrellas | Se llenan una por una, 150 ms cada una | Se pueden saltar con cualquier tecla (muestran todo) |
| Cierre (otra noche) | Fundido 200 ms | — |

### 3.10 Criterios de aceptación

- [ ] Con 4 jugadores, 5 premios y 20 objetos, todo entra a 1280x720 sin cortes (el Detalle desplaza).
- [ ] Cada motivo muestra su sello, su color y su explicación de § 3.6.
- [ ] "Con golpes" y "(se quedó)" se leen como texto aunque se vea en blanco y negro.
- [ ] Solo el anfitrión ve "Otra noche"; los invitados ven el mensaje de espera.
- [ ] Ninguna tecla apretada en los primeros 600 ms activa un botón.
- [ ] Esc no hace nada en esta pantalla.
- [ ] Capturas de los cuatro motivos guardadas en `production/qa/evidence/`.

---

## 4. Computadora del Galpón 7 (`WarehouseComputer`)

### 4.1 Propósito y contexto

- **Necesidad:** convertir lo robado en plata con la sensación de "negocio trucho por internet",
  y decidir juntos (por voz) cuándo cerrar la noche.
- **Meta del jugador:** vender lo que hay en el camión, ver si llegan a la cuota y cerrar la noche
  sin equivocarse.
- **Meta del juego:** que vender sea un momento divertido y legible, que la cuota quede clarísima
  y que cerrar sin la cuota sea una decisión consciente, nunca un accidente.
- **Al llegar:** acaban de llegar manejando, aliviados pero con el reloj corriendo. Los demás
  están alrededor hablando ("¡vendé la tele primero!"). Teme: vender o cerrar sin querer, que
  amanezca mientras está en la compu.
- **Sensación buscada:** "una computadora de los 90 en una oficina trucha": cómica, lenta en
  apariencia pero rápida de usar.

### 4.2 Posición, entradas y salidas

Pantalla completa diegética (es el monitor del escritorio). Modal para el que está sentado: el
resto del HUD se oculta y el mouse se libera. **El juego sigue corriendo** (la noche avanza).
Los demás jugadores no ven esta pantalla: ven al mudancero sentado escribiendo (animación, la
define game-designer / animación, no esta spec).

| Entrada | Condición | Qué pasa |
|---|---|---|
| Mirar el escritorio | Escritorio libre | Ayuda contextual "E: usar la computadora" |
| Mirar el escritorio | Ocupado | Ayuda contextual "Ocupada: la está usando Ana" (sin acción) |
| E en el escritorio | Libre y la noche no terminó | `world.request_desk("sit")` → el servidor confirma → cámara al monitor (600 ms) → se enciende la compu |
| E al mismo tiempo que otro | El servidor elige al primero | El otro recibe el aviso "Ocupada: la está usando Ana" |

| Salida | Qué llama | Resultado |
|---|---|---|
| Esc o "Levantarse" | `world.request_desk("stand")` | Se apaga la compu, la cámara vuelve, el mudancero se para, mouse capturado, vuelve el HUD |
| Cerrar la noche (confirmado) | `world.request_close_night()` | El servidor termina la noche → `night_finished` → la compu se cierra sola y salen los Resultados |
| Amanece / llega la policía / termina la noche por otra razón | — | Igual: la compu se cierra sola y salen los Resultados |
| Se desconecta el que está sentado | — | El servidor libera el escritorio |

### 4.3 Wireframe: escritorio de la compu

```
┌──────────────────────────────────────────────────────────────────────────────┐
│█████████████████████████ (marco del monitor, 16 px) ██████████████████████████│
│█┌────────────────────────────────────────────────────────────────────────┐█│
│█│ (fondo: logo "Mudanzas y Reparaciones Galpón 7" en un azul verdoso      │█│
│█│  de sistema viejo)                                                      │█│
│█│  ┌──────┐                                                                │█│
│█│  │ $$$  │ ●  Mercado del Flaco                                           │█│
│█│  └──────┘                                                                │█│
│█│  ┌──────┐                                                                │█│
│█│  │ llave│    Tienda de herramientas                                      │█│
│█│  └──────┘    (Próximamente)                                              │█│
│█│  ┌──────┐                                                                │█│
│█│  │ nota │    Bloc de notas                                               │█│
│█│  └──────┘                                                                │█│
│█│  ┌──────┐                                                                │█│
│█│  │tacho │    Papelera                                                    │█│
│█│  └──────┘                                                                │█│
│█├────────────────────────────────────────────────────────────────────────┤█│
│█│[Inicio][Mercado del Flaco]           Mic: susurro │ 02:37 amanece en 3:10│█│
│█│                                                      [▸ Levantarse (Esc)]│█│
│█└────────────────────────────────────────────────────────────────────────┘█│
└──────────────────────────────────────────────────────────────────────────────┘
```

- **Marco del monitor** (16 px, plástico gris oscuro) para que se sienta que es una pantalla
  dentro del juego. Área útil: 1248x688.
- **Íconos:** columna a la izquierda, 64x64 con el nombre debajo (17 px, texto claro con fondo
  oscuro detrás del nombre para el contraste sobre el fondo de pantalla). Un clic abre (no doble
  clic: menos fricción, y el doble clic igual funciona porque no abre dos veces).
- **Barra de tareas** (40 px, abajo): "Inicio" (abre un menú con "Levantarse" y "Bloc de notas";
  es un guiño, no un camino obligatorio), pestañas de las ventanas abiertas, bandeja con el
  medidor de voz ("Mic: susurro" + barrita), hora del juego y cuenta regresiva, y el botón
  **"▸ Levantarse (Esc)"** siempre visible a la derecha.
- **Hora del juego:** reloj de pared falso de 23:00 a 06:00 a lo largo de la noche
  (`hora = 23:00 + (1 - time_left / NIGHT_LENGTH) * 7 h`), al lado "amanece en m:ss". Las horas
  de inicio y fin van en `Config` (son números de ajuste, aunque sean cosméticos). Si viene la
  policía, se agrega "⚠ Policía 1:30" en `ALERT_RED`.
- **Notificaciones del sistema:** como el HUD está oculto, los avisos importantes de la partida
  (`World.message` con `important`) aparecen como una ventanita arriba de la bandeja (400 px de
  ancho, mismo comportamiento que el Cuadro de avisos, § 5). Con menos de 60 s para el amanecer:
  aviso urgente "¡Amanece en 1 minuto! Cierren la noche."
- **Ventanas:** una por vez, centradas, tamaño fijo, sin arrastrar. Barra de título con el nombre
  y un "✕" que cierra la ventana (no la compu). Nada de botones decorativos que no hacen nada
  (minimizar/maximizar falsos confunden).
- **Estilo:** gris claro de sistema viejo (`Color(0.75, 0.75, 0.75)`) con texto negro (≈ 11:1),
  barra de título azul con texto blanco. Es intencionalmente distinto del cartón: es "la
  computadora", no el juego. Sin líneas de tubo (scanlines) por defecto; si el art-director las
  quiere, máximo 8 % de opacidad y nunca encima del texto de precios.

### 4.4 Wireframe: app "Mercado del Flaco" (`FenceMarket`)

```
┌─ Mercado del Flaco — www.mercadoflaco.trucho ──────────────────────────────────[✕]┐
│ MERCADO DEL FLACO   "Compramos de todo. No preguntamos nada."                     │
├──────────────────────────────────────────────────────┬────────────────────────────┤
│ EN LA CAJA DEL CAMIÓN (5)        [▸ Vender todo $955]│ ENCARGO DE ESTA NOCHE      │
│ Objeto        Estado              Te paga            │ Cuota ............. $1200  │
│ Televisor     Bien                   $400 [●▸ Vender]│ Vendido ............ $800  │
│ Microondas    Con golpes (x2)        $150 [ ▸ Vender]│ Faltan ............. $400  │
│ Bicicleta     Lo tiene Beto          $300 [   —    ]│ {█████████░░░░░} 67 %      │
│ Lámpara       Bien                    $60 [ ▸ Vender]│                            │
│ Jarrón        Con golpes (x3)         $45 [ ▸ Vender]│ VENDIDO ESTA NOCHE (3)     │
│ ...                                                  │ Heladera ......... $500 ✓  │
│                                                      │ Radio ............ $180 ✓  │
│                                                      │ Silla ............ $120 ✓  │
│                                                      │ ╔════════════════════════╗ │
│                                                      │ ║  ▸ CERRAR LA NOCHE     ║ │
│                                                      │ ╚════════════════════════╝ │
│ Las ventas no se pueden deshacer.                    │ Se cobra al cerrar.        │
│ {línea de estado: "No se pudo vender: ..."}          │                            │
└──────────────────────────────────────────────────────┴────────────────────────────┘
```

Ventana de 1100x600. Columna izquierda (lista) 680 px; derecha (resumen) 400 px.

**Por qué dos columnas:** la lista es donde se trabaja (muchos clics seguidos); el resumen es lo
que se mira para decidir. "Cerrar la noche" queda grande (fácil de encontrar) pero en la otra
columna y abajo, **lejos de "Vender todo"** y de los "Vender" de las filas, para que una racha
de clics no lo toque sin querer (Fitts al revés: lo peligroso, lejos del camino de los clics
repetidos).

### 4.5 Componentes de la app

| Componente | Tipo | Notas |
|---|---|---|
| Encabezado del sitio | Label 26 px + eslogan 17 px | Texto a cargo del guionista/dueño |
| Lista "En la caja del camión" | Lista con desplazamiento (`follow_focus` activado), orden por precio de mayor a menor al abrir | Filas de 44 px |
| Fila | Nombre (17 px) · Estado (texto) · Precio (`$%d`, alineado a la derecha) · Botón "▸ Vender" | El botón tiene foco propio; la fila no |
| Estado de la fila | "Bien" / "Con golpes (x1)" / "(x2)" / "(x3)" + ícono de abolladura | Opcional: "antes $400" tachado al lado del precio si hay golpes (explica por qué paga menos; necesita el precio sano) |
| Vender todo | Botón etiqueta con el total: "▸ Vender todo ($955)" | Deshabilitado si la lista está vacía |
| Resumen del encargo | Renglones Cuota / Vendido / Faltan + barra de progreso con porcentaje escrito | Al llegar: "Faltan" se cambia por **"✓ ¡Cuota cumplida!"** |
| Vendido esta noche | Lista simple (nombre, precio, ✓) con desplazamiento | — |
| Cerrar la noche | Botón etiqueta grande (60 px de alto, ancho completo de la columna) | Siempre abre la Confirmación |
| Notas al pie | "Las ventas no se pueden deshacer." / "Se cobra al cerrar la noche." | 15 px |
| Línea de estado | Errores de venta | Patrón Línea de estado |

### 4.6 Otras apps

| Ícono | Qué abre |
|---|---|
| Tienda de herramientas | Ícono atenuado con "(Próximamente)" debajo. Se puede enfocar y activar (así el que usa teclado también se entera): abre una ventanita "Próximamente: herramientas para las próximas noches." con "▸ Aceptar" |
| Bloc de notas | Ventana de texto (solo lectura): "Encargo de esta noche: $1200. Lo golpeado vale menos. El Flaco solo paga si llegan a la cuota. Cierren la noche antes de que amanezca (06:00)." Sirve de recordatorio de las reglas. Texto a cargo del guionista |
| Papelera | Ventanita: "La papelera está vacía. (El Flaco no deja pruebas.)" |

### 4.7 Estados

| Estado | Disparador | Qué cambia |
|---|---|---|
| Encendiendo | Se sentó | 200 ms de pantalla negra con el logo; luego el escritorio. **Sin destello blanco** |
| Escritorio | Encendida | Foco en el ícono "Mercado del Flaco" |
| Mercado: con mercadería | El camión está en el galpón y tiene cosas | Lista llena; foco en el primer "Vender" |
| Mercado: camión afuera | El camión no está en la zona del galpón | Lista vacía con "El camión no está adentro del Galpón 7. Estaciónenlo adentro para que el Flaco vea la mercadería." "Vender todo" deshabilitado. "Cerrar la noche" sigue disponible (la confirmación avisa) |
| Mercado: caja vacía | Nada en el camión y no se vendió nada | "La caja del camión está vacía." |
| Mercado: todo vendido | La lista se vació después de vender | "¡No queda nada en el camión!" y el foco pasa a "Cerrar la noche" |
| Fila: en la mano de alguien | Un jugador tiene agarrado el objeto | Estado "Lo tiene Beto en la mano"; botón deshabilitado ("—") |
| Fila: vendiendo | Clic en Vender, esperando al servidor | Botón "Vendiendo..." deshabilitado (dura lo que tarda la red) |
| Fila: vendida | El servidor confirmó | Sonido de caja; la fila muestra "Vendido ✓" 250 ms y se va; aparece en "Vendido esta noche"; los números del resumen se actualizan |
| Fila: falló | El servidor rechazó | La fila vuelve a normal; línea de estado "No se pudo vender el televisor: ya no está en el camión." |
| Llega una cosa nueva | Alguien cargó algo mientras tanto | **Se agrega al final** con la marca "(recién cargado)", no en el medio: así nada se mueve debajo del mouse. Además, los clics en la lista se ignoran 300 ms después de cualquier cambio de filas |
| Se va una cosa | Alguien sacó algo del camión | La fila desaparece; si tenía el foco, el foco pasa a la fila siguiente (o la anterior si era la última) |
| Cuota cumplida | Vendido ≥ cuota | "✓ ¡Cuota cumplida!" en el resumen (texto + ícono; el verde acompaña) |
| Confirmación de cierre | Clic en Cerrar la noche | Ver § 4.8 |
| Fin de la noche | `night_finished` | La compu se cierra sola (sin animación de levantarse) y salen los Resultados |

### 4.8 Confirmación de "Cerrar la noche"

Ventana de diálogo del sistema viejo, centrada, encima del Mercado; el resto queda bloqueado.

**Si llegan a la cuota:**
```
┌─ Cerrar la noche ─────────────────────────────────────────┐
│ ¿Cerrar la noche?                                         │
│ Vendieron $1450 de $1200. ✓ Cuota cumplida: cobran $1450. │
│ Lo que no vendieron se queda en el camión.                │
│ Ojo: Beto no está en el galpón (multa de $300).           │  (solo si aplica)
│                                                           │
│        [ ▸ Sí, cerrar la noche ]   [● ▸ Volver ]          │
└───────────────────────────────────────────────────────────┘
```

**Si no llegan a la cuota** (borde `ALERT_RED` de 3 px + ícono ⚠ dibujado):
```
╔═ ⚠ Cerrar la noche ═══════════════════════════════════════╗
║ ¿Cerrar la noche?                                         ║
║ ⚠ NO LLEGAN A LA CUOTA: el encargo se cancela y no        ║
║   cobran nada.                                            ║
║ Vendieron $800 de $1200 (faltan $400).                    ║
║ Lo que no vendieron se queda en el camión.                ║
║                                                           ║
║   [ ▸ Cerrar igual (no cobran nada) ]  [● ▸ Seguir vendiendo ] ║
╚═══════════════════════════════════════════════════════════╝
```

- El foco al abrir va siempre al botón **seguro** ("Volver" / "Seguir vendiendo"); un Enter
  apurado no cierra la noche.
- El botón de cerrar dice lo que pasa ("Cerrar igual (no cobran nada)"), no solo "Sí".
- La advertencia de la cuota va primero y en mayúsculas, con ícono y borde: no depende del color.
- Esc = "Volver". Guarda de entrada de 400 ms en los botones del diálogo.
- La línea "Ojo: X no está en el galpón" necesita saber quién se quedaría atrás (hoy se calcula
  recién al terminar la noche); si no está ese dato, la línea no aparece.

### 4.9 Teclado y mouse

| Entrada | Contexto | Acción |
|---|---|---|
| ↑ ↓ (y Tab) | Escritorio | Entre íconos; luego la barra de tareas ("Inicio", pestañas, "Levantarse") |
| Enter / clic | Ícono | Abre la app |
| ↑ ↓ | Lista del Mercado | Pasa de un "Vender" al siguiente (la lista se desplaza sola para mostrar el foco) |
| → / ← | Lista del Mercado ↔ Resumen | Salta entre columnas (de la lista a "Cerrar la noche" y vuelta) |
| Tab | Mercado | Vender todo → filas (Vender) → Cerrar la noche → ✕ de la ventana → (barra de tareas) → vuelve |
| Enter | Botón con foco | Lo activa. Enter repetido vende de arriba para abajo (rápido a propósito: vender no necesita confirmación) |
| Esc | Con un diálogo abierto | Cierra el diálogo (= Volver) |
| Esc | Sin diálogos | **Se levanta directamente** (no hay que cerrar ventana por ventana; si hay apuro, es una sola tecla). Las ventanas abiertas no se recuerdan |
| W A S D, E, F, Clic izquierdo fuera de la UI | — | No hacen nada (sentado) |
| F3 | — | No hace nada mientras está la compu |
| Rueda | Listas | Desplaza |

No se puede abrir la pausa desde la compu (Esc se usa para levantarse). Para la pausa:
levantarse y Esc otra vez. Es aceptable porque levantarse es instantáneo.

### 4.10 Datos (la UI solo lee)

| Dato | Fuente propuesta | Cuándo se actualiza | Si falta |
|---|---|---|---|
| Quién está sentado | `world.game["desk"]` (peer o 0) *(nuevo)* | Al sentarse/levantarse | Escritorio libre |
| Mercadería en la caja | `world.game["cargo"]`: lista de `[id, nombre, precio, golpes, quien_lo_tiene]` *(nuevo; hoy `_loaded` solo vive en el servidor)* | Cuando cambia (con el `rpc_game` existente) | Estado "caja vacía" |
| ¿El camión está en el galpón? | `world.game["truck_at_warehouse"]` *(nuevo)* o `CityBuilder.in_warehouse_zone()` en el cliente | Con `rpc_game` | Se asume "afuera" |
| Vendido hasta ahora (monto y lista) | `world.game["sold_value"]`, `world.game["sold"]` *(nuevos)* | Al confirmar cada venta | $0 / lista vacía |
| Cuota | `world.game["quota"]` | Al empezar la noche | — |
| Tiempo que queda / policía | `world.game["time_left"]`, `world.game["police"]` | 1 vez por segundo | Se oculta |
| Nivel de voz | `Voice.level` | Cada cuadro | "Mic: no detectado" |

### 4.11 Eventos (todo lo valida el servidor)

| Acción | Llamada propuesta | Validación en el servidor | Respuesta |
|---|---|---|---|
| Sentarse | `world.request_desk("sit")` | Escritorio libre, noche en curso, jugador cerca | `game["desk"] = peer`; a los demás, la animación |
| Levantarse | `world.request_desk("stand")` | El que pide es el que está sentado | `game["desk"] = 0` |
| Vender una cosa | `world.request_sell(entity_id)` | El que pide está sentado; la cosa está en la caja; nadie la tiene en la mano; camión en el galpón; noche en curso | Saca la cosa del mundo, suma a `sold_value` y `sold`, manda `rpc_sale_result(id, ok, motivo)` al que vendió y el mensaje normal "Ana le vendió al Flaco: televisor ($400)." a todos |
| Vender todo | `world.request_sell_all()` | Igual, cosa por cosa (las que no se puedan, se saltean y se informan) | Un solo mensaje resumen: "Ana le vendió 4 cosas al Flaco ($955)." |
| Cerrar la noche | `world.request_close_night()` | El que pide está sentado; noche en curso | `_srv_end_night("sold")` con **lo vendido** como valor (si no llega a la cuota, `payout` lo convierte en `cancel`); mensaje importante a todos: "Ana cerró la noche en la computadora." |

Esto reemplaza la venta automática de `_srv_truck_tick` (el camión parado en el galpón). Ese
cambio es de gameplay y lo tiene que aprobar game-designer (ver § 8).

**Ayuda para el primer uso:** la primera vez que el camión entra al galpón en la noche, aviso
importante "Llegaron al Galpón 7. Que uno se siente en la computadora del escritorio para
venderle al Flaco." y la flecha del GPS pasa a apuntar al escritorio.

### 4.12 Transiciones

| Transición | Tipo | Duración | Notas |
|---|---|---|---|
| Sentarse | Cámara del jugador hasta enfrentar el monitor (cámara: programación de gameplay) | 600 ms | Durante la cámara, el HUD se desvanece (150 ms) |
| Encender | Negro + logo, luego escritorio | 200 ms | Sin destellos |
| Abrir/cerrar ventana | Aparece de golpe (como un sistema viejo) | 0 ms | Ayuda a que se sienta rápido |
| Vender (fila) | "Vendido ✓" y desaparece | 250 ms | La fila de abajo sube en 120 ms |
| Levantarse | Compu se apaga (80 ms), cámara vuelve (400 ms), HUD reaparece | ~500 ms | El jugador puede moverse apenas termina la cámara |

### 4.13 Criterios de aceptación

- [ ] Con E en el escritorio libre, la compu se abre, el HUD desaparece y el mouse queda libre.
- [ ] Con otro sentado, la ayuda dice "Ocupada: la está usando <nombre>" y E no hace nada.
- [ ] Esc sin diálogos levanta al jugador de una vez; con un diálogo abierto, solo lo cierra.
- [ ] Solo con teclado se puede: abrir el Mercado, vender una cosa, vender todo, abrir la
      confirmación, volver, cerrar la noche y levantarse.
- [ ] La confirmación abre con el foco en el botón seguro; Enter apenas aparece no cierra la noche.
- [ ] Sin la cuota, la confirmación dice "NO LLEGAN A LA CUOTA: el encargo se cancela y no cobran
      nada." con ícono y borde (se entiende en blanco y negro).
- [ ] Una cosa nueva cargada mientras la compu está abierta aparece al final y no cambia de lugar
      la fila que está debajo del mouse.
- [ ] Una cosa vendida no vuelve a aparecer ni se puede vender dos veces (tampoco con doble clic).
- [ ] Si amanece con la compu abierta, la compu se cierra y salen los Resultados.
- [ ] Los demás jugadores reciben un mensaje por cada venta y otro al cerrar la noche.
- [ ] Los precios con golpes dicen "Con golpes (xN)" en texto.
- [ ] Capturas del escritorio, del Mercado (lleno, vacío, camión afuera) y de las dos
      confirmaciones en `production/qa/evidence/`.

---

## 5. Cuadro de avisos (`NoticeBox`)

### 5.1 Propósito y contexto

Hoy los avisos importantes aparecen en letras grandes en el centro y tapan justo lo que el
jugador está mirando. **Necesidad:** enterarse de lo importante sin perder de vista la casa, y
tener a mano la ayuda de qué tecla usar. **Meta del juego:** que lo urgente (policía, amanecer)
no pase desapercibido aunque no esté en el centro.

### 5.2 Posición y tamaño

Abajo a la izquierda, anclado a la esquina: margen 16 px, **400 px de ancho, máximo 140 px de
alto** a 1280x720 (crece hacia arriba según el contenido). Se eligió 400 (y no 420) para no pisar
el aviso "¡Despacio!" del velocímetro, que ocupa el centro de abajo (x 440 a 840); ese aviso se
limita también a 400 px de ancho.

### 5.3 Wireframe

```
  Normal (aviso + ayuda)                     Urgente
┌──────────────────────────────────────┐   ╔══════════════════════════════════════╗
│ ¡Salieron del barrio! Ahora, al      │   ║ ⚠ URGENTE                        +1  ║
│ Galpón 7: sigan la flecha.       +2  │   ║ ¡Alguien llamó a la policía!         ║
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ (tiempo)  │   ║ Llegan en 2:00.                      ║
├──────────────────────────────────────┤   ╠══════════════════════════════════════╣
│ [E] agarrar Televisor ($400)         │   ║ [E] agarrar Televisor ($400)         ║
└──────────────────────────────────────┘   ╚══════════════════════════════════════╝
  Solo ayuda (sin aviso)
┌──────────────────────────────────────┐
│ [W]/[S] acelerar y frenar · [A]/[D]  │
│ doblar · [Espacio] freno de mano     │
└──────────────────────────────────────┘
```

| Zona | Contenido | Alto |
|---|---|---|
| Aviso (arriba) | El aviso actual, 17 px, hasta 3 líneas; contador "+N" si hay más en la fila; línea fina que se acorta con el tiempo que le queda | 0 a 76 px |
| Ayuda contextual (abajo, fija) | `Player.prompt`, 17 px, hasta 2 líneas; las teclas dibujadas como tapitas `[E]` | 0 a 48 px |

La ayuda va **abajo y fija** para que siempre aparezca en el mismo lugar (se aprende a mirar
ahí); los avisos se apilan encima. Si no hay ni aviso ni ayuda, el cuadro no se ve.

Panel: `NIGHT` al 85 % con borde de cartón (`CARDBOARD_EDGE`, 2 px) y una solapita de cinta
arriba a la izquierda (decorativa, sin texto). Texto `TEXT_LIGHT`.

### 5.4 Reglas de los avisos

| Tipo | Qué entra | Duración | Aspecto |
|---|---|---|---|
| Normal | `World.message(text, important = true)` de hoy: "¡Salieron del barrio!", "El Flaco...", intro de la noche | `clamp(2,5 + letras × 0,04; 3; 7)` s (la fórmula de hoy) | Como el wireframe |
| Urgente *(nivel nuevo)* | Policía llamada / llegando, amanecer cerca (menos de 60 s), lo detuvieron a alguien | Mínimo 6 s | Borde `ALERT_RED` de 3 px, ícono ⚠ dibujado, rótulo "URGENTE", **un solo** pulso de opacidad al aparecer (300 ms) y un sonido de alerta |
| Mensajes chicos | `World.message(text, important = false)` ("Al camión: lámpara ($60).") | Como hoy | **No van al cuadro**: siguen en la lista de arriba a la derecha |

- **En fila, uno por vez.** Un urgente pasa adelante de todos; si interrumpe a un normal que se
  mostró menos de 1 s, ese normal vuelve al principio de la fila; si no, se descarta.
- Máximo 4 en espera: si llega un quinto normal, se descarta el normal más viejo (los urgentes
  nunca se descartan).
- Hoy la señal solo tiene `important` (sí/no). Para el nivel urgente hace falta que `World` mande
  el nivel (por ejemplo `message(text, level)` con 0 = chico, 1 = aviso, 2 = urgente). No conviene
  adivinarlo por palabras del texto.
- La cuenta regresiva de la policía sigue arriba a la izquierda, debajo del reloj, como hoy.

### 5.5 Ayuda contextual: qué pasa con la mira

Mudar "E: agarrar Televisor" del centro a la esquina aleja la ayuda de donde mira el jugador.
Para compensar: **la mira cambia de forma** (de punto a un anillo chico) cuando hay algo que se
puede usar. Así el jugador sabe que hay algo y mira el cuadro para ver qué tecla. Excepción: el
cartel "Haz clic en el juego para controlar a tu mudancero" se queda en el centro, porque mientras
está, nada funciona.

### 5.6 Criterios de aceptación

- [ ] El cuadro nunca pasa de 400x140 a 1280x720 y no tapa el velocímetro ni su aviso.
- [ ] Dos avisos seguidos se muestran uno después del otro; "+1" indica que hay otro esperando.
- [ ] Un urgente se distingue de un normal en una captura en blanco y negro (borde, ícono, rótulo).
- [ ] Nada parpadea más de una vez por aviso.
- [ ] Con la compu abierta, el cuadro está oculto y los avisos salen como notificaciones de la compu.
- [ ] Captura con aviso normal, urgente y solo ayuda en `production/qa/evidence/`.

---

## 6. Resto del HUD (nota de encaje)

Solo para que el cuadro de avisos y el estilo encajen. El HUD no usa paneles de cartón llenos
(a la noche serían un manchón claro en pantalla): usa paneles `NIGHT` al 55-85 % con borde fino
de cartón y títulos en `SIGN_YELLOW` / `BRAND_ORANGE`.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Noche 2 · amanece en 4:12      Don Ramón: Duerme profundo       Ana (anfitrión)│
│ En el camión: $800 de $1200   {████████████████████░░}          Beto          │
│ ⚠ ¡POLICÍA EN 1:30!            ┌──────────────────┐            ─────────────  │
│                                │ ▲  Galpón 7 · 820 m │          Al camión: lámpara│
│                                └──────────────────┘            ($60).        │
│                                                                              │
│                                       ·  (mira)                              │
│                                                                              │
│                                                                              │
│                                ¡Despacio! Lo de la caja se golpea            │
│ ┌ Cuadro de avisos ─────────┐            42 km/h              Tu voz: susurro │
│ │ ...                       │                                 {████░░░░░░░░} │
│ └───────────────────────────┘                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

| Zona | Qué | Cambio respecto de hoy |
|---|---|---|
| Arriba a la izquierda | Reloj, "En el camión: $X de $Y", cuenta de la policía | Al llegar a la cuota, agregar "✓" al texto (hoy solo cambia a verde). La cuenta de policía lleva "⚠" (no solo rojo) |
| Arriba al centro | "Don Ramón: Duerme profundo" + barra de sueño | **Solo se ve en el terreno de la casa** (ya decidido). La palabra del estado ya acompaña al color |
| Debajo | Flecha al Galpón 7 con metros | En el galpón, apunta al escritorio (§ 4.11) |
| Arriba a la derecha | Jugadores + lista de mensajes chicos | Mensajes a 15 px (ya está) |
| Centro abajo | Velocímetro y "¡Despacio!" | El aviso se limita a 400 px de ancho |
| **Abajo a la derecha** | Medidor de voz ("Tu voz: susurro" + barra) | **Se muda desde abajo a la izquierda** (260 px, margen 16) |
| Abajo a la izquierda | Cuadro de avisos (§ 5) | Nuevo; reemplaza al cartel grande del centro |

Con la compu abierta se oculta todo el HUD. Con la pausa o los resultados, el HUD queda detrás
oscurecido.

---

## 7. Localización

Solo español por ahora. Igual, para no cerrarse puertas:
- Ningún texto va dentro de una textura (la cinta y el cartón son fondo; el texto es un `Label`
  encima). El sello de los resultados también es un `Label`.
- Los botones y columnas tienen al menos 30 % de espacio libre sobre el texto en español (inglés
  suele ser más corto; si algún día se traduce al alemán o al portugués, revisar).
- Los textos visibles conviene juntarlos en constantes por pantalla (no sueltos en el medio del
  código) para que una traducción futura sea buscar y reemplazar.
- Sin idiomas de derecha a izquierda: no aplica.
- Los montos siguen el formato actual `$%d` (sin separador de miles), igual en todas las pantallas.

---

## 8. Preguntas abiertas

| Pregunta | Dueño | Para cuándo |
|---|---|---|
| ¿Se elimina la venta automática del galpón y se reemplaza por la compu? (cambia el final de la noche) | game-designer + dueño | Antes de programar la compu |
| Si nadie cierra la noche y amanece con el camión en el galpón, ¿se pierde todo (`dawn`) o se cierra solo con lo vendido? | game-designer | Antes de programar la compu |
| "Lo que no vendieron se queda en el camión": ¿pasa a la noche siguiente o se pierde con el reinicio de la noche? (hoy la noche nueva reinicia todo) | game-designer | Antes de escribir el texto final de la confirmación |
| ¿Cualquier jugador puede cerrar la noche, o solo el anfitrión? (la spec supone cualquiera que esté sentado) | game-designer + dueño | Antes de programar |
| ¿Lo vendido se cobra en el momento o recién al cerrar? (la spec supone "al cerrar", por eso "sin cuota no cobran nada") | game-designer | Antes de programar |
| Los demás no tienen qué hacer mientras uno vende: ¿alcanza con los mensajes de venta, o conviene algo más (por ejemplo, que otro pueda descargar al galpón)? | game-designer | Después de la primera prueba con amigos |
| ¿Se guardan los ajustes del micrófono entre sesiones? | dueño | Cuando se haga el guardado de partida |
| Texto final de la nota de la web ("hay que descargar el juego") y textos de la compu (eslogan, Bloc de notas, Papelera) | dueño / guionista | Antes de las capturas finales |

---

## 9. Patrones nuevos (para pasar a `design/ux/interaction-patterns.md`)

### 9.1 Botón etiqueta (`LabelButton`)

- **Cuándo:** toda acción en menús, pausa, resultados y ventanas de cartón. No en la compu (ahí
  van botones de sistema viejo).
- **Forma:** etiqueta de caja naranja (`BRAND_ORANGE`), esquinas apenas cortadas, triángulo `▸`
  dibujado a la izquierda, texto `INK` 20 px. Alto 44 px (principal: 52-60 px). Ancho al
  contenido o a la columna.
- **Estados:** normal · hover (naranja 10 % más claro, el triángulo se corre 4 px a la derecha) ·
  **foco** (borde exterior `SIGN_YELLOW` de 3 px + borde interior `INK` de 1 px: se ve sobre
  cualquier fondo y no depende solo del color, porque cambia el grosor) · presionado (2 px más
  abajo, naranja más oscuro) · deshabilitado (cartón gris `Color(0.5, 0.46, 0.4)`, texto `INK` al
  70 %, sin triángulo, **con su explicación en texto al lado o debajo**).
- **Teclado:** Enter y Espacio. Siempre tiene `focus_mode` activo.
- **Sonido:** "tic" de cartón al pasar el foco, "cinta" corta al activar (a definir por audio; si
  no hay, sin sonido).

### 9.2 Panel de cartón (`CardboardPanel`)

- **Cuándo:** contenedor de menús, pausa, resultados y confirmaciones fuera de la compu. **No en
  el HUD** (en el HUD, panel `NIGHT` translúcido con borde de cartón).
- **Forma:** `CARDBOARD` con textura de corrugado suave (generada por
  `tools/generate_textures.py`, nueva textura `carton`), borde `CARDBOARD_EDGE` de 2 px, sombra
  corta. Margen interno 16 px. Texto `INK`.
- **Regla de contraste:** sobre cartón, solo `INK` o tintas oscuras; nunca `MONEY_GREEN`,
  `SIGN_YELLOW` ni blanco.
- **Implementación sugerida:** `StyleBoxTexture` con márgenes de 9 partes, o `StyleBoxFlat` si
  la textura todavía no existe (que se vea bien igual sin la textura).

### 9.3 Título cinta (`TapeTitle`)

- **Cuándo:** título de cada pantalla y subtítulos de sección ("MICRÓFONO", "PERSONAL DE LA
  MUDANZA").
- **Forma:** tira de cinta de embalar (`TAPE`, textura nueva `cinta` con brillo y bordes
  dentados), texto `INK` en mayúsculas encima (`Label`, nunca dentro de la textura). Puede ir
  girada ±2°; nunca más (se lee peor). Tamaños: 52 (menú), 34 (pantallas), 20 (secciones).
- **No es interactivo.**

### 9.4 Cuadro de avisos (`NoticeBox`)

- **Cuándo:** avisos de la partida e instrucciones contextuales durante el juego.
- **Reglas:** ver § 5. Ayuda fija abajo, avisos en fila arriba, uno por vez, urgente con borde +
  ícono + rótulo + un solo pulso. Nunca en el centro de la pantalla.
- **Variante compu:** las mismas reglas como notificación arriba de la bandeja.

### 9.5 Ventana de la computadora (`RetroWindow`)

- **Cuándo:** solo dentro de la computadora del galpón (y futuras apps: tienda, etc.).
- **Forma:** gris de sistema viejo, barra de título azul con texto blanco, un único "✕" que
  funciona. Tamaño fijo, centrada, una por vez, sin arrastrar, aparece sin animación.
- **Teclado:** al abrir, foco en el primer control útil; Tab recorre la ventana y luego la barra
  de tareas; el "✕" se alcanza con Tab.
- **Esc** no cierra la ventana: levanta al jugador (ver § 4.9). Las ventanas no recuerdan estado.

### 9.6 Confirmación (`ConfirmDialog`)

- **Cuándo:** solo para lo que **no tiene vuelta atrás o afecta a todos**: cerrar la noche, salir
  al menú siendo anfitrión o en plena noche. Nunca para vender una cosa (sería fricción en algo
  que se hace muchas veces y que conviene hacer).
- **Forma:** panel de cartón (o ventana de sistema viejo dentro de la compu), título en pregunta,
  consecuencia en una frase concreta, botones que dicen lo que hacen ("Cerrar igual (no cobran
  nada)", no "Sí").
- **Variante peligrosa:** si la consecuencia es perder (sin cuota), borde `ALERT_RED` de 3 px,
  ícono ⚠ y la advertencia primero, en mayúsculas.
- **Teclado:** foco al abrir en el botón seguro; Esc = el botón seguro; guarda de entrada de 400 ms.
- **Modal:** bloquea todo lo de atrás; el foco no se escapa.

### 9.7 Patrones de apoyo

- **Línea de estado (`StatusLine`):** una línea de texto con alto reservado (no hace saltar el
  diseño) para "trabajando..." (`SIGN_YELLOW`) y errores ("⚠ " + texto en `ALERT_RED` o tinta
  roja sobre cartón). El error se borra con la siguiente acción.
- **Guarda de entrada (`InputGuard`):** las pantallas que aparecen solas durante la acción
  (resultados, confirmaciones) ignoran teclas y clics los primeros 400-600 ms.
- **Lista que no se mueve debajo del mouse (`StableList`):** en listas que cambian solas mientras
  se usan, lo nuevo se agrega al final, el foco salta a la fila vecina si la suya desaparece, y
  se ignoran los clics 300 ms después de cualquier cambio. Para acciones sin vuelta atrás, cada
  botón actúa por id del objeto, nunca por posición.
- **Tapita de tecla (`KeyCap`):** la tecla dibujada como una cajita con la letra (`[E]`), usada
  en la ayuda contextual y en la ayuda de controles.
