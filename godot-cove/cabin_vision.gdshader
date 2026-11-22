shader_type canvas_item;

uniform sampler2D view : hint_screen_texture, filter_linear, repeat_disable;
uniform float high = 0.0;
uniform float drunk = 0.0;
uniform float hangover = 0.0;
uniform float clock = 0.0;

void fragment() {
	vec2 at = SCREEN_UV;
	vec2 offset = at - .5;
	float radius = length(offset * vec2(1.25, 1.0));
	vec2 drift = vec2(cos(clock * .89 + at.y * 3.2), sin(clock * 1.16 + at.x * 4.3));
	at += drift * (.0035 * drunk + .0011 * high) * (.38 + radius);
	at += offset * high * .021 * sin(clock * 1.32 + radius * 3.4);
	vec2 fringe = (offset + drift * .11) * (.007 * drunk + .0014 * high);
	vec3 world = texture(view, at).rgb;
	world.r = mix(world.r, texture(view, at + fringe).r, drunk * .68 + high * .19);
	world.b = mix(world.b, texture(view, at - fringe).b, drunk * .68 + high * .19);
	float gray = dot(world, vec3(.2126, .7152, .0722));
	world = mix(vec3(gray), world, 1.0 + high * .27 - hangover * .26);
	world += high * vec3(.025, .011, .013) * (1.0 - gray);
	float corners = smoothstep(.31, .78, radius);
	world *= 1.0 - corners * (.25 * drunk + .12 * high + .22 * hangover);
	COLOR = vec4(world, 1.0);
}
