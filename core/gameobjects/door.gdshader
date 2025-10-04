shader_type canvas_item;

uniform sampler2D atlas_texture : filter_nearest;
uniform vec3 color1: source_color;
uniform vec3 color2: source_color;
uniform bool top_down = false;

const float atlas_size = 256.0;
const float tile_size = 16.0;
const vec2 tile_pos = vec2(7.0, 4.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv = UV / 4.0; // for some reason
	vec2 p = tile_size / atlas_size * tile_pos + uv * tile_size / atlas_size;
	COLOR = texture(atlas_texture, p);
	float step_val = top_down ? uv.y : uv.x;
	COLOR.rgb *= mix(color2, color1, step(0.5, step_val)) * 0.8;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
