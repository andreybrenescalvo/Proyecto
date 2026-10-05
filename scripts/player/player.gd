class_name Player
extends CharacterBody3D
## Minero en primera persona.
## Cada computadora mueve su propio minero y le pide al anfitrión todo lo demás
## (picar, poner dinamita, agarrar cosas, mover el montacargas).

enum Tool { PICKAXE, DYNAMITE, SUPPORT }

const WALK := 4.5
const SPRINT := 7.0
const JUMP := 5.2
const GRAVITY := 14.0
const MOUSE_SENS := 0.0025
const HOLD_DISTANCE := 2.0
const VIEW_POS := Vector3(0.42, -0.42, -0.7)

var peer_id := 0
var player_name := ""
var is_local := false
var world: World
var color := Color.WHITE

var current_tool: Tool = Tool.PICKAXE:
	set(value):
		current_tool = value
		_show_tool(value)
var charge := 2
var holding_id := 0
var yaw := 0.0
var pitch := 0.0
var stun := 0.0
var prompt := ""          # texto de ayuda que muestra el HUD
var look := {}            # lo que el jugador está mirando (resultado del rayo)

var head: Node3D
var camera: Camera3D
var _viewmodel: Node3D
var _view_tools: Array[Node3D] = []
var _hand_tools: Array[Node3D] = []
var _body_visual: Node3D
var _label: Label3D
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _shake := 0.0
var _pick_cooldown := 0.0
var _send_timer := 0.0
var _swing := 0.0
var _hand: Node3D

func setup(id: int, new_name: String, local: bool, w: World, index: int) -> void:
	peer_id = id
	player_name = new_name
	is_local = local
	world = w
	name = str(id)
	color = Config.PLAYER_COLORS[index % Config.PLAYER_COLORS.size()]

func _ready() -> void:
	collision_layer = Config.L_PLAYER
	collision_mask = (Config.L_WORLD | Config.L_BIG | Config.L_PLAYER) if is_local else 0
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	head = Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	add_child(head)
	_build_body()
	_build_headlamp()
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
		_label.position = Vector3(0, 2.25, 0)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 48
		_label.pixel_size = 0.005
		_label.outline_size = 8
		_label.modulate = color.lightened(0.3)
		add_child(_label)
	_net_pos = global_position
	_select_tool(Tool.PICKAXE)

# ---------------------------------------------------------------- modelos

func _build_body() -> void:
	_body_visual = Node3D.new()
	add_child(_body_visual)
	var skin := Color(0.93, 0.76, 0.6)
	var overall := color.darkened(0.15)
	Mats.add_box(_body_visual, Vector3(0.62, 0.75, 0.36), Vector3(0, 1.08, 0), overall)       # torso
	Mats.add_box(_body_visual, Vector3(0.26, 0.7, 0.3), Vector3(-0.16, 0.35, 0), Color(0.25, 0.27, 0.35))
	Mats.add_box(_body_visual, Vector3(0.26, 0.7, 0.3), Vector3(0.16, 0.35, 0), Color(0.25, 0.27, 0.35))
	Mats.add_box(_body_visual, Vector3(0.18, 0.62, 0.2), Vector3(-0.42, 1.1, 0), overall)
	Mats.add_box(_body_visual, Vector3(0.18, 0.62, 0.2), Vector3(0.42, 1.1, 0), overall)
	# Cabeza, casco con lámpara y bigote (porque sí).
	var head_visual := Node3D.new()
	head.add_child(head_visual)
	Mats.add_box(head_visual, Vector3(0.42, 0.42, 0.4), Vector3(0, -0.02, 0), skin)
	Mats.add_box(head_visual, Vector3(0.5, 0.16, 0.5), Vector3(0, 0.24, 0), Color(0.95, 0.8, 0.15))
	Mats.add_box(head_visual, Vector3(0.58, 0.04, 0.58), Vector3(0, 0.17, 0), Color(0.9, 0.72, 0.1))
	var lamp := Mats.add_box(head_visual, Vector3(0.12, 0.1, 0.06), Vector3(0, 0.22, -0.27), Color(1, 0.95, 0.7))
	lamp.material_override = Mats.color(Color(1, 0.95, 0.7), 0.5, 3.0)
	Mats.add_box(head_visual, Vector3(0.22, 0.06, 0.04), Vector3(0, -0.1, -0.21), Color(0.3, 0.2, 0.12))
	Mats.add_box(head_visual, Vector3(0.06, 0.06, 0.04), Vector3(-0.1, 0.04, -0.21), Color(0.1, 0.1, 0.1))
	Mats.add_box(head_visual, Vector3(0.06, 0.06, 0.04), Vector3(0.1, 0.04, -0.21), Color(0.1, 0.1, 0.1))
	if is_local:
		head_visual.reparent(_body_visual, true)
	# Herramienta en la mano (la ven los demás).
	_hand = Node3D.new()
	_hand.position = Vector3(0.42, 0.85, -0.18)
	_body_visual.add_child(_hand)
	for i in 3:
		var t := _make_tool_model(i)
		t.rotation_degrees = Vector3(-70, 0, 0)
		_hand.add_child(t)
		_hand_tools.append(t)

func _build_headlamp() -> void:
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.93, 0.8)
	lamp.light_energy = 3.0 if is_local else 2.0
	lamp.spot_range = 18.0
	lamp.spot_angle = 34.0
	lamp.spot_attenuation = 0.8
	lamp.position = Vector3(0, 0.22, -0.3)
	head.add_child(lamp)
	if is_local:
		# Luz suave alrededor para que las paredes cercanas no queden negras.
		var fill := OmniLight3D.new()
		fill.light_color = Color(1.0, 0.85, 0.65)
		fill.light_energy = 0.5
		fill.omni_range = 5.0
		fill.position = Vector3(0, 0.2, 0)
		head.add_child(fill)

func _make_tool_model(index: int) -> Node3D:
	var root := Node3D.new()
	match index:
		Tool.PICKAXE:
			Mats.add_cylinder(root, 0.03, 0.8, Vector3(0, 0.0, 0), Color(0.55, 0.38, 0.2), Vector3.ZERO, 6)
			Mats.add_box(root, Vector3(0.62, 0.07, 0.07), Vector3(0, 0.38, 0), Color(0.6, 0.62, 0.66), Vector3(0, 0, 8))
			Mats.add_box(root, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.38, 0), Color(0.4, 0.42, 0.45))
		Tool.DYNAMITE:
			for i in 3:
				Mats.add_cylinder(root, 0.035, 0.36, Vector3((i - 1) * 0.075, 0.1, 0), Color(0.8, 0.15, 0.1), Vector3.ZERO, 8)
			Mats.add_box(root, Vector3(0.26, 0.05, 0.09), Vector3(0, 0.12, 0), Color(0.85, 0.8, 0.65))
			Mats.add_cylinder(root, 0.01, 0.14, Vector3(0, 0.34, 0), Color(0.9, 0.85, 0.7), Vector3.ZERO, 4)
		Tool.SUPPORT:
			Mats.add_box(root, Vector3(0.12, 0.7, 0.12), Vector3(0, 0.1, 0), Color(0.6, 0.42, 0.24))
			Mats.add_box(root, Vector3(0.45, 0.1, 0.13), Vector3(0, 0.45, 0), Color(0.5, 0.35, 0.2))
	return root

func _build_viewmodel() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.position = VIEW_POS
	camera.add_child(_viewmodel)
	for i in 3:
		var t := _make_tool_model(i)
		# El pico se ve de costado, con la punta hacia adelante; lo demás, en la mano.
		t.rotation_degrees = Vector3(-10, -25, 35) if i == Tool.PICKAXE else Vector3(-15, -20, 10)
		t.scale = Vector3.ONE * (0.7 if i == Tool.PICKAXE else 0.55)
		_viewmodel.add_child(t)
		_view_tools.append(t)
		_set_no_shadow(t)

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

func _select_tool(t: Tool) -> void:
	current_tool = t

func _show_tool(t: Tool) -> void:
	for i in _view_tools.size():
		_view_tools[i].visible = i == t
	for i in _hand_tools.size():
		_hand_tools[i].visible = i == t

# ---------------------------------------------------------------- entrada

func can_control() -> bool:
	return is_local and stun <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not is_local or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		yaw -= motion.relative.x * MOUSE_SENS
		pitch = clampf(pitch - motion.relative.y * MOUSE_SENS, -1.5, 1.5)
	elif event.is_action_pressed("tool_pickaxe"):
		_select_tool(Tool.PICKAXE)
	elif event.is_action_pressed("tool_dynamite"):
		_select_tool(Tool.DYNAMITE)
	elif event.is_action_pressed("tool_support"):
		_select_tool(Tool.SUPPORT)
	elif event.is_action_pressed("charge_up"):
		if current_tool == Tool.DYNAMITE:
			charge = mini(charge + 1, Config.MAX_CHARGE)
			Sfx.play_ui("click")
	elif event.is_action_pressed("charge_down"):
		if current_tool == Tool.DYNAMITE:
			charge = maxi(charge - 1, 1)
			Sfx.play_ui("click")

# ---------------------------------------------------------------- física

func _physics_process(delta: float) -> void:
	if is_local:
		_local_physics(delta)
	else:
		_remote_physics(delta)

func _local_physics(delta: float) -> void:
	stun = maxf(stun - delta, 0.0)
	_pick_cooldown = maxf(_pick_cooldown - delta, 0.0)
	rotation.y = yaw
	head.rotation.x = pitch
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input := Vector2.ZERO
	if can_control():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := global_transform.basis * Vector3(input.x, 0.0, input.y)
	var top_speed := SPRINT if Input.is_action_pressed("sprint") else WALK
	var accel := 10.0 if is_on_floor() else 2.5
	velocity.x = move_toward(velocity.x, dir.x * top_speed, accel * top_speed * delta)
	velocity.z = move_toward(velocity.z, dir.z * top_speed, accel * top_speed * delta)
	if can_control() and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP
	move_and_slide()
	if global_position.y < Config.MINE_Y - 25.0:
		teleport(Config.SPAWN_POS)
	_update_look()
	_use_tools()
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 0.05
		world.send_player_state(global_position, yaw, pitch, current_tool)

func _process(delta: float) -> void:
	if not is_local or camera == null:
		return
	# Temblor de cámara (explosiones, derrumbes) e inclinación si está aturdido.
	_shake = maxf(_shake - delta * 1.5, 0.0)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.15
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.15
	camera.rotation.z = lerpf(camera.rotation.z, 0.35 if stun > 0.0 else 0.0, delta * 6.0)
	# Animación de golpe con el pico.
	_swing = maxf(_swing - delta * 4.0, 0.0)
	var s := sin(_swing * PI)
	_viewmodel.rotation_degrees = Vector3(-s * 70.0, 0, s * 10.0)
	_viewmodel.position = VIEW_POS + Vector3(0, -s * 0.1, -s * 0.15)

func _remote_physics(delta: float) -> void:
	var t := 1.0 - exp(-14.0 * delta)
	global_position = global_position.lerp(_net_pos, t)
	rotation.y = lerp_angle(rotation.y, _net_yaw, t)
	head.rotation.x = lerpf(head.rotation.x, _net_pitch, t)

func set_net_state(pos: Vector3, new_yaw: float, new_pitch: float, tool_id: int) -> void:
	_net_pos = pos
	_net_yaw = new_yaw
	_net_pitch = new_pitch
	if tool_id != current_tool:
		_select_tool(tool_id as Tool)

## Posición, giro, inclinación y herramienta (lo que se manda por red).
func get_state() -> Array:
	if is_local:
		return [global_position, yaw, pitch, current_tool]
	return [_net_pos, _net_yaw, _net_pitch, current_tool]

func teleport(pos: Vector3) -> void:
	global_position = pos
	_net_pos = pos
	velocity = Vector3.ZERO

func apply_knockback(impulse: Vector3, stun_time: float) -> void:
	velocity += impulse
	stun = maxf(stun, stun_time)
	add_shake(clampf(impulse.length() / 10.0, 0.3, 1.5))

func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

# ---------------------------------------------------------------- mirar e interactuar

func _update_look() -> void:
	look = {}
	var cam := camera.global_transform
	var from := cam.origin
	var to := from - cam.basis.z * Config.INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, Config.L_WORLD | Config.L_SMALL | Config.L_BIG, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_update_prompt()
		return
	var col: Object = hit["collider"]
	look = {"pos": hit["position"], "normal": hit["normal"], "kind": "surface"}
	if col is Entity:
		look["kind"] = "entity"
		look["entity"] = col
	elif col.has_meta("cell"):
		look["kind"] = "cell"
		look["cell"] = col.get_meta("cell")
	elif col.has_meta("interact"):
		look["kind"] = "button"
		look["button"] = col.get_meta("interact")
	_update_prompt()

func _update_prompt() -> void:
	prompt = ""
	if holding_id != 0:
		prompt = "Clic: lanzar   ·   E: soltar"
		return
	var kind: String = look.get("kind", "")
	if kind == "button":
		prompt = _button_prompt(look["button"])
		return
	if kind == "entity":
		var e: Entity = look["entity"]
		if e.is_grabbable():
			prompt = "E: %s %s" % ["empujar" if e.is_heavy() else "agarrar", e.display_name()]
	match current_tool:
		Tool.PICKAXE:
			if kind == "cell":
				var t := world.grid.get_type(look["cell"])
				var info: Dictionary = Config.CELL_INFO.get(t, {})
				if t == Config.Cell.BEDROCK:
					prompt = "Roca madre: no se puede romper"
				elif not info.is_empty():
					prompt = "Clic: picar %s" % String(info["name"]).to_lower()
		Tool.DYNAMITE:
			if kind != "" and prompt == "":
				var p: Vector3 = look["pos"]
				var risk := world.estimate_collapse(p, charge)
				var cost := charge * Config.DYNAMITE_COST
				prompt = "Clic: poner dinamita (%d cartuchos, $%d)" % [charge, cost]
				if MineGrid.in_mine(p):
					prompt += "   ·   Riesgo de derrumbe: %s" % Config.risk_word(risk)
		Tool.SUPPORT:
			if kind != "" and prompt == "":
				if _can_place_support():
					prompt = "Clic: poner puntal ($%d) — baja el riesgo de derrumbe cerca" % Config.SUPPORT_COST
				else:
					prompt = "El puntal va en el piso de la mina"

func _button_prompt(button: String) -> String:
	match button:
		"lift_up_top":
			return "Mantén E: subir montacargas (rápido)"
		"lift_down_top":
			return "Mantén E: bajar montacargas (rápido)"
		"lift_up_bottom":
			return "Mantén E: subir montacargas (lento)"
		"lift_down_bottom":
			return "Mantén E: bajar montacargas (lento)"
		"bell":
			return "E: tocar la campana (avisar arriba)"
	return ""

func _can_place_support() -> bool:
	if look.is_empty():
		return false
	var n: Vector3 = look["normal"]
	var p: Vector3 = look["pos"]
	return n.y > 0.7 and MineGrid.in_mine(p) and look["kind"] == "surface"

func _use_tools() -> void:
	var cam := camera.global_transform
	if holding_id != 0:
		var dist := HOLD_DISTANCE + (0.6 if _holding_heavy() else 0.0)
		world.send_hold_target(holding_id, cam.origin - cam.basis.z * dist)
		if can_control() and Input.is_action_just_pressed("use"):
			world.request_release(holding_id, -cam.basis.z)
			holding_id = 0
		elif can_control() and Input.is_action_just_pressed("interact"):
			world.request_release(holding_id, Vector3.ZERO)
			holding_id = 0
		return
	if not can_control():
		return
	var kind: String = look.get("kind", "")
	# E: botones del montacargas (mantener) o agarrar cosas.
	if kind == "button" and Input.is_action_pressed("interact"):
		var button: String = look["button"]
		if button == "bell":
			if Input.is_action_just_pressed("interact"):
				world.request_bell()
		else:
			var dir := 1 if button.begins_with("lift_up") else -1
			world.send_lift_input(dir, "top" if button.ends_with("top") else "bottom")
	elif kind == "entity" and Input.is_action_just_pressed("interact"):
		var e: Entity = look["entity"]
		if e.is_grabbable():
			world.request_grab(e.entity_id)
	# Clic: usar la herramienta.
	match current_tool:
		Tool.PICKAXE:
			if Input.is_action_pressed("use") and _pick_cooldown <= 0.0:
				_pick_cooldown = Config.PICK_COOLDOWN
				_swing = 1.0
				if kind == "cell":
					var c: Vector2i = look["cell"]
					world.request_pick(c)
					var t := world.grid.get_type(c)
					Sfx.play_at("pick", look["pos"], -4.0, 0.6 if t == Config.Cell.BEDROCK else 1.0)
					Fx.chips(world, look["pos"], Color(0.45, 0.4, 0.35))
					world.grid.shake_cell(c)
				elif kind != "":
					Sfx.play_at("thud", look["pos"], -8.0)
		Tool.DYNAMITE:
			if Input.is_action_just_pressed("use") and kind != "":
				var n: Vector3 = look["normal"]
				var p: Vector3 = look["pos"]
				world.request_dynamite(p + n * 0.16, n, charge)
				_swing = 0.5
		Tool.SUPPORT:
			if Input.is_action_just_pressed("use") and _can_place_support():
				world.request_support(look["pos"])
				_swing = 0.5

func _holding_heavy() -> bool:
	var e: Entity = world.get_entity(holding_id)
	return e != null and e.is_heavy()
