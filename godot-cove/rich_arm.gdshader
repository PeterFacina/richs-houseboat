shader_type spatial;
render_mode diffuse_burley, shadows_disabled;

uniform vec4 skin : source_color;
uniform float elbow_angle = -.24;

vec3 bend(vec3 p, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

void vertex() {
	vec3 pivot = vec3(0.0, -.277, 0.0);
	float angle = elbow_angle * (1.0 - smoothstep(-.374, -.215, VERTEX.y));
	VERTEX = pivot + bend(VERTEX - pivot, angle);
	NORMAL = bend(NORMAL, angle);
}

void fragment() {
	float exposure = .97 + .035 * sin(UV.x * TAU) * cos(UV.y * 8.0);
	ALBEDO = skin.rgb * exposure;
	ROUGHNESS = .84;
	SPECULAR = .30;
}
