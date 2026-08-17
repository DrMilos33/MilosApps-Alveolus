shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color = vec4(0.96, 0.78, 0.42, 1.0);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width : hint_range(1.0, 5.0) = 2.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_width;
	float neighbour_alpha = 0.0;
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(pixel.x, pixel.y)).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	neighbour_alpha = max(neighbour_alpha, texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y)).a);

	float outside = max(neighbour_alpha - base.a, 0.0) * outline_strength;
	vec4 outline = vec4(outline_color.rgb, outline_color.a * outside);
	COLOR = base.a > 0.01 ? base : outline;
}
