shader_type spatial;
global uniform float river_weather_wind;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float foliage_exposure = 1.0;
uniform vec4 fall_bounds = vec4(0.0);
varying float tree_tone;
varying vec3 leaf_color;
varying float fall;

void vertex() {
	vec3 plant = MODEL_MATRIX[3].xyz;
	tree_tone = sin(plant.x * .449 + plant.z * .191);
	vec2 patch = floor(plant.xz / 12.0);
	float season = fract(sin(dot(patch, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 fall_dist = min(plant.xz - fall_bounds.xy, fall_bounds.zw - plant.xz);
	fall = smoothstep(0.0, 66.0, min(fall_dist.x, fall_dist.y)) *
		mix(.0, .87, smoothstep(.31, .48, season));
	vec3 birch = vec3(.97, .59, .125);
	vec3 maple = vec3(.94, .28, .048);
	vec3 sumac = vec3(.82, .13, .039);
	leaf_color = mix(birch, maple, smoothstep(.67, .91, season));
	leaf_color = mix(leaf_color, sumac, smoothstep(.90, .99, season));
	float wind = sin(TIME * .92 + plant.x * .15 + plant.z * .17);
	VERTEX.x += wind * (VERTEX.y + .5) * (.021 + river_weather_wind * .067);
}

void fragment() {
	vec4 leaf = texture(leaves, UV);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = .46;
	float detail = dot(leaf.rgb, vec3(.22, .70, .08));
	vec3 fall_leaf = leaf_color * (detail * 1.72 + .027);
	vec3 foliage = mix(leaf.rgb, fall_leaf, fall) * foliage_exposure;
	ALBEDO = foliage * mix(vec3(.84, .91, .91), vec3(1.24, 1.19, 1.04), .5 + tree_tone * .5);
	EMISSION = foliage * .13;
	ROUGHNESS = .94;
}
