class_name Menu
extends CanvasLayer
## Menú de bienvenida (design/ux/menus-y-venta.md § 1): a la izquierda "lo que hago" (título,
## nombre y botones para entrar), a la derecha "lo que reviso una vez" (micrófono y controles),
## sobre una ciudad de noche dibujada por código.

const SUBTITLE := "De día hacen mudanzas. De noche... también, pero sin permiso. El juego escucha tu micrófono: no despierten a Don Ramón."
const WEB_NOTE := "En el navegador se juega solo. Para jugar con amigos, descarga el juego para computadora."
const STEAM_NOTE := "Steam no detectado: se puede jugar por IP o en red local (ver README)."
const DISCORD_NOTE := "Para hablar entre ustedes usen Discord (o lo que usen): el juego solo mide qué tan fuerte hablan."
const CONTROL_LINES := ["WASD moverse", "Shift correr · C agacharse", "E agarrar / puertas", "Clic lanzar · F linterna", "Esc pausa"]
const FADE_SECONDS := 0.25

## Solo para pruebas y fotos: muestra la variante del navegador aunque se esté en la PC.
var web_preview := false

var _root: Control
var _black: ColorRect
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: UiStyle.StatusLine
var _host: UiStyle.LabelButton
var _join: UiStyle.LabelButton
var _steam_button: UiStyle.LabelButton
var _quit: UiStyle.LabelButton
var _cancel: UiStyle.LabelButton
var _mic: MicPanel
var _buttons: Array[Button] = []
var _used: Button
var _busy := false
var _fade: Tween

func _is_web() -> bool:
	return web_preview or not Net.can_play_online()

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	var sky := Skyline.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(sky)
	_build_left()
	_build_right()
	var version := UiStyle.label("Versión: %s" % Version.text(), UiStyle.SIZE_SMALL, UiStyle.VERSION_GRAY, true)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -20
	version.offset_bottom = -12
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(version)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	_root.add_child(_black)
	_chain()
	if visible:
		_fade_in()
		_host.grab_focus()

func _build_left() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 64
	col.offset_right = 64 + 580
	col.offset_top = 30
	col.offset_bottom = -24
	col.add_theme_constant_override("separation", 10)
	_root.add_child(col)
	col.add_child(UiStyle.TapeTitle.new("Mudanceros", UiStyle.SIZE_MENU_TITLE, -2.0))
	var second := UiStyle.TapeTitle.new("Truchos", UiStyle.SIZE_MENU_TITLE, 1.5)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 150)
	indent.add_child(second)
	col.add_child(indent)
	var sub := UiStyle.wrapped(SUBTITLE, 18, UiStyle.TEXT_LIGHT, 560)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	col.add_child(sub)
	col.add_child(UiStyle.spacer(2))
	col.add_child(UiStyle.label("Tu nombre", UiStyle.SIZE_SMALL, UiStyle.TEXT_LIGHT, true))
	_name_edit = LineEdit.new()
	_name_edit.text = Net.player_name
	_name_edit.placeholder_text = "Mudancero"
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(380, 44)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_name_edit.text_submitted.connect(func(_t: String) -> void: _host.grab_focus())
	col.add_child(_name_edit)
	var web := _is_web()
	_host = UiStyle.LabelButton.new("Jugar" if web else "Crear partida (solo o red local / IP)", true)
	_host.pressed.connect(_on_host)
	col.add_child(_host)
	_buttons.append(_host)
	if web:
		col.add_child(_outlined(UiStyle.wrapped(WEB_NOTE, UiStyle.SIZE_SMALL, UiStyle.TEXT_LIGHT, 560)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.visible = not web
	col.add_child(row)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "IP del anfitrión"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.custom_minimum_size = Vector2(0, 44)
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _on_join())
	row.add_child(_ip_edit)
	_join = UiStyle.LabelButton.new("Unirse por IP")
	_join.pressed.connect(_on_join)
	row.add_child(_join)
	_buttons.append(_join)
	_steam_button = UiStyle.LabelButton.new("Crear partida en Steam (invitar amigos)")
	_steam_button.pressed.connect(_on_host_steam)
	_steam_button.visible = not web
	col.add_child(_steam_button)
	_buttons.append(_steam_button)
	if not web and not Net.has_steam_peer():
		_steam_button.disabled = true
		col.add_child(_outlined(UiStyle.wrapped(STEAM_NOTE, UiStyle.SIZE_SMALL, UiStyle.TEXT_LIGHT, 560)))
	_cancel = UiStyle.LabelButton.new("Cancelar")
	_cancel.pressed.connect(_on_cancel)
	_cancel.visible = false
	col.add_child(_cancel)
	_status = UiStyle.StatusLine.new(false, 560)
	_status.text_label.add_theme_constant_override("outline_size", 6)
	_status.text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	col.add_child(_status)
	_quit = UiStyle.LabelButton.new("Salir")
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_quit.visible = not web and not OS.has_feature("web")
	_quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_quit.custom_minimum_size.x = 160
	col.add_child(_quit)

func _build_right() -> void:
	var panel := UiStyle.CardboardPanel.new(18)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -60 - 420
	panel.offset_right = -60
	panel.offset_top = 64
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiStyle.label("ANTES DE JUGAR", UiStyle.SIZE_SECTION, UiStyle.INK))
	box.add_child(UiStyle.TapeTitle.new("Micrófono", UiStyle.SIZE_BUTTON, -1.0))
	_mic = MicPanel.new()
	box.add_child(_mic)
	box.add_child(UiStyle.wrapped("Habla normal: la barra debería marcar \"hablando\".", UiStyle.SIZE_SMALL, UiStyle.INK, 380))
	var line := ColorRect.new()
	line.color = Color(UiStyle.CARDBOARD_EDGE, 0.9)
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	box.add_child(UiStyle.TapeTitle.new("Controles", UiStyle.SIZE_BUTTON, 1.0))
	for l: String in CONTROL_LINES:
		box.add_child(UiStyle.key_text(l, UiStyle.SIZE_BODY, UiStyle.INK))
	var line2 := line.duplicate() as ColorRect
	box.add_child(line2)
	box.add_child(UiStyle.wrapped(DISCORD_NOTE, UiStyle.SIZE_SMALL, UiStyle.INK, 380))

static func _outlined(l: Label) -> Label:
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l

## Tab: nombre → crear → IP → unirse → Steam → salir → micrófono → sensibilidad (y vuelve).
func _chain() -> void:
	UiStyle.chain_focus([_name_edit, _host, _cancel, _ip_edit, _join, _steam_button, _quit, _mic.toggle, _mic.slider])
	_host.focus_neighbor_right = _host.get_path_to(_mic.toggle)
	_mic.toggle.focus_neighbor_left = _mic.toggle.get_path_to(_host)

## Controles del micrófono (se usan en el menú y en la pausa).
static func mic_controls() -> MicPanel:
	return MicPanel.new()

## Panel del micrófono sobre cartón: casilla, palabra del nivel, barra y sensibilidad.
class MicPanel extends VBoxContainer:
	var toggle: CheckBox
	var slider: HSlider
	var _bar: ProgressBar
	var _word: Label

	func _init() -> void:
		add_theme_constant_override("separation", 6)
		toggle = CheckBox.new()
		toggle.text = "Usar micrófono"
		toggle.button_pressed = Voice.enabled
		toggle.custom_minimum_size = Vector2(0, 34)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		toggle.toggled.connect(func(on: bool) -> void: Voice.enabled = on)
		add_child(toggle)
		_word = UiStyle.wrapped("", UiStyle.SIZE_BODY, UiStyle.INK)
		add_child(_word)
		_bar = UiStyle.bar(Color(0.25, 0.7, 0.25), 0, 14, Color(UiStyle.INK, 0.45))
		add_child(_bar)
		var sens := HBoxContainer.new()
		sens.add_theme_constant_override("separation", 10)
		add_child(sens)
		sens.add_child(UiStyle.label("Sensibilidad", UiStyle.SIZE_SMALL, UiStyle.INK))
		slider = HSlider.new()
		slider.min_value = 0.4
		slider.max_value = 2.5
		slider.step = 0.05
		slider.value = Voice.sensitivity
		slider.custom_minimum_size = Vector2(0, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_ALL
		slider.value_changed.connect(func(v: float) -> void: Voice.sensitivity = v)
		sens.add_child(slider)

	func _process(_delta: float) -> void:
		if not is_visible_in_tree():
			return
		if not Voice.available and Voice.debug_level < 0.0:
			_word.text = "No se detectó micrófono: puedes jugar igual, pero tu voz no cuenta."
			_bar.value = 0.0
			return
		if not Voice.enabled:
			_word.text = "Micrófono apagado"
			_bar.value = 0.0
			return
		var v := Voice.level
		_bar.value = v
		_word.text = "Prueba: " + Voice.level_word(v)
		UiStyle.set_bar_color(_bar, Color(0.25, 0.7, 0.25) if v < 0.25 else (Color(0.85, 0.6, 0.05) if v < 0.55 else Color(0.75, 0.12, 0.08)))

func _apply_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "":
		Net.player_name = n

## Conectando: los botones de entrar se deshabilitan y "Cancelar" ocupa el lugar del usado.
func _start_busy(button: Button, text: String) -> void:
	_busy = true
	_used = button
	_status.show_info(text)
	for b in _buttons:
		b.disabled = true
	var parent := button.get_parent()
	_cancel.get_parent().remove_child(_cancel)
	parent.add_child(_cancel)
	parent.move_child(_cancel, button.get_index())
	button.visible = false
	_cancel.visible = true
	_cancel.custom_minimum_size.y = button.custom_minimum_size.y
	_chain()
	_cancel.grab_focus()

func _end_busy() -> void:
	_busy = false
	for b in _buttons:
		b.disabled = b == _steam_button and not Net.has_steam_peer()
	_cancel.visible = false
	if _used:
		_used.visible = true
	_chain()

func _on_host() -> void:
	_apply_name()
	_start_busy(_host, "Creando partida...")
	Net.host_enet()

func _on_join() -> void:
	_apply_name()
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		_status.show_error("Escribe la IP del anfitrión.")
		_ip_edit.grab_focus()
		return
	_start_busy(_join, "Conectando a %s..." % ip)
	Net.join_enet(ip)

func _on_host_steam() -> void:
	_apply_name()
	_start_busy(_steam_button, "Creando lobby de Steam...")
	Net.host_steam()

func _on_cancel() -> void:
	var used := _used
	_end_busy()
	_status.clear()
	Net.leave("")
	if used and visible:
		used.grab_focus()

func show_status(text: String) -> void:
	_status.show_info(text)

## Vuelve al menú (con el motivo, si se cortó o falló algo).
func open(reason := "") -> void:
	visible = true
	_end_busy()
	if reason != "":
		_status.show_error(reason)
	else:
		_status.clear()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fade_in()
	if reason != "" and _used and _used.visible and not _used.disabled:
		_used.grab_focus()
	else:
		_host.grab_focus()

## Se fue a la partida: fundido a negro (250 ms) y se esconde.
func close() -> void:
	if not visible:
		return
	if _busy:
		_end_busy()
	var f := _root.get_viewport().gui_get_focus_owner() if _root.is_inside_tree() else null
	if f and _root.is_ancestor_of(f):
		f.release_focus()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_black, "modulate:a", 1.0, FADE_SECONDS)
	_fade.tween_callback(func() -> void:
		visible = false
		_black.modulate.a = 0.0)

func _fade_in() -> void:
	if _fade:
		_fade.kill()
	_black.modulate.a = 1.0
	_fade = create_tween()
	_fade.tween_property(_black, "modulate:a", 0.0, FADE_SECONDS)

func _unhandled_input(event: InputEvent) -> void:
	if visible and _busy and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_on_cancel()

## La ciudad de noche: siluetas de cartón recortado, luna y ventanas encendidas, con una deriva
## lateral muy lenta. Semilla fija: siempre sale igual.
class Skyline extends Control:
	const SPEEDS := [1.5, 3.5, 6.0]
	const COLORS := [Color(0.1, 0.11, 0.19), Color(0.07, 0.08, 0.14), Color(0.035, 0.04, 0.07)]
	const HEIGHTS := [[150.0, 330.0], [110.0, 250.0], [60.0, 170.0]]
	const LOOP := 1600.0
	var _layers := []   # por capa: lista de [x, ancho, alto, ventanas]
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for li in 3:
			var blds := []
			var x := 0.0
			while x < LOOP:
				var w := rng.randf_range(50.0, 130.0)
				var h := rng.randf_range(HEIGHTS[li][0], HEIGHTS[li][1])
				var wins := []
				var wx := 8.0
				while wx < w - 10.0:
					var wy := 14.0
					while wy < h - 16.0:
						if rng.randf() < 0.22:
							wins.append([wx, wy, rng.randf_range(0.4, 0.7)])
						wy += 18.0
					wx += 14.0
				blds.append([x, w, h, wins])
				x += w + rng.randf_range(2.0, 18.0)
			_layers.append(blds)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Cielo que aclara un poco hacia el horizonte.
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([UiStyle.NIGHT, UiStyle.NIGHT, Color(0.13, 0.15, 0.26), Color(0.13, 0.15, 0.26)]))
		draw_circle(Vector2(w * 0.56, 96), 34, Color(0.95, 0.93, 0.8))
		draw_circle(Vector2(w * 0.56 + 12, 88), 7, Color(0.85, 0.83, 0.72))
		draw_circle(Vector2(w * 0.56 - 10, 106), 5, Color(0.85, 0.83, 0.72))
		for li in 3:
			var off := fposmod(_t * float(SPEEDS[li]), LOOP)
			for b: Array in _layers[li]:
				for rep in 2:
					var bx: float = b[0] - off + rep * LOOP
					if bx > w or bx + b[1] < 0.0:
						continue
					var top: float = h - b[2]
					draw_rect(Rect2(bx, top, b[1], b[2]), COLORS[li])
					for win: Array in b[3]:
						draw_rect(Rect2(bx + win[0], top + win[1], 5, 7), Color(UiStyle.SIGN_YELLOW, win[2] * (0.55 + 0.2 * li)))
