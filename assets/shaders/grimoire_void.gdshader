// Grimoire Void corruption shader
// Applied to the access-denied screen when void-interred data is detected
// Generates rolling static, chromatic bleed, and void-color distortion

shader_type canvas_item;

uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float corruption_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float static_density : hint_range(0.0, 100.0) = 40.0;
uniform float bleed_strength : hint_range(0.0, 0.05) = 0.008;
uniform vec4 void_color : source_color = vec4(0.04, 0.0, 0.08, 1.0);
uniform vec4 data_color : source_color = vec4(0.45, 0.18, 0.72, 1.0);

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	float t = TIME + time_offset;
	vec2 uv = UV;

	// Horizontal glitch bands
	float band = floor(uv.y * static_density + t * 7.3);
	float glitch = rand(vec2(band, t * 0.3));
	float is_glitch_line = step(0.85, glitch);

	// Horizontal displacement on glitch lines
	float offset_x = (rand(vec2(band * 0.1, t)) - 0.5) * bleed_strength * 8.0 * is_glitch_line;
	vec2 glitch_uv = uv + vec2(offset_x, 0.0);

	// Chromatic aberration
	vec2 ca_offset = vec2(bleed_strength * (1.0 + is_glitch_line * 3.0), 0.0);
	vec4 col_r = texture(TEXTURE, glitch_uv + ca_offset);
	vec4 col_g = texture(TEXTURE, glitch_uv);
	vec4 col_b = texture(TEXTURE, glitch_uv - ca_offset);

	vec4 base = vec4(col_r.r, col_g.g, col_b.b, col_g.a);

	// Rolling void static
	float static_noise = noise(uv * 80.0 + vec2(t * 20.0, t * 7.3));
	float static_val = step(0.5, static_noise) * corruption_intensity * 0.15;

	// Vertical void bleed — dark purple seeping down
	float void_bleed = noise(vec2(uv.x * 3.0, uv.y * 0.5 + t * 0.08)) * 0.4;
	vec4 bleed = void_color * void_bleed;

	// Data signal flicker — bright purple pulses
	float pulse = sin(t * 23.0 + uv.y * 80.0) * 0.5 + 0.5;
	float signal = step(0.97, pulse) * step(0.3, base.r + base.g + base.b);
	vec4 signal_col = data_color * signal * 0.7;

	// Full void replacement on heavy glitch lines
	float void_replace = is_glitch_line * rand(vec2(t * 0.7, band * 0.3));
	base = mix(base, void_color, void_replace * 0.7);

	vec4 result = base + vec4(static_val) + bleed + signal_col;
	result.a = max(base.a, void_bleed * 0.3 + signal * 0.5);

	COLOR = result;
}
