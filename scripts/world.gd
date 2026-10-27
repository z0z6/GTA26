extends Node3D
## Swiat gry (3D, widok z gory): siatka kafli z OpenStreetMap, podloze rysowane shaderem,
## budynki jako siatki z wielokatow strumieniowane chunkami.
##
## Jednostka swiata = 1 kafel (ok. 4,3 m). Os X = wschod, Z = poludnie, Y = gora.
## Kanaly obrazu data/makow_grid.png: R = klasa kafla*16 (12 = zabudowa litera), G = klasa podloza*16,
## B = pokrycie budynkiem*16 (0..15).
## Klasy: 1 grunt, 2 osiedle, 3 przemysl, 4 pole, 5 trawa, 6 las, 7 woda, 8 ulica, 9 droga glowna,
## 10 droga zolta, 11 cmentarz, 12 budynek, 13 poza mapa.

const MeshBuilder := preload("res://scripts/mesh_builder.gd")
const BuildingBuilder := preload("res://scripts/building_builder.gd")
const GRID_TEX: Texture2D = preload("res://data/makow_grid.png")
const Models := preload("res://scripts/models.gd")
const GROUND_SHADER: Shader = preload("res://shaders/ground.gdshader")
const OBJECT_SHADER: Shader = preload("res://shaders/object.gdshader")
const BUILDING_SHADER: Shader = preload("res://shaders/building.gdshader")

const CK := 24                 # kafli w chunku
const LOAD_R := 2              # promien (w chunkach) wczytywanych budynkow
const SPEED_BY_CLASS := [100, 100, 100, 100, 88, 94, 72, 100, 100, 100, 100, 90, 100, 100]
# strefy gagow: [x, y, szerokosc, wysokosc, etykieta, rodzaj]
const ZONES := [
	[530, 438, 9, 3, "Konferencja ze wstęgą", "konf"],
	[508, 446, 10, 3, "Remont od 2019", "remont"],
]

var w := 0
var h := 0
var cls := PackedByteArray()      # klasa kafla (12 = zabudowa)
var under := PackedByteArray()    # klasa podloza
var solid := PackedByteArray()
var spd := PackedByteArray()

var ground: MeshInstance3D
var ground_mat: ShaderMaterial
var building_mat: ShaderMaterial
var obj_mat: ShaderMaterial        # wspolny material obiektow statycznych (auta, przedmioty, lampy)
var tree_mat: ShaderMaterial       # korony drzew znikaja przy graczu
var lamp_pos := {}                 # Vector2i -> PackedVector2Array
var _tree_meshes: Array = []
var _lamp_mesh: ArrayMesh
var night := 0.0

var _bld_index := {}              # Vector2i -> Array[Dictionary]
var _chunks := {}                 # Vector2i -> MeshInstance3D
var _pending: Array[Vector2i] = []
var build_ms_total := 0.0
var build_count := 0


func setup() -> void:
	var img: Image = GRID_TEX.get_image()
	img.convert(Image.FORMAT_RGBA8)
	w = img.get_width()
	h = img.get_height()
	var data: PackedByteArray = img.get_data()
	var n := w * h
	cls.resize(n)
	under.resize(n)
	solid.resize(n)
	spd.resize(n)
	var cov := PackedByteArray()
	cov.resize(n)
	for i in n:
		var o := i * 4
		var c: int = (data[o] + 8) >> 4
		var u: int = (data[o + 1] + 8) >> 4
		cls[i] = c
		under[i] = u
		cov[i] = ((data[o + 2] + 8) >> 4) * 17
		solid[i] = 1 if (c == 12 or c == 7 or c == 13) else 0
		spd[i] = SPEED_BY_CLASS[mini(u, 13)]
	for z in ZONES:
		for j in range(z[1], z[1] + z[3]):
			for i in range(z[0], z[0] + z[2]):
				var id: int = j * w + i
				if solid[id] == 0:
					spd[id] = 50
	_load_buildings()

	var tex_under := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_R8, under))
	var tex_cov := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_R8, cov))
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("gridtex", tex_under)
	ground_mat.set_shader_parameter("bmask", tex_cov)
	ground_mat.set_shader_parameter("grid_size", Vector2(w, h))
	building_mat = ShaderMaterial.new()
	building_mat.shader = BUILDING_SHADER
	obj_mat = ShaderMaterial.new()
	obj_mat.shader = OBJECT_SHADER
	tree_mat = ShaderMaterial.new()
	tree_mat.shader = OBJECT_SHADER
	tree_mat.set_shader_parameter("fade_r", 1.7)
	var trng := RandomNumberGenerator.new()
	trng.seed = 99
	_tree_meshes = [Models.tree(0, trng), Models.tree(1, trng)]
	_lamp_mesh = Models.lamp()

	var plane := PlaneMesh.new()
	plane.size = Vector2(96, 64)
	plane.material = ground_mat
	ground = MeshInstance3D.new()
	ground.mesh = plane
	ground.name = "Ground"
	add_child(ground)
	set_lights(PackedVector4Array())


func _load_buildings() -> void:
	var text := FileAccess.get_file_as_string("res://data/buildings.json")
	var arr = JSON.parse_string(text)
	if arr == null:
		push_error("Nie udalo sie wczytac budynkow")
		return
	for b in arr:
		var p: Array = b["p"]
		var cx := 0.0
		var cz := 0.0
		var k := p.size() / 2
		for i in k:
			cx += p[i * 2]
			cz += p[i * 2 + 1]
		cx /= k
		cz /= k
		var key := Vector2i(floori(cx / CK), floori(cz / CK))
		if not _bld_index.has(key):
			_bld_index[key] = []
		_bld_index[key].append(b)


func set_night(v: float) -> void:
	night = v
	RenderingServer.global_shader_parameter_set("g_night", v)


## Do 12 swiatel: Vector4(x, z, promien, jasnosc) w kaflach.
func set_lights(l: PackedVector4Array) -> void:
	for i in 12:
		RenderingServer.global_shader_parameter_set("g_l%d" % i, l[i] if i < l.size() else Vector4(0, 0, 1, 0))


# --- zapytania o kafle ---
func is_solid_tile(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= w or j >= h:
		return true
	return solid[j * w + i] == 1


func is_solid_at(p: Vector2) -> bool:
	return is_solid_tile(floori(p.x), floori(p.y))


## Czy kolo o promieniu r w punkcie p zahacza o lite kafle.
func blocked(p: Vector2, r: float) -> bool:
	return (is_solid_at(p + Vector2(-r, -r)) or is_solid_at(p + Vector2(r, -r))
		or is_solid_at(p + Vector2(-r, r)) or is_solid_at(p + Vector2(r, r)))


func speed_at(p: Vector2) -> float:
	var i := floori(p.x)
	var j := floori(p.y)
	if i < 0 or j < 0 or i >= w or j >= h:
		return 1.0
	return spd[j * w + i] / 100.0


func class_at(p: Vector2) -> int:
	var i := floori(p.x)
	var j := floori(p.y)
	if i < 0 or j < 0 or i >= w or j >= h:
		return 13
	return cls[j * w + i]


func under_at(p: Vector2) -> int:
	var i := floori(p.x)
	var j := floori(p.y)
	if i < 0 or j < 0 or i >= w or j >= h:
		return 13
	return under[j * w + i]


func is_road_tile(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= w or j >= h:
		return false
	var c: int = cls[j * w + i]
	return c >= 8 and c <= 10


func is_road_at(p: Vector2) -> bool:
	return is_road_tile(floori(p.x), floori(p.y))


func los(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var n := int(ceil(d / 0.33))
	for k in range(1, n):
		var t := float(k) / float(n)
		if is_solid_at(a.lerp(b, t)):
			return false
	return true


func find_start(tile: Vector2i) -> Vector2:
	for r in 30:
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var i := tile.x + di
				var j := tile.y + dj
				if not (is_solid_tile(i, j) or is_solid_tile(i + 1, j) or is_solid_tile(i, j + 1)
						or is_solid_tile(i - 1, j) or is_solid_tile(i, j - 1)):
					return Vector2(i + 0.5, j + 0.5)
	return Vector2(tile.x + 0.5, tile.y + 0.5)


# --- strumieniowanie chunkow budynkow ---
func update_chunks(center: Vector2, budget_ms := 6.0) -> void:
	var cc := Vector2i(floori(center.x / CK), floori(center.y / CK))
	ground.position = Vector3(center.x, 0.0, center.y)
	for dj in range(-LOAD_R, LOAD_R + 1):
		for di in range(-LOAD_R, LOAD_R + 1):
			var key := Vector2i(cc.x + di, cc.y + dj)
			if not _chunks.has(key) and not _pending.has(key) and key.x >= 0 and key.y >= 0 and key.x * CK < w and key.y * CK < h:
				_pending.append(key)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - cc).length_squared() < (b - cc).length_squared())
	var t0 := Time.get_ticks_usec()
	while _pending.size() > 0 and (Time.get_ticks_usec() - t0) / 1000.0 < budget_ms:
		var key: Vector2i = _pending.pop_front()
		if absi(key.x - cc.x) > LOAD_R or absi(key.y - cc.y) > LOAD_R:
			continue
		_build_chunk(key)
	for key in _chunks.keys():
		if absi(key.x - cc.x) > LOAD_R + 1 or absi(key.y - cc.y) > LOAD_R + 1:
			_chunks[key].queue_free()
			_chunks.erase(key)
			lamp_pos.erase(key)


func build_all_near(center: Vector2) -> void:
	update_chunks(center, 100000.0)


func _hash(i: int, j: int) -> int:
	var x: int = (i * 73856093) ^ (j * 19349663)
	x = (x ^ (x >> 13)) & 0x7fffffff
	return x


func _build_chunk(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var ox := float(key.x * CK)
	var oz := float(key.y * CK)
	var root := Node3D.new()
	root.position = Vector3(ox, 0.0, oz)
	add_child(root)
	if _bld_index.has(key):
		var mesh := BuildingBuilder.build_chunk(_bld_index[key], ox, oz)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = building_mat
		mi.custom_aabb = AABB(Vector3(-4, 0, -4), Vector3(CK + 8, 12, CK + 8))
		root.add_child(mi)
	_build_props(key, root)
	_chunks[key] = root
	build_ms_total += (Time.get_ticks_usec() - t0) / 1000.0
	build_count += 1


func _build_props(key: Vector2i, root: Node3D) -> void:
	var ox := key.x * CK
	var oz := key.y * CK
	var trees := [[], []]
	var lamps := PackedVector2Array()
	for j in CK:
		var gj := oz + j
		if gj >= h:
			break
		for i in CK:
			var gi := ox + i
			if gi >= w:
				break
			var id := gj * w + gi
			if solid[id] == 1:
				continue
			var c: int = cls[id]
			var hv := _hash(gi, gj)
			var dens := 0.0
			if c == 6:
				dens = 0.32
			elif c == 5:
				dens = 0.06
			elif c == 11:
				dens = 0.10
			if dens > 0.0 and float(hv & 1023) / 1023.0 < dens:
				var fx := float((hv >> 10) & 255) / 255.0
				var fz := float((hv >> 18) & 255) / 255.0
				var kind := 1 if (c == 6 and (hv >> 5) % 5 < 2) else 0
				trees[kind].append([Vector2(gi + fx - ox, gj + fz - oz), 0.8 + float((hv >> 3) & 15) / 40.0, float(hv & 255) / 255.0 * TAU, float((hv >> 7) & 31) / 31.0])
			elif (c == 1 or c == 2 or c == 3) and hv % 19 == 0:
				for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if is_road_tile(gi + n.x, gj + n.y):
						lamps.append(Vector2(gi + 0.5 + n.x * 0.38, gj + 0.5 + n.y * 0.38))
						break
	for kind in 2:
		var arr: Array = trees[kind]
		if arr.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _tree_meshes[kind]
		mm.instance_count = arr.size()
		for k in arr.size():
			var t: Array = arr[k]
			var p: Vector2 = t[0]
			var bs := Basis(Vector3.UP, t[2]).scaled(Vector3.ONE * t[1])
			mm.set_instance_transform(k, Transform3D(bs, Vector3(p.x, 0.0, p.y)))
			var v: float = 0.86 + 0.26 * t[3]
			mm.set_instance_color(k, Color(v, v * 1.02, v * 0.96, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = tree_mat
		mmi.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(CK + 4, 3, CK + 4))
		root.add_child(mmi)
	if lamps.size() > 0:
		var lm := MultiMesh.new()
		lm.transform_format = MultiMesh.TRANSFORM_3D
		lm.mesh = _lamp_mesh
		lm.instance_count = lamps.size()
		for k in lamps.size():
			var lp: Vector2 = lamps[k]
			var cx := floori(lp.x)
			var cy := floori(lp.y)
			var towards := Vector2.ZERO
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if is_road_tile(cx + n.x, cy + n.y):
					towards = Vector2(n.x, n.y)
			lm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, atan2(-towards.x, -towards.y)), Vector3(lp.x - ox, 0.0, lp.y - oz)))
			lamps[k] = lp
		var lmi := MultiMeshInstance3D.new()
		lmi.multimesh = lm
		lmi.material_override = obj_mat
		lmi.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(CK + 4, 3, CK + 4))
		root.add_child(lmi)
	lamp_pos[key] = lamps


## Najblizsze latarnie wokol punktu (do oswietlenia nocnego).
func nearest_lamps(p: Vector2, n: int) -> Array:
	var all := []
	for key in lamp_pos:
		for lp in lamp_pos[key]:
			all.append([lp.distance_squared_to(p), lp])
	all.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(n, all.size()):
		out.append(all[i][1])
	return out


func chunk_count() -> int:
	return _chunks.size()
