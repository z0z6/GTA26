extends Node3D
## Wierzyciel: scigani gracza po mapie odleglosci. Typy roznia sie szybkoscia i zachowaniem.

const CharacterScript := preload("res://scripts/character.gd")
const Models := preload("res://scripts/models.gd")

const KINDS := {
	"wind": {"name": "Windykator", "spd": 3.7, "r": 0.28, "fine": 1200, "say": [
		"Szanowny Panie, to już trzecie ostrzeżenie…", "Prosimy o kontakt w terminie siedmiu dni.",
		"Odsetki same się nie spłacą.", "Czekamy na wpłatę, Panie Dłużniku."]},
	"chw": {"name": "Pan z chwilówki", "spd": 3.0, "r": 0.28, "fine": 1200, "say": [
		"Chwilówka na już, spłata od razu!", "RRSO to tylko liczba.", "Pierwsza pożyczka gratis, druga za dwie."]},
	"kon": {"name": "Konkubent", "spd": 4.0, "r": 0.30, "fine": 600, "say": [
		"Gdzie jest moja kasa?!", "Kapciem cię dopadnę!", "Oddawaj, coś pożyczył!"]},
	"kom": {"name": "Komornik", "spd": 2.6, "r": 0.34, "fine": 2000, "say": [
		"Zajęcie rachunku bankowego!", "Pieczątka jest, kasy brak.", "Pismo w sprawie egzekucji."]},
}

var game
var kind := "wind"
var d: Dictionary
var pos := Vector2.ZERO
var facing := Vector2(0, 1)
var ch
var radius := 0.28
var stun := 0.0
var cd := 0.0
var say := ""
var say_t := 0.0
var next_say := 3.0
var dash := 0.0
var dash_cd := 4.0
var ph := 0.0
var vel := Vector2.ZERO
var speed_now := 0.0
var label := ""


func setup(g, k: String, start: Vector2, rng: RandomNumberGenerator) -> void:
	game = g
	kind = k
	d = KINDS[k]
	pos = start
	radius = d["r"]
	ph = rng.randf() * 6.28
	next_say = 1.5 + rng.randf() * 4.0
	dash_cd = 2.0 + rng.randf() * 3.0
	var m: Dictionary = Models.person(k, rng)
	ch = CharacterScript.new()
	add_child(ch)
	ch.setup(m["mesh"], m["scale"])
	label = d["name"]
	position = Vector3(pos.x, 0, pos.y)


func hit(item: Dictionary, from: Vector2) -> void:
	stun = maxf(stun, item["stun"])
	var dir := (pos - from).normalized()
	var np := pos + dir * 0.7
	if not game.world.blocked(np, radius):
		pos = np
	say = item["text"]
	say_t = 1.6
	next_say = 4.0
	ch.flash()


func hit_by_car(c) -> void:
	stun = maxf(stun, 2.2)
	say = "Moja noga!"
	say_t = 1.8
	ch.flash()


func tick(delta: float) -> void:
	var world = game.world
	var P: Vector2 = game.player.pos
	next_say -= delta
	if say_t > 0.0:
		say_t -= delta
	if next_say <= 0.0 and stun <= 0.0:
		var lines: Array = d["say"]
		say = lines[game.rng.randi() % lines.size()]
		say_t = 2.6
		next_say = 6.0 + game.rng.randf() * 5.0
	if cd > 0.0:
		cd -= delta
	var dp := pos.distance_to(P)
	if dp > 36.0:
		game.relocate_enemy(self)
		return
	var moving_speed := 0.0
	if stun > 0.0:
		stun -= delta
	else:
		var target := P
		if not (dp < 5.0 and world.los(pos, P)):
			var t: Vector2 = game.flow.next_target(pos)
			if t != Vector2.ZERO:
				target = t
		var dir := (target - pos).normalized()
		if kind == "kon":
			var z := sin(game.time * 5.0 + ph) * 0.45
			dir = (dir + Vector2(-dir.y, dir.x) * z).normalized()
		var spd: float = d["spd"] * world.speed_at(pos)
		if kind == "chw":
			dash_cd -= delta
			if dash > 0.0:
				dash -= delta
				spd *= 2.3
			elif dash_cd <= 0.0:
				dash = 0.55
				dash_cd = 4.5
		if cd > 0.0:
			spd *= 0.15
		for o in game.enemies:
			if o == self:
				continue
			var off: Vector2 = pos - o.pos
			var od := off.length()
			if od > 0.0 and od < 0.7:
				dir += off / od * 0.6
		dir = dir.normalized()
		var mv := dir * spd * delta
		var nx := pos + Vector2(mv.x, 0.0)
		if not world.blocked(nx, radius):
			pos = nx
		var ny := pos + Vector2(0.0, mv.y)
		if not world.blocked(ny, radius):
			pos = ny
		facing = dir
		moving_speed = spd
		if dp < radius + game.player.RADIUS + 0.05 and cd <= 0.0:
			cd = 2.4
			game.on_enemy_touch(self)
	speed_now = moving_speed
	ch.animate(moving_speed, delta)
	ch.face(facing, delta)
	position = Vector3(pos.x, 0, pos.y)
