shader_type canvas_item;

// CRT mode from section 12: scanlines, vignette and 1 px fringing.
// Nostalgia is opt-in, modern is the default, so this starts off.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 resolution = vec2(390.0, 844.0);
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.9;
uniform float fringe_px : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = vec2(1.0) / resolution;

	// The colour channels are pushed a pixel apart, like an old tube.
	float r = texture(screen_tex, uv + vec2(texel.x * fringe_px, 0.0)).r;
	vec3 mid = texture(screen_tex, uv).rgb;
	float b = texture(screen_tex, uv - vec2(texel.x * fringe_px, 0.0)).b;
	vec3 col = vec3(r, mid.g, b);

	// Every other line is dimmed.
	float line = step(1.0, mod(UV.y * resolution.y, 2.0));
	col *= 1.0 - scanline_strength * line;

	// The corners fall away.
	vec2 c = uv - vec2(0.5);
	col *= clamp(1.0 - dot(c, c) * vignette_strength, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}
