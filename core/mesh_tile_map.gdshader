shader_type canvas_item;
uniform sampler2D atlas_texture : filter_nearest;

const float atlas_size = 256.0;
const float tile_size = 16.0;

varying vec4 color;

void vertex() {
	color = INSTANCE_CUSTOM;
}

void fragment() {
	float x = COLOR.r * 255.0;
	float y = COLOR.g * 255.0;
	vec2 p = tile_size / atlas_size * vec2(x,y) + (1.0-UV) * tile_size / atlas_size;
	COLOR = texture(atlas_texture, p);
	//COLOR = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
