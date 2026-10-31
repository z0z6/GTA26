extends Node
## Mapa swiatel. Maly SubViewport 2D, do ktorego co klatke rysujemy kolorowe swiatla addytywnie:
## punktowe (latarnie, gracz, blyski) i stozki (reflektory aut). Shadery terenu, budynkow i obiektow
## probkuja te mape przez globalne g_lightmap i g_lm_origin (common.gdshaderinc), wiec:
##   - liczba swiatel nie zalezy od liczby uniformow,
##   - swiatla maja kolor i ksztalt (stozek reflektora),
##   - dodanie nowego zrodla swiatla to jedno wywolanie point() albo cone().
## Mapa jest LDR (8 bit), wiec zapisujemy 0.5 * jasnosc, a shadery mnoza odczyt x2.
##
## Uzycie co klatke:  begin(srodek) -> point()/cone()... -> end()

const SIZE_TILES := 64.0   # musi byc rowne LM_SIZE w shaders/common.gdshaderinc
const PPT := 8             # pikseli mapy na kafel
const MAX_POINTS := 72
const MAX_CONES := 28
const TEX_POINT := 128
const TEX_CONE_W := 128
const TEX_CONE_H := 64

var origin := Vector2.ZERO          # lewy gorny rog mapy w kaflach swiata
var vp: SubViewport
var _root: Node2D
var _points: Array[Sprite2D] = []
var _cones: Array[Sprite2D] = []
var _np := 0
var _nc := 0
var _flashes: Array = []
var _active := false


func _ready() -> void:
	var px := int(SIZE_TILES) * PPT
	vp = SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)

	_root = Node2D.new()
	vp.add_child(_root)
	var bg := ColorRect.new()                      # czarne tlo (inaczej bralby sie domyslny kolor czyszczenia)
	bg.color = Color.BLACK
	bg.size = Vector2(px, px)
	_root.add_child(bg)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tp := _make_point_texture()
	var tc := _make_cone_texture()
	for i in MAX_POINTS:
		var s := Sprite2D.new()
		s.texture = tp
		s.material = add_mat
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.visible = false
		_root.add_child(s)
		_points.append(s)
	for i in MAX_CONES:
		var s := Sprite2D.new()
		s.texture = tc
		s.material = add_mat
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.centered = false
		s.offset = Vector2(0.0, -TEX_CONE_H * 0.5)   # poczatek stozka = srodek lewej krawedzi
		s.visible = false
		_root.add_child(s)
		_cones.append(s)

	RenderingServer.global_shader_parameter_set("g_lightmap", vp.get_texture())
	RenderingServer.global_shader_parameter_set("g_lm_origin", origin)


## Wlacza/wylacza renderowanie mapy (w dzien nie jest potrzebna).
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func begin(center: Vector2) -> void:
	var half := SIZE_TILES * 0.5
	# przyciaganie do siatki pikseli mapy: swiatla nie "plyna" wzgledem swiata przy ruchu kamery
	origin = ((center - Vector2(half, half)) * PPT).round() / float(PPT)
	RenderingServer.global_shader_parameter_set("g_lm_origin", origin)
	_np = 0
	_nc = 0


## Swiatlo punktowe. p w kaflach swiata, radius w kaflach, intensity ok. 0..1.5.
func point(p: Vector2, radius: float, col: Color, intensity := 1.0) -> void:
	if _np >= MAX_POINTS:
		return
	var q := p - origin
	if q.x < -radius or q.y < -radius or q.x > SIZE_TILES + radius or q.y > SIZE_TILES + radius:
		return
	var s := _points[_np]
	_np += 1
	s.visible = true
	s.position = q * PPT
	var sc := radius * 2.0 * PPT / float(TEX_POINT)
	s.scale = Vector2(sc, sc)
	s.modulate = Color(col.r * intensity * 0.5, col.g * intensity * 0.5, col.b * intensity * 0.5, 1.0)


## Stozek swiatla (reflektor). p = punkt startu, dir = kierunek (znormalizowany),
## length = zasieg, half_width = polowa szerokosci stozka na jego koncu (w kaflach).
func cone(p: Vector2, dir: Vector2, length: float, half_width: float, col: Color, intensity := 1.0) -> void:
	if _nc >= MAX_CONES:
		return
	var q := p - origin
	if q.x < -length or q.y < -length or q.x > SIZE_TILES + length or q.y > SIZE_TILES + length:
		return
	var s := _cones[_nc]
	_nc += 1
	s.visible = true
	s.position = q * PPT
	s.rotation = dir.angle()
	s.scale = Vector2(length * PPT / float(TEX_CONE_W), half_width * 2.0 * PPT / float(TEX_CONE_H))
	s.modulate = Color(col.r * intensity * 0.5, col.g * intensity * 0.5, col.b * intensity * 0.5, 1.0)


## Krotki blysk (trafienie, uderzenie). Gasnie sam po dur sekundach.
func flash(p: Vector2, col: Color, radius := 3.0, dur := 0.3) -> void:
	_flashes.append({"p": p, "col": col, "r": radius, "dur": dur, "t0": Time.get_ticks_msec()})
	if _flashes.size() > 16:
		_flashes.pop_front()


func end() -> void:
	var now := Time.get_ticks_msec()
	for i in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		var age: float = (now - int(f["t0"])) / 1000.0
		if age >= f["dur"]:
			_flashes.remove_at(i)
			continue
		var k: float = 1.0 - age / float(f["dur"])
		point(f["p"], float(f["r"]) * (1.15 - 0.3 * k), f["col"], 1.4 * k * k)
	for i in range(_np, _points.size()):
		_points[i].visible = false
	for i in range(_nc, _cones.size()):
		_cones[i].visible = false


# --- tekstury generowane w kodzie ---
func _make_point_texture() -> ImageTexture:
	var img := Image.create(TEX_POINT, TEX_POINT, false, Image.FORMAT_RGBA8)
	var c := (TEX_POINT - 1) * 0.5
	for y in TEX_POINT:
		for x in TEX_POINT:
			var r := Vector2(x - c, y - c).length() / (TEX_POINT * 0.5)
			var k := clampf(1.0 - r, 0.0, 1.0)
			k *= k                                   # taki sam spadek jak dawne la(): (1 - d/r)^2
			img.set_pixel(x, y, Color(k, k, k, 1.0))
	return ImageTexture.create_from_image(img)


func _make_cone_texture() -> ImageTexture:
	var img := Image.create(TEX_CONE_W, TEX_CONE_H, false, Image.FORMAT_RGBA8)
	for y in TEX_CONE_H:
		for x in TEX_CONE_W:
			var u := (x + 0.5) / TEX_CONE_W                    # 0 przy aucie .. 1 na koncu zasiegu
			var v := ((y + 0.5) / TEX_CONE_H - 0.5) * 2.0      # -1..1 w poprzek
			var hw := lerpf(0.16, 1.0, pow(u, 0.85))           # stozek rozszerza sie z odlegloscia
			var side := 1.0 - smoothstep(0.35, 1.0, absf(v) / hw)
			var along := pow(1.0 - u, 1.35) * smoothstep(0.0, 0.05, u + 0.03)
			var k := clampf(side * along, 0.0, 1.0)
			img.set_pixel(x, y, Color(k, k, k, 1.0))
	return ImageTexture.create_from_image(img)
