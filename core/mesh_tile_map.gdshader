shader_type canvas_item;
uniform sampler2D atlas_texture : filter_nearest;

const vec3 wall_palette[2] = {
	vec3(15.0/255.0, 21.0/255.0, 35.0/255.0),
	vec3(46.0/255.0, 66.0/255.0, 91.0/255.0)
};

const vec3 floor_palette[2] = {
	vec3(15.0/255.0, 21.0/255.0, 35.0/255.0),
	vec3(41.0/255.0, 46.0/255.0, 39.0/255.0)
};

const float atlas_size = 256.0;
const float tile_size = 16.0;

varying vec4 data;

void vertex() {
	data = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 tint_color = COLOR;
	float x = data.r * 16.0;
	float y = data.g * 16.0;
	int palette_idx = int(round(data.b));
	vec2 p = tile_size / atlas_size * vec2(x,y) + (1.0-UV) * tile_size / atlas_size;
	COLOR = texture(atlas_texture, p);
	int idx = int(round(COLOR.r));
	vec3[2] palette = palette_idx == 0 ? wall_palette : floor_palette;
	COLOR.rgb = palette[idx];
	if (idx > 0) {
		COLOR.rgb = tint_color.rgb;
	}
	COLOR.a = COLOR.a* tint_color.a;
	//COLOR = color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
