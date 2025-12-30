shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Heightmap and terrain parameters
uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform vec2 terrain_size = vec2(1024.0, 1024.0);
uniform float height_scale = 300.0;
uniform float min_height = -200.0;
uniform float sea_level = 0.0;

// Parallax occlusion mapping parameters
uniform float parallax_scale = 0.05;
uniform int parallax_steps = 16;
uniform bool parallax_enabled = true;

// Terrain colors - height-based biome coloring
uniform vec3 deep_water_color : source_color = vec3(0.05, 0.1, 0.2);
uniform vec3 shallow_water_color : source_color = vec3(0.1, 0.3, 0.4);
uniform vec3 sand_color : source_color = vec3(0.76, 0.7, 0.5);
uniform vec3 grass_color : source_color = vec3(0.2, 0.4, 0.1);
uniform vec3 rock_color : source_color = vec3(0.4, 0.35, 0.3);
uniform vec3 snow_color : source_color = vec3(0.95, 0.95, 0.97);

// Material properties
uniform float roughness_base = 0.8;
uniform float roughness_variation = 0.2;

varying vec3 world_position;
varying float terrain_height;
varying vec3 vertex_normal;

// Get height from heightmap at UV coordinates
float get_height(vec2 uv) {
	return texture(heightmap, uv).r * height_scale + min_height;
}

// Calculate terrain normal from heightmap using central differences
vec3 calculate_normal(vec2 uv, float texel_size) {
	float h_left = get_height(uv - vec2(texel_size, 0.0));
	float h_right = get_height(uv + vec2(texel_size, 0.0));
	float h_down = get_height(uv - vec2(0.0, texel_size));
	float h_up = get_height(uv + vec2(0.0, texel_size));
	
	// Calculate normal from height differences
	vec3 normal = normalize(vec3(
		(h_left - h_right) / (2.0 * texel_size * terrain_size.x),
		1.0,
		(h_down - h_up) / (2.0 * texel_size * terrain_size.y)
	));
	return normal;
}

// Parallax occlusion mapping for enhanced surface detail
vec2 parallax_occlusion_mapping(vec2 uv, vec3 view_dir) {
	if (!parallax_enabled) {
		return uv;
	}
	
	float layer_depth = 1.0 / float(parallax_steps);
	float current_layer_depth = 0.0;
	
	// Calculate UV offset per layer based on view direction
	vec2 delta_uv = view_dir.xz * parallax_scale / float(parallax_steps);
	
	vec2 current_uv = uv;
	float current_depth = texture(heightmap, current_uv).r;
	
	// Ray march through height layers
	for (int i = 0; i < parallax_steps; i++) {
		if (current_layer_depth >= current_depth) {
			break;
		}
		current_uv -= delta_uv;
		current_depth = texture(heightmap, current_uv).r;
		current_layer_depth += layer_depth;
	}
	
	// Binary search refinement for smoother result
	vec2 prev_uv = current_uv + delta_uv;
	float after_depth = current_depth - current_layer_depth;
	float before_depth = texture(heightmap, prev_uv).r - current_layer_depth + layer_depth;
	float weight = after_depth / (after_depth - before_depth);
	
	return mix(current_uv, prev_uv, weight);
}

// Calculate terrain color based on height and slope
vec3 get_terrain_color(float height, float slope) {
	vec3 color;
	
	// Height-based biome selection
	if (height < sea_level - 50.0) {
		// Deep sea floor
		color = deep_water_color;
	} else if (height < sea_level - 10.0) {
		// Shallow sea floor / continental shelf
		float t = (height - (sea_level - 50.0)) / 40.0;
		color = mix(deep_water_color, shallow_water_color, t);
	} else if (height < sea_level + 5.0) {
		// Beach / coastal sand
		float t = (height - (sea_level - 10.0)) / 15.0;
		color = mix(shallow_water_color, sand_color, t);
	} else if (height < sea_level + 30.0) {
		// Lowland grass
		float t = (height - (sea_level + 5.0)) / 25.0;
		color = mix(sand_color, grass_color, t);
	} else if (height < sea_level + 70.0) {
		// Highland rock
		float t = (height - (sea_level + 30.0)) / 40.0;
		color = mix(grass_color, rock_color, t);
	} else {
		// Mountain snow
		float t = clamp((height - (sea_level + 70.0)) / 30.0, 0.0, 1.0);
		color = mix(rock_color, snow_color, t);
	}
	
	// Slope-based rock exposure (steep slopes show rock regardless of height)
	if (slope > 0.5) {
		float rock_blend = smoothstep(0.5, 0.8, slope);
		color = mix(color, rock_color, rock_blend);
	}
	
	return color;
}

void vertex() {
	// Calculate UV from vertex XZ position
	vec2 uv = (VERTEX.xz / terrain_size) + 0.5;
	
	// Sample heightmap and displace vertex vertically
	float height = get_height(uv);
	VERTEX.y = height;
	
	// Store world position and height for fragment shader
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_height = height;
	
	// Calculate and store normal from heightmap
	float texel_size = 1.0 / float(textureSize(heightmap, 0).x);
	vertex_normal = calculate_normal(uv, texel_size);
	NORMAL = vertex_normal;
}

void fragment() {
	// Calculate base UV from world position
	vec2 uv = (world_position.xz / terrain_size) + 0.5;
	
	// Apply parallax occlusion mapping for surface detail
	vec3 view_dir = normalize(VIEW);
	vec2 parallax_uv = parallax_occlusion_mapping(uv, view_dir);
	
	// Get height and calculate normal at parallax-adjusted UV
	float texel_size = 1.0 / float(textureSize(heightmap, 0).x);
	vec3 normal = calculate_normal(parallax_uv, texel_size);
	
	// Calculate slope from normal (0 = flat, 1 = vertical)
	float slope = 1.0 - normal.y;
	
	// Get terrain color based on height and slope
	vec3 color = get_terrain_color(terrain_height, slope);
	
	// Output material properties
	ALBEDO = color;
	ROUGHNESS = roughness_base + roughness_variation * slope;
	METALLIC = 0.0;
	
	// Apply calculated normal
	NORMAL = normalize(mix(NORMAL, normal, 0.5));
}
