shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Cloud layer shader with procedural noise
// Provides realistic animated clouds with depth and parallax

uniform sampler2D noise_texture : hint_default_white, repeat_enable;
uniform sampler2D detail_noise : hint_default_white, repeat_enable;

// Cloud parameters
uniform float speed : hint_range(0.0, 1.0) = 0.02;
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 0.5) = 0.2;
uniform float density : hint_range(0.0, 2.0) = 1.0;

// Cloud appearance
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow_color : source_color = vec3(0.5, 0.5, 0.6);
uniform float brightness : hint_range(0.0, 2.0) = 1.2;

// Wind
uniform vec2 wind_direction = vec2(1.0, 0.3);

void fragment() {
	// Use UV coordinates for the quad mesh
	vec2 base_uv = UV;
	
	// Animate with time
	vec2 wind_offset = wind_direction * TIME * speed;
	vec2 cloud_uv = base_uv * 0.5 + wind_offset;  // Scale down for larger clouds
	
	// Sample noise textures
	float noise1 = texture(noise_texture, cloud_uv * 1.0).r;
	float noise2 = texture(noise_texture, cloud_uv * 2.3 + vec2(0.5, 0.3)).r;
	float detail = texture(detail_noise, cloud_uv * 5.0).r;
	
	// Combine noises
	float cloud_pattern = noise1 * 0.7 + noise2 * 0.3;
	cloud_pattern = mix(cloud_pattern, detail, 0.2);
	
	// Apply coverage and softness
	float cloud_alpha = smoothstep(coverage - softness, coverage + softness, cloud_pattern);
	cloud_alpha *= density;
	cloud_alpha = clamp(cloud_alpha, 0.0, 1.0);
	
	// Add depth variation
	float depth_factor = mix(0.7, 1.0, cloud_pattern);
	vec3 final_color = mix(shadow_color, cloud_color, depth_factor) * brightness;
	
	// Output
	ALBEDO = final_color;
	ALPHA = cloud_alpha * 0.7;  // Semi-transparent
	
	// Fade out edges of quad
	vec2 edge_fade = abs(UV - 0.5) * 2.0;
	float edge_alpha = (1.0 - max(edge_fade.x, edge_fade.y));
	edge_alpha = smoothstep(0.0, 0.3, edge_alpha);
	ALPHA *= edge_alpha;
}
