extends Node3D
## Glowny kontroler gry: tworzy swiat, kamere, interfejs, wierzycieli, przechodniow i ruch uliczny.
## Argumenty testowe (po "--"): --shot=plik.png --at=x,z --night --autoplay=sekundy --seed=n

const WorldScript := preload("res://scripts/world.gd")
const FlowScript := preload("res://scripts/flow.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const NpcScript := preload("res://scripts/npc.gd")
const CarScript := preload("res://scripts/car.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const HudScript := preload("res://scripts/hud.gd")
const Models := preload("res://scripts/models.gd")
const MeshBuilder := preload("res://scripts/mesh_builder.gd")
const CharacterScript := preload("res://scripts/character.gd")
const LightMapScript := preload("res://scripts/lightmap.gd")
const PostFxScript := preload("res://scripts/postfx.gd")
const EffectsScript := preload("res://scripts/effects.gd")
const SHADOW_SHADER: Shader = preload("res://shaders/shadow.gdshader")

const NIGHT_DUSK := 0.5     # etapy doby: 0 dzien, 0.5 zmierzch, 1 noc
const START_TILE := Vector2i(533, 441)
const CAM_HEIGHT := 40.0
const FOV_MIN := 15.0
const FOV_MAX := 36.0
const FOV_DEFAULT := 24.0
const WAVES := [[0.0, "wind"], [18.0, "chw"], [40.0, "kon"], [65.0, "kom"], [95.0, "wind"], [125.0, "chw"], [155.0, "kon"], [190.0, "kom"]]
const LABELS := [
	["Rynek", 534, 442], ["Zalew", 608, 352], ["Park Sapera", 577, 505], ["Szpital miejski", 296, 544],
	["Cmentarz miejski", 353, 732], ["Jarmark", 367, 294], ["Mleczarnia", 352, 192], ["Stadion", 645, 561],
	["Liceum", 471, 411], ["Stacja wąskotorowa", 358, 419], ["Osiedle Ciechanowska", 440, 353],
]
const CAR_WEIGHTS := [10, 20, 20, 15, 12, 8, 6, 5, 4]

var rng := RandomNumberGenerator.new()
var world
var lights            # mapa swiatel (scripts/lightmap.gd)
var postfx            # bloom (scripts/postfx.gd)
var fx                # efekty: wybuchy, dym, slady opon (scripts/effects.gd)
var flow
var player
var cam: Camera3D
var hud
var state := "menu"
var time := 0.0
var debt := 12480.0
var spent := 0.0
var end_msg := ""
var banner := ""
var banner_t := 0.0
var shake := 0.0
var enemies: Array = []
var npcs: Array = []
var cars: Array = []
var projectiles: Array = []
var coins: Array = []
var bags: Array = []
var floats: Array = []
var zones: Array = []
var items: Array = []
var wave_idx := 0
var night_target := 0.0
var night_cur := 0.0
var joy_active := false
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var _next_item := 0
var _fov_target := FOV_DEFAULT
var _lamp_t := 0.0
var _lamp_cache: Array = []
var _cam_pos := Vector2.ZERO
var _shadow_mm: MultiMesh
var _coin_mesh: ArrayMesh
var _bag_mesh: ArrayMesh
var _labels: Array = []
var _frames := 0
var _shot := ""
var _autoplay := 0.0
var _fxdemo := Vector2.ZERO
var _auto_dir := Vector2.ZERO
var _auto_t := 0.0
var time_scale_test := 1.0
var _steps := 1
var stats := {"thrown": 0, "hits": 0, "car_fines": 0, "touches": 0}


func _ready() -> void:
	rng.seed = 20261027
	var at_override := Vector2.ZERO
	var has_at := false
	var test_night := false
	var test_dusk := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--at="):
			var parts := a.substr(5).split(",")
			at_override = Vector2(float(parts[0]), float(parts[1]))
			has_at = true
		elif a == "--night":
			test_night = true
		elif a == "--dusk":
			test_dusk = true
		elif a.begins_with("--autoplay="):
			_autoplay = float(a.substr(11))
		elif a.begins_with("--fxdemo="):
			var q := a.substr(9).split(",")
			_fxdemo = Vector2(float(q[0]), float(q[1]))
		elif a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
		elif a.begins_with("--steps="):
			_steps = int(a.substr(8))
	lights = LightMapScript.new()
	add_child(lights)
	postfx = PostFxScript.new()
	add_child(postfx)
	fx = EffectsScript.new()
	add_child(fx)
	fx.setup(self)
	world = WorldScript.new()
	add_child(world)
	world.setup()
	flow = FlowScript.new(world)
	items = Models.items()
	_coin_mesh = Models.coin()
	_bag_mesh = Models.pickup_bag()

	var start: Vector2 = world.find_start(START_TILE)
	if has_at:
		start = at_override
	player = PlayerScript.new()
	add_child(player)
	player.setup(world, start)

	cam = Camera3D.new()
	cam.fov = FOV_DEFAULT
	cam.near = 1.0
	cam.far = 160.0
	cam.rotation_degrees = Vector3(-90, 0, 0)
	_cam_pos = start
	cam.position = Vector3(start.x, CAM_HEIGHT, start.y)
	add_child(cam)
	cam.current = true

	_build_shadow_layer()
	_build_zones()
	_build_labels()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)

	night_target = 1.0 if test_night else (NIGHT_DUSK if test_dusk else 0.0)
	world.set_night(night_target)
	night_cur = night_target
	world.build_all_near(start)
	flow.start(start)
	flow.step(100000, start)
	_populate_initial()
	if _autoplay > 0.0:
		start_game()


func _build_shadow_layer() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_shadow_mm = MultiMesh.new()
	_shadow_mm.transform_format = MultiMesh.TRANSFORM_3D
	_shadow_mm.mesh = pm
	_shadow_mm.instance_count = 120
	for i in 120:
		_shadow_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -50, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _shadow_mm
	var mat := ShaderMaterial.new()
	mat.shader = SHADOW_SHADER
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-5000, -1, -5000), Vector3(10000, 2, 10000))
	add_child(mmi)


func _build_zones() -> void:
	var mb := MeshBuilder.new()
	for z in world.ZONES:
		var r := Rect2(z[0], z[1], z[2], z[3])
		var d := {"rect": r, "kind": z[5], "label": z[4]}
		zones.append(d)
		var c := r.get_center()
		if z[5] == "konf":
			mb.box(Vector3(c.x, 0.015, c.y), Vector3(r.size.x, 0.03, r.size.y), Color("#b53a36"))
			for sx in [-1.0, 1.0]:
				mb.cylinder_y(Vector3(c.x + sx * (r.size.x * 0.5 - 0.3), 0.3, c.y), 0.05, 0.6, Color("#e8e4da"), 0.0, 6)
			mb.box(Vector3(c.x, 0.5, c.y), Vector3(r.size.x - 0.6, 0.05, 0.05), Color("#d33a3a"))
		else:
			mb.box(Vector3(c.x, 0.012, c.y), Vector3(r.size.x, 0.024, r.size.y), Color("#7a5a3c"))
			mb.box(Vector3(c.x, 0.026, c.y), Vector3(r.size.x - 0.8, 0.02, r.size.y - 0.8), Color("#4f3a26"))
			for k in int(r.size.x):
				var col := Color("#e8761f") if k % 2 == 0 else Color("#f2f2ee")
				mb.box(Vector3(r.position.x + k + 0.5, 0.18, r.position.y + 0.1), Vector3(0.9, 0.3, 0.12), col)
				mb.box(Vector3(r.position.x + k + 0.5, 0.18, r.end.y - 0.1), Vector3(0.9, 0.3, 0.12), col)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.to_mesh()
	mi.material_override = world.obj_mat
	add_child(mi)
	# figury "samorzadowcow" przy wstedze: zmyslone archetypy
	for z in zones:
		if z["kind"] == "konf":
			var c: Vector2 = (z["rect"] as Rect2).get_center()
			for k in 3:
				var m: Dictionary = Models.person("wind", rng)
				var ch = CharacterScript.new()
				add_child(ch)
				ch.setup(m["mesh"], m["scale"])
				ch.position = Vector3(c.x - 1.2 + k * 1.2, 0.0, c.y + 0.7)
				ch.rotation.y = PI * 0.0
		var lb := _mk_label(z["label"], 52, Color("#3a1f1c"))
		lb.position = Vector3((z["rect"] as Rect2).get_center().x, 1.6, (z["rect"] as Rect2).get_center().y)


func _mk_label(text: String, fs: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = fs
	l.pixel_size = 0.011
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(1, 1, 1, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	add_child(l)
	return l


func _build_labels() -> void:
	for L in LABELS:
		var lb := _mk_label(L[0], 44, Color("#22211d"))
		lb.position = Vector3(L[1], 2.2, L[2])
		_labels.append(lb)


func nearest_zone(p: Vector2, max_d: float):
	var best = null
	var bd := max_d
	for z in zones:
		var d := p.distance_to((z["rect"] as Rect2).get_center())
		if d < bd:
			bd = d
			best = z
	return best


# ------------------------------------------------------------------ rozgrywka
func start_game() -> void:
	if state == "play":
		return
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for c in coins:
		c["node"].queue_free()
	coins.clear()
	for b in bags:
		b["node"].queue_free()
	bags.clear()
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	floats.clear()
	time = 0.0
	debt = 12480.0
	spent = 0.0
	wave_idx = 0
	end_msg = ""
	banner = ""
	banner_t = 0.0
	player.stamina = 1.0
	player.stun = 0.0
	player.ammo = 6
	_next_item = rng.randi() % items.size()
	var s: Vector2 = world.find_start(START_TILE)
	if _autoplay <= 0.0 and player.pos.distance_to(s) > 60.0:
		player.pos = s
	flow.start(player.pos)
	for i in 14:
		_spawn_coin()
	for i in 4:
		_spawn_bag()
	state = "play"


## Przelacza pore doby: dzien -> zmierzch -> noc -> dzien.
func toggle_night() -> void:
	if night_target < 0.25:
		night_target = NIGHT_DUSK
	elif night_target < 0.75:
		night_target = 1.0
	else:
		night_target = 0.0


## Nazwa nastepnej pory doby (do przycisku).
func next_time_of_day_name() -> String:
	if night_target < 0.25:
		return "Zmierzch"
	elif night_target < 0.75:
		return "Noc"
	return "Dzień"


func next_item_name() -> String:
	return items[_next_item]["name"]


func add_float(text: String, p: Vector2, col: Color, ttl := 1.6) -> void:
	floats.append({"text": text, "pos": p, "col": col, "t": ttl, "ttl": ttl, "rise": 0.0})


func banner_show(t: String) -> void:
	banner = t
	banner_t = 3.2


func _ring_point(min_d: float, max_d: float, pred: Callable, tries := 120) -> Variant:
	for n in tries:
		var a := rng.randf() * TAU
		var p: Vector2 = player.pos + Vector2.from_angle(a) * rng.randf_range(min_d, max_d)
		if world.blocked(p, 0.3):
			continue
		if pred.is_valid() and not pred.call(p):
			continue
		return p
	return null


func _spawn_enemy(kind: String, quiet := false) -> void:
	var p = _ring_point(16.0, 26.0, func(q: Vector2) -> bool: return flow.dist_at(q) >= 0)
	if p == null:
		p = _ring_point(16.0, 26.0, Callable())
	if p == null:
		return
	var e = EnemyScript.new()
	add_child(e)
	e.setup(self, kind, p, rng)
	enemies.append(e)
	if not quiet:
		banner_show("Nowy wierzyciel: " + e.label)


func relocate_enemy(e) -> void:
	var p = _ring_point(18.0, 28.0, func(q: Vector2) -> bool: return flow.dist_at(q) >= 0)
	if p != null:
		e.pos = p


func _spawn_npc(near := false) -> void:
	var lo := 6.0 if near else 22.0
	var p = _ring_point(lo, 34.0, func(q: Vector2) -> bool:
		var u: int = world.under_at(q)
		return (u == 1 or u == 2 or u == 3 or u == 5 or u == 11) and not world.is_road_at(q))
	if p == null:
		return
	var n = NpcScript.new()
	add_child(n)
	n.setup(self, p, rng)
	npcs.append(n)


func _spawn_car(near := false) -> void:
	var lo := 8.0 if near else 24.0
	for tries in 80:
		var a := rng.randf() * TAU
		var p: Vector2 = player.pos + Vector2.from_angle(a) * rng.randf_range(lo, 38.0)
		var tile := Vector2i(floori(p.x), floori(p.y))
		if not world.is_road_tile(tile.x, tile.y):
			continue
		var dirs := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if world.is_road_tile(tile.x + d.x, tile.y + d.y) and world.is_road_tile(tile.x + d.x * 2, tile.y + d.y * 2):
				dirs.append(d)
		if dirs.is_empty():
			continue
		var tooclose := false
		for o in cars:
			if o.pos.distance_to(Vector2(tile.x + 0.5, tile.y + 0.5)) < 3.0:
				tooclose = true
				break
		if tooclose:
			continue
		var total := 0
		for w in CAR_WEIGHTS:
			total += w
		var r := rng.randi() % total
		var bt := 0
		for i in CAR_WEIGHTS.size():
			r -= CAR_WEIGHTS[i]
			if r < 0:
				bt = i
				break
		var c = CarScript.new()
		add_child(c)
		c.setup(self, tile, dirs[rng.randi() % dirs.size()], bt, rng, world.obj_mat)
		cars.append(c)
		return


func respawn_car(c) -> void:
	cars.erase(c)
	c.queue_free()


func _spawn_coin() -> void:
	var p = _ring_point(4.0, 24.0, func(q: Vector2) -> bool: return flow.dist_at(q) >= 0 and not world.is_road_at(q))
	if p == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _coin_mesh
	mi.material_override = world.obj_mat
	mi.scale = Vector3.ONE * 1.3
	add_child(mi)
	coins.append({"pos": p, "node": mi, "ph": rng.randf() * 6.0})


func _spawn_bag() -> void:
	var p = _ring_point(6.0, 26.0, func(q: Vector2) -> bool: return flow.dist_at(q) >= 0)
	if p == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _bag_mesh
	mi.material_override = world.obj_mat
	mi.scale = Vector3.ONE * 1.4
	add_child(mi)
	bags.append({"pos": p, "node": mi})


func _populate_initial() -> void:
	for i in 34:
		_spawn_npc(true)
	for i in 12:
		_spawn_car(true)


# ------------------------------------------------------------------ zdarzenia
func on_enemy_touch(e) -> void:
	var fine: int = e.d["fine"]
	debt += fine
	shake = 0.25
	stats["touches"] += 1
	player.hit_by(e.pos, 0.7, 0.35)
	add_float("Wezwanie do zapłaty! +%s zł" % hud._fmt(fine), player.pos, Color("#ff6b5e"))
	for n in npcs:
		if n.pos.distance_to(player.pos) < 5.0:
			n.alarm(e.pos, 0.6)


func player_throw() -> void:
	if state != "play":
		return
	if player.throw_cd > 0.0:
		return
	if player.ammo <= 0:
		add_float("Brak przedmiotów! Zbierz torbę.", player.pos, Color("#ffd2a0"))
		return
	var it: Dictionary = items[_next_item]
	_next_item = rng.randi() % items.size()
	player.ammo -= 1
	player.throw_cd = 0.4
	var best = null
	var bd := 11.0
	for e in enemies:
		var off: Vector2 = e.pos - player.pos
		var d := off.length()
		if d < bd and (off.normalized().dot(player.facing) > -0.2 or d < 4.5):
			bd = d
			best = e
	var target: Vector2 = player.pos + player.facing * 8.0
	if best != null:
		target = best.pos + best.facing * best.speed_now * (bd / 13.0) * 0.8
	var pr = ProjectileScript.new()
	add_child(pr)
	pr.setup(self, player.pos + player.facing * 0.3, target, it, world.obj_mat)
	projectiles.append(pr)
	stats["thrown"] += 1


func on_projectile_hit_enemy(e, it: Dictionary, from: Vector2) -> void:
	if it.get("boom", false):
		_detonate(e.pos, it)
		return
	_apply_enemy_hit(e, it, from)


func _apply_enemy_hit(e, it: Dictionary, from: Vector2) -> void:
	e.hit(it, from)
	stats["hits"] += 1
	lights.flash(e.pos, Color(1.0, 0.92, 0.6), 3.0, 0.3)
	add_float("Trafiony! (%s)" % it["name"], e.pos, Color("#9be58a"))
	if rng.randf() < 0.35:
		_drop_coin(e.pos)
	for n in npcs:
		if n.pos.distance_to(e.pos) < 4.0:
			n.alarm(e.pos, 0.5)


## Wybuch petardy: efekty, ogluszenie wierzycieli, panika przechodniow, zatrzymanie aut, kara za wlasna petarde.
func _detonate(p: Vector2, it: Dictionary) -> void:
	fx.explosion(p, 2.6)
	for e in enemies:
		if e.pos.distance_to(p) < 3.2:
			_apply_enemy_hit(e, it, p)
	for n in npcs:
		var d: float = n.pos.distance_to(p)
		if d < 2.2:
			n.knock(p)
		elif d < 5.0:
			n.alarm(p, 1.0)
	for c in cars:
		if c.pos.distance_to(p) < 3.6 and c.speed > 0.8:
			fx.car_impact(c, c.speed)
			c.speed = 0.0
			c.honk_cd = 2.0
			add_float("Beeep!", c.pos, Color("#ffd23a"), 1.0)
	if player.pos.distance_to(p) < 1.7:
		debt += 300.0
		shake = maxf(shake, 0.7)
		player.hit_by(p, 1.2, 0.8)
		add_float("Własna petarda! +300 zł", player.pos, Color("#ff9d5e"), 2.0)


func _drop_coin(p: Vector2) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _coin_mesh
	mi.material_override = world.obj_mat
	mi.scale = Vector3.ONE * 1.3
	add_child(mi)
	coins.append({"pos": p, "node": mi, "ph": rng.randf() * 6.0})


func on_projectile_hit_npc(n, it: Dictionary, from: Vector2) -> void:
	if it.get("boom", false):
		_detonate(n.pos, it)
		return
	n.knock(from)
	debt += 300.0
	add_float("Rzut w przechodnia! +300 zł", n.pos, Color("#ffb070"))


func on_projectile_hit_car(c, it: Dictionary) -> void:
	if it.get("boom", false):
		_detonate(c.pos, it)
		return
	add_float("Beeep!", c.pos, Color("#ffd23a"), 1.0)
	c.honk_cd = 2.0


func on_projectile_land(p: Vector2, it: Dictionary) -> void:
	if it.get("boom", false):
		_detonate(p, it)
		return
	for n in npcs:
		if n.pos.distance_to(p) < 3.5:
			n.alarm(p, 0.7)
	if it["name"] == "Butelka":
		add_float("Brzdęk!", p, Color("#bfe8ff"), 1.0)


# ------------------------------------------------------------------ wejscie
func zoom_by(factor: float) -> void:
	_fov_target = clampf(_fov_target / factor, FOV_MIN, FOV_MAX)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMagnifyGesture:
		zoom_by(ev.factor)
		return
	if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		zoom_by(1.12 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_EQUAL or ev.keycode == KEY_PLUS or ev.keycode == KEY_KP_ADD:
			zoom_by(1.15)
		elif ev.keycode == KEY_MINUS or ev.keycode == KEY_KP_SUBTRACT:
			zoom_by(1.0 / 1.15)
		elif ev.keycode == KEY_N:
			toggle_night()
		elif ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			if state != "play":
				start_game()
		elif ev.keycode == KEY_SPACE:
			if state == "play":
				player_throw()
			else:
				start_game()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if state != "play":
			if ev.pressed:
				start_game()
			return
		joy_active = ev.pressed
		if ev.pressed:
			joy_origin = ev.position
			joy_pos = ev.position
	elif ev is InputEventMouseMotion and joy_active:
		joy_pos = ev.position


func _read_dir() -> Vector2:
	if _autoplay > 0.0:
		return _auto_dir
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		d.y += 1.0
	d = d.limit_length(1.0)
	if joy_active:
		var v := joy_pos - joy_origin
		if v.length() > 14.0:
			d = v.normalized()
	return d


# ------------------------------------------------------------------ petla
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05) * time_scale_test
	_frames += 1
	if _fxdemo != Vector2.ZERO and _frames == 20:
		_run_fxdemo()
	for k in _steps:
		if _autoplay > 0.0 and state == "play":
			_autoplay_step(dt)
		_update(dt)
	if (_shot != "" or _autoplay > 0.0) and _frames >= 24 and (_autoplay <= 0.0 or time >= _autoplay or state == "over"):
		if _shot != "":
			get_viewport().get_texture().get_image().save_png(_shot)
		var healthy: bool = not world.blocked(player.pos, 0.2) and npcs.size() > 0 and cars.size() > 0
		print("STAT czas=%.1f dlug=%d wrogowie=%d npc=%d auta=%d rzuty=%d trafienia=%d kary_auta=%d dotkniecia=%d chunki=%d wybuchy=%d slady=%d" % [
			time, debt, enemies.size(), npcs.size(), cars.size(), stats["thrown"], stats["hits"], stats["car_fines"], stats["touches"], world.chunk_count(), fx.boom_count, fx.skid_count])
		get_tree().quit(0 if (healthy or _autoplay <= 0.0) else 1)


## Test wizualny (--fxdemo=x,y): wybuch w podanym miejscu oraz zakrzywione slady opon obok.
func _run_fxdemo() -> void:
	_detonate(_fxdemo, items[6])
	for side in [-1.0, 1.0]:
		var prev := Vector2.ZERO
		for i in 40:
			var t := i / 39.0
			var q := _fxdemo + Vector2(-9.0 + t * 7.0, -0.9 + side * 0.32 + sin(t * 2.2) * 0.8)
			if i > 0:
				fx.skid_segment(prev, q)
			prev = q
	for i in 6:
		fx.smoke_puff(_fxdemo + Vector2(-3.0 + i * 0.5, -0.6 + sin(i * 0.4) * 0.5), 0.4, 1.2, 1.6)


func _autoplay_step(dt: float) -> void:
	_auto_t -= dt
	if _auto_t <= 0.0:
		_auto_t = rng.randf_range(0.6, 1.6)
		_auto_dir = Vector2.from_angle(rng.randf() * TAU)
		if enemies.size() > 0 and rng.randf() < 0.6:
			var e = enemies[0]
			_auto_dir = (player.pos - e.pos).normalized().rotated(rng.randf_range(-0.8, 0.8))
	if rng.randf() < dt * 0.8:
		player_throw()


func _update(dt: float) -> void:
	if state == "play":
		time += dt
		if banner_t > 0.0:
			banner_t -= dt
		while wave_idx < WAVES.size() and time >= WAVES[wave_idx][0]:
			_spawn_enemy(WAVES[wave_idx][1], wave_idx == 0)
			wave_idx += 1
		player.tick(dt, _read_dir(), Input.is_physical_key_pressed(KEY_SHIFT) or hud.sprint_held)
		debt += debt * 0.032 / 60.0 * dt
		for e in enemies:
			e.tick(dt)
		_update_pickups(dt)
		_check_car_hits()
		for i in range(projectiles.size() - 1, -1, -1):
			var pr = projectiles[i]
			pr.tick(dt)
			if not pr.alive:
				pr.queue_free()
				projectiles.remove_at(i)
		if debt <= 0.0:
			debt = 0.0
			state = "over"
			end_msg = "win"
		elif debt >= 25000.0:
			state = "over"
			end_msg = "lose"
	else:
		player.ch.animate(0.0, dt)
	# miasto zyje takze w menu
	for n in npcs:
		n.tick(dt)
	for c in cars:
		c.tick(dt)
	_director()
	flow.step(900, player.pos)
	for i in range(floats.size() - 1, -1, -1):
		floats[i]["t"] -= dt
		floats[i]["rise"] += dt
		if floats[i]["t"] <= 0.0:
			floats.remove_at(i)
	if shake > 0.0:
		shake -= dt
	night_cur = move_toward(night_cur, night_target, dt * 0.6)
	world.set_night(night_cur)
	postfx.set_night(night_cur)
	fx.tick(dt)
	_update_camera(dt)
	_update_lights(dt)
	_update_shadows()
	world.update_chunks(_cam_pos, 5.0)
	world.tree_mat.set_shader_parameter("fade_pos", Vector3(player.pos.x, 0, player.pos.y))
	for lb in _labels:
		var d: float = Vector2(lb.position.x, lb.position.z).distance_to(_cam_pos)
		lb.visible = d < 20.0 and night_cur < 0.7
	hud.btn_night.text = next_time_of_day_name()
	hud.position = Vector2.ZERO
	hud.size = get_viewport().get_visible_rect().size
	hud.queue_redraw()


func _update_pickups(dt: float) -> void:
	for i in range(coins.size() - 1, -1, -1):
		var c = coins[i]
		var p: Vector2 = c["pos"]
		var node: MeshInstance3D = c["node"]
		node.position = Vector3(p.x, 0.25 + sin(time * 4.0 + c["ph"]) * 0.04, p.y)
		node.rotation.y += dt * 3.0
		var d := p.distance_to(player.pos)
		if d < 0.55:
			debt -= 200.0
			spent += 200.0
			add_float("−200 zł", p, Color("#ffe066"), 1.1)
			node.queue_free()
			coins.remove_at(i)
			_spawn_coin()
		elif d > 36.0:
			var np = _ring_point(6.0, 24.0, func(q: Vector2) -> bool: return flow.dist_at(q) >= 0 and not world.is_road_at(q))
			if np != null:
				c["pos"] = np
	for i in range(bags.size() - 1, -1, -1):
		var b = bags[i]
		var p2: Vector2 = b["pos"]
		b["node"].position = Vector3(p2.x, 0.0, p2.y)
		var d2 := p2.distance_to(player.pos)
		if d2 < 0.6:
			var n := rng.randi_range(3, 5)
			player.ammo += n
			add_float("+%d przedmiotów" % n, p2, Color("#ffe9a8"), 1.3)
			b["node"].queue_free()
			bags.remove_at(i)
			_spawn_bag()
		elif d2 > 40.0:
			var np2 = _ring_point(8.0, 26.0, func(q: Vector2) -> bool: return flow.dist_at(q) >= 0)
			if np2 != null:
				b["pos"] = np2


func _check_car_hits() -> void:
	for c in cars:
		if c.speed < 0.6:
			continue
		if c.hit_cd <= 0.0 and c.overlaps(player.pos, player.RADIUS):
			c.hit_cd = 3.0
			debt += 300.0
			stats["car_fines"] += 1
			shake = 0.3
			lights.flash(player.pos, Color(1.0, 0.45, 0.2), 4.0, 0.4)
			fx.car_impact(c, c.speed)
			player.hit_by(c.pos, 1.0, 0.6)
			add_float("Mandat: potrącenie (%s)! +300 zł" % c.car_name, player.pos, Color("#ff9d5e"), 2.0)
			c.speed = 0.0
		for n in npcs:
			if n.state != "flee" and c.overlaps(n.pos, n.radius) or (c.overlaps(n.pos, n.radius * 0.6) and c.speed > 1.2):
				n.knock(c.pos)
		for e in enemies:
			if e.stun <= 0.0 and c.overlaps(e.pos, e.radius):
				e.hit_by_car(c)
				fx.car_impact(c, c.speed)
				lights.flash(e.pos, Color(1.0, 0.55, 0.25), 3.5, 0.4)
				add_float("Windykator potrącony!", e.pos, Color("#9be58a"), 1.6)
				c.speed = 0.0


func _director() -> void:
	var want_n := 34 if night_cur < 0.5 else 16
	var want_c := 12 if night_cur < 0.5 else 8
	if npcs.size() < want_n:
		_spawn_npc()
	if cars.size() < want_c:
		_spawn_car()
	for i in range(npcs.size() - 1, -1, -1):
		if npcs[i].pos.distance_to(player.pos) > 44.0 or (night_cur > 0.5 and npcs.size() > want_n and i % 3 == 0):
			npcs[i].queue_free()
			npcs.remove_at(i)
			break
	for i in range(cars.size() - 1, -1, -1):
		if cars[i].pos.distance_to(player.pos) > 48.0:
			cars[i].queue_free()
			cars.remove_at(i)
			break


func _update_lights(dt: float) -> void:
	var on := night_cur >= 0.02
	lights.set_active(on)
	if not on:
		return
	_lamp_t -= dt
	if _lamp_t <= 0.0:
		_lamp_t = 0.4
		_lamp_cache = world.nearest_lamps(_cam_pos, 40)
	lights.begin(_cam_pos)
	# latarnie: cieple, sodowe swiatlo
	for lp in _lamp_cache:
		lights.point(lp, 6.0, Color(1.0, 0.78, 0.42), 0.95)
	# gracz: lagodne ciepla poswiata, zeby postac byla czytelna w ciemnosci
	lights.point(player.pos, 6.5, Color(1.0, 0.90, 0.72), 0.7)
	# auta: stozki reflektorow, delikatny blask pod autem i tylne swiatla (mocniejsze przy hamowaniu)
	var cam2 := _cam_pos
	for c in cars:
		if c.pos.distance_squared_to(cam2) > 1444.0:
			continue
		var front: Vector2 = c.pos + c.dir * c.length * 0.45
		lights.cone(front, c.dir, 9.5, 3.8, Color(1.0, 0.93, 0.74), 1.1)
		lights.point(c.pos, 2.2, Color(1.0, 0.85, 0.6), 0.22)
		var braking: bool = c.speed < 0.5
		lights.point(c.pos - c.dir * c.length * 0.5, 1.4, Color(1.0, 0.12, 0.08), 0.75 if braking else 0.38)
	# wierzyciele: zlowrogi, czerwonawy blask
	for e in enemies:
		lights.point(e.pos, 2.4, Color(1.0, 0.25, 0.15), 0.3)
	lights.end()


func _update_camera(dt: float) -> void:
	var look: Vector2 = player.facing * minf(player.speed_now * 0.35, 1.6)
	var target: Vector2 = player.pos + look
	_cam_pos = _cam_pos.lerp(target, minf(1.0, dt * 5.0))
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake * 0.5
	cam.position = Vector3(_cam_pos.x + off.x, CAM_HEIGHT, _cam_pos.y + off.y)
	cam.fov = lerpf(cam.fov, _fov_target, minf(1.0, dt * 8.0))


func _update_shadows() -> void:
	var i := 0
	var put := func(p: Vector2, sx: float, sz: float, yaw: float) -> void:
		if i >= 120:
			return
		var bs := Basis(Vector3.UP, yaw).scaled(Vector3(sx, 1.0, sz))
		_shadow_mm.set_instance_transform(i, Transform3D(bs, Vector3(p.x + 0.07, 0.03, p.y + 0.1)))
		i += 1
	put.call(player.pos, 0.62, 0.62, 0.0)
	for e in enemies:
		put.call(e.pos, 0.64, 0.64, 0.0)
	for n in npcs:
		if n.pos.distance_squared_to(_cam_pos) < 900.0:
			put.call(n.pos, 0.5, 0.5, 0.0)
	for c in cars:
		if c.pos.distance_squared_to(_cam_pos) < 900.0:
			put.call(c.pos, c.width * 1.25, c.length * 1.12, c.rotation.y)
	while i < 120:
		_shadow_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -50, 0)))
		i += 1
