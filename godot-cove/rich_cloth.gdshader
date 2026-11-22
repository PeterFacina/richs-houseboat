shader_type spatial;
render_mode diffuse_burley, shadows_disabled;

uniform vec4 pigment : source_color = vec4(.56, .41, .38, 1.0);
uniform float workwear = .42;
uniform bool floral = false;

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
	if (floral) {
		vec2 tile = fabric_uv * vec2(19.0, 13.0);
		tile.x += mod(floor(tile.y), 2.0) * .5;
		vec2 bloom = fract(tile) - vec2(.5);
		float seed = soft_stain(floor(tile));
		float angle = atan(bloom.y, bloom.x) + seed * 14.0;
		float petals = 1.0 - smoothstep(.22, .25, length(bloom) - .085 * cos(angle * 5.0));
		float leaf = 1.0 - smoothstep(.85, 1.0, length((bloom - vec2(.27, -.22)) * vec2(5.3, 8.0)));
		vec3 ink = mix(vec3(.23, .36, .34), vec3(.66, .75, .70), step(.23, seed));
		ALBEDO = mix(ALBEDO, vec3(.13, .28, .22), leaf * .82);
		ALBEDO = mix(ALBEDO, ink * fade, petals * .89);
	}
	ROUGHNESS = .96;
	SPECULAR = .20;
}
