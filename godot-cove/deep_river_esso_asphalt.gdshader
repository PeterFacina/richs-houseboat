shader_type spatial;
render_mode specular_disabled;

uniform sampler2D asphalt_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

vec3 hash_cell(vec2 cell) {
	vec3 seed = fract(cell.xyx * vec3(.1031, .1030, .0973));
	seed += dot(seed, seed.yxz + 33.33);
	return fract((seed.xxy + seed.yzz) * seed.zyx);
}

float fissure(vec2 p, vec2 a, vec2 b, float width, float pixel) {
	vec2 span = b - a;
	float along = clamp(dot(p - a, span) / max(dot(span, span), .000001), 0.0, 1.0);
	float distance_from_path = length(p - a - span * along);
	width *= mix(1.2, .48, along) * (.90 + .10 * sin(along * 17.0));
	return (1.0 - smoothstep(max(0.0, width - pixel), width + pixel, distance_from_path))
		* min(1.0, width / pixel);
}

void fragment() {
	// Cells seed isolated cracks. Their edges never contribute to the pattern.
	vec2 p = UV * .37;
	p += vec2(sin(p.y * 31.0 + p.x * 11.1) + .44 * sin(p.y * 85.0),
		sin(p.x * 35.0 - p.y * 9.3) + .42 * sin(p.x * 91.0)) * .012;
	vec2 cell = floor(p);
	float pixel = max(length(fwidth(p)) * .46, .0002);
	float crack = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 anchor = cell + vec2(float(x), float(y));
			vec3 seed = hash_cell(anchor);
			if (seed.z > .38) {
				vec2 origin = anchor + .5 + (seed.xy - .5) * .62;
				vec2 q = p - origin;
				if (dot(q, q) > .51) {
					continue;
				}
				float heading = seed.x * 17.31;
				vec2 direction = vec2(cos(heading), sin(heading));
				vec2 normal = vec2(-direction.y, direction.x);
				float reach = mix(.17, .66, seed.y);
				float width = mix(.0013, .0052, seed.z * seed.z);
				vec2 a = -direction * reach * .44;
				vec2 b = -direction * reach * .12 + normal * (seed.x - .45) * .21;
				vec2 c = direction * reach * .24 - normal * (seed.z - .41) * .10;
				vec2 d = direction * reach + normal * (seed.y - .56) * .19;
				crack = max(crack, fissure(q, a, b, width * .7, pixel));
				crack = max(crack, fissure(q, b, c, width, pixel));
				crack = max(crack, fissure(q, c, d, width * .78, pixel));
				if (seed.y > .39) {
					vec2 branch = c + (direction * .36 + normal * sign(seed.x - .5) * .84) * reach * .62;
					crack = max(crack, fissure(q, c, branch, width * .55, pixel));
				}
			}
		}
	}
	vec3 aggregate = texture(asphalt_scan, UV).rgb;
	float grit = dot(aggregate, vec3(.2126, .7152, .0722));
	float wear = .97 + .07 * sin(p.x * 2.1 + sin(p.y * 1.8)) * cos(p.y * 2.8);
	ALBEDO = mix((grit * .49 + vec3(.236, .223, .202)) * wear, vec3(.087, .079, .068), crack * .73);
	ROUGHNESS = .92;
}
