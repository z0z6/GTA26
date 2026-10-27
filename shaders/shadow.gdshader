shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 0.38;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float a = 1.0 - smoothstep(0.35, 1.0, length(q));
	ALBEDO = vec3(0.0);
	ALPHA = a * strength;
}
