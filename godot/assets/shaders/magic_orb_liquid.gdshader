shader_type canvas_item;

uniform float fill_level : hint_range(0.0, 1.0) = 1.0;
uniform float idle_amp : hint_range(0.0, 0.08) = 0.032;
uniform float slosh_amp : hint_range(0.0, 0.12) = 0.0;
uniform float wave_phase = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Bottle_Full opaque glass circle spans roughly UV.y in [0.05, 0.95].
	float surface_base = mix(0.95, 0.05, clamp(fill_level, 0.0, 1.0));
	// Dampen wave smoothly near completely empty or completely full.
	float edge_damp = sin(clamp(fill_level, 0.0, 1.0) * 3.14159265);
	float idle_wave = idle_amp * sin(UV.x * 7.2 + TIME * 2.5 + wave_phase)
	                + (idle_amp * 0.45) * cos(UV.x * 12.5 - TIME * 1.9 + wave_phase * 1.7);
	float slosh_wave = slosh_amp * sin(UV.x * 10.5 - TIME * 8.5 + wave_phase);
	float surface_y = surface_base + (idle_wave + slosh_wave) * edge_damp;

	float liquid_mask = smoothstep(surface_y - 0.014, surface_y + 0.014, UV.y);
	float meniscus = exp(-pow((UV.y - surface_y) * 46.0, 2.0)) * edge_damp * (0.55 + slosh_amp * 4.5);
	vec3 col = tex.rgb + vec3(0.46, 0.25, 0.58) * meniscus;

	float visible_mask = step(0.002, fill_level);
	float out_alpha = tex.a * liquid_mask * visible_mask;
	COLOR = vec4(col, out_alpha) * v_modulate;
}
