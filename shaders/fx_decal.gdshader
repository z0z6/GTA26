shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
#include "res://shaders/common.gdshaderinc"

// Ślady na ziemi: opony (kind 0) i przypalenia po wybuchu (kind 1).
// INSTANCE_CUSTOM = (czas powstania, czas zaniku w s, rodzaj, -). Zanikają same (g_fxtime ustawia effects.gd).
global uniform float g_fxtime;
varying vec4 v_c;
varying vec3 v_w;

void vertex() {
	v_c = INSTANCE_CUSTOM;
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float age = g_fxtime - v_c.x;
	float fade = 1.0 - smoothstep(v_c.y * 0.45, v_c.y, age);
	float a;
	if (v_c.z < 0.5) {
		float across = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
		float rub = 0.72 + 0.28 * vnoise(v_w.xz * 30.0);
		a = across * rub * 0.55;
	} else {
		vec2 q = UV * 2.0 - 1.0;
		float r = length(q);
		float n = fbm(q * 2.2 + v_c.x);
		a = smoothstep(1.0, 0.2, r + (n - 0.5) * 0.55) * 0.78;
	}
	ALBEDO = vec3(0.02);
	ALPHA = a * fade * COLOR.a;
}
