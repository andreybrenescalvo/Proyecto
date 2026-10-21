class_name Hud
extends CanvasLayer
## Interfaz durante la partida: reloj, botín en el camión, estado de Don Ramón (solo en el
## terreno), medidor de la voz (abajo a la derecha), flecha al Galpón 7 o a la computadora,
## mira, cuadro de avisos con la ayuda contextual (abajo a la izquierda), menú de pausa,
## computadora del galpón y resultados de la noche ("el remito").
## Todo se arma por código; el estilo sale de UiStyle (design/ux/menus-y-venta.md).

const HELP_LINES := [
	"WASD moverse · Shift correr · C agacharse · Espacio saltar",
	"E agarrar, soltar, puertas · Clic lanzar · F linterna",
	"Lo pesado se carga entre dos · F3 datos de depuración · Esc pausa",
]
const CLICK_TO_PLAY := "Haz clic en el juego para controlar a tu mudancero"
const RESULTS_GUARD_MS := 600
const USABLE_KINDS := ["entity", "door", "button"]

var world: World

var _root: Control
var _play: Control               # todo lo que se ve mientras se juega (se oculta con la compu)
var _clock: Label
var _truck: Label
var _truck_check: UiStyle.Glyph
var _sold: Label
var _police_row: HBoxContainer
var _police: Label
var _owner_box: PanelContainer
var _owner: Label
var _sleep_bar: ProgressBar
var _voice_bar: ProgressBar
var _voice_word: Label
var _cross: Crosshair
var _click_prompt: Label
var _notice: NoticeBox
var _speed: Label
var _speed_warn: Label
var _gps: Control
var _gps_arrow: Polygon2D
var _gps_text: Label
var _feed: VBoxContainer
var _players: Label
var _debug: Label
var _pause: Control
var _pause_panel: Control
var _pause_clock: Label
var _pause_police: PanelContainer
var _pause_police_label: Label
var _resume: UiStyle.LabelButton
var _invite: UiStyle.LabelButton
var _pause_leave: UiStyle.LabelButton
var _pause_finish: UiStyle.LabelButton
var _pause_mic: Menu.MicPanel
var _pause_tween: Tween
var _paused := false
var _results: Control
var _results_center: CenterContainer
var _results_tween: Tween
var _results_opened_ms := 0
var _computer: ComputerScreen

func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.theme()
	add_child(_root)
	_play = Control.new()
	_play.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_play)
	_build_status(_play)
	_build_owner(_play)
	_build_voice(_play)
	_build_center(_play)
	_build_gps(_play)
	_build_feed(_play)
	_build_notice(_play)
	_build_pause(_root)
	_build_results(_root)
	_computer = ComputerScreen.new()
	_computer.world = world
	_root.add_child(_computer)
	world.game_changed.connect(_refresh_game)
	world.message.connect(_on_message)
	world.players_changed.connect(_refresh_players)
	world.night_finished.connect(_show_results)
	world.night_started.connect(_hide_results)
	_refresh_game()

# ---------------------------------------------------------------- construcción

## Texto del HUD con contorno negro (se lee sobre el mundo 3D).
static func _label(text: String, size := 18, color := Color.WHITE) -> Label:
	return UiStyle.label(text, size, color, true)

func _build_status(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.night_style(0.8, UiStyle.CARDBOARD_EDGE, 1))
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_clock = _label("", 18, Color(0.8, 0.85, 1.0))
	box.add_child(_clock)
	var truck_row := HBoxContainer.new()
	truck_row.add_theme_constant_override("separation", 8)
	truck_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(truck_row)
	_truck = _label("", 22, UiStyle.MONEY_GREEN)
	truck_row.add_child(_truck)
	_truck_check = UiStyle.Glyph.new("check", UiStyle.MONEY_GREEN, 20.0)
	truck_row.add_child(_truck_check)
	_sold = _label("", 17, UiStyle.MONEY_GREEN)
	box.add_child(_sold)
	_police_row = HBoxContainer.new()
	_police_row.add_theme_constant_override("separation", 8)
	_police_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_police_row.add_child(UiStyle.Glyph.new("warn", UiStyle.ALERT_RED, 22.0, UiStyle.NIGHT))
	_police = _label("", 22, UiStyle.ALERT_RED)
	_police_row.add_child(_police)
	box.add_child(_police_row)
	_debug = _label("", 15, Color(0.8, 0.95, 1.0))
	_debug.position = Vector2(16, 160)
	_debug.visible = false
	root.add_child(_debug)

func _build_owner(root: Control) -> void:
	_owner_box = PanelContainer.new()
	_owner_box.add_theme_stylebox_override("panel", UiStyle.night_style(0.8, UiStyle.CARDBOARD_EDGE, 1, 8))
	_owner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_owner_box.offset_left = -230
	_owner_box.offset_right = 230
	_owner_box.offset_top = 14
	_owner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_owner_box)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owner_box.add_child(box)
	_owner = _label("", 20)
	_owner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_owner)
	_sleep_bar = UiStyle.bar(Color(0.45, 0.6, 1.0), 440, 10)
	box.add_child(_sleep_bar)

## Medidor de la voz: abajo a la derecha (260 px, margen 16).
func _build_voice(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.night_style(0.8, UiStyle.CARDBOARD_EDGE, 1, 8))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -16 - 276
	panel.offset_right = -16
	panel.offset_top = -16 - 60
	panel.offset_bottom = -16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_voice_word = _label("", 16, Color(0.85, 0.9, 1.0))
	box.add_child(_voice_word)
	_voice_bar = UiStyle.bar(Color(0.4, 0.9, 0.4), 260, 14)
	box.add_child(_voice_bar)

func _build_center(root: Control) -> void:
	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.offset_left = -14
	_cross.offset_top = -14
	_cross.offset_right = 14
	_cross.offset_bottom = 14
	root.add_child(_cross)
	# "Haz clic en el juego..." se queda en el centro: mientras está, nada funciona.
	_click_prompt = _label("", 19, Color(1.0, 0.95, 0.8))
	_click_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_click_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_prompt.position = Vector2(-500, 36)
	_click_prompt.size = Vector2(1000, 30)
	root.add_child(_click_prompt)
	# Velocímetro y aviso de "despacio" (solo cuando vas en el camión); el aviso mide 400 px.
	_speed = _label("", 30, Color(0.9, 0.95, 1.0))
	_speed.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed.position = Vector2(-200, -70)
	_speed.size = Vector2(400, 40)
	_speed.visible = false
	root.add_child(_speed)
	_speed_warn = _label("¡Despacio! Lo de la caja se golpea", 22, Color(1.0, 0.45, 0.3))
	_speed_warn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speed_warn.position = Vector2(-200, -110)
	_speed_warn.size = Vector2(400, 34)
	_speed_warn.visible = false
	root.add_child(_speed_warn)

## Flecha que apunta al Galpón 7 (o, con el camión adentro, a la computadora del escritorio).
func _build_gps(root: Control) -> void:
	_gps = PanelContainer.new()
	_gps.add_theme_stylebox_override("panel", UiStyle.night_style(0.8, UiStyle.CARDBOARD_EDGE, 1))
	_gps.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_gps.offset_left = -130
	_gps.offset_right = 130
	_gps.offset_top = 92
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

## Cuadro de avisos abajo a la izquierda: 400 px de ancho, crece hacia arriba (máx. 140).
func _build_notice(root: Control) -> void:
	var corner := VBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.offset_left = 16
	corner.offset_right = 416
	corner.offset_top = -16 - 140
	corner.offset_bottom = -16
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(corner)
	_notice = NoticeBox.new(true)
	corner.add_child(_notice)

func _build_pause(root: Control) -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.55)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var panel := UiStyle.CardboardPanel.new(20)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	_pause_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiStyle.TapeTitle.new("Pausa", UiStyle.SIZE_SCREEN, -1.5, "(la noche sigue corriendo)", UiStyle.SIZE_BUTTON))
	_pause_clock = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.INK)
	box.add_child(_pause_clock)
	_pause_police = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.draw_center = false
	psb.border_color = UiStyle.INK_RED
	psb.set_border_width_all(2)
	psb.set_content_margin_all(6)
	_pause_police.add_theme_stylebox_override("panel", psb)
	_pause_police.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	_pause_police.add_child(prow)
	prow.add_child(UiStyle.Glyph.new("warn", UiStyle.INK_RED, 20.0, UiStyle.CARDBOARD))
	_pause_police_label = UiStyle.label("", UiStyle.SIZE_BODY, UiStyle.INK_RED)
	prow.add_child(_pause_police_label)
	box.add_child(_pause_police)
	_resume = UiStyle.LabelButton.new("Seguir robando... digo, mudando", true)
	_resume.pressed.connect(_set_paused.bind(false))
	box.add_child(_resume)
	_invite = UiStyle.LabelButton.new("Invitar amigos de Steam")
	_invite.pressed.connect(Net.invite_friends)
	box.add_child(_invite)
	box.add_child(UiStyle.TapeTitle.new("Micrófono", UiStyle.SIZE_BUTTON, 1.0))
	_pause_mic = Menu.mic_controls()
	box.add_child(_pause_mic)
	for line: String in HELP_LINES:
		box.add_child(UiStyle.key_text(line, UiStyle.SIZE_SMALL, UiStyle.INK))
	box.add_child(UiStyle.spacer(14))
	# Con la misión cancelada, el anfitrión termina la noche cuando quiere.
	_pause_finish = UiStyle.LabelButton.new("Terminar la noche (misión cancelada)")
	_pause_finish.pressed.connect(_finish_canceled_night)
	box.add_child(_pause_finish)
	_pause_leave = UiStyle.LabelButton.new("Salir al menú")
	_pause_leave.pressed.connect(_ask_leave_from_pause)
	box.add_child(_pause_leave)

func _build_results(root: Control) -> void:
	_results = ColorRect.new()
	(_results as ColorRect).color = Color(0, 0, 0, 0.7)
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.visible = false
	root.add_child(_results)
	_results_center = CenterContainer.new()
	_results_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.add_child(_results_center)

# ---------------------------------------------------------------- actualización

func _process(_delta: float) -> void:
	var p := world.local_player
	if p:
		_update_computer(p)
		_notice.set_help(p.prompt if not p.at_computer else "")
		_click_prompt.text = ""
		if not _paused and not _results.visible and not _computer.is_open() \
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
			_click_prompt.text = CLICK_TO_PLAY
		_cross.set_usable(p.holding_id == 0 and String(p.look.get("kind", "")) in USABLE_KINDS)
		_update_speed(p)
		_update_gps(p)
		_owner_box.visible = HouseBuilder.on_property(p.global_position) and p.seat < 0 and not p.at_computer
	_update_clock()
	if _owner_box.visible:
		_update_owner()
	_update_voice()
	if _debug.visible:
		_debug.text = world.debug_text()

## Abre la computadora cuando el jugador local se sienta y la cierra cuando se levanta.
func _update_computer(p: Player) -> void:
	if p.at_computer == _computer.is_open():
		return
	if p.at_computer:
		if _paused:
			_set_paused(false)
		_play.visible = false
		_computer.open()
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_computer.close()
		_play.visible = true
		if not _results.visible and not _paused and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	var to_desk := bool(world.game.get("truck_in", false)) and world.computer_user() == 0 and p.seat < 0
	_gps.visible = (to_desk or p.seat >= 0 or bool(world.game.get("away", false))) and not world.night_over() and not p.at_computer \
			and not world.mission_canceled()
	if not _gps.visible:
		return
	var cam := get_viewport().get_camera_3d()
	var from := world.truck.global_position if p.seat >= 0 else p.global_position
	var to := (CityBuilder.COMPUTER_DESK if to_desk else CityBuilder.WAREHOUSE) - from
	to.y = 0.0
	_gps_text.text = "%s · %d m" % ["Computadora" if to_desk else "Galpón 7", roundi(to.length())]
	if cam:
		var b := cam.global_transform.basis
		var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
		var right := Vector3(b.x.x, 0, b.x.z).normalized()
		_gps_arrow.rotation = atan2(to.dot(right), to.dot(fwd))

func _update_clock() -> void:
	if not world.game.has("time_left"):
		return
	var left := maxf(float(world.game["time_left"]), 0.0)
	var clock := "Noche %d   ·   amanece en %d:%02d" % [int(world.game["night"]), floori(left / 60.0), int(left) % 60]
	_clock.text = clock
	var police := float(world.game.get("police", -1.0))
	_police_row.visible = police >= 0.0 and not world.night_over()
	var police_text := "¡POLICÍA EN %d:%02d!" % [floori(police / 60.0), int(police) % 60]
	if _police_row.visible:
		_police.text = police_text
		_police_row.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.006))
	if _pause.visible:
		_pause_clock.text = "Noche %d · amanece en %d:%02d" % [int(world.game["night"]), floori(left / 60.0), int(left) % 60]
		_pause_police.visible = _police_row.visible
		_pause_police_label.text = "¡Policía en %d:%02d!" % [floori(police / 60.0), int(police) % 60]

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
	UiStyle.set_bar_color(_sleep_bar, c)

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
	UiStyle.set_bar_color(_voice_bar, Color(0.4, 0.9, 0.4) if v < 0.25 else (Color(1.0, 0.85, 0.3) if v < 0.55 else Color(1.0, 0.3, 0.25)))

func _refresh_game() -> void:
	if not world.game.has("truck"):
		return
	var value := int(world.game["truck"])
	var quota := int(world.game["quota"])
	var sold := int(world.game.get("sold", 0))
	_truck.text = "En el camión: $%d de $%d" % [value, quota]
	_truck.add_theme_color_override("font_color", UiStyle.MONEY_GREEN if value >= quota else Color(1.0, 0.9, 0.6))
	_truck_check.visible = value >= quota
	_sold.visible = sold > 0
	_sold.text = "Vendido al Flaco: $%d" % sold

func _refresh_players() -> void:
	var lines := PackedStringArray()
	for peer: int in world.players:
		var p: Player = world.players[peer]
		lines.append(p.player_name + ("  (anfitrión)" if peer == 1 else ""))
	_players.text = "\n".join(lines)

## Avisos de la partida: los chicos van a la lista de la derecha; los demás, al cuadro de avisos
## (o a las notificaciones de la compu, si está abierta).
func _on_message(text: String, level: int) -> void:
	if level >= World.MSG_NOTICE:
		if _computer.is_open():
			_computer.notify(text, level >= World.MSG_URGENT)
		else:
			_notice.push(text, level >= World.MSG_URGENT)
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

## Muestra un aviso normal en el cuadro de avisos (lo usa World, por ejemplo "Llegando a la casa...").
func show_banner(text: String, seconds := 0.0) -> void:
	_notice.push(text, false, seconds)

## Saca los avisos del cuadro (la ayuda contextual sigue).
func hide_banner() -> void:
	_notice.clear_all()

## El cuadro de avisos (para las pruebas y las fotos).
func notice_box() -> NoticeBox:
	return _notice

## La computadora del galpón (para las pruebas y las fotos).
func computer() -> ComputerScreen:
	return _computer

# ---------------------------------------------------------------- resultados ("el remito")

const REASONS := {
	"sold": ["¡VENDIDO EN EL GALPÓN 7!", UiStyle.INK_GREEN],
	"cancel": ["MISIÓN CANCELADA", UiStyle.INK_RED],
	"police": ["¡LLEGÓ LA POLICÍA!", UiStyle.INK_RED],
	"dawn": ["AMANECIÓ...", UiStyle.INK_BLUE],
}
const EXPLAIN := {
	"cancel": "Cerraron la noche sin llegar a la cuota: el Flaco no paga nada y el encargo se cancela.",
	"police": "La policía los agarró con el camión en el barrio: se pierde todo lo cargado.",
	"dawn": "Amaneció antes de cerrar la noche: hay que devolver todo lo cargado.",
}

func _show_results(res: Dictionary) -> void:
	for c in _results_center.get_children():
		c.queue_free()
	var reason := String(res.get("reason", "dawn"))
	var night := int(res.get("night", world.game.get("night", 1)))
	var panel := UiStyle.CardboardPanel.new(16)
	panel.custom_minimum_size = Vector2(1200, 0)
	_results_center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	root.add_child(head)
	head.add_child(UiStyle.TapeTitle.new("Remito N° 0007-%04d" % night, 28, -1.0))
	var sub := UiStyle.label("Mudanzas y Reparaciones · Galpón 7 · Noche %d" % night, UiStyle.SIZE_BODY, UiStyle.INK)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sub)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)
	var stamp := _results_summary(cols, res, reason)
	var detail := _results_detail(cols, res, reason)
	_results_people(root, res)
	_results_titles(root, res)
	# Botones: solo el anfitrión empieza otra noche.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	var again: UiStyle.LabelButton = null
	if world.is_server:
		again = UiStyle.LabelButton.new("Otra noche (Don Ramón duerme más liviano)", true)
		again.pressed.connect(func() -> void:
			if not _results_guarded():
				world.srv_next_night())
		row.add_child(again)
	else:
		var wait := UiStyle.label("Esperando que el anfitrión empiece otra noche...", UiStyle.SIZE_BODY, UiStyle.INK)
		wait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(wait)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	var leave := UiStyle.LabelButton.new("Salir al menú")
	leave.pressed.connect(_ask_leave_from_results.bind(leave))
	row.add_child(leave)
	_results.visible = true
	if _paused:
		_set_paused(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_results_opened_ms = Time.get_ticks_msec()
	# Foco: el anfitrión en "Otra noche"; el invitado en la lista (Enter ahí no hace nada).
	var order: Array = [detail, again, leave]
	UiStyle.chain_focus(order)
	var live: Array = order.filter(func(c: Variant) -> bool: return c != null)
	for i in live.size():
		var c: Control = live[i]
		c.focus_neighbor_right = c.get_path_to(live[(i + 1) % live.size()])
		c.focus_neighbor_left = c.get_path_to(live[(i - 1 + live.size()) % live.size()])
	if again:
		again.grab_focus()
	else:
		detail.grab_focus()
	_animate_results(panel, stamp)

## Columna "Resumen": sello del motivo, estrellas, plata y explicación.
func _results_summary(cols: HBoxContainer, res: Dictionary, reason: String) -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 520
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	left.add_child(UiStyle.TapeTitle.new("Resumen", UiStyle.SIZE_BUTTON))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	left.add_child(top)
	var info: Array = REASONS.get(reason, ["FIN DE LA NOCHE", UiStyle.INK])
	var stamp := _stamp(String(info[0]), info[1])
	top.add_child(stamp)
	var stars_box := VBoxContainer.new()
	stars_box.add_theme_constant_override("separation", 0)
	stars_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(stars_box)
	var stars_row := HBoxContainer.new()
	stars_row.name = "Stars"
	stars_row.add_theme_constant_override("separation", 4)
	stars_box.add_child(stars_row)
	var stars := int(res.get("stars", 0))
	for i in 3:
		var g := UiStyle.Glyph.new("star_empty", UiStyle.INK, 30.0)
		g.set_meta("full", i < stars)
		stars_row.add_child(g)
	stars_box.add_child(UiStyle.label("%d de 3 estrellas" % stars, UiStyle.SIZE_SMALL, UiStyle.INK))
	var value := int(res.get("value", 0))
	var quota := int(res.get("quota", 0))
	var fines := int(res.get("fines", 0))
	left.add_child(UiStyle.LeaderRow.new("Botín vendido", "$%d" % value))
	var quota_row := UiStyle.LeaderRow.new("Cuota del encargo", "$%d" % quota)
	quota_row.add_child(UiStyle.Glyph.new("check" if value >= quota else "cross", UiStyle.INK_GREEN if value >= quota else UiStyle.INK_RED, 18.0))
	left.add_child(quota_row)
	if value < quota:
		left.add_child(UiStyle.LeaderRow.new("Faltaron", "$%d" % (quota - value), UiStyle.SIZE_BODY, UiStyle.INK_RED))
	if fines > 0:
		var left_n := (res.get("players", []) as Array).filter(func(r: Dictionary) -> bool: return bool(r["left"])).size()
		left.add_child(UiStyle.LeaderRow.new("Multas (%d %s)" % [left_n, "se quedó" if left_n == 1 else "se quedaron"], "-$%d" % fines))
	var line := ColorRect.new()
	line.color = Color(UiStyle.INK, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	left.add_child(line)
	left.add_child(UiStyle.LeaderRow.new("GANANCIA DE LA NOCHE", "$%d" % int(res.get("total", 0)), UiStyle.SIZE_BODY + 2))
	left.add_child(UiStyle.LeaderRow.new("Plata acumulada", "$%d" % int(res.get("bank", 0))))
	var wakes := int(res.get("wakes", 0))
	left.add_child(UiStyle.label("Don Ramón se despertó %d %s." % [wakes, "vez" if wakes == 1 else "veces"], UiStyle.SIZE_BODY, UiStyle.INK))
	var explain := String(EXPLAIN.get(reason, ""))
	if bool(res.get("left_without_quota", false)):
		explain = "Se fueron del barrio sin la cuota: la misión se canceló y no cobran nada."
	if explain != "":
		var l := UiStyle.wrapped(explain, UiStyle.SIZE_BODY, UiStyle.INK, 510)
		l.max_lines_visible = 2
		left.add_child(l)
	return stamp

## El sello de goma: texto de 30 px dentro de un borde doble, girado -4°.
func _stamp(text: String, color: Color) -> Control:
	var outer := PanelContainer.new()
	var a := StyleBoxFlat.new()
	a.draw_center = false
	a.border_color = color
	a.set_border_width_all(3)
	a.set_corner_radius_all(4)
	a.set_content_margin_all(4)
	outer.add_theme_stylebox_override("panel", a)
	var inner := PanelContainer.new()
	var b := a.duplicate() as StyleBoxFlat
	b.set_border_width_all(1)
	b.content_margin_left = 12
	b.content_margin_right = 12
	b.content_margin_top = 2
	b.content_margin_bottom = 2
	inner.add_theme_stylebox_override("panel", b)
	outer.add_child(inner)
	inner.add_child(UiStyle.label(text, 26, color))
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.tilt(outer, -4.0)
	return outer

## Columna "Detalle de la mercadería": lista con desplazamiento (rueda o flechas).
func _results_detail(cols: HBoxContainer, res: Dictionary, reason: String) -> ScrollContainer:
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 632
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	right.add_child(UiStyle.TapeTitle.new("Detalle de la mercadería", UiStyle.SIZE_BUTTON, 1.0))
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.8, 0.65, 0.45)
	sb.border_color = UiStyle.CARDBOARD_EDGE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 196)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.draw_focus_border = true
	scroll.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_down", true):
			scroll.scroll_vertical += 26
			scroll.accept_event()
		elif e.is_action_pressed("ui_up", true):
			scroll.scroll_vertical -= 26
			scroll.accept_event())
	frame.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 1)
	scroll.add_child(list)
	var sold: Array = res.get("sold", [])
	var left_in: Array = res.get("left_in_truck", [])
	var groups := []
	if reason == "sold":
		groups.append(["Lo que les compró el Flaco", sold])
		groups.append(["Quedó en el camión (se pierde)", left_in])
	else:
		if not sold.is_empty():
			groups.append(["Se lo vendieron al Flaco, pero no pagó", sold])
		groups.append(["Lo que había en el camión", left_in])
	var count := 0
	for g: Array in groups:
		var items: Array = g[1]
		if items.is_empty():
			continue
		count += items.size()
		list.add_child(UiStyle.label("%s (%d)" % [g[0], items.size()], UiStyle.SIZE_BODY, UiStyle.INK_BLUE))
		var header := _detail_row("Objeto", "Estado", "Precio", UiStyle.SIZE_SMALL)
		list.add_child(header)
		for it: Array in items:
			var dents := int(it[2])
			list.add_child(_detail_row(String(it[0]), "Con golpes (x%d)" % dents if dents > 0 else "Bien", "$%d" % int(it[1])))
	if count == 0:
		list.add_child(UiStyle.label("El camión volvió vacío.", UiStyle.SIZE_BODY, UiStyle.INK))
	right.add_child(UiStyle.label("%d %s · rueda o flechas para ver todo" % [count, "cosa" if count == 1 else "cosas"], UiStyle.SIZE_SMALL, UiStyle.INK))
	return scroll

static func _detail_row(a: String, b: String, c: String, size := UiStyle.SIZE_BODY) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var widths := [300.0, 190.0, 90.0]
	var texts := [a, b, c]
	for i in 3:
		var l := UiStyle.label(texts[i], size, UiStyle.INK)
		l.custom_minimum_size.x = widths[i]
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if i == 2:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	return row

## Tabla "Personal de la mudanza".
func _results_people(root: VBoxContainer, res: Dictionary) -> void:
	root.add_child(UiStyle.TapeTitle.new("Personal de la mudanza", UiStyle.SIZE_BUTTON, -1.0))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	var heads := ["Mudancero", "Botín", "Ruido", "Rotos", "Lo echaron", "Lo despertó"]
	for i in heads.size():
		var h := UiStyle.label(heads[i], UiStyle.SIZE_SMALL, UiStyle.INK)
		h.custom_minimum_size.x = 330 if i == 0 else 110
		if i > 0:
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(h)
	for r: Dictionary in res.get("players", []):
		var gone := bool(r["left"])
		var color := UiStyle.INK_RED if gone else UiStyle.INK
		grid.add_child(UiStyle.label(String(r["name"]) + (" (se quedó)" if gone else ""), UiStyle.SIZE_BODY, color))
		for v in ["$%d" % int(r["loot"]), str(r["noise"]), str(r["broken"]), str(r["caught"]), str(r["wakes"])]:
			var l := UiStyle.label(v, UiStyle.SIZE_BODY, color)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(l)

## Premios: etiquetas de caja en una fila que se ajusta (si no hay, no se muestra).
func _results_titles(root: VBoxContainer, res: Dictionary) -> void:
	var titles: Array = res.get("titles", [])
	if titles.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	var head := UiStyle.label("PREMIOS", UiStyle.SIZE_BODY, UiStyle.INK)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(head)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 6)
	row.add_child(flow)
	for t: Array in titles:
		var tag := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiStyle.TAPE
		sb.border_color = Color(UiStyle.INK, 0.5)
		sb.set_border_width_all(1)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		tag.add_theme_stylebox_override("panel", sb)
		tag.add_child(UiStyle.label("%s: %s" % [t[0], t[1]], UiStyle.SIZE_BODY, UiStyle.INK))
		flow.add_child(tag)

## El remito "se apoya" (cae 20 px), el sello aparece con un "tunc" y las estrellas se llenan
## una por una. Cualquier tecla lo muestra todo de una.
func _animate_results(panel: Control, stamp: Control) -> void:
	if _results_tween:
		_results_tween.kill()
	_results.modulate.a = 0.0
	panel.offset_transform_enabled = true
	panel.offset_transform_visual_only = true
	panel.offset_transform_position = Vector2(0, -20)
	stamp.modulate.a = 0.0
	var stars: Array = panel.find_child("Stars", true, false).get_children()
	_results_tween = create_tween()
	_results_tween.tween_property(_results, "modulate:a", 1.0, 0.2)
	_results_tween.tween_property(panel, "offset_transform_position", Vector2.ZERO, 0.25).set_ease(Tween.EASE_OUT)
	_results_tween.tween_interval(0.3)
	_results_tween.tween_callback(func() -> void:
		stamp.modulate.a = 1.0
		Sfx.play_ui("thud", -6.0))
	for g: UiStyle.Glyph in stars:
		if g.get_meta("full", false):
			_results_tween.tween_interval(0.15)
			_results_tween.tween_callback(g.set_kind.bind("star", UiStyle.SIGN_YELLOW))

func _skip_results_animation() -> void:
	if _results_tween and _results_tween.is_running():
		_results_tween.custom_step(10.0)

func _results_guarded() -> bool:
	return Time.get_ticks_msec() - _results_opened_ms < RESULTS_GUARD_MS

func _ask_leave_from_results(button: Control) -> void:
	if _results_guarded():
		return
	if world.is_server and world.players.size() > 1:
		var dlg := UiStyle.ConfirmDialog.new("¿Salir al menú?", ["Los demás también vuelven al menú."], "Salir", "Volver")
		dlg.confirmed.connect(func() -> void: Net.leave(""))
		dlg.cancelled.connect(func() -> void: if is_instance_valid(button): button.grab_focus())
		_results.add_child(dlg)
	else:
		Net.leave("")

func _hide_results() -> void:
	if not _results.visible:
		return
	if _results_tween:
		_results_tween.kill()
	_results.visible = false
	if DisplayServer.get_name() != "headless" and not _computer.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- pausa y mouse

func _finish_canceled_night() -> void:
	_set_paused(false)
	world.srv_finish_canceled()

func _set_paused(paused: bool) -> void:
	if _pause_tween:
		_pause_tween.kill()
	_paused = paused
	_invite.visible = Net.mode == Net.Mode.STEAM
	_pause_finish.visible = world.is_server and world.mission_canceled() and not world.night_over()
	if paused:
		_pause.visible = true
		_pause.modulate.a = 0.0
		_pause_tween = create_tween()
		_pause_tween.tween_property(_pause, "modulate:a", 1.0, 0.12)
		_update_clock()
		UiStyle.chain_focus([_resume, _invite, _pause_mic.toggle, _pause_mic.slider, _pause_finish, _pause_leave], true)
		_resume.grab_focus()
	else:
		for c in _pause.get_children():
			if c is UiStyle.ConfirmDialog:
				c.queue_free()
		var f := get_viewport().gui_get_focus_owner()
		if f and _pause.is_ancestor_of(f):
			f.release_focus()
		_pause_tween = create_tween()
		_pause_tween.tween_property(_pause, "modulate:a", 0.0, 0.08)
		_pause_tween.tween_callback(func() -> void: _pause.visible = false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

## Abre (o cierra) la pausa (también para las fotos).
func set_paused(paused: bool) -> void:
	_set_paused(paused)

## "Salir al menú" pide confirmación; el texto distingue anfitrión de invitado.
func _ask_leave_from_pause() -> void:
	var line := "Tus compañeros siguen sin ti."
	if Net.mode == Net.Mode.SOLO:
		line = "Se pierde lo de esta noche."
	elif world.is_server:
		line = "Eres el anfitrión: la partida se termina para todos."
	var dlg := UiStyle.ConfirmDialog.new("¿Salir al menú?", [line], "Salir", "Volver")
	dlg.confirmed.connect(func() -> void: Net.leave(""))
	dlg.cancelled.connect(func() -> void: _pause_leave.grab_focus())
	_pause.add_child(dlg)

func _unhandled_input(event: InputEvent) -> void:
	if _computer.is_open():
		return
	if _results.visible:
		if event is InputEventKey and event.pressed:
			_skip_results_animation()
		return
	if event.is_action_pressed("pause"):
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug"):
		_debug.visible = not _debug.visible
	elif event is InputEventMouseButton and event.pressed and not _paused \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## La mira: un punto, o un anillo chico cuando hay algo para usar (la ayuda está en el cuadro).
class Crosshair extends Control:
	var usable := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_usable(on: bool) -> void:
		if on != usable:
			usable = on
			queue_redraw()

	func _draw() -> void:
		var mid := size * 0.5
		if usable:
			draw_arc(mid, 9.0, 0.0, TAU, 32, Color(0, 0, 0, 0.8), 5.0, true)
			draw_arc(mid, 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.95), 2.5, true)
		else:
			draw_circle(mid, 3.5, Color(0, 0, 0, 0.8))
			draw_circle(mid, 2.2, Color(1, 1, 1, 0.95))
