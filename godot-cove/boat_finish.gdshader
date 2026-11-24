shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 coat : source_color = vec4(.25, .28, .29, 1.0);
uniform bool timber = false;
uniform float matte = .50;
uniform float grain_offset = 0.0;
varying vec3 panel;
varying vec3 panel_normal;

float grain(vec2 p) {
	vec2 block = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 x = block.x + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 y = block.y + vec4(0.0, 0.0, 1.0, 1.0);
	vec4 ink = fract(sin(x * 13.29 + y * 61.31) * 321.56);
	return mix(mix(ink.x, ink.y, f.x), mix(ink.z, ink.w, f.x), f.y);
}

void vertex() {
	panel = VERTEX;
	panel_normal = NORMAL;
}

void fragment() {
	if (timber) {
		vec2 strip = panel.xz;
		if (abs(panel_normal.y) < .45) {
			strip = vec2(abs(panel_normal.x) > .55 ? panel.z : panel.x, panel.y);
		}
		float knots = grain(strip * vec2(3.45, 12.0) + grain_offset);
		float fibers = grain(vec2(strip.x * 4.6, strip.y * 122.0 + knots * 2.6 + grain_offset));
		float pores = grain(strip * vec2(22.0, 314.0));
		float seam = smoothstep(.77, .97, pores) * (.43 + .57 * knots);
		ALBEDO = coat.rgb * (.78 + knots * .14 + fibers * .21 + pores * .047 - seam * .049);
		ROUGHNESS = .72 + fibers * .18 + seam * .061;
	} else {
		vec2 steel = vec2(panel.x + panel.z, panel.y + (panel.z - panel.x) * .034);
		float chips = grain(steel * vec2(127.0, 12.4)) * grain(steel * vec2(62.0, 22.2));
		float aging = grain(steel * vec2(8.6, 3.3));
		ALBEDO = coat.rgb * (.86 + aging * .18 + chips * .047);
		ROUGHNESS = matte + aging * .19;
		SPECULAR = .46;
	}
}
