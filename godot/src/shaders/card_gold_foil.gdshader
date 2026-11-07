shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.22, 0.17, 0.05, 0.96);
uniform vec4 sheen_color : source_color = vec4(1.0, 0.88, 0.35, 0.55);
uniform float speed : hint_range(0.1, 5.0) = 1.4;
uniform float sheen_width : hint_range(0.05, 0.5) = 0.22;

void fragment() {
	float diag = UV.x * 0.7 + UV.y * 0.3;
	float wave = fract(TIME * speed * 0.35);
	float dist = abs(diag - wave);
	float band = smoothstep(sheen_width, 0.0, dist);
	vec3 col = mix(base_color.rgb, sheen_color.rgb, band * sheen_color.a);
	COLOR = vec4(col, base_color.a);
}
