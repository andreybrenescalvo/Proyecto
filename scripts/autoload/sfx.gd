extends Node
## Sonidos generados por código (placeholder hasta tener audio de verdad).
## Así el prototipo tiene explosiones, crujidos y golpes sin depender de archivos externos.

const RATE := 22050

var streams := {}

func _ready() -> void:
	streams["boom"] = _make(1.6, _gen_boom)
	streams["pick"] = _make(0.25, _gen_pick)
	streams["thud"] = _make(0.3, _gen_thud)
	streams["creak"] = _make(1.1, _gen_creak)
	streams["rumble"] = _make(2.6, _gen_rumble)
	streams["coin"] = _make(0.35, _gen_coin)
	streams["bell"] = _make(1.4, _gen_bell)
	streams["fuse"] = _make(1.0, _gen_fuse, true)
	streams["motor"] = _make(1.0, _gen_motor, true)
	streams["click"] = _make(0.06, _gen_click)

## Reproduce un sonido en una posición del mundo.
func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or not streams.has(sound):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.unit_size = 8.0
	p.max_distance = 80.0
	scene.add_child(p)
	p.global_position = pos
	p.play()
	_free_later(p, (streams[sound] as AudioStreamWAV).get_length() / pitch + 0.2)

## Reproduce un sonido sin posición (interfaz).
func play_ui(sound: String, volume_db := -6.0) -> void:
	if not streams.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_free_later(p, (streams[sound] as AudioStreamWAV).get_length() + 0.2)

## Crea un reproductor 3D en bucle (mecha, motor) que el llamador maneja.
func make_loop(sound: String, parent: Node3D, volume_db := -8.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.unit_size = 5.0
	p.max_distance = 40.0
	parent.add_child(p)
	return p

func _free_later(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(node.queue_free)

# ---------------------------------------------------------------- generación

func _make(seconds: float, gen: Callable, loop := false) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var state := {"lp": 0.0, "lp2": 0.0, "hp": 0.0, "prev": 0.0}
	for i in n:
		var t := float(i) / RATE
		var v: float = gen.call(t, seconds, state)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s

static func _lowpass(state: Dictionary, key: String, v: float, k: float) -> float:
	var y: float = state[key] + (v - state[key]) * k
	state[key] = y
	return y

func _gen_boom(t: float, _dur: float, st: Dictionary) -> float:
	var noise := randf_range(-1.0, 1.0)
	var low := _lowpass(st, "lp", noise, 0.06)
	low = _lowpass(st, "lp2", low, 0.3)
	var env := exp(-t * 3.2) * minf(t * 200.0, 1.0)
	var thump := sin(TAU * (55.0 - 25.0 * t) * t) * exp(-t * 5.0)
	return (low * 3.2 + thump * 0.8) * env

func _gen_pick(t: float, _dur: float, _st: Dictionary) -> float:
	var ring := sin(TAU * 1850.0 * t) * 0.5 + sin(TAU * 2790.0 * t) * 0.3 + sin(TAU * 4100.0 * t) * 0.2
	var click := randf_range(-1.0, 1.0) * exp(-t * 90.0)
	return ring * exp(-t * 28.0) * 0.7 + click * 0.6

func _gen_thud(t: float, _dur: float, st: Dictionary) -> float:
	var low := _lowpass(st, "lp", randf_range(-1.0, 1.0), 0.08)
	return (low * 2.5 + sin(TAU * 90.0 * t) * 0.5) * exp(-t * 18.0)

func _gen_creak(t: float, dur: float, _st: Dictionary) -> float:
	var f := 70.0 + 35.0 * sin(TAU * 2.3 * t) + 20.0 * sin(TAU * 7.1 * t)
	var saw := fmod(f * t, 1.0) * 2.0 - 1.0
	var env := sin(PI * t / dur) * (0.6 + 0.4 * sin(TAU * 11.0 * t))
	return saw * env * 0.35

func _gen_rumble(t: float, dur: float, st: Dictionary) -> float:
	var low := _lowpass(st, "lp", randf_range(-1.0, 1.0), 0.03)
	low = _lowpass(st, "lp2", low, 0.2)
	var env := minf(t * 4.0, 1.0) * clampf((dur - t) / 1.2, 0.0, 1.0)
	var crack := 0.0
	if randf() < 0.002:
		crack = randf_range(-1.0, 1.0)
	return low * 5.0 * env + crack

func _gen_coin(t: float, _dur: float, _st: Dictionary) -> float:
	var f := 1320.0 if t < 0.08 else 1760.0
	return sin(TAU * f * t) * exp(-t * 9.0) * 0.5

func _gen_bell(t: float, _dur: float, _st: Dictionary) -> float:
	var v := sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1320.0 * t) * 0.25 + sin(TAU * 2210.0 * t) * 0.12
	return v * exp(-t * 2.8) * 0.8

func _gen_fuse(_t: float, _dur: float, st: Dictionary) -> float:
	var n := randf_range(-1.0, 1.0)
	var low := _lowpass(st, "lp", n, 0.5)
	var crackle := randf_range(-1.0, 1.0) if randf() < 0.01 else 0.0
	return (n - low) * 0.35 + crackle * 0.5

func _gen_motor(t: float, _dur: float, st: Dictionary) -> float:
	var saw := fmod(60.0 * t, 1.0) * 2.0 - 1.0
	var hum := _lowpass(st, "lp", saw, 0.2)
	return hum * 0.5 + randf_range(-0.05, 0.05)

func _gen_click(t: float, _dur: float, _st: Dictionary) -> float:
	return randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.6
