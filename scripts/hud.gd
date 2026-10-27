extends Control
## Interfejs: dlug, poscig, kondycja, przedmioty, dymki, unoszace sie napisy, ekrany startu i konca,
## oraz przyciski dotykowe (Rzuc, Sprint).

var game
var font: Font = ThemeDB.fallback_font
var btn_throw: Button
var btn_sprint: Button
var btn_night: Button
var sprint_held := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_throw = _mk_button("Rzuć", Vector2(-146, -92), Vector2(130, 72))
	btn_sprint = _mk_button("Sprint", Vector2(-290, -92), Vector2(130, 72))
	btn_night = _mk_button("Noc", Vector2(-146, -170), Vector2(130, 56))
	btn_throw.pressed.connect(func(): game.player_throw())
	btn_sprint.button_down.connect(func(): sprint_held = true)
	btn_sprint.button_up.connect(func(): sprint_held = false)
	btn_night.pressed.connect(func(): game.toggle_night())


func _mk_button(text: String, off: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + sz.x
	b.offset_bottom = off.y + sz.y
	b.modulate = Color(1, 1, 1, 0.82)
	add_child(b)
	return b


func _txt(text: String, p: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0) -> void:
	if outline > 0:
		draw_string_outline(font, p, text, align, -1, fs, outline, Color(0, 0, 0, 0.85))
	draw_string(font, p, text, align, -1, fs, col)


func _rr(r: Rect2, col: Color, rad := 8.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	draw_style_box(sb, r)


func _fmt(n: float) -> String:
	var s := str(int(round(n)))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = " " + out
	return out


func _draw() -> void:
	if game == null:
		return
	var sz := size
	if game.state != "menu" or true:
		_draw_world_overlays()
	if game.state != "menu":
		_draw_hud(sz)
	if game.state != "play":
		_draw_overlay(sz)


func _screen(p: Vector2, y := 0.9) -> Vector2:
	return game.cam.unproject_position(Vector3(p.x, y, p.y))


func _draw_world_overlays() -> void:
	var cam: Camera3D = game.cam
	for e in game.enemies:
		if e.say_t > 0.0 and not cam.is_position_behind(Vector3(e.pos.x, 0, e.pos.y)):
			_bubble(_screen(e.pos, 1.0), e.say)
	for n in game.npcs:
		if n.say_t > 0.0:
			_bubble(_screen(n.pos, 0.9), n.say, true)
	for f in game.floats:
		var sp := _screen(f["pos"], 0.8)
		var a := clampf(f["t"] / 0.4, 0.0, 1.0)
		var col: Color = f["col"]
		col.a = a
		_txt(f["text"], sp + Vector2(0, -f["rise"] * 26.0), 15, col, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _bubble(p: Vector2, text: String, small := false) -> void:
	var fs := 12 if small else 13
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
	var x := clampf(p.x - w / 2.0, 4.0, size.x - w - 4.0)
	var y := p.y - 30.0
	_rr(Rect2(x, y, w, 22), Color(1, 1, 1, 0.96), 7.0)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - 4, y + 21), Vector2(p.x + 4, y + 21), Vector2(p.x, y + 29)]), Color(1, 1, 1, 0.96))
	_txt(text, Vector2(x + 8, y + 16), fs, Color("#1c1c1c"))


func _draw_hud(sz: Vector2) -> void:
	_rr(Rect2(12, 10, 244, 58), Color(0.07, 0.075, 0.085, 0.9))
	_txt("Dług: %s zł" % _fmt(game.debt), Vector2(24, 38), 22, Color("#f2c200"))
	_txt("odsetki +3,2% na minutę", Vector2(24, 58), 12, Color("#d6d6d0"))
	_rr(Rect2(sz.x - 224, 10, 212, 58), Color(0.07, 0.075, 0.085, 0.9))
	_txt("Pościg", Vector2(sz.x - 212, 32), 15, Color.WHITE)
	var near := 0
	for e in game.enemies:
		if e.pos.distance_to(game.player.pos) < 14.0:
			near += 1
	near = mini(near, 5)
	for i in 5:
		var c := Vector2(sz.x - 142 + i * 20, 26)
		if i < near:
			draw_circle(c, 6.0, Color("#e24b4a"))
		else:
			draw_arc(c, 6.0, 0, TAU, 16, Color("#e24b4a"), 1.5)
	var m := int(game.time) / 60
	var s := int(game.time) % 60
	_txt("czas %d:%02d  ·  wierzycieli %d" % [m, s, game.enemies.size()], Vector2(sz.x - 212, 56), 12, Color("#d6d6d0"))
	# kondycja i przedmioty
	_rr(Rect2(12, sz.y - 34, 160, 20), Color(0.07, 0.075, 0.085, 0.8), 5.0)
	var st: float = game.player.stamina
	_rr(Rect2(14, sz.y - 32, maxf(3.0, 156.0 * st), 16), Color("#6fcf6f") if st > 0.25 else Color("#e8a33a"), 4.0)
	_txt("kondycja", Vector2(22, sz.y - 19), 12, Color.WHITE)
	_rr(Rect2(12, sz.y - 62, 250, 24), Color(0.07, 0.075, 0.085, 0.85), 6.0)
	_txt("Rzut: %s  ×%d" % [game.next_item_name(), game.player.ammo], Vector2(22, sz.y - 45), 14, Color("#ffe9a8"))
	if game.banner_t > 0.0 and game.state == "play":
		var w := font.get_string_size(game.banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 30.0
		_rr(Rect2(sz.x / 2.0 - w / 2.0, 78, w, 32), Color(0.07, 0.075, 0.085, 0.9), 7.0)
		_txt(game.banner, Vector2(sz.x / 2.0, 100), 16, Color("#ff8a7a"), HORIZONTAL_ALIGNMENT_CENTER)
	_txt("© autorzy OpenStreetMap", Vector2(sz.x - 14, sz.y - 10), 11, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	if game.joy_active:
		draw_arc(game.joy_origin, 38.0, 0, TAU, 32, Color(1, 1, 1, 0.55), 2.0)
		var v: Vector2 = game.joy_pos - game.joy_origin
		draw_circle(game.joy_origin + v.limit_length(38.0), 15.0, Color(1, 1, 1, 0.5))


func _draw_overlay(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.045, 0.055, 0.72))
	var t1 := ""
	var t2 := ""
	var t3 := ""
	if game.state == "menu":
		t1 = "Uciekaj przed windykatorem"
		t2 = "Maków Mazowiecki: 12 480 zł długu i rosnące odsetki. Zbieraj monety, rzucaj czym popadnie."
		t3 = "Dotknij ekranu, kliknij lub naciśnij Enter"
	elif game.end_msg == "win":
		t1 = "Dług spłacony!"
		t2 = "Czas ucieczki: %d:%02d. Pierwszy raz w historii osiedla." % [int(game.time) / 60, int(game.time) % 60]
		t3 = "Enter lub dotknięcie, żeby zagrać jeszcze raz"
	else:
		t1 = "Komornik zajął wszystko"
		t2 = "Dług przekroczył 25 000 zł po %d:%02d. Spłaciłeś %s zł." % [int(game.time) / 60, int(game.time) % 60, _fmt(game.spent)]
		t3 = "Enter lub dotknięcie, żeby spróbować ponownie"
	_txt(t1, Vector2(sz.x / 2.0, sz.y / 2.0 - 30), 38, Color("#f2c200"), HORIZONTAL_ALIGNMENT_CENTER)
	_txt(t2, Vector2(sz.x / 2.0, sz.y / 2.0 + 8), 17, Color("#ecebe4"), HORIZONTAL_ALIGNMENT_CENTER)
	_txt(t3, Vector2(sz.x / 2.0, sz.y / 2.0 + 46), 15, Color("#bdbbb0"), HORIZONTAL_ALIGNMENT_CENTER)
