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

## Explosión: escombros, humo y un destello de luz.
static func explosion(parent: Node, pos: Vector3, charge: int) -> void:
	var r := Config.blast_radius(charge)
	var debris := _burst(parent, pos, 30 + charge * 12, 1.6, Mats.box_mesh(Vector3(0.18, 0.18, 0.18)),
			[Color(0.35, 0.3, 0.26), Color(0.55, 0.48, 0.4)])
	debris.direction = Vector3.UP
	debris.spread = 180.0
	debris.initial_velocity_min = 4.0
	debris.initial_velocity_max = 6.0 + r * 1.5
	debris.gravity = Vector3(0, -14, 0)
	debris.scale_amount_min = 0.6
	debris.scale_amount_max = 1.8
	debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	debris.emission_sphere_radius = 0.5

	var smoke := _burst(parent, pos, 22 + charge * 8, 3.5, Mats.sphere_mesh(0.55, 6),
			[Color(0.5, 0.46, 0.42, 0.6), Color(0.32, 0.3, 0.28, 0.45)])
	smoke.material_override = Mats.particle(true)
	smoke.direction = Vector3.UP
	smoke.spread = 180.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.5 + r * 0.4
	smoke.gravity = Vector3(0, 0.6, 0)
	smoke.damping_min = 1.5
	smoke.damping_max = 3.0
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.0 + charge * 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	smoke.scale_amount_curve = curve

	var fire := _burst(parent, pos, 16 + charge * 4, 0.55, Mats.sphere_mesh(0.45, 6),
			[Color(1.0, 0.9, 0.45), Color(1.0, 0.45, 0.1)])
	fire.material_override = Mats.unshaded_vertex()
	fire.spread = 180.0
	fire.initial_velocity_min = 2.0
	fire.initial_velocity_max = 4.0 + charge
	fire.damping_min = 4.0
	fire.damping_max = 6.0
	fire.gravity = Vector3(0, 1.0, 0)
	fire.scale_amount_min = 1.2
	fire.scale_amount_max = 2.2 + charge * 0.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1.0))
	shrink.add_point(Vector2(1, 0.1))
	fire.scale_amount_curve = shrink

	flash(parent, pos, Color(1.0, 0.7, 0.35), 14.0 + charge * 4.0, r * 3.5, 0.8)

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

## Polvo que cae del techo (aviso de que la zona está inestable).
static func dust(parent: Node, pos: Vector3, amount := 16) -> void:
	var p := _burst(parent, pos, amount, 2.2, Mats.box_mesh(Vector3(0.05, 0.05, 0.05)),
			[Color(0.6, 0.53, 0.42), Color(0.45, 0.4, 0.33)])
	p.explosiveness = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.2, 0.05, 1.2)
	p.direction = Vector3.DOWN
	p.spread = 15.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6

## Astillas de roca al picar.
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

## Piedras que caen del techo en un derrumbe (decorativas, cada PC las simula por su cuenta).
static func falling_rocks(parent: Node, center: Vector3, radius: float, count: int) -> void:
	for i in count:
		var rock := RigidBody3D.new()
		rock.collision_layer = 0
		rock.collision_mask = Config.L_WORLD
		var s := randf_range(0.25, 0.6)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(s, s, s)
		shape.shape = box
		rock.add_child(shape)
		Mats.add_box(rock, Vector3(s, s, s), Vector3.ZERO, Color(0.42, 0.36, 0.3).darkened(randf() * 0.3))
		parent.add_child(rock)
		var off := Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
		rock.global_position = Vector3(center.x, Config.MINE_Y + Config.CELL_HEIGHT - 0.4, center.z) + off
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		rock.linear_velocity = Vector3(0, -randf_range(0.0, 3.0), 0)
		parent.get_tree().create_timer(randf_range(4.0, 6.0)).timeout.connect(rock.queue_free)
