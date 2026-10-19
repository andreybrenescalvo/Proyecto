class_name Config
extends RefCounted
## Constantes del juego en un solo lugar, para ajustar el balance sin buscar por todo el código.

# --- Capas de colisión (valores de bit) ---
const L_WORLD := 1    # piso, paredes, muebles fijos, camión
const L_PLAYER := 2   # jugadores
const L_SMALL := 4    # objetos que se agarran con una mano
const L_BIG := 8      # objetos pesados (se cargan entre dos)
const L_OWNER := 16   # el dueño de casa
const L_DOOR := 32    # hojas de las puertas
const L_WALL := 64    # paredes y techo (para saber cuánto tapan el sonido y la vista)

# --- Jugadores ---
const WALK := 4.0
const SPRINT := 6.5
const CROUCH := 1.9
const INTERACT_RANGE := 2.6
const THROW_SPEED := 8.0
const LEAVE_HOLD_TIME := 1.2      # segundos manteniendo E en la cabina para irse

# --- Ruido ---
## El dueño "oye" cada ruido según lo fuerte que es (0..1+), la distancia y las paredes en el medio.
## oído = fuerza * atenuación(distancia) * WALL_FACTOR ^ paredes
## Lo que pase de HEARING_FLOOR se suma a su nivel de alerta (0 a 100).
const HEARING_DISTANCE := 5.0     # a esta distancia el ruido llega a la mitad
const WALL_FACTOR := 0.7
const HEARING_FLOOR := 0.04
const ALERT_GAIN := 100.0
const ALERT_DECAY := 2.5          # por segundo, cuando hay silencio
const ALERT_RESTLESS := 35.0      # deja de roncar y se da vuelta
const ALERT_STIRRING := 70.0      # medio despierto: si ve a alguien moverse en la pieza, se levanta
const ALERT_WAKE := 100.0
const LIGHTER_SLEEP := 1.25       # cada vez que se vuelve a dormir tiene el sueño más liviano

## Ruido de cada cosa: [fuerza, peso]. El peso es cuánto "dura" (un golpe suelto pesa más que un paso).
const NOISE_STEP_WALK := [0.12, 0.5]
const NOISE_STEP_SPRINT := [0.35, 0.5]
const NOISE_STEP_CROUCH := [0.02, 0.5]
const STEP_INTERVAL_WALK := 0.5
const STEP_INTERVAL_SPRINT := 0.32
const STEP_INTERVAL_CROUCH := 0.7
const NOISE_BOARD := [0.5, 1.0]         # tabla del piso que cruje
const NOISE_BOARD_CROUCH := [0.25, 1.0]
const NOISE_SCRAPE := [0.4, 0.3]        # arrastrar algo pesado solo (cada 0,3 s)
const NOISE_CRASH := [1.2, 1.5]         # algo que se rompe
const NOISE_IMPACT_K := 0.06            # golpe de un objeto: fuerza = velocidad * raíz(masa) * K
const NOISE_IMPACT_MIN_SPEED := 1.2
const VOICE_LOUDNESS := 1.0             # el micrófono (0..1) se multiplica por esto

# --- El dueño ---
const OWNER_WALK := 2.2           # en pantuflas, investigando
const OWNER_RUN := 4.6            # persiguiendo
const OWNER_CATCH := 1.1          # distancia a la que atrapa
const OWNER_VIEW_RANGE := 12.0
const OWNER_VIEW_RANGE_LIGHT := 18.0   # si el ladrón tiene la linterna prendida
const OWNER_VIEW_RANGE_CROUCH := 6.0
const OWNER_VIEW_ANGLE := 55.0         # grados a cada lado
const OWNER_GLANCE := 2.5              # de reojo (fuera del cono) ve a quien está así de cerca...
const OWNER_GLANCE_CROUCH := 1.2       # ...o así, si está agachado
const OWNER_GLANCE_LIGHT := 5.0        # una linterna prendida se nota de reojo desde más lejos
const OWNER_SEARCH_TIME := 5.0
const OWNER_LOSE_TIME := 1.5           # cuánto tarda en "perder" a alguien que dejó de ver
const CAUGHT_STUN := 2.5

# --- La noche ---
const NIGHT_LENGTH := 420.0       # segundos hasta que amanece
const POLICE_DELAY := 60.0        # desde que el dueño atrapa a alguien y llama a la policía
const ARREST_FINE := 300          # por cada ladrón que se queda adentro cuando llega la policía

static func quota_for_night(night: int) -> int:
	return 1800 + 400 * (night - 1)

## Estrellas de la noche según lo que quedó en el camión.
static func stars(value: int, quota: int) -> int:
	if value >= quota * 2.5:
		return 3
	if value >= quota * 1.75:
		return 2
	if value >= quota:
		return 1
	return 0

# --- Objetos ---
## name: lo que se ve en pantalla · value: precio · mass: kg · size: caja de colisión
## fragile/break: se rompe si choca con un cambio de velocidad mayor a `break` m/s
## heavy: se carga entre dos (solo, se arrastra y hace ruido) · hang: colgado de la pared hasta que se agarra
## slow: cuánto frena al que lo lleva (1 = nada)
const ITEMS := {
	"tv": {"name": "Televisor", "value": 400, "mass": 14.0, "size": Vector3(0.15, 0.65, 1.1), "fragile": true, "break": 6.0, "slow": 0.75},
	"console": {"name": "Consola", "value": 250, "mass": 2.5, "size": Vector3(0.3, 0.08, 0.26)},
	"sofa": {"name": "Sillón", "value": 300, "mass": 45.0, "size": Vector3(0.9, 0.8, 2.2), "heavy": true},
	"vase": {"name": "Jarrón", "value": 120, "mass": 2.0, "size": Vector3(0.22, 0.4, 0.22), "fragile": true, "break": 3.5},
	"lamp": {"name": "Lámpara de pie", "value": 60, "mass": 4.0, "size": Vector3(0.3, 1.6, 0.3), "fragile": true, "break": 4.5, "slow": 0.85},
	"painting": {"name": "Cuadro", "value": 200, "mass": 3.0, "size": Vector3(1.0, 0.7, 0.05), "hang": true, "slow": 0.9},
	"microwave": {"name": "Microondas", "value": 150, "mass": 10.0, "size": Vector3(0.5, 0.3, 0.36), "slow": 0.8},
	"blender": {"name": "Licuadora", "value": 80, "mass": 2.0, "size": Vector3(0.18, 0.36, 0.18), "fragile": true, "break": 5.0},
	"plates": {"name": "Platos", "value": 0, "mass": 2.0, "size": Vector3(0.3, 0.12, 0.3), "fragile": true, "break": 3.0},
	"pot": {"name": "Olla", "value": 0, "mass": 1.5, "size": Vector3(0.3, 0.2, 0.3)},
	"chair": {"name": "Silla", "value": 0, "mass": 5.0, "size": Vector3(0.45, 0.9, 0.45), "slow": 0.85},
	"jewelry": {"name": "Joyero", "value": 600, "mass": 1.0, "size": Vector3(0.3, 0.18, 0.22)},
	"watch": {"name": "Reloj de oro", "value": 250, "mass": 0.3, "size": Vector3(0.14, 0.06, 0.14)},
	"safe": {"name": "Caja fuerte", "value": 1200, "mass": 80.0, "size": Vector3(0.7, 0.7, 0.6), "heavy": true},
	"laptop": {"name": "Notebook", "value": 500, "mass": 2.0, "size": Vector3(0.36, 0.04, 0.26), "fragile": true, "break": 7.0},
	"pc": {"name": "Computadora", "value": 350, "mass": 9.0, "size": Vector3(0.22, 0.46, 0.46), "slow": 0.8},
	"guitar": {"name": "Guitarra", "value": 350, "mass": 3.5, "size": Vector3(0.36, 1.0, 0.12), "slow": 0.9},
	"trophy": {"name": "Trofeo", "value": 300, "mass": 1.5, "size": Vector3(0.16, 0.36, 0.16)},
	"office_chair": {"name": "Silla de escritorio", "value": 0, "mass": 8.0, "size": Vector3(0.55, 1.0, 0.55), "slow": 0.85},
	"perfume": {"name": "Perfume", "value": 90, "mass": 0.3, "size": Vector3(0.1, 0.16, 0.1), "fragile": true, "break": 4.0},
	"duck": {"name": "Patito de hule", "value": 1, "mass": 0.2, "size": Vector3(0.16, 0.16, 0.16)},
	"photo": {"name": "Foto familiar", "value": 30, "mass": 0.5, "size": Vector3(0.22, 0.26, 0.06)},
}
const MAX_ENTITIES := 120

static func item(id: String) -> Dictionary:
	return ITEMS.get(id, ITEMS["pot"])

# --- Lugares ---
const PLAYER_COLORS := [
	Color(0.95, 0.55, 0.15), Color(0.25, 0.55, 0.95),
	Color(0.35, 0.8, 0.35), Color(0.75, 0.4, 0.9),
]
