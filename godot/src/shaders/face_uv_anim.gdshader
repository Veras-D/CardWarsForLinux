shader_type canvas_item;

uniform vec2 uv_offset = vec2(0.0, 0.75);
uniform vec2 uv_scale = vec2(0.25, 0.25);

void fragment() {
    // Convert from Unity bottom-left UV coordinate space to Godot top-left space:
    vec2 offset = vec2(uv_offset.x, 1.0 - uv_offset.y - uv_scale.y);
    vec2 final_uv = offset + UV * uv_scale;
    vec4 tex_col = texture(TEXTURE, final_uv);
    // Key out solid atlas background color (sampled from cell top-left corner)
    vec4 bg_col = texture(TEXTURE, offset + vec2(0.005, 0.005));
    float diff = distance(tex_col.rgb, bg_col.rgb);
    float alpha_mask = smoothstep(0.04, 0.14, diff);
    COLOR = vec4(tex_col.rgb, tex_col.a * alpha_mask);
}
