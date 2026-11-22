shader_type spatial;
render_mode diffuse_burley, shadows_disabled;

uniform vec4 pigment : source_color = vec4(.56, .41, .38, 1.0);
uniform float workwear = .42;

float soft_stain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 k = fract(sin(dot(i, vec2(43.61, 27.79)) + vec4(0.0, 43.61, 27.79, 71.40)) * 13858.17);
	return mix(mix(k.x, k.y, f.x), mix(k.z, k.w, f.x), f.y);
}

void fragment() {
	vec2 fabric_uv = UV * vec2(.68, 1.0);
	float wear = soft_stain(fabric_uv * vec2(14.0, 14.0));
	float flecks = soft_stain(fabric_uv * vec2(88.0, 100.0) + vec2(5.7, 8.3));
	float hem = (1.0 - smoothstep(.08, .45, UV2.y)) * smoothstep(.56, .92, wear * .77 + flecks * .23);
	float fade = (.96 + .075 * wear) * (1.0 - hem * .31 * workwear);
	ALBEDO = pigment.rgb * fade;
	ROUGHNESS = .96;
	SPECULAR = .20;
}
