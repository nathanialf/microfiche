// Phosphor glow effect for text elements
// Simulates the bloom of CRT phosphor dots

shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 3.0) = 1.2;
uniform float glow_radius : hint_range(0.0, 8.0) = 2.0;
uniform vec4 glow_color : source_color = vec4(0.98, 0.72, 0.12, 1.0);

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);

	// Sample surrounding pixels for glow
	vec4 glow = vec4(0.0);
	float total = 0.0;
	int steps = 4;

	for (int x = -steps; x <= steps; x++) {
		for (int y = -steps; y <= steps; y++) {
			float dist = length(vec2(float(x), float(y)));
			if (dist > float(steps)) continue;
			float weight = 1.0 - (dist / float(steps));
			weight = weight * weight;
			vec2 offset = vec2(float(x), float(y)) * glow_radius * TEXTURE_PIXEL_SIZE;
			glow += texture(TEXTURE, UV + offset) * weight;
			total += weight;
		}
	}

	glow /= total;
	glow.rgb *= glow_color.rgb;

	// Combine
	vec4 result = base_color + glow * glow_strength * (1.0 - base_color.a);
	COLOR = result;
}
