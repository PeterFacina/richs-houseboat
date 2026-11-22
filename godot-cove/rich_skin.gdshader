shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D portrait : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
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

void fragment() {
	vec2 uv = UV;
	float lip = .683 + .006 * (1.0 - smoothstep(.03, .12, abs(uv.x - .5)));
	float width = 1.0 - smoothstep(.067, .123, abs(uv.x - .5));
	float opening = .040 * jaw_open * width;
	if (uv.y > lip) {
		uv.y -= opening * (1.0 - smoothstep(lip + .04, .98, uv.y));
	}
	vec3 skin = texture(portrait, uv).rgb;
	float space = UV.y - lip;
	if (opening > .002 && space > .0 && space < opening) {
		float teeth = (1.0 - smoothstep(.16, .36, space / opening)) * smoothstep(.65, .98, width);
		skin = mix(vec3(.067, .016, .020), vec3(.69, .55, .42), teeth);
	}
	vec3 side = texture(portrait, vec2(.10 + .029 * sin(UV.y * 10.0), .46)).rgb;
	ALBEDO = mix(side * vec3(.89, .92, .96), skin, face_weight);
	ROUGHNESS = .82;
	SPECULAR = .30;
}
