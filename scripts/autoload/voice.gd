extends Node
## Micrófono: mide qué tan fuerte habla el jugador en su propia computadora.
##
## El sonido del micrófono entra a un bus propio ("Mic") que está silenciado (así nadie se escucha
## a sí mismo). Un AudioEffectCapture copia lo que entra antes del silencio y con eso se calcula
## el volumen. Cada jugador manda ese número al anfitrión, que decide si el dueño lo oyó.
##
## La voz en sí no viaja por la red: por ahora se habla por Discord (o lo que usen).

const SILENCE_DB := -50.0   # por debajo de esto cuenta como silencio
const SHOUT_DB := -10.0     # desde acá cuenta como grito (nivel 1)
const GATE := 0.1           # lo que no llega a esto es ruido de fondo (ventilador, teclado...)

var enabled := true
var sensitivity := 1.0      # 0,5 = hay que hablar el doble de fuerte; 2 = la mitad
var available := false      # hay un micrófono andando
var level := 0.0            # 0..1, suavizado (sube rápido y baja despacio)
var debug_level := -1.0     # pruebas automáticas: si es >= 0 se usa en vez del micrófono

var _capture: AudioEffectCapture
var _player: AudioStreamPlayer

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or not ProjectSettings.get_setting("audio/driver/enable_input", false):
		return
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Mic")
	AudioServer.set_bus_mute(bus, true)
	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Mic"
	add_child(_player)
	_player.play()
	available = true

func _process(delta: float) -> void:
	if debug_level >= 0.0:
		level = debug_level
		return
	var raw := 0.0
	if _capture != null:
		var frames := _capture.get_frames_available()
		if frames > 0:
			var buf := _capture.get_buffer(frames)
			var sum := 0.0
			for f in buf:
				var v := maxf(absf(f.x), absf(f.y))
				sum += v * v
			var rms := sqrt(sum / frames)
			raw = clampf((linear_to_db(rms + 0.000001) - SILENCE_DB) / (SHOUT_DB - SILENCE_DB), 0.0, 1.0)
	if not enabled:
		raw = 0.0
	raw = clampf(raw * sensitivity, 0.0, 1.0)
	if raw < GATE:
		raw = 0.0
	level = raw if raw > level else maxf(level - delta * 1.5, raw)

## Palabra para el nivel actual (para el medidor de la interfaz).
static func level_word(v: float) -> String:
	if v < GATE:
		return "silencio"
	if v < 0.25:
		return "susurro"
	if v < 0.55:
		return "hablando"
	return "¡GRITANDO!"
