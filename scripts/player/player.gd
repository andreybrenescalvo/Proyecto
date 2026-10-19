class_name Player
extends CharacterBody3D
## Ladrón (perdón, "mudancero") en primera persona.
## Cada computadora mueve su propio jugador y le pide al anfitrión todo lo demás
## (agarrar cosas, abrir puertas, irse con el camión).

# Lo que se manda por red de cada jugador (y lo que mira el dueño para verlos u oírlos).
const F_CROUCH := 1
const F_LIGHT := 2
const F_MOVING := 4
const F_SPRINT := 8

const JUMP := 4.6
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const HOLD_DISTANCE := 1.5
const EYE_STAND := 1.6
const EYE_CROUCH := 1.0
const VIEW_POS := Vector3(0.22, -0.2, -0.38)

var peer_id := 0
var player_name := ""
var is_local := false
var world: World
var color := Color.WHITE

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
var leave_progress := 0.0 # 0..1 mientras mantiene E en la cabina del camión

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
	var suit := color.darkened(0.1)
	var dark := Color(0.12, 0.12, 0.14)
	Mats.add_box(_body_visual, Vector3(0.6, 0.72, 0.36), Vector3(0, 1.08, 0), suit)          # mameluco
	Mats.add_box(_body_visual, Vector3(0.62, 0.08, 0.38), Vector3(0, 0.76, 0), dark)         # cinturón
	Mats.add_box(_body_visual, Vector3(0.25, 0.72, 0.3), Vector3(-0.15, 0.36, 0), suit.darkened(0.15))
	Mats.add_box(_body_visual, Vector3(0.25, 0.72, 0.3), Vector3(0.15, 0.36, 0), suit.darkened(0.15))
	Mats.add_box(_body_visual, Vector3(0.27, 0.12, 0.36), Vector3(-0.15, 0.06, -0.04), dark)
	Mats.add_box(_body_visual, Vector3(0.27, 0.12, 0.36), Vector3(0.15, 0.06, -0.04), dark)
	Mats.add_box(_body_visual, Vector3(0.17, 0.6, 0.2), Vector3(-0.4, 1.1, 0), suit)
	Mats.add_box(_body_visual, Vector3(0.17, 0.6, 0.2), Vector3(0.4, 1.1, 0), suit)
	Mats.add_box(_body_visual, Vector3(0.16, 0.14, 0.18), Vector3(-0.4, 0.75, 0), dark)       # guantes
	Mats.add_box(_body_visual, Vector3(0.16, 0.14, 0.18), Vector3(0.4, 0.75, 0), dark)
	var logo := Label3D.new()
	logo.text = "MT"
	logo.font_size = 64
	logo.pixel_size = 0.004
	logo.outline_size = 6
	logo.position = Vector3(0, 1.15, 0.19)
	logo.modulate = Color(0.95, 0.95, 0.9)
	_body_visual.add_child(logo)
	# Cabeza con pasamontañas (porque son mudanceros muy profesionales).
	var head_visual := Node3D.new()
	head.add_child(head_visual)
	var skin := Color(0.93, 0.76, 0.6)
	Mats.add_box(head_visual, Vector3(0.4, 0.42, 0.38), Vector3(0, -0.02, 0), dark)
	Mats.add_box(head_visual, Vector3(0.32, 0.09, 0.02), Vector3(0, 0.04, -0.19), skin)
	Mats.add_box(head_visual, Vector3(0.06, 0.05, 0.02), Vector3(-0.08, 0.04, -0.2), Color(0.95, 0.95, 0.95))
	Mats.add_box(head_visual, Vector3(0.06, 0.05, 0.02), Vector3(0.08, 0.04, -0.2), Color(0.95, 0.95, 0.95))
	Mats.add_box(head_visual, Vector3(0.025, 0.025, 0.02), Vector3(-0.08, 0.04, -0.212), Color(0.05, 0.05, 0.05))
	Mats.add_box(head_visual, Vector3(0.025, 0.025, 0.02), Vector3(0.08, 0.04, -0.212), Color(0.05, 0.05, 0.05))
	Mats.add_box(head_visual, Vector3(0.42, 0.1, 0.4), Vector3(0, 0.22, 0), color)            # gorro
	Mats.add_box(head_visual, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.3, 0), color.lightened(0.3))
	if is_local:
		head_visual.reparent(_body_visual, true)

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
	_footsteps(delta)
	_update_look()
	_use_hands(delta)
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 0.05
		world.send_player_state(global_position, yaw, pitch, net_flags, voice)

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
	_body_visual.scale.y = lerpf(_body_visual.scale.y, 0.68 if (net_flags & F_CROUCH) != 0 else 1.0, clampf(delta * 10.0, 0.0, 1.0))
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
		if col is Entity:
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
			if look["button"] == "truck_leave":
				prompt = "Mantén E: irse con el camión (termina la noche)"
				var missing := world.players_away_from_truck()
				if missing > 0:
					prompt += "   ·   ¡faltan %d!" % missing

func _use_hands(delta: float) -> void:
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
		leave_progress = 0.0
		return
	var kind: String = look.get("kind", "")
	if kind == "button" and look["button"] == "truck_leave" and can_control() and Input.is_action_pressed("interact"):
		leave_progress += delta / Config.LEAVE_HOLD_TIME
		if leave_progress >= 1.0:
			leave_progress = 0.0
			world.request_leave()
	else:
		leave_progress = 0.0
	if not can_control() or not Input.is_action_just_pressed("interact"):
		return
	if kind == "entity":
		world.request_grab((look["entity"] as Entity).entity_id)
	elif kind == "door":
		world.request_door(look["door"])

func _holding_heavy() -> bool:
	var e: Entity = world.get_entity(holding_id) if holding_id != 0 else null
	return e != null and e.is_heavy()
