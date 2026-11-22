shader_type spatial;
render_mode unshaded;

float ellipse(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(.88, 1.0, length((p - center) / radius));
}

float rect(vec2 p, vec2 center, vec2 half_size) {
	vec2 edge = half_size - abs(p - center);
	return smoothstep(.0, .015, min(edge.x, edge.y));
}

void fragment() {
	vec2 page = UV;
	vec3 color = vec3(.85, .90, .9);
	float bar = 1.0 - smoothstep(.21, .22, page.y);
	color = mix(color, vec3(.09, .19, .25), bar);
	for (int i = 0; i < 3; i++) {
		vec2 at = (page - vec2(.06 + float(i) * .305, .31)) / vec2(.26, .43);
		color = mix(color, vec3(.98, 1.0, .98), rect(at, vec2(.5), vec2(.53, .55)));
		float body = rect(at, vec2(.46, .59), vec2(.30, .12));
		body = max(body, rect(at, vec2(.62, .45), vec2(.15, .13)));
		float tread = max(ellipse(at, vec2(.72, .71), vec2(.135, .19)), ellipse(at, vec2(.19, .75), vec2(.082, .115)));
		float seat = max(rect(at, vec2(.58, .41), vec2(.11, .05)), rect(at, vec2(.66, .32), vec2(.044, .09)));
		vec3 paint = mix(vec3(.91, .29, .07), vec3(.22, .42, .17), float(i) * .48);
		color = mix(color, paint, body);
		color = mix(color, vec3(.12, .15, .16), max(tread, seat));
		color = mix(color, vec3(.35, .45, .48), rect(at, vec2(.40, 1.25), vec2(.36, .026)));
		color = mix(color, vec3(.16, .43, .29), rect(at, vec2(.35, 1.44), vec2(.30, .036)));
	}
	ALBEDO = color * .74;
}
