shader_type spatial;
render_mode specular_disabled;

uniform sampler2D asphalt_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

vec3 hash_cell(vec2 cell) {
	vec3 seed = fract(cell.xyx * vec3(.1031, .1030, .0973));
	seed += dot(seed, seed.yxz + 33.33);
	return fract((seed.xxy + seed.yzz) * seed.zyx);
}

vec2 across(vec2 axis) {
	return vec2(-axis.y, axis.x);
}

float curve_offset(float t, float seed) {
	float envelope = 4.0 * t * (1.0 - t);
	float bow = (seed - .5) * .25;
	float waviness = sin(t * (6.0 + seed * 13.0)) * .027 + sin(t * (24.0 + seed * 35.0)) * .011;
	return envelope * (bow + waviness);
}

float fissure(vec2 p, vec2 start, vec2 axis, float reach, float width, float seed, float pixel) {
	vec2 q = p - start;
	float u = dot(q, axis);
	float t = clamp(u / reach, 0.0, 1.0);
	float v = dot(q, across(axis)) - curve_offset(t, seed);
	float distance_from_path = length(vec2(u - t * reach, v));
	width *= (.70 + .31 * sin(3.14159 * t)) * (.78 + .22 * sin(t * (15.0 + seed * 48.0) + seed * 17.0));
	return (1.0 - smoothstep(max(0.0, width - pixel), width + pixel, distance_from_path))
		* min(1.0, width / pixel);
}

void fragment() {
	// Cells only seed positions. Four independent fracture patterns break up the pavement.
	vec2 p = UV * .33;
	p += vec2(sin(p.y * 41.0 + p.x * 11.1), sin(p.x * 35.0 - p.y * 9.3)) * .006;
	vec2 cell = floor(p);
	float pixel = max(length(fwidth(p)) * .48, .0002);
	float crack = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 anchor = cell + vec2(float(x), float(y));
			vec3 seed = hash_cell(anchor + vec2(13.0, 29.0));
			if (seed.z < .26) {
				continue;
			}
			vec2 q = p - (anchor + .5 + (seed.xy - .5) * .50);
			if (dot(q, q) > .52) {
				continue;
			}

			vec3 detail = hash_cell(anchor + vec2(71.0, -18.0));
			float heading = seed.y * TAU;
			vec2 axis = vec2(cos(heading), sin(heading));
			float reach = mix(.14, 1.04, detail.x * detail.x);
			float width = mix(.0012, .0043, detail.y * detail.y);
			vec2 start = -axis * reach * .5;

			if (detail.z < .34) {
				// Isolated curving cracks, from short hairlines to long seams.
				crack = max(crack, fissure(q, start, axis, reach, width, seed.x, pixel));
			} else if (detail.z < .62) {
				// Interrupted and offset segments with a patch of unbroken asphalt between them.
				vec2 offset = axis * (reach * .58 + .035) + across(axis) * ((seed.x - .5) * .095);
				crack = max(crack, fissure(q, start, axis, reach * .43, width * .72, seed.x, pixel));
				crack = max(crack, fissure(q, start + offset, axis, reach * .35, width * .53, detail.y, pixel));
			} else {
				float join = mix(.19, .82, seed.x);
				vec2 junction = start + axis * reach * join + across(axis) * curve_offset(join, seed.x);
				float fork = heading + mix(.48, 2.55, detail.x) * sign(seed.y - .5);
				vec2 branch = vec2(cos(fork), sin(fork));
				crack = max(crack, fissure(q, start, axis, reach, width, seed.x, pixel));
				crack = max(crack, fissure(q, junction, branch, mix(.07, .38, detail.y), width * .65, seed.y, pixel));
				if (detail.z > .83) {
					// A short crossing or second fracture can form independently of the first.
					float other_join = mix(.23, .72, seed.y);
					vec2 other_root = start + axis * reach * other_join + across(axis) * curve_offset(other_join, seed.x);
					float crossing = heading - mix(.82, 2.2, seed.x) * sign(seed.y - .5);
					vec2 twig = vec2(cos(crossing), sin(crossing));
					crack = max(crack, fissure(q, other_root, twig, mix(.12, .34, seed.z), width * .57, detail.x, pixel));
				}
			}
		}
	}
	vec3 aggregate = texture(asphalt_scan, UV).rgb;
	float grit = dot(aggregate, vec3(.2126, .7152, .0722));
	float wear = .97 + .055 * sin(p.x * 2.1 + sin(p.y * 1.8)) * cos(p.y * 2.8);
	ALBEDO = mix((grit * .49 + vec3(.236, .223, .202)) * wear, vec3(.087, .079, .068), crack * .76);
	ROUGHNESS = .92;
}
