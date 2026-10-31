shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
#include "res://shaders/common.gdshaderinc"

// Dym i kurz: miękka, zaszumiona plama. W nocy oświetlana przez mapę świateł
// (więc dym obok wybuchu świeci pomarańczowo, a obok reflektora jest jasny).
varying vec3 v_w;
varying vec4 v_c;

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_c = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float n = fbm(q * 1.7 + vec2(v_c.x * 17.0, v_c.x * 5.0) + v_c.y * 0.8);
	float shape = smoothstep(1.0, 0.25, r + (n - 0.5) * 0.7);
	vec3 col = COLOR.rgb * (0.70 + 0.50 * n);
	col = apply_night_obj(col, v_w.xz);
	ALBEDO = col;
	ALPHA = shape * COLOR.a;
}
