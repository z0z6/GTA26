extends SceneTree
## Test dymny: wczytuje siatke i sprawdza podstawowe wlasnosci swiata.
## Uruchomienie: godot --headless --path . --script res://tests/smoke.gd

func _initialize() -> void:
	var world: Node2D = load("res://scripts/world.gd").new()
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	world.setup()
	print("setup ms: ", Time.get_ticks_msec() - t0)
	var ok := true
	ok = _check(world.w == 1074 and world.h == 1001, "rozmiar siatki %dx%d" % [world.w, world.h]) and ok
	var counts := {}
	for i in world.w * world.h:
		counts[world.cls[i]] = counts.get(world.cls[i], 0) + 1
	print("klasy: ", counts)
	ok = _check(counts.get(12, 0) == 32702, "liczba kafli budynkow") and ok
	ok = _check(counts.get(7, 0) > 15000, "woda obecna") and ok
	var s: Vector2 = world.find_start(Vector2i(533, 441))
	ok = _check(not world.is_solid_px(s), "start nie jest w scianie") and ok
	ok = _check(world.is_solid_px(Vector2(-5, 10)), "poza mapa jest lita") and ok
	ok = _check(world.speed_at(Vector2(535 * 24 + 5, 439 * 24 + 5)) == 0.5, "strefa konferencji spowalnia") and ok
	world.update_chunks(s)
	ok = _check(world.chunk_count() >= 4, "chunki zbudowane (%d)" % world.chunk_count()) and ok
	# strumieniowanie: po przejsciu przez mape stare chunki sa zwalniane
	var far: Array = [Vector2(300 * 24, 300 * 24), Vector2(900 * 24, 800 * 24), Vector2(100 * 24, 900 * 24)]
	for p in far:
		world.update_chunks(p)
		ok = _check(world.chunk_count() <= 9, "chunki po przeskoku nie rosną (%d)" % world.chunk_count()) and ok
	print("WYNIK: ", "OK" if ok else "BLAD")
	quit(0 if ok else 1)


func _check(cond: bool, label: String) -> bool:
	print(("  ok   " if cond else "  FAIL ") + label)
	return cond
