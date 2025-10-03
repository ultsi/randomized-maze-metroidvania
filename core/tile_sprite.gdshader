shader_type canvas_item;

uniform sampler2D atlas_texture : filter_nearest;
uniform vec2 tile_pos = vec2(0.0);
uniform vec4 tint : source_color;
uniform float tint_amount : hint_range(0, 1, 0.02) = 0.0;

const float atlas_size = 256.0;
const float tile_size = 16.0;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 p = tile_size / atlas_size * tile_pos + UV * tile_size / atlas_size / 4.0;
	COLOR = texture(atlas_texture, p);
	COLOR.rgb = mix(COLOR.rgb, tint.rgb, tint_amount);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
