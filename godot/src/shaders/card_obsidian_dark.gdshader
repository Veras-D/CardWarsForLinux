shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.08, 0.04, 0.14, 0.98);
uniform vec4 pulse_color : source_color = vec4(0.68, 0.22, 0.95, 0.5);
uniform float speed : hint_range(0.1, 5.0) = 1.8;

void fragment() {
	float radial = distance(UV, vec2(0.5, 0.5));
	float wave = 0.5 + 0.5 * sin(TIME * speed - radial * 6.0);
	float edge = smoothstep(0.15, 0.7, radial);
	vec3 col = mix(base_color.rgb, pulse_color.rgb, wave * edge * pulse_color.a);
	COLOR = vec4(col, base_color.a);
}
