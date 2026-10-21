class_name Truck
extends VehicleBody3D
## El camión de mudanzas: se maneja de verdad (ruedas con suspensión, motor y frenos).
##
## El anfitrión simula la física y el que maneja (cualquier jugador) le manda acelerador, volante
## y freno. En los clientes el camión está congelado y sigue lo que llega por red.
## Lo que va en la caja también es físico: si frenan de golpe o doblan rápido, se desliza y choca
## contra las paredes (y lo frágil se rompe).
##
## Coordenadas propias: el largo va a lo largo de Z, la cabina adelante (+Z) y la puerta de carga
## atrás (-Z). Mirando hacia adelante, la izquierda es +X: ahí va el conductor (se maneja por la
## derecha de la calle) y el acompañante del lado de la vereda (-X).
## Al arrancar, la rampa se pliega y cierra la caja (así no se cae nada); al detenerse sin nadie
## al volante, vuelve a bajar.

const ENGINE_FORCE := 9000.0
const REVERSE_SPEED := 4.0     # m/s marcha atrás
const BRAKE_FORCE := 60.0
const HANDBRAKE_FORCE := 140.0
const PARK_BRAKE := 40.0       # sin conductor queda frenado
const ENGINE_BRAKE := 6.0      # al soltar el acelerador frena un poco (como un motor de verdad)
const MAX_STEER := 0.55        # radianes, parado
const MIN_STEER := 0.12        # a toda velocidad gira poco (si no, se vuelca)
const STEER_SPEED := 1.6       # qué tan rápido gira el volante
const INPUT_TIMEOUT := 0.5     # si el conductor deja de mandar, suelta todo
const ORBIT_RETURN_DELAY := 2.0  # segundos sin mover el mouse para que la cámara vuelva atrás

## Sacudón fuerte (un lomo de burro rápido o un choque): `strength` es como la velocidad de un
## golpe (m/s) y se compara con lo que aguanta cada cosa frágil de la caja.
signal jolted(strength: float)

const MAX_SEATS := 4
## Asientos: 0 = conductor, 1 = acompañante, 2 y 3 = atrás, en la caja.
const SEAT_POS := [Vector3(0.45, 1.15, 3.1), Vector3(-0.45, 1.15, 3.1), Vector3(0.5, 0.75, -0.6), Vector3(-0.5, 0.75, -0.6)]
const EXIT_POS := [Vector3(1.9, 0.15, 3.0), Vector3(-1.9, 0.15, 3.0), Vector3(-0.6, 0.15, -4.4), Vector3(0.6, 0.15, -4.4)]
const WHEELS := [Vector3(1.0, 0.63, -1.2), Vector3(-1.0, 0.63, -1.2), Vector3(1.0, 0.63, 3.0), Vector3(-1.0, 0.63, 3.0)]
const WHEEL_RADIUS := 0.38

var server_side := false
var driver := 0               # peer al volante (0 = nadie)
var seats := {}               # peer -> asiento
var area: Area3D              # la caja de carga: lo que está adentro cuenta como botín
var camera: Camera3D          # cámara de persecución (para los que van arriba)
## La cámara gira alrededor del camión con el mouse (360°); si no se mueve el mouse un rato,
## vuelve sola atrás del camión.
var orbit_yaw := 0.0
var orbit_pitch := 0.0
var _orbit_idle := 0.0
var speed := 0.0              # m/s, en todas las computadoras
var forward_speed := 0.0      # con signo: negativo = marcha atrás
var locked := false           # terminó la noche: queda frenado aunque haya alguien al volante
var bumps: Array[Rect2] = []  # lomos de burro (rectángulos en X/Z del piso)

var _input := Vector3.ZERO    # x: acelerador (-1..1), y: volante (-1..1), z: freno de mano (0/1)
var _input_time := -10.0
var _time := 0.0
var _net_pos := Vector3.ZERO
var _net_rot := Quaternion.IDENTITY
var _net_steer := 0.0
var _net_speed := 0.0
var _ramp_shape: CollisionShape3D
var _ramp_mesh: Node3D
var _gate_shape: CollisionShape3D
var _gate_mesh: Node3D
var _buttons := {}            # CollisionShape3D -> qué hace (para el rayo de "mirar")
var _wheel_nodes: Array[VehicleWheel3D] = []
var _wheel_visuals: Array[Node3D] = []
var _spin := 0.0
var _engine: AudioStreamPlayer3D
var _prev_pos := Vector3.ZERO
var _cam_smooth := Transform3D.IDENTITY
var _prev_vel := Vector3.ZERO
var _jolt_peak := 0.0
var _jolt_left := 0.0
var _axles_on_bump := [false, false]

func _init() -> void:
	name = "Truck"
	mass = 3200.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.25, 0.6)
	collision_layer = Config.L_WORLD
	collision_mask = Config.L_WORLD
	_build()

## Lo llama la partida después de crearlo: el anfitrión simula; los clientes solo copian.
func setup(is_server: bool) -> void:
	server_side = is_server
	if not server_side:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true

func _ready() -> void:
	_net_pos = global_position
	_net_rot = global_transform.basis.get_rotation_quaternion()
	_prev_pos = global_position
	_cam_smooth = _chase_transform()
	_engine = Sfx.make_loop("engine", self, -6.0)
	_engine.position = Vector3(0, 0.8, 3.4)
	_engine.unit_size = 10.0
	_engine.max_distance = 90.0
	_set_ramp(true)

# ---------------------------------------------------------------- modelo

func _shape(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	cs.rotation_degrees = rot
	add_child(cs)
	return cs

func _mesh(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.box_mesh(size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

## Pieza sólida: colisión y malla del mismo tamaño.
func _part(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> CollisionShape3D:
	_mesh(self, size, pos, mat, rot)
	return _shape(size, pos, rot)

func _build() -> void:
	var paint := Mats.tex("metal", Color(0.95, 0.94, 0.9), 2.0, false, 0.45)
	var dark := Mats.tex("metal", Color(0.2, 0.2, 0.22), 1.0, false, 0.6)
	var stripe := Mats.color(Color(0.95, 0.5, 0.12), 0.5)
	var glass := Mats.color(Color(0.18, 0.22, 0.3), 0.08, 0.15, 0.4)
	var rubber := Mats.color(Color(0.07, 0.07, 0.07), 0.9)
	var chrome := Mats.color(Color(0.8, 0.8, 0.82), 0.2, 0.0, 0.9)
	# Chasis y caja de carga (piso a 0,55 m).
	_part(Vector3(2.1, 0.15, 6.0), Vector3(0, 0.38, 0.9), dark)
	_part(Vector3(2.2, 0.1, 4.2), Vector3(0, 0.5, 0), Mats.tex("wood_floor", Color(0.8, 0.75, 0.7), 1.2, false, 0.7))
	for side in [-1.0, 1.0]:
		_part(Vector3(0.08, 2.05, 4.2), Vector3(side * 1.1, 1.575, 0), paint)
		_mesh(self, Vector3(0.1, 0.3, 4.2), Vector3(side * 1.11, 1.2, 0), stripe)
		_mesh(self, Vector3(0.1, 0.06, 4.22), Vector3(side * 1.12, 2.6, 0), chrome)
	_part(Vector3(2.2, 2.05, 0.08), Vector3(0, 1.575, 2.1), paint)
	_part(Vector3(2.3, 0.08, 4.3), Vector3(0, 2.64, 0), paint)
	# Cabina: más baja que la caja, con parabrisas inclinado, capó y paragolpes.
	_part(Vector3(2.1, 1.2, 1.6), Vector3(0, 1.15, 2.95), paint)
	_part(Vector3(2.1, 0.6, 0.7), Vector3(0, 0.85, 4.05), paint)
	_mesh(self, Vector3(2.0, 0.62, 0.06), Vector3(0, 1.45, 3.78), glass, Vector3(-28, 0, 0))
	_mesh(self, Vector3(2.12, 0.09, 0.75), Vector3(0, 1.17, 4.05), paint)
	_part(Vector3(2.2, 0.22, 0.14), Vector3(0, 0.55, 4.45), dark)
	_mesh(self, Vector3(1.0, 0.28, 0.04), Vector3(0, 0.88, 4.41), dark)
	for side in [-1.0, 1.0]:
		var head := _mesh(self, Vector3(0.32, 0.16, 0.05), Vector3(side * 0.72, 0.9, 4.41), Mats.color(Color(1, 0.95, 0.75), 0.5, 1.6))
		head.name = "Headlight"
		_mesh(self, Vector3(0.12, 0.22, 0.05), Vector3(side * 1.0, 0.75, -2.12), Mats.color(Color(1, 0.1, 0.1), 0.5, 2.4))
		_mesh(self, Vector3(0.06, 0.5, 0.9), Vector3(side * 1.06, 1.45, 2.9), glass)          # ventanilla
		_mesh(self, Vector3(0.18, 0.22, 0.05), Vector3(side * 1.22, 1.55, 3.55), dark)        # espejo
		_mesh(self, Vector3(0.05, 0.4, 0.4), Vector3(side * 1.08, 0.55, -1.6), rubber)       # guardabarros
	# Faros que alumbran de verdad.
	for side in [-1.0, 1.0]:
		var beam := SpotLight3D.new()
		beam.light_color = Color(1.0, 0.95, 0.8)
		beam.light_energy = 2.5
		beam.spot_range = 28.0
		beam.spot_angle = 32.0
		beam.position = Vector3(side * 0.72, 0.95, 4.5)
		beam.rotation_degrees = Vector3(-6, 180, 0)
		add_child(beam)
	# Puertas que se usan: el conductor del lado de la calle, el acompañante del lado de la vereda,
	# y la puerta de carga atrás.
	_button("truck_drive", _shape(Vector3(0.06, 0.9, 0.9), Vector3(1.08, 1.25, 2.95)))
	_button("truck_ride", _shape(Vector3(0.06, 0.9, 0.9), Vector3(-1.08, 1.25, 2.95)))
	for side in [-1.0, 1.0]:
		_mesh(self, Vector3(0.02, 0.06, 0.18), Vector3(side * 1.12, 1.15, 2.6), chrome)      # manijas
	# Rampa (bajada, para cargar) y portón (rampa plegada, al manejar).
	_ramp_mesh = Node3D.new()
	add_child(_ramp_mesh)
	var ramp_rot := Vector3(-20, 0, 0)
	_mesh(_ramp_mesh, Vector3(2.0, 0.08, 1.5), Vector3(0, 0.3, -2.8), Mats.tex("metal", Color(0.7, 0.7, 0.72), 0.5, false, 0.5), ramp_rot)
	_ramp_shape = _shape(Vector3(2.0, 0.08, 1.5), Vector3(0, 0.3, -2.8), ramp_rot)
	_button("truck_ride", _ramp_shape)
	_gate_mesh = Node3D.new()
	add_child(_gate_mesh)
	_mesh(_gate_mesh, Vector3(2.1, 1.5, 0.08), Vector3(0, 1.3, -2.13), Mats.tex("metal", Color(0.7, 0.7, 0.72), 0.5, false, 0.5))
	_gate_shape = _shape(Vector3(2.1, 1.5, 0.08), Vector3(0, 1.3, -2.13))
	# Letreros.
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "MUDANZAS TRUCHAS\n¡Nos llevamos todo!"
		label.font_size = 72
		label.pixel_size = 0.005
		label.outline_size = 12
		label.modulate = Color(0.95, 0.45, 0.1)
		label.outline_modulate = Color(0.15, 0.1, 0.05)
		label.position = Vector3(side * 1.17, 1.85, 0)
		label.rotation_degrees.y = 90.0 * side
		add_child(label)
	var back := Label3D.new()
	back.text = "MUDANZAS TRUCHAS"
	back.font_size = 48
	back.pixel_size = 0.005
	back.outline_size = 10
	back.modulate = Color(0.95, 0.45, 0.1)
	back.position = Vector3(0, 2.45, -2.14)
	back.rotation_degrees.y = 180.0
	add_child(back)
	var inside := OmniLight3D.new()
	inside.light_color = Color(1.0, 0.85, 0.6)
	inside.light_energy = 0.8
	inside.omni_range = 4.5
	inside.position = Vector3(0, 2.4, 0.4)
	add_child(inside)
	# Ruedas: el anfitrión usa las VehicleWheel3D (suspensión de verdad); lo que se ve son
	# llantas aparte, que cada computadora acomoda (así también giran en los clientes).
	for i in WHEELS.size():
		var p: Vector3 = WHEELS[i]
		var w := VehicleWheel3D.new()
		w.position = p
		w.wheel_radius = WHEEL_RADIUS
		w.wheel_rest_length = 0.25
		w.suspension_travel = 0.2
		w.suspension_stiffness = 60.0
		w.suspension_max_force = 60000.0
		w.damping_compression = 0.6
		w.damping_relaxation = 0.9
		w.wheel_friction_slip = 2.2
		w.wheel_roll_influence = 0.05
		w.use_as_traction = p.z < 0.0
		w.use_as_steering = p.z > 0.0
		add_child(w)
		_wheel_nodes.append(w)
		var vis := Node3D.new()
		add_child(vis)
		var tire := MeshInstance3D.new()
		tire.mesh = Mats.cylinder_mesh(WHEEL_RADIUS, 0.28, 14)
		tire.material_override = rubber
		tire.rotation_degrees = Vector3(0, 0, 90)
		vis.add_child(tire)
		var hub := MeshInstance3D.new()
		hub.mesh = Mats.cylinder_mesh(0.18, 0.3, 8)
		hub.material_override = chrome
		hub.rotation_degrees = Vector3(0, 0, 90)
		vis.add_child(hub)
		_wheel_visuals.append(vis)
	# Lo que toca esta zona cuenta como cargado.
	area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Config.L_SMALL | Config.L_BIG
	area.monitorable = false
	area.position = Vector3(0, 1.6, 0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 2.1, 4.1)
	cs.shape = box
	area.add_child(cs)
	add_child(area)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.top_level = true
	camera.far = 300.0
	add_child(camera)

func _button(action: String, cs: CollisionShape3D) -> void:
	_buttons[cs] = action

## Qué hace la parte del camión que el rayo tocó ("" si no es una puerta).
func button_at(shape_idx: int) -> String:
	var owner_id := shape_find_owner(shape_idx)
	var node := shape_owner_get_owner(owner_id)
	return _buttons.get(node, "")

## Rampa bajada (estacionado) o plegada como portón (andando).
func _set_ramp(down: bool) -> void:
	_ramp_shape.disabled = not down
	_ramp_mesh.visible = down
	_gate_shape.disabled = down
	_gate_mesh.visible = not down

# ---------------------------------------------------------------- asientos

func seat_position(seat: int) -> Vector3:
	return global_transform * (SEAT_POS[clampi(seat, 0, MAX_SEATS - 1)] as Vector3)

func exit_position(seat: int) -> Vector3:
	return global_transform * (EXIT_POS[clampi(seat, 0, MAX_SEATS - 1)] as Vector3)

## Dónde está cada puerta (para saber si el jugador está cerca).
func door_position(action: String) -> Vector3:
	match action:
		"truck_drive":
			return global_transform * Vector3(1.6, 1.0, 2.95)
		"truck_ride":
			return global_transform * Vector3(-1.6, 1.0, 2.95)
	return global_transform * Vector3(0, 0.5, -3.4)

## El primer asiento libre para subirse (sin contar el del conductor).
func free_seat() -> int:
	for s in range(1, MAX_SEATS):
		if not seats.values().has(s):
			return s
	return -1

func set_seats(new_seats: Dictionary) -> void:
	seats = new_seats
	driver = 0
	for peer: int in seats:
		if int(seats[peer]) == 0:
			driver = peer
	_set_ramp(driver == 0)
	if driver != 0 and server_side:
		sleeping = false

func is_moving() -> bool:
	return speed > 0.5

# ---------------------------------------------------------------- manejo

## Lo que manda el conductor (en el anfitrión).
func set_input(throttle: float, steer: float, handbrake: bool) -> void:
	_input = Vector3(clampf(throttle, -1.0, 1.0), clampf(steer, -1.0, 1.0), 1.0 if handbrake else 0.0)
	_input_time = _time

## Vuelve al lugar de estacionamiento (al empezar otra noche).
func park(pos: Vector3, rot_y_deg: float) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y_deg)), pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steering = 0.0
	engine_force = 0.0
	locked = false
	_input = Vector3.ZERO
	_prev_vel = Vector3.ZERO
	_jolt_peak = 0.0
	_net_pos = pos
	_net_rot = global_transform.basis.get_rotation_quaternion()
	_prev_pos = pos
	_cam_smooth = _chase_transform()

func _physics_process(delta: float) -> void:
	_time += delta
	if server_side:
		_drive(delta)
		_measure_crash(delta)
		_check_bumps()
	else:
		var t := 1.0 - exp(-14.0 * delta)
		var current := global_transform
		var rot := current.basis.get_rotation_quaternion().slerp(_net_rot, t)
		global_transform = Transform3D(Basis(rot), current.origin.lerp(_net_pos, t))
	# Velocidad medida igual en todas las computadoras (para el velocímetro y el motor).
	var moved := (global_position - _prev_pos) / maxf(delta, 0.0001)
	_prev_pos = global_position
	speed = lerpf(speed, moved.length(), clampf(delta * 8.0, 0.0, 1.0))
	forward_speed = moved.dot(global_transform.basis.z)

## Choques: si la velocidad (de costado o de frente, no la de los saltos de la suspensión) cambia
## de golpe, es un sacudón; se avisa el más fuerte de ese momento.
func _measure_crash(delta: float) -> void:
	var dv := linear_velocity - _prev_vel
	var was_moving := Vector2(_prev_vel.x, _prev_vel.z).length() > Config.BUMP_SAFE_SPEED
	_prev_vel = linear_velocity
	var accel := Vector2(dv.x, dv.z).length() / maxf(delta, 0.0001)
	# Parado no hay choque (si no, cargar algo pesado o empujarlo contaría como sacudón).
	if accel > Config.TRUCK_CRASH_MIN and was_moving:
		if _jolt_peak == 0.0:
			_jolt_left = 0.12
		_jolt_peak = maxf(_jolt_peak, accel)
	if _jolt_peak > 0.0:
		_jolt_left -= delta
		if _jolt_left <= 0.0:
			jolted.emit(_jolt_peak * Config.TRUCK_CRASH_K)
			_jolt_peak = 0.0

## Lomos de burro: cada vez que un eje del camión se sube a uno, sacude la caja según la velocidad.
func _check_bumps() -> void:
	for i in 2:
		var p := to_global(Vector3(0, 0, WHEELS[i * 2].z))
		var on := false
		for r in bumps:
			on = on or r.has_point(Vector2(p.x, p.z))
		if on and not _axles_on_bump[i] and speed > Config.BUMP_SAFE_SPEED:
			jolted.emit(speed * Config.BUMP_K)
		_axles_on_bump[i] = on

func _drive(delta: float) -> void:
	var fwd := linear_velocity.dot(global_transform.basis.z)
	var input := _input if _time - _input_time < INPUT_TIMEOUT and driver != 0 and not locked else Vector3.ZERO
	var throttle := input.x
	var steer_target := input.y * lerpf(MAX_STEER, MIN_STEER, clampf(absf(fwd) / Config.TRUCK_MAX_SPEED, 0.0, 1.0))
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)
	var force := 0.0
	var brake_force := 0.0
	if throttle > 0.05:
		if fwd < -0.5:
			brake_force = BRAKE_FORCE      # iba para atrás: primero frena
		else:
			force = ENGINE_FORCE * throttle * clampf((Config.TRUCK_MAX_SPEED - fwd) / 3.0, 0.0, 1.0)
	elif throttle < -0.05:
		if fwd > 0.5:
			brake_force = BRAKE_FORCE * -throttle
		else:
			force = ENGINE_FORCE * 0.6 * throttle * clampf((REVERSE_SPEED + fwd) / 2.0, 0.0, 1.0)
	else:
		brake_force = ENGINE_BRAKE
	if input.z > 0.5:
		brake_force = HANDBRAKE_FORCE
		force = 0.0
	if driver == 0 or locked:
		brake_force = HANDBRAKE_FORCE if locked else PARK_BRAKE
		force = 0.0
	engine_force = force
	brake = brake_force

func _process(delta: float) -> void:
	_update_wheels(delta)
	var running := driver != 0
	if running and not _engine.playing:
		_engine.play()
	elif not running and _engine.playing:
		_engine.stop()
	_engine.pitch_scale = 0.7 + clampf(speed / Config.TRUCK_MAX_SPEED, 0.0, 1.0) * 0.8
	_engine.volume_db = -8.0 + clampf(speed / Config.TRUCK_MAX_SPEED, 0.0, 1.0) * 6.0
	# Cámara de persecución, suave (si no, se sacude con la suspensión).
	_orbit_idle += delta
	if _orbit_idle > ORBIT_RETURN_DELAY and speed > 1.0:
		orbit_yaw = lerp_angle(orbit_yaw, 0.0, clampf(delta * 1.5, 0.0, 1.0))
		orbit_pitch = lerpf(orbit_pitch, 0.0, clampf(delta * 1.5, 0.0, 1.0))
	_cam_smooth = _cam_smooth.interpolate_with(_chase_transform(), clampf(delta * 6.0, 0.0, 1.0))
	camera.global_transform = _cam_smooth

## Mover la cámara con el mouse (lo llama el jugador que va arriba).
func orbit(dx: float, dy: float) -> void:
	orbit_yaw = wrapf(orbit_yaw - dx, -PI, PI)
	orbit_pitch = clampf(orbit_pitch - dy, -0.35, 0.9)
	_orbit_idle = 0.0

func _chase_transform() -> Transform3D:
	var flat := global_transform.basis.z
	flat.y = 0.0
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	flat = flat.rotated(Vector3.UP, orbit_yaw)
	var height := 4.2 + orbit_pitch * 6.0
	var back := 9.0 - orbit_pitch * 2.5
	var eye := global_position - flat * back + Vector3(0, height, 0)
	var target := global_position + flat * 3.0 + Vector3(0, 1.2, 0)
	return Transform3D.IDENTITY.translated(eye).looking_at(target, Vector3.UP)

## Las llantas que se ven: en el anfitrión copian la suspensión; en los clientes giran según la velocidad.
func _update_wheels(delta: float) -> void:
	_spin += forward_speed / WHEEL_RADIUS * delta
	for i in _wheel_visuals.size():
		var vis := _wheel_visuals[i]
		if server_side:
			# Godot ya mueve cada VehicleWheel3D con la suspensión, el volante y el giro.
			vis.transform = _wheel_nodes[i].transform
			continue
		var p: Vector3 = WHEELS[i]
		vis.position = p - Vector3(0, 0.25, 0)
		var yaw := _net_steer if p.z > 0.0 else 0.0
		vis.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _spin)

# ---------------------------------------------------------------- red

func get_net_state() -> Array:
	return [global_position, global_transform.basis.get_rotation_quaternion(), steering]

func set_net_state(pos: Vector3, rot: Quaternion, steer: float) -> void:
	_net_pos = pos
	_net_rot = rot
	_net_steer = steer
