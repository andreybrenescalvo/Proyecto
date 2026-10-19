class_name Fx
extends RefCounted
## Efectos visuales sueltos (partículas, destellos, textos flotantes).
## Son solo visuales: cada computadora los genera por su cuenta, no se sincronizan.

static func _burst(parent: Node, pos: Vector3, amount: int, lifetime: float, mesh: Mesh, colors: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.mesh = mesh
	p.material_override = Mats.particle()
	var ramp := Gradient.new()
	ramp.set_color(0, colors[0])
	ramp.set_color(1, colors[colors.size() - 1])
	p.color_initial_ramp = ramp
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
	return p

## Algo que se rompe: pedazos que saltan para todos lados.
static func shards(parent: Node, pos: Vector3, c: Color) -> void:
	var p := _burst(parent, pos, 26, 1.2, Mats.box_mesh(Vector3(0.06, 0.02, 0.06)), [c.lightened(0.2), c.darkened(0.2)])
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 2.0

## Luz que aparece y se apaga rápido.
static func flash(parent: Node, pos: Vector3, c: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = energy
	light.omni_range = light_range
	parent.add_child(light)
	light.global_position = pos
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)

## Polvo (al arrastrar muebles, al caer algo pesado).
static func dust(parent: Node, pos: Vector3, amount := 16) -> void:
	var p := _burst(parent, pos, amount, 1.6, Mats.box_mesh(Vector3(0.05, 0.05, 0.05)),
			[Color(0.6, 0.55, 0.48), Color(0.45, 0.42, 0.38)])
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.5, 0.05, 0.5)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, -1.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6

## Astillas chicas (un golpe fuerte contra algo).
static func chips(parent: Node, pos: Vector3, c: Color) -> void:
	var p := _burst(parent, pos, 10, 0.7, Mats.box_mesh(Vector3(0.07, 0.07, 0.07)), [c, c.darkened(0.3)])
	p.spread = 70.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12, 0)

## Texto que sube y se desvanece (por ejemplo "+$12").
static func floating_text(parent: Node, pos: Vector3, text: String, c := Color(1, 0.9, 0.3)) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = c
	label.outline_size = 10
	label.font_size = 64
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = pos
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position", pos + Vector3(0, 1.5, 0), 1.4)
	tw.tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)
