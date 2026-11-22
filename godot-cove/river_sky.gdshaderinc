uniform sampler2D day_sky : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_day_sky = false;

vec3 daylight_color(vec3 ray, float detail) {
	vec2 uv = vec2(atan(ray.z, ray.x) / TAU + .5, acos(clamp(ray.y, -1.0, 1.0)) / PI);
	// An explicit mip level keeps the wrap at +/- PI from widening into a visible seam.
	vec3 photograph = textureLod(day_sky, uv, (1.0 - detail) * 2.2).rgb;
	return mix(vec3(.33, .41, .40), photograph, smoothstep(-.24, -.022, ray.y));
}

float sky_grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	// Hash identical corner coordinates on both sides of every cell edge.
	vec4 x = fract((cell.x + vec4(0.0, 1.0, 0.0, 1.0)) * 0.1031);
	vec4 y = fract((cell.y + vec4(0.0, 0.0, 1.0, 1.0)) * 0.11369);
	vec4 z = fract((cell.x + vec4(0.0, 1.0, 0.0, 1.0)) * 0.13787);
	vec4 hash = x * (y + 19.19) + y * (z + 19.19) + z * (x + 19.19);
	vec4 h = fract((x + y + 2.0 * hash) * (z + hash));
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

vec3 river_sky(vec3 ray, float detail, float evening) {
	if (has_day_sky && evening < .001) {
		return daylight_color(ray, detail);
	}
	float height = max(ray.y, 0.0);
	float glow = pow(max(0.0, dot(normalize(vec3(ray.x, .23, ray.z)), normalize(vec3(-.63, .16, -.78)))), 2.9);
	vec3 horizon = mix(vec3(0.75, 0.84, 0.86), mix(vec3(.47, .51, .65), vec3(.94, .57, .32), glow), evening);
	vec3 zenith = mix(vec3(0.225, 0.48, 0.70), vec3(.094, .17, .36), evening);
	vec3 blue = mix(horizon, zenith, 1.0 - exp(-height * 2.5));
	vec2 clouds = ray.xz / (height + 0.21) * vec2(2.0, 2.72) + vec2(6.7, 10.2);
	float soft = sky_grain(clouds) * 0.60 + sky_grain(clouds * 2.13 + 4.8) * 0.25;
	float fringe = (sky_grain(clouds * 4.58 - 8.1) * 0.10 + sky_grain(clouds * 9.17 + 3.6) * 0.05);
	float vapor = soft + mix(fringe * 0.52, fringe, detail);
	float mass = smoothstep(0.47, 0.64, vapor);
	vec3 cloud = mix(vec3(0.58, 0.675, 0.727), vec3(0.97, 0.962, 0.909),
		smoothstep(0.50, 0.77, vapor + height * 0.14));
	cloud = mix(cloud, mix(vec3(.43, .50, .65), vec3(.92, .63, .49), glow * .76 + .15), evening);
	float clear_horizon = smoothstep(0.017, 0.165, height);
	vec3 air = mix(blue, cloud, mass * clear_horizon);
	if (ray.y < 0.0) {
		air = mix(air, mix(vec3(0.36, 0.46, 0.43), vec3(.15, .22, .35), evening), smoothstep(0.0, 0.38, -ray.y));
	}
	if (has_day_sky && evening < .73) {
		air = mix(daylight_color(ray, detail), air, smoothstep(.0, .73, evening));
	}
	return air;
}
