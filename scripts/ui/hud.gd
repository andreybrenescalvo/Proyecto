class_name Hud
extends CanvasLayer
## Interfaz durante la partida: dinero y deuda, ayuda contextual, herramientas,
## avisos y menú de pausa. Todo se arma por código.

var world: World

var _money: Label
var _debt: Label
var _day: Label
var _quota: Label
var _strikes: Label
var _prompt: Label
var _charge: Label
var _tool_panels: Array[PanelContainer] = []
var _feed: VBoxContainer
var _players: Label
var _banner: Label
var _debug: Label
var _pause: Control
var _invite: Button
var _banner_timer := 0.0
var _banner_queue: Array[String] = []
var _style_on := _panel_style(0.75, Color(1.0, 0.8, 0.3))
var _style_off := _panel_style(0.45)

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status(root)
	_build_center(root)
	_build_toolbar(root)
	_build_feed(root)
	_build_pause(root)
	world.game_changed.connect(_refresh_game)
	world.message.connect(_on_message)
	world.players_changed.connect(_refresh_players)
	_refresh_game()

# ---------------------------------------------------------------- construcción

static func _label(text: String, size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _panel_style(alpha := 0.55, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, alpha)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb

func _build_status(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_money = _label("", 26, Color(0.55, 1.0, 0.55))
	_debt = _label("", 18, Color(1.0, 0.6, 0.5))
	_day = _label("", 18)
	_quota = _label("", 16, Color(1.0, 0.9, 0.6))
	_strikes = _label("", 16, Color(1.0, 0.5, 0.4))
	for l in [_money, _debt, _day, _quota, _strikes]:
		box.add_child(l)
	_debug = _label("", 14, Color(0.8, 0.95, 1.0))
	_debug.position = Vector2(16, 230)
	_debug.visible = false
	root.add_child(_debug)

func _build_center(root: Control) -> void:
	var cross := _label("+", 22)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.position = Vector2(-20, -16)
	cross.size = Vector2(40, 32)
	root.add_child(cross)
	_prompt = _label("", 20, Color(1.0, 0.95, 0.8))
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-450, 40)
	_prompt.size = Vector2(900, 30)
	root.add_child(_prompt)
	_banner = _label("", 28, Color(1.0, 0.85, 0.35))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.position = Vector2(-320, -190)
	_banner.size = Vector2(640, 140)
	_banner.visible = false
	root.add_child(_banner)

func _build_toolbar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-240, -78)
	bar.size = Vector2(480, 60)
	bar.add_theme_constant_override("separation", 10)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var names := ["1  Pico", "2  Dinamita", "3  Puntal ($%d)" % Config.SUPPORT_COST]
	for n in names:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(150, 0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(n, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(l)
		bar.add_child(panel)
		_tool_panels.append(panel)
	_charge = _label("", 18, Color(1.0, 0.75, 0.6))
	_charge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_charge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charge.position = Vector2(-300, -112)
	_charge.size = Vector2(600, 28)
	root.add_child(_charge)

func _build_feed(root: Control) -> void:
	_players = _label("", 16, Color(0.85, 0.9, 1.0))
	_players.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_players.position = Vector2(-336, 16)
	_players.size = Vector2(320, 90)
	root.add_child(_players)
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.position = Vector2(-436, 120)
	_feed.size = Vector2(420, 300)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)

func _build_pause(root: Control) -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.55)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.92, Color(0.9, 0.7, 0.3)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -230)
	panel.size = Vector2(520, 460)
	_pause.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label("Pausa (la mina sigue andando)", 26, Color(1.0, 0.85, 0.4)))
	var resume := _button("Seguir jugando")
	resume.pressed.connect(_set_paused.bind(false))
	box.add_child(resume)
	_invite = _button("Invitar amigos de Steam")
	_invite.pressed.connect(Net.invite_friends)
	box.add_child(_invite)
	var leave := _button("Salir al menú")
	leave.pressed.connect(func() -> void: Net.leave(""))
	box.add_child(leave)
	var help := _label(
		"WASD moverse · Shift correr · Espacio saltar\n" +
		"1 Pico · 2 Dinamita · 3 Puntal · Rueda o +/- cambia la carga\n" +
		"Clic usar herramienta / lanzar · E agarrar, soltar, botones\n" +
		"F3 datos de depuración · Esc pausa", 15, Color(0.85, 0.85, 0.85))
	box.add_child(help)

static func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 20)
	return b

# ---------------------------------------------------------------- actualización

func _process(delta: float) -> void:
	var p := world.local_player
	if p:
		_prompt.text = p.prompt
		for i in _tool_panels.size():
			_tool_panels[i].add_theme_stylebox_override("panel", _style_on if i == p.current_tool else _style_off)
		if p.current_tool == Player.Tool.DYNAMITE:
			_charge.text = "Carga: %d de %d cartuchos ($%d)   ·   rueda del mouse para cambiar" \
					% [p.charge, Config.MAX_CHARGE, p.charge * Config.DYNAMITE_COST]
		else:
			_charge.text = ""
	if world.game.has("time_left"):
		var left := maxf(float(world.game["time_left"]), 0.0)
		_day.text = "Día %d   ·   quedan %d:%02d" % [int(world.game["day"]), floori(left / 60.0), int(left) % 60]
	if _debug.visible:
		_debug.text = world.debug_text()
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_next_banner()

func _refresh_game() -> void:
	if not world.game.has("money"):
		return
	_money.text = "Dinero: $%d" % int(world.game["money"])
	_debt.text = "Deuda con el prestamista: $%d" % int(world.game["debt"])
	var due := mini(Config.quota_for_day(int(world.game["day"])), int(world.game["debt"]))
	_quota.text = "Cuota al terminar el día: $%d" % due
	var strikes := int(world.game["strikes"])
	_strikes.text = "Advertencias: %d de %d" % [strikes, Config.MAX_STRIKES] if strikes > 0 else ""
	_strikes.visible = strikes > 0

func _refresh_players() -> void:
	var lines := PackedStringArray()
	for peer: int in world.players:
		var p: Player = world.players[peer]
		lines.append(p.player_name + ("  (anfitrión)" if peer == 1 else ""))
	_players.text = "\n".join(lines)

func _on_message(text: String, important: bool) -> void:
	# Lo importante va al cartel grande (en fila, uno por vez); lo demás, a la lista de la derecha.
	if important:
		_banner_queue.append(text)
		if _banner_timer <= 0.0:
			_next_banner()
		return
	var l := _label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	_feed.add_child(l)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

func _next_banner() -> void:
	if _banner_queue.is_empty():
		_banner.visible = false
		return
	var text: String = _banner_queue.pop_front()
	show_banner(text, clampf(2.5 + text.length() * 0.04, 3.0, 7.0))

func show_banner(text: String, seconds := 0.0) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_timer = seconds

func hide_banner() -> void:
	_banner.visible = false
	_banner_timer = 0.0

# ---------------------------------------------------------------- pausa y mouse

func _set_paused(paused: bool) -> void:
	_pause.visible = paused
	_invite.visible = Net.mode == Net.Mode.STEAM
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not _pause.visible)
	elif event.is_action_pressed("debug"):
		_debug.visible = not _debug.visible
	elif event is InputEventMouseButton and event.pressed and not _pause.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
