# Game Brief: Mudanceros Truchos

**One-sentence pitch:** De 1 a 4 amigos "mudan" casas ajenas de noche, en silencio porque el
juego escucha el micrófono, cargan el botín en un camión que hay que manejar con cuidado y lo
venden en el mercado negro de su almacén secreto.

## Core loop
- Elegir el encargo y comprar herramientas en el mercado negro del almacén.
- Robar la casa sin despertar al dueño: el ruido, la voz y lo pesado se cargan entre varios.
- Escapar manejando el camión hasta el almacén, despacio para que no se rompa lo de la caja.
- Vender lo robado, cobrar y volver con mejores herramientas a una casa más difícil.

## Player goal & fail state — what "working" looks like
- Una noche sale bien cuando llegan al almacén con un botín de al menos la cuota del encargo y
  lo venden.
- Se pierde todo lo cargado si amanece antes de llegar al almacén, o si la policía (por una
  llamada) encuentra el camión todavía en el barrio. Si llegan al almacén sin la cuota, la
  misión se cancela y **no se vende nada**.
- Lo que se golpea en el viaje (lomos de burro, paso a nivel, choques) vale menos al venderlo.

## MVP — what must exist to be the game
- Personas con forma humana y animadas (caminar, correr, agacharse, cargar, dormir), con sombras
  que se mueven con el cuerpo.
- Un camión de verdad: cabina, ruedas, suspensión y faros que alumbran.
- Modo de conducción: el camión se maneja, y frenazos, choques o ir rápido golpean y rompen lo
  que va en la caja.
- Un camino desde el barrio hasta el almacén secreto, donde se descarga el camión.
- Mercado negro de venta: cada objeto con su precio.
- Mercado negro de compra: herramientas para las próximas noches.
- Guardado de partida: la plata y las herramientas se mantienen entre sesiones.

## Out of scope — not building this
- Etapa 2 (seguridad): alarmas, cámaras, caja de luz, inhibidor de señal, perros con pistola
  tranquilizante y cajas fuertes con minijuegos.
- Etapa 3 (ciudad): barrios popular, medio, alto y millonario; vigilancia privada; vecinos que
  ven el robo y van al teléfono público a llamar a la policía (y se los intercepta o soborna).
- La mudanza de día, más casas para robar y la voz por proximidad dentro del juego.

## Build order
1. Personas animadas: jugadores y Don Ramón (modelos gratuitos de Quaternius, con sus animaciones).
2. El camión nuevo (modelo de Kenney) con física de vehículo y modo de conducción.
3. Que lo cargado se golpee y se rompa al manejar mal; la cuota y la cancelación al irse antes.
4. El camino y el almacén secreto, y la venta en el mercado negro. *(Hecho: la ciudad con tres
   barrios, comercios y zona industrial; el Galpón 7 con venta automática de todo lo de la caja.)*
5. La compra de herramientas y el guardado de partida.
6. Probarlo con amigos y ajustar.

---
**Who it's for / what they feel:** grupos de amigos que juegan con voz y se ríen de los
fracasos: la tensión de susurrar al lado de un dueño dormido y el caos de huir en un camión
cargado.

**Art & audio direction:** estilo low-poly como Schedule I pero con formas y sombras creíbles;
texturas propias con relieve; modelos gratuitos sin licencias (Quaternius, Kenney, Poly Haven).

**Reference game:** Schedule I y Thief Simulator 2 — del segundo, robar casas con herramientas y
vender en el mercado negro; sin su mundo abierto completo en esta etapa.
