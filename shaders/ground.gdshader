shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;
#include "res://shaders/common.gdshaderinc"

uniform sampler2D gridtex : filter_nearest, repeat_disable;  // R8: klasa podloza
uniform sampler2D bmask : filter_linear, repeat_disable;     // R8: pokrycie budynkami
uniform vec2 grid_size = vec2(1074.0, 1001.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

int cls_at(ivec2 t) {
	ivec2 g = ivec2(grid_size);
	t = clamp(t, ivec2(0), g - 1);
	return int(texelFetch(gridtex, t, 0).r * 255.0 + 0.5);
}
bool is_road(int c) { return c == 8 || c == 9 || c == 10; }

vec3 paving(vec2 p, float tone) {
	vec2 q = p * 1.5;
	vec2 f = fract(q);
	float line = step(f.x, 0.035) + step(f.y, 0.035);
	float v = h21(floor(q));
	float stain = fbm(p * 0.7 + 3.0);
	vec3 base = vec3(0.80, 0.77, 0.69) * (0.94 + 0.08 * v) * tone * (0.92 + 0.12 * stain);
	return base - vec3(0.05) * min(line, 1.0);
}
vec3 sidewalk(vec2 p) {
	vec2 q = vec2(p.x * 2.2, p.y * 2.2);
	vec2 f = fract(q);
	float line = step(f.x, 0.05) + step(f.y, 0.05);
	float v = h21(floor(q));
	vec3 base = vec3(0.74, 0.72, 0.66) * (0.95 + 0.07 * v);
	return base - vec3(0.06) * min(line, 1.0);
}
vec3 grass(vec2 p) {
	float n = fbm(p * 1.1);
	float n2 = vnoise(p * 16.0);
	float dry = smoothstep(0.55, 0.8, fbm(p * 0.45 + 31.0));
	vec3 a = vec3(0.38, 0.58, 0.26);
	vec3 b = vec3(0.50, 0.68, 0.31);
	vec3 g = mix(a, b, n);
	g = mix(g, vec3(0.62, 0.64, 0.36), dry * 0.55);
	return g * (0.93 + 0.14 * n2);
}

vec3 class_color(int c, vec2 p) {
	float grain = h21(floor(p * 26.0));
	if (c == 8 || c == 10) {
		float n = fbm(p * 1.6);
		vec3 base = (c == 10) ? vec3(0.37, 0.37, 0.36) : vec3(0.30, 0.31, 0.33);
		return base * (0.90 + 0.18 * n) + (grain - 0.5) * 0.04;
	}
	if (c == 9) {
		float n = fbm(p * 1.4);
		vec3 base = vec3(0.26, 0.27, 0.29);
		return base * (0.92 + 0.16 * n) + (grain - 0.5) * 0.035;
	}
	if (c == 1) return paving(p, 1.0) + (grain - 0.5) * 0.02;
	if (c == 2) {
		float m = smoothstep(0.36, 0.52, fbm(p * 0.75 + 13.0));
		vec3 earth = vec3(0.67, 0.61, 0.49) * (0.92 + 0.14 * fbm(p * 2.0)) + (grain - 0.5) * 0.04;
		return mix(earth, grass(p) * 0.96, m);
	}
	if (c == 3) {
		vec2 q = p / 2.0;
		vec2 f = fract(q);
		float line = step(f.x, 0.02) + step(f.y, 0.02);
		vec3 base = vec3(0.64, 0.62, 0.66) * (0.92 + 0.12 * fbm(p * 1.1));
		return base - vec3(0.07) * min(line, 1.0) + (grain - 0.5) * 0.03;
	}
	if (c == 4) {
		vec2 cell = floor(p / 9.0);
		float ang = h21(cell) * 3.14159;
		vec2 dir = vec2(cos(ang), sin(ang));
		float s = 0.5 + 0.5 * sin(dot(p, dir) * 14.0);
		vec3 a = vec3(0.74, 0.76, 0.52);
		vec3 b = vec3(0.64, 0.69, 0.40);
		vec3 tint = mix(vec3(0.95, 1.0, 0.85), vec3(1.05, 0.98, 0.85), h21(cell + 3.0));
		return mix(a, b, s * 0.55 + 0.25 * fbm(p * 0.5)) * tint;
	}
	if (c == 5) return grass(p);
	if (c == 6) {
		float n = fbm(p * 1.1);
		float blobs = smoothstep(0.35, 0.8, vnoise(p * 3.2));
		vec3 a = vec3(0.17, 0.33, 0.15);
		vec3 b = vec3(0.30, 0.49, 0.22);
		return mix(a, b, blobs * 0.8 + n * 0.2);
	}
	if (c == 7) {
		float t = TIME;
		float wv = vnoise(p * 0.7 + vec2(t * 0.05, 0.0));
		float r1 = sin((p.x * 0.8 + p.y * 0.55) * 6.0 + t * 1.1 + wv * 6.0);
		float r2 = sin((p.x * -0.5 + p.y * 0.9) * 8.0 - t * 0.8 + wv * 5.0);
		float hl = smoothstep(0.93, 1.0, r1) * 0.30 + smoothstep(0.95, 1.0, r2) * 0.22;
		vec3 base = mix(vec3(0.24, 0.50, 0.66), vec3(0.20, 0.44, 0.60), fbm(p * 0.35));
		return base + vec3(hl);
	}
	if (c == 11) {
		vec3 g = grass(p) * 0.9;
		vec2 q = p * 1.5;
		vec2 f = fract(q);
		float path = step(f.x, 0.14) + step(f.y, 0.14);
		return mix(g, vec3(0.72, 0.68, 0.58), min(path, 1.0) * 0.8);
	}
	if (c == 13) return vec3(0.03);
	return vec3(0.8, 0.78, 0.7);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 warp = (vec2(vnoise(p * 2.6), vnoise(p * 2.6 + 7.1)) - 0.5) * 0.24;
	vec2 pw = p + warp;
	ivec2 t0 = ivec2(floor(pw));
	float w[16];
	for (int i = 0; i < 16; i++) w[i] = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 t = t0 + ivec2(dx, dy);
			int c = cls_at(t);
			vec2 d = pw - (vec2(t) + 0.5);
			float k = exp(-dot(d, d) * 1.75);
			float bias = is_road(c) ? 1.25 : 1.0;
			w[c] += k * bias;
		}
	}
	int c1 = 0; int c2 = 0;
	float w1 = -1.0; float w2 = -1.0;
	for (int i = 0; i < 16; i++) {
		if (w[i] > w1) { w2 = w1; c2 = c1; w1 = w[i]; c1 = i; }
		else if (w[i] > w2) { w2 = w[i]; c2 = i; }
	}
	float d = max(w1 - w2, 0.0);
	vec3 col1 = class_color(c1, p);
	vec3 col2 = (w2 > 0.0) ? class_color(c2, p) : col1;
	float m = smoothstep(0.0, 0.16, d);
	vec3 col = mix(col2, col1, 0.5 + 0.5 * m);

	float roadw = w[8] + w[9] + w[10];
	if (!is_road(c1) && c1 != 7 && c1 != 6 && c1 != 4) {
		float sw = smoothstep(0.10, 0.45, roadw);
		col = mix(col, sidewalk(p), sw * 0.92);
	}
	float edge = 1.0 - smoothstep(0.0, 0.11, d);
	if (is_road(c1) != is_road(c2) && w2 > 0.0) {
		col = mix(col, vec3(0.86, 0.84, 0.76), edge * 0.85);
	} else if ((c1 == 7) != (c2 == 7) && w2 > 0.0) {
		col = mix(col, vec3(0.86, 0.92, 0.88), edge * 0.55);
	} else if (c1 != c2 && w2 > 0.0) {
		col *= 1.0 - edge * 0.12;
	}

	// znaki poziome na drogach glownych
	if ((c1 == 9 || c1 == 10) && w2 >= 0.0) {
		ivec2 t = ivec2(floor(p));
		int l = 0; int r = 0; int u = 0; int dn = 0;
		for (int i = 1; i <= 4; i++) { if (is_road(cls_at(t + ivec2(-i, 0)))) l++; else break; }
		for (int i = 1; i <= 4; i++) { if (is_road(cls_at(t + ivec2(i, 0)))) r++; else break; }
		for (int i = 1; i <= 4; i++) { if (is_road(cls_at(t + ivec2(0, -i)))) u++; else break; }
		for (int i = 1; i <= 4; i++) { if (is_road(cls_at(t + ivec2(0, i)))) dn++; else break; }
		float ew = float(l + r + 1);
		float eh = float(u + dn + 1);
		if (min(ew, eh) >= 3.0 && min(ew, eh) < 7.0) {
			float line = 0.0;
			if (ew < eh) {
				float cx = float(t.x - l) + ew * 0.5;
				line = (1.0 - smoothstep(0.025, 0.05, abs(p.x - cx))) * step(fract(p.y * 1.1), 0.58);
			} else {
				float cy = float(t.y - u) + eh * 0.5;
				line = (1.0 - smoothstep(0.025, 0.05, abs(p.y - cy))) * step(fract(p.x * 1.1), 0.58);
			}
			col = mix(col, vec3(0.90, 0.78, 0.25), line * 0.9);
		}
	}

	// miekki cien budynkow (swiatlo z polnocnego zachodu)
	vec2 sdir = normalize(vec2(0.6, 0.45));
	float sh = 0.0;
	for (int i = 1; i <= 3; i++) {
		vec2 q = (p - sdir * float(i) * 0.5) / grid_size;
		sh += texture(bmask, q).r;
	}
	sh /= 3.0;
	col *= 1.0 - 0.34 * clamp(sh, 0.0, 1.0);

	col = apply_night(col, p);
	ALBEDO = to_lin(col);
}
