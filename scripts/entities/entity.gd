class_name Entity
extends RigidBody3D
## Objeto físico compartido: trozos de mineral, carrito, dinamita y puntales.
## El anfitrión simula la física de verdad; los demás solo copian la posición que llega por red
## (en los clientes el cuerpo está "congelado" y se mueve suavemente hacia esa posición).

var entity_id := 0
var kind := ""           # "ore", "cart", "dynamite", "support"
var info := {}           # datos extra: {"ore": "iron"}, {"charge": 3, "stuck": true}
var server_side := false

# --- solo en el anfitrión ---
var held_by := 0         # peer que lo está sosteniendo (0 = nadie)
var hold_target := Vector3.ZERO
var hold_stamp := 0.0
var fuse := 0.0          # dinamita: segundos que le quedan a la mecha
var last_sent_pos := Vector3(INF, INF, INF)
var last_sent_rot := Quaternion.IDENTITY
var resend_timer := 0.0

# --- en los clientes ---
var _net_pos := Vector3.ZERO
var _net_rot := Quaternion.IDENTITY

var _spark: CPUParticles3D
var _spark_light: OmniLight3D
var _fuse_sound: AudioStreamPlayer3D

static func create(id: int, new_kind: String, new_info: Dictionary, is_server: bool) -> Entity:
	var e := Entity.new()
	e.entity_id = id
	e.kind = new_kind
	e.info = new_info
	e.server_side = is_server
	e.name = "E%d" % id
	e._build()
	return e

func is_grabbable() -> bool:
	return kind == "ore" or kind == "cart" or kind == "dynamite"

func is_heavy() -> bool:
	return kind == "cart"

## Nombre para mostrar en pantalla.
func display_name() -> String:
	match kind:
		"ore":
			var ore: Dictionary = Config.ORES[info.get("ore", "coal")]
			return "%s ($%d)" % [ore["name"], ore["value"]]
		"cart":
			return "carrito"
		"dynamite":
			return "dinamita encendida (%d)" % int(info.get("charge", 1))
		"support":
			return "puntal"
	return kind

func ore_value() -> int:
	if kind != "ore":
		return 0
	return int(Config.ORES[info.get("ore", "coal")]["value"])

func _build() -> void:
	can_sleep = true
	continuous_cd = kind == "ore" or kind == "dynamite"
	var phys := PhysicsMaterial.new()
	phys.friction = 0.8
	phys.bounce = 0.05
	physics_material_override = phys
	match kind:
		"ore":
			_build_ore()
		"cart":
			_build_cart()
		"dynamite":
			_build_dynamite()
		"support":
			_build_support()
	if not server_side:
		# Cliente: no simula, solo sigue lo que manda el anfitrión.
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
	elif kind == "support" or (kind == "dynamite" and info.get("stuck", false)):
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true

func _add_shape(shape: Shape3D, pos := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)

func _box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b

func _build_ore() -> void:
	mass = 2.0
	collision_layer = Config.L_SMALL
	collision_mask = Config.L_WORLD | Config.L_SMALL | Config.L_BIG | Config.L_PLAYER
	_add_shape(_box(Vector3(0.38, 0.38, 0.38)))
	var ore: Dictionary = Config.ORES[info.get("ore", "coal")]
	var c: Color = ore["color"]
	var shiny: bool = info.get("ore", "") == "gold" or info.get("ore", "") == "silver"
	Mats.add_box(self, Vector3(0.36, 0.34, 0.36), Vector3.ZERO, Color(0.36, 0.31, 0.27))
	var crystal := Mats.add_box(self, Vector3(0.24, 0.3, 0.24), Vector3(0.06, 0.06, 0.02), c, Vector3(20, 35, 10))
	crystal.material_override = Mats.color(c, 0.3 if shiny else 0.8, 0.35 if shiny else 0.0, 0.6 if shiny else 0.0)
	var crystal2 := Mats.add_box(self, Vector3(0.18, 0.22, 0.18), Vector3(-0.08, 0.1, -0.06), c, Vector3(-25, 10, 30))
	crystal2.material_override = crystal.material_override

func _build_cart() -> void:
	mass = 30.0
	collision_layer = Config.L_BIG
	collision_mask = Config.L_WORLD | Config.L_SMALL | Config.L_BIG | Config.L_PLAYER
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.15, 0)
	angular_damp = 1.0
	var wood := Color(0.5, 0.34, 0.2)
	var iron := Color(0.25, 0.26, 0.28)
	# Base con ruedas, piso y cuatro paredes (la colisión es la misma forma).
	_add_shape(_box(Vector3(1.3, 0.2, 0.8)), Vector3(0, 0.12, 0))
	_add_shape(_box(Vector3(1.5, 0.1, 1.0)), Vector3(0, 0.27, 0))
	_add_shape(_box(Vector3(0.08, 0.6, 1.0)), Vector3(0.71, 0.6, 0))
	_add_shape(_box(Vector3(0.08, 0.6, 1.0)), Vector3(-0.71, 0.6, 0))
	_add_shape(_box(Vector3(1.5, 0.6, 0.08)), Vector3(0, 0.6, 0.46))
	_add_shape(_box(Vector3(1.5, 0.6, 0.08)), Vector3(0, 0.6, -0.46))
	Mats.add_box(self, Vector3(1.3, 0.12, 0.8), Vector3(0, 0.16, 0), iron)
	Mats.add_box(self, Vector3(1.5, 0.1, 1.0), Vector3(0, 0.27, 0), wood)
	Mats.add_box(self, Vector3(0.08, 0.6, 1.0), Vector3(0.71, 0.6, 0), wood)
	Mats.add_box(self, Vector3(0.08, 0.6, 1.0), Vector3(-0.71, 0.6, 0), wood)
	Mats.add_box(self, Vector3(1.5, 0.6, 0.08), Vector3(0, 0.6, 0.46), wood.darkened(0.1))
	Mats.add_box(self, Vector3(1.5, 0.6, 0.08), Vector3(0, 0.6, -0.46), wood.darkened(0.1))
	for sx in [-0.45, 0.45]:
		for sz in [-0.45, 0.45]:
			Mats.add_cylinder(self, 0.13, 0.08, Vector3(sx, 0.13, sz * 1.05), iron, Vector3(90, 0, 0), 10)
	# Bandas de hierro en las esquinas.
	for sx in [-0.72, 0.72]:
		for sz in [-0.47, 0.47]:
			Mats.add_box(self, Vector3(0.1, 0.62, 0.1), Vector3(sx, 0.6, sz), iron)

func _build_dynamite() -> void:
	mass = 0.6
	collision_layer = Config.L_SMALL
	collision_mask = Config.L_WORLD | Config.L_SMALL | Config.L_BIG | Config.L_PLAYER
	_add_shape(_box(Vector3(0.3, 0.42, 0.22)))
	fuse = float(info.get("fuse", Config.FUSE_TIME))
	var charge := int(info.get("charge", 1))
	var red := Color(0.8, 0.15, 0.1)
	for i in charge:
		var x := (i - (charge - 1) * 0.5) * 0.075
		Mats.add_cylinder(self, 0.035, 0.38, Vector3(x, 0, 0.0), red.darkened(0.1 * (i % 2)), Vector3.ZERO, 8)
	Mats.add_box(self, Vector3(0.08 * charge + 0.04, 0.06, 0.09), Vector3(0, 0.05, 0), Color(0.85, 0.8, 0.65))
	Mats.add_cylinder(self, 0.01, 0.16, Vector3(0, 0.26, 0), Color(0.9, 0.85, 0.7), Vector3(0, 0, 18), 4)
	# Chispas de la mecha.
	_spark = CPUParticles3D.new()
	_spark.amount = 14
	_spark.lifetime = 0.35
	_spark.mesh = Mats.box_mesh(Vector3(0.025, 0.025, 0.025))
	_spark.material_override = Mats.unshaded(Color(1.0, 0.8, 0.3))
	_spark.direction = Vector3.UP
	_spark.spread = 60.0
	_spark.initial_velocity_min = 0.8
	_spark.initial_velocity_max = 2.0
	_spark.gravity = Vector3(0, -6, 0)
	_spark.position = Vector3(0.02, 0.34, 0)
	add_child(_spark)
	_spark_light = OmniLight3D.new()
	_spark_light.light_color = Color(1.0, 0.6, 0.25)
	_spark_light.light_energy = 1.5
	_spark_light.omni_range = 4.0
	_spark_light.position = Vector3(0, 0.4, 0)
	add_child(_spark_light)

func _build_support() -> void:
	mass = 20.0
	collision_layer = Config.L_BIG
	collision_mask = 0
	var h := Config.CELL_HEIGHT
	_add_shape(_box(Vector3(0.28, h, 0.28)), Vector3(0, h * 0.5, 0))
	var wood := Color(0.6, 0.42, 0.24)
	Mats.add_box(self, Vector3(0.28, h - 0.25, 0.28), Vector3(0, (h - 0.25) * 0.5, 0), wood)
	Mats.add_box(self, Vector3(1.8, 0.25, 0.32), Vector3(0, h - 0.125, 0), wood.darkened(0.15))
	Mats.add_box(self, Vector3(0.5, 0.2, 0.5), Vector3(0, 0.1, 0), wood.darkened(0.25))

func _ready() -> void:
	_net_pos = global_position
	_net_rot = global_transform.basis.get_rotation_quaternion()
	if kind == "dynamite":
		_fuse_sound = Sfx.make_loop("fuse", self, -6.0)
		_fuse_sound.play()

## Llega una posición nueva desde el anfitrión.
func set_net_transform(pos: Vector3, rot: Quaternion) -> void:
	_net_pos = pos
	_net_rot = rot

func _physics_process(delta: float) -> void:
	if kind == "dynamite":
		_update_fuse_fx(delta)
	if server_side:
		return
	var t := 1.0 - exp(-18.0 * delta)
	var current := global_transform
	var rot := current.basis.get_rotation_quaternion().slerp(_net_rot, t)
	global_transform = Transform3D(Basis(rot), current.origin.lerp(_net_pos, t))

func _update_fuse_fx(delta: float) -> void:
	fuse = maxf(fuse - delta, 0.0)
	if _spark_light:
		# Parpadea cada vez más rápido cuando queda poca mecha.
		var urgency := 1.0 - clampf(fuse / Config.FUSE_TIME, 0.0, 1.0)
		_spark_light.light_energy = 1.2 + randf() * (1.0 + urgency * 2.5)

## Física de "sostener": el objeto va hacia el punto que mira el jugador.
## Lo llama el anfitrión en cada paso de física mientras alguien lo tiene agarrado.
func server_hold_step(delta: float) -> void:
	var to := hold_target - global_position
	if is_heavy():
		to.y = 0.0
		var desired := (to * 6.0).limit_length(3.5)
		desired.y = linear_velocity.y
		linear_velocity = linear_velocity.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
		angular_velocity *= 0.9
	else:
		var desired := (to * 12.0).limit_length(14.0)
		linear_velocity = linear_velocity.lerp(desired, clampf(delta * 20.0, 0.0, 1.0))
		angular_velocity *= 0.85

## ¿Se movió lo suficiente como para mandarlo por red?
func needs_sync(delta: float) -> bool:
	if freeze and freeze_mode == RigidBody3D.FREEZE_MODE_STATIC:
		return false
	resend_timer -= delta
	var rot := global_transform.basis.get_rotation_quaternion()
	if resend_timer <= 0.0:
		return true
	return global_position.distance_squared_to(last_sent_pos) > 0.0001 or rot.angle_to(last_sent_rot) > 0.01

func mark_sent() -> void:
	last_sent_pos = global_position
	last_sent_rot = global_transform.basis.get_rotation_quaternion()
	resend_timer = 1.5
