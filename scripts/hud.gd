extends Control
## Interfejs w stylu GTA 2: paski z ikonami (lewy gorny rog), kwota dlugu i slot przedmiotu (prawy gorny),
## glowy poscigu (gora, srodek), zolty baner z nazwa dzielnicy, dymek z czaszka na dole (komunikaty),
## dymki postaci, unoszace sie napisy, ekrany startu i konca oraz przyciski dotykowe.
## Cala grafika to wektory rysowane w kodzie (bez plikow obrazkow), czcionki: Anton i Oswald (SIL OFL, katalog fonts/).

const FONT_DISPLAY: Font = preload("res://fonts/Anton-Regular.ttf")
const FONT_UI_FILE: Font = preload("res://fonts/Oswald-Variable.ttf")

const C_FRAME := Color(0.04, 0.07, 0.16, 0.88)
const C_FRAME_EDGE := Color(0.55, 0.66, 0.86, 0.9)
const C_MONEY := Color("#f6a623")
const C_MONEY_HI := Color("#ffe08a")
const C_BANNER := Color("#e5c52c")
const C_BANNER_DARK := Color("#2a2810")
const C_DIALOG := Color("#e2e65c")
const C_RED := Color("#e24b4a")
const C_GREEN := Color("#58d058")
const C_BLACK := Color(0, 0, 0, 0.9)
const DEBT_MAX := 25000.0

var game
var font: Font                      # czcionka UI (Oswald, polgrube) do malych napisow i dymkow
var btn_throw: Button
var btn_sprint: Button
var btn_night: Button
var sprint_held := false

var _last_ms := 0
var _disp := {"st": 1.0, "debt": 0.5, "thr": 0.0}   # wygladzone wartosci pasków


func _ready() -> void:
	var fv := FontVariation.new()
	fv.base_font = FONT_UI_FILE
	fv.variation_opentype = {0x77676874: 600}      # 'wght' = polgrube
	font = fv
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_throw = _mk_button("RZUĆ", Vector2(-146, -92), Vector2(130, 72))
	btn_sprint = _mk_button("SPRINT", Vector2(-290, -92), Vector2(130, 72))
	btn_night = _mk_button("NOC", Vector2(-146, -170), Vector2(130, 56))
	btn_throw.pressed.connect(func(): game.player_throw())
	btn_sprint.button_down.connect(func(): sprint_held = true)
	btn_sprint.button_up.connect(func(): sprint_held = false)
	btn_night.pressed.connect(func(): game.toggle_night())


func _mk_button(text: String, off: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT_DISPLAY)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("#f0d060"))
	b.add_theme_color_override("font_hover_color", Color("#fff2b0"))
	b.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.04, 0.07, 0.16, 0.72)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.08, 0.12, 0.26, 0.8)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.35, 0.28, 0.05, 0.85)))
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + sz.x
	b.offset_bottom = off.y + sz.y
	add_child(b)
	return b


func _btn_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color("#c9a227")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	return sb


# ------------------------------------------------------------------ rysowanie tekstu
## Tekst z konturem i poprawnym wyrownaniem (align dziala wzgledem x; draw_string z width=-1 nie wyrownuje).
func _txt(text: String, p: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, f: Font = null) -> void:
	var ft: Font = f if f != null else font
	var x := p.x
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var w := ft.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x -= w * (0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 1.0)
	var q := Vector2(x, p.y)
	if outline > 0:
		draw_string_outline(ft, q, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, C_BLACK)
	draw_string(ft, q, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _txt_w(text: String, fs: int, f: Font = null) -> float:
	var ft: Font = f if f != null else font
	return ft.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


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


# ------------------------------------------------------------------ elementy graficzne
func _poly_o(pts: PackedVector2Array, fill: Color, ow := 3.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, C_BLACK, ow, true)
	draw_colored_polygon(pts, fill)


func _circle_o(c: Vector2, r: float, fill: Color, ow := 1.5) -> void:
	draw_circle(c, r + ow, C_BLACK)
	draw_circle(c, r, fill)


func _rect_o(r: Rect2, fill: Color, ow := 1.5) -> void:
	draw_rect(r.grow(ow), C_BLACK)
	draw_rect(r, fill)


## Pasek jak w GTA 2: ciemnoniebieska rama, wypelnienie z jasna gorna i ciemna dolna krawedzia.
func _bar(p: Vector2, w: float, h: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(w + 4, h + 4)), C_BLACK)
	draw_rect(Rect2(p - Vector2(1, 1), Vector2(w + 2, h + 2)), C_FRAME_EDGE.darkened(0.35))
	draw_rect(Rect2(p, Vector2(w, h)), C_FRAME)
	var fw := w * clampf(frac, 0.0, 1.0)
	if fw >= 1.0:
		draw_rect(Rect2(p, Vector2(fw, h)), col)
		draw_rect(Rect2(p, Vector2(fw, maxf(1.0, h * 0.38))), col.lightened(0.4))
		draw_rect(Rect2(p + Vector2(0, h * 0.75), Vector2(fw, maxf(1.0, h * 0.25))), col.darkened(0.35))
	for i in range(1, 10):                                       # kreski podzialki
		draw_line(p + Vector2(w * i / 10.0, h * 0.62), p + Vector2(w * i / 10.0, h), Color(0, 0, 0, 0.35), 1.0)


func _icon_bolt(c: Vector2, s: float, col: Color) -> void:
	var k := s * 0.5
	var pts := PackedVector2Array([Vector2(0.22, -1.0), Vector2(-0.58, 0.10), Vector2(-0.06, 0.10),
		Vector2(-0.26, 1.0), Vector2(0.62, -0.22), Vector2(0.06, -0.22)])
	for i in pts.size():
		pts[i] = c + pts[i] * k
	_poly_o(pts, col, 3.0)


func _icon_coin(c: Vector2, s: float) -> void:
	var r := s * 0.46
	_circle_o(c, r, Color("#f2c200"), 1.6)
	draw_arc(c, r * 0.68, 0.0, TAU, 20, Color("#b88a00"), 1.6)
	draw_arc(c, r * 0.9, 3.6, 5.2, 8, Color("#fff0a0"), 1.5)
	draw_line(c + Vector2(0, -r * 0.35), c + Vector2(0, r * 0.35), Color("#8a6400"), 2.0)


## Glowa windykatora: twarz, czapka z daszkiem, ciemne okulary.
func _icon_head(c: Vector2, s: float, skin: Color, hat: Color) -> void:
	var r := s * 0.36
	_circle_o(c + Vector2(0, s * 0.06), r, skin, 1.5)
	_poly_o(PackedVector2Array([c + Vector2(-r * 1.05, -s * 0.06), c + Vector2(-r * 0.8, -s * 0.42),
		c + Vector2(r * 0.8, -s * 0.42), c + Vector2(r * 1.05, -s * 0.06)]), hat, 2.5)
	draw_rect(Rect2(c + Vector2(-r * 0.85, -s * 0.02), Vector2(r * 1.7, s * 0.13)), Color(0.05, 0.05, 0.06))


func _icon_skull(c: Vector2, s: float) -> void:
	var bone := Color("#ece8d8")
	_circle_o(c + Vector2(0, -s * 0.08), s * 0.4, bone, 2.0)
	_rect_o(Rect2(c + Vector2(-s * 0.22, s * 0.2), Vector2(s * 0.44, s * 0.24)), bone, 2.0)
	for sx in [-1.0, 1.0]:
		draw_circle(c + Vector2(sx * s * 0.16, -s * 0.08), s * 0.115, Color(0.04, 0.04, 0.05))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.05), c + Vector2(-s * 0.05, s * 0.15), c + Vector2(s * 0.05, s * 0.15)]), Color(0.05, 0.05, 0.06))
	for i in range(-1, 2):
		draw_line(c + Vector2(i * s * 0.1, s * 0.22), c + Vector2(i * s * 0.1, s * 0.44), Color(0.2, 0.2, 0.2), 1.2)


## Ikona przedmiotu do rzucania (nazwy z Models.items()). s = rozmiar w px.
func _icon_item(item_name: String, c: Vector2, s: float) -> void:
	draw_set_transform(c, -0.5, Vector2.ONE)
	var k := s * 0.5
	match item_name:
		"Kamień":
			var pts := PackedVector2Array()
			for i in 9:
				var a := TAU * i / 9.0
				pts.append(Vector2(cos(a) * k * (0.85 + 0.12 * sin(i * 2.3)), sin(a) * k * (0.7 + 0.1 * cos(i * 1.7))))
			_poly_o(pts, Color("#8c8e92"), 2.5)
			draw_circle(Vector2(-k * 0.25, -k * 0.2), k * 0.18, Color("#b8babe"))
		"Puszka":
			_rect_o(Rect2(-k * 0.5, -k * 0.85, k, k * 1.7), Color("#cfd3d8"), 2.0)
			draw_rect(Rect2(-k * 0.5, -k * 0.3, k, k * 0.6), Color("#c0392b"))
			draw_rect(Rect2(-k * 0.5, -k * 0.85, k, k * 0.2), Color("#9aa0a8"))
			draw_rect(Rect2(-k * 0.5, k * 0.65, k, k * 0.2), Color("#9aa0a8"))
		"Butelka":
			_rect_o(Rect2(-k * 0.4, -k * 0.1, k * 0.8, k * 1.0), Color("#4aa05a"), 2.0)
			_rect_o(Rect2(-k * 0.16, -k * 0.85, k * 0.32, k * 0.8), Color("#4aa05a"), 2.0)
			draw_rect(Rect2(-k * 0.2, -k * 0.95, k * 0.4, k * 0.16), Color("#d8c070"))
			draw_rect(Rect2(-k * 0.26, k * 0.0, k * 0.1, k * 0.7), Color("#9be0a8"))
		"Bułka":
			var pts2 := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				pts2.append(Vector2(cos(a) * k * 0.95, sin(a) * k * 0.62))
			_poly_o(pts2, Color("#d9a860"), 2.5)
			for sx in [-0.4, 0.0, 0.4]:
				draw_line(Vector2(k * sx - k * 0.12, -k * 0.3), Vector2(k * sx + k * 0.12, k * 0.3), Color("#a8743a"), 2.0)
		"Kapeć":
			var pts3 := PackedVector2Array()
			for i in 14:
				var a := TAU * i / 14.0
				pts3.append(Vector2(cos(a) * k * 0.55, sin(a) * k * 0.95))
			_poly_o(pts3, Color("#9a6a4a"), 2.5)
			draw_circle(Vector2(0, -k * 0.35), k * 0.3, Color("#3b2a1e"))
		"Pilot":
			_rect_o(Rect2(-k * 0.38, -k * 0.95, k * 0.76, k * 1.9), Color("#2a2c30"), 2.0)
			draw_circle(Vector2(0, -k * 0.6), k * 0.14, C_RED)
			draw_circle(Vector2(-k * 0.16, -k * 0.2), k * 0.1, Color("#58d058"))
			draw_circle(Vector2(k * 0.16, -k * 0.2), k * 0.1, Color("#5aa0ff"))
			draw_circle(Vector2(-k * 0.16, k * 0.2), k * 0.1, Color("#e8e060"))
			draw_circle(Vector2(k * 0.16, k * 0.2), k * 0.1, Color("#d0d0d0"))
		"Petarda":
			_rect_o(Rect2(-k * 0.4, -k * 0.6, k * 0.8, k * 1.5), Color("#d23a2e"), 2.0)
			draw_rect(Rect2(-k * 0.4, -k * 0.2, k * 0.8, k * 0.2), Color("#f0e6c0"))
			draw_line(Vector2(0, -k * 0.6), Vector2(k * 0.15, -k * 0.95), Color("#e8d9a8"), 2.0)
			draw_circle(Vector2(k * 0.2, -k * 1.0), k * 0.2, Color("#ffd040"))
			draw_circle(Vector2(k * 0.2, -k * 1.0), k * 0.1, Color.WHITE)
		_:
			_circle_o(Vector2.ZERO, k * 0.7, Color("#cccccc"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Zolty, "postrzepiony" baner (jak z nazwa dzielnicy w GTA 2): nierowne krawedzie, plamki, ciemne paski.
func _grunge_banner(r: Rect2, alpha := 1.0) -> void:
	var seg := 14
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in seg + 1:
		var x := r.position.x + r.size.x * i / float(seg)
		var j1 := sin(i * 12.9898) * 43758.5453
		var j2 := sin(i * 78.233 + 3.1) * 12345.678
		top.append(Vector2(x, r.position.y + (j1 - floorf(j1)) * 3.0))
		bot.append(Vector2(x, r.end.y - (j2 - floorf(j2)) * 3.0))
	var pts := PackedVector2Array()
	pts.append_array(top)
	bot.reverse()
	pts.append_array(bot)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(3, 3))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45 * alpha))
	var col := C_BANNER
	col.a = alpha
	draw_colored_polygon(pts, col)
	# plamki i zacieki
	for i in int(r.size.x / 7.0):
		var h1 := sin(i * 91.17 + 1.3) * 9301.0
		var h2 := sin(i * 47.31 + 7.7) * 4973.0
		var h3 := sin(i * 13.71 + 2.2) * 6677.0
		var fx := h1 - floorf(h1)
		var fy := h2 - floorf(h2)
		var fs := h3 - floorf(h3)
		draw_rect(Rect2(r.position.x + fx * r.size.x, r.position.y + 3 + fy * (r.size.y - 8), 1.0 + fs * 3.0, 1.0 + fs * 1.5),
			Color(0.45, 0.36, 0.05, 0.28 * alpha))
	draw_line(Vector2(r.position.x + 3, r.position.y + 3), Vector2(r.end.x - 3, r.position.y + 3), Color(0.3, 0.24, 0.02, 0.5 * alpha), 1.5)
	draw_line(Vector2(r.position.x + 3, r.end.y - 3), Vector2(r.end.x - 3, r.end.y - 3), Color(0.3, 0.24, 0.02, 0.5 * alpha), 1.5)


# ------------------------------------------------------------------ glowna petla rysowania
func _draw() -> void:
	if game == null:
		return
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	var sz := size
	_draw_world_overlays()
	if game.state != "menu":
		_draw_hud(sz, dt)
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
		_txt(f["text"], sp + Vector2(0, -f["rise"] * 26.0), 17, col, HORIZONTAL_ALIGNMENT_CENTER, 5, FONT_DISPLAY)


func _bubble(p: Vector2, text: String, small := false) -> void:
	var fs := 13 if small else 14
	var w := _txt_w(text, fs) + 16.0
	var x := clampf(p.x - w / 2.0, 4.0, size.x - w - 4.0)
	var y := p.y - 30.0
	_rr(Rect2(x - 1.5, y - 1.5, w + 3.0, 25.0), Color(0, 0, 0, 0.9), 7.0)
	_rr(Rect2(x, y, w, 22), Color(1, 1, 1, 0.96), 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - 4, y + 21), Vector2(p.x + 4, y + 21), Vector2(p.x, y + 29)]), Color(1, 1, 1, 0.96))
	_txt(text, Vector2(x + 8, y + 17), fs, Color("#1c1c1c"))


func _approach(key: String, target: float, dt: float, speed := 5.0) -> float:
	_disp[key] = lerpf(_disp[key], target, minf(1.0, dt * speed))
	return _disp[key]


func _draw_hud(sz: Vector2, dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pl = game.player
	# ---- lewy gorny rog: trzy paski z ikonami ----
	var near := 0
	var threat := 0.0
	for e in game.enemies:
		var d: float = e.pos.distance_to(pl.pos)
		if d < 14.0:
			near += 1
		threat += clampf(1.0 - d / 16.0, 0.0, 1.0)
	near = mini(near, 5)
	threat = clampf(threat, 0.0, 1.0)
	var st := _approach("st", pl.stamina, dt)
	var dbt := _approach("debt", clampf(game.debt / DEBT_MAX, 0.0, 1.0), dt, 3.0)
	var thr := _approach("thr", threat, dt, 3.0)

	var bx := 50.0
	var bw := 150.0
	var bh := 13.0
	var y0 := 20.0
	var gap := 29.0
	# kondycja
	var st_col := C_GREEN if st > 0.25 else Color("#e8a33a")
	if st < 0.25 and int(t * 5.0) % 2 == 0:
		st_col = C_RED
	_icon_bolt(Vector2(28, y0 + bh * 0.5), 22.0, Color("#f6e040"))
	_bar(Vector2(bx, y0), bw, bh, st, st_col)
	_txt("KONDYCJA", Vector2(bx + bw + 10, y0 + 11), 13, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT, 3)
	# dlug (zapelnia sie w strone limitu 25 000 zl)
	var dc := Color("#f2c200").lerp(C_RED, smoothstep(0.45, 0.85, dbt))
	if dbt > 0.88 and int(t * 6.0) % 2 == 0:
		dc = Color("#ffffff")
	_icon_coin(Vector2(28, y0 + gap + bh * 0.5), 22.0)
	_bar(Vector2(bx, y0 + gap), bw, bh, dbt, dc)
	_txt("DŁUG", Vector2(bx + bw + 10, y0 + gap + 11), 13, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT, 3)
	# zagrozenie (bliskosc windykatorow)
	var tc := Color("#6a7bff").lerp(C_RED, smoothstep(0.2, 0.8, thr))
	_icon_head(Vector2(28, y0 + gap * 2.0 + bh * 0.5), 24.0, Color("#e8b890"), Color("#3a3d44"))
	_bar(Vector2(bx, y0 + gap * 2.0), bw, bh, thr, tc)
	_txt("ZAGROŻENIE", Vector2(bx + bw + 10, y0 + gap * 2.0 + 11), 13, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT, 3)

	# ---- gora, srodek: glowy poscigu ----
	var hx := sz.x * 0.5 - 2.0 * 26.0
	var flash := int(t * 4.0) % 2 == 0
	for i in 5:
		var c := Vector2(hx + i * 26.0, 24.0)
		if i < near:
			_icon_head(c, 26.0, Color("#e8b890"), C_RED if flash else Color("#ff9a8a"))
		else:
			draw_set_transform(c, 0.0, Vector2.ONE)
			draw_circle(Vector2.ZERO, 8.0, Color(0.05, 0.07, 0.15, 0.55))
			draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 20, Color(C_FRAME_EDGE, 0.6), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ---- prawy gorny rog: kwota, odsetki, czas, slot przedmiotu ----
	var right := sz.x - 18.0
	var money := "%s zł" % _fmt(game.debt)
	_txt(money, Vector2(right, 47), 38, C_MONEY, HORIZONTAL_ALIGNMENT_RIGHT, 7, FONT_DISPLAY)
	_txt(money, Vector2(right, 45), 38, C_MONEY_HI, HORIZONTAL_ALIGNMENT_RIGHT, 0, FONT_DISPLAY)   # jasna gorna krawedz
	_txt(money, Vector2(right, 47), 38, C_MONEY, HORIZONTAL_ALIGNMENT_RIGHT, 0, FONT_DISPLAY)
	var m := int(game.time) / 60
	var s := int(game.time) % 60
	_txt("ODSETKI +3,2%%/MIN  ·  CZAS %d:%02d" % [m, s], Vector2(right, 68), 13, Color(1, 1, 1, 0.92), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	# slot przedmiotu: ikona + ilosc pod nia (jak bron i amunicja w GTA 2)
	var item_name: String = game.next_item_name()
	var ic := Vector2(right - 20.0, 106.0)
	_icon_item(item_name, ic, 38.0)
	var ammo_col := Color("#ffffff") if pl.ammo > 0 else C_RED
	_txt(str(pl.ammo), Vector2(ic.x, 145), 24, ammo_col, HORIZONTAL_ALIGNMENT_CENTER, 5, FONT_DISPLAY)
	_txt("RZUT: " + item_name.to_upper(), Vector2(ic.x - 32.0, 111), 14, Color("#ffe9a8"), HORIZONTAL_ALIGNMENT_RIGHT, 3)

	# ---- baner dzielnicy (zolty) ----
	if game.district != "" and game.district_t > 0.0:
		var age: float = game.DISTRICT_SHOW - game.district_t
		var slide := 1.0 - smoothstep(0.0, 0.25, age)                  # wjazd z gory
		var out := smoothstep(0.0, 0.35, game.district_t)               # zanikanie na koncu
		var name_up: String = game.district.to_upper()
		var w := _txt_w(name_up, 26, FONT_DISPLAY) + 64.0
		var r := Rect2(sz.x * 0.5 - w * 0.5, 48.0 - slide * 60.0, w, 36.0)
		_grunge_banner(r, out)
		var tc2 := C_BANNER_DARK
		tc2.a = out
		_txt(name_up, Vector2(sz.x * 0.5, r.position.y + 28.0), 26, tc2, HORIZONTAL_ALIGNMENT_CENTER, 0, FONT_DISPLAY)

	# ---- komunikaty: dymek z czaszka u dolu po lewej ----
	if game.banner_t > 0.0 and game.state == "play":
		var a := clampf(game.banner_t / 0.5, 0.0, 1.0)
		var by := sz.y - 78.0
		_icon_skull(Vector2(38, by + 18), 46.0)
		var tcol := C_DIALOG
		tcol.a = a
		var wrap := minf(sz.x - 360.0, 560.0)
		draw_multiline_string_outline(font, Vector2(72, by + 12), game.banner, HORIZONTAL_ALIGNMENT_LEFT, wrap, 22, 2, 6, Color(0, 0, 0, 0.9 * a))
		draw_multiline_string(font, Vector2(72, by + 12), game.banner, HORIZONTAL_ALIGNMENT_LEFT, wrap, 22, 2, tcol)

	_txt("© autorzy OpenStreetMap", Vector2(sz.x - 14, sz.y - 10), 11, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	if game.joy_active:
		draw_arc(game.joy_origin, 38.0, 0, TAU, 32, Color(1, 1, 1, 0.55), 2.0)
		var v: Vector2 = game.joy_pos - game.joy_origin
		draw_circle(game.joy_origin + v.limit_length(38.0), 15.0, Color(1, 1, 1, 0.5))


func _draw_overlay(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.035, 0.07, 0.74))
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
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5
	var title := t1.to_upper()
	var tw := minf(_txt_w(title, 54, FONT_DISPLAY) + 90.0, sz.x - 20.0)
	_grunge_banner(Rect2(cx - tw * 0.5, cy - 92.0, tw, 74.0))
	_txt(title, Vector2(cx, cy - 36.0), 54, C_BANNER_DARK, HORIZONTAL_ALIGNMENT_CENTER, 0, FONT_DISPLAY)
	_txt(t2, Vector2(cx, cy + 20.0), 19, Color("#f4f2e6"), HORIZONTAL_ALIGNMENT_CENTER, 5)
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 260.0)
	_txt(t3.to_upper(), Vector2(cx, cy + 62.0), 17, Color(C_DIALOG, pulse), HORIZONTAL_ALIGNMENT_CENTER, 5)
