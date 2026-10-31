extends Node3D
## Rzucany przedmiot: lot po luku, trafia wrogow i przechodniow, budzi okolice przy ladowaniu.

const G := 22.0

var game
var pos := Vector2.ZERO
var h := 0.6
var vel := Vector2.ZERO
var vy := 0.0
var item: Dictionary
var alive := true
var spin := 0.0
var from_pos := Vector2.ZERO
var _trail_t := 0.0


func setup(g, start: Vector2, target: Vector2, it: Dictionary, mat: Material) -> void:
	game = g
	item = it
	pos = start
	from_pos = start
	var dist := maxf(start.distance_to(target), 0.8)
	var spd := 13.0
	var t := dist / spd
	vel = (target - start).normalized() * spd
	vy = (0.5 * G * t * t - h) / t
	var mi := MeshInstance3D.new()
	mi.mesh = it["mesh"]
	mi.material_override = mat
	mi.scale = Vector3.ONE * 1.6
	add_child(mi)
	spin = game.rng.randf_range(8.0, 18.0)
	_sync()


func _sync() -> void:
	position = Vector3(pos.x, h, pos.y)


func tick(delta: float) -> void:
	pos += vel * delta
	vy -= G * delta
	h += vy * delta
	rotation.y += spin * delta
	rotation.x += spin * 0.6 * delta
	_sync()
	if item.get("boom", false):
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			game.fx.fuse_spark(pos, h)
	if game.world.is_solid_at(pos) and game.world.class_at(pos) == 12 and h < 2.0:
		_land()
		return
	if h < 1.0:
		for e in game.enemies:
			if pos.distance_to(e.pos) < 0.55:
				game.on_projectile_hit_enemy(e, item, from_pos)
				alive = false
				return
		for n in game.npcs:
			if pos.distance_to(n.pos) < 0.45:
				game.on_projectile_hit_npc(n, item, from_pos)
				alive = false
				return
		for c in game.cars:
			if c.overlaps(pos, 0.1) and h < 0.5:
				game.on_projectile_hit_car(c, item)
				alive = false
				return
	if h <= 0.04:
		_land()


func _land() -> void:
	game.on_projectile_land(pos, item)
	alive = false
