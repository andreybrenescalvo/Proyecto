extends Node
## Sonidos generados por código (placeholder hasta tener audio de verdad).
## Así el prototipo tiene ronquidos, vidrios rotos y puertas que chillan sin depender de archivos externos.

const RATE := 22050

var streams := {}

func _ready() -> void:
	streams["thud"] = _make(0.3, _gen_thud)
	streams["step"] = _make(0.12, _gen_step)
	streams["creak"] = _make(1.1, _gen_creak)
	streams["door"] = _make(0.7, _gen_door)
	streams["squeak"] = _make(0.45, _gen_squeak)
	streams["crash"] = _make(1.0, _gen_crash)
	streams["clang"] = _make(0.8, _gen_clang)
	streams["scrape"] = _make(0.35, _gen_scrape)
	streams["duck"] = _make(0.25, _gen_duck)
	streams["snore"] = _make(3.2, _gen_snore, true)
	streams["mumble"] = _make(0.9, _gen_mumble)
	streams["shout"] = _make(1.0, _gen_shout)
	streams["siren"] = _make(2.0, _gen_siren, true)
	streams["honk"] = _make(0.6, _gen_honk)
	streams["engine"] = _make(1.0, _gen_engine, true)
	streams["coin"] = _make(0.35, _gen_coin)
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

func _gen_thud(t: float, _dur: float, st: Dictionary) -> float:
	var low := _lowpass(st, "lp", randf_range(-1.0, 1.0), 0.08)
	return (low * 2.5 + sin(TAU * 90.0 * t) * 0.5) * exp(-t * 18.0)

func _gen_step(t: float, _dur: float, st: Dictionary) -> float:
	var low := _lowpass(st, "lp", randf_range(-1.0, 1.0), 0.15)
	return low * 1.6 * exp(-t * 40.0)

func _gen_creak(t: float, dur: float, _st: Dictionary) -> float:
	var f := 70.0 + 35.0 * sin(TAU * 2.3 * t) + 20.0 * sin(TAU * 7.1 * t)
	var saw := fmod(f * t, 1.0) * 2.0 - 1.0
	var env := sin(PI * t / dur) * (0.6 + 0.4 * sin(TAU * 11.0 * t))
	return saw * env * 0.35

## Bisagra oxidada: un chirrido que sube de tono.
func _gen_door(t: float, dur: float, st: Dictionary) -> float:
	var f := 380.0 + 260.0 * (t / dur) + 40.0 * sin(TAU * 9.0 * t)
	st["ph"] = float(st.get("ph", 0.0)) + f / RATE
	var saw := fmod(float(st["ph"]), 1.0) * 2.0 - 1.0
	var grit := 0.6 + 0.4 * sin(TAU * 31.0 * t)
	return saw * grit * sin(PI * t / dur) * 0.3

func _gen_squeak(t: float, dur: float, st: Dictionary) -> float:
	var f := 220.0 + 90.0 * sin(PI * t / dur)
	st["ph"] = float(st.get("ph", 0.0)) + f / RATE
	var saw := fmod(float(st["ph"]), 1.0) * 2.0 - 1.0
	return saw * sin(PI * t / dur) * 0.4

## Vidrio o loza: golpe seco y muchos "tintines" agudos.
func _gen_crash(t: float, _dur: float, st: Dictionary) -> float:
	var n := randf_range(-1.0, 1.0)
	var high := n - _lowpass(st, "lp", n, 0.3)
	var body := high * exp(-t * 7.0) * 1.2
	var tink := 0.0
	if randf() < 0.004 * exp(-t * 3.0):
		st["tf"] = randf_range(2500.0, 6000.0)
		st["tt"] = t
	if st.has("tf"):
		var dt := t - float(st["tt"])
		tink = sin(TAU * float(st["tf"]) * dt) * exp(-dt * 30.0) * 0.5
	return body + tink

func _gen_clang(t: float, _dur: float, _st: Dictionary) -> float:
	var v := sin(TAU * 410.0 * t) * 0.5 + sin(TAU * 1130.0 * t) * 0.3 + sin(TAU * 2350.0 * t) * 0.2
	return v * exp(-t * 6.0) * 0.8 + randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.4

func _gen_scrape(t: float, dur: float, st: Dictionary) -> float:
	var n := randf_range(-1.0, 1.0)
	var band := _lowpass(st, "lp", n, 0.25) - _lowpass(st, "lp2", n, 0.04)
	var judder := 0.5 + 0.5 * sin(TAU * 38.0 * t)
	return band * 3.0 * judder * sin(PI * t / dur)

func _gen_duck(t: float, dur: float, st: Dictionary) -> float:
	var f := 900.0 + 500.0 * sin(PI * t / dur)
	st["ph"] = float(st.get("ph", 0.0)) + f / RATE
	return signf(sin(TAU * float(st["ph"]))) * sin(PI * t / dur) * 0.25

## Ronquido: inhalación áspera y exhalación con silbido, en bucle.
func _gen_snore(t: float, _dur: float, st: Dictionary) -> float:
	var n := randf_range(-1.0, 1.0)
	var low := _lowpass(st, "lp", n, 0.05)
	if t < 1.4:
		var env := sin(PI * t / 1.4)
		var rattle := 0.5 + 0.5 * sin(TAU * 32.0 * t)
		return low * 4.0 * env * rattle
	if t < 2.6:
		var env2 := sin(PI * (t - 1.4) / 1.2)
		var air := (n - _lowpass(st, "lp2", n, 0.5)) * 0.15
		return (low * 1.5 + air) * env2
	return 0.0

## Murmullo del dueño cuando se da vuelta en la cama.
func _gen_mumble(t: float, dur: float, st: Dictionary) -> float:
	var f := 120.0 + 25.0 * sin(TAU * 3.0 * t)
	st["ph"] = float(st.get("ph", 0.0)) + f / RATE
	var saw := fmod(float(st["ph"]), 1.0) * 2.0 - 1.0
	var syll := maxf(sin(TAU * 4.5 * t), 0.0)
	return _lowpass(st, "lp", saw, 0.12) * syll * sin(PI * t / dur) * 1.4

## "¿¡QUIÉN ANDA AHÍ!?": tres sílabas con la voz quebrada.
func _gen_shout(t: float, dur: float, st: Dictionary) -> float:
	var f := 210.0 + 70.0 * sin(PI * t / dur) + 15.0 * sin(TAU * 7.0 * t)
	st["ph"] = float(st.get("ph", 0.0)) + f / RATE
	var saw := fmod(float(st["ph"]), 1.0) * 2.0 - 1.0
	var syll := clampf(sin(TAU * 3.2 * t) * 2.0, 0.0, 1.0)
	var formant := _lowpass(st, "lp", saw, 0.35)
	return formant * syll * minf(t * 20.0, 1.0) * clampf((dur - t) * 6.0, 0.0, 1.0) * 1.1

func _gen_siren(t: float, _dur: float, st: Dictionary) -> float:
	var f := 700.0 + 300.0 * sin(TAU * 0.5 * t)
	st["ph"] = float(st.get("ph", 0.0)) + f / RATE
	return sin(TAU * float(st["ph"])) * 0.35

func _gen_honk(t: float, dur: float, _st: Dictionary) -> float:
	var v := signf(sin(TAU * 330.0 * t)) * 0.3 + signf(sin(TAU * 415.0 * t)) * 0.3
	return v * minf(t * 40.0, 1.0) * clampf((dur - t) * 20.0, 0.0, 1.0) * 0.6

## Motor diésel en marcha: pulsos graves (la velocidad la pone el pitch del reproductor).
func _gen_engine(t: float, _dur: float, st: Dictionary) -> float:
	var firing := maxf(sin(TAU * 32.0 * t), 0.0)
	var low := _lowpass(st, "lp", randf_range(-1.0, 1.0), 0.06)
	var hum := sin(TAU * 64.0 * t) * 0.3 + sin(TAU * 96.0 * t) * 0.12
	return (firing * 0.5 + hum) * (0.7 + low * 2.0) * 0.6

func _gen_coin(t: float, _dur: float, _st: Dictionary) -> float:
	var f := 1320.0 if t < 0.08 else 1760.0
	return sin(TAU * f * t) * exp(-t * 9.0) * 0.5

func _gen_click(t: float, _dur: float, _st: Dictionary) -> float:
	return randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.6
