class_name Door
extends Node3D
## Puerta con bisagra. El anfitrión decide si está abierta; cada computadora anima el giro.
## El nodo está en la bisagra y la hoja sale hacia +X (local). `open_sign` dice hacia qué lado gira.

const HEIGHT := 2.05
const OPEN_ANGLE := 95.0
const SPEED := 3.2      # radianes por segundo

var door_id := 0
var door_name := ""
var is_open := false
var creak := 0.3        # qué tan fuerte chilla (0..1): es el ruido que oye el dueño
var width := 1.0
var open_sign := 1.0

var _hinge: Node3D
var _panel: AnimatableBody3D
var _angle := 0.0

static func create(id: int, label: String, hinge_pos: Vector3, base_rot_deg: float, w: float, open_dir: float, loud: float) -> Door:
	var d := Door.new()
	d.door_id = id
	d.door_name = label
	d.name = "Door%d" % id
	d.position = hinge_pos
	d.rotation_degrees.y = base_rot_deg
	d.width = w
	d.open_sign = open_dir
	d.creak = loud
	return d

func _ready() -> void:
	_hinge = Node3D.new()
	add_child(_hinge)
	_panel = AnimatableBody3D.new()
	_panel.collision_layer = Config.L_DOOR
	_panel.collision_mask = 0
	_panel.position = Vector3(width * 0.5, HEIGHT * 0.5, 0)
	_panel.set_meta("door", door_id)
	_hinge.add_child(_panel)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.04, HEIGHT, 0.06)
	shape.shape = box
	_panel.add_child(shape)
	var wood := Color(0.55, 0.36, 0.22) if creak < 0.5 else Color(0.48, 0.3, 0.2)
	Mats.add_box(_panel, Vector3(width - 0.04, HEIGHT, 0.05), Vector3.ZERO, wood)
	Mats.add_box(_panel, Vector3(width - 0.24, 0.7, 0.06), Vector3(0, 0.45, 0), wood.darkened(0.12))
	Mats.add_box(_panel, Vector3(width - 0.24, 0.7, 0.06), Vector3(0, -0.45, 0), wood.darkened(0.12))
	for side in [-1.0, 1.0]:
		Mats.add_box(_panel, Vector3(0.05, 0.05, 0.08), Vector3(width * 0.5 - 0.12, 0.0, side * 0.05), Color(0.85, 0.75, 0.3))

func set_open(value: bool) -> void:
	is_open = value

## Para la ayuda en pantalla.
func action_word() -> String:
	return "cerrar" if is_open else "abrir"

## Centro del vano (por donde pasa la gente).
func center() -> Vector3:
	return global_transform * Vector3(width * 0.5, 0, 0)

func _physics_process(delta: float) -> void:
	var target := deg_to_rad(OPEN_ANGLE) * open_sign if is_open else 0.0
	_angle = move_toward(_angle, target, SPEED * delta)
	_hinge.rotation.y = _angle
