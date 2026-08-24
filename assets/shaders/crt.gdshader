shader_type canvas_item;

// CRT-tilstand fra afsnit 12: scanlines, vignette og 1 px fringing.
// Nostalgi som tilvalg, moderne som standard, så den er slukket fra start.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 resolution = vec2(390.0, 844.0);
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.9;
uniform float fringe_px : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 texel = vec2(1.0) / resolution;

	// Farvekanalerne skubbes en pixel fra hinanden, som et gammelt rør.
	float r = texture(screen_tex, uv + vec2(texel.x * fringe_px, 0.0)).r;
	vec3 mid = texture(screen_tex, uv).rgb;
	float b = texture(screen_tex, uv - vec2(texel.x * fringe_px, 0.0)).b;
	vec3 col = vec3(r, mid.g, b);

	// Hver anden linje er dæmpet.
	float line = step(1.0, mod(UV.y * resolution.y, 2.0));
	col *= 1.0 - scanline_strength * line;

	// Hjørnerne falder af.
	vec2 c = uv - vec2(0.5);
	col *= clamp(1.0 - dot(c, c) * vignette_strength, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}
