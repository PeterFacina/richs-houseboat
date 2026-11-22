shader_type spatial;
render_mode specular_disabled;

uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float court_pitch = 12.5;
uniform int court_count = 6;
uniform vec3 apron : source_color = vec3(.345, .455, .365);
uniform vec3 playing_area : source_color = vec3(.336, .418, .338);
uniform vec3 paint : source_color = vec3(.944, .951, .909);

float stripe(float d, float half_width, float aa) {
	return smoothstep(-aa, aa, d + half_width) - smoothstep(-aa, aa, d - half_width);
}

void fragment() {
	vec2 aa = max(fwidth(UV) * .60, vec2(.002));
	float row = UV.x + court_pitch * float(court_count) * .5;
	float x = abs(mod(row, court_pitch) - court_pitch * .5);
	float z = abs(UV.y);
	float doubles = 5.485;
	float singles = 4.115;
	float baseline = 11.885;
	float service = 6.40;
	float line = .028;
	float sides = max(stripe(x - doubles, line, aa.x), stripe(x - singles, line, aa.x));
	sides *= 1.0 - smoothstep(baseline - aa.y, baseline + line + aa.y, z);
	float ends = stripe(z - baseline, line, aa.y) *
		(1.0 - smoothstep(doubles - aa.x, doubles + line + aa.x, x));
	float boxes = stripe(z - service, line, aa.y) *
		(1.0 - smoothstep(singles - aa.x, singles + line + aa.x, x));
	float center = stripe(x, line, aa.x) *
		(1.0 - smoothstep(service - aa.y, service + aa.y, z));
	float tick = stripe(x, line, aa.x) *
		(1.0 - smoothstep(.05, .05 + aa.y, abs(z - (baseline - .055))));
	float fill = (1.0 - smoothstep(doubles - aa.x, doubles + aa.x, x)) *
		(1.0 - smoothstep(baseline - aa.y, baseline + aa.y, z));
	float in_row = step(0.0, row) * step(row, court_pitch * float(court_count));
	float marking = max(max(sides, ends), max(boxes, max(center, tick))) * in_row;
	float grain = texture(aggregate, UV * .39).r;
	vec3 coating = mix(apron, playing_area, fill * in_row) * mix(.91, 1.09, grain);
	ALBEDO = mix(coating, paint, marking);
	ROUGHNESS = .94;
}
