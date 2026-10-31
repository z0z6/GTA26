shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
#include "res://shaders/common.gdshaderinc"

// Cząsteczki świecące (addytywne): ogień, iskry, żar, błysk i fala uderzeniowa.
// Dane per instancja: COLOR = kolor i jasność, INSTANCE_CUSTOM = (ziarno, wiek 0..1, kształt, -)
// Kształt: 0 miękka plama (ogień), 1 pierścień (fala uderzeniowa), 2 iskra (rozciągnięta wzdłuż prędkości).
varying vec4 v_c;

void vertex() {
	v_c = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a;
	if (v_c.z < 0.5) {
		float n = fbm(q * 2.0 + vec2(v_c.x * 11.0, v_c.x * 3.0) + v_c.y * 1.5);
		a = pow(clamp(1.0 - r, 0.0, 1.0), 1.3) * (0.65 + 0.7 * n);
	} else if (v_c.z < 1.5) {
		float ring = abs(r - 0.82);
		a = clamp(1.0 - ring / 0.16, 0.0, 1.0);
		a *= a;
	} else {
		a = clamp(1.0 - r, 0.0, 1.0);
		a *= a;
	}
	ALBEDO = COLOR.rgb * a * COLOR.a;
	ALPHA = 1.0;
}
