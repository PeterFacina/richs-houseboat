shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform int pattern = 0;
uniform float pattern_phase = 0.0;
uniform bool elongated = false;
uniform vec3 back : source_color = vec3(0.21, 0.28, 0.16);
uniform vec3 flank : source_color = vec3(0.69, 0.59, 0.27);
uniform vec3 belly : source_color = vec3(0.86, 0.83, 0.67);
uniform bool fin = false;
uniform float swim = 0.0;
uniform float phase = 0.0;

float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 x = i.x + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 y = i.y + vec4(0.0, 0.0, 1.0, 1.0);
	vec4 h = fract(sin(x * 61.48 + y * 143.76) * 18073.17);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void vertex() {
	float pivot = elongated ? 0.21 : 0.27;
	float t = max(0.0, (VERTEX.z - pivot) / (1.0 - pivot));
	float sweep = elongated ? 9.2 : 5.4;
	float angle = phase - t * sweep;
	VERTEX.x += sin(angle) * swim * t * t;
	float tilt = swim * (2.0 * t * sin(angle) - t * t * sweep * cos(angle));
	NORMAL = normalize(vec3(NORMAL.x, NORMAL.y, NORMAL.z - NORMAL.x * tilt));
}

void fragment() {
	if (fin) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.48;
		SPECULAR = 0.36;
	} else {
		float around = cos(UV.y * 6.283185);
		vec3 pigment = mix(flank, back, smoothstep(0.15, 0.98, around));
		pigment = mix(pigment, belly, smoothstep(0.18, 0.97, -around));
		vec2 skin = UV * vec2(16.5, 9.0);
		float clouds = grain(skin + vec2(7.1, 3.7) + pattern_phase);
		float side = smoothstep(-0.81, -0.42, around) * (1.0 - smoothstep(0.76, 0.98, around));
		float body = smoothstep(0.13, 0.24, UV.x) * (1.0 - smoothstep(0.86, 0.96, UV.x));
		float stripes = 1.0 - smoothstep(0.12, 0.43, abs(fract(UV.x * (7.4 + .7 * sin(pattern_phase)) + around * 0.21 + clouds * 0.22) - 0.5));
		vec2 spots = UV * vec2(23.0, 12.0) + vec2(clouds * 1.1 + around * 0.24, clouds * 0.64);
		vec2 cell_id = floor(spots);
		vec3 scatter = fract(sin(dot(cell_id, vec2(16.67, 83.82)) + pattern_phase + vec3(0.0, 37.9, 51.77)) * 1734.93);
		vec2 spot_center = mix(vec2(0.27, 0.31), vec2(0.76, 0.69), scatter.xy);
		float dot_radius = length((fract(spots) - spot_center) * vec2(0.86, 1.30));
		float spot = 1.0 - smoothstep(0.09, 0.25, dot_radius);
		float dark = 0.0;
		float pale = 0.0;
		float stripe = (1.0 - smoothstep(0.07, 0.23, abs(around + .04 * sin(UV.x * 18.0)))) * body;
		if (pattern == 1 || pattern == 7) {
			dark = stripes * side * body * (pattern == 7 ? smoothstep(-.46, .68, around) * .67 : .68);
		} else if (pattern == 2 || pattern == 17) {
			dark = stripe * (.65 + .30 * clouds) * (pattern == 17 ? smoothstep(.11, .37, clouds) : 1.0);
		} else if (pattern == 3 || pattern == 6 || pattern == 18 || pattern == 22 || pattern == 23) {
			dark = (pattern == 6 ? smoothstep(.52, .78, clouds) : spot * scatter.z) * body * side * .9;
		} else if (pattern == 4 || pattern == 5 || pattern == 13 || pattern == 14) {
			pale = spot * side * body * scatter.z * .9;
			if (pattern == 5) {
				dark = max(stripes * .21, spot * scatter.z * .68) * side * body;
				pale *= .10;
			}
		} else if (pattern == 10) {
			vec2 eye_spot = vec2((UV.x - .825) * 22.0, (around - .09) * 2.6);
			dark = 1.0 - smoothstep(.32, .76, length(eye_spot));
		} else if (pattern == 11 || pattern == 12) {
			vec2 ear = vec2((UV.x - .217) * 21.0, (around - .16) * 2.1);
			dark = max(stripes * .41 * side * body, 1.0 - smoothstep(.24, .72, length(ear)));
			pale = pattern == 12 ? spot * .51 * side * body : .0;
		} else if (pattern == 15 || pattern == 16) {
			dark = spot * body * smoothstep(-.39, .52, around);
			pigment = mix(pigment, vec3(.65, .30, .21), (pattern == 16 ? stripe * .39 : spot * .25 * side));
		} else if (pattern == 19 || pattern == 20) {
			float blush = pattern == 19 ? smoothstep(.15, .81, -around) * body : 1.0 - smoothstep(.07, .25, UV.x);
			pigment = mix(pigment, vec3(.69, .27, .17), blush * .57);
		}
		pigment = mix(pigment, back * .38, dark);
		pigment = mix(pigment, pattern == 12 ? vec3(.26, .49, .48) : vec3(.77, .76, .45), pale);
		float lateral = 1.0 - smoothstep(0.025, 0.12, abs(around + 0.08 + 0.11 * sin(UV.x * 8.0)));
		float gill_depth = (pattern == 4 || pattern == 5 || pattern == 22 ? 0.235 : 0.197) + 0.030 * (1.0 - around * around);
		float operculum = 1.0 - smoothstep(0.002, 0.011, abs(UV.x - gill_depth));
		pigment *= 1.0 - body * lateral * 0.15 - operculum * side * 0.28;
		vec2 scales = UV * (pattern == 8 || pattern == 21 || pattern == 22 ? vec2(34.0, 19.0) : vec2(79.0, 33.0));
		scales.x += mod(floor(scales.y), 2.0) * 0.50;
		vec2 cell = (fract(scales) - 0.5) * vec2(1.08, 1.0);
		float ridge = 1.0 - smoothstep(0.015, 0.091, abs(length(cell) - 0.43));
		float detail = 1.0 - smoothstep(0.60, 1.45, max(fwidth(scales.x), fwidth(scales.y)));
		float sheen = 0.88 + 0.17 * clouds + (pattern == 8 ? .155 : .095) * ridge * detail * body;
		ALBEDO = pigment * sheen;
		ROUGHNESS = mix(0.23, 0.40, clouds) - ridge * detail * body * 0.06;
		SPECULAR = 0.60;
		METALLIC = pattern == 9 ? .21 : .035;
	}
}
