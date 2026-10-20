class_name Menu
extends CanvasLayer
## Menú principal: nombre, crear partida, unirse por IP o por Steam, y prueba del micrófono.

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _steam_button: Button
var _buttons: Array[Button] = []

func _ready() -> void:
	layer = 10
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Hud._label("MUDANCEROS TRUCHOS", 52, Color(0.95, 0.5, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Hud._label("De día hacen mudanzas. De noche... también, pero sin permiso.\nEl juego escucha tu micrófono: no despierten a Don Ramón.", 18, Color(0.8, 0.82, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_spacer(10))

	box.add_child(Hud._label("Tu nombre", 16, Color(0.8, 0.8, 0.8)))
	_name_edit = LineEdit.new()
	_name_edit.text = Net.player_name
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(0, 40)
	box.add_child(_name_edit)

	var host := Hud._button("Crear partida (solo o red local / IP)" if Net.can_play_online() else "Jugar")
	host.pressed.connect(_on_host)
	box.add_child(host)
	_buttons.append(host)
	if not Net.can_play_online():
		var web_note := Hud._label("En el navegador se juega solo. Para jugar con amigos hay que abrir el proyecto en Godot.", 14, Color(0.75, 0.7, 0.6))
		web_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		web_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(web_note)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.visible = Net.can_play_online()
	box.add_child(row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "IP del anfitrión"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.custom_minimum_size = Vector2(0, 44)
	row.add_child(_ip_edit)
	var join := Hud._button("Unirse por IP")
	join.pressed.connect(_on_join)
	row.add_child(join)
	_buttons.append(join)

	_steam_button = Hud._button("Crear partida en Steam (invitar amigos)")
	_steam_button.pressed.connect(_on_host_steam)
	_steam_button.visible = Net.can_play_online()
	box.add_child(_steam_button)
	_buttons.append(_steam_button)
	if not Net.has_steam_peer() and Net.can_play_online():
		_steam_button.disabled = true
		_steam_button.tooltip_text = "Necesita Steam abierto y el plugin GodotSteam (ver README)."
		var note := Hud._label("Steam no detectado: para jugar por Steam hay que instalar GodotSteam (ver README).\nMientras tanto se puede probar por IP o en red local.", 14, Color(0.75, 0.7, 0.6))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)

	_status = Hud._label("", 17, Color(1.0, 0.6, 0.45))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	box.add_child(mic_controls())

	var quit := Hud._button("Salir")
	quit.pressed.connect(func() -> void: get_tree().quit())
	quit.visible = not OS.has_feature("web")
	box.add_child(quit)

	var version := Hud._label("Versión: %s" % Version.text(), 14, Color(0.5, 0.52, 0.6))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version)

	var help := Hud._label("WASD moverse · Shift correr · C agacharse · E agarrar / puertas · Clic lanzar · F linterna\nPara hablar entre ustedes usen Discord (o lo que usen): el juego solo mide qué tan fuerte hablan.", 14, Color(0.6, 0.62, 0.7))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)

## Controles del micrófono (se usan en el menú y en la pausa).
static func mic_controls() -> Control:
	return MicPanel.new()

class MicPanel extends VBoxContainer:
	var _bar: ProgressBar
	var _word: Label

	func _ready() -> void:
		add_theme_constant_override("separation", 4)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		add_child(row)
		var toggle := CheckBox.new()
		toggle.text = "Usar micrófono"
		toggle.button_pressed = Voice.enabled
		toggle.toggled.connect(func(on: bool) -> void: Voice.enabled = on)
		row.add_child(toggle)
		_word = Hud._label("", 15, Color(0.8, 0.85, 1.0))
		_word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(_word)
		_bar = Hud._bar(Color(0.4, 0.9, 0.4), 0, 12)
		add_child(_bar)
		var sens := HBoxContainer.new()
		add_child(sens)
		sens.add_child(Hud._label("Sensibilidad", 15, Color(0.8, 0.8, 0.8)))
		var slider := HSlider.new()
		slider.min_value = 0.4
		slider.max_value = 2.5
		slider.step = 0.05
		slider.value = Voice.sensitivity
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v: float) -> void: Voice.sensitivity = v)
		sens.add_child(slider)

	func _process(_delta: float) -> void:
		if not Voice.available:
			_word.text = "no se detectó micrófono"
			_bar.value = 0.0
			return
		_bar.value = Voice.level
		_word.text = "Prueba: " + Voice.level_word(Voice.level)

static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _apply_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "":
		Net.player_name = n

func _set_busy(busy: bool) -> void:
	for b in _buttons:
		b.disabled = busy or (b == _steam_button and not Net.has_steam_peer())

func _on_host() -> void:
	_apply_name()
	show_status("Creando partida...")
	Net.host_enet()

func _on_join() -> void:
	_apply_name()
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		show_status("Escribe la IP del anfitrión.")
		return
	show_status("Conectando a %s..." % ip)
	_set_busy(true)
	Net.join_enet(ip)

func _on_host_steam() -> void:
	show_status("Creando lobby de Steam...")
	_set_busy(true)
	Net.host_steam()

func show_status(text: String) -> void:
	_status.text = text

func open(reason := "") -> void:
	visible = true
	_set_busy(false)
	show_status(reason)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
