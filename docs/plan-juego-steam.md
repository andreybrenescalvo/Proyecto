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
