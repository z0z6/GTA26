extends Node3D
## Przechodzien: porusza sie autonomicznie i reaguje na sytuacje (samochody, poscig, rzucane przedmioty,
## strefy wydarzen). Osobowosc (odwaga, ciekawosc) wplywa na zachowanie.

const CharacterScript := preload("res://scripts/character.gd")
const Models := preload("res://scripts/models.gd")

var game
var pos := Vector2.ZERO
var facing := Vector2(0, 1)
var ch
var radius := 0.22
var state := "wander"
var timer := 0.0
var target := Vector2.ZERO
var walk_speed := 1.4
var courage := 0.5
var curiosity := 0.5
var flee_dir := Vector2.ZERO
var watch_pos := Vector2.ZERO
var think_t := 0.0
var say := ""
var say_t := 0.0
var stuck_t := 0.0
var chat_cd := 8.0
var kind_name := "Przechodzień"


func setup(g, start: Vector2, rng: RandomNumberGenerator) -> void:
	game = g
	pos = start
	courage = rng.randf()
	curiosity = rng.randf()
	var m: Dictionary = Models.person("npc", rng)
	kind_name = m["name"]
	walk_speed = rng.randf_range(1.0, 1.7)
	if kind_name == "Dziecko":
		walk_speed *= 1.25
		radius = 0.17
	elif kind_name == "Senior":
		walk_speed *= 0.65
	ch = CharacterScript.new()
	add_child(ch)
	ch.setup(m["mesh"], m["scale"])
	facing = Vector2.from_angle(rng.randf() * TAU)
	timer = rng.randf_range(0.5, 3.0)
	state = "idle"
	chat_cd = rng.randf_range(4.0, 20.0)
	position = Vector3(pos.x, 0, pos.y)


func _say(text: String, t := 2.2) -> void:
	if say_t > 0.5:
		return
	say = text
	say_t = t


func alarm(from: Vector2, panic := 1.0) -> void:
	var away := (pos - from)
	if away.length() < 0.01:
		away = Vector2.from_angle(game.rng.randf() * TAU)
	flee_dir = away.normalized()
	state = "flee"
	timer = 1.4 + panic * 1.2
	_say(["Ej!", "Kto rzuca?!", "Co to było?!", "Ratunku!"][game.rng.randi() % 4], 1.8)


func knock(from: Vector2) -> void:
	alarm(from, 1.5)
	_say("Jezu, mój kręgosłup!", 2.2)
	ch.flash()


func _think() -> void:
	var rng: RandomNumberGenerator = game.rng
	# samochody jadace w moja strone
	for c in game.cars:
		var rel: Vector2 = pos - c.pos
		var dd := rel.length()
		if dd < 4.6 and c.speed > 0.8:
			var ahead := rel.dot(c.dir)
			if ahead > -0.2 and absf(rel.dot(c.perp())) < 1.3:
				var side: float = 1.0 if rel.dot(c.perp()) >= 0.0 else -1.0
				flee_dir = (c.perp() * side + c.dir * 0.3).normalized()
				if state != "flee":
					state = "flee"
					timer = 0.8
					if rng.randf() < 0.35:
						_say("Uważaj!")
				return
	# poscig w poblizu
	if state != "flee":
		for e in game.enemies:
			if e.stun > 0.0:
				continue
			var de := pos.distance_to(e.pos)
			if de < 6.5 and e.pos.distance_to(game.player.pos) < 12.0:
				if courage < 0.45:
					flee_dir = (pos - e.pos).normalized()
					state = "flee"
					timer = 2.0
					_say(["Ratunku!", "Uciekajmy!", "Windykator!"][rng.randi() % 3])
				elif state != "watch" and curiosity > 0.35:
					state = "watch"
					watch_pos = e.pos
					timer = 2.5
					_say(["Co się dzieje?", "Znowu ktoś nie zapłacił…", "Oho, pościg!"][rng.randi() % 3])
				return
	# gracz biegnie tuz obok
	if state != "flee" and pos.distance_to(game.player.pos) < 1.4 and game.player.speed_now > 5.0:
		if rng.randf() < 0.3:
			_say(["Dokąd tak pędzisz?", "Spokojnie!", "Patrz pod nogi!"][rng.randi() % 3])
		flee_dir = (pos - game.player.pos).normalized()
		state = "flee"
		timer = 0.5


func _pick_target() -> void:
	var rng: RandomNumberGenerator = game.rng
	if rng.randf() < 0.30:
		var z = game.nearest_zone(pos, 28.0)
		if z != null:
			var r: Rect2 = z["rect"]
			target = Vector2(r.position.x + rng.randf() * r.size.x, r.position.y + rng.randf() * r.size.y)
			state = "goto_zone"
			timer = 25.0
			return
	for i in 10:
		var a := rng.randf() * TAU
		var t := pos + Vector2.from_angle(a) * rng.randf_range(3.0, 11.0)
		if game.world.blocked(t, radius):
			continue
		var u: int = game.world.under_at(t)
		if u == 7 or u == 6 or u == 4 or u == 13:
			continue
		target = t
		state = "wander"
		timer = 20.0
		return
	state = "idle"
	timer = 2.0


func tick(delta: float) -> void:
	var world = game.world
	var rng: RandomNumberGenerator = game.rng
	if say_t > 0.0:
		say_t -= delta
	chat_cd -= delta
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.28 + rng.randf() * 0.12
		_think()
	if chat_cd <= 0.0:
		chat_cd = rng.randf_range(14.0, 40.0)
		if state == "idle" or state == "wander":
			_say(["Dzień dobry.", "Ładna dziś pogoda.", "Do sklepu idę.", "Znowu ceny w górę…", "Gdzie ten autobus?"][rng.randi() % 5])
	timer -= delta
	var mv := Vector2.ZERO
	var spd := 0.0
	match state:
		"idle":
			if timer <= 0.0:
				_pick_target()
		"wander", "goto_zone":
			var to := target - pos
			if to.length() < 0.5 or timer <= 0.0:
				if state == "goto_zone":
					state = "gather"
					timer = rng.randf_range(6.0, 14.0)
					var z = game.nearest_zone(pos, 4.0)
					if z != null:
						_say("Brawo!" if z["kind"] == "konf" else "Znowu remont…")
				else:
					state = "idle"
					timer = rng.randf_range(0.8, 4.0)
			else:
				mv = to.normalized()
				spd = walk_speed
		"gather":
			var z = game.nearest_zone(pos, 6.0)
			if z != null:
				facing = ((z["rect"] as Rect2).get_center() - pos).normalized()
			if timer <= 0.0:
				state = "idle"
				timer = 0.5
		"watch":
			facing = (watch_pos - pos).normalized()
			if timer <= 0.0:
				state = "idle"
				timer = 0.5
		"flee":
			mv = flee_dir
			spd = 3.6
			if timer <= 0.0:
				state = "idle"
				timer = rng.randf_range(0.5, 2.0)
	var moved := 0.0
	if mv != Vector2.ZERO:
		spd *= world.speed_at(pos)
		var step := mv * spd * delta
		var nx := pos + Vector2(step.x, 0.0)
		var blockedx: bool = world.blocked(nx, radius)
		if not blockedx:
			pos = nx
		var ny := pos + Vector2(0.0, step.y)
		var blockedy: bool = world.blocked(ny, radius)
		if not blockedy:
			pos = ny
		facing = mv
		moved = spd
		if blockedx and blockedy:
			stuck_t += delta
			if stuck_t > 0.7:
				stuck_t = 0.0
				if state == "flee":
					flee_dir = flee_dir.rotated(rng.randf_range(-1.6, 1.6))
				else:
					state = "idle"
					timer = 0.3
		else:
			stuck_t = 0.0
	ch.animate(moved, delta)
	ch.face(facing, delta)
	position = Vector3(pos.x, 0, pos.y)
