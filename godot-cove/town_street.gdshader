shader_type spatial;

#include "res://river_surfaces.gdshaderinc"
#include "res://road_asphalt.gdshaderinc"
#include "res://road_gravel.gdshaderinc"

// Matches RoadSurface in deep_river_roads.gd.
const int CHAMPLAIN_SURFACE = 0;
const int BROCKHOUSE_SURFACE = 1;
const int CEDAR_SURFACE = 2;
const int YARD_DRIVE_SURFACE = 3;
const float STANDARD_SURFACE = 4.0;
const vec4 SILVIE_APPROACH = vec4(18475.5, 13812.15, -.8252, .5649);
const vec4 GLENDALE_STOP_BAR = vec4(17974.76, 13436.25, -.0206, .9998);

uniform vec2 champlain_access = vec2(0.0);
uniform vec4 champlain_bays = vec4(24.0, 3.25, .59, 3.5);
uniform bool parking_lot = false;
uniform vec4 parking_bays = vec4(0.0);
uniform vec2 parking_aisle = vec2(0.0);
// xy is the center of the marking. zw is its unit axis along the road.
uniform vec4 laurier_crossing = vec4(0.0);
uniform vec4 deep_river_crossing = vec4(0.0);
varying vec2 world_xz;
varying vec4 verge_and_wear;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	verge_and_wear = CUSTOM0;
}

float paint_line(float value, float half_width) {
	float blur = max(.003, fwidth(value) * .65);
	return (1.0 - smoothstep(max(0.0, half_width - blur), half_width + blur, abs(value)))
		* min(1.0, half_width / blur);
}

float road_section(float station, float start, float end, float taper) {
	return smoothstep(start, start + taper, station) * (1.0 - smoothstep(end - taper, end, station));
}

vec2 crossing_coordinates(vec2 world, vec4 crossing) {
	vec2 from_center = world - crossing.xy;
	vec2 axis = crossing.zw;
	return vec2(dot(from_center, vec2(-axis.y, axis.x)), dot(from_center, axis));
}

float reference_repairs(vec2 world) {
	// May 2025 views show a meandering seam across Silvie and a longitudinal repair on Laurier.
	if (distance(world, SILVIE_APPROACH.xy) < 5.0) {
		vec2 at = crossing_coordinates(world, SILVIE_APPROACH);
		float bend = (road_noise(world * 2.8) - .5) * .22 + at.x * .34;
		return paint_line(at.y - bend, .021) * (1.0 - smoothstep(1.85, 3.05, abs(at.x))) * .24;
	}
	if (distance(world, laurier_crossing.xy) < 8.0) {
		vec2 at = crossing_coordinates(world, laurier_crossing);
		float bend = (road_noise(world * 2.3) - .5) * .34 + at.y * .08;
		return paint_line(at.x - bend + .36, .016) * (1.0 - smoothstep(4.0, 6.7, abs(at.y))) * .29;
	}
	return 0.0;
}

float cedar_wear(vec2 road_uv, vec2 world) {
	float approach = road_section(road_uv.y, 178.0, 316.0, 17.0);
	float mottling = road_noise(world * .44);
	float seam = road_uv.x + .62 + (mottling - .5) * .36;
	float seal = paint_line(seam, .027) * smoothstep(.24, .62, mottling);
	float patch = 1.0 - smoothstep(.78, 1.0, max(
		abs(road_uv.x - 1.45 + (mottling - .5) * .38) / 1.01, abs(road_uv.y - 256.0) / 4.2));
	float edge_dust = smoothstep(1.85, 3.40, abs(road_uv.x) + (mottling - .5) * .65);
	return approach * (.12 * mottling + .14 * edge_dust - .23 * seal - .12 * patch);
}

vec3 yard_drive_dust(vec2 road_uv, vec2 world) {
	float mottling = road_noise(world * .47);
	float track = 1.0 - smoothstep(.20, .72, abs(abs(road_uv.x) - 1.00));
	// Keep the paving visible while dust builds up toward the gravel yard.
	float dust = smoothstep(5.0, 54.0, road_uv.y) * mix(.65, 1.0, mottling);
	return dust * (1.0 - track * .78) * vec3(.22, .17, .11);
}

void fragment() {
	float eye = length(VERTEX);
	int road_surface = int(round(COLOR.a * STANDARD_SURFACE));
	float school_paving = 0.0;
	if (road_surface == BROCKHOUSE_SURFACE) {
		school_paving = road_section(UV.y, 265.0, 475.0, 16.0) *
			(1.0 - smoothstep(2.68, 3.40, abs(UV.x)));
	}
	vec2 blocks = abs(world_xz - vec2(18028., 13364.)) / vec2(67., 71.);
	float civic = 1.0 - smoothstep(.92, 1.16, max(blocks.x, blocks.y));
	float style = round(COLOR.r * 3.0);
	float road_age = mix(.42, .91, verge_and_wear.z);
	float junction = parking_lot ? 0.0 : verge_and_wear.w;
	float condition = mix(mix(road_age, .46, step(2.5, style)), .10, civic) * mix(1.0, .31, school_paving);
	condition = mix(condition, mix(.54, .10, civic), junction);
	float unpaved = parking_lot ? 0.0 : COLOR.b;
	vec3 asphalt = vec3(0.0);
	if (unpaved < .999) {
		asphalt = weathered_asphalt(world_xz, eye, condition);
		if (road_surface == int(STANDARD_SURFACE) && !parking_lot) {
			float local_age = mix(.93, 1.075, verge_and_wear.z);
			asphalt *= mix(local_age, 1.0, max(max(civic, step(2.5, style)), junction));
			asphalt *= 1.0 - reference_repairs(world_xz);
		}
	}
	asphalt = mix(asphalt, vec3(.265, .241, .213), civic * .20);
	float yellow = 0.0;
	float white = 0.0;
	if (parking_lot) {
		// UV is measured from the frontage in metres.
		float bay = (UV.x - parking_bays.x) / parking_bays.y;
		float spaces = step(-.03, bay) * step(bay, parking_bays.z + .03);
		float stripes = step(parking_bays.w + .23, UV.y) * step(UV.y, parking_aisle.y);
		float divider = (fract(bay + .5) - .5) * parking_bays.y;
		float crossing = step(parking_aisle.x + .30, UV.x)
			* step(UV.x, parking_aisle.x + parking_bays.y - .30)
			* step(parking_bays.w + .28, UV.y) * step(UV.y, parking_aisle.y);
		float bar = mod(UV.y - parking_bays.w - .33, .68) - .08;
		white = max(spaces * stripes * paint_line(divider, .055), crossing * paint_line(bar, .08));
	} else {
		float apron = marina_gravel_mask(world_xz);
		if (road_surface == CEDAR_SURFACE) {
			asphalt *= 1.0 + cedar_wear(UV, world_xz) * (1.0 - junction);
		} else if (road_surface == YARD_DRIVE_SURFACE) {
			asphalt *= 1.0 + yard_drive_dust(UV, world_xz) * (1.0 - junction);
		} else if (school_paving > 0.0) {
			// A faint longitudinal paving join and fewer patches near the school.
			float mottling = road_noise(world_xz * .37);
			float join = paint_line(UV.x + .17 + (mottling - .5) * .09, .022);
			asphalt *= 1.0 - school_paving * (.09 + .04 * mottling + .09 * join) * (1.0 - junction);
		}
		if (unpaved > .001) {
			vec3 loose_gravel = mix(road_gravel(world_xz, UV.x, 3.4), gravel_color(world_xz), junction);
			asphalt = mix(asphalt, loose_gravel, unpaved);
		}
		if (verge_and_wear.y > .01) {
			float distance_to_edge = verge_and_wear.x - abs(UV.x);
			float grit = road_noise(world_xz * 2.7) * .14 + road_noise(world_xz * .59) * .20;
			float dust = (1.0 - smoothstep(-.08, .18 + grit, distance_to_edge));
			asphalt = mix(asphalt, road_verge(world_xz), dust * verge_and_wear.y * .76);
		}
		asphalt = mix(asphalt, marina_gravel(world_xz), apron);
		float gravel = max(apron, unpaved);
		float dash = abs(mod(UV.y + 1.2, 9.0) - 4.5);
		float broken = 1.0 - smoothstep(1.43, 1.49 + fwidth(UV.y), dash);
		yellow = paint_line(UV.x, .060) * step(.5, style) * mix(1.0, broken, step(1.5, style)) * UV2.x;
		white = paint_line(abs(UV.x) - 3.13, .055) * COLOR.g * UV2.x;
		if (style > 2.5) {
			yellow = paint_line(abs(UV.x) - .135, .064) * UV2.x;
			white = paint_line(abs(UV.x) - 5.11, .072) * COLOR.g * UV2.x;
		}
		if (road_surface == CHAMPLAIN_SURFACE) {
			float offset = abs(UV.x);
			float east = 1.0 - step(0.0, UV.x);
			yellow = paint_line(UV.x, .048) * UV2.x * .83;
			// Angle each row in the direction of the adjoining travel lane.
			float bay = (UV.y + sign(UV.x) * (offset - champlain_bays.w) * champlain_bays.z -
				champlain_bays.x) / champlain_bays.y;
			float divider = (fract(bay + .5) - .5) * champlain_bays.y;
			float stripe = paint_line(divider, .055);
			float inside_bay = step(champlain_bays.w, offset) * step(offset, 8.54);
			float bay_start = champlain_bays.x + floor(bay + .5) * champlain_bays.y;
			float block = step(champlain_bays.x - .01, bay_start) *
				step(bay_start, mix(161.0, 103.0, east));
			float civic_walk = step(50.0, bay_start) * step(bay_start, 57.0);
			float driveway = step(abs(bay_start - champlain_access.x), champlain_access.y + 1.6);
			float angled = stripe * inside_bay * block * (1.0 - max(civic_walk, driveway) * east);
			// Use shorter parallel spaces where the plaza return narrows.
			float parallel_end = abs(fract((UV.y - 126.0) / 7.05 + .5) - .5) * 7.05;
			float parallel = step(125.94, UV.y) * step(UV.y, 147.22) * east *
				max(paint_line(parallel_end, .054) * step(3.46, offset) * step(offset, 5.02),
					paint_line(offset - 3.49, .054) * step(parallel_end, .54));
			white = max(white, max(angled, parallel) * UV2.x);
			// Weathered paving at the west storefront bays. The long repair follows
			// the bay ends and tapers out before the adjoining frontages.
			float along_frontage = UV.y - 49.0;
			float frontage = 1.0 - smoothstep(15.0, 25.0, abs(along_frontage));
			if (frontage > 0.0) {
				float mottling = road_noise(UV * vec2(1.3, .55));
				float seam = UV.x - 3.76 - along_frontage * .021 - (mottling - .5) * .27;
				float bay_age = smoothstep(-.24, .58, seam) * (.07 + .11 * mottling);
				float seal = paint_line(seam, .028) * mix(.44, 1.0, mottling);
				float patch = 1.0 - smoothstep(.82, 1.0, max(
					abs(UV.x - 2.4 + .33 * mottling) / .93, abs(along_frontage - 3.0) / 3.7));
				asphalt *= 1.0 + frontage * (1.0 - gravel) * (bay_age - .29 * seal - .13 * patch) * (1.0 - junction);
				white *= 1.0 - frontage * (1.0 - smoothstep(.05, .27, abs(seam))) * .36;
			}
		}
		float walk = max(paint_line(UV2.y - 6.35, .10), paint_line(UV2.y - 8.35, .10));
		float stop = paint_line(UV2.y - 9.55, .14) * step(.14, UV.x);
		white = max(white, max(walk, stop) * (1.0 - step(3.22, abs(UV.x))));
		yellow *= 1.0 - gravel;
		white *= 1.0 - gravel;
		if (distance(world_xz, GLENDALE_STOP_BAR.xy) < 4.0) {
			vec2 at = crossing_coordinates(world_xz, GLENDALE_STOP_BAR);
			float lane = smoothstep(-3.32, -3.21, at.x) * (1.0 - smoothstep(-.18, -.06, at.x));
			white = max(white, paint_line(at.y, .137) * lane);
		}
		if (distance(world_xz, laurier_crossing.xy) < 5.0) {
			vec2 at = crossing_coordinates(world_xz, laurier_crossing);
			white = max(white, paint_line(abs(at.y) - 1.12, .10)
				* (1.0 - smoothstep(3.0, 3.32, abs(at.x))));
		}
		if (distance(world_xz, deep_river_crossing.xy) < 5.0) {
			vec2 at = crossing_coordinates(world_xz, deep_river_crossing);
			float stripe = paint_line(mod(at.x + at.y * .24, .68) - .34, .15);
			float edge = paint_line(abs(at.y) - 1.12, .075);
			yellow = max(yellow, max(edge, stripe * (1.0 - smoothstep(1.04, 1.14, abs(at.y))))
				* (1.0 - smoothstep(3.03, 3.36, abs(at.x))));
		}
	}
	float wear = worn_road_paint(world_xz);
	ALBEDO = mix(asphalt, vec3(.76, .54, .18), yellow * wear);
	ALBEDO = mix(ALBEDO, vec3(.87, .86, .81), white * wear);
	vec3 asphalt_normal = NORMAL;
	vec3 gravel_detail = NORMAL;
	if (unpaved < .999) {
		asphalt_normal = road_relief(world_xz, NORMAL, VIEW_MATRIX[0].xyz, eye);
	}
	if (unpaved > .001) {
		gravel_detail = gravel_relief(world_xz, NORMAL, VIEW_MATRIX[0].xyz, eye);
	}
	NORMAL = normalize(mix(asphalt_normal, gravel_detail, unpaved));
	ROUGHNESS = mix(mix(.93, .99, road_noise(world_xz * .48)), .995, unpaved);
	SPECULAR = .17;
}
