// Wspolne funkcje: szum, oswietlenie nocne, korekta gamma.
global uniform float g_night;
global uniform vec4 g_l0;
global uniform vec4 g_l1;
global uniform vec4 g_l2;
global uniform vec4 g_l3;
global uniform vec4 g_l4;
global uniform vec4 g_l5;
global uniform vec4 g_l6;
global uniform vec4 g_l7;
global uniform vec4 g_l8;
global uniform vec4 g_l9;
global uniform vec4 g_l10;
global uniform vec4 g_l11;   // xy = pozycja (kafle), z = promien, w = jasnosc
#define night g_night

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
float la(vec4 L, vec2 p) {
	float d = distance(p, L.xy);
	float k = clamp(1.0 - d / max(L.z, 0.001), 0.0, 1.0);
	return L.w * k * k;
}
float light_amount(vec2 p) {
	return la(g_l0, p) + la(g_l1, p) + la(g_l2, p) + la(g_l3, p) + la(g_l4, p) + la(g_l5, p)
		+ la(g_l6, p) + la(g_l7, p) + la(g_l8, p) + la(g_l9, p) + la(g_l10, p) + la(g_l11, p);
}
vec3 apply_night(vec3 col, vec2 p) {
	if (night <= 0.001) return col;
	float lit = light_amount(p);
	vec3 dark = col * vec3(0.17, 0.21, 0.36);
	vec3 warm = col * lit * vec3(1.0, 0.86, 0.58);
	return mix(col, dark + warm, night);
}
vec3 to_lin(vec3 c) { return c; }

vec3 apply_night_bld(vec3 col, vec2 p, float glow) {
	if (night <= 0.001) return col;
	float lit = light_amount(p);
	vec3 dark = col * vec3(0.20, 0.24, 0.38);
	vec3 warm = col * lit * vec3(1.0, 0.86, 0.58);
	vec3 r = mix(col, dark + warm, night);
	return mix(r, vec3(1.0, 0.84, 0.48), clamp(glow, 0.0, 1.0) * 0.85);
}
