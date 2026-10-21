class_name Player
extends CharacterBody3D
## Ladrón (perdón, "mudancero") en primera persona.
## Cada computadora mueve su propio jugador y le pide al anfitrión todo lo demás
## (agarrar cosas, abrir puertas, subirse al camión y manejarlo).

# Lo que se manda por red de cada jugador (y lo que mira el dueño para verlos u oírlos).
const F_CROUCH := 1
const F_LIGHT := 2
const F_MOVING := 4
const F_SPRINT := 8
const F_SEATED := 16      # va arriba del camión (no se ve ni hace ruido de pasos)

const JUMP := 4.6
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const HOLD_DISTANCE := 1.5
const EYE_STAND := 1.6
const EYE_CROUCH := 1.0
const VIEW_POS := Vector3(0.22, -0.2, -0.38)
## Sentado en la computadora: altura del asiento, de los ojos y cuánto mira para abajo (al monitor).
const COMPUTER_SEAT_HEIGHT := 0.46
const COMPUTER_EYE := 0.72
const COMPUTER_PITCH := -0.24

var peer_id := 0
var player_name := ""
var is_local := false
var world: World
var color := Color.WHITE
var slot := 0             # número de jugador (elige color y modelo)
var model: CharacterModel

var holding_id := 0
var yaw := 0.0
var pitch := 0.0
var stun := 0.0
var crouching := false
var flashlight_on := true
var net_flags := 0        # banderas F_* (del propio jugador o las que llegan por red)
var voice := 0.0          # nivel de voz 0..1 (en los remotos, lo que llega por red)
var ejected := false      # (anfitrión) lo acaban de echar: el dueño no lo persigue por un rato
var prompt := ""          # texto de ayuda que muestra el HUD
var look := {}            # lo que el jugador está mirando (resultado del rayo)
var seat := -1            # asiento en el camión (-1 = a pie, 0 = manejando)
var at_computer := false  # sentado en la computadora del galpón

var head: Node3D
var camera: Camera3D
var _viewmodel: Node3D
var _body_visual: Node3D
var _label: Label3D
var _voice_label: Label3D
var _light: SpotLight3D
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _shake := 0.0
var _send_timer := 0.0
var _step_timer := 0.0
var _bob := 0.0

func setup(id: int, new_name: String, local: bool, w: World, index: int) -> void:
	peer_id = id
	player_name = new_name
	is_local = local
	world = w
	name = str(id)
	color = Config.PLAYER_COLORS[index % Config.PLAYER_COLORS.size()]
	slot = index

func _ready() -> void:
	collision_layer = Config.L_PLAYER
	collision_mask = (Config.L_WORLD | Config.L_BIG | Config.L_PLAYER | Config.L_DOOR | Config.L_OWNER) if is_local else 0
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3(0, 0.875, 0)
	add_child(shape)

	head = Node3D.new()
	head.position = Vector3(0, EYE_STAND, 0)
	add_child(head)
	_build_body()
	_light = SpotLight3D.new()
	_light.light_color = Color(1.0, 0.95, 0.82)
	_light.spot_range = 16.0
	_light.spot_angle = 28.0
	_light.spot_attenuation = 0.9
	_light.shadow_enabled = is_local
	_light.shadow_bias = 0.4
	_light.shadow_normal_bias = 3.0
	_light.position = Vector3(0.18, -0.12, -0.25)
	head.add_child(_light)
	if is_local:
		camera = Camera3D.new()
		camera.fov = 80.0
		camera.near = 0.05
		head.add_child(camera)
		camera.make_current()
		_build_viewmodel()
		# El cuerpo propio no se ve, pero sí su sombra.
		_set_shadow_only(_body_visual)
	else:
		_label = Label3D.new()
		_label.text = player_name
		_label.position = Vector3(0, 2.15, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 44
		_label.pixel_size = 0.005
		_label.outline_size = 8
		_label.modulate = color.lightened(0.3)
		add_child(_label)
		_voice_label = Label3D.new()
		_voice_label.text = "((  ))"
		_voice_label.position = Vector3(0, 2.42, 0)
		_voice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_voice_label.font_size = 48
		_voice_label.pixel_size = 0.005
		_voice_label.outline_size = 8
		_voice_label.visible = false
		add_child(_voice_label)
	_net_pos = global_position
	_update_light()

# ---------------------------------------------------------------- modelos

func _build_body() -> void:
	_body_visual = Node3D.new()
	add_child(_body_visual)
	model = CharacterModel.create(CharacterModel.PLAYER_MODELS[slot % CharacterModel.PLAYER_MODELS.size()])
	_body_visual.add_child(model)

## La animación según lo que hace (vale para el propio y para los que llegan por red).
func _animate(in_air := false) -> void:
	model.set_typing(at_computer)
	if seat >= 0 or at_computer:
		model.play("Sitting_Idle")
		return
	model.update_from((net_flags & F_MOVING) != 0, (net_flags & F_SPRINT) != 0, (net_flags & F_CROUCH) != 0,
			(net_flags & F_LIGHT) != 0, in_air)

func _build_viewmodel() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.position = VIEW_POS
	camera.add_child(_viewmodel)
	Mats.add_cylinder(_viewmodel, 0.022, 0.2, Vector3(0, 0.0, -0.01), Color(0.25, 0.25, 0.28), Vector3(90, 0, 0), 8)
	var lens := Mats.add_cylinder(_viewmodel, 0.03, 0.03, Vector3(0, 0.0, -0.12), Color(1, 0.95, 0.8), Vector3(90, 0, 0), 8)
	lens.name = "Lens"
	_set_no_shadow(_viewmodel)

func _set_shadow_only(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_set_shadow_only(child)

func _set_no_shadow(node: Node) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_set_no_shadow(child)

func _update_light() -> void:
	var on := (net_flags & F_LIGHT) != 0 if not is_local else flashlight_on
	_light.light_energy = (2.6 if is_local else 1.8) if on else 0.0
	if _viewmodel:
		var lens := _viewmodel.get_node("Lens") as MeshInstance3D
		lens.material_override = Mats.color(Color(1, 0.95, 0.8), 0.5, 3.0) if on else Mats.color(Color(0.4, 0.4, 0.38))

# ---------------------------------------------------------------- entrada

func can_control() -> bool:
	return is_local and stun <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not world.night_over()

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * MOUSE_SENS
		pitch = clampf(pitch - motion.relative.y * MOUSE_SENS, -1.5, 1.5)
	elif event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		Sfx.play_ui("click")
		_update_light()

# ---------------------------------------------------------------- física

func _physics_process(delta: float) -> void:
	if is_local:
		_local_physics(delta)
	else:
		_remote_physics(delta)

func carry_factor() -> float:
	var e: Entity = world.get_entity(holding_id) if holding_id != 0 else null
	return e.slow_factor() if e else 1.0

func _local_physics(delta: float) -> void:
	stun = maxf(stun - delta, 0.0)
	if seat >= 0:
		_seated_physics()
		return
	if at_computer:
		_computer_physics()
		return
	rotation.y = yaw
	head.rotation.x = pitch
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input := Vector2.ZERO
	if can_control():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	crouching = can_control() and Input.is_action_pressed("crouch")
	var holding_heavy := _holding_heavy()
	var sprinting := can_control() and Input.is_action_pressed("sprint") and not crouching and not holding_heavy and input.length() > 0.1
	var dir := global_transform.basis * Vector3(input.x, 0.0, input.y)
	var top_speed := Config.CROUCH if crouching else (Config.SPRINT if sprinting else Config.WALK)
	top_speed *= carry_factor()
	var accel := 10.0 if is_on_floor() else 2.5
	velocity.x = move_toward(velocity.x, dir.x * top_speed, accel * top_speed * delta)
	velocity.z = move_toward(velocity.z, dir.z * top_speed, accel * top_speed * delta)
	if can_control() and is_on_floor() and Input.is_action_just_pressed("jump") and not holding_heavy and not crouching:
		velocity.y = JUMP
	move_and_slide()
	head.position.y = lerpf(head.position.y, EYE_CROUCH if crouching else EYE_STAND, clampf(delta * 10.0, 0.0, 1.0))
	if global_position.y < -10.0:
		teleport(HouseBuilder.SPAWNS[0])
	var moving := Vector2(velocity.x, velocity.z).length() > 0.6 and is_on_floor()
	net_flags = (F_CROUCH if crouching else 0) | (F_LIGHT if flashlight_on else 0) \
			| (F_MOVING if moving else 0) | (F_SPRINT if sprinting and moving else 0)
	voice = Voice.level
	_animate(not is_on_floor())
	_footsteps(delta)
	_update_look()
	_use_hands(delta)
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 0.05
		world.send_player_state(global_position, yaw, pitch, net_flags, voice)

## Arriba del camión: el cuerpo va con el asiento y, si maneja, manda acelerador y volante.
func _seated_physics() -> void:
	velocity = Vector3.ZERO
	global_position = world.truck.seat_position(seat)
	net_flags = F_SEATED | (F_LIGHT if flashlight_on else 0)
	voice = Voice.level
	# Si no tiene el control (menú abierto), no manda nada: al rato el camión suelta todo solo.
	if can_control():
		if seat == 0:
			world.send_drive_input(Input.get_axis("move_back", "move_forward"),
					Input.get_axis("move_right", "move_left"), Input.is_action_pressed("jump"))
		if Input.is_action_just_pressed("interact"):
			world.request_seat("exit")
	_update_seated_prompt()
	_send_timer -= get_physics_process_delta_time()
	if _send_timer <= 0.0:
		_send_timer = 0.05
		world.send_player_state(global_position, yaw, pitch, net_flags, voice)

## Sentado en la computadora: quieto, mirando el monitor (la pantalla la maneja el HUD).
func _computer_physics() -> void:
	velocity = Vector3.ZERO
	global_position = CityBuilder.COMPUTER_SEAT + Vector3(0, COMPUTER_SEAT_HEIGHT, 0)
	yaw = 0.0
	pitch = COMPUTER_PITCH
	rotation.y = yaw
	head.rotation.x = pitch
	head.position.y = COMPUTER_EYE
	net_flags = F_SEATED
	voice = Voice.level
	prompt = ""
	_animate()
	_send_timer -= get_physics_process_delta_time()
	if _send_timer <= 0.0:
		_send_timer = 0.05
		world.send_player_state(global_position, yaw, pitch, net_flags, voice)

## El anfitrión avisa que se sentó en la computadora (o que se levantó).
func set_at_computer(on: bool) -> void:
	if on == at_computer:
		return
	at_computer = on
	if not is_local:
		return
	collision_layer = 0 if on else Config.L_PLAYER
	collision_mask = 0 if on else (Config.L_WORLD | Config.L_BIG | Config.L_PLAYER | Config.L_DOOR | Config.L_OWNER)
	if on:
		holding_id = 0
	else:
		teleport(CityBuilder.COMPUTER_SEAT + Vector3(0.0, 0.1, 0.9))
		head.position.y = EYE_STAND

func _update_seated_prompt() -> void:
	if world.truck.speed > Config.TRUCK_EXIT_SPEED:
		prompt = "W/S acelerar y frenar · A/D doblar · Espacio freno de mano" if seat == 0 else "Agárrense..."
	elif seat == 0:
		prompt = "W/S acelerar y frenar · A/D doblar · Espacio freno de mano · E bajarse"
		var missing := world.players_away_from_truck()
		if missing > 0:
			prompt += "   ·   faltan %d por subir" % missing
	else:
		prompt = "E: bajarse"

## El anfitrión cambió quién va en el camión.
func set_seat(new_seat: int) -> void:
	if new_seat == seat:
		return
	var old := seat
	seat = new_seat
	var seated := seat >= 0
	if is_local:
		collision_layer = 0 if seated else Config.L_PLAYER
		collision_mask = 0 if seated else (Config.L_WORLD | Config.L_BIG | Config.L_PLAYER | Config.L_DOOR | Config.L_OWNER)
		if seated:
			holding_id = 0
			world.truck.camera.make_current()
		else:
			camera.make_current()
			if old >= 0:
				teleport(world.truck.exit_position(old))
	else:
		visible = not seated

func _process(delta: float) -> void:
	if not is_local:
		_update_voice_label()
		return
	if camera == null:
		return
	# Temblor de cámara y cabeza ladeada si lo acaban de echar.
	_shake = maxf(_shake - delta * 1.5, 0.0)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.12
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.12
	camera.rotation.z = lerpf(camera.rotation.z, 0.4 if stun > 0.0 else 0.0, delta * 6.0)
	# La mano con la linterna se balancea al caminar.
	if (net_flags & F_MOVING) != 0:
		_bob += delta * (12.0 if (net_flags & F_SPRINT) != 0 else 8.0)
	_viewmodel.position = VIEW_POS + Vector3(sin(_bob) * 0.012, absf(cos(_bob)) * 0.015, 0)

## Pasos: suenan en esta computadora (el anfitrión calcula aparte si el dueño los oye).
func _footsteps(delta: float) -> void:
	if (net_flags & F_MOVING) == 0:
		_step_timer = 0.15
		return
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	if (net_flags & F_CROUCH) != 0:
		_step_timer = Config.STEP_INTERVAL_CROUCH
		Sfx.play_at("step", global_position, -24.0, 0.8)
	elif (net_flags & F_SPRINT) != 0:
		_step_timer = Config.STEP_INTERVAL_SPRINT
		Sfx.play_at("step", global_position, -6.0, 0.9)
	else:
		_step_timer = Config.STEP_INTERVAL_WALK
		Sfx.play_at("step", global_position, -14.0)

func _remote_physics(delta: float) -> void:
	var t := 1.0 - exp(-14.0 * delta)
	global_position = global_position.lerp(_net_pos, t)
	rotation.y = lerp_angle(rotation.y, _net_yaw, t)
	head.rotation.x = lerpf(head.rotation.x, _net_pitch, t)
	head.position.y = lerpf(head.position.y, EYE_CROUCH if (net_flags & F_CROUCH) != 0 else EYE_STAND, clampf(delta * 10.0, 0.0, 1.0))
	_animate()
	_footsteps(delta)

func _update_voice_label() -> void:
	var talking := voice > 0.1
	_voice_label.visible = talking
	if talking:
		_voice_label.text = "(( ))" if voice < 0.3 else ("((( )))" if voice < 0.6 else "(((( ! ))))")
		_voice_label.modulate = Color(1, 1, 1).lerp(Color(1, 0.3, 0.2), clampf(voice * 1.4, 0, 1))

func set_net_state(pos: Vector3, new_yaw: float, new_pitch: float, flags: int, level: float) -> void:
	_net_pos = pos
	_net_yaw = new_yaw
	_net_pitch = new_pitch
	voice = level
	if flags != net_flags:
		net_flags = flags
		_update_light()

## Posición, giro, inclinación, banderas y voz (lo que se manda por red).
func get_state() -> Array:
	if is_local:
		return [global_position, yaw, pitch, net_flags, voice]
	return [_net_pos, _net_yaw, _net_pitch, net_flags, voice]

func teleport(pos: Vector3) -> void:
	global_position = pos
	_net_pos = pos
	velocity = Vector3.ZERO

func apply_knockback(impulse: Vector3, stun_time: float) -> void:
	velocity += impulse
	stun = maxf(stun, stun_time)
	add_shake(clampf(impulse.length() / 8.0, 0.3, 1.5))

func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

# ---------------------------------------------------------------- mirar e interactuar

func _update_look() -> void:
	look = {}
	var cam := camera.global_transform
	var from := cam.origin
	var to := from - cam.basis.z * Config.INTERACT_RANGE
	var mask := Config.L_WORLD | Config.L_SMALL | Config.L_BIG | Config.L_DOOR
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var col: Object = hit["collider"]
		look = {"pos": hit["position"], "kind": "surface"}
		if col is Truck:
			var action := (col as Truck).button_at(hit["shape"])
			if action != "":
				look["kind"] = "button"
				look["button"] = action
		elif col is Entity:
			look["kind"] = "entity"
			look["entity"] = col
		elif col.has_meta("door"):
			look["kind"] = "door"
			look["door"] = col.get_meta("door")
		elif col.has_meta("interact"):
			look["kind"] = "button"
			look["button"] = col.get_meta("interact")
	_update_prompt()

func _update_prompt() -> void:
	prompt = ""
	if stun > 0.0:
		return
	if holding_id != 0:
		var e: Entity = world.get_entity(holding_id)
		if e and e.is_heavy():
			if e.carriers >= 2:
				prompt = "Lo cargan entre %d: ¡así sí!   ·   E: soltar" % e.carriers
			else:
				prompt = "Arrastrándolo solo: ¡hace ruido! Que alguien te ayude   ·   E: soltar"
		else:
			prompt = "Clic: lanzar (¡hace ruido!)   ·   E: soltar"
		return
	var kind: String = look.get("kind", "")
	match kind:
		"entity":
			var e: Entity = look["entity"]
			prompt = "E: agarrar %s" % e.display_name()
			if e.is_heavy():
				prompt += "   ·   pesado: entre dos se levanta"
			elif e.is_fragile():
				prompt += "   ·   frágil"
		"door":
			var d: Door = world.get_door(look["door"])
			if d:
				prompt = "E: %s la %s" % [d.action_word(), d.door_name]
				if d.creak >= 0.5:
					prompt += "   ·   ¡chilla!"
		"button":
			match look["button"]:
				"truck_drive":
					prompt = "E: manejar el camión" if world.truck.driver == 0 else "E: subirse al camión"
				"truck_ride":
					prompt = "E: subirse al camión"
				"computer":
					var user := world.computer_user()
					if user == 0:
						prompt = "E: usar la computadora (venderle al Flaco)"
					else:
						prompt = "Ocupada: la está usando %s" % world.player_names.get(user, "otro")

func _use_hands(_delta: float) -> void:
	var cam := camera.global_transform
	if holding_id != 0:
		var e: Entity = world.get_entity(holding_id)
		var target := cam.origin - cam.basis.z * HOLD_DISTANCE
		if e and e.is_heavy():
			var fwd := -cam.basis.z
			fwd.y = 0.0
			target = global_position + fwd.normalized() * 1.1 + Vector3(0, 0.9, 0)
		world.send_hold_target(holding_id, target)
		if can_control() and Input.is_action_just_pressed("use") and not (e and e.is_heavy()):
			world.request_release(holding_id, -cam.basis.z)
			holding_id = 0
		elif can_control() and Input.is_action_just_pressed("interact"):
			world.request_release(holding_id, Vector3.ZERO)
			holding_id = 0
		return
	var kind: String = look.get("kind", "")
	if not can_control() or not Input.is_action_just_pressed("interact"):
		return
	if kind == "button" and look["button"] == "computer":
		world.request_computer("sit")
	elif kind == "button":
		world.request_seat(look["button"])
	elif kind == "entity":
		world.request_grab((look["entity"] as Entity).entity_id)
	elif kind == "door":
		world.request_door(look["door"])

func _holding_heavy() -> bool:
	var e: Entity = world.get_entity(holding_id) if holding_id != 0 else null
	return e != null and e.is_heavy()
