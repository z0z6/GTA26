extends Node2D
## Scena glowna: tworzy swiat, gracza, kamere i prosty HUD.
## Uruchomienie z argumentem "-- --autotest" wykonuje krotki test ruchu i konczy proces.

const WorldScript := preload("res://scripts/world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const START_TILE := Vector2i(533, 441)   # okolice Rynku

var world: Node2D
var player: Node2D
var cam: Camera2D
var hud: Label
var _frames := 0
var _autotest := false
var _start_pos := Vector2.ZERO


func _ready() -> void:
	world = WorldScript.new()
	add_child(world)
	world.setup()

	player = PlayerScript.new()
	player.world = world
	add_child(player)
	player.position = world.find_start(START_TILE)
	_start_pos = player.position

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = world.w * world.T
	cam.limit_bottom = world.h * world.T
	player.add_child(cam)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_color_override("font_color", Color.WHITE)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(hud)

	_autotest = "--autotest" in OS.get_cmdline_user_args()
	if _autotest:
		player.auto_dir = Vector2(1.0, 0.35)
	world.update_chunks(player.position)


func _process(_delta: float) -> void:
	world.update_chunks(player.position)
	var tile := Vector2i(floori(player.position.x / world.T), floori(player.position.y / world.T))
	hud.text = "FPS %d  kafel %d,%d  chunki %d\n© autorzy OpenStreetMap" % [
		Engine.get_frames_per_second(), tile.x, tile.y, world.chunk_count()]
	_frames += 1
	if _autotest and _frames >= 240:
		var moved := player.position.distance_to(_start_pos)
		var inside: bool = world.is_solid_px(player.position)
		print("AUTOTEST pozycja=", player.position, " przesuniecie=", snappedf(moved, 0.1),
			" w_scianie=", inside, " chunki=", world.chunk_count())
		get_tree().quit(1 if inside or moved < 50.0 else 0)
