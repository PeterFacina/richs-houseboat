uniform sampler2D day_sky : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_day_sky = false;
uniform vec3 sun_direction = vec3(-0.588, 0.304, -0.761);
uniform vec4 sky_zenith : source_color = vec4(.32, .53, .73, 1.0);
uniform vec4 sky_horizon : source_color = vec4(.72, .81, .84, 1.0);
uniform vec4 sky_glow : source_color = vec4(1.0, .77, .53, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, .96, .91, 1.0);
uniform float sun_strength = .82;
uniform float moon_strength = 0.0;
uniform float night_weight = 0.0;
uniform float photo_weight = .45;
uniform float cloud_coverage = 0.0;
uniform vec2 weather_cloud_drift = vec2(0.0);

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

vec3 timed_river_sky(vec3 ray, float detail) {
	float height = max(ray.y, 0.0);
	float sky_gradient = 1.0 - exp(-height * 2.8);
	float toward_sun = max(dot(ray, sun_direction), 0.0);
	float warm_air = pow(toward_sun, 6.0) * (1.0 - night_weight) * exp(-height * 3.0);
	vec3 air = mix(sky_horizon.rgb, sky_zenith.rgb, sky_gradient);
	air = mix(air, sky_glow.rgb, .8 * warm_air);
	float clouds = 0.0;
	// Reflections use a filtered panorama and the same sky colours. Reserve
	// fine procedural clouds for the backdrop when the photograph fades out.
	float cloud_weight = max(smoothstep(.10, .86, cloud_coverage), 1.0 - smoothstep(.23, .52, photo_weight));
	if (detail > .8 && cloud_weight > 0.0) {
		vec2 cloud_uv = ray.xz / (height + .22) * vec2(2.0, 2.72) + vec2(6.7, 10.2) + weather_cloud_drift;
		float cover = sky_grain(cloud_uv) * .72 + sky_grain(cloud_uv * 2.13 + 4.8) * .28;
		clouds = smoothstep(mix(.63, .24, cloud_coverage), mix(.78, .51, cloud_coverage), cover) * smoothstep(.015, .22, height) * cloud_weight;
		vec3 cloud = mix(sky_horizon.rgb * .9, mix(vec3(.83), sky_glow.rgb, warm_air), .54 * (1.0 - night_weight));
		air = mix(air, cloud, clouds * mix(.70, .50, cloud_coverage));
	}
	if (has_day_sky && photo_weight > .0) {
		// Use the existing panorama for cloud detail without its baked lighting.
		vec3 photo = daylight_color(ray, detail);
		float texture_tone = dot(photo, vec3(.2126, .7152, .0722));
		air *= mix(1.0, mix(.69, 1.35, smoothstep(.16, .74, texture_tone)),
			photo_weight * smoothstep(.005, .23, height));
	}
	if (sun_strength > 0.0) {
		float sun_disc = smoothstep(.99979, .99993, toward_sun);
		air += sun_color.rgb * sun_strength * (.36 * pow(toward_sun, 42.0) + 1.75 * sun_disc);
	}
	if (moon_strength > 0.0) {
		float toward_moon = max(dot(ray, -sun_direction), 0.0);
		float moon_disc = smoothstep(.99980, .99991, toward_moon);
		air += vec3(.59, .69, 1.0) * moon_strength * (.57 * pow(toward_moon, 33.0) + 2.4 * moon_disc);
	}
	if (detail > .8 && night_weight > 0.0 && height > .025) {
		// Cubic direction cells have no panorama seam.
		vec3 p = ray * 210.0;
		vec3 cell = floor(p);
		float seed = fract(sin(dot(cell, vec3(127.1, 311.7, 74.7))) * 43758.55);
		float star = 1.0 - smoothstep(.10, .23, length(fract(p) - .5));
		air += vec3(.83, .89, 1.0) * star * smoothstep(.965, .999, seed)
			* night_weight * smoothstep(.025, .24, height) * (1.0 - max(cloud_coverage, clouds) * .94);
	}
	return mix(air, sky_horizon.rgb * .52, smoothstep(.0, .52, -ray.y));
}
