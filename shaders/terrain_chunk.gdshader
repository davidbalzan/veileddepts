shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Textures
uniform sampler2D biome_map : filter_nearest, repeat_disable;
uniform sampler2D bump_map : filter_linear, repeat_enable;

// Parameters
uniform float chunk_size = 512.0;
uniform float sea_level = 0.0;
uniform float bump_strength = 1.0;
uniform float underwater_visibility = 50.0;  // Distance in meters for underwater darkening

// Biome colors (matching BiomeType enum)
// 0: DEEP_WATER
const vec3 DEEP_WATER_COLOR = vec3(0.05, 0.1, 0.2);
const float DEEP_WATER_ROUGHNESS = 0.3;
const float DEEP_WATER_METALLIC = 0.0;

// 1: SHALLOW_WATER
const vec3 SHALLOW_WATER_COLOR = vec3(0.1, 0.3, 0.4);
const float SHALLOW_WATER_ROUGHNESS = 0.2;
const float SHALLOW_WATER_METALLIC = 0.0;

// 2: BEACH
const vec3 BEACH_COLOR = vec3(0.76, 0.7, 0.5);
const float BEACH_ROUGHNESS = 0.9;
const float BEACH_METALLIC = 0.0;

// 3: CLIFF
const vec3 CLIFF_COLOR = vec3(0.4, 0.35, 0.3);
const float CLIFF_ROUGHNESS = 0.95;
const float CLIFF_METALLIC = 0.0;

// 4: GRASS
const vec3 GRASS_COLOR = vec3(0.2, 0.4, 0.1);
const float GRASS_ROUGHNESS = 0.85;
const float GRASS_METALLIC = 0.0;

// 5: ROCK
const vec3 ROCK_COLOR = vec3(0.4, 0.35, 0.3);
const float ROCK_ROUGHNESS = 0.9;
const float ROCK_METALLIC = 0.0;

// 6: SNOW
const vec3 SNOW_COLOR = vec3(0.95, 0.95, 0.97);
const float SNOW_ROUGHNESS = 0.7;
const float SNOW_METALLIC = 0.0;

varying vec3 world_position;
varying vec2 world_uv;
varying float vertex_height;

// Get biome properties
void get_biome_properties(float biome_id, out vec3 color, out float roughness, out float metallic) {
	int biome = int(biome_id * 255.0 + 0.5);
	
	if (biome == 0) {
		color = DEEP_WATER_COLOR;
		roughness = DEEP_WATER_ROUGHNESS;
		metallic = DEEP_WATER_METALLIC;
	} else if (biome == 1) {
		color = SHALLOW_WATER_COLOR;
		roughness = SHALLOW_WATER_ROUGHNESS;
		metallic = SHALLOW_WATER_METALLIC;
	} else if (biome == 2) {
		color = BEACH_COLOR;
		roughness = BEACH_ROUGHNESS;
		metallic = BEACH_METALLIC;
	} else if (biome == 3) {
		color = CLIFF_COLOR;
		roughness = CLIFF_ROUGHNESS;
		metallic = CLIFF_METALLIC;
	} else if (biome == 4) {
		color = GRASS_COLOR;
		roughness = GRASS_ROUGHNESS;
		metallic = GRASS_METALLIC;
	} else if (biome == 5) {
		color = ROCK_COLOR;
		roughness = ROCK_ROUGHNESS;
		metallic = ROCK_METALLIC;
	} else if (biome == 6) {
		color = SNOW_COLOR;
		roughness = SNOW_ROUGHNESS;
		metallic = SNOW_METALLIC;
	} else {
		// Default fallback
		color = vec3(0.5);
		roughness = 0.8;
		metallic = 0.0;
	}
}

// Blend between biomes for smooth transitions
vec3 blend_biomes(vec2 uv, sampler2D biome_tex) {
	// Sample biome at current position
	float center_biome = texture(biome_tex, uv).r;
	
	// Sample neighboring biomes for blending
	vec2 texel_size = 1.0 / vec2(textureSize(biome_tex, 0));
	float biome_n = texture(biome_tex, uv + vec2(0.0, texel_size.y)).r;
	float biome_s = texture(biome_tex, uv - vec2(0.0, texel_size.y)).r;
	float biome_e = texture(biome_tex, uv + vec2(texel_size.x, 0.0)).r;
	float biome_w = texture(biome_tex, uv - vec2(texel_size.x, 0.0)).r;
	
	// If all neighbors are the same, no blending needed
	if (center_biome == biome_n && center_biome == biome_s && 
	    center_biome == biome_e && center_biome == biome_w) {
		vec3 color;
		float roughness, metallic;
		get_biome_properties(center_biome, color, roughness, metallic);
		return color;
	}
	
	// Blend with neighbors
	vec3 color_center, color_n, color_s, color_e, color_w;
	float r_center, r_n, r_s, r_e, r_w;
	float m_center, m_n, m_s, m_e, m_w;
	
	get_biome_properties(center_biome, color_center, r_center, m_center);
	get_biome_properties(biome_n, color_n, r_n, m_n);
	get_biome_properties(biome_s, color_s, r_s, m_s);
	get_biome_properties(biome_e, color_e, r_e, m_e);
	get_biome_properties(biome_w, color_w, r_w, m_w);
	
	// Simple average blend
	vec3 blended_color = (color_center * 4.0 + color_n + color_s + color_e + color_w) / 8.0;
	
	return blended_color;
}

void vertex() {
	// Store world position for fragment shader
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_uv = UV;
	vertex_height = VERTEX.y;
}

void fragment() {
	// Sample biome map with blending
	vec2 biome_uv = world_uv;
	float biome_id = texture(biome_map, biome_uv).r;
	
	// Get biome properties
	vec3 base_color;
	float base_roughness;
	float base_metallic;
	get_biome_properties(biome_id, base_color, base_roughness, base_metallic);
	
	// Apply biome blending for smooth transitions
	vec3 blended_color = blend_biomes(biome_uv, biome_map);
	
	// Sample bump map for detail
	vec2 bump_uv = world_position.xz / 10.0; // Tile bump map every 10 meters
	vec3 bump_normal = texture(bump_map, bump_uv).rgb;
	bump_normal = bump_normal * 2.0 - 1.0; // Convert from [0,1] to [-1,1]
	bump_normal.xy *= bump_strength;
	bump_normal = normalize(bump_normal);
	
	// Blend bump normal with surface normal
	vec3 final_normal = normalize(NORMAL + bump_normal * 0.3);
	
	// Underwater rendering effects
	float depth_factor = 1.0;
	if (world_position.y < sea_level) {
		float depth = sea_level - world_position.y;
		
		// Gentler exponential darkening - increase visibility range for gameplay
		// Using 150m visibility instead of 50m for better seabed visibility
		float effective_visibility = underwater_visibility * 3.0;
		depth_factor = exp(-depth / effective_visibility);
		
		// Ensure minimum visibility (don't go completely black)
		depth_factor = max(depth_factor, 0.25);
		
		// Add blue tint for underwater
		vec3 water_tint = vec3(0.3, 0.5, 0.7);
		blended_color = mix(blended_color * water_tint, blended_color, depth_factor);
		
		// Increase roughness underwater (less specular)
		base_roughness = min(1.0, base_roughness + 0.2);
	}
	
	// Apply depth darkening
	vec3 final_color = blended_color * depth_factor;
	
	// Output
	ALBEDO = final_color;
	ROUGHNESS = base_roughness;
	METALLIC = base_metallic;
	NORMAL = final_normal;
}
