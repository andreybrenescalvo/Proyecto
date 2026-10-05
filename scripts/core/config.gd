class_name Config
extends RefCounted
## Constantes del juego en un solo lugar, para ajustar el balance sin buscar por todo el código.

# --- Capas de colisión (valores de bit) ---
const L_WORLD := 1    # terreno, celdas de roca, paredes, montacargas
const L_PLAYER := 2   # jugadores
const L_SMALL := 4    # objetos chicos: mineral, dinamita
const L_BIG := 8      # objetos grandes: carrito, puntales

# --- Mina ---
const CELL_SIZE := 2.0        # ancho de cada columna de roca (metros)
const CELL_HEIGHT := 3.0      # alto de la galería
const MINE_Y := -30.0         # altura del piso de la mina (la superficie está en 0)
const GRID_MIN := -14         # la grilla va de GRID_MIN a GRID_MAX (incluidos); el borde es roca madre
const GRID_MAX := 13
const ZONE_CELLS := 4         # cada "zona" de estabilidad mide 4x4 celdas

enum Cell { EMPTY, BEDROCK, ROCK, COAL, IRON, SILVER, GOLD, RUBBLE }

## Datos de cada tipo de celda: golpes de pico que aguanta, mineral que suelta y cuántos trozos.
const CELL_INFO := {
	Cell.BEDROCK: {"name": "Roca madre", "hp": 0, "ore": "", "drops": 0},
	Cell.ROCK: {"name": "Roca", "hp": 4, "ore": "", "drops": 0},
	Cell.COAL: {"name": "Veta de carbón", "hp": 5, "ore": "coal", "drops": 3},
	Cell.IRON: {"name": "Veta de hierro", "hp": 6, "ore": "iron", "drops": 3},
	Cell.SILVER: {"name": "Veta de plata", "hp": 7, "ore": "silver", "drops": 2},
	Cell.GOLD: {"name": "Veta de oro", "hp": 8, "ore": "gold", "drops": 2},
	Cell.RUBBLE: {"name": "Escombros", "hp": 2, "ore": "", "drops": 0},
}

## Minerales: nombre visible, precio por trozo y color.
const ORES := {
	"coal": {"name": "Carbón", "value": 6, "color": Color(0.17, 0.17, 0.18)},
	"iron": {"name": "Hierro", "value": 12, "color": Color(0.72, 0.42, 0.25)},
	"silver": {"name": "Plata", "value": 25, "color": Color(0.82, 0.86, 0.92)},
	"gold": {"name": "Oro", "value": 50, "color": Color(1.0, 0.78, 0.18)},
}

# --- Herramientas ---
const PICK_RANGE := 3.0
const PICK_COOLDOWN := 0.45
const INTERACT_RANGE := 3.2
const DYNAMITE_COST := 5      # por cartucho
const MAX_CHARGE := 4         # cartuchos por carga
const FUSE_TIME := 4.0        # segundos de mecha
const SUPPORT_COST := 15
const THROW_SPEED := 9.0
const MAX_ENTITIES := 260     # tope de objetos físicos para no matar el rendimiento

## Radio de la explosión en metros según cantidad de cartuchos.
static func blast_radius(charge: int) -> float:
	return 2.2 + 1.3 * charge

# --- Derrumbes ---
## Probabilidad base de derrumbe por cantidad de cartuchos (índice = cartuchos).
const BASE_COLLAPSE := [0.0, 0.05, 0.14, 0.30, 0.52]
## Estabilidad que pierde la zona con cada explosión (índice = cartuchos).
const STABILITY_LOSS := [0.0, 0.06, 0.15, 0.28, 0.45]
const STABILITY_RECOVERY := 0.004   # por segundo
const COLLAPSE_WARNING := 1.6       # segundos de crujidos antes de que caiga el techo

## Probabilidad de derrumbe de una explosión.
## Más cartuchos y menos estabilidad = más riesgo. Cada puntal cerca reduce el riesgo a la mitad.
static func collapse_chance(charge: int, stability: float, supports: int) -> float:
	var p: float = BASE_COLLAPSE[clampi(charge, 0, MAX_CHARGE)]
	p *= 1.0 + 2.0 * (1.0 - stability)
	p *= pow(0.5, supports)
	return clampf(p, 0.0, 0.95)

## Riesgo en palabras (la idea es que se sienta, no que se lea un número).
static func risk_word(p: float) -> String:
	if p < 0.08:
		return "bajo"
	if p < 0.2:
		return "moderado"
	if p < 0.4:
		return "alto"
	return "muy alto"

# --- Montacargas ---
const LIFT_TOP := 0.0
const LIFT_BOTTOM := MINE_Y
const LIFT_FAST := 6.0      # desde el panel de arriba
const LIFT_SLOW := 1.5      # desde el panel de abajo (lento pero seguro)
const LIFT_ACCEL := 5.0
const LIFT_BRAKE := 22.0
const LIFT_DERAIL_SPEED := 3.0   # frenar o llegar al tope más rápido que esto descarrila la carga

# --- Economía: el prestamista ---
const START_MONEY := 40
const START_DEBT := 1500
const DAY_LENGTH := 300.0          # segundos por día de juego
const MAX_STRIKES := 3

## Cuota que cobra el prestamista al terminar cada día.
static func quota_for_day(day: int) -> int:
	return 120 + 80 * (day - 1)

# --- Lugares de la superficie ---
const SELL_ZONE_POS := Vector3(9.0, 0.0, 0.0)
const SPAWN_POS := Vector3(5.0, 1.0, 7.0)
const PLAYER_COLORS := [
	Color(0.95, 0.55, 0.15), Color(0.25, 0.55, 0.95),
	Color(0.35, 0.8, 0.35), Color(0.75, 0.4, 0.9),
]
