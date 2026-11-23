uniform sampler2D road_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

float road_hash(vec2 cell) {
	return fract(sin(dot(mod(cell, 4096.0), vec2(73.13, 217.69))) * 43758.5453);
}

float road_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(road_hash(cell), road_hash(cell + vec2(1, 0)), t.x),
		mix(road_hash(cell + vec2(0, 1)), road_hash(cell + vec2(1, 1)), t.x), t.y);
}

vec3 weathered_asphalt(vec2 p, float scan_distance, float patch_strength) {
	vec3 scan = texture(road_scan, p / 2.5).rgb;
	float stone = dot(scan, vec3(.23, .62, .15));
	float weather = road_noise(p / 22.0) * .65 + road_noise(p / 5.5) * .35;
	vec3 color = vec3(.313, .309, .301) * (.55 + 1.05 * stone + .45 * weather);
	float close = 1.0 - smoothstep(25.0, 88.0, scan_distance);
	if (close > .001) {
		float gravel = texture(road_scan, p / 1.36 + vec2(.31, -.17)).r;
		color *= 1.0 + close * (gravel - .25) * .24;
		vec2 cells = p / vec2(5.1, 7.3);
		vec2 repair = fract(cells) - vec2(.48, .44);
		float site = road_hash(floor(cells));
		float seam = abs(repair.x + .12 * repair.y + (road_noise(p * 2.1) - .5) * .075);
		float sealed = step(.93, site) * (1.0 - smoothstep(.002, .008, seam))
			* (1.0 - smoothstep(.19, .37, abs(repair.y)));
		float patch = step(.966, site) * (1.0 - smoothstep(.24, .29, abs(repair.x) + .024 * stone))
			* (1.0 - smoothstep(.12, .16, abs(repair.y)));
		color *= 1.0 - close * (.22 * sealed + .15 * patch * patch_strength);
	}
	return color;
}

vec3 weathered_asphalt(vec2 p, float scan_distance) {
	return weathered_asphalt(p, scan_distance, 1.0);
}

vec3 road_relief(vec2 p, vec3 normal, vec3 world_x, float distance_to_eye) {
	float detail = 1.0 - smoothstep(12.0, 48.0, distance_to_eye);
	if (detail < .001) {
		return normal;
	}
	vec2 aggregate = texture(road_normal, p / 2.5).rg * 2.0 - 1.0;
	vec3 tangent = normalize(world_x - normal * dot(world_x, normal));
	vec3 bitangent = cross(tangent, normal);
	return normalize(normal + (tangent * aggregate.x + bitangent * aggregate.y) * .31 * detail);
}

float worn_road_paint(vec2 p) {
	float grit = texture(road_scan, p / 2.5).r;
	return .61 + .33 * smoothstep(.17, .56, grit + road_noise(p * 1.7) * .28);
}
