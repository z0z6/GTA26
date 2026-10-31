extends RefCounted
## Proceduralne modele: ludzie (z animowanymi konczynami), samochody, drzewa, latarnie, przedmioty.
## Konwencja: model patrzy w kierunku -Z, poczatek ukladu na ziemi, jednostka = kafel.

const MeshBuilder := preload("res://scripts/mesh_builder.gd")

const SKINS := ["#f0c8a0", "#e6b48c", "#d49a72", "#b87a56", "#8a5a3c", "#f4d6b8"]
const HAIRS := ["#1d1a17", "#3a2a1e", "#5a3a22", "#8a6a3a", "#b8a070", "#8c8c8c", "#c9c2b0"]
const TOPS := ["#c0392b", "#2f6fb5", "#3d8b5a", "#e0b43a", "#7a4aa0", "#d9d4c8", "#4a5560", "#e08a3a", "#2c3e50", "#b05a7a"]
const BOTTOMS := ["#2b3a55", "#3a3a3d", "#5a4a3a", "#6b7078", "#2f4a3a", "#8a8070"]
const CAR_COLORS := ["#c43c3c", "#3c6ec4", "#e0c33a", "#d8d8d0", "#2b2f33", "#7a7d80", "#3caa6a",
	"#8a4a2a", "#e8761f", "#5a3b8a", "#9fb4c4", "#a8a090", "#6b1f2a"]
const BRANDS := ["Kormoran", "Zefir", "Bursztyn", "Mazur", "Orlik", "Żmija", "Bałtyk", "Jantar", "Wiarus", "Kaszub"]
const BODY_NAMES := ["Mikrus", "Hatchback", "Sedan", "Kombi", "Terenówka", "Furgon", "Pickup", "Ciężarówka", "Autobus"]
# dlugosc, szerokosc, dlugosc maski, dlugosc kabiny (w kaflach)
const CAR_DIMS := [
	[1.10, 0.56, 0.26, 0.50], [1.25, 0.62, 0.30, 0.62], [1.55, 0.66, 0.38, 0.62], [1.62, 0.66, 0.36, 0.86],
	[1.50, 0.72, 0.34, 0.80], [1.70, 0.70, 0.28, 1.10], [1.65, 0.70, 0.36, 0.44], [2.30, 0.76, 0.40, 0.34],
	[2.90, 0.80, 0.0, 0.0],
]


static func _c(h: String, a: float = 1.0) -> Color:
	var c := Color.html(h)
	c.a = a
	return c


static func _tone(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


# ---------------------------------------------------------------- ludzie
## kind: player, wind, chw, kon, kom, npc. Zwraca {mesh, scale, name}.
static func person(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var mb := MeshBuilder.new()
	var skin := _c(SKINS[rng.randi() % SKINS.size()])
	var hair := _c(HAIRS[rng.randi() % HAIRS.size()])
	var top := _c(TOPS[rng.randi() % TOPS.size()])
	var bottom := _c(BOTTOMS[rng.randi() % BOTTOMS.size()])
	var shoes := _c("#222222")
	var hair_style := rng.randi() % 4        # 0 krotkie, 1 dlugie, 2 lysy, 3 czapka
	var outfit := 0                          # 0 kurtka, 1 sukienka, 2 garnitur
	var accessory := 0                       # 1 teczka, 2 torba, 3 plecak, 4 laska, 5 kapec, 6 pieczatka, 7 siatka
	var sc := rng.randf_range(0.92, 1.08)
	var width := 1.0
	var cap_col := _c(TOPS[rng.randi() % TOPS.size()])
	var glasses := false
	var tie := Color(0, 0, 0, 0)
	var nm := "Przechodzień"
	match kind:
		"player":
			skin = _c(SKINS[0]); hair = _c("#2a1e16"); top = _c("#2f6fb5"); bottom = _c("#2b3a55")
			hair_style = 3; cap_col = _c("#e8761f"); accessory = 3; sc = 1.0; nm = "Gracz"
		"wind":
			top = _c("#25272b"); bottom = _c("#25272b"); outfit = 2; accessory = 1; hair_style = 0
			hair = _c("#1d1a17"); tie = _c("#b02a2a"); sc = 1.02; nm = "Windykator"
		"chw":
			top = _c("#6b2d8a"); bottom = _c("#3a2a4a"); outfit = 2; hair_style = 0; hair = _c("#14110f")
			glasses = true; tie = _c("#e8d34a"); sc = 1.0; nm = "Pan z chwilówki"
		"kon":
			top = _c("#e8e4da"); bottom = _c("#4a5a78"); shoes = _c("#8a5a3a"); accessory = 5
			hair_style = rng.randi() % 3; width = 1.18; sc = 1.04; nm = "Konkubent"
		"kom":
			top = _c("#2f5a35"); bottom = _c("#27402c"); outfit = 2; accessory = 6; hair_style = 3
			cap_col = _c("#2f5a35"); sc = 1.14; width = 1.12; tie = _c("#b02a2a"); nm = "Komornik"
		_:
			var r := rng.randf()
			if r < 0.12:
				sc = rng.randf_range(0.70, 0.80)         # dziecko
				hair_style = rng.randi() % 3
				nm = "Dziecko"
			elif r < 0.45:
				outfit = 1                               # sukienka / kobieta
				hair_style = 1 if rng.randf() < 0.7 else 0
				nm = "Przechodzień"
			elif r < 0.60:
				hair = _c("#a8a8a8"); accessory = 4; sc *= 0.96; nm = "Senior"
			if kind == "npc" and accessory == 0:
				var a := rng.randf()
				if a < 0.15: accessory = 2
				elif a < 0.27: accessory = 3
				elif a < 0.35: accessory = 7
	var hw := 0.14 * width
	# nogi (limb 1,2)
	for side in [-1.0, 1.0]:
		var limb := 1.0 if side < 0 else 2.0
		mb.box(Vector3(side * 0.07 * width, 0.155, 0.0), Vector3(0.105, 0.31, 0.115), bottom, limb)
		mb.box(Vector3(side * 0.07 * width, 0.03, -0.02), Vector3(0.11, 0.06, 0.17), shoes, limb)
	# korpus
	if outfit == 1:
		mb.frustum(0.20, 0.52, [-0.17 * width, 0.17 * width, -0.11, 0.11], [-0.125 * width, 0.125 * width, -0.075, 0.075], top, top)
	else:
		mb.box(Vector3(0, 0.415, 0), Vector3(0.28 * width, 0.23, 0.165 * width), top, 0.0, _tone(top, 1.08))
		if outfit == 2:
			mb.box(Vector3(0, 0.50, -0.083), Vector3(0.10, 0.07, 0.01), _c("#f2f2ee"))      # kolnierz koszuli
			if tie.a > 0.0:
				mb.box(Vector3(0, 0.43, -0.088), Vector3(0.035, 0.16, 0.012), tie)
	# rece (limb 3,4)
	for side in [-1.0, 1.0]:
		var limb := 3.0 if side < 0 else 4.0
		var sleeve := top if kind != "kon" else skin
		mb.box(Vector3(side * (0.145 * width + 0.045), 0.40, 0.0), Vector3(0.075, 0.25, 0.085), sleeve, limb)
		mb.box(Vector3(side * (0.145 * width + 0.045), 0.265, 0.0), Vector3(0.07, 0.06, 0.075), skin, limb)
	# glowa
	mb.sphere(Vector3(0, 0.60, 0), Vector3(0.088, 0.098, 0.092), skin, 0.0, 9, 6)
	match hair_style:
		0:
			mb.sphere(Vector3(0, 0.625, 0.012), Vector3(0.094, 0.07, 0.097), hair, 0.0, 9, 4)
		1:
			mb.sphere(Vector3(0, 0.625, 0.012), Vector3(0.095, 0.072, 0.098), hair, 0.0, 9, 4)
			mb.box(Vector3(0, 0.55, 0.075), Vector3(0.17, 0.19, 0.045), hair)
		3:
			mb.sphere(Vector3(0, 0.628, 0.005), Vector3(0.096, 0.06, 0.098), cap_col, 0.0, 9, 4)
			mb.box(Vector3(0, 0.615, -0.098), Vector3(0.13, 0.014, 0.075), _tone(cap_col, 0.8))
			if kind == "kom":
				mb.box(Vector3(0, 0.66, -0.07), Vector3(0.035, 0.03, 0.01), _c("#d33a3a"))
	if glasses:
		mb.box(Vector3(0, 0.61, -0.088), Vector3(0.13, 0.03, 0.02), _c("#111111"))
	# akcesoria
	match accessory:
		1:
			mb.box(Vector3(0.20, 0.215, -0.03), Vector3(0.04, 0.12, 0.17), _c("#7a4a24"), 4.0)
		2:
			mb.box(Vector3(-0.185, 0.30, 0.0), Vector3(0.05, 0.13, 0.17), _c(TOPS[rng.randi() % TOPS.size()]), 0.0)
		3:
			var bc := _c("#e8761f") if kind == "player" else _c(TOPS[rng.randi() % TOPS.size()])
			mb.box(Vector3(0, 0.43, 0.125), Vector3(0.21, 0.21, 0.08), bc)
		4:
			mb.box(Vector3(0.20, 0.17, -0.06), Vector3(0.025, 0.34, 0.025), _c("#5a3a22"), 4.0)
		5:
			mb.box(Vector3(0.19, 0.22, -0.07), Vector3(0.07, 0.025, 0.15), _c("#8a5a3a"), 4.0)
		6:
			mb.box(Vector3(0.20, 0.22, -0.05), Vector3(0.09, 0.09, 0.11), _c("#8a8a82"), 4.0)
			mb.box(Vector3(0.20, 0.275, -0.05), Vector3(0.04, 0.03, 0.04), _c("#8a2a2a"), 4.0)
		7:
			mb.box(Vector3(0.19, 0.22, -0.03), Vector3(0.07, 0.14, 0.1), _c("#e8e4da"), 4.0)
	return {"mesh": mb.to_mesh(), "scale": sc, "name": nm}


# ---------------------------------------------------------------- samochody
static func car(body_type: int, rng: RandomNumberGenerator) -> Dictionary:
	var d: Array = CAR_DIMS[body_type]
	var L: float = d[0]
	var W: float = d[1]
	var hood: float = d[2]
	var cabin: float = d[3]
	var col := _c(CAR_COLORS[rng.randi() % CAR_COLORS.size()])
	if body_type == 8:
		col = _c(["#e8e4da", "#d9d4c8", "#c43c3c", "#3c6ec4"][rng.randi() % 4])
	var glass := _c("#26333f")
	var dark := _c("#17181a")
	var roofc := col if rng.randf() > 0.2 else _tone(col, 0.82)
	var mb := MeshBuilder.new()
	var zf := -L * 0.5
	var zb := L * 0.5
	var hw := W * 0.5
	# kola
	for sx in [-1.0, 1.0]:
		for zz in [zf + L * 0.20, zb - L * 0.20]:
			mb.box(Vector3(sx * (hw - 0.02), 0.085, zz), Vector3(0.10, 0.17, 0.21), dark)
	if body_type == 8:
		# autobus: dlugie, wysokie nadwozie z pasem okien
		mb.box(Vector3(0, 0.40, 0), Vector3(W, 0.52, L), col, 0.0, roofc)
		for sx in [-1.0, 1.0]:
			mb.box(Vector3(sx * (hw + 0.002), 0.50, 0.05), Vector3(0.012, 0.18, L * 0.86), glass)
		mb.box(Vector3(0, 0.50, zf - 0.002), Vector3(W * 0.88, 0.2, 0.012), glass)
		mb.box(Vector3(0, 0.67, 0.2), Vector3(0.32, 0.06, 0.5), _tone(roofc, 0.85))
	elif body_type == 7:
		# ciezarowka: kabina + skrzynia
		mb.box(Vector3(0, 0.25, zf + 0.32), Vector3(W, 0.30, 0.62), col)
		mb.frustum(0.38, 0.68, [-hw + 0.02, hw - 0.02, zf + 0.04, zf + 0.60], [-hw + 0.07, hw - 0.07, zf + 0.12, zf + 0.54], glass, roofc)
		var cargo := _c(["#d9d4c8", "#e8e4da", "#8a9aa8", "#c9b27a"][rng.randi() % 4])
		mb.box(Vector3(0, 0.46, zb - 0.78), Vector3(W + 0.02, 0.62, 1.52), cargo, 0.0, _tone(cargo, 1.05))
		mb.box(Vector3(0, 0.12, 0.2), Vector3(W * 0.7, 0.08, L * 0.9), dark)
	elif body_type == 6:
		# pickup: kabina z przodu, skrzynia otwarta
		mb.box(Vector3(0, 0.22, zf + 0.5), Vector3(W, 0.22, 1.0), col)
		mb.frustum(0.33, 0.58, [-hw + 0.03, hw - 0.03, zf + hood, zf + hood + cabin + 0.1], [-hw + 0.08, hw - 0.08, zf + hood + 0.1, zf + hood + cabin - 0.04], glass, roofc)
		mb.box(Vector3(0, 0.30, zb - 0.38), Vector3(W, 0.16, 0.76), _tone(col, 0.9))
		mb.box(Vector3(0, 0.385, zb - 0.38), Vector3(W - 0.14, 0.02, 0.62), _c("#3a3631"))
	elif body_type == 5:
		# furgon: wysoki, jednobryłowy
		mb.box(Vector3(0, 0.40, 0), Vector3(W, 0.46, L), col, 0.0, roofc)
		mb.frustum(0.52, 0.64, [-hw + 0.01, hw - 0.01, zf, zf + 0.34], [-hw + 0.03, hw - 0.03, zf + 0.1, zf + 0.32], glass, glass)
		for sx in [-1.0, 1.0]:
			mb.box(Vector3(sx * (hw + 0.002), 0.50, zf + 0.22), Vector3(0.012, 0.14, 0.3), glass)
	else:
		# osobowe: korpus + kabina
		var bh := 0.26 if body_type != 4 else 0.32
		mb.box(Vector3(0, 0.13 + bh * 0.5, 0), Vector3(W, bh, L), col)
		var cz0 := zf + hood
		var cz1 := cz0 + cabin
		if body_type == 4:
			mb.frustum(0.34, 0.62, [-hw + 0.02, hw - 0.02, cz0 - 0.05, cz1], [-hw + 0.08, hw - 0.08, cz0 + 0.1, cz1 - 0.04], glass, roofc)
		elif body_type == 3 or body_type == 1 or body_type == 0:
			mb.frustum(0.36, 0.58, [-hw + 0.03, hw - 0.03, cz0, cz1], [-hw + 0.08, hw - 0.08, cz0 + 0.12, cz1 - 0.03], glass, roofc)
		else:
			mb.frustum(0.36, 0.57, [-hw + 0.03, hw - 0.03, cz0, cz1], [-hw + 0.08, hw - 0.08, cz0 + 0.14, cz1 - 0.16], glass, roofc)
		# pasek / dodatki
		var r := rng.randf()
		if r < 0.15:
			var sc := _tone(col, 0.55) if col.get_luminance() > 0.4 else _c("#e8e4da")
			mb.box(Vector3(0, 0.395, 0), Vector3(0.09, 0.006, L * 0.98), sc)
		elif r < 0.30 and (body_type == 3 or body_type == 4):
			mb.box(Vector3(0, 0.595, (cz0 + cz1) * 0.5), Vector3(W * 0.66, 0.025, cabin * 0.8), dark)
		elif r < 0.36 and body_type == 2:
			mb.box(Vector3(0, 0.60, (cz0 + cz1) * 0.5), Vector3(0.18, 0.05, 0.10), _c("#f2c200", 0.5))
	# swiatla i zderzaki
	for sx in [-1.0, 1.0]:
		mb.box(Vector3(sx * (hw - 0.11), 0.26, zf - 0.004), Vector3(0.10, 0.05, 0.02), _c("#fff2b0", 0.5))
		mb.box(Vector3(sx * (hw - 0.10), 0.27, zb + 0.004), Vector3(0.10, 0.05, 0.02), _c("#d02020", 0.5))
	mb.box(Vector3(0, 0.15, zf - 0.01), Vector3(W + 0.01, 0.07, 0.04), dark)
	mb.box(Vector3(0, 0.15, zb + 0.01), Vector3(W + 0.01, 0.07, 0.04), dark)
	return {"mesh": mb.to_mesh(), "length": L, "width": W,
		"name": "%s %s" % [BRANDS[rng.randi() % BRANDS.size()], BODY_NAMES[body_type]]}


# ---------------------------------------------------------------- otoczenie
static func tree(kind: int, rng: RandomNumberGenerator) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.box(Vector3(0, 0.30, 0), Vector3(0.12, 0.60, 0.12), _c("#5a4128"))
	if kind == 0:
		mb.sphere(Vector3(0, 0.95, 0), Vector3(0.50, 0.46, 0.50), _c("#4f8a3a"), 0.0, 8, 5)
		mb.sphere(Vector3(0.18, 1.10, -0.08), Vector3(0.32, 0.30, 0.32), _c("#5f9a46"), 0.0, 7, 4)
		mb.sphere(Vector3(-0.16, 0.85, 0.14), Vector3(0.30, 0.28, 0.30), _c("#448030"), 0.0, 7, 4)
	else:
		mb.frustum(0.30, 0.75, [-0.34, 0.34, -0.34, 0.34], [-0.20, 0.20, -0.20, 0.20], _c("#2f5f35"), _c("#2f5f35"))
		mb.frustum(0.70, 1.15, [-0.26, 0.26, -0.26, 0.26], [-0.12, 0.12, -0.12, 0.12], _c("#376b3c"), _c("#376b3c"))
		mb.frustum(1.10, 1.50, [-0.18, 0.18, -0.18, 0.18], [-0.03, 0.03, -0.03, 0.03], _c("#3f7a44"), _c("#3f7a44"))
	return mb.to_mesh()


static func lamp() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cylinder_y(Vector3(0, 0.55, 0), 0.025, 1.1, _c("#4a4d52"), 0.0, 6)
	mb.box(Vector3(0, 1.1, -0.08), Vector3(0.1, 0.035, 0.22), _c("#3c3f44"))
	mb.box(Vector3(0, 1.075, -0.15), Vector3(0.09, 0.02, 0.09), _c("#fff2b0", 0.5))
	return mb.to_mesh()


## Przedmioty do rzucania: {name, mesh, stun, text}
static func items() -> Array:
	var list := []
	var specs := [
		["Kamień", 0.9, "Au!"],
		["Puszka", 0.7, "Puszką?!"],
		["Butelka", 1.3, "Moja głowa!"],
		["Bułka", 0.5, "Bułka?!"],
		["Kapeć", 0.8, "Kapeć!?"],
		["Pilot", 1.0, "Pilot od telewizora!"],
		["Petarda", 2.4, "Moje uszy!"],
	]
	for i in specs.size():
		var mb := MeshBuilder.new()
		match i:
			0: mb.sphere(Vector3(0, 0, 0), Vector3(0.07, 0.06, 0.07), _c("#7d7f82"), 0.0, 6, 4)
			1: mb.cylinder_y(Vector3(0, 0, 0), 0.05, 0.11, _c("#c9ccd0"), 0.0, 7)
			2:
				mb.cylinder_y(Vector3(0, 0, 0), 0.04, 0.14, _c("#4aa05a"), 0.0, 7)
				mb.cylinder_y(Vector3(0, 0.1, 0), 0.02, 0.07, _c("#4aa05a"), 0.0, 6)
			3: mb.sphere(Vector3(0, 0, 0), Vector3(0.09, 0.06, 0.07), _c("#c99a5a"), 0.0, 7, 4)
			4: mb.box(Vector3(0, 0, 0), Vector3(0.07, 0.025, 0.16), _c("#9a6a4a"))
			5: mb.box(Vector3(0, 0, 0), Vector3(0.05, 0.025, 0.14), _c("#222426"))
			6:
				mb.cylinder_y(Vector3(0, 0, 0), 0.035, 0.13, _c("#d23a2e"), 0.0, 7)
				mb.cylinder_y(Vector3(0, 0.09, 0), 0.008, 0.05, _c("#e8d9a8"), 0.0, 5)
				mb.sphere(Vector3(0, 0.13, 0), Vector3(0.022, 0.022, 0.022), _c("#ffb040", 0.5), 0.0, 5, 4)   # zarzacy sie loncik (swieci w nocy)
		list.append({"name": specs[i][0], "mesh": mb.to_mesh(), "stun": specs[i][1], "text": specs[i][2], "boom": specs[i][0] == "Petarda"})
	return list


static func coin() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cylinder_y(Vector3(0, 0, 0), 0.13, 0.035, _c("#f2c200"), 0.0, 10, _c("#ffe066"))
	return mb.to_mesh()


static func pickup_bag() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.box(Vector3(0, 0.07, 0), Vector3(0.22, 0.14, 0.16), _c("#8a6a3a"))
	mb.box(Vector3(0, 0.15, 0), Vector3(0.16, 0.03, 0.05), _c("#5a4128"))
	return mb.to_mesh()
