shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;
#include "res://shaders/common.gdshaderinc"

// COLOR.rgb = kolor bazowy (sRGB), COLOR.a = rodzaj powierzchni:
//   0.0 sciana, 0.34 dach plaski, 0.67 dach spadzisty, 1.0 szczyt (trojkat sciany)
// UV  = sciana: (odleglosc wzdluz sciany, wysokosc); dach: (x,z) w chunku lub (wzdluz kalenicy, po spadku)
// UV2 = (wysokosc sciany lub dlugosc spadku, styl budynku)
varying vec3 v_nrm;
varying vec4 v_col;
varying vec2 v_uv;
varying vec2 v_uv2;
varying vec3 v_w;

void vertex() {
	v_nrm = NORMAL;
	v_col = COLOR;
	v_uv = UV;
	v_uv2 = UV2;
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float box_mask(vec2 f, vec2 lo, vec2 hi, float aa) {
	vec2 a = smoothstep(lo - aa, lo + aa, f);
	vec2 b = 1.0 - smoothstep(hi - aa, hi + aa, f);
	return a.x * a.y * b.x * b.y;
}

void fragment() {
	float kind = v_col.a;
	vec3 base = v_col.rgb;
	vec3 N = normalize(v_nrm);
	vec3 L = normalize(vec3(-0.5, 0.78, -0.4));
	float diff = clamp(dot(N, L), 0.0, 1.0);
	float shade = 0.56 + 0.62 * diff;
	vec3 col = base;
	float glow = 0.0;      // swiatlo okien w nocy
	vec3 glow_col = vec3(1.0, 0.82, 0.45);

	if (kind < 0.2) {
		float u = v_uv.x;
		float v = v_uv.y;
		float H = max(v_uv2.x, 0.1);
		int style = int(v_uv2.y + 0.5);
		float fh = 0.55;
		float plaster = 0.93 + 0.13 * vnoise(vec2(u * 6.0, v * 6.0));
		col = base * plaster;
		col *= 0.80 + 0.20 * smoothstep(0.0, 0.5, v);              // brud przy ziemi
		col = mix(col, col * 1.12, smoothstep(H - 0.09, H - 0.05, v)); // gzyms

		float sp = 0.62;
		if (style == 0) sp = 0.78;
		if (style == 3) sp = 0.95;
		if (style == 4) sp = 1.6;
		if (style == 1) sp = 1.2;
		float fi = floor(v / fh);
		float fy = fract(v / fh);
		float cu = u / sp;
		float cell = floor(cu);
		float fx = fract(cu);
		float rnd = h21(vec2(cell, fi) + vec2(floor(u * 0.0), 3.0));

		if (style == 3 || style == 2) {
			float seam = step(fract(u / 1.2), 0.025) + step(fy, 0.04);
			col *= 1.0 - 0.10 * min(seam, 1.0);
		}
		bool has_win = (style != 1) && (v < H - 0.12);
		if (style == 4) has_win = has_win && fi >= 1.0 && fy > 0.2;
		if (has_win) {
			vec2 lo = vec2(0.24, 0.30);
			vec2 hi = vec2(0.76, 0.80);
			if (style == 3) { lo = vec2(0.16, 0.34); hi = vec2(0.84, 0.74); }
			if (style == 0) { lo = vec2(0.30, 0.32); hi = vec2(0.70, 0.80); }
			if (style == 4) { lo = vec2(0.10, 0.30); hi = vec2(0.90, 0.70); }
			if (fi < 0.5 && (style == 2 || style == 5)) {          // parter: sklepy i drzwi
				lo = vec2(0.12, 0.10); hi = vec2(0.88, 0.80);
				if (mod(cell, 3.0) < 0.5) { lo = vec2(0.30, 0.0); hi = vec2(0.70, 0.78); }
			}
			vec2 f = vec2(fx, fy);
			float frame = box_mask(f, lo - 0.045, hi + 0.045, 0.012);
			float glass = box_mask(f, lo, hi, 0.012);
			vec3 frame_col = base * 0.55 + 0.35;
			col = mix(col, frame_col, frame * 0.9);
			float sky = (f.y - lo.y) / (hi.y - lo.y);
			vec3 gl = mix(vec3(0.32, 0.44, 0.56), vec3(0.72, 0.83, 0.92), clamp(sky, 0.0, 1.0));
			if (rnd > 0.78) gl = mix(gl, vec3(0.86, 0.80, 0.66), 0.7);   // firanki
			bool lit = h21(vec2(cell * 1.7, fi * 2.3 + 9.0)) > 0.52;
			if (night > 0.01 && lit) {
				glow = glass * lamps_on(night);
				gl = mix(gl, glow_col, lamps_on(night));
			}
			if (style == 2 || style == 5) {
				// parapet i balkon co drugi cell na wyzszych pietrach
				float balc = step(0.5, h21(vec2(cell, 5.0))) * step(1.0, fi);
				float rail = box_mask(f, vec2(lo.x - 0.12, 0.05), vec2(hi.x + 0.12, 0.20), 0.01) * balc;
				col = mix(col, base * 0.62, rail * 0.85);
			}
			col = mix(col, gl, glass);
		}
		if (style == 4) {
			float rib = 0.93 + 0.07 * sin(u * 40.0);
			col *= rib;
		}
	} else if (kind < 0.5) {
		// dach plaski: papa, laty, szwy i plamy
		float big = fbm(v_uv * 0.33 + 4.0);
		float patch = smoothstep(0.46, 0.62, fbm(v_uv * 0.9 + 5.0));
		col = base * (0.80 + 0.34 * big);
		col = mix(col, col * 0.80, patch * 0.65);
		float seam = step(fract(v_uv.x / 1.25), 0.022) + step(fract(v_uv.y / 1.25), 0.022);
		col -= vec3(0.065) * min(seam, 1.0);
		col += (h21(floor(v_uv * 28.0)) - 0.5) * 0.05;
	} else if (kind < 0.85) {
		// dach spadzisty: dachowki
		float row = floor(v_uv.y / 0.085);
		float fr = fract(v_uv.y / 0.085);
		float off = mod(row, 2.0) * 0.5;
		float cu2 = v_uv.x / 0.13 + off;
		float fc = fract(cu2);
		float tile = h21(vec2(floor(cu2), row));
		col = base * (0.90 + 0.16 * tile);
		col *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.22, fr));
		col *= 1.0 - 0.10 * (1.0 - smoothstep(0.0, 0.06, fc));
		float len = max(v_uv2.y, 0.2);
		col = mix(col, base * 1.18, smoothstep(len - 0.06, len - 0.02, v_uv.y));
		col *= 0.97 + 0.06 * fbm(v_uv * 4.0);
	} else {
		col = base * (0.94 + 0.1 * vnoise(v_uv * 5.0));
	}

	col *= shade;
	// swiatla ulicy (latarnie, reflektory) oswietlaja dolne partie scian, nie dachy ani gorne pietra
	float reach = (kind < 0.2) ? (1.0 - 0.7 * smoothstep(0.0, 3.5, v_w.y)) : 0.2;
	col = apply_night_bld(col, v_w.xz, glow, reach);
	ALBEDO = to_lin(col);
}
