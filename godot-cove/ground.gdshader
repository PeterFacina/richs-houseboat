shader_type spatial;

#include "res://river_surfaces.gdshaderinc"
#include "res://road_asphalt.gdshaderinc"
#include "res://lamure_surface.gdshaderinc"

uniform sampler2D town_ground : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D riverbank : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lamure_litter : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 town_bounds = vec4(0.0);
uniform sampler2D town_paving : filter_linear, repeat_disable;
uniform vec4 paving_bounds = vec4(0.0);
uniform sampler2D station_paving : filter_linear, repeat_disable;
uniform vec4 station_bounds = vec4(0.0);
uniform sampler2D riverbank_path_mask : filter_linear_mipmap, repeat_disable;
uniform vec4 riverbank_path_bounds = vec4(0.0);
uniform sampler2D brockhouse_surface : filter_linear_mipmap, repeat_disable;
uniform vec4 brockhouse_bounds = vec4(0.0);
varying vec3 coordinates;
varying float upness;

float patch(vec2 p) {
	vec2 q = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 x = q.x + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 y = q.y + vec4(0.0, 0.0, 1.0, 1.0);
	vec4 s = fract(sin(x * 83.7 + y * 39.4) * 4378.24);
	return mix(mix(s.x, s.y, f.x), mix(s.z, s.w, f.x), f.y);
}

void vertex() {
	coordinates = VERTEX;
	upness = NORMAL.y;
}

void fragment() {
	vec2 p = coordinates.xz;
	vec2 region = p + vec2(coordinates.y * 0.29, coordinates.y * 0.67);
	float variation = patch(p * 0.083);
	float mottling = patch(p * 0.38 + 11.4);
	float worn = smoothstep(0.31, 0.76, variation * 0.63 + mottling * 0.37);
	float grass = smoothstep(0.18, 0.93, coordinates.y) * smoothstep(0.71, 0.96, upness);
	vec3 grit = texture(riverbank, region / 2.3).rgb;
	vec3 soil = mix(vec3(0.43, 0.375, 0.291), grit, 0.62);
	float lawn = material_luminance(texture(grass_scan, region / 1.85).rgb);
	vec3 blades = mix(vec3(0.265, 0.354, 0.174), vec3(0.415, 0.451, 0.254), worn);
	blades *= 0.52 + lawn * 1.05;
	ALBEDO = mix(soil, blades, grass) * (0.87 + 0.25 * variation);
	float distance_fade = smoothstep(96.0, 870.0, length(VERTEX));
	ALBEDO = mix(ALBEDO, COLOR.rgb * (0.89 + 0.22 * variation), distance_fade * 0.82);
	if (town_bounds.z > 0.0) {
		vec2 uv = (p - town_bounds.xy) / town_bounds.zw;
		vec2 bounds = min(uv, 1.0 - uv);
		float edge = min(bounds.x, bounds.y);
		if (edge > 0.0) {
			vec3 color = texture(town_ground, uv).rgb;
			float dry = smoothstep(0.03, 0.62, coordinates.y);
			float photo = smoothstep(0.0, 0.07, edge);
			ALBEDO = mix(ALBEDO, grit * 0.88, photo * (1.0 - dry));
			ALBEDO = mix(ALBEDO, color, photo * dry * mix(0.19, 0.65, distance_fade));
		}
	}
	ALBEDO *= mix(0.65, 1.0, smoothstep(-0.16, 0.36, coordinates.y));
	ROUGHNESS = mix(0.75, 0.98, smoothstep(-0.08, 0.42, coordinates.y));
	float apron = marina_gravel_mask(p) * smoothstep(.04, .29, coordinates.y);
	if (apron > .001) {
		ALBEDO = mix(ALBEDO, marina_gravel(p), apron);
		grass *= 1.0 - apron;
	}
	vec4 lamure = lamure_coverage(p);
	if (lamure.r > .001) {
		float damp = 1.0 - smoothstep(.02, .65, coordinates.y + (mottling - .5) * .095);
		vec3 sand = beach_sand(p, damp) * mix(.90, 1.08, mottling);
		if (lamure.a > .001) {
			float litter = .72 * lamure.a * smoothstep(.22, .74, variation * .60 + mottling * .40);
			sand = mix(sand, texture(lamure_litter, p / 2.0).rgb, litter);
		}
		ALBEDO = mix(ALBEDO, sand, lamure.r);
		ROUGHNESS = mix(ROUGHNESS, mix(.67, .97, 1.0 - damp), lamure.r);
	}
	if (lamure.g > .001) {
		vec3 limestone = mix(concrete_color(p), grit, .44) * vec3(.90, .898, .855);
		ALBEDO = mix(ALBEDO, limestone, lamure.g);
	}
	grass *= 1.0 - max(lamure.r, lamure.g);
	if (paving_bounds.z > 0.0) {
		vec2 uv = (p - paving_bounds.xy) / paving_bounds.zw;
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			vec2 paving = texture(town_paving, uv).rg;
			if (paving.r > .001) {
				ALBEDO = mix(ALBEDO, weathered_asphalt(p, length(VERTEX)), paving.r);
			}
			ALBEDO = mix(ALBEDO, concrete_color(p), paving.g);
			grass *= 1.0 - max(paving.r, paving.g);
		}
	}
	if (station_bounds.z > 0.0) {
		vec2 uv = (p - station_bounds.xy) / station_bounds.zw;
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			float paving = texture(station_paving, uv).b;
			vec3 gravel_yard = mix(concrete_color(p), grit, 0.56);
			ALBEDO = mix(ALBEDO, gravel_yard, paving);
			grass *= 1.0 - paving;
		}
	}
	if (brockhouse_bounds.z > 0.0) {
		vec2 uv = (p - brockhouse_bounds.xy) / brockhouse_bounds.zw;
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			vec3 campus = texture(brockhouse_surface, uv).rgb;
			vec3 grit_shoulder = mix(concrete_color(p), grit, .57) * vec3(.86, .82, .73);
			vec3 sidewalk = concrete_color(p) * mix(.78, .94, mottling);
			ALBEDO = mix(ALBEDO, grit_shoulder, campus.b);
			if (campus.r > .001) {
				ALBEDO = mix(ALBEDO, weathered_asphalt(p, length(VERTEX)), campus.r);
			}
			ALBEDO = mix(ALBEDO, sidewalk, campus.g);
			grass *= 1.0 - max(max(campus.r, campus.g), campus.b);
		}
	}
	if (riverbank_path_bounds.z > 0.0) {
		vec2 uv = (p - riverbank_path_bounds.xy) / riverbank_path_bounds.zw;
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			vec3 path = texture(riverbank_path_mask, uv).rgb;
			float edge = .10 * (patch(p * 3.8) - .5);
			float gravel = smoothstep(.13 + edge, .74 + edge, path.r);
			float pavers = smoothstep(.15, .80, path.g);
			float shoulder = path.b * mix(.15, .66, mottling);
			vec3 screened = mix(concrete_color(p), grit, .46) * vec3(.91, .88, .80);
			ALBEDO = mix(ALBEDO, soil * .80, shoulder);
			ALBEDO = mix(ALBEDO, screened, gravel);
			vec2 blocks = vec2(dot(p, vec2(.35, .93675)), dot(p, vec2(-.93675, .35))) / vec2(.24, .15);
			float width = max(fwidth(blocks.x), fwidth(blocks.y));
			float block_detail = 1.0 - smoothstep(.09, .32, width);
			blocks.x += .5 * mod(floor(blocks.y), 2.0);
			vec2 joint = min(fract(blocks), 1.0 - fract(blocks));
			float mortar = (1.0 - smoothstep(.016, .034 + width * .55, min(joint.x, joint.y))) * block_detail;
			float tone = .91 + (patch(floor(blocks) + 7.4) - .5) * .23 * block_detail;
			vec3 stone = concrete_color(p) * vec3(.83, .85, .83) * mix(tone, .52, mortar * .59);
			ALBEDO = mix(ALBEDO, stone, pavers);
			grass *= 1.0 - max(max(gravel, pavers), shoulder);
		}
	}
	float detail = grass * (1.0 - smoothstep(42.0, 110.0, length(VERTEX)));
	if (detail > .005) {
		vec2 relief = texture(grass_normal, region / 1.85).rg * 2.0 - 1.0;
		vec3 tangent = normalize(VIEW_MATRIX[0].xyz - NORMAL * dot(VIEW_MATRIX[0].xyz, NORMAL));
		vec3 bitangent = cross(tangent, NORMAL);
		NORMAL = normalize(NORMAL + (tangent * relief.x - bitangent * relief.y) * .35 * detail);
	}
}
