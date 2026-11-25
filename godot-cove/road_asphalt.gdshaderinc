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

float crack_coverage(float offset, float width, float footprint) {
	float blur = max(.003, footprint * .65);
	return (1.0 - smoothstep(max(0.0, width - blur), width + blur, abs(offset))) *
		min(1.0, width / blur);
}

float asphalt_cracks(vec2 p, float age, float jaggedness, float footprint) {
	// Stagger small fracture groups in world space so they continue across mesh chunks.
	vec2 grid = vec2(p.x + p.y * .38, p.y - p.x * .24) / 4.1;
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - .5;
	float site = road_hash(cell);
	float shape = road_hash(cell + vec2(17.0, 43.0));
	float angle = shape * 6.283185;
	vec2 axis = vec2(cos(angle), sin(angle));
	vec2 along = vec2(dot(local, axis), dot(local, vec2(-axis.y, axis.x))) * 4.1;
	along += vec2((site - .5) * .70, (shape - .5) * .92);
	float broken_edge = 1.0 - smoothstep(.41, .49, max(abs(local.x), abs(local.y)));
	float bend = (jaggedness - .5) * .19;
	float extent = mix(.71, 1.93, site);
	float main = crack_coverage(along.y - bend, mix(.018, .038, shape), footprint) *
		(1.0 - smoothstep(extent - .38, extent, abs(along.x)));
	float split = along.x + mix(-.31, .29, shape);
	float branch = crack_coverage(along.y + bend * .53 - split * mix(.39, .79, site), .018, footprint) *
		smoothstep(-.06, .13, split) * (1.0 - smoothstep(.56, 1.21, split));
	float frequency = mix(.78, .39, age);
	return broken_edge * step(frequency, site) * max(main, branch * .79);
}

vec3 weathered_asphalt(vec2 p, float scan_distance, float patch_strength) {
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	vec3 scan = texture(road_scan, p / 2.5).rgb;
	float stone = dot(scan, vec3(.23, .62, .15));
	float weather = road_noise(p / 22.0) * .65 + road_noise(p / 5.5) * .35;
	vec3 color = vec3(.313, .309, .301) * (.55 + 1.05 * stone + .45 * weather);
	float close = 1.0 - smoothstep(25.0, 88.0, scan_distance);
	if (close > .001) {
		float gravel = texture(road_scan, p / .92 + vec2(.31, -.17)).r;
		float aggregate_detail = 1.0 - smoothstep(.045, .17, footprint);
		color *= 1.0 + close * aggregate_detail * (gravel - .43) * .72;
		vec2 cells = p / vec2(5.1, 7.3);
		vec2 repair = fract(cells) - vec2(.48, .44);
		float site = road_hash(floor(cells));
		float jaggedness = road_noise(p * 3.1);
		float cracks = asphalt_cracks(p, patch_strength, jaggedness, footprint);
		float patch = step(.91, site) * (1.0 - smoothstep(.24, .29, abs(repair.x) + .048 * stone))
			* (1.0 - smoothstep(.12, .16, abs(repair.y)));
		color *= 1.0 - close * ((.38 + .18 * jaggedness) * cracks + .17 * patch * patch_strength);
	}
	return color;
}

vec3 weathered_asphalt(vec2 p, float scan_distance) {
	return weathered_asphalt(p, scan_distance, 1.0);
}

vec3 road_grain_normal(vec2 grain, vec3 normal, vec3 world_x, float strength) {
	vec3 tangent = normalize(world_x - normal * dot(world_x, normal));
	vec3 bitangent = cross(tangent, normal);
	return normalize(normal + (tangent * grain.x + bitangent * grain.y) * strength);
}

vec3 road_relief(vec2 p, vec3 normal, vec3 world_x, float distance_to_eye) {
	float detail = 1.0 - smoothstep(12.0, 48.0, distance_to_eye);
	if (detail < .001) {
		return normal;
	}
	vec2 aggregate = texture(road_normal, p / 2.5).rg * 2.0 - 1.0;
	return road_grain_normal(aggregate, normal, world_x, .48 * detail);
}

float worn_road_paint(vec2 p) {
	float grit = texture(road_scan, p / 2.5).r;
	return .61 + .33 * smoothstep(.17, .56, grit + road_noise(p * 1.7) * .28);
}
