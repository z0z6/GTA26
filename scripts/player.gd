extends Node3D
## Gracz: ruch z kolizjami o kafle, sprint z kondycja, rzucanie przedmiotami.

const CharacterScript := preload("res://scripts/character.gd")
const Models := preload("res://scripts/models.gd")

const WALK := 4.2
const SPRINT := 6.0
const RADIUS := 0.28

var world
var pos := Vector2.ZERO
var facing := Vector2(0, -1)
var ch
var stamina := 1.0
var stun := 0.0
var ammo := 6
var item_idx := 0
var speed_now := 0.0
var throw_cd := 0.0


func setup(w, start: Vector2) -> void:
	world = w
	pos = start
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var d: Dictionary = Models.person("player", rng)
	ch = CharacterScript.new()
	add_child(ch)
	ch.setup(d["mesh"], d["scale"])
	_sync()


func _sync() -> void:
	position = Vector3(pos.x, 0.0, pos.y)


func tick(delta: float, dir: Vector2, sprint_held: bool) -> void:
	if throw_cd > 0.0:
		throw_cd -= delta
	var moving := dir.length() > 0.05
	var sprinting := sprint_held and stamina > 0.02 and moving
	stamina = clampf(stamina + (-0.36 if sprinting else 0.20) * delta, 0.0, 1.0)
	var sp: float = (SPRINT if sprinting else WALK) * float(world.speed_at(pos))
	if stun > 0.0:
		stun -= delta
		sp *= 0.15
	speed_now = 0.0
	if moving:
		var d := dir.normalized()
		facing = d
		var mv: Vector2 = d * sp * delta
		var nx := pos + Vector2(mv.x, 0.0)
		if not world.blocked(nx, RADIUS):
			pos = nx
		var ny := pos + Vector2(0.0, mv.y)
		if not world.blocked(ny, RADIUS):
			pos = ny
		speed_now = sp
	ch.animate(speed_now, delta)
	ch.face(facing, delta)
	_sync()


func hit_by(from: Vector2, stun_s: float, push: float) -> void:
	stun = maxf(stun, stun_s)
	var d := (pos - from).normalized()
	var np := pos + d * push
	if not world.blocked(np, RADIUS):
		pos = np
	ch.flash()
