shader_type spatial;
render_mode cull_disabled, depth_draw_never;

uniform float seed = 0.0;
uniform float remaining = 1.0;

void fragment() {
	vec2 point = (UV - .5) * vec2(1.75, 2.0);
	float angle = atan(point.y, point.x);
	float edge = .64 + .10 * sin(angle * 5.0 + seed) + .066 * cos(angle * 11.0 - seed);
	float stain = 1.0 - smoothstep(edge - .046, edge + .015, length(point));
	vec2 grid = point * vec2(15.0, 20.0);
	vec2 cell = floor(grid);
	float noise = fract(sin(dot(cell, vec2(17.13, 71.29)) + seed) * 2217.7);
	float speck = (1.0 - smoothstep(.08, .26, length(fract(grid) - .5))) * smoothstep(.54, .90, noise);
	float scatter = speck * (1.0 - smoothstep(.32, .85, length(point)));
	ALBEDO = mix(vec3(.20, .18, .076), vec3(.47, .38, .19), speck * .53 + noise * .15);
	ROUGHNESS = .39;
	SPECULAR = .48;
	ALPHA = max(stain * .84, scatter * .69) * remaining;
}
