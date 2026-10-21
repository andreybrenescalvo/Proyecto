class_name Entity
extends RigidBody3D
## Objeto físico de la casa: lo que se roba (televisor, joyero, caja fuerte...) y lo que solo
## hace ruido (sillas, platos, ollas). Los datos de cada uno están en Config.ITEMS.
##
## El anfitrión simula la física de verdad; los demás solo copian la posición que llega por red
## (en los clientes el cuerpo está "congelado" y se mueve suavemente hacia esa posición).

## Choque fuerte (solo en el anfitrión): `speed` es el cambio de velocidad en ese paso de física.
signal impact(e: Entity, speed: float)

const HOLD_TIMEOUT := 0.6       # si un jugador deja de mandar su punto de agarre, lo suelta
const DRAG_SPEED := 1.4         # pesado con una sola persona: se arrastra
const LIFT_SPEED := 3.2         # pesado entre dos o más: se levanta

var entity_id := 0
var kind := "item"
var info := {}           # {"item": "tv", "hung": true}
var item_id := ""
var data := {}           # la ficha de Config.ITEMS
var server_side := false
var main_color := Color.GRAY
var carriers := 0        # cuántos lo tienen agarrado (lo saben todos: frena al que lo lleva)

# --- solo en el anfitrión ---
var holders := {}        # peer -> [punto al que lo lleva, momento del último aviso]
var last_holder := 0     # quién lo tocó por última vez (para las estadísticas)
var quiet_until := 0.0   # al aparecer se acomoda: esos golpes no hacen ruido
var dragging := false    # se está arrastrando (lo usa la partida para el ruido)
var last_sent_pos := Vector3(INF, INF, INF)
var last_sent_rot := Quaternion.IDENTITY
var resend_timer := 0.0
var _prev_vel := Vector3.ZERO
var _skip_impact := 0

# --- en los clientes ---
var _net_pos := Vector3.ZERO
var _net_rot := Quaternion.IDENTITY
var _ride: Node3D = null              # si va en la caja del camión: la posición llega relativa a él
var _net_local := Transform3D.IDENTITY

static func create(id: int, new_kind: String, new_info: Dictionary, is_server: bool) -> Entity:
	var e := Entity.new()
	e.entity_id = id
	e.kind = new_kind
	e.info = new_info
	e.item_id = String(new_info.get("item", "pot"))
	e.data = Config.item(e.item_id)
	e.server_side = is_server
	e.name = "E%d" % id
	e._build()
	return e

func is_grabbable() -> bool:
	return true

func is_heavy() -> bool:
	return bool(data.get("heavy", false))

func is_fragile() -> bool:
	return bool(data.get("fragile", false))

## Precio: el de la ficha, menos lo que perdió por cada golpe fuerte.
func value() -> int:
	var v := int(data.get("value", 0))
	if v <= 1:
		return v
	return roundi(v * (1.0 - Config.DENT_LOSS * dents()))

## Cuántos golpes fuertes tiene (viaja en `info`, así lo saben todos).
func dents() -> int:
	return int(info.get("dents", 0))

## Cuánto frena al que lo lleva (1 = nada).
func slow_factor() -> float:
	if is_heavy():
		return 0.35 if carriers <= 1 else 0.6
	return float(data.get("slow", 1.0))

## Nombre para mostrar en pantalla.
func display_name() -> String:
	var n: String = data.get("name", item_id)
	if dents() > 0:
		n += " (con golpes)"
	return "%s ($%d)" % [n, value()] if value() > 1 else n.to_lower()

func _build() -> void:
	mass = float(data.get("mass", 1.0))
	can_sleep = true
	continuous_cd = mass < 3.0
	var phys := PhysicsMaterial.new()
	phys.friction = 0.9 if is_heavy() else 0.7
	phys.bounce = 0.05
	physics_material_override = phys
	collision_layer = Config.L_BIG if is_heavy() else Config.L_SMALL
	collision_mask = Config.L_WORLD | Config.L_SMALL | Config.L_BIG | Config.L_PLAYER | Config.L_DOOR | Config.L_OWNER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.get("size", Vector3(0.3, 0.3, 0.3))
	cs.shape = box
	add_child(cs)
	angular_damp = 1.5 if is_heavy() else 0.5
	_build_visual()
	if not server_side:
		# Cliente: no simula, solo sigue lo que manda el anfitrión.
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
	else:
		contact_monitor = true
		max_contacts_reported = 4
		if info.get("hung", false):
			freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			freeze = true

func _ready() -> void:
	_net_pos = global_position
	_net_rot = global_transform.basis.get_rotation_quaternion()

# ---------------------------------------------------------------- modelos

func _box(size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return Mats.add_box(self, size, pos, c, rot)

func _cyl(r: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO, sides := 10) -> MeshInstance3D:
	return Mats.add_cylinder(self, r, h, pos, c, rot, sides)

## Textura pegada al objeto (no al mundo: así no "resbala" cuando se mueve).
func _skin(mi: MeshInstance3D, tex_name: String, c: Color, meters := 0.5, rough := 0.75) -> MeshInstance3D:
	mi.material_override = Mats.tex(tex_name, c, meters, false, rough)
	return mi

func _glow(mi: MeshInstance3D, c: Color, energy := 1.5) -> void:
	mi.material_override = Mats.color(c, 0.4, energy)

func _shiny(mi: MeshInstance3D, c: Color) -> void:
	mi.material_override = Mats.color(c, 0.25, 0.15, 0.85)

func _build_visual() -> void:
	var s: Vector3 = data.get("size", Vector3(0.3, 0.3, 0.3))
	var h := s * 0.5
	match item_id:
		"tv":
			main_color = Color(0.12, 0.12, 0.13)
			_skin(_box(s, Vector3.ZERO, main_color), "plastic", main_color, 0.5, 0.35)
			_glow(_box(Vector3(0.01, s.y - 0.08, s.z - 0.08), Vector3(h.x + 0.003, 0, 0), Color(0.08, 0.1, 0.16)), Color(0.08, 0.1, 0.16), 0.3)
		"console":
			main_color = Color(0.1, 0.1, 0.11)
			_skin(_box(s, Vector3.ZERO, main_color), "plastic", main_color, 0.5, 0.3)
			_glow(_box(Vector3(0.01, 0.01, s.z * 0.6), Vector3(h.x + 0.004, 0.01, 0), Color(0.2, 0.5, 1.0)), Color(0.2, 0.5, 1.0), 2.5)
		"sofa":
			main_color = Color(0.32, 0.46, 0.36)
			_skin(_box(Vector3(s.x, 0.4, s.z), Vector3(0, -0.2, 0), main_color), "fabric", main_color, 0.4, 1.0)
			_skin(_box(Vector3(0.25, 0.42, s.z), Vector3(h.x - 0.125, 0.2, 0), main_color), "fabric", main_color.darkened(0.1), 0.4, 1.0)
			for side in [-1.0, 1.0]:
				_skin(_box(Vector3(s.x, 0.22, 0.2), Vector3(0, 0.1, side * (h.z - 0.1)), main_color), "fabric", main_color.darkened(0.15), 0.4, 1.0)
			for z in [-0.5, 0.5]:
				_skin(_box(Vector3(0.6, 0.12, 0.88), Vector3(-0.1, 0.06, z), main_color), "fabric", main_color.lightened(0.1), 0.4, 1.0)
		"vase":
			main_color = Color(0.3, 0.45, 0.85)
			_cyl(0.1, s.y * 0.8, Vector3(0, -0.04, 0), main_color)
			_cyl(0.06, s.y * 0.25, Vector3(0, 0.15, 0), Color(0.92, 0.92, 0.95))
		"lamp":
			main_color = Color(0.95, 0.88, 0.7)
			_cyl(0.15, 0.04, Vector3(0, -h.y + 0.02, 0), Color(0.25, 0.25, 0.27))
			_cyl(0.025, s.y - 0.3, Vector3(0, -0.12, 0), Color(0.25, 0.25, 0.27), Vector3.ZERO, 6)
			_skin(_cyl(0.15, 0.28, Vector3(0, h.y - 0.14, 0), main_color), "fabric", main_color, 0.3, 1.0)
		"painting":
			main_color = Color(0.55, 0.42, 0.2)
			_skin(_box(s, Vector3.ZERO, main_color), "wood", Color(0.85, 0.7, 0.45), 0.4, 0.5)
			var hue := float(entity_id % 7) / 7.0
			_box(Vector3(s.x - 0.1, s.y - 0.1, 0.01), Vector3(0, 0, -h.z - 0.002), Color.from_hsv(hue, 0.5, 0.75))
			_box(Vector3(0.18, 0.18, 0.01), Vector3(0.2, 0.12, -h.z - 0.006), Color.from_hsv(fmod(hue + 0.15, 1.0), 0.8, 0.95))
			_box(Vector3(0.6, 0.2, 0.01), Vector3(-0.1, -0.15, -h.z - 0.006), Color.from_hsv(fmod(hue + 0.4, 1.0), 0.6, 0.5), Vector3(0, 0, 12))
		"microwave":
			main_color = Color(0.85, 0.85, 0.85)
			_skin(_box(s, Vector3.ZERO, main_color), "metal", Color(0.95, 0.95, 0.95), 0.5, 0.35)
			_box(Vector3(0.32, 0.22, 0.01), Vector3(-0.06, 0, h.z + 0.004), Color(0.1, 0.1, 0.12))
			_glow(_box(Vector3(0.07, 0.03, 0.01), Vector3(0.17, 0.08, h.z + 0.004), Color(0.3, 1.0, 0.4)), Color(0.3, 1.0, 0.4), 2.0)
		"blender":
			main_color = Color(0.85, 0.3, 0.25)
			_box(Vector3(0.18, 0.12, 0.18), Vector3(0, -h.y + 0.06, 0), main_color)
			_cyl(0.075, 0.22, Vector3(0, 0.06, 0), Color(0.75, 0.85, 0.9))
		"plates":
			main_color = Color(0.95, 0.95, 0.93)
			for i in 4:
				_skin(_cyl(0.15, 0.025, Vector3(0, -h.y + 0.015 + i * 0.03, 0), main_color, Vector3.ZERO, 12), "plastic", main_color.darkened(0.04 * (i % 2)), 0.3, 0.15)
		"pot":
			main_color = Color(0.6, 0.62, 0.66)
			_skin(_cyl(0.15, s.y, Vector3.ZERO, main_color, Vector3.ZERO, 12), "metal", main_color.lightened(0.2), 0.3, 0.25)
			for side in [-1.0, 1.0]:
				_box(Vector3(0.06, 0.03, 0.04), Vector3(side * 0.17, 0.06, 0), Color(0.15, 0.15, 0.15))
		"chair":
			main_color = Color(0.5, 0.35, 0.22)
			var chair_wood := Color(0.85, 0.7, 0.55)
			_skin(_box(Vector3(s.x, 0.05, s.z), Vector3(0, 0, 0), main_color), "wood", chair_wood, 0.4, 0.55)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_skin(_box(Vector3(0.04, h.y, 0.04), Vector3(sx * (h.x - 0.03), -h.y * 0.5, sz * (h.z - 0.03)), main_color), "wood", chair_wood.darkened(0.2), 0.4, 0.55)
			_skin(_box(Vector3(s.x, h.y, 0.05), Vector3(0, h.y * 0.5, h.z - 0.03), main_color), "wood", chair_wood, 0.4, 0.55)
		"jewelry":
			main_color = Color(0.45, 0.15, 0.4)
			_skin(_box(Vector3(s.x, s.y * 0.65, s.z), Vector3(0, -s.y * 0.17, 0), main_color), "fabric", main_color, 0.2, 1.0)
			_skin(_box(Vector3(s.x + 0.01, s.y * 0.35, s.z + 0.01), Vector3(0, s.y * 0.32, 0), main_color), "fabric", main_color.lightened(0.1), 0.2, 1.0)
			_shiny(_box(Vector3(0.06, 0.04, 0.02), Vector3(0, 0.02, h.z + 0.008), Color(1, 0.8, 0.2)), Color(1, 0.8, 0.2))
		"watch":
			main_color = Color(1.0, 0.8, 0.25)
			_shiny(_cyl(0.05, 0.02, Vector3(0, 0.01, 0), main_color, Vector3.ZERO, 12), main_color)
			_box(Vector3(0.04, 0.012, s.z), Vector3(0, -0.01, 0), Color(0.3, 0.2, 0.12))
		"safe":
			main_color = Color(0.22, 0.24, 0.26)
			_skin(_box(s, Vector3.ZERO, main_color), "metal", Color(0.38, 0.4, 0.43), 0.6, 0.45)
			_box(Vector3(0.01, s.y - 0.08, s.z - 0.08), Vector3(h.x + 0.003, 0, 0), main_color.lightened(0.1))
			_shiny(_cyl(0.08, 0.04, Vector3(h.x + 0.02, 0.08, 0), Color(0.8, 0.8, 0.82), Vector3(0, 0, 90), 12), Color(0.8, 0.8, 0.82))
			_shiny(_box(Vector3(0.03, 0.03, 0.18), Vector3(h.x + 0.02, -0.12, 0), Color(0.8, 0.8, 0.82)), Color(0.8, 0.8, 0.82))
		"laptop":
			main_color = Color(0.7, 0.72, 0.75)
			_skin(_box(Vector3(s.x, s.y * 0.5, s.z), Vector3(0, -s.y * 0.25, 0), main_color), "metal", main_color, 0.3, 0.3)
			_skin(_box(Vector3(s.x, s.y * 0.5, s.z), Vector3(0, s.y * 0.25, 0), main_color), "metal", main_color.darkened(0.15), 0.3, 0.3)
			_glow(_box(Vector3(0.05, 0.004, 0.05), Vector3(0, h.y + 0.001, 0), Color(0.9, 0.9, 1.0)), Color(0.9, 0.9, 1.0), 1.0)
		"pc":
			main_color = Color(0.12, 0.12, 0.14)
			_skin(_box(s, Vector3.ZERO, main_color), "plastic", main_color, 0.4, 0.4)
			_glow(_box(Vector3(0.01, 0.3, 0.01), Vector3(-h.x - 0.003, 0, h.z - 0.06), Color(0.9, 0.2, 0.9)), Color(0.9, 0.2, 0.9), 2.0)
		"guitar":
			main_color = Color(0.7, 0.42, 0.18)
			_skin(_box(Vector3(s.x, 0.46, 0.1), Vector3(0, -0.25, 0), main_color), "wood", Color(1.05, 0.8, 0.5), 0.4, 0.3)
			_skin(_box(Vector3(s.x * 0.8, 0.2, 0.1), Vector3(0, -0.02, 0), main_color), "wood", Color(1.05, 0.8, 0.5), 0.4, 0.3)
			_cyl(0.055, 0.012, Vector3(0, -0.15, -0.052), Color(0.08, 0.06, 0.05), Vector3(90, 0, 0), 10)
			_box(Vector3(0.06, 0.5, 0.04), Vector3(0, 0.25, 0), Color(0.3, 0.2, 0.12))
			_box(Vector3(0.09, 0.1, 0.04), Vector3(0, h.y - 0.05, 0), Color(0.15, 0.1, 0.07))
		"trophy":
			main_color = Color(1.0, 0.78, 0.2)
			_skin(_box(Vector3(0.14, 0.06, 0.14), Vector3(0, -h.y + 0.03, 0), Color(0.25, 0.18, 0.12)), "wood", Color(0.5, 0.38, 0.3), 0.2, 0.4)
			_shiny(_cyl(0.02, 0.12, Vector3(0, -0.06, 0), main_color, Vector3.ZERO, 8), main_color)
			_shiny(_cyl(0.07, 0.14, Vector3(0, 0.1, 0), main_color, Vector3.ZERO, 10), main_color)
			for side in [-1.0, 1.0]:
				_shiny(_box(Vector3(0.03, 0.08, 0.02), Vector3(side * 0.08, 0.1, 0), main_color), main_color)
		"office_chair":
			main_color = Color(0.15, 0.15, 0.17)
			_skin(_box(Vector3(0.5, 0.08, 0.5), Vector3(0, -0.05, 0), main_color), "fabric", Color(0.25, 0.25, 0.28), 0.3, 1.0)
			_skin(_box(Vector3(0.48, 0.48, 0.06), Vector3(0, 0.25, 0.22), main_color), "fabric", Color(0.25, 0.25, 0.28), 0.3, 1.0)
			_cyl(0.03, 0.35, Vector3(0, -0.27, 0), Color(0.5, 0.5, 0.52), Vector3.ZERO, 6)
			_box(Vector3(0.5, 0.04, 0.08), Vector3(0, -h.y + 0.04, 0), Color(0.3, 0.3, 0.32))
			_box(Vector3(0.08, 0.04, 0.5), Vector3(0, -h.y + 0.04, 0), Color(0.3, 0.3, 0.32))
		"perfume":
			main_color = Color(0.95, 0.5, 0.75)
			_cyl(0.045, 0.11, Vector3(0, -0.02, 0), main_color, Vector3.ZERO, 8)
			_shiny(_box(Vector3(0.04, 0.04, 0.04), Vector3(0, 0.06, 0), Color(1, 0.8, 0.2)), Color(1, 0.8, 0.2))
		"duck":
			main_color = Color(1.0, 0.85, 0.1)
			_box(Vector3(0.16, 0.1, 0.12), Vector3(0, -0.03, 0), main_color)
			_box(Vector3(0.08, 0.08, 0.08), Vector3(-0.05, 0.05, 0), main_color)
			_box(Vector3(0.05, 0.02, 0.04), Vector3(-0.1, 0.05, 0), Color(1, 0.5, 0.1))
		"photo":
			main_color = Color(0.3, 0.2, 0.12)
			_skin(_box(s, Vector3.ZERO, main_color), "wood", Color(0.55, 0.42, 0.32), 0.2, 0.5)
			_box(Vector3(s.x - 0.04, s.y - 0.04, 0.005), Vector3(0, 0, -h.z - 0.002), Color(0.75, 0.65, 0.55))
			_box(Vector3(0.05, 0.08, 0.004), Vector3(-0.04, -0.02, -h.z - 0.006), Color(0.3, 0.35, 0.5))
			_box(Vector3(0.05, 0.1, 0.004), Vector3(0.04, -0.01, -h.z - 0.006), Color(0.55, 0.3, 0.3))
		_:
			_box(s, Vector3.ZERO, main_color)

# ---------------------------------------------------------------- red

## Llega una posición nueva desde el anfitrión.
func set_net_transform(pos: Vector3, rot: Quaternion) -> void:
	_net_pos = pos
	_net_rot = rot
	_ride = null

## Llega una posición relativa al camión (va en la caja): así viaja pegado a él aunque ande rápido.
func set_net_local(pos: Vector3, rot: Quaternion, vehicle: Node3D) -> void:
	_net_local = Transform3D(Basis(rot), pos)
	_ride = vehicle

func _physics_process(delta: float) -> void:
	if server_side:
		_server_impacts()
		return
	if _ride != null and is_instance_valid(_ride):
		var target := _ride.global_transform * _net_local
		_net_pos = target.origin
		_net_rot = target.basis.get_rotation_quaternion()
		var k := 1.0 - exp(-30.0 * delta)
		global_transform = Transform3D(Basis(global_transform.basis.get_rotation_quaternion().slerp(_net_rot, k)),
				global_position.lerp(_net_pos, k))
		return
	var t := 1.0 - exp(-18.0 * delta)
	var current := global_transform
	var rot := current.basis.get_rotation_quaternion().slerp(_net_rot, t)
	global_transform = Transform3D(Basis(rot), current.origin.lerp(_net_pos, t))

## Golpes: un cambio brusco de velocidad mientras toca algo.
## (Los callbacks de física corren antes de cada paso: la velocidad que se ve acá es la del paso anterior.)
func _server_impacts() -> void:
	var dv := (linear_velocity - _prev_vel).length()
	_prev_vel = linear_velocity
	if _skip_impact > 0:
		_skip_impact -= 1
		return
	if freeze or not holders.is_empty():
		return
	if dv > Config.NOISE_IMPACT_MIN_SPEED and get_contact_count() > 0:
		impact.emit(self, dv)

## La velocidad cambió a propósito (lanzar, soltar): no es un golpe.
func ignore_next_impacts(frames := 2) -> void:
	_skip_impact = frames
	_prev_vel = linear_velocity

## Física de "sostener": el objeto va hacia el punto que mira cada jugador que lo tiene agarrado.
## Lo llama el anfitrión en cada paso de física.
func server_hold_step(delta: float) -> void:
	var target := Vector3.ZERO
	for h: Array in holders.values():
		target += h[0]
	target /= holders.size()
	var to := target - global_position
	dragging = false
	if is_heavy() and holders.size() == 1:
		# Una sola persona: se arrastra por el piso (lento y ruidoso).
		to.y = 0.0
		var desired := (to * 4.0).limit_length(DRAG_SPEED)
		desired.y = minf(linear_velocity.y, 0.0)
		linear_velocity = linear_velocity.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
		angular_velocity *= 0.8
		dragging = Vector2(linear_velocity.x, linear_velocity.z).length() > 0.3
	elif is_heavy():
		# Entre dos o más: se levanta y se lleva.
		var desired := (to * 6.0).limit_length(LIFT_SPEED)
		linear_velocity = linear_velocity.lerp(desired, clampf(delta * 10.0, 0.0, 1.0))
		_keep_upright(delta)
	else:
		var desired := (to * 12.0).limit_length(14.0)
		linear_velocity = linear_velocity.lerp(desired, clampf(delta * 20.0, 0.0, 1.0))
		angular_velocity *= 0.85
	_prev_vel = linear_velocity

## Endereza de a poco un mueble que se está cargando (para que no gire como trompo).
func _keep_upright(delta: float) -> void:
	var up := global_transform.basis.y
	var axis := up.cross(Vector3.UP)
	angular_velocity = angular_velocity.lerp(axis * 6.0, clampf(delta * 8.0, 0.0, 1.0))
	angular_velocity.y *= 0.8

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
