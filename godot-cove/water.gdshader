shader_type spatial;

global uniform float river_weather_rain;
global uniform float river_weather_reflection;
uniform float wave_wind = .12;
uniform float water_detail = .5;
uniform float water_fog = 0.0;
uniform float use_weather = 0.0;
render_mode unshaded;

#include "res://river_sky.gdshaderinc"
#include "res://boat_launch_surface.gdshaderinc"
#include "res://lamure_surface.gdshaderinc"

uniform float clock;
uniform bool mapped = false;
uniform bool distant = false;
uniform bool headpond = false;
uniform sampler2D shoals : filter_linear, repeat_disable;
uniform sampler2D marina_shoals : filter_linear, repeat_disable;
uniform sampler2D swisha_shoals : filter_linear, repeat_disable;
uniform sampler2D lamure_shoals : filter_linear, repeat_disable;
uniform vec4 lamure_bounds = vec4(0.0);
uniform float lamure_shore_unit = .25;
uniform sampler2D riverbed : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ramp_concrete : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 ramp_axes = vec4(0.0);
uniform vec2 ramp_size = vec2(0.0);
uniform sampler2D reflect_shore : filter_linear, repeat_disable;
uniform vec4 marina_bounds = vec4(0.0);
uniform vec4 swisha_bounds = vec4(0.0);
uniform vec4 marina_shelter = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 shore_units = vec3(2.0, 0.25, 0.25);
uniform vec4 outfall = vec4(0.0);
uniform float outfall_width = 0.0;
uniform vec4 hooked_fish = vec4(0.0);
uniform vec4 surface_slick = vec4(0.0);
uniform vec2 fish_heading = vec2(1.0, 0.0);
uniform vec2 map_size = vec2(1.0);
uniform vec2 center = vec2(0.0);
uniform vec2 riverside_center = vec2(0.0);
uniform vec4 river_waves[6];
uniform float river_amplitudes[6];
uniform int wake_count = 0;
uniform vec4 wake_origins[12];
uniform vec4 wake_shapes[12];
uniform vec3 active_prop = vec3(0.0);
uniform vec2 prop_heading = vec2(0.0, 1.0);
uniform vec4 bow_light = vec4(0.0);
uniform vec3 bow_direction = vec3(0.0, -0.2, -1.0);
varying vec3 world;
varying vec2 slope;
varying float wave_height;
varying vec2 wake_foam;

vec2 grid_uv(sampler2D grid, vec2 uv) {
	vec2 dimensions = vec2(textureSize(grid, 0));
	return (uv * (dimensions - 1.0) + 0.5) / dimensions;
}

// Bank clearance, simulated bed depth, and a flag for the dam's tailrace.
vec3 channel(vec2 point) {
	vec2 uv = point / map_size;
	vec3 regional = textureLod(shoals, grid_uv(shoals, uv), 0.0).rgb;
	vec3 sample_data = vec3((headpond ? regional.g : regional.r) * 255.0 * shore_units.x,
		regional.b * 63.75, 0.0);
	vec2 marina_uv = (point - marina_bounds.xy) / max(vec2(0.001), marina_bounds.zw);
	if (!headpond && all(greaterThanEqual(marina_uv, vec2(0.0))) && all(lessThan(marina_uv, vec2(1.0)))) {
		vec3 harbor = textureLod(marina_shoals, grid_uv(marina_shoals, marina_uv), 0.0).rgb;
		sample_data = vec3(harbor.r * 255.0 * shore_units.y, harbor.b * 63.75, 0.0);
	}
	if (!headpond && lamure_bounds.z > 0.0) {
		vec2 beach_uv = (point - lamure_bounds.xy) / lamure_bounds.zw;
		if (all(greaterThanEqual(beach_uv, vec2(0.0))) && all(lessThan(beach_uv, vec2(1.0)))) {
			vec3 beach = textureLod(lamure_shoals, grid_uv(lamure_shoals, beach_uv), 0.0).rgb;
			sample_data = vec3(beach.r * 255.0 * lamure_shore_unit, beach.b * 63.75, 0.0);
		}
	}
	vec2 station_uv = (point - swisha_bounds.xy) / max(vec2(0.001), swisha_bounds.zw);
	if (all(greaterThanEqual(station_uv, vec2(0.0))) && all(lessThan(station_uv, vec2(1.0)))) {
		vec2 local = textureLod(swisha_shoals, grid_uv(swisha_shoals, station_uv), 0.0).rg;
		float shoal = (headpond ? local.g : local.r) * 255.0 * shore_units.z;
		sample_data = vec3(shoal, mix(0.18, 16.0, 1.0 - exp(-shoal * 0.064)), headpond ? 0.0 : 1.0);
	}
	return sample_data;
}

vec3 wave_component(vec2 p, vec2 k, float rate, float phase, float height) {
	float position = dot(p, k) - rate * clock + phase;
	return height * vec3(sin(position), cos(position) * k);
}

vec3 river_wave(vec2 p) {
	vec3 waves = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		vec4 wave = river_waves[i];
		waves += wave_component(p, wave.xy, wave.z, wave.w, river_amplitudes[i]);
	}
	return waves;
}

float wave_exposure(vec2 p, float shore) {
	float cove = length((p - marina_shelter.xy) / marina_shelter.zw);
	return mix(.24, 1.0, smoothstep(0.0, 57.0, shore)) * mix(.53, 1.0, smoothstep(.70, 1.0, cove));
}

vec3 wake_packet(vec2 p, vec4 origin, vec4 shape, out vec2 foam) {
	vec2 shift = p - origin.xy;
	foam = vec2(0.0);
	if (any(greaterThan(abs(shift), vec2(28.0)))) {
		return vec3(0.0);
	}
	vec2 side = vec2(origin.w, -origin.z);
	float along = dot(shift, origin.zw);
	float across = dot(shift, side);
	float age = shape.x;
	float length_weight = 1.0 - smoothstep(1.8, 6.0, abs(along - (2.7 + age * 2.65)));
	float edge = abs(across) - (1.0 + max(0.0, along) * shape.z + age * .84);
	float width_weight = 1.0 - smoothstep(.45, 3.1, abs(edge));
	float life = smoothstep(0.0, .32, age) * (1.0 - smoothstep(1.4, 4.5, age));
	float weight = shape.y * life * length_weight * width_weight;
	float phase = edge * 1.40;
	float crest = sin(phase);
	foam.x = max(0.0, crest) * weight * 2.4;
	float wash_age = smoothstep(0.0, .28, age) * (1.0 - smoothstep(.4, 2.6, age));
	float wash_width = .48 + max(0.0, along) * .15;
	foam.y = shape.w * wash_age * (1.0 - smoothstep(wash_width * .22, wash_width, abs(across)))
		* (1.0 - smoothstep(1.0, 4.1, abs(along - (1.5 + age * 1.9)))) * .55;
	vec2 heading = sign(across) * side - max(0.0, sign(along)) * shape.z * origin.zw;
	return weight * vec3(crest, cos(phase) * 1.40 * heading);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wake_foam = vec2(0.0);
	wave_height = 0.0;
	slope = vec2(0.0);
	if (!mapped) {
		vec3 wave = wave_component(world.xz, vec2(.31, .43), 1.45, 0.0, .15)
			+ wave_component(world.xz, vec2(-.64, .25), 1.92, 0.0, .071)
			+ wave_component(world.xz, vec2(.85, -.54), 2.4, 0.0, .033);
		wave_height = distant ? 0.0 : wave.x;
		slope = wave.yz;
	} else if (!distant) {
		vec3 wave = river_wave(world.xz);
		float shore = channel(world.xz).x;
		float exposure = headpond ? .12 : wave_exposure(world.xz, shore);
		float fade = headpond ? 1.0 : 1.0 - smoothstep(89.0, 112.0, distance(world.xz, center));
		vec3 wake = vec3(0.0);
		if (!headpond && fade > 0.0) {
			for (int i = 0; i < wake_count; i++) {
				vec2 foam;
				wake += wake_packet(world.xz, wake_origins[i], wake_shapes[i], foam);
				wake_foam += foam;
			}
		}
		wake.x = clamp(wake.x, -.14, .14);
		wave_height = ((wave.x + wake.x) * exposure + .03) * fade - .03;
		slope = (wave.yz + clamp(wake.yz, vec2(-.18), vec2(.18)) * fade) * exposure;
		wake_foam *= fade;
	}
	VERTEX.y += wave_height;
	world.y += wave_height;
}

float water_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 x = cell.x + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 y = cell.y + vec4(0.0, 0.0, 1.0, 1.0);
	vec4 grains = fract(sin(x * 41.37 + y * 173.21) * 1719.214);
	return mix(mix(grains.x, grains.y, blend.x), mix(grains.z, grains.w, blend.x), blend.y);
}

vec3 local_reflection(vec2 start, vec3 ray, vec3 sky_color, float nearby) {
	if (ray.y < -.03 || ray.y > .42) {
		return sky_color;
	}
	vec2 travel = ray.xz / max(.25, length(ray.xz));
	vec3 color = sky_color;
	int count = nearby > 0.0 ? 3 : 1;
	for (int sample_index = 0; sample_index < count; sample_index++) {
		float reach = sample_index == 0 ? 250.0 : (sample_index == 1 ? 82.0 : 29.0);
		vec2 uv = (start + travel * reach) / map_size;
		vec3 bank = texture(reflect_shore, uv).rgb;
		float dry = smoothstep(.022, .081, bank.r - bank.b);
		float height = max(0.0, (bank.r - .232) * 1327.0) + 12.0;
		float above = reach * max(0.0, ray.y);
		float visible = dry * (1.0 - smoothstep(height * .52, height + 4.5, above));
		vec3 timber = mix(bank * .90, vec3(.24, .32, .23), .38);
		color = mix(color, timber, visible * .59 * (sample_index == 0 ? 1.0 : nearby));
	}
	return color;
}

void fragment() {
	float riverside = riverside_profile && mapped && !headpond
		? 1.0 - smoothstep(175.0, 280.0, distance(world.xz, riverside_center)) : 0.0;
	float west = length((world.xz - vec2(-34.0, 5.0)) / vec2(28.0, 62.0));
	float east = length((world.xz - vec2(35.0, -37.0)) / vec2(26.0, 48.0));
	float shore = min(west, east);
	float shallow = 1.0 - smoothstep(0.87, 1.16, shore);
	float mapped_bank = 0.0;
	float bank_clearance = 0.0;
	float nearby = 1.0;
	float bed_depth = 20.0;
	bool in_tailrace = false;
	if (mapped) {
		float distance_from_boat = distance(world.xz, center);
		if (!headpond && ((distant && distance_from_boat < 112.0) || (!distant && distance_from_boat >= 112.0))) {
			discard;
		}
		vec3 sample_data = channel(world.xz);
		bank_clearance = sample_data.x;
		if (sample_data.x < 0.12) {
			discard;
		}
		bed_depth = max(.015, sample_data.y + (distant ? -.03 : wave_height));
		in_tailrace = sample_data.z > .5;
		nearby = 1.0 - smoothstep(68.0, 108.0, distance_from_boat);
		shallow = 1.0 - smoothstep(0.25, 5.5, bed_depth);
		mapped_bank = (1.0 - smoothstep(0.23, 1.26, sample_data.x)) * 0.18;
	}
	vec2 flow = world.xz;
	float irregularity = water_noise(flow * .47 + vec2(.07, -.21) * clock) - .5;
	float warp = sin(flow.x * .142 + flow.y * .258) * 1.6
		+ sin(flow.x * .39 - flow.y * .11 + clock * .61) + irregularity * 2.3;
	vec2 ripple = vec2(sin(dot(flow, vec2(3.2, 2.3)) + clock * 3.0 + warp) * .78
		+ cos(dot(flow, vec2(-5.8, 4.1)) - clock * 4.7 + warp * .53) * .22,
		cos(dot(flow, vec2(-1.7, 4.1)) - clock * 3.4 - warp) * .73
		+ sin(dot(flow, vec2(5.6, .12)) - clock * 4.8 + warp * .69) * .27);
	float footprint = length(fwidth(flow));
	float fine = 1.0 - smoothstep(.11, .59, footprint);
	vec2 normal_slope = slope;
	if (mapped && distant && !headpond) {
		normal_slope = river_wave(flow).yz * wave_exposure(flow, bank_clearance);
	}
	float stern_foam = 0.0;
	if (max(wake_foam.x, wake_foam.y) > .003) {
		float bubbles = water_noise(flow * 7.8 - vec2(.49, .31) * clock);
		stern_foam = (wake_foam.x + wake_foam.y) * smoothstep(.25, .70, bubbles);
		normal_slope += ripple * wake_foam.y * .037;
	}
	if (!distant && !headpond && active_prop.z > .025) {
		vec2 shift = flow - active_prop.xy;
		float along = dot(shift, prop_heading);
		float across = dot(shift, vec2(prop_heading.y, -prop_heading.x));
		if (along > -.25 && along < 8.0 && abs(across) < 1.4) {
			float width = .34 + max(0.0, along) * .13;
			float turbine = water_noise(vec2(along * 8.0 - clock * 13.0, across * 11.0));
			float wash = (1.0 - smoothstep(width * .28, width, abs(across + (turbine - .5) * .21)))
				* (1.0 - smoothstep(1.2, 8.0, along)) * active_prop.z;
			stern_foam += wash * smoothstep(.19, .79, turbine) * .66;
			normal_slope += ripple * wash * .031;
		}
	}
	float rain = river_weather_rain * use_weather;
	riverside *= 1.0 - rain * .6;
	if (!distant && rain * fine > .01 && water_detail > .01) {
		vec2 rain_grid = flow * 2.35;
		vec2 cell = floor(rain_grid);
		vec3 seed = fract(sin(vec3(dot(cell, vec2(127.1, 311.7)),
			dot(cell, vec2(269.5, 183.3)), dot(cell, vec2(419.2, 371.9)))) * 43758.5453);
		float age = fract(clock * (1.4 + seed.z * .9) + seed.x);
		vec2 drop = fract(rain_grid) - mix(vec2(.38), vec2(.62), seed.xy);
		float radius = length(drop);
		float front = radius - age * .30;
		float ring = sin(front * 96.0) * (1.0 - smoothstep(.018, .069, abs(front)));
		ripple += (drop / max(.02, radius)) * ring * (1.0 - age) * rain * 2.8;
	}
	float ripple_strength = (headpond ? .015 : mix(.014, .032, wave_wind))
		* fine * mix(.65, 1.1, water_detail);
	vec3 n = normalize(vec3(-normal_slope.x + ripple.x * ripple_strength, 1.0, -normal_slope.y + ripple.y * ripple_strength));
	vec3 view = normalize(CAMERA_POSITION_WORLD - world);
	float sky = pow(1.0 - max(dot(n, view), 0.0), 3.2);
	vec3 blue = mix(vec3(0.025, 0.20, 0.245), vec3(0.12, 0.43, 0.39), shallow);
	vec3 hue = mix(blue, vec3(0.44, 0.61, 0.66), sky * 0.81);
	if (mapped && !in_tailrace) {
		float wind = .64 + .36 * sin(dot(flow, vec2(.24, .073)) - clock * .39);
		vec2 breeze = vec2(sin(dot(flow, vec2(10.4, -5.7)) - clock * 5.4 + warp * 1.45),
			cos(dot(flow, vec2(7.5, 8.9)) - clock * 6.8 - warp * 1.53));
		breeze *= .023 * wind * water_detail * (1.0 - smoothstep(.05, .24, footprint));
		vec3 capillary = normalize(n + vec3(breeze.x, 0.0, breeze.y));
		vec3 mirror = reflect(-view, capillary);
		vec3 reflection = timed_river_sky(mirror, .37) * vec3(0.87, 0.96, 0.97);
		reflection = mix(reflection, reflection * vec3(.94, .99, .97), riverside);
		if (!headpond) {
			if ((river_weather_reflection > .3 && water_detail > .01) || use_weather < .5) {
				reflection = local_reflection(flow, mirror, reflection, nearby);
			}
		}
		if (water_fog > .01) {
			reflection = mix(reflection, sky_horizon.rgb,
				water_fog * smoothstep(22.0, 350.0, distance(CAMERA_POSITION_WORLD, world)) * .74);
		}
		float fresnel = 0.037 + pow(1.0 - max(dot(capillary, view), 0.0), 4.25) * 0.79;
		vec3 basin = mix(vec3(0.047, 0.138, 0.148), vec3(0.157, 0.255, 0.201), shallow);
		basin = mix(basin, mix(vec3(.040, .145, .164), vec3(.20, .38, .285),
			smoothstep(.0, .9, shallow)), riverside * .84);
		if (bed_depth < 7.0 && !headpond) {
			vec3 underwater = refract(-view, capillary, .75);
			float path = bed_depth / max(.37, -underwater.y);
			vec2 floor_uv = flow + underwater.xz * path;
			vec3 gravel = texture(riverbed, floor_uv / 2.4).rgb;
			float sandy = lamure_coverage(floor_uv).b;
			if (sandy > .001) {
				gravel = mix(gravel, beach_sand(floor_uv, 1.0) * vec3(1.12, 1.07, .96), sandy);
			}
			if (ramp_size.x > 0.0 && distance(floor_uv, ramp_axes.xy) < ramp_size.x + ramp_size.y) {
				vec2 offset = floor_uv - ramp_axes.xy;
				vec2 across = vec2(-ramp_axes.w, ramp_axes.z);
				vec2 metres = vec2(dot(offset, across), dot(offset, ramp_axes.zw));
				if (metres.y >= 0.0 && metres.y <= ramp_size.x && abs(metres.x) < ramp_size.y * .5) {
					gravel = launch_surface(ramp_concrete, metres, 1.0);
				}
			}
			float light = water_noise((floor_uv + .15 * ripple) * 3.7 + vec2(.34, -.28) * clock);
			float caustic = (1.0 - smoothstep(.024, .116, abs(light - .52))) * fine;
			vec3 attenuation = exp(-path * vec3(.67, .34, .38));
			vec3 bottom = gravel * vec3(.71, .83, .76) * (1.0 + caustic * .22);
			basin = mix(basin, bottom, attenuation * .95);
		}
		hue = mix(basin, reflection, min(.94, fresnel + riverside * .075));
	}
	float crest_breaks = ripple.x + 0.35 * sin(dot(flow, vec2(0.83, -1.58)) + clock * 1.7);
	float flecks = smoothstep(.45, .84, wave_wind) * smoothstep(.19, .31, wave_height)
		* smoothstep(.63, 1.33, crest_breaks);
	float foam = (1.0 - smoothstep(0.011, 0.045, abs(shore - 0.92 + sin(clock + world.z * 0.27) * 0.008)))
		* smoothstep(-0.17, 0.80, ripple.x);
	if (mapped) {
		foam = mapped_bank * smoothstep(.12, .92, ripple.x * .55 + ripple.y * .45)
			* mix(.45, 1.1, wave_wind);
		float broken_edge = irregularity + .5;
		foam += riverside * mapped_bank * smoothstep(.43, .72, broken_edge + ripple.x * .09) * .38;
	}
	ALBEDO = hue
		+ vec3(0.49, 0.60, 0.56) * max(flecks * 0.26, foam * 0.52);
	if (riverside > 0.0) {
		float light_lines = sin(dot(flow, vec2(1.8, -.68)) + clock * 1.15 + warp * .62);
		float sparkle = pow(max(0.0, light_lines), 14.0) * fine * (1.0 - shallow * .55);
		ALBEDO += vec3(.22, .31, .27) * sparkle * riverside * .10;
	}
	ALBEDO = mix(ALBEDO, vec3(.74, .849, .806), min(.74, stern_foam));
	if (surface_slick.w > 0.0 && !distant && !headpond) {
		vec2 slick = (world.xz - surface_slick.xy) / max(.05, surface_slick.z);
		float radius = length(slick * vec2(.82, 1.06));
		if (radius < 1.50) {
			float broken = water_noise(slick * 7.4 + ripple * .20);
			float plume = (1.0 - smoothstep(.26, 1.46, radius + .32 * broken)) * smoothstep(.25, .64, broken);
			ALBEDO = mix(ALBEDO, vec3(.36, .367, .248), plume * surface_slick.w * .51);
		}
	}
	if (headpond) {
		float shimmer = water_noise(flow * vec2(1.96, 0.81) + vec2(-clock * 0.32, clock * 0.18));
		ALBEDO = mix(hue, vec3(0.10, 0.245, 0.29), 0.42) + vec3(0.04, 0.06, 0.067) * shimmer;
	}
	if (hooked_fish.w > 0.0 && hooked_fish.z < 0.86 && !headpond) {
		vec2 relative = world.xz - hooked_fish.xy + fish_heading * hooked_fish.w * 0.41;
		vec2 along = vec2(dot(relative, fish_heading), dot(relative, vec2(fish_heading.y, -fish_heading.x)));
		float blur = 0.025 + 0.20 * hooked_fish.z;
		vec2 body = along / (vec2(hooked_fish.w * 0.48, hooked_fish.w * 0.15) + blur);
		float fish_shadow = (1.0 - smoothstep(0.34, 1.16, length(body)))
			* (1.0 - smoothstep(0.04, 0.86, hooked_fish.z));
		ALBEDO = mix(ALBEDO, vec3(0.067, 0.165, 0.147), fish_shadow * 0.52);
		float trail = -along.x - hooked_fish.w * 0.30;
		if (trail > 0.0 && trail < 1.36 && hooked_fish.z < 0.24) {
			float edge = abs(along.y) - (0.027 + trail * 0.30);
			float lip = 1.0 - smoothstep(0.008, 0.074, abs(edge));
			float wake = lip * smoothstep(0.0, 0.12, trail) * (1.0 - smoothstep(0.30, 1.36, trail));
			wake *= (1.0 - smoothstep(0.027, 0.24, hooked_fish.z)) * (0.70 + 0.30 * sin(trail * 31.0 + clock * 9.0));
			ALBEDO += vec3(0.22, 0.32, 0.30) * wake;
		}
	}
	if (in_tailrace) {
		vec2 delta = world.xz - outfall.xy;
		vec2 along_bays = vec2(outfall.w, -outfall.z);
		float downstream = dot(delta, outfall.zw);
		float across = dot(delta, along_bays);
		if (downstream >= -1.1 && downstream < 140.0 && abs(across) < outfall_width * 0.7) {
			float pitch = outfall_width / 8.0;
			float bend = water_noise(vec2(across * 0.65, downstream * 0.73 - clock * 1.4)) - 0.5;
			float jet = abs(fract(across / pitch + 4.0 + bend * min(0.7, downstream * 0.15)) - 0.5);
			float spread = 0.25 + min(0.22, downstream * 0.0063);
			float edges = 1.0 - smoothstep(outfall_width * 0.42, outfall_width * 0.7, abs(across));
			float plume = mix(0.49, 1.0, 1.0 - smoothstep(spread, 0.50, jet))
				* edges * exp(-max(0.0, downstream) * 0.020);
			vec2 stream = vec2(across + bend * 0.35, downstream - clock * 2.2);
			float froth = water_noise(stream * vec2(7.4, 4.85));
			float churn = water_noise(stream * vec2(2.2, 1.85) + vec2(3.8, clock * 0.23));
			float seams = (1.0 - smoothstep(0.045, 0.18, abs(froth - 0.48))) * smoothstep(0.23, 0.69, churn);
			float foam_patch = smoothstep(0.41, 0.81, 0.67 * churn + 0.33 * froth + plume * 0.17);
			float at_outlet = 1.0 - smoothstep(4.2, 33.0, downstream);
			float whitewash = plume * (0.05 + 0.50 * seams + 0.52 * foam_patch + 0.28 * at_outlet);
			ALBEDO = mix(ALBEDO, vec3(0.90, 0.96, 0.935), min(0.94, whitewash));
		}
	}
	ALBEDO *= mix(vec3(.16, .20, .31), vec3(1.0), smoothstep(0.0, .62, sun_strength));
	if (sun_strength > 0.0) {
		float sun_glint = pow(max(dot(reflect(-sun_direction, n), view), 0.0), mix(92.0, 42.0, wave_wind));
		ALBEDO += sun_color.rgb * sun_glint * sun_strength * .35;
	}
	if (moon_strength > 0.0) {
		float moon_glint = pow(max(dot(reflect(sun_direction, n), view), 0.0), 89.0);
		ALBEDO += vec3(.58, .71, 1.0) * moon_glint * moon_strength * .85;
	}
	if (bow_light.w > 0.0 && !distant && !headpond) {
		vec3 span = world - bow_light.xyz;
		float distance_to_lamp = length(span);
		float cone = smoothstep(.917, .986, dot(normalize(span), bow_direction));
		float lamp_falloff = exp(-distance_to_lamp * .052) * (1.0 - smoothstep(20.0, 45.0, distance_to_lamp));
		float glint = max(0.0, dot(reflect(normalize(span), n), view));
		ALBEDO += vec3(.82, .61, .32) * bow_light.w * lamp_falloff * cone
			* (.14 + .54 * pow(glint, 16.0) + ripple.x * .032);
	}
}
