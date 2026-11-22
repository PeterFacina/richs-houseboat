shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D portrait : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool procedural_face = false;
uniform float jaw_open : hint_range(0.0, 1.0) = 0.0;
uniform mat3 pose_basis = mat3(1.0);
varying float face_weight;

void vertex() {
	face_weight = COLOR.r;
	float chin = smoothstep(.63, .91, UV.y) * face_weight;
	float head_weight = smoothstep(-.055, .038, VERTEX.y);
	VERTEX.y -= .010 * chin * jaw_open;
	VERTEX.z -= .006 * chin * jaw_open;
	VERTEX = mix(VERTEX, pose_basis * VERTEX, head_weight);
	NORMAL = normalize(mix(NORMAL, pose_basis * NORMAL, head_weight));
}

vec3 shannon_face(vec2 uv) {
	vec2 eye = vec2(abs(uv.x - .5) - .158, uv.y - .433);
	float socket = exp(-dot(eye * vec2(12.0, 21.0), eye * vec2(12.0, 21.0)));
	float sclera = 1.0 - smoothstep(.73, 1.0, length(eye * vec2(18.0, 65.0)));
	float iris = 1.0 - smoothstep(.53, 1.0, length((eye - vec2(.003, -.001)) * vec2(42.0, 77.0)));
	float pupil = 1.0 - smoothstep(.65, 1.0, length(eye * vec2(85.0, 150.0)));
	float brow = exp(-pow(abs(eye.x) * 13.5, 2.0) - pow(abs(eye.y + .047 - .15 * eye.x) * 88.0, 2.0));
	float nostril = exp(-pow(abs(abs(uv.x - .5) - .045) * 61.0, 2.0) - pow(abs(uv.y - .589) * 100.0, 2.0));
	float lips = exp(-pow(abs(uv.x - .5) * 10.4, 4.0) - pow(abs(uv.y - .686) * 65.0, 2.0));
	float cheek = exp(-pow(abs(abs(uv.x - .5) - .229) * 9.2, 2.0) - pow(abs(uv.y - .575) * 9.0, 2.0));
	float grain = fract(sin(dot(floor(uv * 480.0), vec2(32.78, 81.72))) * 17718.41) - .5;
	vec3 skin = vec3(.64, .385, .288) + vec3(.058, -.02, -.017) * cheek - .083 * socket + grain * .037;
	skin = mix(skin, vec3(.48, .20, .17), lips * .85);
	skin = mix(skin, vec3(.105, .047, .033), max(nostril * .54, brow * .78));
	skin = mix(skin, vec3(.69, .62, .54), sclera * .89);
	skin = mix(skin, vec3(.105, .144, .09), min(iris, sclera));
	return mix(skin, vec3(.022, .019, .015), min(pupil, sclera));
}

void fragment() {
	vec2 uv = UV;
	float lip = .683 + .006 * (1.0 - smoothstep(.03, .12, abs(uv.x - .5)));
	float width = 1.0 - smoothstep(.067, .123, abs(uv.x - .5));
	float opening = .040 * jaw_open * width;
	if (uv.y > lip) {
		uv.y -= opening * (1.0 - smoothstep(lip + .04, .98, uv.y));
	}
	vec3 skin = procedural_face ? shannon_face(uv) : texture(portrait, uv).rgb;
	float space = UV.y - lip;
	if (opening > .002 && space > .0 && space < opening) {
		float teeth = (1.0 - smoothstep(.16, .36, space / opening)) * smoothstep(.65, .98, width);
		skin = mix(vec3(.067, .016, .020), vec3(.69, .55, .42), teeth);
	}
	vec3 side = procedural_face ? vec3(.58, .333, .244) : texture(portrait, vec2(.10 + .029 * sin(UV.y * 10.0), .46)).rgb;
	ALBEDO = mix(side * vec3(.89, .92, .96), skin, face_weight);
	ROUGHNESS = .82;
	SPECULAR = .30;
}
