class_name Hud
extends CanvasLayer
## Interfaz durante la partida: reloj, botín en el camión, estado de Don Ramón, medidor de la voz,
## flecha al Galpón 7, ayuda contextual, avisos, menú de pausa y resultados de la noche.
## Todo se arma por código.

var world: World

var _clock: Label
var _truck: Label
var _police: Label
var _owner: Label
var _sleep_bar: ProgressBar
var _voice_bar: ProgressBar
var _voice_word: Label
var _prompt: Label
var _speed: Label
var _speed_warn: Label
var _gps: Control
var _gps_arrow: Polygon2D
var _gps_text: Label
var _feed: VBoxContainer
var _players: Label
var _banner: Label
var _debug: Label
var _pause: Control
var _invite: Button
var _results: Control
var _results_box: VBoxContainer
var _banner_timer := 0.0
var _banner_queue: Array[String] = []

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status(root)
	_build_owner(root)
	_build_voice(root)
	_build_center(root)
	_build_gps(root)
	_build_feed(root)
	_build_pause(root)
	_build_results(root)
	world.game_changed.connect(_refresh_game)
	world.message.connect(_on_message)
	world.players_changed.connect(_refresh_players)
	world.night_finished.connect(_show_results)
	world.night_started.connect(_hide_results)
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
	sb.bg_color = Color(0.04, 0.05, 0.09, alpha)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb

static func _bar(fill: Color, w: float, h: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(w, h)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar

static func _set_bar_color(bar: ProgressBar, c: Color) -> void:
	(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c

func _build_status(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_clock = _label("", 18, Color(0.8, 0.85, 1.0))
	_truck = _label("", 24, Color(0.55, 1.0, 0.55))
	_police = _label("", 22, Color(1.0, 0.35, 0.3))
	for l in [_clock, _truck, _police]:
		box.add_child(l)
	_debug = _label("", 14, Color(0.8, 0.95, 1.0))
	_debug.position = Vector2(16, 140)
	_debug.visible = false
	root.add_child(_debug)

func _build_owner(root: Control) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-220, 14)
	box.size = Vector2(440, 60)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_owner = _label("", 20)
	_owner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_owner)
	_sleep_bar = _bar(Color(0.45, 0.6, 1.0), 440, 10)
	box.add_child(_sleep_bar)

func _build_voice(root: Control) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.position = Vector2(16, -78)
	box.size = Vector2(260, 60)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_voice_word = _label("", 16, Color(0.85, 0.9, 1.0))
	box.add_child(_voice_word)
	_voice_bar = _bar(Color(0.4, 0.9, 0.4), 260, 14)
	box.add_child(_voice_bar)

func _build_center(root: Control) -> void:
	var cross := _label("·", 30)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.position = Vector2(-20, -20)
	cross.size = Vector2(40, 36)
	root.add_child(cross)
	_prompt = _label("", 19, Color(1.0, 0.95, 0.8))
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-500, 36)
	_prompt.size = Vector2(1000, 30)
	root.add_child(_prompt)
	# Velocímetro y aviso de "despacio" (solo cuando vas en el camión).
	_speed = _label("", 30, Color(0.9, 0.95, 1.0))
	_speed.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed.position = Vector2(-200, -110)
	_speed.size = Vector2(400, 40)
	_speed.visible = false
	root.add_child(_speed)
	_speed_warn = _label("¡Despacio! Lo de la caja se golpea", 22, Color(1.0, 0.45, 0.3))
	_speed_warn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_warn.position = Vector2(-300, -150)
	_speed_warn.size = Vector2(600, 34)
	_speed_warn.visible = false
	root.add_child(_speed_warn)
	_banner = _label("", 28, Color(1.0, 0.85, 0.35))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.position = Vector2(-340, -200)
	_banner.size = Vector2(680, 150)
	_banner.visible = false
	root.add_child(_banner)

## Flecha que apunta al Galpón 7 (cuando van en el camión o ya salieron del barrio).
func _build_gps(root: Control) -> void:
	_gps = PanelContainer.new()
	_gps.add_theme_stylebox_override("panel", _panel_style(0.5))
	_gps.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_gps.position = Vector2(-120, 86)
	_gps.size = Vector2(240, 56)
	_gps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gps.visible = false
	root.add_child(_gps)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_gps.add_child(row)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(44, 44)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	_gps_arrow = Polygon2D.new()
	_gps_arrow.polygon = PackedVector2Array([Vector2(0, -19), Vector2(14, 15), Vector2(0, 7), Vector2(-14, 15)])
	_gps_arrow.color = Color(1.0, 0.75, 0.2)
	_gps_arrow.position = Vector2(22, 22)
	holder.add_child(_gps_arrow)
	_gps_text = _label("", 20, Color(1.0, 0.85, 0.5))
	_gps_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gps_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_gps_text)

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
	panel.add_theme_stylebox_override("panel", _panel_style(0.92, Color(0.95, 0.5, 0.15)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -250)
	panel.size = Vector2(560, 500)
	_pause.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label("Pausa (la noche sigue corriendo)", 26, Color(1.0, 0.6, 0.25)))
	var resume := _button("Seguir robando... digo, mudando")
	resume.pressed.connect(_set_paused.bind(false))
	box.add_child(resume)
	box.add_child(Menu.mic_controls())
	_invite = _button("Invitar amigos de Steam")
	_invite.pressed.connect(Net.invite_friends)
	box.add_child(_invite)
	var leave := _button("Salir al menú")
	leave.pressed.connect(func() -> void: Net.leave(""))
	box.add_child(leave)
	box.add_child(_label(HELP, 15, Color(0.85, 0.85, 0.85)))

const HELP := "WASD moverse · Shift correr · C o Ctrl agacharse · Espacio saltar\n" + \
		"E agarrar, soltar, abrir puertas · Clic lanzar · F linterna\n" + \
		"Lo pesado se carga entre dos · F3 datos de depuración · Esc pausa"

func _build_results(root: Control) -> void:
	_results = ColorRect.new()
	(_results as ColorRect).color = Color(0, 0, 0, 0.7)
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.visible = false
	root.add_child(_results)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.95, Color(0.95, 0.5, 0.15)))
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	_results_box = VBoxContainer.new()
	_results_box.add_theme_constant_override("separation", 8)
	panel.add_child(_results_box)

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
		if not _pause.visible and not _results.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
			_prompt.text = "Haz clic en el juego para controlar a tu mudancero"
		_update_speed(p)
		_update_gps(p)
	_update_clock()
	_update_owner()
	_update_voice()
	if _debug.visible:
		_debug.text = world.debug_text()
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_next_banner()

func _update_speed(p: Player) -> void:
	_speed.visible = p.seat >= 0 and not world.night_over()
	_speed_warn.visible = false
	if not _speed.visible:
		return
	var kmh := roundi(world.truck.speed * 3.6)
	_speed.text = "%d km/h" % kmh
	var fast := world.truck.speed > Config.TRUCK_SAFE_SPEED
	_speed.add_theme_color_override("font_color", Color(1.0, 0.5, 0.35) if fast else Color(0.9, 0.95, 1.0))
	_speed_warn.visible = fast
	if fast:
		_speed_warn.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.008))

func _update_gps(p: Player) -> void:
	_gps.visible = (p.seat >= 0 or bool(world.game.get("away", false))) and not world.night_over()
	if not _gps.visible:
		return
	var cam := get_viewport().get_camera_3d()
	var from := world.truck.global_position if p.seat >= 0 else p.global_position
	var to := CityBuilder.WAREHOUSE - from
	to.y = 0.0
	_gps_text.text = "Galpón 7 · %d m" % roundi(to.length())
	if cam:
		var b := cam.global_transform.basis
		var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
		var right := Vector3(b.x.x, 0, b.x.z).normalized()
		_gps_arrow.rotation = atan2(to.dot(right), to.dot(fwd))

func _update_clock() -> void:
	if not world.game.has("time_left"):
		return
	var left := maxf(float(world.game["time_left"]), 0.0)
	_clock.text = "Noche %d   ·   amanece en %d:%02d" % [int(world.game["night"]), floori(left / 60.0), int(left) % 60]
	var police := float(world.game.get("police", -1.0))
	_police.visible = police >= 0.0 and not world.night_over()
	if _police.visible:
		_police.text = "¡POLICÍA EN %d:%02d!" % [floori(police / 60.0), int(police) % 60]
		_police.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.006))

func _update_owner() -> void:
	var o := world.homeowner
	_owner.text = "Don Ramón: " + o.status_text()
	var stage := HouseOwner.stage_of(o.alert)
	var c: Color = [Color(0.7, 0.8, 1.0), Color(1.0, 0.85, 0.35), Color(1.0, 0.55, 0.2)][stage]
	if o.is_awake():
		c = Color(1.0, 0.3, 0.25)
	_owner.add_theme_color_override("font_color", c)
	# La barra muestra cuánto sueño le queda (se vacía con el ruido).
	_sleep_bar.value = 0.0 if o.is_awake() else 1.0 - o.alert / Config.ALERT_WAKE
	_set_bar_color(_sleep_bar, c)

func _update_voice() -> void:
	if not Voice.available and Voice.debug_level < 0.0:
		_voice_word.text = "Micrófono: no detectado"
		_voice_bar.value = 0.0
		return
	if not Voice.enabled:
		_voice_word.text = "Micrófono: apagado (Esc para prenderlo)"
		_voice_bar.value = 0.0
		return
	var v := Voice.level
	_voice_word.text = "Tu voz: " + Voice.level_word(v)
	_voice_bar.value = v
	_set_bar_color(_voice_bar, Color(0.4, 0.9, 0.4) if v < 0.25 else (Color(1.0, 0.85, 0.3) if v < 0.55 else Color(1.0, 0.3, 0.25)))

func _refresh_game() -> void:
	if not world.game.has("truck"):
		return
	var value := int(world.game["truck"])
	var quota := int(world.game["quota"])
	_truck.text = "En el camión: $%d de $%d" % [value, quota]
	_truck.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55) if value >= quota else Color(1.0, 0.9, 0.6))

func _refresh_players() -> void:
	var lines := PackedStringArray()
	for peer: int in world.players:
		var p: Player = world.players[peer]
		lines.append(p.player_name + ("  (anfitrión)" if peer == 1 else ""))
	_players.text = "\n".join(lines)

func _on_message(text: String, level: int) -> void:
	var important := level >= World.MSG_NOTICE
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

# ---------------------------------------------------------------- resultados

const REASONS := {
	"sold": "¡Vendido en el Galpón 7!",
	"cancel": "Misión cancelada",
	"police": "¡Llegó la policía!",
	"dawn": "Amaneció...",
}

func _show_results(res: Dictionary) -> void:
	for c in _results_box.get_children():
		c.queue_free()
	var stars := int(res["stars"])
	var title := _label(REASONS.get(res["reason"], "Fin de la noche"), 34, Color(1.0, 0.6, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(title)
	var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
	var star_label := _label(star_text, 44, Color(1.0, 0.85, 0.3))
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(star_label)
	var verdict := "¡Cumplieron la cuota!" if stars > 0 else "No llegaron a la cuota."
	var lines := "Botín en el camión: $%d   (cuota $%d)   %s" % [res["value"], res["quota"], verdict]
	match res["reason"]:
		"cancel":
			lines += "\nLlegaron al galpón sin la cuota: el Flaco no les compra nada y el encargo se cancela."
		"dawn":
			lines += "\nAmaneció antes de llegar al galpón: hay que devolver todo lo cargado."
		"police":
			lines += "\nLa policía los agarró con el camión en el barrio: se pierde todo lo cargado."
	if int(res["fines"]) > 0:
		lines += "\nMultas por los que se quedaron atrás: -$%d" % res["fines"]
	lines += "\nGanancia de la noche: $%d   ·   Plata acumulada: $%d" % [res["total"], res["bank"]]
	lines += "\nDon Ramón se despertó %d %s." % [res["wakes"], "vez" if int(res["wakes"]) == 1 else "veces"]
	var summary := _label(lines, 18)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(summary)
	_add_sold_list(res)
	# Tabla por jugador.
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 22)
	for h in ["", "Botín", "Ruido", "Rotos", "Lo echaron", "Lo despertó"]:
		grid.add_child(_label(h, 15, Color(0.75, 0.75, 0.8)))
	for r: Dictionary in res["players"]:
		grid.add_child(_label(r["name"] + (" (se quedó)" if r["left"] else ""), 16, Color(1, 0.6, 0.5) if r["left"] else Color.WHITE))
		grid.add_child(_label("$%d" % r["loot"], 16))
		grid.add_child(_label(str(r["noise"]), 16))
		grid.add_child(_label(str(r["broken"]), 16))
		grid.add_child(_label(str(r["caught"]), 16))
		grid.add_child(_label(str(r["wakes"]), 16))
	var grid_center := CenterContainer.new()
	grid_center.add_child(grid)
	_results_box.add_child(grid_center)
	for t: Array in res["titles"]:
		var l := _label("%s: %s" % [t[0], t[1]], 20, Color(1.0, 0.85, 0.45))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_results_box.add_child(l)
	if world.is_server:
		var again := _button("Otra noche (Don Ramón duerme más liviano)")
		again.pressed.connect(world.srv_next_night)
		_results_box.add_child(again)
	else:
		var wait := _label("Esperando que el anfitrión empiece otra noche...", 16, Color(0.8, 0.8, 0.8))
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_results_box.add_child(wait)
	var leave := _button("Salir al menú")
	leave.pressed.connect(func() -> void: Net.leave(""))
	_results_box.add_child(leave)
	_results.visible = true
	_pause.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Lo que se llevó el reducidor (o lo que había en el camión, si no hubo venta).
func _add_sold_list(res: Dictionary) -> void:
	var sold: Array = res.get("sold", [])
	if sold.is_empty():
		return
	var head := "Lo que les compró el Flaco:" if res["reason"] == "sold" else "Lo que había en el camión:"
	var title := _label(head, 16, Color(0.75, 0.75, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	var shown := mini(sold.size(), 12)
	for i in shown:
		var it: Array = sold[i]
		var dented := int(it[2]) > 0
		grid.add_child(_label(String(it[0]) + (" (con golpes)" if dented else ""), 15, Color(1.0, 0.7, 0.55) if dented else Color.WHITE))
		grid.add_child(_label("$%d" % int(it[1]), 15, Color(0.55, 1.0, 0.55)))
	var center := CenterContainer.new()
	center.add_child(grid)
	_results_box.add_child(center)
	if sold.size() > shown:
		var more := _label("...y %d cosas más." % (sold.size() - shown), 14, Color(0.75, 0.75, 0.8))
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_results_box.add_child(more)

func _hide_results() -> void:
	if not _results.visible:
		return
	_results.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- pausa y mouse

func _set_paused(paused: bool) -> void:
	_pause.visible = paused
	_invite.visible = Net.mode == Net.Mode.STEAM
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if _results.visible:
		return
	if event.is_action_pressed("pause"):
		_set_paused(not _pause.visible)
	elif event.is_action_pressed("debug"):
		_debug.visible = not _debug.visible
	elif event is InputEventMouseButton and event.pressed and not _pause.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
