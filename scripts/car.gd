extends Node3D
## Samochod: jezdzi po kaflach drog (losowy skret na skrzyzowaniach), prawa strona jezdni,
## zwalnia przed przeszkodami, trabi na pieszych.

const Models := preload("res://scripts/models.gd")

var game
var world
var pos := Vector2.ZERO
var dir := Vector2.RIGHT
var speed := 0.0
var cruise := 3.0
var length := 1.5
var width := 0.66
var car_name := ""
var tile_dir := Vector2i.RIGHT
var target := Vector2.ZERO
var stuck_t := 0.0
var honk_cd := 0.0
var body_type := 1
var hit_cd := 0.0


func perp() -> Vector2:
	return Vector2(-dir.y, dir.x)


func setup(g, tile: Vector2i, tdir: Vector2i, btype: int, rng: RandomNumberGenerator, obj_mat: Material) -> void:
	game = g
	world = g.world
	body_type = btype
	var m: Dictionary = Models.car(btype, rng)
	length = m["length"]
	width = m["width"]
	car_name = m["name"]
	var mi := MeshInstance3D.new()
	mi.mesh = m["mesh"]
	mi.material_override = obj_mat
	mi.scale = Vector3.ONE * 1.0
	add_child(mi)
	cruise = rng.randf_range(2.6, 4.2)
	if btype == 8:
		cruise = rng.randf_range(2.0, 2.8)
	elif btype == 7:
		cruise = rng.randf_range(2.2, 3.2)
	tile_dir = tdir
	dir = Vector2(tdir.x, tdir.y)
	var right := Vector2(-dir.y, dir.x)
	pos = Vector2(tile.x + 0.5, tile.y + 0.5) + right * 0.22
	target = pos + dir * 1.0
	speed = cruise * 0.6
	_sync()


func _sync() -> void:
	position = Vector3(pos.x, 0.0, pos.y)
	rotation.y = atan2(-dir.x, -dir.y)


func _pick_next() -> void:
	var cur := Vector2i(floori(pos.x), floori(pos.y))
	var fwd := tile_dir
	var left := Vector2i(fwd.y, -fwd.x)
	var right := Vector2i(-fwd.y, fwd.x)
	var opts := []
	var wts := []
	if world.is_road_tile(cur.x + fwd.x, cur.y + fwd.y):
		opts.append(fwd)
		wts.append(0.72)
	if world.is_road_tile(cur.x + right.x, cur.y + right.y):
		opts.append(right)
		wts.append(0.15)
	if world.is_road_tile(cur.x + left.x, cur.y + left.y):
		opts.append(left)
		wts.append(0.13)
	var choice := Vector2i.ZERO
	if opts.is_empty():
		var back := -fwd
		if world.is_road_tile(cur.x + back.x, cur.y + back.y):
			choice = back
		else:
			stuck_t = 99.0
			return
	else:
		var total := 0.0
		for w in wts:
			total += w
		var r: float = game.rng.randf() * total
		choice = opts[0]
		for i in opts.size():
			r -= wts[i]
			if r <= 0.0:
				choice = opts[i]
				break
	tile_dir = choice
	var nt := cur + choice
	var cd := Vector2(choice.x, choice.y)
	target = Vector2(nt.x + 0.5, nt.y + 0.5) + Vector2(-cd.y, cd.x) * 0.22


## Odleglosc do najblizszej przeszkody przed maska (lub 99).
func _scan() -> float:
	var best := 99.0
	var p := perp()
	for o in game.cars:
		if o == self:
			continue
		var rel: Vector2 = o.pos - pos
		var ahead := rel.dot(dir)
		if ahead < 0.2 or ahead > 3.0:
			continue
		var lat := absf(rel.dot(p))
		if lat < (width + o.width) * 0.5 + 0.12:
			best = minf(best, ahead - (length + o.length) * 0.5)
	var peds := []
	peds.append(game.player.pos)
	for n in game.npcs:
		peds.append(n.pos)
	for e in game.enemies:
		peds.append(e.pos)
	for q in peds:
		var rel2: Vector2 = q - pos
		var ahead2 := rel2.dot(dir)
		if ahead2 < 0.2 or ahead2 > 2.6:
			continue
		if absf(rel2.dot(p)) < width * 0.5 + 0.32:
			var gap := ahead2 - length * 0.5 - 0.25
			if gap < 1.6 and honk_cd <= 0.0 and speed > 0.5:
				honk_cd = 3.0
				game.add_float("Beeep!", pos + dir * 1.2, Color("#ffd23a"), 1.0)
			best = minf(best, gap)
	return best


func tick(delta: float) -> void:
	honk_cd -= delta
	hit_cd -= delta
	if pos.distance_to(target) < 0.5:
		_pick_next()
	var desired := (target - pos).normalized()
	var da := angle_difference(dir.angle(), desired.angle())
	var turn := clampf(da, -2.8 * delta, 2.8 * delta)
	dir = Vector2.from_angle(dir.angle() + turn)
	var want := cruise * clampf(1.0 - absf(da) * 0.55, 0.35, 1.0)
	var gap := _scan()
	if gap < 2.4:
		want = minf(want, maxf(0.0, (gap - 0.4) * 1.5))
	var acc := 7.5 if want < speed else 2.6
	speed = move_toward(speed, want, acc * delta)
	var step := dir * speed * delta
	var np := pos + step
	if world.is_solid_at(np):
		speed = 0.0
		stuck_t += delta * 3.0
	else:
		pos = np
	if speed < 0.1:
		stuck_t += delta
	else:
		stuck_t = maxf(0.0, stuck_t - delta)
	if stuck_t > 7.0:
		game.respawn_car(self)
		return
	_sync()


## Czy kolo o srodku p i promieniu r zahacza o nadwozie.
func overlaps(p: Vector2, r: float) -> bool:
	var rel := p - pos
	return absf(rel.dot(dir)) < length * 0.5 + r and absf(rel.dot(perp())) < width * 0.5 + r
