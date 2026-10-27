extends Node3D
## Osadza model czlowieka z animowanymi konczynami (animacja w vertex shaderze).

const OBJECT_SHADER: Shader = preload("res://shaders/object.gdshader")

var mat: ShaderMaterial
var mesh_i: MeshInstance3D
var phase := 0.0
var gait := 0.0
var yaw := 0.0
var base_scale := 1.0
var _flash := 0.0
var _last_swing := -1.0


func setup(mesh: Mesh, sc: float, tint: Color = Color.WHITE) -> void:
	base_scale = sc
	mesh_i = MeshInstance3D.new()
	mesh_i.mesh = mesh
	mat = ShaderMaterial.new()
	mat.shader = OBJECT_SHADER
	mat.set_shader_parameter("tint", tint)
	mesh_i.material_override = mat
	add_child(mesh_i)
	scale = Vector3.ONE * sc * 1.25


## speed: aktualna predkosc w kaflach/s.
func animate(speed: float, delta: float) -> void:
	gait = lerpf(gait, clampf(speed / 3.2, 0.0, 1.0), minf(1.0, 12.0 * delta))
	phase += delta * (3.0 + speed * 1.9)
	mat.set_shader_parameter("phase", phase)
	var sw := snappedf(0.95 * gait, 0.02)
	if sw != _last_swing:
		mat.set_shader_parameter("swing", sw)
		mat.set_shader_parameter("bob", 0.02 * gait)
		_last_swing = sw
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		mat.set_shader_parameter("flash", _flash)


func flash() -> void:
	_flash = 1.0


func face(dir: Vector2, delta: float, rate := 14.0) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target := atan2(-dir.x, -dir.y)
	yaw = lerp_angle(yaw, target, minf(1.0, rate * delta))
	rotation.y = yaw
