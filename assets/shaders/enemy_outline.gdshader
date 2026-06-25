shader_type canvas_item;

// Outline + circle-clip in one pass for enemy sprites. The dark outline
// gives enemies the silhouette readability rule that BTD6/KR enforce
// (Mark Brown / GMTK / TF2 reads): every unit must be identifiable from
// 10m by its outline alone. Without this, AI-painted enemies on a busy
// painted background disappear into the noise.
//
// Sampling pattern: 8-tap edge detect against the texture's alpha at
// `outline_radius` UV offset. If a sampled neighbor is transparent
// while the center is not, paint outline color there.

uniform vec4 outline_color : source_color = vec4(0.05, 0.03, 0.02, 1.0);
uniform float outline_radius : hint_range(0.0, 0.02) = 0.012;
uniform bool circle_clip = true;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	// Center alpha
	float a = tex_color.a;

	// 8 neighbor taps for outline detection
	float r = outline_radius;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2( r, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-r, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0,  r)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, -r)).a);
	n = max(n, texture(TEXTURE, UV + vec2( r,  r)).a * 0.85);
	n = max(n, texture(TEXTURE, UV + vec2(-r,  r)).a * 0.85);
	n = max(n, texture(TEXTURE, UV + vec2( r, -r)).a * 0.85);
	n = max(n, texture(TEXTURE, UV + vec2(-r, -r)).a * 0.85);

	// Optional circle clip — keeps the existing tower-style framing
	float mask = 1.0;
	if (circle_clip) {
		vec2 d = UV - vec2(0.5);
		float dist = length(d) * 2.0;
		mask = 1.0 - smoothstep(0.88, 0.99, dist);
	}

	// Background-artifact removal: near-white semi-transparent pixels are
	// residual halos from imperfect background-removal in the art pipeline
	// (#1210). A pixel that is very bright (> 0.88 luminance) AND not fully
	// opaque (a < 0.75) is almost certainly a white-background artifact —
	// discard it before the outline/blend decision so it never contributes
	// to the framebuffer, preventing white halos in dense crowds.
	float lum = dot(tex_color.rgb, vec3(0.2126, 0.7152, 0.0722));
	if (lum > 0.88 && a < 0.75) {
		a = 0.0;
		tex_color.a = 0.0;
	}

	// Blend: where the texture is opaque, draw texture; where it's
	// transparent but a neighbor is opaque, draw the outline color.
	if (a > 0.5) {
		COLOR = vec4(tex_color.rgb, tex_color.a * mask) * COLOR;
	} else {
		float outline_a = (n - a) * mask;
		COLOR = vec4(outline_color.rgb, outline_color.a * outline_a) * COLOR;
	}
}
