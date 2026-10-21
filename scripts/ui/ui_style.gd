class_name UiStyle
extends RefCounted
## Estilo común de la interfaz: "cartón de mudanza" (ver design/ux/menus-y-venta.md § 0 y § 9).
##
## Junta la paleta, los tamaños de letra, un `Theme` armado por código (botones etiqueta, campos,
## casillas, deslizadores, listas) y piezas reutilizables: panel de cartón, título cinta, tapitas
## de teclas, línea de estado, renglón con puntos guía y confirmación.
##
## Los símbolos ▸ ★ ✓ ⚠ ✕ NO están en la fuente por defecto (en la web saldrían cuadraditos):
## se dibujan como polígonos con `draw_glyph` o con el control `Glyph`.

# ---------------------------------------------------------------- paleta (§ 0.3)

const NIGHT := Color(0.05, 0.06, 0.1)
const BRAND_ORANGE := Color(0.95, 0.5, 0.15)
const SIGN_YELLOW := Color(1, 0.85, 0.35)
const MONEY_GREEN := Color(0.55, 1, 0.55)
const CARDBOARD := Color(0.72, 0.55, 0.36)
const CARDBOARD_EDGE := Color(0.55, 0.4, 0.25)
const TAPE := Color(0.78, 0.55, 0.25)
const INK := Color(0.1, 0.07, 0.04)
const ALERT_RED := Color(1, 0.35, 0.3)
const TEXT_LIGHT := Color(0.92, 0.93, 0.97)
const TEXT_MUTED := Color(0.6, 0.62, 0.7)
const VERSION_GRAY := Color(0.5, 0.52, 0.6)
const DISABLED_CARD := Color(0.5, 0.46, 0.4)
## Tintas oscuras para escribir sobre cartón (sello de los resultados, errores). Son un poco más
## oscuras que las de la spec para pasar 3:1 sobre `CARDBOARD` con letra de 30 px.
const INK_RED := Color(0.5, 0.08, 0.06)
const INK_GREEN := Color(0.07, 0.28, 0.09)
const INK_BLUE := Color(0.1, 0.18, 0.4)

# ---------------------------------------------------------------- tamaños de letra a 720p

const SIZE_SMALL := 15
const SIZE_BODY := 17
const SIZE_BUTTON := 20
const SIZE_SECTION := 22
const SIZE_SCREEN := 34
const SIZE_MENU_TITLE := 52

const BUTTON_HEIGHT := 44
const BUTTON_HEIGHT_PRIMARY := 52

static var _theme: Theme

## El `Theme` común. Se arma una sola vez y se aplica a la raíz de cada pantalla.
static func theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme

# ---------------------------------------------------------------- estilos

## Fondo de cartón (panel de menús, pausa, resultados y confirmaciones).
static func cardboard_style(margin := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARDBOARD
	sb.border_color = CARDBOARD_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(3, 4)
	sb.set_content_margin_all(margin)
	return sb

## Panel oscuro translúcido con borde fino de cartón (el que usa el HUD).
static func night_style(alpha := 0.85, border := CARDBOARD_EDGE, width := 2, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(NIGHT, alpha)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(margin)
	if width > 0:
		sb.set_border_width_all(width)
		sb.border_color = border
	return sb

## Borde de foco: 3 px de amarillo cartel por fuera del control.
static func focus_style(radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = SIGN_YELLOW
	sb.set_border_width_all(3)
	sb.set_expand_margin_all(4)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 1
	return sb

## Etiqueta de caja: naranja, esquinas apenas cortadas y borde de tinta de 1 px.
static func _label_button_style(bg: Color, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = INK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.corner_detail = 1
	sb.content_margin_left = 42
	sb.content_margin_right = 18
	sb.content_margin_top = 6 + (2 if pressed else 0)
	sb.content_margin_bottom = 6 - (2 if pressed else 0)
	if pressed:
		sb.expand_margin_top = -2
		sb.expand_margin_bottom = 2
	return sb

static func _flat(bg: Color, margin := 4.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(margin)
	return sb

static func _empty(margin := 4.0) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(margin)
	return sb

static func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = SIZE_BODY
	t.set_color(&"font_color", &"Label", TEXT_LIGHT)
	t.set_font_size(&"font_size", &"Label", SIZE_BODY)
	t.set_stylebox(&"panel", &"PanelContainer", cardboard_style())
	# Botón etiqueta.
	t.set_stylebox(&"normal", &"Button", _label_button_style(BRAND_ORANGE))
	t.set_stylebox(&"hover", &"Button", _label_button_style(BRAND_ORANGE.lightened(0.12)))
	t.set_stylebox(&"pressed", &"Button", _label_button_style(BRAND_ORANGE.darkened(0.18), true))
	t.set_stylebox(&"hover_pressed", &"Button", _label_button_style(BRAND_ORANGE.darkened(0.18), true))
	var dis := _label_button_style(DISABLED_CARD)
	dis.content_margin_left = 18
	t.set_stylebox(&"disabled", &"Button", dis)
	t.set_stylebox(&"focus", &"Button", focus_style())
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		t.set_color(c, &"Button", INK)
	t.set_color(&"font_disabled_color", &"Button", Color(INK, 0.7))
	t.set_font_size(&"font_size", &"Button", SIZE_BUTTON)
	# Botones de la computadora del galpón (sistema viejo): ver ComputerScreen.
	t.set_type_variation(&"RetroButton", &"Button")
	var retro := _flat(Color(0.75, 0.75, 0.75), 6.0)
	retro.set_corner_radius_all(0)
	retro.content_margin_left = 10
	retro.content_margin_right = 10
	t.set_stylebox(&"normal", &"RetroButton", retro)
	var retro_hover := retro.duplicate() as StyleBoxFlat
	retro_hover.bg_color = Color(0.8, 0.8, 0.8)
	t.set_stylebox(&"hover", &"RetroButton", retro_hover)
	var retro_pressed := retro.duplicate() as StyleBoxFlat
	retro_pressed.bg_color = Color(0.68, 0.68, 0.68)
	retro_pressed.content_margin_top = 8
	retro_pressed.content_margin_bottom = 4
	t.set_stylebox(&"pressed", &"RetroButton", retro_pressed)
	t.set_stylebox(&"hover_pressed", &"RetroButton", retro_pressed)
	t.set_stylebox(&"disabled", &"RetroButton", retro)
	t.set_stylebox(&"focus", &"RetroButton", focus_style(0))
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		t.set_color(c, &"RetroButton", Color(0.04, 0.04, 0.04))
	t.set_color(&"font_disabled_color", &"RetroButton", Color(0.36, 0.36, 0.36))
	t.set_font_size(&"font_size", &"RetroButton", SIZE_BODY)
	# Casilla (va sobre cartón: texto en tinta).
	for s in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		t.set_stylebox(s, &"CheckBox", _empty(4.0))
	t.set_stylebox(&"focus", &"CheckBox", focus_style(4))
	t.set_icon(&"checked", &"CheckBox", _check_icon(true))
	t.set_icon(&"unchecked", &"CheckBox", _check_icon(false))
	t.set_icon(&"checked_disabled", &"CheckBox", _check_icon(true))
	t.set_icon(&"unchecked_disabled", &"CheckBox", _check_icon(false))
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		t.set_color(c, &"CheckBox", INK)
	t.set_font_size(&"font_size", &"CheckBox", SIZE_BODY)
	t.set_constant(&"h_separation", &"CheckBox", 8)
	# Campo de texto.
	var edit := _flat(Color(0.1, 0.1, 0.14, 0.95), 10.0)
	edit.border_color = CARDBOARD_EDGE
	edit.set_border_width_all(2)
	t.set_stylebox(&"normal", &"LineEdit", edit)
	t.set_stylebox(&"read_only", &"LineEdit", edit)
	t.set_stylebox(&"focus", &"LineEdit", focus_style(4))
	t.set_color(&"font_color", &"LineEdit", TEXT_LIGHT)
	t.set_color(&"font_placeholder_color", &"LineEdit", TEXT_MUTED)
	t.set_color(&"caret_color", &"LineEdit", SIGN_YELLOW)
	t.set_color(&"selection_color", &"LineEdit", Color(BRAND_ORANGE, 0.45))
	t.set_font_size(&"font_size", &"LineEdit", 18)
	# Deslizador.
	var track := _flat(Color(INK, 0.55), 0.0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox(&"slider", &"HSlider", track)
	var area := track.duplicate() as StyleBoxFlat
	area.bg_color = BRAND_ORANGE.darkened(0.1)
	t.set_stylebox(&"grabber_area", &"HSlider", area)
	var area_hi := area.duplicate() as StyleBoxFlat
	area_hi.bg_color = BRAND_ORANGE
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", area_hi)
	t.set_stylebox(&"focus", &"HSlider", focus_style(4))
	t.set_icon(&"grabber", &"HSlider", _dot_icon(BRAND_ORANGE))
	t.set_icon(&"grabber_highlight", &"HSlider", _dot_icon(BRAND_ORANGE.lightened(0.2)))
	t.set_icon(&"grabber_disabled", &"HSlider", _dot_icon(DISABLED_CARD))
	# Listas con desplazamiento.
	t.set_stylebox(&"panel", &"ScrollContainer", _empty(0.0))
	t.set_stylebox(&"focus", &"ScrollContainer", focus_style(2))
	var bar_bg := _flat(Color(0, 0, 0, 0.18), 0.0)
	bar_bg.content_margin_left = 5
	bar_bg.content_margin_right = 5
	t.set_stylebox(&"scroll", &"VScrollBar", bar_bg)
	t.set_stylebox(&"grabber", &"VScrollBar", _flat(Color(INK, 0.6), 0.0))
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat(Color(INK, 0.8), 0.0))
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", _flat(INK, 0.0))
	return t

## Ícono de la casilla, dibujado píxel por píxel (cajita clara con tilde de tinta).
static func _check_icon(checked: bool, s := 24) -> ImageTexture:
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(1, 1, s - 2, s - 2), INK)
	img.fill_rect(Rect2i(3, 3, s - 6, s - 6), Color(0.96, 0.93, 0.86))
	if checked:
		_stroke(img, [Vector2(6, 12), Vector2(10, 17), Vector2(18, 6)], 1.7, INK)
	return ImageTexture.create_from_image(img)

static func _dot_icon(c: Color, s := 22) -> ImageTexture:
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid := Vector2(s, s) * 0.5 - Vector2(0.5, 0.5)
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(mid)
			if d <= s * 0.5 - 1.0:
				img.set_pixel(x, y, INK if d > s * 0.5 - 3.0 else c)
	return ImageTexture.create_from_image(img)

static func _stroke(img: Image, pts: Array, r: float, c: Color) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := int(a.distance_to(b) * 2.0) + 1
		for k in steps + 1:
			var p := a.lerp(b, float(k) / steps)
			for y in range(floori(p.y - r), ceili(p.y + r) + 1):
				for x in range(floori(p.x - r), ceili(p.x + r) + 1):
					if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(p) <= r:
						img.set_pixel(x, y, c)

# ---------------------------------------------------------------- símbolos dibujados

## Dibuja un símbolo dentro de `r`: "play" (▸), "star" (★), "star_empty" (☆), "check" (✓),
## "warn" (⚠), "cross" (✕). `inner` es el color del signo de admiración de "warn".
static func draw_glyph(ci: CanvasItem, kind: String, r: Rect2, c: Color, inner := INK) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.position + (r.size - Vector2(s, s)) * 0.5
	match kind:
		"play":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0.18, 0.1) * s, o + Vector2(0.9, 0.5) * s, o + Vector2(0.18, 0.9) * s]), c)
		"star", "star_empty":
			var pts := PackedVector2Array()
			var mid := o + Vector2(s, s) * 0.5
			for i in 10:
				var rad := s * (0.5 if i % 2 == 0 else 0.21)
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(mid + Vector2(cos(a), sin(a)) * rad + Vector2(0, s * 0.04))
			if kind == "star":
				ci.draw_colored_polygon(pts, c)
				if inner != c:
					pts.append(pts[0])
					ci.draw_polyline(pts, inner, maxf(1.0, s * 0.05), true)
			else:
				ci.draw_colored_polygon(pts, Color(c, 0.18))
				pts.append(pts[0])
				ci.draw_polyline(pts, c, maxf(1.5, s * 0.07), true)
		"check":
			ci.draw_polyline(PackedVector2Array([o + Vector2(0.12, 0.55) * s, o + Vector2(0.4, 0.82) * s, o + Vector2(0.9, 0.2) * s]), c, maxf(2.0, s * 0.17))
		"cross":
			var w := maxf(2.0, s * 0.16)
			ci.draw_line(o + Vector2(0.18, 0.18) * s, o + Vector2(0.82, 0.82) * s, c, w)
			ci.draw_line(o + Vector2(0.82, 0.18) * s, o + Vector2(0.18, 0.82) * s, c, w)
		"warn":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0.5, 0.04) * s, o + Vector2(0.98, 0.94) * s, o + Vector2(0.02, 0.94) * s]), c)
			ci.draw_rect(Rect2(o + Vector2(0.43, 0.32) * s, Vector2(0.14, 0.34) * s), inner)
			ci.draw_rect(Rect2(o + Vector2(0.43, 0.73) * s, Vector2(0.14, 0.12) * s), inner)

## Un símbolo dibujado como control (para meterlo en contenedores, al lado de un texto).
class Glyph extends Control:
	var kind := "play"
	var color := UiStyle.INK
	var inner := UiStyle.INK

	func _init(k := "play", c := UiStyle.INK, s := 16.0, inner_color := UiStyle.INK) -> void:
		kind = k
		color = c
		inner = inner_color
		custom_minimum_size = Vector2(s, s)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(k: String, c: Color) -> void:
		kind = k
		color = c
		queue_redraw()

	func _draw() -> void:
		UiStyle.draw_glyph(self, kind, Rect2(Vector2.ZERO, size), color, inner)

# ---------------------------------------------------------------- piezas

## Texto simple. `outline` agrega el contorno negro del HUD (para leerse sobre el mundo 3D).
static func label(text: String, font_size := SIZE_BODY, color := TEXT_LIGHT, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Texto con ajuste de línea a un ancho dado.
static func wrapped(text: String, font_size := SIZE_BODY, color := TEXT_LIGHT, width := 0.0) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	return l

static func bar(fill: Color, w: float, h: float, bg := Color(0, 0, 0, 0.6)) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.max_value = 1.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = bg
	back.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", back)
	b.add_theme_stylebox_override("fill", fg)
	return b

static func set_bar_color(b: ProgressBar, c: Color) -> void:
	(b.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c

static func spacer(h: float, w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Gira un control sin que el contenedor lo enderece (solo cambia cómo se ve).
static func tilt(c: Control, degrees: float) -> void:
	c.offset_transform_enabled = true
	c.offset_transform_visual_only = true
	c.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	c.offset_transform_rotation = deg_to_rad(degrees)

## Encadena el foco de Tab / Shift+Tab en ciclo cerrado (el foco no se escapa de la pantalla).
## Saltea lo oculto y lo deshabilitado. Con `vertical`, ↑ y ↓ también dan la vuelta en los extremos.
static func chain_focus(list: Array, vertical := false) -> void:
	var items: Array[Control] = []
	for c: Control in list:
		if c != null and c.is_inside_tree() and c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE \
				and not (c is BaseButton and (c as BaseButton).disabled):
			items.append(c)
	var n := items.size()
	for i in n:
		var c := items[i]
		var nxt := items[(i + 1) % n]
		var prv := items[(i - 1 + n) % n]
		c.focus_next = c.get_path_to(nxt)
		c.focus_previous = c.get_path_to(prv)
		if vertical:
			c.focus_neighbor_bottom = c.get_path_to(nxt)
			c.focus_neighbor_top = c.get_path_to(prv)

## Botón etiqueta (§ 9.1): etiqueta de caja naranja con un triángulo dibujado a la izquierda.
## Al pasar el mouse el triángulo se corre 4 px; deshabilitado, no lo muestra.
class LabelButton extends Button:
	func _init(t := "", primary := false) -> void:
		text = t
		custom_minimum_size = Vector2(0, UiStyle.BUTTON_HEIGHT_PRIMARY if primary else UiStyle.BUTTON_HEIGHT)
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(func() -> void: Sfx.play_ui("click", -18.0))

	func _draw() -> void:
		if disabled:
			return
		var s := 15.0
		var x := 18.0 + (4.0 if is_hovered() else 0.0)
		var y := (size.y - s) * 0.5 + (2.0 if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 0.0)
		UiStyle.draw_glyph(self, "play", Rect2(x, y, s, s), UiStyle.INK)

## Panel de cartón (§ 9.2): cartón con canaletas suaves de corrugado (dibujadas, sin textura).
class CardboardPanel extends PanelContainer:
	func _init(margin := 16) -> void:
		add_theme_stylebox_override("panel", UiStyle.cardboard_style(margin))

	func _draw() -> void:
		var c := Color(UiStyle.CARDBOARD_EDGE, 0.13)
		var x := 6.0
		while x < size.x - 3.0:
			draw_line(Vector2(x, 3), Vector2(x, size.y - 3), c, 2.0)
			x += 9.0

## Título cinta (§ 9.3): tira de cinta de embalar con el texto en tinta encima (es un Label).
## `sub` es un texto más chico en la misma cinta ("(la noche sigue corriendo)").
class TapeTitle extends PanelContainer:
	var title: Label

	func _init(t: String, font_size := UiStyle.SIZE_SCREEN, degrees := 0.0, sub := "", sub_size := UiStyle.SIZE_BUTTON) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiStyle.TAPE
		sb.content_margin_left = 14 if font_size < 30 else 20
		sb.content_margin_right = sb.content_margin_left
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		add_theme_stylebox_override("panel", sb)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		add_child(row)
		title = UiStyle.label(t.to_upper(), font_size, UiStyle.INK)
		row.add_child(title)
		if sub != "":
			var s := UiStyle.label(sub, sub_size, UiStyle.INK)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(s)
		if degrees != 0.0:
			UiStyle.tilt(self, degrees)

	func _draw() -> void:
		# Brillo de la cinta y bordes dentados (los dientes salen un poco por los costados).
		draw_rect(Rect2(0, 2, size.x, maxf(2.0, size.y * 0.12)), Color(1, 1, 1, 0.16))
		draw_rect(Rect2(0, size.y - 3, size.x, 2), Color(0, 0, 0, 0.12))
		var step := 6.0
		var y := 0.0
		while y < size.y:
			var h := minf(step, size.y - y)
			draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(-4, y + h * 0.5), Vector2(0, y + h)]), UiStyle.TAPE)
			draw_colored_polygon(PackedVector2Array([Vector2(size.x, y), Vector2(size.x + 4, y + h * 0.5), Vector2(size.x, y + h)]), UiStyle.TAPE)
			y += step

## Tapita de tecla (§ 9.7): la tecla dibujada como una cajita clara con la letra.
static func key_cap(key: String, font_size := SIZE_SMALL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.9, 0.82)
	sb.border_color = INK
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(key, font_size, INK))
	return p

## Palabras que se dibujan como tapitas en la ayuda ("E:", "W/S", "Clic:", "Espacio"...).
const KEY_WORDS := ["E", "F", "C", "W/S", "A/D", "WASD", "Shift", "Ctrl", "Espacio", "Clic", "Esc", "F3", "Tab", "Enter"]

## Arma una línea de ayuda que se ajusta sola: las teclas van como tapitas y el resto como texto.
## Ejemplo: "E: agarrar Televisor ($400)   ·   frágil".
static func key_text(text: String, font_size := SIZE_BODY, color := TEXT_LIGHT, outline := false) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 3)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_key_text(flow, text, font_size, color, outline)
	return flow

static func fill_key_text(flow: HFlowContainer, text: String, font_size := SIZE_BODY, color := TEXT_LIGHT, outline := false) -> void:
	for c in flow.get_children():
		flow.remove_child(c)
		c.queue_free()
	var words := text.replace("   ·   ", " · ").split(" ", false)
	var run := PackedStringArray()
	for w in words:
		var bare := w.trim_suffix(":")
		if bare in KEY_WORDS:
			if not run.is_empty():
				_flow_words(flow, run, font_size, color, outline)
				run.clear()
			flow.add_child(key_cap(bare, font_size - 1))
		else:
			run.append(w)
	if not run.is_empty():
		_flow_words(flow, run, font_size, color, outline)

static func _flow_words(flow: HFlowContainer, words: PackedStringArray, font_size: int, color: Color, outline: bool) -> void:
	# Una palabra por Label, así el flujo puede cortar la línea donde haga falta.
	for w in words:
		flow.add_child(label(w, font_size, color, outline))

## Renglón con puntos guía: "Cuota ............ $1200".
class LeaderRow extends HBoxContainer:
	var left: Label
	var right: Label
	var _dots: Control

	func _init(l: String, r: String, font_size := UiStyle.SIZE_BODY, color := UiStyle.INK) -> void:
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		left = UiStyle.label(l, font_size, color)
		add_child(left)
		_dots = Control.new()
		_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.draw.connect(_draw_dots.bind(Color(color, 0.55)))
		add_child(_dots)
		right = UiStyle.label(r, font_size, color)
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(right)

	func _draw_dots(c: Color) -> void:
		var y := _dots.size.y * 0.72
		var x := 2.0
		while x < _dots.size.x - 2.0:
			_dots.draw_rect(Rect2(x, y, 2, 2), c)
			x += 6.0

## Línea de estado (§ 9.7): alto reservado para que nada salte; "trabajando..." o error con ⚠.
class StatusLine extends HBoxContainer:
	var text_label: Label
	var _icon: UiStyle.Glyph
	var _info: Color
	var _error: Color

	func _init(on_card := false, width := 0.0, lines := 2, font_size := UiStyle.SIZE_BODY) -> void:
		_info = UiStyle.INK if on_card else UiStyle.SIGN_YELLOW
		_error = UiStyle.INK_RED if on_card else UiStyle.ALERT_RED
		add_theme_constant_override("separation", 8)
		custom_minimum_size = Vector2(width, lines * (font_size + 7))
		_icon = UiStyle.Glyph.new("warn", _error, 20.0, UiStyle.CARDBOARD if on_card else UiStyle.NIGHT)
		_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_icon.visible = false
		add_child(_icon)
		text_label = UiStyle.wrapped("", font_size, _info)
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.max_lines_visible = lines
		add_child(text_label)

	func show_info(t: String) -> void:
		_icon.visible = false
		text_label.text = t
		text_label.add_theme_color_override("font_color", _info)

	func show_error(t: String) -> void:
		_icon.visible = t != ""
		text_label.text = t
		text_label.add_theme_color_override("font_color", _error)

	func clear() -> void:
		show_info("")

## Confirmación (§ 9.6) en panel de cartón: oscurece todo, pregunta, dice la consecuencia y tiene
## dos botones que dicen lo que hacen. El foco empieza en el botón seguro; Esc = botón seguro;
## los primeros 400 ms no responde (guarda de entrada).
class ConfirmDialog extends ColorRect:
	signal confirmed
	signal cancelled

	const GUARD_MS := 400
	var safe_button: UiStyle.LabelButton
	var confirm_button: UiStyle.LabelButton
	var _opened_ms := 0

	func _init(question: String, lines: Array, confirm_text: String, safe_text: String, danger := false) -> void:
		color = Color(0, 0, 0, 0.5)
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		var panel := UiStyle.CardboardPanel.new(20)
		if danger:
			var sb := UiStyle.cardboard_style(20)
			sb.border_color = UiStyle.ALERT_RED
			sb.set_border_width_all(3)
			panel.add_theme_stylebox_override("panel", sb)
		panel.custom_minimum_size = Vector2(560, 0)
		center.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		box.add_child(head)
		if danger:
			head.add_child(UiStyle.Glyph.new("warn", UiStyle.INK_RED, 28.0, UiStyle.CARDBOARD))
		head.add_child(UiStyle.label(question, UiStyle.SIZE_SECTION + 2, UiStyle.INK))
		for l: String in lines:
			box.add_child(UiStyle.wrapped(l, UiStyle.SIZE_BODY, UiStyle.INK, 520))
		box.add_child(UiStyle.spacer(6))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_END
		box.add_child(row)
		confirm_button = UiStyle.LabelButton.new(confirm_text)
		confirm_button.pressed.connect(_on_confirm)
		row.add_child(confirm_button)
		safe_button = UiStyle.LabelButton.new(safe_text)
		safe_button.pressed.connect(_on_cancel)
		row.add_child(safe_button)

	func _ready() -> void:
		_opened_ms = Time.get_ticks_msec()
		UiStyle.chain_focus([confirm_button, safe_button])
		confirm_button.focus_neighbor_right = confirm_button.get_path_to(safe_button)
		safe_button.focus_neighbor_left = safe_button.get_path_to(confirm_button)
		safe_button.grab_focus()

	func _guarded() -> bool:
		return Time.get_ticks_msec() - _opened_ms < GUARD_MS

	func _on_confirm() -> void:
		if _guarded():
			return
		confirmed.emit()
		queue_free()

	func _on_cancel() -> void:
		if _guarded():
			return
		cancelled.emit()
		queue_free()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			cancelled.emit()
			queue_free()
