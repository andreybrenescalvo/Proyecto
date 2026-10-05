class_name Lift
extends AnimatableBody3D
## Montacargas del pozo. Lo simula el anfitrión; los demás reciben la altura por red.
##
## Se maneja manteniendo E sobre los botones de los paneles:
##  - Panel de arriba: rápido (LIFT_FAST). Si frena de golpe o llega al tope muy rápido,
##    lo que va encima sale volando (el carrito "se descarrila").
##  - Panel de abajo: lento pero seguro (LIFT_SLOW).

signal hard_stop(speed: float)   # frenada brusca: el mundo sacude lo que va arriba

const SIZE := 3.7
const WHEEL_Y := 8.6   # altura de la rueda de la torre

var height := Config.LIFT_TOP
var speed := 0.0
var server_side := false
var _inputs := {}           # peer -> {"dir": int, "max": float, "t": float}
var _net_height := Config.LIFT_TOP
var _net_speed := 0.0
var _motor: AudioStreamPlayer3D
var _time := 0.0
var _driving := false
var _cable: MeshInstance3D

func _ready() -> void:
	sync_to_physics = true
	collision_layer = Config.L_WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, 0.3, SIZE)
	shape.shape = box
	shape.position = Vector3(0, -0.15, 0)
	add_child(shape)
	_build_visual()
	_motor = Sfx.make_loop("motor", self, -10.0)
	position = Vector3(0, height, 0)

func _build_visual() -> void:
	var wood := Color(0.55, 0.38, 0.22)
	var metal := Color(0.3, 0.32, 0.35)
	Mats.add_box(self, Vector3(SIZE, 0.3, SIZE), Vector3(0, -0.15, 0), wood)
	for i in 5:
		Mats.add_box(self, Vector3(SIZE, 0.04, 0.08), Vector3(0, 0.01, -1.6 + i * 0.8), wood.darkened(0.25))
	# Postes de las esquinas y marco superior (jaula abierta por los costados X).
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Mats.add_box(self, Vector3(0.14, 2.6, 0.14), Vector3(sx * (SIZE * 0.5 - 0.07), 1.3, sz * (SIZE * 0.5 - 0.07)), metal)
	for sz in [-1.0, 1.0]:
		Mats.add_box(self, Vector3(SIZE, 0.12, 0.12), Vector3(0, 2.6, sz * (SIZE * 0.5 - 0.07)), metal)
		Mats.add_box(self, Vector3(SIZE, 0.08, 0.08), Vector3(0, 1.0, sz * (SIZE * 0.5 - 0.07)), metal)
	Mats.add_box(self, Vector3(0.12, 0.12, SIZE), Vector3(0, 2.6, 0), metal)
	# Cable hasta la rueda de la torre (se estira en _update_cable).
	_cable = Mats.add_cylinder(self, 0.04, 1.0, Vector3.ZERO, Color(0.15, 0.15, 0.15), Vector3.ZERO, 4)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 1.2
	lamp.omni_range = 6.0
	lamp.position = Vector3(0, 2.4, 0)
	add_child(lamp)
	Mats.add_box(self, Vector3(0.25, 0.2, 0.25), Vector3(0, 2.45, 0), Color(1.0, 0.85, 0.5)).material_override = Mats.color(Color(1.0, 0.85, 0.5), 0.5, 2.0)

## El anfitrión registra que alguien mantiene apretado un botón.
func set_input(peer: int, dir: int, panel: String) -> void:
	_inputs[peer] = {
		"dir": clampi(dir, -1, 1),
		"max": Config.LIFT_FAST if panel == "top" else Config.LIFT_SLOW,
		"t": _time,
	}

func set_net_state(h: float, s: float) -> void:
	_net_height = h
	_net_speed = s

func _physics_process(delta: float) -> void:
	_time += delta
	if server_side:
		_simulate(delta)
	else:
		# Cliente: seguir la altura que manda el anfitrión, adelantándose un poco con la velocidad.
		_net_height += _net_speed * delta
		height = lerpf(height, _net_height, 1.0 - exp(-12.0 * delta))
		speed = _net_speed
	position = Vector3(0, height, 0)
	_update_cable()
	_update_motor_sound()

func _update_cable() -> void:
	var length := maxf(WHEEL_Y - height - 2.6, 0.1)
	_cable.scale = Vector3(1, length, 1)
	_cable.position = Vector3(0, 2.6 + length * 0.5, 0)

func _simulate(delta: float) -> void:
	var dir := 0
	var max_speed := 0.0
	for peer in _inputs.keys():
		var inp: Dictionary = _inputs[peer]
		if _time - float(inp["t"]) > 0.25:
			_inputs.erase(peer)
			continue
		dir += int(inp["dir"])
		max_speed = maxf(max_speed, float(inp["max"]))
	dir = signi(dir)
	var target := dir * max_speed
	if dir == 0:
		# Soltar el botón a toda velocidad = frenazo.
		if _driving and absf(speed) > Config.LIFT_DERAIL_SPEED:
			hard_stop.emit(speed)
		speed = move_toward(speed, 0.0, Config.LIFT_BRAKE * delta)
	else:
		speed = move_toward(speed, target, Config.LIFT_ACCEL * delta)
	_driving = dir != 0
	height += speed * delta
	if height >= Config.LIFT_TOP:
		height = Config.LIFT_TOP
		if speed > Config.LIFT_DERAIL_SPEED:
			hard_stop.emit(speed)
		speed = minf(speed, 0.0)
	elif height <= Config.LIFT_BOTTOM:
		height = Config.LIFT_BOTTOM
		if speed < -Config.LIFT_DERAIL_SPEED:
			hard_stop.emit(speed)
		speed = maxf(speed, 0.0)

func _update_motor_sound() -> void:
	if _motor == null:
		return
	var moving := absf(speed) > 0.05
	if moving and not _motor.playing:
		_motor.play()
	elif not moving and _motor.playing:
		_motor.stop()
	_motor.pitch_scale = 0.7 + absf(speed) * 0.12

## ¿El punto está encima de la plataforma (dentro de la jaula)?
func is_on_platform(p: Vector3) -> bool:
	return absf(p.x) < SIZE * 0.5 and absf(p.z) < SIZE * 0.5 and p.y > height - 0.3 and p.y < height + 2.8
