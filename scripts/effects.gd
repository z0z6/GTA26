extends Node3D
## Efekty: wybuchy (ogien, iskry, zar, dym, fala uderzeniowa, przypalenie), dym spod opon,
## slady opon na jezdni. Wszystko rysowane przez trzy MultiMeshe (jedna warstwa = jedno wywolanie rysowania):
##   - cząsteczki świecące (addytywne)  -> shaders/fx_glow.gdshader
##   - dym                              -> shaders/fx_smoke.gdshader
##   - decale na ziemi (slady, przypalenia) -> shaders/fx_decal.gdshader
## Cząsteczki symulowane w GDScript, bufor MultiMesha zapisywany raz na klatke.
## Efekty uzywaja wlasnego generatora losowego, wiec nie zaburzaja losowosci rozgrywki (seed testow).

const GLOW_SHADER: Shader = preload("res://shaders/fx_glow.gdshader")
const SMOKE_SHADER: Shader = preload("res://shaders/fx_smoke.gdshader")
const DECAL_SHADER: Shader = preload("res://shaders/fx_decal.gdshader")

const MAX_GLOW := 220
const MAX_SMOKE := 140
const MAX_DECALS := 640
const STRIDE := 20            # transformacja 12 + kolor 4 + dane wlasne 4 (floaty na instancje)
const SKID_FADE := 32.0       # po ilu sekundach slad opony znika
const SCORCH_FADE := 50.0

const SHAPE_BLOB := 0.0
const SHAPE_RING := 1.0
const SHAPE_SPARK := 2.0


class Particle extends RefCounted:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var age := 0.0
	var life := 1.0
	var s0 := 1.0
	var s1 := 1.0
	var c0 := Color.WHITE
	var c1 := Color(1, 1, 1, 0)
	var drag := 0.0
	var grav := 0.0
	var spin := 0.0
	var rot := 0.0
	var seed := 0.0
	var shape := 0.0
	var stretch := 0.0


var game
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _purge_t := 0.0
var _glow: Array[Particle] = []
var _smoke: Array[Particle] = []
var _glow_mm: MultiMesh
var _smoke_mm: MultiMesh
var _decal_mm: MultiMesh
var _glow_buf := PackedFloat32Array()
var _smoke_buf := PackedFloat32Array()
var _decal_i := 0
var boom_count := 0           # liczniki do testow
var skid_count := 0
var _skid := {}               # auto -> {l, r, t, puff}: ostatnie polozenie kol podczas hamowania


func setup(g) -> void:
	game = g
	_rng.seed = 424242
	_glow_buf.resize(MAX_GLOW * STRIDE)
	_smoke_buf.resize(MAX_SMOKE * STRIDE)
	_glow_mm = _make_layer(GLOW_SHADER, MAX_GLOW, 2)
	_smoke_mm = _make_layer(SMOKE_SHADER, MAX_SMOKE, 1)
	_decal_mm = _make_layer(DECAL_SHADER, MAX_DECALS, 0)
	_decal_mm.visible_instance_count = MAX_DECALS
	var zeros := PackedFloat32Array()
	zeros.resize(MAX_DECALS * STRIDE)
	_decal_mm.buffer = zeros                      # zerowe transformacje = niewidoczne


func _make_layer(shader: Shader, cap: int, priority := 0) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	mm.mesh = pm
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-100, -5, -100), Vector3(1400, 30, 1400))   # cala mapa, bez kulingu
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


# ------------------------------------------------------------------ petla
func tick(dt: float) -> void:
	_t += dt
	RenderingServer.global_shader_parameter_set("g_fxtime", _t)
	_step(_glow, dt)
	_step(_smoke, dt)
	_write(_glow, _glow_buf, _glow_mm)
	_write(_smoke, _smoke_buf, _smoke_mm)
	# zapomnij auta, ktore przestaly hamowac lub zniknely
	_purge_t -= dt
	if _purge_t <= 0.0:
		_purge_t = 0.25
		for c in _skid.keys():
			if not is_instance_valid(c) or _t - float(_skid[c]["t"]) > 0.15:
				_skid.erase(c)


func _step(list: Array, dt: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var p: Particle = list[i]
		p.age += dt
		if p.age < 0.0:                       # jeszcze czeka na start (opoznienie)
			i -= 1
			continue
		if p.age >= p.life:
			list[i] = list.back()
			list.pop_back()
		else:
			p.vel.y -= p.grav * dt
			p.vel *= maxf(0.0, 1.0 - p.drag * dt)
			p.pos += p.vel * dt
			if p.pos.y < 0.05:
				p.pos.y = 0.05
				p.vel.y = absf(p.vel.y) * 0.25
				p.vel.x *= 0.7
				p.vel.z *= 0.7
			p.rot += p.spin * dt
		i -= 1


func _write(list: Array, buf: PackedFloat32Array, mm: MultiMesh) -> void:
	var n := 0
	var o := 0
	for k in list.size():
		var p: Particle = list[k]
		if p.age < 0.0 or n >= mm.instance_count:
			continue
		n += 1
		var t := p.age / p.life
		var s := lerpf(p.s0, p.s1, t)
		var c := p.c0.lerp(p.c1, t)
		var bx := Vector3.ZERO
		var bz := Vector3.ZERO
		if p.stretch > 0.0:
			var sp := Vector2(p.vel.x, p.vel.z)
			var l := sp.length()
			var d := sp / l if l > 0.01 else Vector2.RIGHT
			bx = Vector3(d.x, 0.0, d.y) * s * (1.0 + p.stretch * l)
			bz = Vector3(-d.y, 0.0, d.x) * s * 0.6
		else:
			var cr := cos(p.rot)
			var sr := sin(p.rot)
			bx = Vector3(cr, 0.0, sr) * s
			bz = Vector3(-sr, 0.0, cr) * s
		buf[o] = bx.x
		buf[o + 1] = 0.0
		buf[o + 2] = bz.x
		buf[o + 3] = p.pos.x
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = p.pos.y
		buf[o + 8] = bx.z
		buf[o + 9] = 0.0
		buf[o + 10] = bz.z
		buf[o + 11] = p.pos.z
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
		buf[o + 16] = p.seed
		buf[o + 17] = t
		buf[o + 18] = p.shape
		buf[o + 19] = 0.0
		o += STRIDE
	mm.visible_instance_count = n
	mm.buffer = buf


# ------------------------------------------------------------------ tworzenie cząsteczek
func _add(list: Array, cap: int, p: Particle) -> void:
	p.seed = _rng.randf()
	p.rot = _rng.randf() * TAU
	if list.size() >= cap:
		list[_rng.randi() % list.size()] = p      # pelna pula: nadpisz losowa
	else:
		list.append(p)


func _glow_p(pos: Vector3, vel: Vector3, life: float, s0: float, s1: float, c0: Color, c1: Color,
		drag := 0.0, grav := 0.0, shape := SHAPE_BLOB, stretch := 0.0, spin := 0.0) -> void:
	var p := Particle.new()
	p.pos = pos
	p.vel = vel
	p.life = life
	p.s0 = s0
	p.s1 = s1
	p.c0 = c0
	p.c1 = c1
	p.drag = drag
	p.grav = grav
	p.shape = shape
	p.stretch = stretch
	p.spin = spin
	_add(_glow, MAX_GLOW, p)


func _smoke_p(pos: Vector3, vel: Vector3, life: float, s0: float, s1: float, c0: Color, c1: Color,
		drag := 0.8, grav := 0.0, spin := 0.0, delay := 0.0) -> void:
	var p := Particle.new()
	p.age = -delay
	p.pos = pos
	p.vel = vel
	p.life = life
	p.s0 = s0
	p.s1 = s1
	p.c0 = c0
	p.c1 = c1
	p.drag = drag
	p.grav = grav
	p.spin = spin
	_add(_smoke, MAX_SMOKE, p)


func _rdir() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU)


# ------------------------------------------------------------------ efekty
## Wybuch: blysk, fala uderzeniowa, kula ognia, iskry, zar, dym i przypalenie. radius w kaflach.
func explosion(p: Vector2, radius := 2.6) -> void:
	boom_count += 1
	var R := radius
	var c := Vector3(p.x, 0.45, p.y)
	_glow_p(c + Vector3(0, 0.3, 0), Vector3.ZERO, 0.2, R * 1.5, R * 2.5, Color(1.0, 0.96, 0.75, 1.0), Color(1.0, 0.7, 0.3, 0.0))
	_glow_p(c, Vector3.ZERO, 0.5, R * 0.6, R * 4.4, Color(1.0, 0.85, 0.6, 0.75), Color(1.0, 0.5, 0.2, 0.0), 0.0, 0.0, SHAPE_RING)
	for i in 11:                                   # kula ognia
		var d := _rdir()
		var pos := c + Vector3(d.x, 0.0, d.y) * _rng.randf() * R * 0.45 + Vector3(0, _rng.randf() * 0.4, 0)
		var v := Vector3(d.x, 0.0, d.y) * _rng.randf_range(1.5, 4.5) + Vector3(0, _rng.randf_range(0.8, 2.4), 0)
		_glow_p(pos, v, _rng.randf_range(0.45, 0.9), R * _rng.randf_range(0.5, 0.8), R * _rng.randf_range(1.2, 1.8),
			Color(1.0, 0.85, 0.4, 0.95), Color(0.85, 0.2, 0.04, 0.0), 2.0)
	for i in 30:                                   # iskry
		var d := _rdir()
		var sp := _rng.randf_range(5.0, 13.0)
		_glow_p(c, Vector3(d.x * sp, _rng.randf_range(2.0, 7.0), d.y * sp), _rng.randf_range(0.5, 1.0),
			0.16, 0.05, Color(1.0, 0.92, 0.55, 1.0), Color(1.0, 0.3, 0.05, 0.0), 0.4, 14.0, SHAPE_SPARK, 0.09)
	for i in 12:                                   # zar
		var d := _rdir()
		var sp := _rng.randf_range(1.0, 3.0)
		_glow_p(c, Vector3(d.x * sp, _rng.randf_range(2.0, 5.0), d.y * sp), _rng.randf_range(1.2, 2.3),
			0.16, 0.03, Color(1.0, 0.6, 0.2, 1.0), Color(0.8, 0.2, 0.05, 0.0), 0.5, 7.0)
	for i in 14:                                   # dym
		var d := _rdir()
		var sp := _rng.randf_range(0.4, 1.6)
		_smoke_p(c + Vector3(d.x, 0, d.y) * _rng.randf() * R * 0.4, Vector3(d.x * sp, _rng.randf_range(0.9, 2.3), d.y * sp),
			_rng.randf_range(2.2, 3.6), R * 0.35, R * _rng.randf_range(0.9, 1.3),
			Color(0.14, 0.12, 0.11, 0.85), Color(0.32, 0.31, 0.30, 0.0), 0.7, -0.15, _rng.randf_range(-0.6, 0.6), _rng.randf_range(0.15, 0.4))
	_decal(p, Vector2(R * 1.9, R * 1.9), _rng.randf() * TAU, SCORCH_FADE, 1.0)
	if game != null:
		game.shake = maxf(game.shake, 0.55)
		if game.lights != null:
			game.lights.flash(p, Color(1.0, 0.78, 0.4), R * 3.6, 0.5)      # glowny blysk
			game.lights.flash(p, Color(1.0, 0.45, 0.12), R * 1.8, 1.6)     # tlacy sie zar


## Iskry z lecacej petardy (loncik).
func fuse_spark(p: Vector2, h: float) -> void:
	var d := _rdir()
	_glow_p(Vector3(p.x, h + 0.05, p.y), Vector3(d.x * 1.4, _rng.randf_range(0.2, 1.4), d.y * 1.4), _rng.randf_range(0.25, 0.45),
		0.12, 0.03, Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.3, 0.05, 0.0), 1.0, 6.0, SHAPE_SPARK, 0.12)
	_glow_p(Vector3(p.x, h + 0.05, p.y), Vector3.ZERO, 0.08, 0.28, 0.1, Color(1.0, 0.8, 0.4, 0.8), Color(1.0, 0.5, 0.1, 0.0))


## Garsc iskier (uderzenie, zgrzyt).
func spark_burst(p: Vector2, count := 8, speed := 4.0, h := 0.2) -> void:
	for i in count:
		var d := _rdir()
		var sp := _rng.randf_range(speed * 0.4, speed)
		_glow_p(Vector3(p.x, h, p.y), Vector3(d.x * sp, _rng.randf_range(0.8, 3.0), d.y * sp), _rng.randf_range(0.25, 0.55),
			0.13, 0.04, Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.35, 0.08, 0.0), 0.5, 12.0, SHAPE_SPARK, 0.08)


## Pojedyncza chmurka dymu (np. spod kol).
func smoke_puff(p: Vector2, size := 0.5, size_end := 1.4, life := 1.0, col := Color(0.82, 0.82, 0.8, 0.35), h := 0.12) -> void:
	var d := _rdir()
	_smoke_p(Vector3(p.x, h, p.y), Vector3(d.x * 0.25, _rng.randf_range(0.2, 0.6), d.y * 0.25), life, size, size_end,
		col, Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, 0.0), 1.2, 0.0, _rng.randf_range(-0.5, 0.5))


# ------------------------------------------------------------------ decale (slady)
func _decal(p: Vector2, size: Vector2, yaw: float, fade: float, kind: float, dir := Vector2.ZERO) -> void:
	var bx: Vector3
	var bz: Vector3
	if kind < 0.5:
		bx = Vector3(-dir.y, 0.0, dir.x) * size.x       # w poprzek sladu
		bz = Vector3(dir.x, 0.0, dir.y) * size.y        # wzdluz sladu
	else:
		bx = Vector3(cos(yaw), 0.0, sin(yaw)) * size.x
		bz = Vector3(-sin(yaw), 0.0, cos(yaw)) * size.y
	var y := 0.02 if kind < 0.5 else 0.018
	_decal_mm.set_instance_transform(_decal_i, Transform3D(Basis(bx, Vector3.UP, bz), Vector3(p.x, y, p.y)))
	_decal_mm.set_instance_color(_decal_i, Color(1, 1, 1, _rng.randf_range(0.85, 1.0)))
	_decal_mm.set_instance_custom_data(_decal_i, Color(_t, fade, kind, 0.0))
	_decal_i = (_decal_i + 1) % MAX_DECALS


## Odcinek sladu opony od a do b.
func skid_segment(a: Vector2, b: Vector2, width := 0.12) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.02:
		return
	skid_count += 1
	_decal((a + b) * 0.5, Vector2(width, l), 0.0, SKID_FADE, 0.0, d / l)


## Wywolywane przez auto co klatke, gdy hamuje awaryjnie: rysuje slady tylnych kol i dymi.
func skid_car(c) -> void:
	var perp: Vector2 = c.perp()
	var base: Vector2 = c.pos - c.dir * c.length * 0.28
	var off: float = c.width * 0.36
	var wl: Vector2 = base + perp * off
	var wr: Vector2 = base - perp * off
	var st: Dictionary = _skid.get(c, {})
	if st.is_empty():
		_skid[c] = {"l": wl, "r": wr, "t": _t, "puff": 0.0}
		return
	if wl.distance_to(st["l"]) > 0.22:
		skid_segment(st["l"], wl)
		skid_segment(st["r"], wr)
		st["l"] = wl
		st["r"] = wr
	st["t"] = _t
	if _t >= float(st["puff"]):
		st["puff"] = _t + 0.07
		smoke_puff(wl, 0.35, 1.0, 0.9)
		smoke_puff(wr, 0.35, 1.0, 0.9)
	_skid[c] = st


## Auto zatrzymane nagle przez uderzenie (v = predkosc przed): dluzszy slad hamowania, iskry i dym.
func car_impact(c, v: float) -> void:
	if v < 0.8:
		return
	var perp: Vector2 = c.perp()
	var base: Vector2 = c.pos - c.dir * c.length * 0.28
	var L := clampf(v * 0.5, 0.7, 2.4)
	for s in [-1.0, 1.0]:
		var w: Vector2 = base + perp * s * c.width * 0.36
		skid_segment(w - c.dir * L, w, 0.1)
	var front: Vector2 = c.pos + c.dir * c.length * 0.5
	spark_burst(front, 8, 4.0)
	for i in 3:
		smoke_puff(c.pos - c.dir * c.length * 0.28 + perp * _rng.randf_range(-0.3, 0.3), 0.5, 1.5, 1.1)
	_skid.erase(c)
