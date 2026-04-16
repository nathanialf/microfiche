// CRT scanline effect for the terminal screen
// Adds rolling scanlines, subtle distortion, and vignette darkening

shader_type canvas_item;

uniform float speed : hint_range(0.0, 100.0) = 30.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.04;
uniform float line_count : hint_range(50.0, 600.0) = 240.0;
uniform float distortion : hint_range(0.0, 0.05) = 0.003;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float flicker_intensity : hint_range(0.0, 0.1) = 0.015;
uniform vec4 tint : source_color = vec4(0.98, 0.75, 0.15, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;

	// Barrel distortion (CRT curvature)
	vec2 centered = uv * 2.0 - 1.0;
	float dist = dot(centered, centered);
	vec2 distorted_uv = uv + centered * dist * distortion;

	// Scanline pattern
	float scanline = sin(distorted_uv.y * line_count * PI + TIME * speed) * 0.5 + 0.5;
	scanline = pow(scanline, 1.2);
	float scanline_dark = 1.0 - scanline * intensity;

	// Vignette
	vec2 vig_uv = uv * (1.0 - uv);
	float vignette = vig_uv.x * vig_uv.y * 15.0;
	vignette = pow(vignette, vignette_strength);
	vignette = clamp(vignette, 0.0, 1.0);

	// Screen flicker
	float flicker = 1.0 - (sin(TIME * flicker_speed) * 0.5 + 0.5) * flicker_intensity;

	// Sample screen
	vec4 screen_color = texture(TEXTURE, distorted_uv);

	// Apply CRT amber tint
	screen_color.rgb = mix(screen_color.rgb, screen_color.rgb * tint.rgb, 0.3);

	// Apply effects
	screen_color.rgb *= scanline_dark * vignette * flicker;

	COLOR = screen_color;
}
