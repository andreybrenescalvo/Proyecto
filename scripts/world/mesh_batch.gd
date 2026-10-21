class_name MeshBatch
extends RefCounted
## Junta muchas piezas fijas (cajas, cilindros, techos) en pocas mallas: una por pedazo del mapa,
## con una superficie por material. Cada MeshInstance3D es un dibujo aparte para la placa de video
## y la ciudad tiene miles de cajas: sueltas, la versión web no andaría.
## Los pedazos miden CHUNK metros, así lo que queda fuera de la cámara o muy lejos no se dibuja.
## Las colisiones también se juntan: un solo cuerpo estático por pedazo, con muchas formas.
##
## Uso: b.box(tamaño, transformación, material), b.solid(...) (con colisión), y al final b.commit().

const CHUNK := 64.0
const FAR := 170.0          # hasta dónde se dibuja un pedazo de ciudad (más allá, la niebla lo tapa)
const FAR_DETAIL := 70.0    # los detalles chicos (rejas, macetas, rayas) se dejan de dibujar antes
## Capas: lo normal, los detalles chicos (se dejan de ver antes y no hacen sombra) y los brillos
## (tampoco hacen sombra).
const NORMAL := 0
const DETAIL := 1
const GLOW := 2

var _root: Node3D
var _parts := {}            # "x|z|capa" -> {material: [vértices, normales, índices]}
var _bodies := {}           # "x|z" -> StaticBody3D
static var _arrays := {}    # mallas base (de tamaño 1), para no pedirlas cada vez

func _init(root: Node3D) -> void:
	_root = root

static func _unit(kind: String) -> Array:
	if _arrays.has(kind):
		return _arrays[kind]
	var mesh: PrimitiveMesh
	match kind:
		"box":
			mesh = BoxMesh.new()
		"prism":
			mesh = PrismMesh.new()
		"plane":
			mesh = PlaneMesh.new()
			(mesh as PlaneMesh).size = Vector2.ONE
		"cone8":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 8
			c.rings = 1
			mesh = c
		"pyramid":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 4
			c.rings = 1
			mesh = c
		_:
			# "cylN": cilindro de N lados
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = int(kind.substr(3))
			c.rings = 1
			mesh = c
	var a := mesh.get_mesh_arrays()
	_arrays[kind] = a
	return a

## Plano horizontal (mirando para arriba) de `w` por `d`: para manchas de luz en el piso.
func plane(w: float, d: float, xform: Transform3D, mat: Material, layer := GLOW) -> void:
	add("plane", xform * Transform3D(Basis.from_scale(Vector3(w, 1.0, d)), Vector3.ZERO), mat, layer)

## Caja de `size` con su centro en `xform`.
func box(size: Vector3, xform: Transform3D, mat: Material, layer := NORMAL) -> void:
	add("box", xform * Transform3D(Basis.from_scale(size), Vector3.ZERO), mat, layer)

## Caja con colisión.
func solid(size: Vector3, xform: Transform3D, mat: Material, layer := Config.L_WORLD) -> void:
	box(size, xform, mat)
	collider(size, xform, layer)

## Cilindro (de pie) de radio `r` y alto `h`, con el centro en `xform`.
func cylinder(r: float, h: float, xform: Transform3D, mat: Material, sides := 10, layer := NORMAL) -> void:
	add("cyl%d" % sides, xform * Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), Vector3.ZERO), mat, layer)

## Prisma triangular (techo a dos aguas) apoyado en `xform`: `size` x = largo de la cumbrera, y = alto, z = ancho.
func roof(size: Vector3, xform: Transform3D, mat: Material) -> void:
	# El PrismMesh tiene el triángulo en X/Y: se gira para que la cumbrera quede a lo largo de X.
	# `xform` es la base del techo (no el centro).
	add("prism", xform * Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_scale(Vector3(size.z, size.y, size.x)), Vector3(0, size.y * 0.5, 0)), mat)

## Malla base (de tamaño 1) transformada.
func add(kind: String, xform: Transform3D, mat: Material, layer := NORMAL) -> void:
	var a := _unit(kind)
	var src_v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var src_i: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var key := "%d|%d|%d" % [floori(xform.origin.x / CHUNK), floori(xform.origin.z / CHUNK), layer]
	var part: Dictionary = _parts.get(key, {})
	if part.is_empty():
		_parts[key] = part
	var buf: Array = part.get(mat, [])
	if buf.is_empty():
		buf = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array(), PackedVector2Array()]
		part[mat] = buf
	var verts: PackedVector3Array = buf[0]
	var norms: PackedVector3Array = buf[1]
	var idx: PackedInt32Array = buf[2]
	var uvs: PackedVector2Array = buf[3]
	var base := verts.size()
	var nb := xform.basis.inverse().transposed()
	for i in src_v.size():
		verts.append(xform * src_v[i])
		norms.append((nb * src_n[i]).normalized())
		uvs.append(src_uv[i])
	for i in src_i:
		idx.append(base + i)
	buf[0] = verts
	buf[1] = norms
	buf[2] = idx
	buf[3] = uvs

## Forma de colisión (caja) sin nada que se vea.
func collider(size: Vector3, xform: Transform3D, layer := Config.L_WORLD) -> void:
	var key := "%d|%d|%d" % [floori(xform.origin.x / CHUNK), floori(xform.origin.z / CHUNK), layer]
	var body: StaticBody3D = _bodies.get(key)
	if body == null:
		body = StaticBody3D.new()
		body.name = "Colisiones_" + key.replace("|", "_").replace("-", "m")
		body.collision_layer = layer
		body.collision_mask = 0
		_root.add_child(body)
		_bodies[key] = body
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.transform = xform
	body.add_child(shape)

## Arma las mallas. Después de esto no se puede agregar nada más.
func commit() -> void:
	for key: String in _parts:
		var part: Dictionary = _parts[key]
		var mesh := ArrayMesh.new()
		for mat: Material in part:
			var buf: Array = part[mat]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = buf[0]
			arr[Mesh.ARRAY_NORMAL] = buf[1]
			arr[Mesh.ARRAY_INDEX] = buf[2]
			arr[Mesh.ARRAY_TEX_UV] = buf[3]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Ciudad_" + key.replace("|", "_").replace("-", "m")
		mi.mesh = mesh
		mi.visibility_range_end = FAR_DETAIL if key.ends_with("|%d" % DETAIL) else FAR
		if not key.ends_with("|%d" % NORMAL):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end_margin = 8.0
		_root.add_child(mi)
	_parts.clear()
