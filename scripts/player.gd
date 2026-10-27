extends Node2D
## Gracz: ruch z kolizja o kafle, sprint z kondycja, sterowanie klawiatura i dotykiem.

const SPEED := 136.0
const SPRINT_SPEED := 196.0
const RADIUS := 7.0

var world: Node
var facing := 0.0
var stamina := 1.0
var auto_dir := Vector2.ZERO   # uzywane w tescie automatycznym
var _drag_active := false
var _drag_origin := Vector2.ZERO
var _drag_pos := Vector2.ZERO
var _step := 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed
		if event.pressed:
			_drag_origin = event.position
			_drag_pos = event.position
	elif event is InputEventMouseMotion and _drag_active:
		_drag_pos = event.position


func _read_input() -> Vector2:
	if auto_dir != Vector2.ZERO:
		return auto_dir.normalized()
	var d := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	d.x += float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	d.y += float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	d = d.limit_length(1.0)
	if _drag_active:
		var v := _drag_pos - _drag_origin
		if v.length() > 14.0:
			d = v.normalized()
	return d


func _blocked(p: Vector2) -> bool:
	return (world.is_solid_px(p + Vector2(-RADIUS, -RADIUS)) or world.is_solid_px(p + Vector2(RADIUS, -RADIUS))
		or world.is_solid_px(p + Vector2(-RADIUS, RADIUS)) or world.is_solid_px(p + Vector2(RADIUS, RADIUS)))


func _physics_process(delta: float) -> void:
	var dir := _read_input()
	var moving := dir.length() > 0.05
	var wants_sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	var sprinting := wants_sprint and stamina > 0.02 and moving
	stamina = clampf(stamina + (-0.38 if sprinting else 0.22) * delta, 0.0, 1.0)
	var sp: float = (SPRINT_SPEED if sprinting else SPEED) * float(world.speed_at(position))
	if moving:
		facing = dir.angle()
		_step += delta * sp * 0.06
		var mv := dir * sp * delta
		var nx := position + Vector2(mv.x, 0)
		if not _blocked(nx):
			position = nx
		var ny := position + Vector2(0, mv.y)
		if not _blocked(ny):
			position = ny
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(2, 3), RADIUS + 1.5, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	var sw := sin(_step) * 2.2
	draw_rect(Rect2(-2 + sw, -RADIUS * 0.8, 5, 3), Color("#1b1b1b"))
	draw_rect(Rect2(-2 - sw, RADIUS * 0.8 - 3, 5, 3), Color("#1b1b1b"))
	draw_circle(Vector2.ZERO, RADIUS * 0.92, Color("#2f6fb5"))
	draw_circle(Vector2(RADIUS * 0.25, 0), RADIUS * 0.62, Color("#3b3b3b"))
	draw_circle(Vector2(RADIUS * 0.38, 0), RADIUS * 0.45, Color("#f0c8a0"))
