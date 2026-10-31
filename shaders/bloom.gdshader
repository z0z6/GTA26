shader_type canvas_item;
render_mode blend_add;

// Bloom: swiecace miejsca (reflektory, latarnie, okna, odbicia) rozlewaja sie miekka poswiata.
// Probkuje kolejne poziomy mipmap ekranu (coraz bardziej rozmyte) i dodaje to, co przekracza prog.
// Rysowany pod interfejsem (CanvasLayer nizej niz HUD), wiec HUD nie jest rozmywany.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float strength = 0.0;     // 0 = wylaczony (ustawiane z postfx.gd wedlug pory doby)
uniform float threshold = 0.2;    // od jakiej jasnosci zaczyna sie poswiata

vec3 glow_at(vec2 uv, float lod, float thr) {
	vec3 c = textureLod(screen_tex, uv, lod).rgb;
	return max(c - vec3(thr), vec3(0.0));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 g = vec3(0.0);
	g += glow_at(uv, 2.0, threshold * 1.00) * 0.70;
	g += glow_at(uv, 3.0, threshold * 0.85) * 0.65;
	g += glow_at(uv, 4.0, threshold * 0.75) * 0.50;
	g += glow_at(uv, 5.0, threshold * 0.65) * 0.40;
	COLOR = vec4(g * strength, 1.0);
}
