// Wspolne funkcje: szum, oswietlenie nocne (mapa swiatel z scripts/lightmap.gd), korekta gamma.
global uniform float g_night;                 // 0 = dzien, ~0.5 = zmierzch, 1 = noc
global uniform sampler2D g_lightmap : filter_linear, repeat_disable;
global uniform vec2 g_lm_origin;              // lewy gorny rog mapy swiatel (kafle swiata)
#define night g_night
const float LM_SIZE = 64.0;                   // rozmiar mapy swiatel w kaflach (= SIZE_TILES w lightmap.gd)

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

// Kolorowe swiatlo w punkcie swiata (kolor * jasnosc), z mapy swiatel. Poza mapa = 0.
vec3 light_rgb(vec2 p) {
	vec2 uv = (p - g_lm_origin) / LM_SIZE;
	vec2 e = min(uv, 1.0 - uv);
	float edge = smoothstep(0.0, 0.03, min(e.x, e.y));
	return texture(g_lightmap, uv).rgb * 2.0 * edge;
}

// Swiatlo otoczenia: dzien (1) -> cieply, przygaszony zmierzch -> ciemna granatowo-czarna noc.
// To tutaj reguluje sie "nastroj" nocy.
const vec3 AMB_DUSK = vec3(0.48, 0.41, 0.34);
const vec3 AMB_NIGHT = vec3(0.095, 0.105, 0.165);
vec3 night_ambient(float k) {
	vec3 a = mix(AMB_DUSK, AMB_NIGHT, smoothstep(0.5, 1.0, k));
	return mix(vec3(1.0), a, smoothstep(0.0, 0.5, k));
}
// Latarnie, reflektory i okna zapalaja sie stopniowo od zmierzchu.
float lamps_on(float k) { return smoothstep(0.15, 0.65, k); }

vec3 apply_night(vec3 col, vec2 p) {
	if (night <= 0.001) return col;
	return col * (night_ambient(night) + light_rgb(p) * lamps_on(night));
}
vec3 to_lin(vec3 c) { return c; }

// reach = jak mocno swiatla z poziomu ulicy docieraja do tej powierzchni (1 = parter, 0.2 = dach).
vec3 apply_night_bld(vec3 col, vec2 p, float glow, float reach) {
	if (night <= 0.001) return col;
	vec3 r = col * (night_ambient(night) * 1.15 + light_rgb(p) * lamps_on(night) * reach);
	return mix(r, vec3(1.0, 0.84, 0.48), clamp(glow, 0.0, 1.0) * 0.85);
}
// Obiekty (postacie, auta) sa odrobine jasniejsze od terenu, zeby byly czytelne w ciemnosci.
vec3 apply_night_obj(vec3 col, vec2 p) {
	if (night <= 0.001) return col;
	return col * (night_ambient(night) * 1.45 + light_rgb(p) * lamps_on(night));
}
