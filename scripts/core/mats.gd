class_name Mats
extends RefCounted
## Materiales y mallas compartidas. Estilo low-poly: colores planos, sin texturas.

static var _materials := {}
static var _meshes := {}

## Material de color plano. Se cachea por parámetros para no crear miles de materiales iguales.
static func color(c: Color, roughness := 0.9, emission := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), roughness, emission, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m

## Material con textura (generadas por tools/generate_textures.py, en assets/textures/).
## Usa proyección triplanar: la textura se pega sola sobre cualquier caja, sin coordenadas UV.
##   meters: cuántos metros mide la textura (un ladrillo siempre mide lo mismo).
##   world:  true para lo fijo (paredes, pisos); false para lo que se mueve (si no, la textura
##           "resbala" sobre el objeto cuando se mueve).
## `tint` multiplica el color: las texturas claras (pintura, revestimiento, baldosas) se tiñen.
static func tex(name: String, tint := Color.WHITE, meters := 1.0, world := true, roughness := 0.85) -> StandardMaterial3D:
	var key := "tex|%s|%s|%.2f|%s|%.2f" % [name, tint.to_html(), meters, world, roughness]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = roughness
	var albedo := _texture(name)
	if albedo:
		m.albedo_texture = albedo
		var normal := _texture(name + "_n")
		if normal:
			m.normal_enabled = true
			m.normal_texture = normal
			m.normal_scale = 1.0
		m.uv1_triplanar = true
		m.uv1_world_triplanar = world
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / meters
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = m
	return m

static var _textures := {}

static func _texture(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var path := "res://assets/textures/%s.jpg" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[name] = t
	return t

## Material que ignora la luz (para carteles, chispas, etc.).
static func unshaded(c: Color) -> StandardMaterial3D:
	var key := "unshaded|%s" % c.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = m
	return m

## Material para partículas: toma el color de cada partícula.
static func particle(transparent := false) -> StandardMaterial3D:
	var key := "particle|%s" % transparent
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = m
	return m

## Material para partículas que brillan (fuego, chispas): sin luz, toma el color de cada partícula.
static func unshaded_vertex() -> StandardMaterial3D:
	if _materials.has("unshaded_vertex"):
		return _materials["unshaded_vertex"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials["unshaded_vertex"] = m
	return m

static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box|%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m

static func cylinder_mesh(radius: float, height: float, sides := 8) -> CylinderMesh:
	var key := "cyl|%.3f|%.3f|%d" % [radius, height, sides]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	_meshes[key] = m
	return m

static func sphere_mesh(radius: float, segments := 8) -> SphereMesh:
	var key := "sph|%.3f|%d" % [radius, segments]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(int(segments * 0.5), 3)
	_meshes[key] = m
	return m

## Agrega una caja visual (sin colisión) como hija de `parent`.
static func add_box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = color(c)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## Agrega un cilindro visual como hijo de `parent`.
static func add_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, c: Color, rot_deg := Vector3.ZERO, sides := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = cylinder_mesh(radius, height, sides)
	mi.material_override = color(c)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## Agrega una caja sólida (StaticBody3D con colisión) como hija de `parent`.
static func add_solid_box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, layer := Config.L_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_box(body, size, Vector3.ZERO, c)
	parent.add_child(body)
	return body
