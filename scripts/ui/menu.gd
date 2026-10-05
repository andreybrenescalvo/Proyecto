class_name Menu
extends CanvasLayer
## Menú principal: nombre, crear partida, unirse por IP o por Steam.

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _steam_button: Button
var _buttons: Array[Button] = []

func _ready() -> void:
	layer = 10
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.09, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Hud._label("MINEROS ENDEUDADOS", 52, Color(1.0, 0.78, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Hud._label("Le deben una fortuna al prestamista. La mina es inestable.\nLa dinamita es barata. ¿Qué podría salir mal?", 18, Color(0.85, 0.8, 0.72))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_spacer(10))

	box.add_child(Hud._label("Tu nombre", 16, Color(0.8, 0.8, 0.8)))
	_name_edit = LineEdit.new()
	_name_edit.text = Net.player_name
	_name_edit.max_length = 20
	_name_edit.custom_minimum_size = Vector2(0, 40)
	box.add_child(_name_edit)

	var host := Hud._button("Crear partida (solo o red local / IP)")
	host.pressed.connect(_on_host)
	box.add_child(host)
	_buttons.append(host)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
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
	box.add_child(_steam_button)
	_buttons.append(_steam_button)
	if not Net.has_steam_peer():
		_steam_button.disabled = true
		_steam_button.tooltip_text = "Necesita Steam abierto y el plugin GodotSteam (ver README)."
		var note := Hud._label("Steam no detectado: para jugar por Steam hay que instalar GodotSteam (ver README).\nMientras tanto se puede probar por IP o en red local.", 14, Color(0.75, 0.7, 0.6))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)

	_status = Hud._label("", 17, Color(1.0, 0.6, 0.45))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	var quit := Hud._button("Salir")
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	var help := Hud._label("WASD moverse · Shift correr · Espacio saltar · E agarrar / botones\nClic usar herramienta · 1 Pico · 2 Dinamita · 3 Puntal · Rueda: cantidad de cartuchos", 14, Color(0.65, 0.62, 0.58))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)

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
