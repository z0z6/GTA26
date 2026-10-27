shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;
#include "res://shaders/common.gdshaderinc"

// Obiekty z kolorami wierzcholkow: postacie (animacja konczyn), pojazdy, drzewa, przedmioty.
// UV.x = id konczyny: 0 korpus, 1 noga L, 2 noga P, 3 reka L, 4 reka P.
// COLOR.a < 0.75 oznacza powierzchnie swiecaca w nocy (reflektory, lampy).
uniform float phase = 0.0;
uniform float swing = 0.0;
uniform float bob = 0.0;
uniform float flash = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade_r = 0.0;          // przezroczystosc koron drzew przy graczu
uniform vec3 fade_pos = vec3(0.0);
varying vec3 v_nrm;
varying vec3 v_w;
varying vec4 v_col;

void vertex() {
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float limb = UV.x;
	if (limb > 0.5) {
		float s = sin(phase) * swing;
		float sgn = 1.0;
		float py = 0.30;
		if (limb < 1.5) { sgn = 1.0; py = 0.30; }
		else if (limb < 2.5) { sgn = -1.0; py = 0.30; }
		else if (limb < 3.5) { sgn = -0.8; py = 0.50; }
		else { sgn = 0.8; py = 0.50; }
		float a = s * sgn;
		float c = cos(a);
		float sn = sin(a);
		vec3 q = v - vec3(0.0, py, 0.0);
		v = vec3(q.x, q.y * c - q.z * sn, q.y * sn + q.z * c) + vec3(0.0, py, 0.0);
		n = vec3(n.x, n.y * c - n.z * sn, n.y * sn + n.z * c);
	}
	v.y += bob * abs(sin(phase));
	v_nrm = (MODEL_NORMAL_MATRIX * n);
	v_w = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	v_col = COLOR;
	VERTEX = v;
}

void fragment() {
	if (fade_r > 0.0 && v_w.y > 0.45) {
		if (distance(v_w.xz, fade_pos.xz) < fade_r) {
			float d = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
			if (d > 0.3) discard;
		}
	}
	vec3 N = normalize(v_nrm);
	vec3 L = normalize(vec3(-0.5, 0.78, -0.4));
	float diff = clamp(dot(N, L), 0.0, 1.0);
	float shade = 0.60 + 0.58 * diff;
	vec3 col = v_col.rgb * tint.rgb * shade;
	col = mix(col, vec3(1.0), flash);
	if (night > 0.001) {
		float lit = light_amount(v_w.xz);
		vec3 dark = col * vec3(0.24, 0.28, 0.42);
		vec3 warm = col * lit * vec3(1.0, 0.86, 0.58);
		vec3 r = mix(col, dark + warm, night);
		if (v_col.a < 0.75) r = mix(r, v_col.rgb * 1.5 + vec3(0.2), night * 0.9);
		col = r;
	}
	ALBEDO = to_lin(col);
}
