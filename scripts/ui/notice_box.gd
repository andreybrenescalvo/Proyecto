class_name NoticeBox
extends PanelContainer
## Cuadro de avisos (design/ux/menus-y-venta.md § 5 y § 9.4).
##
## Arriba, los avisos de la partida (hasta 4 líneas) en fila, uno por vez (con "+N" si hay más esperando y una
## línea que se acorta con el tiempo que le queda). Abajo y fija, la ayuda contextual con las
## teclas dibujadas como tapitas. Si no hay ni aviso ni ayuda, el cuadro no se ve.
##
## Los urgentes pasan adelante, llevan borde rojo de 3 px, ícono ⚠ dibujado, el rótulo "URGENTE",
## un solo pulso de opacidad al aparecer y un sonido. En la computadora del galpón se usa sin la
## ayuda (`with_help = false`), como notificación arriba de la bandeja.

const MAX_WAITING := 4
const URGENT_MIN_SECONDS := 6.0
## Si un urgente interrumpe a un aviso normal que se mostró menos que esto, el normal vuelve a la fila.
const REQUEUE_IF_SHOWN_LESS := 1.0
const URGENT_WORD := "URGENTE"

var with_help := true

var _queue: Array = []          # [texto, urgente, segundos]
var _current: Array = []        # el aviso que se está mostrando (vacío = ninguno)
var _shown_for := 0.0
var _duration := 0.0
var _help_text := ""

var _notice_box: VBoxContainer
var _urgent_row: HBoxContainer
var _notice_label: Label
var _more_label: Label
var _time_line: ProgressBar
var _separator: ColorRect
var _help_flow: HFlowContainer
var _normal_style: StyleBoxFlat
var _urgent_style: StyleBoxFlat

func _init(help := true) -> void:
	with_help = help

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_normal_style = UiStyle.night_style(0.85, UiStyle.CARDBOARD_EDGE, 2, 10)
	_urgent_style = UiStyle.night_style(0.9, UiStyle.ALERT_RED, 3, 10)
	add_theme_stylebox_override("panel", _normal_style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_notice_box = VBoxContainer.new()
	_notice_box.add_theme_constant_override("separation", 3)
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_notice_box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_box.add_child(head)
	_urgent_row = HBoxContainer.new()
	_urgent_row.add_theme_constant_override("separation", 8)
	_urgent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_urgent_row.add_child(UiStyle.Glyph.new("warn", UiStyle.ALERT_RED, 20.0, UiStyle.NIGHT))
	_urgent_row.add_child(UiStyle.label(URGENT_WORD, UiStyle.SIZE_SMALL + 1, UiStyle.ALERT_RED))
	head.add_child(_urgent_row)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(fill)
	_more_label = UiStyle.label("", UiStyle.SIZE_SMALL, UiStyle.SIGN_YELLOW)
	head.add_child(_more_label)
	_notice_label = UiStyle.wrapped("", UiStyle.SIZE_BODY, UiStyle.TEXT_LIGHT)
	_notice_label.max_lines_visible = 4
	_notice_box.add_child(_notice_label)
	_time_line = UiStyle.bar(UiStyle.SIGN_YELLOW, 0, 3, Color(1, 1, 1, 0.08))
	_notice_box.add_child(_time_line)
	_separator = ColorRect.new()
	_separator.color = Color(UiStyle.CARDBOARD_EDGE, 0.8)
	_separator.custom_minimum_size = Vector2(0, 1)
	_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_separator)
	_help_flow = UiStyle.key_text("", UiStyle.SIZE_BODY, UiStyle.TEXT_LIGHT)
	box.add_child(_help_flow)
	_refresh()

func _draw() -> void:
	# Solapita de cinta arriba a la izquierda (decorativa, sin texto).
	draw_rect(Rect2(14, -5, 46, 10), Color(UiStyle.TAPE, 0.95))

## Agrega un aviso a la fila. Los urgentes pasan adelante de todos.
func push(text: String, urgent := false, seconds := 0.0) -> void:
	if text == "":
		return
	var secs := seconds if seconds > 0.0 else clampf(2.5 + text.length() * 0.04, 3.0, 7.0)
	if urgent:
		secs = maxf(secs, URGENT_MIN_SECONDS)
	var item := [text, urgent, secs]
	if urgent:
		if not _current.is_empty() and not bool(_current[1]):
			# Interrumpe a un normal: si casi no se vio, vuelve al principio de la fila.
			if _shown_for < REQUEUE_IF_SHOWN_LESS:
				_queue.push_front(_current)
			_current = []
		# Detrás de los urgentes que ya esperan, delante de los normales.
		var at := 0
		while at < _queue.size() and bool(_queue[at][1]):
			at += 1
		_queue.insert(at, item)
	else:
		_queue.append(item)
		_trim_queue()
	if _current.is_empty():
		_next()
	else:
		_refresh()

## Ayuda contextual (texto de `Player.prompt`). Vacío = sin ayuda.
func set_help(text: String) -> void:
	if not with_help or text == _help_text:
		return
	_help_text = text
	UiStyle.fill_key_text(_help_flow, text, UiStyle.SIZE_BODY, UiStyle.TEXT_LIGHT)
	_refresh()

## Saca el aviso actual y vacía la fila.
func clear_all() -> void:
	_queue.clear()
	_current = []
	_refresh()

func waiting() -> int:
	return _queue.size()

func current_text() -> String:
	return "" if _current.is_empty() else String(_current[0])

func _trim_queue() -> void:
	while _queue.size() > MAX_WAITING:
		var dropped := false
		for i in _queue.size():
			if not bool(_queue[i][1]):
				_queue.remove_at(i)
				dropped = true
				break
		if not dropped:
			return   # los urgentes nunca se descartan

func _next() -> void:
	if _queue.is_empty():
		_current = []
		_refresh()
		return
	_current = _queue.pop_front()
	_shown_for = 0.0
	_duration = float(_current[2])
	_refresh()
	if bool(_current[1]):
		# Un solo pulso de opacidad (60 % a 100 %) y un sonido de alerta.
		modulate.a = 0.6
		create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
		Sfx.play_ui("clang", -14.0)

func _refresh() -> void:
	var has_notice := not _current.is_empty()
	var has_help := with_help and _help_text != ""
	_notice_box.visible = has_notice
	_help_flow.visible = has_help
	_separator.visible = has_notice and has_help
	visible = has_notice or has_help
	if has_notice:
		var urgent := bool(_current[1])
		_notice_label.text = String(_current[0])
		_urgent_row.visible = urgent
		_more_label.text = "+%d" % _queue.size() if _queue.size() > 0 else ""
		add_theme_stylebox_override("panel", _urgent_style if urgent else _normal_style)
		UiStyle.set_bar_color(_time_line, UiStyle.ALERT_RED if urgent else UiStyle.SIGN_YELLOW)
	else:
		add_theme_stylebox_override("panel", _normal_style)

func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_shown_for += delta
	_time_line.value = clampf(1.0 - _shown_for / maxf(_duration, 0.01), 0.0, 1.0)
	if _shown_for >= _duration:
		_next()
