shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float pace = 1.0;
uniform float offset = 0.0;

float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 h = fract(sin(dot(i, vec2(72.93, 157.31)) + vec4(0.0, 72.93, 157.31, 230.24)) * 22917.171);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void vertex() {
	float phase = TIME * pace + offset;
	float fall = smoothstep(0.0, 0.37, UV.y);
	VERTEX.y += fall * (sin(UV.x * 41.0 + UV.y * 23.0 - phase * 10.0) * 0.027
		+ sin(UV.x * 19.0 - UV.y * 31.0 + phase * 13.0) * 0.018);
}

void fragment() {
	float phase = TIME * pace + offset;
	// V follows the torrent down the face of each outlet.
	float eddies = grain(vec2(UV.x * 19.0, UV.y * 3.6 - phase * 6.8));
	vec2 moving = vec2(UV.x + (eddies - 0.5) * UV.y * 0.16, UV.y - phase * 1.95);
	float streams = grain(moving * vec2(44.0, 4.1));
	float bubbles = grain(moving * vec2(67.0, 31.0) + vec2(0.0, phase * 4.3));
	float rim = smoothstep(0.26, 0.49, abs(UV.x - 0.5));
	if (UV.y > 0.17 && abs(UV.x - 0.5) > 0.484 + 0.044 * (bubbles - 0.5)) {
		discard;
	}
	float foam = smoothstep(0.25, 0.83, streams * 0.48 + bubbles * 0.22 + eddies * 0.30
		+ rim * 0.28 + UV.y * 0.26);
	float crest = smoothstep(0.69, 0.98, UV.y);
	vec3 water = mix(vec3(0.12, 0.33, 0.37), vec3(0.25, 0.52, 0.55), eddies);
	ALBEDO = mix(water, vec3(0.90, 0.97, 0.96), max(foam, crest * 0.42));
}
