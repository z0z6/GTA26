extends RefCounted
## Prosty konstruktor siatek: pozycje, normalne, kolory wierzcholkow, UV i UV2.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var uvs2 := PackedVector2Array()
var idx := PackedInt32Array()
var planar_uv := false   # UV = (x, z) pozycji (dla dachow i dodatkow na dachach)


func vertex_count() -> int:
	return verts.size()


func add_vertex(p: Vector3, n: Vector3, c: Color, uv: Vector2 = Vector2.ZERO, uv2: Vector2 = Vector2.ZERO) -> int:
	verts.append(p)
	norms.append(n)
	cols.append(c)
	uvs.append(uv)
	uvs2.append(uv2)
	return verts.size() - 1


## Czworokat z plaska normalna. Gdy normal == ZERO liczona z wierzcholkow.
func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, c: Color, n: Vector3 = Vector3.ZERO,
		uv0: Vector2 = Vector2.ZERO, uv1: Vector2 = Vector2.ZERO, uv2_: Vector2 = Vector2.ZERO,
		uv3: Vector2 = Vector2.ZERO, extra: Vector2 = Vector2.ZERO) -> void:
	if n == Vector3.ZERO:
		n = (p1 - p0).cross(p3 - p0).normalized()
	var a := add_vertex(p0, n, c, uv0, extra)
	var b := add_vertex(p1, n, c, uv1, extra)
	var d := add_vertex(p2, n, c, uv2_, extra)
	var e := add_vertex(p3, n, c, uv3, extra)
	idx.append_array([a, b, d, a, d, e])


func tri(p0: Vector3, p1: Vector3, p2: Vector3, c: Color, n: Vector3 = Vector3.ZERO,
		uv0: Vector2 = Vector2.ZERO, uv1: Vector2 = Vector2.ZERO, uv2_: Vector2 = Vector2.ZERO,
		extra: Vector2 = Vector2.ZERO) -> void:
	if n == Vector3.ZERO:
		n = (p1 - p0).cross(p2 - p0).normalized()
	var a := add_vertex(p0, n, c, uv0, extra)
	var b := add_vertex(p1, n, c, uv1, extra)
	var d := add_vertex(p2, n, c, uv2_, extra)
	idx.append_array([a, b, d])


func _puv(p: Vector3, limb: float) -> Vector2:
	return Vector2(p.x, p.z) if planar_uv else Vector2(limb, 0.0)


## Prostopadloscian o srodku `center` i wymiarach `size`.
func box(center: Vector3, size: Vector3, c: Color, limb: float = 0.0, top_c: Color = Color(0, 0, 0, -1)) -> void:
	var h := size * 0.5
	var tc := c if top_c.a < 0.0 else top_c
	var x0 := center.x - h.x
	var x1 := center.x + h.x
	var y0 := center.y - h.y
	var y1 := center.y + h.y
	var z0 := center.z - h.z
	var z1 := center.z + h.z
	_q(Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), tc, Vector3.UP, limb)
	_q(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0), c, Vector3.DOWN, limb)
	_q(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), c, Vector3(0, 0, -1), limb)
	_q(Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), c, Vector3(0, 0, 1), limb)
	_q(Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), c, Vector3(1, 0, 0), limb)
	_q(Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), c, Vector3(-1, 0, 0), limb)


func _q(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, c: Color, n: Vector3, limb: float) -> void:
	quad(p0, p1, p2, p3, c, n, _puv(p0, limb), _puv(p1, limb), _puv(p2, limb), _puv(p3, limb))


## Bryla o prostokatnej podstawie i mniejszym (lub przesunietym) wierzchu: boki w kolorze c, gora w top_c.
## b = [x0, x1, z0, z1] na wysokosci y0; t = [x0, x1, z0, z1] na wysokosci y1.
func frustum(y0: float, y1: float, b: Array, t: Array, c: Color, top_c: Color, limb: float = 0.0) -> void:
	var b00 := Vector3(b[0], y0, b[2])
	var b10 := Vector3(b[1], y0, b[2])
	var b11 := Vector3(b[1], y0, b[3])
	var b01 := Vector3(b[0], y0, b[3])
	var t00 := Vector3(t[0], y1, t[2])
	var t10 := Vector3(t[1], y1, t[2])
	var t11 := Vector3(t[1], y1, t[3])
	var t01 := Vector3(t[0], y1, t[3])
	var ctr := (b00 + b11 + t00 + t11) * 0.25
	_fq(b00, b10, t10, t00, c, limb, ctr)
	_fq(b11, b01, t01, t11, c, limb, ctr)
	_fq(b10, b11, t11, t10, c, limb, ctr)
	_fq(b01, b00, t00, t01, c, limb, ctr)
	_fq(t00, t10, t11, t01, top_c, limb, ctr)


func _fq(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, c: Color, limb: float, ctr: Vector3) -> void:
	var n := (p1 - p0).cross(p3 - p0).normalized()
	var m := (p0 + p1 + p2 + p3) * 0.25
	if n.dot(m - ctr) < 0.0:
		n = -n
	_q(p0, p1, p2, p3, c, n, limb)


## Kula/elipsoida o gladkich normalnych.
func sphere(center: Vector3, radius: Vector3, c: Color, limb: float = 0.0, seg: int = 8, rings: int = 5) -> void:
	var start := verts.size()
	for r in range(rings + 1):
		var ph := PI * float(r) / float(rings)
		for s in range(seg + 1):
			var th := TAU * float(s) / float(seg)
			var d := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var p := center + Vector3(d.x * radius.x, d.y * radius.y, d.z * radius.z)
			add_vertex(p, d, c, _puv(p, limb))
	for r in range(rings):
		for s in range(seg):
			var a := start + r * (seg + 1) + s
			var b := a + seg + 1
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])


## Walec pionowy.
func cylinder_y(center: Vector3, radius: float, height: float, c: Color, limb: float = 0.0, seg: int = 8, top_c: Color = Color(0, 0, 0, -1)) -> void:
	var tc := c if top_c.a < 0.0 else top_c
	var y0 := center.y - height * 0.5
	var y1 := center.y + height * 0.5
	var start := verts.size()
	for s in range(seg + 1):
		var th := TAU * float(s) / float(seg)
		var d := Vector3(cos(th), 0.0, sin(th))
		var p0 := Vector3(center.x + d.x * radius, y0, center.z + d.z * radius)
		var p1 := Vector3(center.x + d.x * radius, y1, center.z + d.z * radius)
		add_vertex(p0, d, c, _puv(p0, limb))
		add_vertex(p1, d, c, _puv(p1, limb))
	for s in range(seg):
		var a := start + s * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var ctr := add_vertex(Vector3(center.x, y1, center.z), Vector3.UP, tc, _puv(Vector3(center.x, y1, center.z), limb))
	var ring_start := verts.size()
	for s in range(seg):
		var th := TAU * float(s) / float(seg)
		var p := Vector3(center.x + cos(th) * radius, y1, center.z + sin(th) * radius)
		add_vertex(p, Vector3.UP, tc, _puv(p, limb))
	for s in range(seg):
		idx.append_array([ctr, ring_start + s, ring_start + (s + 1) % seg])


func to_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
