class_name Autopilot
extends RefCounted
## Piloto automático para las pruebas y el recorrido de fotos: maneja el camión siguiendo una
## lista de puntos (no hay teclado, así que se le pasa el mando a mano al anfitrión).

## De lo de Don Ramón al Galpón 7: por Los Aromos hasta San José, por San José hasta la avenida,
## por la avenida hasta la calle industrial y de ahí al portón. Va un poco corrido del medio,
## del lado contrario a los autos estacionados.
const ROUTE_TO_WAREHOUSE := [
	Vector3(-52.0, 0, 20.1), Vector3(-57.5, 0, 21.5), Vector3(-60.2, 0, 25.0), Vector3(-60.9, 0, 30.0),
	Vector3(-60.9, 0, 72.0), Vector3(-62.0, 0, 77.0), Vector3(-66.0, 0, 80.2), Vector3(-72.0, 0, 81.0),
	Vector3(-250.0, 0, 81.0), Vector3(-256.5, 0, 79.6), Vector3(-260.6, 0, 75.5), Vector3(-262.0, 0, 69.0),
	Vector3(-262.0, 0, 10.0), Vector3(-263.5, 0, 5.0), Vector3(-267.5, 0, 1.2), Vector3(-273.0, 0, 0.0),
	Vector3(-288.5, 0, 0.0),
]

var route: Array = []
var index := 0
var cruise := 11.0       # m/s en las rectas
var turn_speed := 3.5    # m/s al llegar a una esquina
const BRAKING := 2.5     # m/s² que se cuenta para frenar antes de las esquinas
var _stuck := 0.0
var _reverse := 0.0

func _init(points: Array) -> void:
	route = points

func done() -> bool:
	return index >= route.size()

## Devuelve [acelerador, volante, freno de mano] para este paso de física.
func step(truck: Truck) -> Array:
	if done():
		return [0.0, 0.0, true]
	var target: Vector3 = route[index]
	var local := truck.to_local(target)
	var dist := Vector2(local.x, local.z).length()
	var last := index == route.size() - 1
	# Llegó al punto (o ya lo pasó de largo): al siguiente.
	if dist < (2.0 if last else 3.5) or (not last and local.z < -1.0 and dist < 14.0):
		index += 1
		if done():
			return [0.0, 0.0, true]
		return step(truck)
	var angle := atan2(local.x, local.z)
	var steer := clampf(angle * 2.2, -1.0, 1.0)
	# Velocidad: la que permite frenar a tiempo para la próxima esquina (o para parar al final).
	var corner := 1.5 if last else turn_speed
	var want := minf(cruise, sqrt(corner * corner + 2.0 * BRAKING * maxf(dist - 7.0, 0.0)))
	if absf(angle) > 0.5:
		want = minf(want, turn_speed)
	# Despacio por los lomos de burro y el paso a nivel (como un buen chofer).
	var ahead := truck.global_position + truck.global_transform.basis.z * 6.0
	for r: Rect2 in truck.bumps:
		if r.grow(10.0).has_point(Vector2(ahead.x, ahead.z)):
			want = minf(want, Config.BUMP_SAFE_SPEED - 0.5)
	# Si se trabó contra algo, marcha atrás un rato.
	var dt := 1.0 / Engine.physics_ticks_per_second
	if _reverse > 0.0:
		_reverse -= dt
		return [-1.0, -steer, false]
	_stuck = _stuck + dt if truck.speed < 0.4 else 0.0
	if _stuck > 2.0:
		_stuck = 0.0
		_reverse = 1.6
	var throttle := clampf((want - truck.forward_speed) * 0.6, -1.0, 1.0)
	# Si viene muy rápido para la esquina, también el freno de mano.
	return [throttle, steer, truck.forward_speed - want > 2.0]
