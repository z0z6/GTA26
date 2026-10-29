extends SceneTree
## Test dymny: swiat, budynki, kolizje, mapa odleglosci, modele.
## Uruchomienie: godot --headless --path . --script res://tests/smoke.gd

const Models := preload("res://scripts/models.gd")
const FlowScript := preload("res://scripts/flow.gd")

var ok := true


func _initialize() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	world.setup()
	print("setup ms: ", Time.get_ticks_msec() - t0)
	_check(world.w == 1074 and world.h == 1001, "rozmiar siatki %dx%d" % [world.w, world.h])
	var counts := {}
	for i in world.w * world.h:
		counts[world.cls[i]] = counts.get(world.cls[i], 0) + 1
	_check(counts.get(12, 0) > 30000, "kafle zabudowy (%d)" % counts.get(12, 0))
	_check(counts.get(7, 0) > 15000, "woda obecna")
	var total_b := 0
	for k in world._bld_index:
		total_b += world._bld_index[k].size()
	_check(total_b > 1500, "wielokaty budynkow (%d)" % total_b)
	var s: Vector2 = world.find_start(Vector2i(533, 441))
	_check(not world.blocked(s, 0.3), "start nie jest w scianie")
	_check(world.blocked(Vector2(-5, 10), 0.3), "poza mapa jest lita")
	_check(world.speed_at(Vector2(535.5, 439.5)) == 0.5, "strefa konferencji spowalnia")
	var t1 := Time.get_ticks_msec()
	world.build_all_near(s)
	_check(world.chunk_count() >= 20, "chunki zbudowane (%d, %d ms)" % [world.chunk_count(), Time.get_ticks_msec() - t1])
	for jump in [Vector2(300, 300), Vector2(900, 800), Vector2(100, 900)]:
		world.build_all_near(jump)
	_check(world.chunk_count() <= 30, "chunki sa zwalniane (%d)" % world.chunk_count())
	# mapa odleglosci
	var flow = FlowScript.new(world)
	flow.step(100000, s)
	_check(flow.dist_at(s) == 0, "mapa odleglosci: zero w punkcie gracza")
	var far := s + Vector2(6, 0)
	var nt: Vector2 = flow.next_target(far)
	_check(flow.dist_at(far) > 0 and nt != Vector2.ZERO, "mapa odleglosci prowadzi do gracza")
	# modele
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for kind in ["player", "wind", "chw", "kon", "kom", "npc"]:
		var m: Dictionary = Models.person(kind, rng)
		_check(m["mesh"].get_surface_count() == 1, "model postaci " + kind)
	for bt in 9:
		var c: Dictionary = Models.car(bt, rng)
		_check(c["mesh"].get_surface_count() == 1 and c["length"] > 1.0, "model auta typ %d (%s)" % [bt, c["name"]])
	_check(Models.items().size() == 6, "przedmioty do rzucania")
	print("WYNIK: ", "OK" if ok else "BLAD")
	quit(0 if ok else 1)


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		ok = false
