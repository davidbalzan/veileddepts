shader_type spatial;

// Wetness shader for terrain and surfaces during rain
// Adds darkening, glossiness, and puddle reflections

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

// Wetness control
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float wetness_strength : hint_range(0.0, 2.0) = 1.0;
uniform float puddle_threshold : hint_range(0.0, 1.0) = 0.5;

// Surface properties
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.5;

// Puddle noise (for variation)
uniform sampler2D puddle_noise : hint_default_white, repeat_enable;
uniform float puddle_scale : hint_range(0.1, 10.0) = 2.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV = UV * uv_scale;
}

void fragment() {
	// Sample base textures
	vec4 albedo = texture(albedo_texture, UV);
	vec3 normal = texture(normal_map, UV).rgb;
	float roughness = texture(roughness_texture, UV).r;
	
	// Sample puddle noise for variation
	vec2 puddle_uv = world_pos.xz * puddle_scale * 0.1;
	float puddle_mask = texture(puddle_noise, puddle_uv).r;
	
	// Calculate wetness effect
	float wet_factor = wetness * wetness_strength;
	
	// Darken wet areas (water absorption)
	vec3 wet_albedo = albedo.rgb * (1.0 - wet_factor * 0.3);
	
	// Create puddles in low areas
	float puddle_amount = smoothstep(puddle_threshold, puddle_threshold + 0.2, puddle_mask);
	puddle_amount *= wet_factor;
	
	// Wet surfaces are more reflective (lower roughness)
	float wet_roughness = mix(roughness, 0.05, wet_factor);
	wet_roughness = mix(wet_roughness, 0.01, puddle_amount);  // Puddles very smooth
	
	// Puddles reflect more light
	vec3 puddle_color = mix(wet_albedo, wet_albedo * 1.3, puddle_amount);
	
	// Output
	ALBEDO = puddle_color;
	NORMAL_MAP = normal;
	ROUGHNESS = wet_roughness;
	SPECULAR = mix(specular_intensity, 1.0, wet_factor * 0.5);
	METALLIC = mix(0.0, 0.1, puddle_amount);  // Slight metallic for reflections
}
