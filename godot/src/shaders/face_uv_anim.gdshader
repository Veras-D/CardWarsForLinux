shader_type canvas_item;

uniform vec2 uv_offset = vec2(0.0, 0.75);
uniform vec2 uv_scale = vec2(0.25, 0.25);

void fragment() {
    // Convert from Unity bottom-left UV coordinate space to Godot top-left space:
    vec2 offset = vec2(uv_offset.x, 1.0 - uv_offset.y - uv_scale.y);
    vec2 final_uv = offset + UV * uv_scale;
    COLOR = texture(TEXTURE, final_uv);
}
