class_name HouseOwner
extends CharacterBody3D
## Don Ramón, el dueño de casa.
##
## Duerme en su cama con un nivel de alerta de 0 a 100. Cada ruido que oye lo sube y el silencio
## lo baja de a poco. Al llegar a 100 se levanta, prende la luz, va a ver qué fue el ruido y,
## si ve a alguien, lo persigue. Al que atrapa lo echa a la calle (y llama a la policía).
## Si no encuentra a nadie, vuelve a la cama... con el sueño más liviano.
##
## La inteligencia corre solo en el anfitrión. Los clientes reciben posición, giro, estado
## y alerta, y con eso muestran la pose, los "Zzz" y la linterna.

signal woke_up(blame_peer: int)           # se despertó (y quién hizo más ruido)
signal caught(peer: int)                  # atrapó a un ladrón
signal spotted(peer: int)                 # vio a alguien y lo empezó a perseguir

enum State { SLEEP, WAKING, INVESTIGATE, SEARCH, CHASE, RETURN }

const EYE := 1.6
const REACH := 0.45         # distancia a la que da por alcanzado un punto del camino

var world: World
var server_side := false

var state: State = State.SLEEP
var alert := 0.0
var sleep_mult := 1.0       # sube cada vez que se vuelve a dormir
var wakes := 0

# --- solo en el anfitrión ---
var _astar := AStar3D.new()
var _node_pos: Array[Vector3] = []
var _path: Array[Vector3] = []
var _state_time := 0.0
var _noise_pos := Vector3.ZERO
var _noise_heard := 0.0       # qué tan fuerte fue el ruido que va a investigar
var _quiet_time := 0.0        # segundos sin oír nada
var _blame := {}              # peer -> ruido aportado hace poco
var _target_peer := 0
var _last_seen := Vector3.ZERO
var _unseen_time := 0.0
var _view_timer := 0.0
var _stuck_time := 0.0
var _last_pos := Vector3.ZERO
var _look_yaw := 0.0

# --- en cada computadora ---
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _visual: Node3D
var model: CharacterModel
var _prev_pos := Vector3.ZERO
var _speed := 0.0            # medida por el movimiento (así sirve igual en los clientes)
var _icon: Label3D
var _flashlight: SpotLight3D
var _snore: AudioStreamPlayer3D
var _shape: CollisionShape3D
var _shown_state := -1
var _stage := 0               # 0 profundo, 1 inquieto, 2 medio despierto (para efectos)
var _mumble_timer := 0.0
var _anim := 0.0

func setup(w: World, is_server: bool) -> void:
	world = w
	server_side = is_server
	name = "Owner"

func _ready() -> void:
	collision_layer = Config.L_OWNER
	collision_mask = Config.L_WORLD
	floor_snap_length = 0.3
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	_shape.shape = capsule
	_shape.position = Vector3(0, 0.875, 0)
	add_child(_shape)
	_build_visual()
	_build_graph()
	_snore = Sfx.make_loop("snore", self, -4.0)
	_snore.unit_size = 4.0
	_snore.position = Vector3(1.6, 0.0, 0)
	reset()

## Vuelve a dormir en la cama, como al empezar la noche.
func reset() -> void:
	state = State.SLEEP
	alert = 0.0
	sleep_mult = 1.0
	wakes = 0
	_path.clear()
	_blame.clear()
	_target_peer = 0
	_lie_down()

func _lie_down() -> void:
	global_position = HouseBuilder.BED_LYING
	_net_pos = global_position
	velocity = Vector3.ZERO
	rotation.y = 0.0
	_net_yaw = 0.0
	_shape.disabled = true

# ---------------------------------------------------------------- modelo

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	model = CharacterModel.create("ramon")
	_visual.add_child(model)
	# Linterna (solo se prende cuando anda despierto).
	var torch := Node3D.new()
	torch.position = Vector3(-0.25, 1.15, -0.3)
	_visual.add_child(torch)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	model.skeleton().add_child(hand)
	Mats.add_cylinder(hand, 0.025, 0.18, Vector3(0, 0.09, 0.03), Color(0.2, 0.2, 0.22), Vector3.ZERO, 8)
	_flashlight = SpotLight3D.new()
	_flashlight.light_color = Color(1.0, 0.95, 0.8)
	_flashlight.light_energy = 0.0
	_flashlight.spot_range = 16.0
	_flashlight.spot_angle = 26.0
	_flashlight.shadow_enabled = true
	_flashlight.position = Vector3(0, 0, -0.12)
	torch.add_child(_flashlight)
	_icon = Label3D.new()
	_icon.position = Vector3(0, 2.3, 0)
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.font_size = 72
	_icon.pixel_size = 0.006
	_icon.outline_size = 12
	_icon.no_depth_test = true
	add_child(_icon)

func _update_pose(delta: float) -> void:
	_anim += delta
	var moved := global_position - _prev_pos
	_prev_pos = global_position
	_speed = lerpf(_speed, Vector2(moved.x, moved.z).length() / maxf(delta, 0.0001), clampf(delta * 8.0, 0.0, 1.0))
	var lying := state == State.SLEEP
	if lying:
		_visual.rotation_degrees = HouseBuilder.BED_LYING_ROT
		_visual.position = Vector3(0, -0.05, 0)      # metido bajo la frazada
		# Respira tranquilo; cuanto más inquieto, más se mueve.
		var wiggle := 0.0 if _stage == 0 else sin(_anim * 3.0) * 4.0 * _stage
		_visual.rotation_degrees.z = wiggle
		model.play("Idle", 0.35 + 0.3 * _stage, 0.0)
	elif state == State.WAKING:
		# Parado al lado de la cama, mirando hacia la puerta.
		_visual.rotation_degrees = Vector3(0, 90, 0)
		_visual.position = HouseBuilder.WAYPOINTS["cama"] - global_position + Vector3(0, 0.03, 0)
		model.play("Idle_Talking")
	else:
		_visual.rotation_degrees = Vector3(0, 0, 0)
		_visual.position = Vector3.ZERO
		var spd := _speed
		if spd > Config.OWNER_WALK + 0.3:
			model.play("Jog_Fwd", clampf(spd / 3.5, 0.8, 1.4))
		elif spd > 0.3:
			model.play("Walk", clampf(spd / 1.4, 0.7, 1.4))
		else:
			model.play("Idle_Torch")
	# Ícono sobre la cabeza.
	var icon_pos := Vector3(1.4, 0.7, 0) if lying else Vector3(0, 2.3, 0)
	if state == State.WAKING:
		icon_pos = HouseBuilder.WAYPOINTS["cama"] - global_position + Vector3(0, 2.3, 0)
	_icon.position = icon_pos
	match state:
		State.SLEEP:
			_icon.text = ["z Z z", "?", "? !"][_stage]
			_icon.modulate = [Color(0.7, 0.8, 1.0, 0.8), Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.2)][_stage]
			_icon.position.y += sin(_anim * 1.5) * 0.06
		State.WAKING, State.INVESTIGATE, State.SEARCH, State.RETURN:
			_icon.text = "?!" if state != State.RETURN else "..."
			_icon.modulate = Color(1.0, 0.6, 0.2)
		State.CHASE:
			_icon.text = "!!"
			_icon.modulate = Color(1.0, 0.2, 0.15)
	var awake := state != State.SLEEP
	_flashlight.light_energy = 3.0 if awake and state != State.WAKING else 0.0
	# Dormido se ve a través de las paredes (para saber cómo está); despierto, no: así sorprende.
	_icon.no_depth_test = not awake

## Etapa del sueño según la alerta: 0 profundo, 1 inquieto, 2 medio despierto.
static func stage_of(value: float) -> int:
	if value >= Config.ALERT_STIRRING:
		return 2
	if value >= Config.ALERT_RESTLESS:
		return 1
	return 0

## Para la interfaz.
func status_text() -> String:
	match state:
		State.SLEEP:
			return ["Duerme profundo", "Se mueve en la cama...", "¡Está por despertarse!"][stage_of(alert)]
		State.WAKING:
			return "¡SE DESPERTÓ!"
		State.INVESTIGATE:
			return "Anda buscando de dónde vino el ruido"
		State.SEARCH:
			return "Está mirando para todos lados"
		State.CHASE:
			return "¡LOS VIO! ¡CORRAN!"
		State.RETURN:
			return "Vuelve a la cama, refunfuñando"
	return ""

func is_awake() -> bool:
	return state != State.SLEEP

# ---------------------------------------------------------------- red

func set_net_state(pos: Vector3, yaw: float, new_state: int, new_alert: float) -> void:
	_net_pos = pos
	_net_yaw = yaw
	state = new_state as State
	alert = new_alert

func get_net_state() -> Array:
	return [global_position, rotation.y, int(state), alert]

func _physics_process(delta: float) -> void:
	if server_side:
		_server_tick(delta)
	else:
		var t := 1.0 - exp(-14.0 * delta)
		global_position = global_position.lerp(_net_pos, t)
		rotation.y = lerp_angle(rotation.y, _net_yaw, t)

func _process(delta: float) -> void:
	var new_stage := stage_of(alert)
	if state == State.SLEEP and new_stage > _stage:
		Sfx.play_at("mumble", global_position + Vector3(1.4, 0.3, 0), 2.0, 0.9 + 0.15 * new_stage)
		_mumble_timer = 4.0
	_stage = new_stage
	if state != _shown_state:
		_on_state_shown(_shown_state, state)
		_shown_state = state
	# Ronca solo cuando duerme profundo; inquieto murmura de vez en cuando.
	var should_snore := state == State.SLEEP and _stage == 0
	if should_snore and not _snore.playing:
		_snore.play()
	elif not should_snore and _snore.playing:
		_snore.stop()
	if state == State.SLEEP and _stage > 0:
		_mumble_timer -= delta
		if _mumble_timer <= 0.0:
			_mumble_timer = randf_range(3.0, 6.0)
			Sfx.play_at("mumble", global_position + Vector3(1.4, 0.3, 0), -2.0, randf_range(0.8, 1.1))
	_update_pose(delta)

## Efectos de cada cambio de estado (en todas las computadoras).
func _on_state_shown(old: int, now_state: State) -> void:
	if now_state == State.WAKING:
		Sfx.play_at("shout", HouseBuilder.BED_SIT + Vector3(0, 1.4, 0), 6.0)
	elif now_state == State.CHASE:
		Sfx.play_at("shout", global_position + Vector3(0, 1.6, 0), 8.0, 1.2)
	elif now_state == State.SLEEP and old != -1:
		Sfx.play_at("mumble", HouseBuilder.BED_LYING + Vector3(1.4, 0.3, 0), 0.0, 0.7)

# ---------------------------------------------------------------- oído

## Un ruido en `pos` de fuerza `loudness` (0..1+). `weight` es cuánto dura (ver Config).
## Devuelve cuánto subió la alerta (para las estadísticas de quién hizo más ruido).
func hear(pos: Vector3, loudness: float, weight: float, peer: int) -> float:
	if loudness <= 0.0:
		return 0.0
	var ear := global_position + Vector3(0, 0.3 if state == State.SLEEP else EYE, 0)
	if state == State.SLEEP:
		ear = HouseBuilder.BED_LYING + Vector3(1.5, 0.2, 0)
	var d := pos.distance_to(ear)
	var att := 1.0 / (1.0 + pow(d / Config.HEARING_DISTANCE, 2.0))
	var walls := world.count_walls(pos, ear)
	var heard := loudness * att * pow(Config.WALL_FACTOR, walls)
	if state == State.SLEEP:
		var add := maxf(heard - Config.HEARING_FLOOR, 0.0) * Config.ALERT_GAIN * weight * sleep_mult
		if add <= 0.0:
			return 0.0
		alert = minf(alert + add, Config.ALERT_WAKE)
		_quiet_time = 0.0
		_blame[peer] = float(_blame.get(peer, 0.0)) + add
		if heard >= _noise_heard * 0.7:
			_noise_pos = pos
			_noise_heard = heard
		return add
	# Despierto: un ruido fuerte lo hace ir a ver (si no está persiguiendo a alguien).
	if heard > 0.12 and state != State.CHASE and state != State.WAKING:
		_noise_pos = pos
		_go_investigate()
	return 0.0

# ---------------------------------------------------------------- inteligencia (anfitrión)

func _build_graph() -> void:
	var names: Array = HouseBuilder.WAYPOINTS.keys()
	for i in names.size():
		var p: Vector3 = HouseBuilder.WAYPOINTS[names[i]]
		_astar.add_point(i, p)
		_node_pos.append(p)
	for e: Array in HouseBuilder.EDGES:
		_astar.connect_points(names.find(e[0]), names.find(e[1]))

func _server_tick(delta: float) -> void:
	if world.night_over():
		return
	_state_time += delta
	match state:
		State.SLEEP:
			_tick_sleep(delta)
		State.WAKING:
			if _state_time > 1.6:
				_shape.disabled = false
				global_position = HouseBuilder.WAYPOINTS["cama"] + Vector3(0, 0.05, 0)
				rotation.y = PI * 0.5   # mirando hacia la puerta (-X)
				_go_investigate()
		State.INVESTIGATE:
			_look_for_thieves(delta)
			if _follow_path(delta, Config.OWNER_WALK):
				_set_state(State.SEARCH)
				_look_yaw = rotation.y
		State.SEARCH:
			velocity = Vector3(0, velocity.y, 0)
			_apply_gravity(delta)
			move_and_slide()
			rotation.y = _look_yaw + sin(_state_time * 1.6) * 1.4
			_look_for_thieves(delta)
			if state == State.SEARCH and _state_time > Config.OWNER_SEARCH_TIME:
				_set_state(State.RETURN)
				_path = _plan(HouseBuilder.WAYPOINTS["cama"])
		State.CHASE:
			_tick_chase(delta)
		State.RETURN:
			_look_for_thieves(delta)
			if state == State.RETURN and _follow_path(delta, Config.OWNER_WALK):
				_go_to_sleep()

func _set_state(s: State) -> void:
	state = s
	_state_time = 0.0

func _tick_sleep(delta: float) -> void:
	if alert >= Config.ALERT_WAKE:
		_wake()
		return
	_quiet_time += delta
	if _quiet_time > 1.0:
		alert = maxf(alert - Config.ALERT_DECAY * delta, 0.0)
	for peer: int in _blame.keys():
		_blame[peer] = float(_blame[peer]) * pow(0.85, delta)
	_noise_heard *= pow(0.7, delta)
	# Medio despierto: si ve a alguien moviéndose en la pieza, se levanta de una.
	if alert >= Config.ALERT_STIRRING:
		_view_timer -= delta
		if _view_timer <= 0.0:
			_view_timer = 0.25
			var eye := HouseBuilder.BED_LYING + Vector3(1.5, 0.35, 0)
			for peer: int in world.players:
				var p: Player = world.players[peer]
				var pos := world.player_position(peer)
				if pos.distance_to(eye) > 5.5 or not HouseBuilder.room_name(pos) == "el dormitorio":
					continue
				if (p.net_flags & Player.F_MOVING) == 0 or (p.net_flags & Player.F_CROUCH) != 0:
					continue
				if world.line_clear(eye, pos + Vector3(0, 1.4, 0)):
					_noise_pos = pos
					_blame[peer] = float(_blame.get(peer, 0.0)) + 50.0
					alert = Config.ALERT_WAKE
					break
	if alert >= Config.ALERT_WAKE:
		_wake()

func _wake() -> void:
	wakes += 1
	var blame := 0
	var best := 0.0
	for peer: int in _blame:
		if float(_blame[peer]) > best:
			best = _blame[peer]
			blame = peer
	_blame.clear()
	_set_state(State.WAKING)
	woke_up.emit(blame)

func _go_investigate() -> void:
	_set_state(State.INVESTIGATE)
	_path = _plan(_noise_pos)

func _go_to_sleep() -> void:
	sleep_mult *= Config.LIGHTER_SLEEP
	alert = 45.0
	_noise_heard = 0.0
	_set_state(State.SLEEP)
	_lie_down()

func _tick_chase(delta: float) -> void:
	var target := world.player_position(_target_peer)
	var p: Player = world.players.get(_target_peer)
	if target == Vector3.INF or p == null or p.ejected:
		_set_state(State.SEARCH)
		_look_yaw = rotation.y
		return
	var eye := global_position + Vector3(0, EYE, 0)
	var sees := _can_see(peer_eye(_target_peer), eye, p)
	if sees:
		_last_seen = target
		_unseen_time = 0.0
	else:
		_unseen_time += delta
	if global_position.distance_to(target) < Config.OWNER_CATCH and sees:
		caught.emit(_target_peer)
		_target_peer = 0
		_set_state(State.SEARCH)
		_look_yaw = rotation.y
		return
	if sees and world.line_clear(eye - Vector3(0, 1.2, 0), target + Vector3(0, 0.4, 0), false):
		_path = [target]
		_follow_path(delta, Config.OWNER_RUN)
	elif _unseen_time > Config.OWNER_LOSE_TIME:
		# Lo perdió: va al último lugar donde lo vio y se pone a buscar.
		_noise_pos = _last_seen
		_go_investigate()
	else:
		if _path.is_empty() or _path.back().distance_to(_last_seen) > 1.0:
			_path = _plan(_last_seen)
		_follow_path(delta, Config.OWNER_RUN)
	# Mientras persigue, si ve a otro más cerca, cambia de presa.
	_look_for_thieves(delta)

func peer_eye(peer: int) -> Vector3:
	var p: Player = world.players.get(peer)
	var crouch := p != null and (p.net_flags & Player.F_CROUCH) != 0
	return world.player_position(peer) + Vector3(0, 1.0 if crouch else 1.55, 0)

## ¿Ve a este jugador? Cono de visión, distancia (menos si está agachado, más si tiene la linterna
## prendida) y nada en el medio (paredes, puertas o muebles).
func _can_see(target_eye: Vector3, eye: Vector3, p: Player) -> bool:
	# Arriba del camión no lo ve (va metido en la cabina o en la caja).
	if p.seat >= 0:
		return false
	var to := target_eye - eye
	var d := to.length()
	var flags := p.net_flags
	var view := Config.OWNER_VIEW_RANGE
	if (flags & Player.F_LIGHT) != 0:
		view = Config.OWNER_VIEW_RANGE_LIGHT
	elif (flags & Player.F_CROUCH) != 0:
		view = Config.OWNER_VIEW_RANGE_CROUCH
	if d > view:
		return false
	var forward := -global_transform.basis.z
	var flat := Vector3(to.x, 0, to.z).normalized()
	if rad_to_deg(forward.angle_to(flat)) > Config.OWNER_VIEW_ANGLE:
		# De reojo: una linterna prendida cerca, o alguien parado al lado, se nota igual.
		var crouch := (flags & Player.F_CROUCH) != 0
		var lit := (flags & Player.F_LIGHT) != 0 and d < Config.OWNER_GLANCE_LIGHT
		if not lit and d > (Config.OWNER_GLANCE_CROUCH if crouch else Config.OWNER_GLANCE):
			return false
	return world.line_clear(eye, target_eye)

func _look_for_thieves(delta: float) -> void:
	_view_timer -= delta
	if _view_timer > 0.0:
		return
	_view_timer = 0.15
	var eye := global_position + Vector3(0, EYE, 0)
	var best := 0
	var best_d := INF
	for peer: int in world.players:
		var p: Player = world.players[peer]
		if p.ejected:
			continue
		var target := peer_eye(peer)
		if _can_see(target, eye, p):
			var d := target.distance_to(eye)
			if d < best_d:
				best_d = d
				best = peer
	if best == 0 or (state == State.CHASE and best == _target_peer):
		return
	var was_chasing := state == State.CHASE
	_target_peer = best
	_last_seen = world.player_position(best)
	_unseen_time = 0.0
	_set_state(State.CHASE)
	if not was_chasing:
		spotted.emit(best)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	else:
		velocity.y = 0.0

## Camina por el camino. Devuelve true al llegar al final.
func _follow_path(delta: float, speed: float) -> bool:
	_apply_gravity(delta)
	if _path.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return true
	var next: Vector3 = _path[0]
	var to := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if to.length() < REACH:
		_path.remove_at(0)
		return _path.is_empty()
	var dir := to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 8.0, 0.0, 1.0))
	_open_doors_ahead(dir)
	# Si se trabó contra algo, salta al siguiente punto (mejor eso que quedarse quieto).
	if global_position.distance_to(_last_pos) < speed * delta * 0.2:
		_stuck_time += delta
		if _stuck_time > 1.2:
			_stuck_time = 0.0
			global_position = Vector3(next.x, global_position.y, next.z)
	else:
		_stuck_time = 0.0
	_last_pos = global_position
	return false

## Abre las puertas cerradas que tiene adelante (las atraviesa, pero así se ve que entra).
func _open_doors_ahead(dir: Vector3) -> void:
	for door: Door in world.doors:
		if door.is_open:
			continue
		var c := door.center()
		var to := Vector3(c.x - global_position.x, 0, c.z - global_position.z)
		if to.length() < 1.3 and (to.length() < 0.5 or to.normalized().dot(dir) > 0.3):
			world.srv_set_door(door.door_id, true, 0)

## Camino del punto actual a `goal`, por los puntos del grafo.
func _plan(goal: Vector3) -> Array[Vector3]:
	var from := _nearest_node(global_position)
	var to := _nearest_node(goal)
	var out: Array[Vector3] = []
	if from >= 0 and to >= 0:
		for p in _astar.get_point_path(from, to):
			out.append(p)
	out.append(Vector3(goal.x, 0, goal.z))
	return out

## Punto del grafo más cercano que se ve desde `pos` (así no elige uno del otro lado de una pared).
func _nearest_node(pos: Vector3) -> int:
	var best := -1
	var best_d := INF
	var fallback := -1
	var fallback_d := INF
	for i in _node_pos.size():
		var p := _node_pos[i]
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d < fallback_d:
			fallback_d = d
			fallback = i
		if d < best_d and world.line_clear(Vector3(pos.x, 1.0, pos.z), Vector3(p.x, 1.0, p.z), false):
			best_d = d
			best = i
	return best if best >= 0 else fallback
