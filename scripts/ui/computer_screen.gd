class_name ComputerScreen
extends Control
## La computadora del Galpón 7 (design/ux/menus-y-venta.md § 4): un escritorio de sistema viejo
## con el "Mercado del Flaco" (vender lo del camión y cerrar la noche), la Tienda "Próximamente",
## el Bloc de notas y la Papelera, notificaciones y una barra de tareas con la hora 23:00 → 06:00.
##
## La pantalla solo lee `world.game` y llama a `request_sell`, `request_close_night` y
## `request_computer("stand")`: todo lo valida el anfitrión. La abre y la cierra el HUD cuando el
## jugador local se sienta (`Player.at_computer`). Esc sin diálogos = levantarse.

## Reloj de pared falso: la noche va de las 23:00 a las 06:00 (cosmético).
const START_HOUR := 23.0
const END_HOUR := 6.0
const BOOT_SECONDS := 0.2
const SHUTDOWN_SECONDS := 0.08
## Si en este tiempo la cosa no se fue del camión, la venta falló.
const SELL_TIMEOUT_MS := 2000
## Después de que cambian las filas, los clics en la lista se ignoran este tiempo (lista estable).
const CLICK_GUARD_MS := 300
const DIALOG_GUARD_MS := 400
const ROW_HEIGHT := 44.0

const SCREEN_BG := Color(0.0, 0.4, 0.42)
const SYS_GRAY := Color(0.75, 0.75, 0.75)
const SYS_TEXT := Color(0.04, 0.04, 0.04)
const TITLE_BLUE := Color(0.0, 0.0, 0.5)
const FRAME := Color(0.16, 0.16, 0.17)

const TXT_MARKET := "Mercado del Flaco"
const TXT_TOOLS := "Tienda de herramientas"
const TXT_NOTES := "Bloc de notas"
const TXT_TRASH := "Papelera"
const TXT_SOON := "(Próximamente)"
const TXT_STAND := "Levantarse (Esc)"
const TXT_SLOGAN := "\"Compramos de todo. No preguntamos nada.\""
const TXT_TRUCK_OUT := "El camión no está adentro del Galpón 7. Estaciónenlo adentro para que el Flaco vea la mercadería."
const TXT_EMPTY := "La caja del camión está vacía."
const TXT_ALL_SOLD := "¡No queda nada en el camión!"
const TXT_NO_UNDO := "Las ventas no se pueden deshacer."
const TXT_PAID_AT_CLOSE := "Se cobra al cerrar la noche."
const TXT_LOST := "Lo que no vendan se pierde: la noche siguiente empieza de cero."

var world: World

var _open := false
var _screen: Control
var _desktop: Control
var _icons: Array[Control] = []
var _window_layer: CenterContainer
var _window: RetroWindow
var _window_kind := ""
var _modal: Control
var _modal_window: RetroWindow
var _modal_safe: Button
var _modal_opened_ms := 0
var _start_menu: PanelContainer
var _start_items: Array[Control] = []
var _boot: ColorRect
var _notices: NoticeBox
var _start_button: RetroButton
var _tab_button: RetroButton
var _stand_button: RetroButton
var _clock: Label
var _police_row: HBoxContainer
var _police: Label
var _mic_word: Label
var _mic_bar: ProgressBar
var _fade: Tween
var _last_input_mouse := false

# Mercado del Flaco
var _mk_order: Array[int] = []    # ids en el orden en que se muestran (lo nuevo va al final)
var _mk_rows := {}                # id -> {wrap, name, fresh, state, price, button, data}
var _mk_pending := {}             # id -> momento en que se pidió la venta (ms)
var _mk_initialized := false
var _mk_changed_ms := 0
var _mk_sold_count := -1
var _mk_list: VBoxContainer
var _mk_scroll: ScrollContainer
var _mk_empty: Label
var _mk_count: Label
var _mk_sell_all: RetroButton
var _mk_status: UiStyle.StatusLine
var _mk_quota: UiStyle.LeaderRow
var _mk_sold: UiStyle.LeaderRow
var _mk_missing: UiStyle.LeaderRow
var _mk_met: HBoxContainer
var _mk_bar: ProgressBar
var _mk_pct: Label
var _mk_sold_title: Label
var _mk_sold_list: VBoxContainer
var _mk_close: RetroButton
var _closing := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UiStyle.theme()
	# Marco del monitor (plástico gris oscuro).
	var frame := ColorRect.new()
	frame.color = FRAME
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.offset_left = 16
	_screen.offset_top = 16
	_screen.offset_right = -16
	_screen.offset_bottom = -16
	_screen.clip_contents = true
	add_child(_screen)
	_build_desktop()
	_build_taskbar()
	_window_layer = CenterContainer.new()
	_window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_layer.offset_bottom = -40
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_window_layer)
	var corner := VBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_left = -416
	corner.offset_right = -16
	corner.offset_top = -40 - 12 - 180
	corner.offset_bottom = -40 - 12
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(corner)
	_notices = NoticeBox.new(false)
	corner.add_child(_notices)
	_build_start_menu()
	_boot = ColorRect.new()
	_boot.color = Color.BLACK
	_boot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot.visible = false
	_screen.add_child(_boot)
	var logo := UiStyle.label("Mudanzas y Reparaciones · Galpón 7", 26, Color(0.75, 0.8, 0.8))
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boot.add_child(logo)

# ---------------------------------------------------------------- abrir y cerrar

func is_open() -> bool:
	return _open

## Se sentó: se enciende (200 ms de negro con el logo, sin destellos) y queda el escritorio.
func open() -> void:
	if _open:
		return
	_open = true
	_closing = false
	if _fade:
		_fade.kill()
	modulate.a = 1.0
	visible = true
	_close_modal()
	_close_window()
	_start_menu.visible = false
	_notices.clear_all()
	_boot.visible = true
	if not world.game_changed.is_connected(_on_game_changed):
		world.game_changed.connect(_on_game_changed)
	_fade = create_tween()
	_fade.tween_interval(BOOT_SECONDS)
	_fade.tween_callback(func() -> void: _boot.visible = false)
	_desktop_focus()

## Se levantó (o terminó la noche): se apaga en 80 ms. Las ventanas no se recuerdan.
func close() -> void:
	if not _open:
		return
	_open = false
	if world.game_changed.is_connected(_on_game_changed):
		world.game_changed.disconnect(_on_game_changed)
	var focus := get_viewport().gui_get_focus_owner()
	if focus and is_ancestor_of(focus):
		focus.release_focus()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, SHUTDOWN_SECONDS)
	_fade.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
		_close_modal()
		_close_window())

## Notificación del sistema (los avisos de la partida mientras el HUD está oculto).
func notify(text: String, urgent := false) -> void:
	_notices.push(text, urgent)

## Abre una app por su nombre ("market", "tools", "notes", "trash"). Sirve también para las fotos.
func open_app(kind: String) -> void:
	_start_menu.visible = false
	_close_window()
	_window_kind = kind
	match kind:
		"market":
			_build_market()
		"tools":
			_message_window(TXT_TOOLS, "Próximamente: herramientas para las próximas noches.")
		"notes":
			_message_window(TXT_NOTES, ("Encargo de esta noche: $%d. Lo golpeado vale menos. El Flaco solo paga si " +
					"llegan a la cuota. Cierren la noche antes de que amanezca (06:00). " + TXT_LOST) % int(world.game.get("quota", 0)))
		"trash":
			_message_window(TXT_TRASH, "La papelera está vacía. (El Flaco no deja pruebas.)")
	if _window:
		_tab_button.text = _window.title_text
		_tab_button.visible = true
	_refresh_taskbar_focus()

## Abre la confirmación de "Cerrar la noche" (también para las fotos).
func ask_close_night() -> void:
	if _modal or world.night_over():
		return
	var quota := int(world.game.get("quota", 0))
	var sold := int(world.game.get("sold", 0))
	var met := sold >= quota
	var away := _people_away()
	var fine := away.size() * Config.ARREST_FINE
	var win := RetroWindow.new("Cerrar la noche", 660, 0, not met)
	var body := win.body
	body.add_child(_sys_label("¿Cerrar la noche?", UiStyle.SIZE_SECTION))
	var confirm_text := ""
	var safe_text := ""
	if met:
		body.add_child(_sys_wrapped("Vendieron $%d de $%d." % [sold, quota]))
		body.add_child(_glyph_line("check", UiStyle.INK_GREEN, "Cuota cumplida: cobran $%d." % maxi(sold - fine, 0)))
		body.add_child(_sys_wrapped(TXT_LOST))
		if not away.is_empty():
			var who := _join_names(away)
			var verb := "no está" if away.size() == 1 else "no están"
			var each := "" if away.size() == 1 else " cada uno"
			body.add_child(_glyph_line("warn", UiStyle.INK_RED, "Ojo: %s %s en el galpón (multa de $%d%s)." % [who, verb, Config.ARREST_FINE, each]))
		confirm_text = "Sí, cerrar la noche"
		safe_text = "Volver"
	else:
		body.add_child(_glyph_line("warn", UiStyle.INK_RED, "NO LLEGAN A LA CUOTA: el encargo se cancela y no cobran nada."))
		body.add_child(_sys_wrapped("Vendieron $%d de $%d (faltan $%d)." % [sold, quota, quota - sold]))
		body.add_child(_sys_wrapped(TXT_LOST))
		confirm_text = "Cerrar igual (no cobran nada)"
		safe_text = "Seguir vendiendo"
	body.add_child(UiStyle.spacer(8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 14)
	body.add_child(row)
	var yes := RetroButton.new(confirm_text, "play", 40)
	row.add_child(yes)
	var no := RetroButton.new(safe_text, "play", 40)
	row.add_child(no)
	var status := UiStyle.StatusLine.new(true, 0, 1)
	body.add_child(status)
	yes.pressed.connect(func() -> void:
		if _dialog_guarded() or _closing:
			return
		_closing = true
		yes.disabled = true
		no.disabled = true
		status.show_info("Cerrando la noche...")
		world.request_close_night())
	no.pressed.connect(func() -> void:
		if not _dialog_guarded():
			_close_modal())
	win.close_button.pressed.connect(func() -> void:
		if not _dialog_guarded():
			_close_modal())
	_show_modal(win, no)
	UiStyle.chain_focus([yes, no, win.close_button])
	yes.focus_neighbor_right = yes.get_path_to(no)
	no.focus_neighbor_left = no.get_path_to(yes)

# ---------------------------------------------------------------- escritorio y barra de tareas

func _build_desktop() -> void:
	_desktop = ColorRect.new()
	(_desktop as ColorRect).color = SCREEN_BG
	_desktop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desktop.offset_bottom = -40
	_screen.add_child(_desktop)
	var logo := UiStyle.label("Mudanzas y Reparaciones\nGALPÓN 7", 46, Color(1, 1, 1, 0.13))
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.offset_left = 200
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desktop.add_child(logo)
	var column := VBoxContainer.new()
	column.position = Vector2(20, 18)
	column.add_theme_constant_override("separation", 14)
	_desktop.add_child(column)
	var defs := [["market", TXT_MARKET, "", false], ["tools", TXT_TOOLS, TXT_SOON, true],
			["notes", TXT_NOTES, "", false], ["trash", TXT_TRASH, "", false]]
	for d: Array in defs:
		var icon := DesktopIcon.new(d[0], d[1], d[2], d[3])
		icon.pressed.connect(open_app.bind(d[0]))
		column.add_child(icon)
		_icons.append(icon)

func _build_taskbar() -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SYS_GRAY
	sb.border_color = Color(0.97, 0.97, 0.97)
	sb.border_width_top = 2
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 2
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -40
	_screen.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	_start_button = RetroButton.new("Inicio", "", 33)
	_start_button.pressed.connect(_toggle_start_menu)
	row.add_child(_start_button)
	_tab_button = RetroButton.new("", "", 33)
	_tab_button.custom_minimum_size.x = 200
	_tab_button.visible = false
	_tab_button.pressed.connect(func() -> void:
		if _window:
			_window_first_focus())
	row.add_child(_tab_button)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	# Bandeja: micrófono, policía, hora y "Levantarse".
	var tray := HBoxContainer.new()
	tray.add_theme_constant_override("separation", 10)
	row.add_child(tray)
	_mic_word = _sys_label("", UiStyle.SIZE_SMALL)
	_mic_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tray.add_child(_mic_word)
	_mic_bar = UiStyle.bar(Color(0.1, 0.55, 0.1), 60, 10, Color(0, 0, 0, 0.35))
	_mic_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tray.add_child(_mic_bar)
	tray.add_child(_tray_separator())
	_police_row = HBoxContainer.new()
	_police_row.add_theme_constant_override("separation", 6)
	_police_row.add_child(UiStyle.Glyph.new("warn", UiStyle.INK_RED, 18.0, SYS_GRAY))
	_police = _sys_label("", UiStyle.SIZE_BODY, UiStyle.INK_RED)
	_police_row.add_child(_police)
	_police_row.visible = false
	tray.add_child(_police_row)
	_clock = _sys_label("", UiStyle.SIZE_BODY)
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tray.add_child(_clock)
	tray.add_child(_tray_separator())
	_stand_button = RetroButton.new(TXT_STAND, "play", 33)
	_stand_button.pressed.connect(_stand)
	tray.add_child(_stand_button)

func _tray_separator() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.45, 0.45, 0.45)
	c.custom_minimum_size = Vector2(2, 26)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c

func _build_start_menu() -> void:
	_start_menu = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = SYS_GRAY
	sb.border_color = Color(0.25, 0.25, 0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6)
	_start_menu.add_theme_stylebox_override("panel", sb)
	_start_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_start_menu.offset_left = 4
	_start_menu.offset_right = 244
	_start_menu.offset_top = -40 - 100
	_start_menu.offset_bottom = -42
	_start_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_start_menu.visible = false
	_screen.add_child(_start_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_start_menu.add_child(box)
	var notes := RetroButton.new(TXT_NOTES, "", 38)
	notes.alignment = HORIZONTAL_ALIGNMENT_LEFT
	notes.pressed.connect(open_app.bind("notes"))
	box.add_child(notes)
	var stand := RetroButton.new("Levantarse", "", 38)
	stand.alignment = HORIZONTAL_ALIGNMENT_LEFT
	stand.pressed.connect(_stand)
	box.add_child(stand)
	_start_items = [notes, stand]

func _toggle_start_menu() -> void:
	_start_menu.visible = not _start_menu.visible
	if _start_menu.visible:
		UiStyle.chain_focus(_start_items, true)
		(_start_items[0] as Control).grab_focus()
	else:
		_start_button.grab_focus()

func _stand() -> void:
	world.request_computer("stand")

func _desktop_focus() -> void:
	_refresh_taskbar_focus()
	(_icons[0] as Control).grab_focus()

## Tab recorre la ventana abierta (o los íconos) y después la barra de tareas, en ciclo cerrado.
func _refresh_taskbar_focus() -> void:
	var list: Array = []
	if _window and _window_kind == "market":
		list.append(_mk_sell_all)
		for id in _mk_order:
			list.append(_mk_rows[id]["button"])
		list.append(_mk_close)
		list.append(_window.close_button)
	elif _window:
		list.append_array(_window.focusables)
		list.append(_window.close_button)
	else:
		list.append_array(_icons)
	list.append_array([_start_button, _tab_button, _stand_button])
	UiStyle.chain_focus(list)

# ---------------------------------------------------------------- ventanas

func _show_window(win: RetroWindow) -> void:
	_window = win
	_window_layer.add_child(win)
	win.close_button.pressed.connect(func() -> void:
		var kind := _window_kind
		_close_window()
		_focus_icon(kind))

func _close_window() -> void:
	if _window:
		_window.queue_free()
		_window = null
	_window_kind = ""
	_mk_order.clear()
	_mk_rows.clear()
	_mk_pending.clear()
	_mk_initialized = false
	_mk_sold_count = -1
	if _tab_button:
		_tab_button.visible = false
	if _icons.size() > 0:
		_refresh_taskbar_focus()

func _focus_icon(kind: String) -> void:
	_refresh_taskbar_focus()
	var i := ["market", "tools", "notes", "trash"].find(kind)
	(_icons[maxi(i, 0)] as Control).grab_focus()

func _window_first_focus() -> void:
	if _window_kind == "market":
		_market_default_focus()
	elif _window and not _window.focusables.is_empty():
		(_window.focusables[0] as Control).grab_focus()

func _message_window(title: String, text: String) -> void:
	var win := RetroWindow.new(title, 560, 0)
	win.body.add_child(_sys_wrapped(text, UiStyle.SIZE_BODY, 520))
	win.body.add_child(UiStyle.spacer(6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	win.body.add_child(row)
	var ok := RetroButton.new("Aceptar", "play", 40)
	ok.custom_minimum_size.x = 140
	row.add_child(ok)
	win.focusables = [ok]
	_show_window(win)
	var kind := _window_kind
	ok.pressed.connect(func() -> void:
		_close_window()
		_focus_icon(kind))
	ok.grab_focus()

func _show_modal(win: RetroWindow, safe: Button) -> void:
	_close_modal()
	_modal = ColorRect.new()
	(_modal as ColorRect).color = Color(0, 0, 0, 0.35)
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(_modal)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	center.add_child(win)
	_modal_window = win
	_modal_safe = safe
	_modal_opened_ms = Time.get_ticks_msec()
	safe.grab_focus()

func _close_modal() -> void:
	if _modal == null:
		return
	_modal.queue_free()
	_modal = null
	_modal_window = null
	_modal_safe = null
	_closing = false
	if _open and _window_kind == "market" and is_instance_valid(_mk_close):
		_mk_close.grab_focus()

func _dialog_guarded() -> bool:
	return Time.get_ticks_msec() - _modal_opened_ms < DIALOG_GUARD_MS

# ---------------------------------------------------------------- Mercado del Flaco

func _build_market() -> void:
	var win := RetroWindow.new("%s — www.mercadoflaco.trucho" % TXT_MARKET, 1100, 600)
	var body := win.body
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	body.add_child(head)
	head.add_child(_sys_label("MERCADO DEL FLACO", 26, TITLE_BLUE))
	var slogan := _sys_label(TXT_SLOGAN, UiStyle.SIZE_BODY)
	slogan.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(slogan)
	body.add_child(_hline())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	# Izquierda: lo que hay en la caja.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 660
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	_mk_count = _sys_label("", UiStyle.SIZE_BODY)
	_mk_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mk_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_mk_count)
	_mk_sell_all = RetroButton.new("", "play", 38)
	_mk_sell_all.pressed.connect(_sell_all)
	top.add_child(_mk_sell_all)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	left.add_child(header)
	for h: Array in [["Objeto", 230.0], ["Estado", 210.0], ["Te paga", 80.0]]:
		var l := _sys_label(h[0], UiStyle.SIZE_SMALL, Color(0.2, 0.2, 0.25))
		l.custom_minimum_size.x = h[1]
		if h[0] == "Te paga":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(l)
	var list_bg := PanelContainer.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color(0.86, 0.86, 0.84)
	lsb.border_color = Color(0.4, 0.4, 0.4)
	lsb.set_border_width_all(1)
	lsb.set_content_margin_all(4)
	list_bg.add_theme_stylebox_override("panel", lsb)
	list_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list_bg)
	var stack := Control.new()
	list_bg.add_child(stack)
	_mk_scroll = ScrollContainer.new()
	_mk_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mk_scroll.follow_focus = true
	_mk_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(_mk_scroll)
	_mk_list = VBoxContainer.new()
	_mk_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mk_list.add_theme_constant_override("separation", 0)
	_mk_scroll.add_child(_mk_list)
	_mk_empty = _sys_wrapped("", UiStyle.SIZE_BODY)
	_mk_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mk_empty.offset_left = 12
	_mk_empty.offset_right = -12
	_mk_empty.offset_top = 12
	stack.add_child(_mk_empty)
	left.add_child(_sys_label(TXT_NO_UNDO, UiStyle.SIZE_SMALL))
	_mk_status = UiStyle.StatusLine.new(true, 0, 1)
	left.add_child(_mk_status)
	var sep := ColorRect.new()
	sep.color = Color(0.45, 0.45, 0.45)
	sep.custom_minimum_size = Vector2(2, 0)
	cols.add_child(sep)
	# Derecha: el encargo, lo vendido y "Cerrar la noche" (lejos de los "Vender").
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(_sys_label("ENCARGO DE ESTA NOCHE", UiStyle.SIZE_BODY, TITLE_BLUE))
	_mk_quota = UiStyle.LeaderRow.new("Cuota", "", UiStyle.SIZE_BODY, SYS_TEXT)
	right.add_child(_mk_quota)
	_mk_sold = UiStyle.LeaderRow.new("Vendido", "", UiStyle.SIZE_BODY, SYS_TEXT)
	right.add_child(_mk_sold)
	_mk_missing = UiStyle.LeaderRow.new("Faltan", "", UiStyle.SIZE_BODY, SYS_TEXT)
	right.add_child(_mk_missing)
	_mk_met = _glyph_line("check", UiStyle.INK_GREEN, "¡Cuota cumplida!")
	right.add_child(_mk_met)
	var prog := HBoxContainer.new()
	prog.add_theme_constant_override("separation", 8)
	right.add_child(prog)
	_mk_bar = UiStyle.bar(Color(0.8, 0.45, 0.1), 0, 16, Color(0, 0, 0, 0.25))
	_mk_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mk_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.add_child(_mk_bar)
	_mk_pct = _sys_label("", UiStyle.SIZE_BODY)
	_mk_pct.custom_minimum_size.x = 56
	_mk_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog.add_child(_mk_pct)
	right.add_child(UiStyle.spacer(4))
	_mk_sold_title = _sys_label("", UiStyle.SIZE_BODY, TITLE_BLUE)
	right.add_child(_mk_sold_title)
	var sold_scroll := ScrollContainer.new()
	sold_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sold_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sold_scroll)
	_mk_sold_list = VBoxContainer.new()
	_mk_sold_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mk_sold_list.add_theme_constant_override("separation", 2)
	sold_scroll.add_child(_mk_sold_list)
	_mk_close = RetroButton.new("CERRAR LA NOCHE", "play", 60)
	_mk_close.add_theme_font_size_override("font_size", UiStyle.SIZE_BUTTON + 2)
	_mk_close.pressed.connect(ask_close_night)
	right.add_child(_mk_close)
	right.add_child(_sys_label(TXT_PAID_AT_CLOSE, UiStyle.SIZE_SMALL))
	_show_window(win)
	_mk_refresh()
	_market_default_focus()

func _market_default_focus() -> void:
	for id in _mk_order:
		var b: Button = _mk_rows[id]["button"]
		if not b.disabled:
			b.grab_focus()
			return
	if not _mk_sell_all.disabled:
		_mk_sell_all.grab_focus()
	else:
		_mk_close.grab_focus()

func _on_game_changed() -> void:
	if _window_kind == "market" and _window:
		_mk_refresh()

## Pone la lista al día con lo que dice el anfitrión. Lo nuevo va al final (nada se mueve debajo
## del mouse); lo que se fue, se saca (si se estaba vendiendo, se muestra "Vendido").
func _mk_refresh() -> void:
	var truck_in := bool(world.game.get("truck_in", false))
	var cargo := world.cargo_for_sale()
	var by_id := {}
	for it: Array in cargo:
		by_id[int(it[0])] = it
	for id in _mk_order.duplicate():
		if not by_id.has(id):
			_mk_remove_row(id, _mk_pending.has(id))
	for it: Array in cargo:
		var id := int(it[0])
		if _mk_rows.has(id):
			_mk_update_row(id, it)
		else:
			_mk_add_row(it, _mk_initialized)
	_mk_initialized = truck_in
	# Encabezado y "Vender todo".
	var total := 0
	var sellable := 0
	for id in _mk_order:
		var data: Array = _mk_rows[id]["data"]
		if int(data[4]) == 0 and not _mk_pending.has(id):
			total += int(data[2])
			sellable += 1
	_mk_count.text = "EN LA CAJA DEL CAMIÓN (%d)" % _mk_order.size()
	_mk_sell_all.text = "Vender todo ($%d)" % total
	_mk_sell_all.disabled = sellable == 0
	var sold := int(world.game.get("sold", 0))
	if not truck_in:
		_mk_empty.text = TXT_TRUCK_OUT
	elif _mk_order.is_empty():
		_mk_empty.text = TXT_ALL_SOLD if sold > 0 else TXT_EMPTY
	else:
		_mk_empty.text = ""
	_mk_empty.visible = _mk_empty.text != ""
	if _mk_order.is_empty() and sold > 0 and truck_in and _modal == null:
		var f := get_viewport().gui_get_focus_owner()
		if f == null or f == _mk_sell_all or (f is Button and f.get_parent() and _mk_list.is_ancestor_of(f)):
			_mk_close.grab_focus()
	_mk_refresh_summary()
	_refresh_taskbar_focus()
	for id in _mk_order:
		var b: Button = _mk_rows[id]["button"]
		b.focus_neighbor_right = b.get_path_to(_mk_close)
	if not _mk_order.is_empty():
		_mk_close.focus_neighbor_left = _mk_close.get_path_to(_mk_rows[_mk_order[0]]["button"])

func _mk_refresh_summary() -> void:
	var quota := int(world.game.get("quota", 0))
	var sold := int(world.game.get("sold", 0))
	var met := quota > 0 and sold >= quota
	_mk_quota.right.text = "$%d" % quota
	_mk_sold.right.text = "$%d" % sold
	_mk_missing.right.text = "$%d" % maxi(quota - sold, 0)
	_mk_missing.visible = not met
	_mk_met.visible = met
	var frac := clampf(float(sold) / maxf(float(quota), 1.0), 0.0, 1.0)
	_mk_bar.value = frac
	UiStyle.set_bar_color(_mk_bar, Color(0.1, 0.55, 0.15) if met else Color(0.8, 0.45, 0.1))
	_mk_pct.text = "%d %%" % floori(100.0 * sold / maxf(float(quota), 1.0))
	var items: Array = world.game.get("sold_items", [])
	_mk_sold_title.text = "VENDIDO ESTA NOCHE (%d)" % items.size()
	if items.size() == _mk_sold_count:
		return
	_mk_sold_count = items.size()
	for c in _mk_sold_list.get_children():
		c.queue_free()
	for it: Array in items:
		var row := UiStyle.LeaderRow.new(String(it[0]), "$%d" % int(it[1]), UiStyle.SIZE_BODY, SYS_TEXT)
		row.add_child(UiStyle.Glyph.new("check", UiStyle.INK_GREEN, 16.0))
		_mk_sold_list.add_child(row)

func _mk_add_row(it: Array, fresh: bool) -> void:
	var id := int(it[0])
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	wrap.clip_contents = true
	_mk_list.add_child(wrap)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_bottom = ROW_HEIGHT
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)
	var names := VBoxContainer.new()
	names.custom_minimum_size.x = 230
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -2)
	row.add_child(names)
	var name_label := _sys_label(String(it[1]), UiStyle.SIZE_BODY)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 230
	names.add_child(name_label)
	var fresh_label := _sys_label("(recién cargado)", UiStyle.SIZE_SMALL, TITLE_BLUE)
	fresh_label.visible = fresh
	names.add_child(fresh_label)
	var state := _sys_label("", UiStyle.SIZE_BODY)
	state.custom_minimum_size.x = 210
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	var price := _sys_label("", UiStyle.SIZE_BODY)
	price.custom_minimum_size.x = 80
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	var button := RetroButton.new("Vender", "play", 36)
	button.custom_minimum_size.x = 120
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_sell.bind(id))
	row.add_child(button)
	_mk_rows[id] = {"wrap": wrap, "name": name_label, "fresh": fresh_label, "state": state, "price": price, "button": button, "data": it}
	_mk_order.append(id)
	_mk_changed_ms = Time.get_ticks_msec()
	_mk_update_row(id, it)

func _mk_update_row(id: int, it: Array) -> void:
	var r: Dictionary = _mk_rows[id]
	r["data"] = it
	var holder := int(it[4])
	var dents := int(it[3])
	var state: Label = r["state"]
	if holder != 0:
		state.text = "Lo tiene %s en la mano" % world.player_names.get(holder, "otro")
	elif dents > 0:
		state.text = "Con golpes (x%d)" % dents
	else:
		state.text = "Bien"
	(r["price"] as Label).text = "$%d" % int(it[2])
	var b: RetroButton = r["button"]
	if _mk_pending.has(id):
		b.set_look("Vendiendo...", "")
		b.disabled = true
	elif holder != 0:
		b.set_look("—", "")
		b.disabled = true
	else:
		b.set_look("Vender", "play")
		b.disabled = false

func _mk_remove_row(id: int, sold: bool) -> void:
	var r: Dictionary = _mk_rows[id]
	var at := _mk_order.find(id)
	_mk_rows.erase(id)
	_mk_order.erase(id)
	_mk_pending.erase(id)
	_mk_changed_ms = Time.get_ticks_msec()
	var b: RetroButton = r["button"]
	if b.has_focus():
		# El foco pasa a la fila siguiente (o a la anterior si era la última).
		if not _mk_order.is_empty():
			(_mk_rows[_mk_order[mini(at, _mk_order.size() - 1)]]["button"] as Control).grab_focus()
		else:
			_mk_close.grab_focus()
	var wrap: Control = r["wrap"]
	if not sold:
		wrap.queue_free()
		return
	# "Vendido ✓" un ratito y la fila de abajo sube.
	b.set_look("Vendido", "check")
	b.disabled = true
	(r["state"] as Label).text = "Vendido"
	var tw := wrap.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(wrap, "custom_minimum_size:y", 0.0, 0.12)
	tw.tween_callback(wrap.queue_free)

func _sell(id: int) -> void:
	if _last_input_mouse and Time.get_ticks_msec() - _mk_changed_ms < CLICK_GUARD_MS:
		return
	if not _mk_rows.has(id) or _mk_pending.has(id):
		return
	_mk_status.clear()
	_mk_pending[id] = Time.get_ticks_msec()
	_mk_update_row(id, _mk_rows[id]["data"])
	world.request_sell(PackedInt32Array([id]))

func _sell_all() -> void:
	if _last_input_mouse and Time.get_ticks_msec() - _mk_changed_ms < CLICK_GUARD_MS:
		return
	var any := false
	for id in _mk_order:
		var data: Array = _mk_rows[id]["data"]
		if int(data[4]) == 0 and not _mk_pending.has(id):
			_mk_pending[id] = Time.get_ticks_msec()
			_mk_update_row(id, data)
			any = true
	if not any:
		return
	_mk_status.clear()
	_mk_sell_all.disabled = true
	world.request_sell(PackedInt32Array())

func _check_pending() -> void:
	var now := Time.get_ticks_msec()
	for id: int in _mk_pending.keys():
		if now - int(_mk_pending[id]) < SELL_TIMEOUT_MS or not _mk_rows.has(id):
			continue
		_mk_pending.erase(id)
		var data: Array = _mk_rows[id]["data"]
		_mk_update_row(id, data)
		_mk_status.show_error("No se pudo vender %s: revisen que nadie lo tenga en la mano y que el camión siga adentro." % String(data[1]).to_lower())
		_mk_refresh()

# ---------------------------------------------------------------- datos

## Los que no están en el galpón ni en el camión (al cerrar, pagan multa).
func _people_away() -> Array:
	var out := []
	for peer: int in world.players:
		var p: Player = world.players[peer]
		if not world.is_seated(peer) and not p.at_computer and not CityBuilder.at_warehouse(p.global_position):
			out.append(p.player_name)
	return out

static func _join_names(names: Array) -> String:
	if names.size() == 1:
		return String(names[0])
	var head := PackedStringArray()
	for i in names.size() - 1:
		head.append(String(names[i]))
	return "%s y %s" % [", ".join(head), names[-1]]

## Hora del reloj de pared: de las 23:00 a las 06:00 a lo largo de la noche.
static func clock_text(time_left: float) -> String:
	var frac := clampf(1.0 - time_left / Config.NIGHT_LENGTH, 0.0, 1.0)
	var span := fposmod(END_HOUR - START_HOUR, 24.0)
	var h := fposmod(START_HOUR + frac * span, 24.0)
	return "%02d:%02d" % [floori(h), floori(fposmod(h, 1.0) * 60.0)]

func _process(_delta: float) -> void:
	if not _open:
		return
	var left := maxf(float(world.game.get("time_left", Config.NIGHT_LENGTH)), 0.0)
	_clock.text = "%s  ·  amanece en %d:%02d" % [clock_text(left), floori(left / 60.0), int(left) % 60]
	var police := float(world.game.get("police", -1.0))
	_police_row.visible = police >= 0.0
	if _police_row.visible:
		_police.text = "Policía %d:%02d" % [floori(police / 60.0), int(police) % 60]
	if not Voice.available and Voice.debug_level < 0.0:
		_mic_word.text = "Mic: no detectado"
		_mic_bar.value = 0.0
	elif not Voice.enabled:
		_mic_word.text = "Mic: apagado"
		_mic_bar.value = 0.0
	else:
		_mic_word.text = "Mic: " + Voice.level_word(Voice.level)
		_mic_bar.value = Voice.level
		UiStyle.set_bar_color(_mic_bar, Color(0.1, 0.55, 0.1) if Voice.level < 0.25 else (Color(0.7, 0.55, 0.0) if Voice.level < 0.55 else Color(0.7, 0.1, 0.05)))
	if not _mk_pending.is_empty():
		_check_pending()

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton:
		_last_input_mouse = true
	elif event is InputEventKey:
		_last_input_mouse = false

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _modal:
			_close_modal()
		elif _start_menu.visible:
			_toggle_start_menu()
		else:
			_stand()
	elif event.is_action_pressed("debug"):
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- piezas del sistema viejo

static func _sys_label(text: String, font_size := UiStyle.SIZE_BODY, color := SYS_TEXT) -> Label:
	return UiStyle.label(text, font_size, color)

static func _sys_wrapped(text: String, font_size := UiStyle.SIZE_BODY, width := 0.0) -> Label:
	return UiStyle.wrapped(text, font_size, SYS_TEXT, width)

static func _glyph_line(kind: String, color: Color, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiStyle.Glyph.new(kind, color, 20.0, SYS_GRAY))
	var l := UiStyle.wrapped(text, UiStyle.SIZE_BODY, color if kind == "warn" else SYS_TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row

static func _hline() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.45, 0.45, 0.45)
	c.custom_minimum_size = Vector2(0, 2)
	return c

## Relieve de sistema viejo: claro arriba y a la izquierda, oscuro abajo y a la derecha.
static func draw_bevel(ci: CanvasItem, r: Rect2, sunken := false) -> void:
	var hi := Color(0.97, 0.97, 0.97)
	var lo := Color(0.25, 0.25, 0.25)
	if sunken:
		var t := hi
		hi = lo
		lo = t
	ci.draw_line(r.position + Vector2(0, 1), Vector2(r.end.x, r.position.y + 1), hi, 2.0)
	ci.draw_line(r.position + Vector2(1, 0), Vector2(r.position.x + 1, r.end.y), hi, 2.0)
	ci.draw_line(Vector2(r.position.x, r.end.y - 1), r.end - Vector2(0, 1), lo, 2.0)
	ci.draw_line(Vector2(r.end.x - 1, r.position.y), r.end - Vector2(1, 0), lo, 2.0)

## Botón de sistema viejo: gris con relieve, triángulo dibujado opcional y foco con borde amarillo
## por fuera y punteado negro por dentro (se ve sobre el gris y sobre el fondo de pantalla).
class RetroButton extends Button:
	var glyph := ""

	func _init(t := "", g := "", h := 36.0) -> void:
		theme_type_variation = &"RetroButton"
		custom_minimum_size = Vector2(0, h)
		focus_mode = Control.FOCUS_ALL
		set_look(t, g)

	func set_look(t: String, g: String) -> void:
		text = t
		glyph = g
		var pad := 32 if g != "" else 10
		for state in [&"normal", &"hover", &"disabled", &"pressed", &"hover_pressed"]:
			var sb := StyleBoxFlat.new()
			var pressed: bool = state in [&"pressed", &"hover_pressed"]
			sb.bg_color = Color(0.8, 0.8, 0.8) if state == &"hover" else (Color(0.68, 0.68, 0.68) if pressed else ComputerScreen.SYS_GRAY)
			sb.content_margin_left = pad + (1 if pressed else 0)
			sb.content_margin_right = 12
			sb.content_margin_top = 5 + (2 if pressed else 0)
			sb.content_margin_bottom = 5 - (2 if pressed else 0)
			add_theme_stylebox_override(state, sb)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		ComputerScreen.draw_bevel(self, r, get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED])
		if glyph != "" and not (disabled and glyph == "play"):
			var s := 14.0
			var c := Color(0.36, 0.36, 0.36) if disabled and glyph != "check" else (UiStyle.INK_GREEN if glyph == "check" else ComputerScreen.SYS_TEXT)
			UiStyle.draw_glyph(self, glyph, Rect2(11, (size.y - s) * 0.5, s, s), c)
		if has_focus(true):
			var inset := r.grow(-4)
			for seg: Array in [[inset.position, Vector2(inset.end.x, inset.position.y)], [Vector2(inset.end.x, inset.position.y), inset.end],
					[inset.end, Vector2(inset.position.x, inset.end.y)], [Vector2(inset.position.x, inset.end.y), inset.position]]:
				draw_dashed_line(seg[0], seg[1], Color.BLACK, 1.0, 2.0)

## Ventana de la computadora (§ 9.5): gris, barra de título azul con texto blanco y un único "✕".
## Tamaño fijo, centrada, una por vez, sin arrastrar, aparece sin animación.
class RetroWindow extends PanelContainer:
	var body: VBoxContainer
	var close_button: RetroButton
	var title_text := ""
	var danger := false
	var focusables: Array = []

	func _init(title: String, w: float, h: float, is_danger := false) -> void:
		title_text = title
		danger = is_danger
		custom_minimum_size = Vector2(w, h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = ComputerScreen.SYS_GRAY
		sb.set_content_margin_all(5 if is_danger else 3)
		add_theme_stylebox_override("panel", sb)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		add_child(box)
		var bar := PanelContainer.new()
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = ComputerScreen.TITLE_BLUE
		tsb.content_margin_left = 8
		tsb.content_margin_right = 4
		tsb.content_margin_top = 3
		tsb.content_margin_bottom = 3
		bar.add_theme_stylebox_override("panel", tsb)
		box.add_child(bar)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		bar.add_child(row)
		if is_danger:
			row.add_child(UiStyle.Glyph.new("warn", UiStyle.SIGN_YELLOW, 20.0, ComputerScreen.TITLE_BLUE))
		var t := UiStyle.label(title, UiStyle.SIZE_BODY, Color.WHITE)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		close_button = RetroButton.new("", "", 28)
		close_button.custom_minimum_size = Vector2(32, 28)
		close_button.tooltip_text = "Cerrar"
		row.add_child(close_button)
		var cross := UiStyle.Glyph.new("cross", ComputerScreen.SYS_TEXT, 14.0)
		cross.set_anchors_preset(Control.PRESET_CENTER)
		cross.position = Vector2(9, 7)
		close_button.add_child(cross)
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 12)
		margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(margin)
		body = VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		margin.add_child(body)

	func _draw() -> void:
		ComputerScreen.draw_bevel(self, Rect2(Vector2.ZERO, size))
		if danger:
			draw_rect(Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), UiStyle.ALERT_RED, false, 3.0)

## Ícono del escritorio: dibujo de 64x64 con el nombre debajo (sobre un fondo oscuro para leerse).
## Un clic abre (no hace falta doble clic).
class DesktopIcon extends Button:
	var pic := ""
	var caption := ""
	var sub := ""
	var dim := false

	func _init(p: String, title: String, subtitle := "", dimmed := false) -> void:
		pic = p
		caption = title
		sub = subtitle
		dim = dimmed
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(168, 118 if subtitle != "" else 100)
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_theme_stylebox_override(&"focus", UiStyle.focus_style(2))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		if is_hovered():
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12))
		var o := Vector2((size.x - 64.0) * 0.5, 4.0)
		var a := 0.55 if dim else 1.0
		match pic:
			"market":
				draw_rect(Rect2(o + Vector2(2, 14), Vector2(60, 36)), Color(0.35, 0.65, 0.35, a))
				draw_rect(Rect2(o + Vector2(2, 14), Vector2(60, 36)), Color(0.08, 0.3, 0.1, a), false, 2.0)
				draw_circle(o + Vector2(32, 32), 12, Color(0.55, 0.82, 0.5, a))
				var f := get_theme_default_font()
				draw_string(f, o + Vector2(24, 42), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.06, 0.25, 0.08, a))
			"tools":
				draw_rect(Rect2(o + Vector2(28, 22), Vector2(9, 38)), Color(0.55, 0.35, 0.18, a))
				draw_rect(Rect2(o + Vector2(12, 8), Vector2(40, 16)), Color(0.6, 0.62, 0.66, a))
				draw_rect(Rect2(o + Vector2(12, 8), Vector2(40, 16)), Color(0.15, 0.15, 0.18, a), false, 2.0)
			"notes":
				draw_colored_polygon(PackedVector2Array([o + Vector2(12, 4), o + Vector2(42, 4), o + Vector2(52, 14), o + Vector2(52, 60), o + Vector2(12, 60)]), Color(1, 0.96, 0.6, a))
				draw_colored_polygon(PackedVector2Array([o + Vector2(42, 4), o + Vector2(52, 14), o + Vector2(42, 14)]), Color(0.85, 0.8, 0.45, a))
				for i in 5:
					draw_line(o + Vector2(17, 22 + i * 8), o + Vector2(47, 22 + i * 8), Color(0.3, 0.4, 0.8, a), 1.5)
			"trash":
				draw_rect(Rect2(o + Vector2(26, 6), Vector2(12, 5)), Color(0.35, 0.37, 0.4, a))
				draw_rect(Rect2(o + Vector2(12, 11), Vector2(40, 6)), Color(0.55, 0.57, 0.6, a))
				draw_colored_polygon(PackedVector2Array([o + Vector2(15, 19), o + Vector2(49, 19), o + Vector2(45, 60), o + Vector2(19, 60)]), Color(0.7, 0.72, 0.75, a))
				for x in [24.0, 32.0, 40.0]:
					draw_line(o + Vector2(x, 24), o + Vector2(x, 55), Color(0.35, 0.37, 0.4, a), 2.0)
		var f2 := get_theme_default_font()
		var lines := [[caption, UiStyle.SIZE_BODY], [sub, UiStyle.SIZE_SMALL]] if sub != "" else [[caption, UiStyle.SIZE_BODY]]
		var y := 72.0
		for ln: Array in lines:
			var fs: int = ln[1]
			var w := f2.get_string_size(ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var box := Rect2((size.x - w) * 0.5 - 4.0, y, w + 8.0, fs + 7.0)
			draw_rect(box, Color(0, 0, 0, 0.6))
			draw_string(f2, Vector2(box.position.x + 4.0, y + fs + 1.0), ln[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.TEXT_LIGHT)
			y += fs + 9.0
