extends CanvasLayer
## Post-processing: bloom (shaders/bloom.gdshader). Dziala tylko wieczorem i w nocy, w dzien jest wylaczony.
## Na slabszych telefonach mozna calkiem wylaczyc: ENABLED = false.

const ENABLED := true
const BLOOM_STRENGTH := 0.6

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 0                       # pod interfejsem (HUD siedzi w CanvasLayer 1)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/bloom.gdshader")
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)


## night: 0 dzien, ~0.5 zmierzch, 1 noc (jak g_night).
func set_night(night: float) -> void:
	var k := smoothstep(0.15, 0.8, night)
	_rect.visible = ENABLED and k > 0.01
	if not _rect.visible:
		return
	_mat.set_shader_parameter("strength", BLOOM_STRENGTH * k)
	# o zmierzchu tlo jest jasniejsze, wiec prog wyzszy; w nocy nizszy
	_mat.set_shader_parameter("threshold", lerpf(0.55, 0.30, smoothstep(0.5, 1.0, night)))
