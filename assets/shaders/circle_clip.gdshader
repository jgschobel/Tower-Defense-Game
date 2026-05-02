shader_type canvas_item;

// Clips the sprite to a soft circle so all tower portraits appear as circular
// frames regardless of whether their source texture has a transparent background.
// Applied to base_tower.gd Sprite2D so both original friend-photo towers and
// newer custom-texture towers (Joe/Justus/Seve) look visually consistent.

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec2 d = UV - vec2(0.5);
	float dist = length(d) * 2.0;  // 0 at center, 1 at inscribed-circle edge
	float mask = 1.0 - smoothstep(0.85, 0.97, dist);
	COLOR = tex_color;
	COLOR.a *= mask;
}
