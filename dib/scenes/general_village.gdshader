shader_type canvas_item;
// Control the blur amount in the inspector
uniform float blur_amount : hint_range(0.0, 5.0);

void fragment() {
    // Use textureLod to blur the texture
    COLOR = textureLod(TEXTURE, UV, blur_amount);
}
