shader_type canvas_item;

// Soft radial vignette overlay for the play field. Darkens the edges of
// the 1280×720 viewport while keeping the path / tower area bright,
// adding cinematic polish to AI-generated map art without redoing the
// textures. Applied to a full-screen ColorRect drawn at z_index -88 so
// it sits above the FloorWash but below all gameplay sprites.

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.42;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.86;
uniform vec4 tint : source_color = vec4(0.03, 0.02, 0.0, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	// Keep aspect ratio so the vignette is elliptical in 16:9.
	d.x *= 1.78;
	float dist = length(d);
	float falloff = smoothstep(inner_radius, outer_radius, dist);
	COLOR = vec4(tint.rgb, falloff * strength);
}
