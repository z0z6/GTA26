extends Node2D
## Swiat gry: siatka kafli zbudowana z mapy OpenStreetMap (Makow Mazowiecki)
## oraz strumieniowanie chunkow podloza wokol kamery.
##
## Klasy kafli (kanal R obrazu data/makow_grid.png, wartosc / 16):
## 1 grunt, 2 osiedle, 3 przemysl, 4 pole, 5 trawa, 6 las, 7 woda,
## 8 ulica, 9 droga glowna, 10 droga zolta, 11 cmentarz, 12 budynek, 13 poza mapa.
## Kanal G = liczba kondygnacji budynku, kanal B = indeks koloru dachu.

const T := 24                 # rozmiar kafla w pikselach
const CK := 24                # kafli w chunku (w jednej osi)
const CKP := CK * T           # rozmiar chunku w pikselach
const GRID_TEX: Texture2D = preload("res://data/makow_grid.png")

const GROUND_HEX := {
	0: "#cdc8b4", 1: "#cdc8b4", 2: "#c3c0b3", 3: "#bab4bc", 4: "#b8bf86",
	5: "#80a85b", 6: "#5a8447", 7: "#5f98b1", 8: "#4a4d52", 9: "#54565c",
	10: "#5b5d60", 11: "#6f9560", 13: "#0f1013",
}
const ROOF_HEX := ["#c0623f", "#d9a07f", "#9aa0a6", "#b8a98a", "#a8604a",
	"#8f9aa6", "#c9b27a", "#7f8f7a", "#b9755a"]
# mnoznik predkosci (procent) wg klasy kafla
const SPEED_BY_CLASS := [100, 100, 100, 100, 88, 94, 72, 100, 100, 100, 100, 90, 100, 100]
# strefy gagow: [x, y, szerokosc, wysokosc, etykieta, rodzaj]
const ZONES := [
	[530, 438, 9, 3, "Konferencja ze wstęgą", "konf"],
	[508, 446, 10, 3, "Remont od 2019", "remont"],
]

var w := 0
var h := 0
var cls := PackedByteArray()
var lvl := PackedByteArray()
var cix := PackedByteArray()
var solid := PackedByteArray()
var spd := PackedByteArray()

var _variants := {}
var _roofs: Array[Color] = []
var _chunks := {}


func setup() -> void:
	var img: Image = GRID_TEX.get_image()
	img.convert(Image.FORMAT_RGBA8)
	w = img.get_width()
	h = img.get_height()
	var data: PackedByteArray = img.get_data()
	var n := w * h
	cls.resize(n)
	lvl.resize(n)
	cix.resize(n)
	solid.resize(n)
	spd.resize(n)
	for i in n:
		var o := i * 4
		var c: int = (data[o] + 8) >> 4
		cls[i] = c
		lvl[i] = (data[o + 1] + 8) >> 4
		cix[i] = (data[o + 2] + 8) >> 4
		solid[i] = 1 if (c == 12 or c == 7 or c == 13) else 0
		spd[i] = SPEED_BY_CLASS[mini(c, 13)]
	for z in ZONES:
		for j in range(z[1], z[1] + z[3]):
			for i in range(z[0], z[0] + z[2]):
				var id: int = j * w + i
				if solid[id] == 0:
					spd[id] = 50
	for k in GROUND_HEX:
		var base := Color.html(GROUND_HEX[k])
		var vs: Array[Color] = []
		for f in [0.95, 1.0, 1.04, 0.98]:
			vs.append(Color(base.r * f, base.g * f, base.b * f, 1.0))
		_variants[k] = vs
	_variants[12] = _variants[2]
	for hx in ROOF_HEX:
		_roofs.append(Color.html(hx))


func is_solid_tile(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= w or j >= h:
		return true
	return solid[j * w + i] == 1


func is_solid_px(p: Vector2) -> bool:
	return is_solid_tile(floori(p.x / T), floori(p.y / T))


func speed_at(p: Vector2) -> float:
	var i := floori(p.x / T)
	var j := floori(p.y / T)
	if i < 0 or j < 0 or i >= w or j >= h:
		return 1.0
	return spd[j * w + i] / 100.0


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
					return Vector2((i + 0.5) * T, (j + 0.5) * T)
	return Vector2((tile.x + 0.5) * T, (tile.y + 0.5) * T)


func update_chunks(center: Vector2) -> void:
	var cc := Vector2i(floori(center.x / CKP), floori(center.y / CKP))
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var key := Vector2i(cc.x + di, cc.y + dj)
			if key.x < 0 or key.y < 0 or key.x * CK >= w or key.y * CK >= h:
				continue
			if not _chunks.has(key):
				_chunks[key] = _build_chunk(key.x, key.y)
	for key in _chunks.keys():
		if absi(key.x - cc.x) > 2 or absi(key.y - cc.y) > 2:
			_chunks[key].queue_free()
			_chunks.erase(key)


func chunk_count() -> int:
	return _chunks.size()


func _hash(i: int, j: int) -> int:
	var x: int = (i * 73856093) ^ (j * 19349663)
	x = (x ^ (x >> 13)) & 0x7fffffff
	return x


func _non_road(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= w or j >= h:
		return true
	var c: int = cls[j * w + i]
	return c < 8 or c > 10


func _build_chunk(ci: int, cj: int) -> Sprite2D:
	var img := Image.create(CKP, CKP, false, Image.FORMAT_RGBA8)
	img.fill(Color.html("#0f1013"))
	var curb := Color(0.93, 0.9, 0.82, 1.0)
	var forest_dot := Color.html("#456b35")
	for j in CK:
		var gj := cj * CK + j
		if gj >= h:
			break
		for i in CK:
			var gi := ci * CK + i
			if gi >= w:
				break
			var id := gj * w + gi
			var c: int = cls[id]
			var hv := _hash(gi, gj)
			var col: Color
			if c == 12:
				col = _roofs[cix[id] % 9]
			else:
				col = _variants[c][hv & 3]
			var x := i * T
			var y := j * T
			img.fill_rect(Rect2i(x, y, T, T), col)
			if c == 8 or c == 9 or c == 10:
				if _non_road(gi, gj - 1):
					img.fill_rect(Rect2i(x, y, T, 2), curb)
				if _non_road(gi, gj + 1):
					img.fill_rect(Rect2i(x, y + T - 2, T, 2), curb)
				if _non_road(gi - 1, gj):
					img.fill_rect(Rect2i(x, y, 2, T), curb)
				if _non_road(gi + 1, gj):
					img.fill_rect(Rect2i(x + T - 2, y, 2, T), curb)
			elif c == 6:
				img.fill_rect(Rect2i(x + 4 + (hv & 7), y + 4 + ((hv >> 3) & 7), 9, 9), forest_dot)
			elif c == 12:
				var edge := Color(col.r * 0.75, col.g * 0.75, col.b * 0.75, 1.0)
				img.fill_rect(Rect2i(x, y, T, 1), edge)
				img.fill_rect(Rect2i(x, y, 1, T), edge)
	for z in ZONES:
		_tint_zone(img, ci, cj, z)
	var spr := Sprite2D.new()
	spr.centered = false
	spr.position = Vector2(ci * CKP, cj * CKP)
	spr.texture = ImageTexture.create_from_image(img)
	add_child(spr)
	return spr


func _tint_zone(img: Image, ci: int, cj: int, z: Array) -> void:
	var col := Color(0.75, 0.24, 0.22, 0.55) if z[5] == "konf" else Color(0.47, 0.35, 0.23, 0.85)
	for j in range(z[1], z[1] + z[3]):
		for i in range(z[0], z[0] + z[2]):
			if i / CK != ci or j / CK != cj:
				continue
			var ox: int = (i - ci * CK) * T
			var oy: int = (j - cj * CK) * T
			for yy in range(oy, oy + T):
				for xx in range(ox, ox + T):
					img.set_pixel(xx, yy, img.get_pixel(xx, yy).blend(col))
