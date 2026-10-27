extends RefCounted
## Buduje siatke budynkow z wielokatow (JSON z mapy OSM): sciany, dachy plaskie i spadziste, dodatki.

const MeshBuilder := preload("res://scripts/mesh_builder.gd")
const FLOOR_H := 0.55

const WALLS := [
	["#e8dcc0", "#efe6cf", "#d8c9a8", "#e6d3c8", "#c9d3c6", "#dfe0d8"],   # 0 dom
	["#b8a890", "#a7a199", "#c4b59a", "#b09a82", "#a9aaa0", "#bcae9c"],   # 1 szopa
	["#d8d4c8", "#cfcbbd", "#c7ccc9", "#dcd3be", "#c9c2b4", "#d2d8d6"],   # 2 blok
	["#c9c8c2", "#bfc3c4", "#d0cdc2", "#b9bdb8", "#c8c4b6", "#c0c5c8"],   # 3 wielka plyta
	["#a9b0b8", "#9ea6ad", "#b8b4a8", "#8f98a0", "#b0b6b2", "#a4a8a0"],   # 4 hala
	["#e2cfa0", "#d8b88a", "#e8d9b8", "#cdb596", "#dcc3a6", "#e6d2b0"],   # 5 kamienica
]
const ROOF_PITCHED := ["#a8482e", "#8a3d2a", "#5a4a42", "#4a4d52", "#6d7a52"]
const ROOF_FLAT := ["#7a7d80", "#5d6366", "#8e9091", "#a1695a", "#6e7e68", "#8a7f74", "#4f5458"]

const K_WALL := 0.0
const K_FLAT := 0.34
const K_PITCH := 0.67
const K_GABLE := 1.0

static var _wall_cols: Array = []
static var _pitch_cols: Array = []
static var _flat_cols: Array = []


static func _init_palettes() -> void:
	if _wall_cols.size() > 0:
		return
	for g in WALLS:
		var arr := []
		for h in g:
			arr.append(Color.html(h))
		_wall_cols.append(arr)
	for h in ROOF_PITCHED:
		_pitch_cols.append(Color.html(h))
	for h in ROOF_FLAT:
		_flat_cols.append(Color.html(h))


static func build_chunk(buildings: Array, ox: float, oz: float) -> ArrayMesh:
	_init_palettes()
	var mb := MeshBuilder.new()
	for b in buildings:
		_add_building(mb, b, ox, oz)
	return mb.to_mesh()


static func _col(c: Color, kind: float) -> Color:
	return Color(c.r, c.g, c.b, kind)


static func _add_building(mb, b: Dictionary, ox: float, oz: float) -> void:
	var flat: Array = b["p"]
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(Vector2(flat[i] - ox, flat[i + 1] - oz))
	if pts.size() < 3:
		return
	var style: int = int(b["t"])
	var floors: int = int(b["n"])
	var H := float(floors) * FLOOR_H
	var wall_c: Color = _wall_cols[style][int(b["w"]) % 6]
	var area := _signed_area(pts)
	if area < 0.0:
		pts.reverse()
		area = -area
	var extra := Vector2(H, float(style))
	_add_walls(mb, pts, H, wall_c, extra)
	var roof_type: int = int(b["r"])
	var seed_v: int = int(absf(flat[0] * 131.0 + flat[1] * 71.0)) + floors * 7
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	if roof_type != 0 and b.has("q"):
		var q: Array = b["q"]
		_add_pitched_roof(mb, Vector2(q[0] - ox, q[1] - oz), q[2], q[3], q[4], H, wall_c,
			_pitch_cols[int(b["c"]) % _pitch_cols.size()], roof_type == 2, extra, rng, style)
	else:
		var fc: Color = _flat_cols[int(b["c"]) % _flat_cols.size()]
		_add_flat_roof(mb, pts, H, fc, rng, style, area)


static func _signed_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var j := (i + 1) % p.size()
		a += p[i].x * p[j].y - p[j].x * p[i].y
	return a * 0.5


static func _add_walls(mb, pts: PackedVector2Array, H: float, c: Color, extra: Vector2) -> void:
	var cum := 0.0
	var wc := _col(c, K_WALL)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var e := b - a
		var len := e.length()
		if len < 0.01:
			continue
		var n2 := Vector2(e.y, -e.x) / len
		var n := Vector3(n2.x, 0.0, n2.y)
		mb.quad(Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(b.x, H, b.y), Vector3(a.x, H, a.y),
			wc, n, Vector2(cum, 0.0), Vector2(cum + len, 0.0), Vector2(cum + len, H), Vector2(cum, H), extra)
		cum += len


static func _add_flat_roof(mb, pts: PackedVector2Array, H: float, c: Color, rng: RandomNumberGenerator, style: int, area: float) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	var rc := _col(c, K_FLAT)
	var base: int = mb.vertex_count()
	for p in pts:
		mb.add_vertex(Vector3(p.x, H, p.y), Vector3.UP, rc, p, Vector2(0.0, 0.0))
	if tri.size() >= 3:
		for t in tri:
			mb.idx.append(base + t)
	else:
		for i in range(1, pts.size() - 1):
			mb.idx.append_array([base, base + i, base + i + 1])
	# attyka: waski pas wokol dachu (krawedz lekko wyzej)
	_add_parapet(mb, pts, H, rc)
	# dodatki na dachach: klimatyzatory, swietliki, nadbudowki klatek schodowych
	if style >= 2 and area > 2.0:
		var bb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			bb = bb.expand(p)
		var n := clampi(1 + int(area / 5.0), 1, 7)
		mb.planar_uv = true
		for k in n:
			for attempt in 14:
				var cx := rng.randf_range(bb.position.x, bb.end.x)
				var cz := rng.randf_range(bb.position.y, bb.end.y)
				var big := rng.randf() < 0.18
				var sx := rng.randf_range(0.30, 0.6) if big else rng.randf_range(0.16, 0.42)
				var sz := rng.randf_range(0.30, 0.55) if big else rng.randf_range(0.16, 0.34)
				var corners := [Vector2(cx - sx, cz - sz), Vector2(cx + sx, cz - sz), Vector2(cx + sx, cz + sz), Vector2(cx - sx, cz + sz)]
				var ok := true
				for cr in corners:
					if not Geometry2D.is_point_in_polygon(cr, pts):
						ok = false
						break
				if ok:
					var hh := rng.randf_range(0.22, 0.34) if big else rng.randf_range(0.08, 0.2)
					var col := Color(0.58, 0.6, 0.62, K_FLAT)
					var r := rng.randf()
					if r < 0.25:
						col = Color(0.50, 0.66, 0.78, K_FLAT)      # swietlik
						hh = 0.07
					elif r < 0.5:
						col = Color(0.42, 0.44, 0.47, K_FLAT)
					elif r < 0.7:
						col = Color(0.72, 0.68, 0.62, K_FLAT)
					mb.box(Vector3(cx, H + hh * 0.5, cz), Vector3(sx * 2.0, hh, sz * 2.0), col)
					break
		mb.planar_uv = false


static func _add_parapet(mb, pts: PackedVector2Array, H: float, rc: Color) -> void:
	var pc := Color(rc.r * 0.82, rc.g * 0.82, rc.b * 0.82, K_FLAT)
	var ph := 0.07
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var e := b - a
		var len := e.length()
		if len < 0.01:
			continue
		var n2 := Vector2(e.y, -e.x) / len
		var n := Vector3(n2.x, 0.0, n2.y)
		mb.quad(Vector3(a.x, H, a.y), Vector3(b.x, H, b.y), Vector3(b.x, H + ph, b.y), Vector3(a.x, H + ph, a.y),
			pc, n, a, b, b, a, Vector2(0.0, 0.0))


static func _add_pitched_roof(mb, ctr: Vector2, hw: float, hh: float, ang: float, H: float, wall_c: Color,
		roof_c: Color, hipped: bool, extra: Vector2, rng: RandomNumberGenerator, style: int) -> void:
	var ax := Vector2(cos(ang), sin(ang))
	var pz := Vector2(-sin(ang), cos(ang))
	var ov := 0.07
	var g := clampf(hh * 0.8, 0.22, 1.0)
	var Hr := H + g
	var Hs := H - 0.03
	var sl := sqrt(hh * hh + g * g) + ov
	var rcol := _col(roof_c, K_PITCH)
	var gcol := _col(wall_c, K_GABLE)
	var rl := hw + ov if not hipped else maxf(hw - hh * 0.95, 0.04)
	var P := func(along: float, perp: float, y: float) -> Vector3:
		var p: Vector2 = ctr + ax * along + pz * perp
		return Vector3(p.x, y, p.y)
	# dwie dluzsze polacie
	for side in [-1.0, 1.0]:
		var e0: Vector3 = P.call(-(hw + ov), side * (hh + ov), Hs)
		var e1: Vector3 = P.call(hw + ov, side * (hh + ov), Hs)
		var r1: Vector3 = P.call(rl, 0.0, Hr)
		var r0: Vector3 = P.call(-rl, 0.0, Hr)
		var n := (e1 - e0).cross(r0 - e0).normalized()
		if n.y < 0.0:
			n = -n
		var u0 := 0.0
		var u1 := hw * 2.0 + ov * 2.0
		var ur0 := (hw + ov) - rl
		var ur1 := (hw + ov) + rl
		mb.quad(e0, e1, r1, r0, rcol, n, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(ur1, sl), Vector2(ur0, sl), Vector2(0.0, sl))
	# szczyty (trojkaty) albo skosy walmowe
	for end in [-1.0, 1.0]:
		if not hipped:
			var q0: Vector3 = P.call(end * hw, -hh, H)
			var q1: Vector3 = P.call(end * hw, hh, H)
			var q2: Vector3 = P.call(end * hw, 0.0, Hr)
			var n3 := (q1 - q0).cross(q2 - q0).normalized()
			if n3.dot(Vector3(ax.x * end, 0.0, ax.y * end)) < 0.0:
				n3 = -n3
			mb.tri(q0, q1, q2, gcol, n3, Vector2(0, 0), Vector2(hh * 2.0, 0), Vector2(hh, g), extra)
		else:
			var e0: Vector3 = P.call(end * (hw + ov), -(hh + ov), Hs)
			var e1: Vector3 = P.call(end * (hw + ov), hh + ov, Hs)
			var r: Vector3 = P.call(end * rl, 0.0, Hr)
			var n := (e1 - e0).cross(r - e0).normalized()
			if n.y < 0.0:
				n = -n
			mb.tri(e0, e1, r, rcol, n, Vector2(0.0, 0.0), Vector2(hh * 2.0 + ov * 2.0, 0.0), Vector2(hh + ov, sl), Vector2(0.0, sl))
	# komin
	if style <= 1 or style == 5:
		if rng.randf() < 0.6:
			var along := rng.randf_range(-hw * 0.6, hw * 0.6)
			var cp: Vector2 = ctr + ax * along
			mb.planar_uv = true
			mb.box(Vector3(cp.x, Hr - 0.04, cp.y), Vector3(0.14, 0.34, 0.14), Color(0.45, 0.28, 0.22, K_FLAT))
			mb.planar_uv = false
