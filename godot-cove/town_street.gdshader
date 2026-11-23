shader_type spatial;

#include "res://river_surfaces.gdshaderinc"
#include "res://road_asphalt.gdshaderinc"

uniform bool parking_lot = false;
uniform vec4 parking_bays = vec4(0.0);
uniform vec2 parking_aisle = vec2(0.0);
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float paint_line(float value, float half_width) {
	float blur = max(.003, fwidth(value) * .65);
	return (1.0 - smoothstep(max(0.0, half_width - blur), half_width + blur, abs(value)))
		* min(1.0, half_width / blur);
}

void fragment() {
	float eye = length(VERTEX);
	vec3 asphalt = weathered_asphalt(world_xz, eye);
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
		float gravel = marina_gravel_mask(world_xz);
		asphalt = mix(asphalt, marina_gravel(world_xz), gravel);
		float style = round(COLOR.r * 3.0);
		float dash = abs(mod(UV.y + 1.2, 9.0) - 4.5);
		float broken = 1.0 - smoothstep(1.43, 1.49 + fwidth(UV.y), dash);
		yellow = paint_line(UV.x, .060) * step(.5, style) * mix(1.0, broken, step(1.5, style)) * UV2.x;
		white = paint_line(abs(UV.x) - 3.13, .055) * COLOR.g * UV2.x;
		if (style > 2.5) {
			yellow = paint_line(abs(UV.x) - .135, .064) * UV2.x;
			white = paint_line(abs(UV.x) - 5.11, .072) * COLOR.g * UV2.x;
		}
		if (COLOR.a < .5) {
			asphalt = mix(asphalt, vec3(.265, .241, .213), .22);
			float offset = abs(UV.x);
			// The left and right rows angle forward in their respective lanes.
			float bay = (UV.y + sign(UV.x) * (offset - 3.5) * .59 - 27.0) / 3.25;
			float divider = (fract(bay + .5) - .5) * 3.25;
			float stripe = paint_line(divider, .061);
			float inside_bay = step(3.55, offset) * step(offset, 8.54);
			float block = step(25.0, UV.y) * step(UV.y, 102.0) * step(0.0, bay + .02) * step(bay, 22.02);
			// Keep the civic sidewalk connection clear of parking stalls.
			float bay_start = 27.0 + floor(bay + .5) * 3.25;
			float entrance = step(50.0, bay_start) * step(bay_start, 57.0) * step(UV.x, 0.0);
			white = max(white, stripe * inside_bay * block * (1.0 - entrance) * UV2.x);
		}
		float walk = max(paint_line(UV2.y - 6.35, .10), paint_line(UV2.y - 8.35, .10));
		float stop = paint_line(UV2.y - 9.55, .14) * step(.14, UV.x);
		white = max(white, max(walk, stop) * (1.0 - step(3.22, abs(UV.x))));
		yellow *= 1.0 - gravel;
		white *= 1.0 - gravel;
	}
	float wear = worn_road_paint(world_xz);
	ALBEDO = mix(asphalt, vec3(.76, .54, .18), yellow * wear);
	ALBEDO = mix(ALBEDO, vec3(.87, .86, .81), white * wear);
	NORMAL = road_relief(world_xz, NORMAL, VIEW_MATRIX[0].xyz, eye);
	ROUGHNESS = mix(.93, .99, road_noise(world_xz * .48));
	SPECULAR = .17;
}
