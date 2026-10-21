# Plan de juego para Steam

Resumen de la conversación sobre crear un juego con Claude (Opus 5.5) y publicarlo en Steam.

---

## 1. ¿Se puede hacer un juego con Claude y sacarlo en Steam?

**Sí.** Claude puede programar el juego, pero hay partes que te tocan a ti.

### Lo que hace Claude
- Programar el juego completo: mecánicas, menús, guardado, física, IA de enemigos.
- Recomendar motor: **Godot** (gratis, fácil de manejar desde código). Alternativas: Unity, o un juego web empaquetado con Electron/Tauri.
- Corregir errores, mejorar rendimiento y preparar los ejecutables (Windows/Mac/Linux).
- Integrar Steamworks: logros, guardado en la nube, tablas de puntaje.
- Redactar los textos de la página de la tienda.

### Lo que te toca a ti
1. **Crear la cuenta de Steamworks** y pagar el **Steam Direct: US$100 por juego** (se recupera cuando el juego pasa de US$1.000 en ventas brutas).
2. **Registrar datos fiscales y bancarios** (formulario de impuestos y cuenta para cobrar).
3. **Conseguir arte, música y sonidos** (propios, comprados, gratuitos o generados con IA).
4. **Declarar el contenido hecho con IA** en el formulario de Steam (sobre todo lo que el jugador ve u oye). Revisar las reglas vigentes al publicar.
5. **Pasar la revisión de Valve:** primero la página de la tienda y después el build. La página debe estar visible como "Próximamente" al menos 2 semanas antes del lanzamiento.

### Consejos
- Empezar con algo **pequeño y terminable**.
- **Que otras personas lo prueben**: solo así se sabe si es divertido.
- **Abrir la página "Próximamente" temprano** para juntar wishlists: es lo que más influye en las ventas al lanzar.

---

## 2. Niveles de esfuerzo de Claude Code

No existe un nivel "ultracode". Los niveles son: **low, medium, high, xhigh, max**.

- **high**: sirve para casi todo el desarrollo.
- **xhigh / max**: para lo difícil (organizar el proyecto, sistemas complejos, errores que no salen).
- **low / medium**: cambios chicos y ajustes rápidos.

Más esfuerzo da mejor resultado en problemas difíciles, pero tarda más y gasta más del límite de uso. Se cambia desde el selector de modelo y esfuerzo de la app.

---

## 3. Estilo gráfico de referencia

Referencias: *Schedule I* y *Gamble With Your Friends*.

- **3D low-poly**, colores planos o texturas simples.
- **Primera persona** con humor.
- **Arte barato o gratis**: Kenney y Quaternius (gratis), Synty (de pago).
- *Schedule I* lo hizo una sola persona, así que es un estilo alcanzable.

---

## 4. ¿Se puede ganar dinero con un juego gratis en Steam?

Sí, pero es más difícil que vender el juego.

### Formas de ganar dinero
1. **Compras dentro del juego** (skins, ropa, decoraciones, emotes).
2. **DLC de pago** (mapas, modos, personajes).
3. **"Supporter pack"** para quien quiera apoyar.
4. **Donaciones fuera de Steam** (Patreon, Ko-fi).
5. **Juego gratis o demo como vitrina** para después vender una versión completa o una secuela.

No contar con publicidad estilo celular: Steam no funciona con anuncios dentro del juego.

### Datos importantes
- **Valve se queda con el 30 %** de ventas y compras dentro del juego.
- **Los US$100 de Steam Direct se pagan igual** aunque el juego sea gratis.
- En juegos gratis normalmente **paga menos del 5 % de los jugadores**: hace falta mucha gente jugando.

### Recomendación
Para un primer juego indie suele rendir más **un juego de pago barato (US$5–10) con demo gratis**. Lo gratis con compras adentro tiene más sentido en un juego cooperativo, porque es más fácil invitar a amigos.

---

## 5. Perfil del juego deseado

Respuestas del cuestionario:

| Aspecto | Elección |
|---|---|
| Relación entre jugadores | **Cooperativo** |
| Lo que divierte | **Caos y física ridícula**, **apostar/mentir/engañar**, **construir y progresar juntos** |
| Jugadores por partida | **2 a 4** |
| Duración | **Partidas largas con progreso guardado** |

**Técnica:** Godot + lobbies de Steam (GodotSteam). Un jugador hace de anfitrión y los demás se conectan a él: **no hace falta pagar servidores.**

---

## 6. Ideas de juego (versiones mejoradas)

### Idea 1: Saqueadores de islas malditas
Cooperativo en un barco destartalado, saqueando islas.

- **Tesoros malditos:** valen mucho más, pero al subirlos al barco activan maldiciones (gravedad loca, controles invertidos, barco que hace agua, un amigo convertido en esqueleto). La apuesta es cuántas maldiciones aguantar antes de volver.
- **Barco manejado entre todos:** uno pilotea, otro saca agua, otro repara, otro amarra el botín.
- **La marea sube cada noche** y la isla se hunde de a poco.
- **Progreso por temporadas:** hay que cumplir la cuota de oro del capitán fantasma o se pierde el barco.

### Idea 2: Guerra de bandas
Cada jugador tiene su propia banda criminal y compite por el control de la ciudad.

- Ciudad con tiendas, joyerías, bancos, etc.
- Se puede robar, estafar, vender piezas en el mercado negro y cometer muchos otros delitos para ganar **respeto y territorio**.
- Gana quien controle más zona frente a los demás jugadores.

**Observaciones:**
- Es **competitivo**, no cooperativo. Se puede mezclar con **alianzas temporales y traiciones**.
- Es la **más ambiciosa**: ciudad, policía con IA, territorio, mercado negro, muchos delitos. Como primer juego puede tomar años.
- Si se hace, por etapas: un barrio chico, 3 delitos (tienda → joyería → banco), zonas capturables y nivel de "calor" policial.
- **Recomendación: guardarla como segundo juego.**

### Idea 3: Mineros endeudados ⭐ (recomendada)
Cooperativo: le deben una fortuna a un prestamista turbio y bajan a una mina inestable para pagar.

**Dinamita**
- El jugador elige cuánta carga poner: **más dinamita = más mineral, pero mayor % de derrumbe**.
- Cada zona tiene **estabilidad** que se nota sin números: crujidos, polvo, grietas.
- Se pueden colocar **puntales** para bajar el riesgo (cuestan plata y tiempo).

**Profundidad = riesgo y recompensa**
- Niveles: carbón → hierro → plata → oro → gemas → algo raro en el fondo.
- Más abajo hay más peligros: gas, inundaciones, derrumbes en cadena.

**El carrito (obliga a cooperar)**
- Unos cargan abajo y otro maneja el **montacargas** arriba. Si se distrae, el carrito se descarrila y todo vuela con física.
- Si alguien queda **atrapado en un derrumbe**, los demás pueden excavar para rescatarlo antes de que se le acabe el aire.

**Deuda y apuestas**
- El prestamista cobra cada semana del juego; si no pagan, pierden equipo o el campamento.
- El **precio del mineral fluctúa**: vender ahora o guardar.
- El prestamista ofrece **"doble o nada"** sobre la deuda.

**Progreso entre sesiones:** mejor dinamita, lámparas, puntales, ascensor más rápido, campamento más grande.

---

## 7. Próximos pasos

1. **Empezar con la idea 3** (tamaño realista y lo aprendido sirve para la idea 2).
2. **Primer prototipo:**
   - 2 jugadores conectados por Steam.
   - Un pozo de mina.
   - Dinamita con probabilidad de derrumbe.
   - Un carrito que sube mineral.
3. Probar si es divertido y luego iterar.
4. Pendiente: elegir la carpeta del PC donde se guardará el proyecto de Godot.

---

## 8. Nueva dirección: Mudanceros Truchos (nombre provisorio)

El prototipo de los mineros no convenció: es un juego de "trabajar para pagar" y los momentos graciosos
tardan en llegar. El objetivo ahora no es que el juego dure años, sino que **pegue** con amigos, como
*Schedule I*, *Lethal Company*, *R.E.P.O.* o *Peak*.

### Qué tienen en común los juegos que pegan
- **Se explican en una frase** y se entienden con 10 segundos de clip.
- **Chat de voz por cercanía:** la mitad de la gracia la ponen los amigos.
- **Fallar da risa, no rabia.** El fracaso es lo que se sube a TikTok.
- **Barato (US$5–8) y partidas cortas** (10–20 minutos).
- **Un amigo convence a los otros tres.**

### La idea
Una empresa de mudanzas que **de día hace mudanzas de verdad** y usa ese trabajo para ver las casas por dentro.
**De noche vuelve a esas casas a robarlas mientras el dueño duerme**, y el juego escucha el micrófono de los jugadores.

| | Mañana | Noche |
|---|---|---|
| Qué hacen | Mudanza legal | Robo en silencio |
| Lo divertido | Caos físico, muebles volando | Susurrar, aguantar la risa, no despertar al dueño |
| Para qué sirve | Plata limpia y **ver la casa por dentro** (dónde está la caja fuerte, si hay perro, cómo duerme el dueño) | Plata sucia (vale mucho más) |

### Un día de juego
1. **Mañana:** llega un pedido de mudanza. Se cargan los muebles y se llevan a la casa nueva. El cliente
   revisa los daños y descuenta del pago. Mientras tanto, los jugadores miran qué hay de valor.
2. **Noche:** vuelven a la casa del cliente. Si hablan fuerte, se ríen o rompen algo, el dueño se mueve
   en la cama; al tercer aviso se despierta. Lo robado se carga en el mismo camión.
3. **Base:** se vende lo robado y se compran mejoras (camión más silencioso, guantes, linternas).

### Sospecha de la policía
Una barra que sube cada vez que roban a un cliente propio. Si llega al máximo, los arrestan y pierden.
Así hay que decidir en cada pedido: **¿este cliente lo robamos o solo le hacemos la mudanza?**

### Objetivo final
Juntar plata hasta que llegue **el pedido soñado: un millonario que se muda a su mansión** (bóveda,
guardias, perros). Hacen la mudanza de día, la roban de noche y **se jubilan**: termina el juego.
Una campaña completa debería durar unas 4–8 horas.

- **Progreso de casas:** departamento chico → casa con escaleras → casa con perro → departamento con
  vecinos de pared delgada → **la mansión**.
- **Para volver a jugar:** modo difícil (sueño liviano), casas y clientes al azar, récords de
  "botín sin despertar a nadie".

### Primer prototipo (orden de trabajo)
Empezar solo por **la noche**, que es el gancho de los clips:
1. ✅ Una casa, un dueño dormido con IA simple: dormido → inquieto → despierto → persiguiendo.
2. ✅ Detección del volumen del micrófono (y ruido de objetos que caen o chocan).
3. ✅ Objetos con peso y valor que se cargan al camión.
4. ⏳ Probarlo con amigos. Si se ríen la primera noche, se agrega la mudanza de día.

Del prototipo de los mineros se reaprovechó el multijugador, la física de objetos y la interfaz.
El prototipo de la noche ya está en el repositorio (ver el README): la casa de Don Ramón, el
micrófono, las puertas que chillan, lo pesado entre dos, la policía y los "premios" de cada noche.
La voz entre jugadores todavía va por Discord; la voz por proximidad dentro del juego es el
siguiente paso grande.

Segunda vuelta (después de la primera prueba): se arreglaron las puertas (se veían abiertas pero
no dejaban pasar), el camión se estacionó en la calle (cerca de la casa el motor lo despertaría)
y se pasó del estilo de cajas de colores a texturas con relieve, con referencia en las casas de
*Thief Simulator 2*. Cada noche la casa tiene otra fachada, techo, pinturas y pisos, y el barrio
tiene casas vecinas distintas.

---

## 9. Hoja de ruta después de la segunda prueba

Lo que se pidió después de jugarlo: personas con forma humana y animadas (con sombras que se
muevan), un camión de verdad, huir manejando, un almacén secreto con mercado negro, un mapa más
grande con barrios de distinto nivel y mucha más seguridad en las casas. Se ordenó en tres
etapas, probando con amigos entre una y otra. El detalle de la etapa en curso está en
`design/game-brief.md`.

### Etapa 1: "La huida" (en curso)
Cerrar el ciclo completo: robar → huir → vender → comprar → volver.
- Personas animadas (jugadores y Don Ramón): caminar, correr, agacharse, cargar, dormir.
- Camión de verdad, con física de vehículo y modo de conducción.
- Lo que va en la caja se golpea y se rompe con frenazos, choques o yendo rápido.
- Camino hasta el **almacén secreto**: ahí se descarga y se vende en el **mercado negro**.
  *(Hecho, primera versión: la ciudad en cuadrícula con tres barrios pegados (Villa Esperanza,
  Los Aromos y Las Lomas), la avenida con comercios, la plaza, la estación de servicio y la zona
  industrial cruzando las vías. El almacén es el **Galpón 7**: hay que dejar el camión parado
  adentro y "el Flaco" compra solo todo lo de la caja; lo golpeado vale menos. Una flecha marca
  el camino. Sin la cuota no hay trato; si amanece antes de llegar, o la policía encuentra el
  camión en el barrio, se pierde todo.)*
- Mercado negro de **compra**: herramientas para las próximas noches.
- Guardado de partida (plata y herramientas).
- **Llegar al almacén sin la cuota cancela la misión y se pierde todo lo cargado.**

### Etapa 2: "La seguridad"
Cada cosa con su minijuego, y las herramientas se compran en el mercado negro.
- Alarmas con panel para desactivarlas.
- Cámaras de seguridad (si te ven, suena la alarma).
- Caja de electricidad afuera de la casa: cortar la luz apaga alarmas y cámaras.
- **Inhibidor de señal** (estilo Mute de *Rainbow Six*): apaga la tecnología cercana; alcance y
  batería limitados.
- Mascotas que huelen y ladran (y despiertan al dueño) + **pistola tranquilizante**.
- Cajas fuertes con minijuego.

### Etapa 3: "La ciudad"
- Mapa más grande con cuatro barrios: **popular, clase media, clase alta y millonarios**.
- Cuanto más rico el barrio: objetos más valiosos, más seguridad, más objetos que hay que cargar
  entre 3 o 4, y **vigilancia privada** que patrulla el de millonarios.
- Casas con distintas distribuciones de cuartos.
- **Vecinos testigos:** si ven el robo, caminan al teléfono público más cercano a llamar a la
  policía; los jugadores pueden interceptarlos o sobornarlos antes de que lleguen.

### Modelos 3D
**Personajes (hecho, primera versión):** se arman en Blender con `tools/personajes/` sobre los
cuerpos base de Quaternius: proporciones y piel propias, ropa en capas. Quedan para más adelante:
más modelos distintos (sexo, tez, contextura), sombreros y vello facial, que todavía no convencen.

Las personas y el camión realistas necesitan modelos hechos por artistas. Se usan modelos
gratuitos y sin licencias: **Quaternius** (personas con animaciones), **Kenney** (vehículos,
muebles) y **Poly Haven** (objetos y texturas fotográficas). Para descargarlos hay que permitir
esos sitios en la configuración de red del entorno de Claude Code.
