class_name TerrainRenderer extends Node3D
## Terrain rendering system for procedural coastal and sea floor terrain
## Provides heightmap generation, LOD system, collision detection, and parallax occlusion
## Can integrate with Terrain3D addon when available, or use built-in fallback

# Terrain configuration
@export_group("Terrain Settings")
@export var terrain_size: Vector2i = Vector2i(1024, 1024)  # Size in meters
@export var terrain_resolution: int = 256  # Heightmap resolution (vertices per side)
@export var max_height: float = 100.0  # Maximum terrain height
@export var min_height: float = -200.0  # Minimum terrain height (sea floor)
@export var sea_level: float = 0.0  # Water surface level

@export_group("Noise Settings")
@export var noise_seed: int = 12345
@export var noise_octaves: int = 6
@export var noise_frequency: float = 0.002
@export var noise_lacunarity: float = 2.0
@export var noise_persistence: float = 0.5

@export_group("Micro Detail Settings")
@export var enable_micro_detail: bool = true  # Add fine detail to terrain
@export var micro_detail_scale: float = 2.0  # Height variation in meters for micro detail
@export var micro_detail_frequency: float = 0.05  # Frequency of micro detail noise

@export_group("LOD Settings")
@export var lod_levels: int = 4  # Number of LOD levels
@export var lod_distance_multiplier: float = 2.0  # Distance multiplier between LOD levels
@export var base_lod_distance: float = 100.0  # Distance for first LOD transition

@export_group("Collision Settings")
@export var collision_enabled: bool = true
@export var collision_margin: float = 0.1

# Internal state
var heightmap: Image
var heightmap_texture: ImageTexture
var terrain_mesh: MeshInstance3D
var collision_shape: CollisionShape3D
var static_body: StaticBody3D
var noise: FastNoiseLite
var terrain_material: ShaderMaterial

# LOD meshes
var lod_meshes: Array[ArrayMesh] = []
var current_lod: int = 0

# Camera reference for LOD updates
var camera: Camera3D

# Initialization flag
var initialized: bool = false

# Terrain3D integration (when available)
var terrain3d_node: Node = null
var using_terrain3d: bool = false

func _ready() -> void:
	add_to_group("terrain_renderer")
	
	if not Engine.is_editor_hint():
		call_deferred("_setup_terrain")


func _exit_tree() -> void:
	_cleanup_terrain()


func _cleanup_terrain() -> void:
	"""Clean up terrain resources"""
	if terrain_mesh:
		terrain_mesh.queue_free()
		terrain_mesh = null
	
	if static_body:
		static_body.queue_free()
		static_body = null
	
	lod_meshes.clear()
	heightmap = null
	heightmap_texture = null
	initialized = false


func _setup_terrain() -> void:
	"""Setup the terrain system"""
	
	# Try to find Terrain3D addon first
	if _try_setup_terrain3d():
		using_terrain3d = true
		initialized = true
		print("TerrainRenderer: Using Terrain3D addon")
		return
	
	# Fallback to built-in terrain generation
	_setup_builtin_terrain()
	initialized = true
	print("TerrainRenderer: Initialized with built-in terrain (size: ", terrain_size, ", resolution: ", terrain_resolution, ")")


func _try_setup_terrain3d() -> bool:
	"""Try to setup Terrain3D addon if available"""
	# Check if Terrain3D class exists
	if not ClassDB.class_exists("Terrain3D"):
		return false
	
	# Terrain3D addon is available - this would be used when the addon is installed
	# For now, return false to use built-in terrain
	return false


func _setup_builtin_terrain() -> void:
	"""Setup terrain using Godot's built-in features"""
	
	# Initialize noise generator
	noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = noise_octaves
	noise.frequency = noise_frequency
	noise.fractal_lacunarity = noise_lacunarity
	noise.fractal_gain = noise_persistence
	
	# Load external heightmap if enabled, otherwise generate procedural
	if use_external_heightmap and external_heightmap_path != "":
		if not load_heightmap_from_file(external_heightmap_path, heightmap_region):
			# Fallback to procedural if loading fails
			print("TerrainRenderer: Failed to load external heightmap, using procedural")
			generate_heightmap(noise_seed, terrain_size)
	else:
		# Generate heightmap
		generate_heightmap(noise_seed, terrain_size)
	
	# Create terrain material with parallax occlusion
	_create_terrain_material()
	
	# Generate LOD meshes
	_generate_lod_meshes()
	
	# Create terrain mesh instance
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.mesh = lod_meshes[0] if lod_meshes.size() > 0 else null
	terrain_mesh.material_override = terrain_material
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain_mesh)
	
	# Create collision if enabled
	if collision_enabled:
		_create_collision_geometry()
	
	# Get camera reference
	camera = get_viewport().get_camera_3d()


func generate_heightmap(seed_value: int, size: Vector2i) -> void:
	"""Generate procedural heightmap using Perlin/Simplex noise"""
	noise_seed = seed_value
	terrain_size = size
	
	# Update noise seed
	if noise:
		noise.seed = seed_value
	else:
		noise = FastNoiseLite.new()
		noise.seed = seed_value
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = noise_octaves
		noise.frequency = noise_frequency
		noise.fractal_lacunarity = noise_lacunarity
		noise.fractal_gain = noise_persistence
	
	# Create heightmap image
	heightmap = Image.create(terrain_resolution, terrain_resolution, false, Image.FORMAT_RF)
	
	var half_size_x = terrain_size.x / 2.0
	var half_size_y = terrain_size.y / 2.0
	
	for y in range(terrain_resolution):
		for x in range(terrain_resolution):
			# Convert pixel coordinates to world coordinates
			var world_x = (float(x) / terrain_resolution) * terrain_size.x - half_size_x
			var world_z = (float(y) / terrain_resolution) * terrain_size.y - half_size_y
			
			# Get noise value (-1 to 1)
			var noise_value = noise.get_noise_2d(world_x, world_z)
			
			# Apply coastal shaping - lower terrain near edges for sea floor effect
			var edge_factor = _calculate_edge_factor(x, y)
			noise_value = noise_value * edge_factor - (1.0 - edge_factor) * 0.5
			
			# Map to height range
			var height = lerp(min_height, max_height, (noise_value + 1.0) / 2.0)
			
			# Store normalized height (0-1) in image
			var normalized_height = (height - min_height) / (max_height - min_height)
			heightmap.set_pixel(x, y, Color(normalized_height, 0, 0, 1))
	
	# Create texture from heightmap
	heightmap_texture = ImageTexture.create_from_image(heightmap)


func _calculate_edge_factor(x: int, y: int) -> float:
	"""Calculate edge falloff factor for coastal terrain shaping"""
	var edge_distance = 0.15  # 15% of terrain is edge zone
	
	var fx = float(x) / terrain_resolution
	var fy = float(y) / terrain_resolution
	
	# Distance from edges (0 at edge, 1 at center)
	var dx = min(fx, 1.0 - fx) / edge_distance
	var dy = min(fy, 1.0 - fy) / edge_distance
	
	dx = clamp(dx, 0.0, 1.0)
	dy = clamp(dy, 0.0, 1.0)
	
	# Smooth falloff
	return smoothstep(0.0, 1.0, min(dx, dy))



func _create_terrain_material() -> void:
	"""Create terrain shader material with parallax occlusion mapping"""
	terrain_material = ShaderMaterial.new()
	
	# Try to load external shader first, fall back to embedded
	var shader = load("res://shaders/terrain_parallax.gdshader")
	if not shader:
		shader = _create_terrain_shader()
	terrain_material.shader = shader
	
	# Set shader parameters
	if heightmap_texture:
		terrain_material.set_shader_parameter("heightmap", heightmap_texture)
	terrain_material.set_shader_parameter("terrain_size", Vector2(terrain_size.x, terrain_size.y))
	terrain_material.set_shader_parameter("height_scale", max_height - min_height)
	terrain_material.set_shader_parameter("min_height", min_height)
	terrain_material.set_shader_parameter("sea_level", sea_level)
	terrain_material.set_shader_parameter("parallax_scale", 0.05)
	terrain_material.set_shader_parameter("parallax_steps", 16)


func _create_terrain_shader() -> Shader:
	"""Create the terrain shader with parallax occlusion mapping"""
	var shader = Shader.new()
	shader.code = _get_terrain_shader_code()
	return shader


func _get_terrain_shader_code() -> String:
	"""Return the terrain shader code with parallax occlusion mapping"""
	return """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform vec2 terrain_size = vec2(1024.0, 1024.0);
uniform float height_scale = 300.0;
uniform float min_height = -200.0;
uniform float sea_level = 0.0;
uniform float parallax_scale = 0.05;
uniform int parallax_steps = 16;

// Terrain colors
uniform vec3 deep_water_color : source_color = vec3(0.05, 0.1, 0.2);
uniform vec3 shallow_water_color : source_color = vec3(0.1, 0.3, 0.4);
uniform vec3 sand_color : source_color = vec3(0.76, 0.7, 0.5);
uniform vec3 grass_color : source_color = vec3(0.2, 0.4, 0.1);
uniform vec3 rock_color : source_color = vec3(0.4, 0.35, 0.3);
uniform vec3 snow_color : source_color = vec3(0.95, 0.95, 0.97);

varying vec3 world_position;
varying float terrain_height;

float get_height(vec2 uv) {
	return texture(heightmap, uv).r * height_scale + min_height;
}

vec3 calculate_normal(vec2 uv, float texel_size) {
	float h_left = get_height(uv - vec2(texel_size, 0.0));
	float h_right = get_height(uv + vec2(texel_size, 0.0));
	float h_down = get_height(uv - vec2(0.0, texel_size));
	float h_up = get_height(uv + vec2(0.0, texel_size));
	
	vec3 normal = normalize(vec3(h_left - h_right, 2.0 * texel_size * terrain_size.x, h_down - h_up));
	return normal;
}

vec2 parallax_occlusion_mapping(vec2 uv, vec3 view_dir) {
	float layer_depth = 1.0 / float(parallax_steps);
	float current_layer_depth = 0.0;
	vec2 delta_uv = view_dir.xz * parallax_scale / float(parallax_steps);
	
	vec2 current_uv = uv;
	float current_depth = texture(heightmap, current_uv).r;
	
	for (int i = 0; i < parallax_steps; i++) {
		if (current_layer_depth >= current_depth) {
			break;
		}
		current_uv -= delta_uv;
		current_depth = texture(heightmap, current_uv).r;
		current_layer_depth += layer_depth;
	}
	
	// Interpolation for smoother result
	vec2 prev_uv = current_uv + delta_uv;
	float after_depth = current_depth - current_layer_depth;
	float before_depth = texture(heightmap, prev_uv).r - current_layer_depth + layer_depth;
	float weight = after_depth / (after_depth - before_depth);
	
	return mix(current_uv, prev_uv, weight);
}

void vertex() {
	// Get UV from vertex position
	vec2 uv = (VERTEX.xz / terrain_size) + 0.5;
	
	// Sample heightmap and displace vertex
	float height = get_height(uv);
	VERTEX.y = height;
	
	// Store for fragment shader
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_height = height;
	
	// Calculate normal from heightmap
	float texel_size = 1.0 / float(textureSize(heightmap, 0).x);
	NORMAL = calculate_normal(uv, texel_size);
}

void fragment() {
	vec2 uv = (world_position.xz / terrain_size) + 0.5;
	
	// Apply parallax occlusion mapping
	vec3 view_dir = normalize(VIEW);
	vec2 parallax_uv = parallax_occlusion_mapping(uv, view_dir);
	
	float height = terrain_height;
	
	// Calculate terrain color based on height and slope
	float texel_size = 1.0 / float(textureSize(heightmap, 0).x);
	vec3 normal = calculate_normal(parallax_uv, texel_size);
	float slope = 1.0 - normal.y;
	
	// Height-based coloring
	vec3 color;
	float height_normalized = (height - min_height) / height_scale;
	
	if (height < sea_level - 50.0) {
		// Deep water / sea floor
		color = deep_water_color;
	} else if (height < sea_level - 10.0) {
		// Shallow water / sea floor
		float t = (height - (sea_level - 50.0)) / 40.0;
		color = mix(deep_water_color, shallow_water_color, t);
	} else if (height < sea_level + 5.0) {
		// Beach / sand
		float t = (height - (sea_level - 10.0)) / 15.0;
		color = mix(shallow_water_color, sand_color, t);
	} else if (height < sea_level + 30.0) {
		// Grass
		float t = (height - (sea_level + 5.0)) / 25.0;
		color = mix(sand_color, grass_color, t);
	} else if (height < sea_level + 70.0) {
		// Rock
		float t = (height - (sea_level + 30.0)) / 40.0;
		color = mix(grass_color, rock_color, t);
	} else {
		// Snow
		float t = clamp((height - (sea_level + 70.0)) / 30.0, 0.0, 1.0);
		color = mix(rock_color, snow_color, t);
	}
	
	// Add slope-based rock coloring
	if (slope > 0.5) {
		float rock_blend = smoothstep(0.5, 0.8, slope);
		color = mix(color, rock_color, rock_blend);
	}
	
	ALBEDO = color;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
	NORMAL_MAP = vec3(normal.x * 0.5 + 0.5, normal.z * 0.5 + 0.5, normal.y);
}
"""


func _generate_lod_meshes() -> void:
	"""Generate terrain meshes for each LOD level"""
	lod_meshes.clear()
	
	for lod in range(lod_levels):
		var lod_resolution = max(4, terrain_resolution >> lod)  # Halve resolution each LOD
		var lod_mesh = _create_terrain_mesh(lod_resolution)
		lod_meshes.append(lod_mesh)


func _create_terrain_mesh(resolution: int) -> ArrayMesh:
	"""Create a terrain mesh with the given resolution"""
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_size_x = terrain_size.x / 2.0
	var half_size_y = terrain_size.y / 2.0
	var step_x = terrain_size.x / float(resolution - 1)
	var step_z = terrain_size.y / float(resolution - 1)
	
	# Generate vertices
	for z in range(resolution):
		for x in range(resolution):
			var world_x = x * step_x - half_size_x
			var world_z = z * step_z - half_size_y
			
			# UV coordinates
			var u = float(x) / (resolution - 1)
			var v = float(z) / (resolution - 1)
			
			# Get height from heightmap
			var height = get_height_at(Vector2(world_x, world_z))
			
			surface_tool.set_uv(Vector2(u, v))
			surface_tool.set_normal(Vector3.UP)  # Will be recalculated in shader
			surface_tool.add_vertex(Vector3(world_x, height, world_z))
	
	# Generate indices
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var top_left = z * resolution + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * resolution + x
			var bottom_right = bottom_left + 1
			
			# First triangle
			surface_tool.add_index(top_left)
			surface_tool.add_index(bottom_left)
			surface_tool.add_index(top_right)
			
			# Second triangle
			surface_tool.add_index(top_right)
			surface_tool.add_index(bottom_left)
			surface_tool.add_index(bottom_right)
	
	surface_tool.generate_normals()
	return surface_tool.commit()


func _create_collision_geometry() -> void:
	"""Generate collision geometry from heightmap"""
	if not heightmap:
		return
	
	# Create static body for terrain collision
	static_body = StaticBody3D.new()
	static_body.collision_layer = 1  # Terrain layer
	static_body.collision_mask = 0  # Don't detect other objects
	add_child(static_body)
	
	# Create heightmap shape for collision
	var shape = HeightMapShape3D.new()
	
	# HeightMapShape3D requires square dimensions that are power of 2 + 1
	var collision_resolution = _get_nearest_power_of_two(terrain_resolution) + 1
	shape.map_width = collision_resolution
	shape.map_depth = collision_resolution
	
	# Generate height data for collision shape
	var height_data: PackedFloat32Array = PackedFloat32Array()
	height_data.resize(collision_resolution * collision_resolution)
	
	var half_size_x = terrain_size.x / 2.0
	var half_size_y = terrain_size.y / 2.0
	
	for z in range(collision_resolution):
		for x in range(collision_resolution):
			var world_x = (float(x) / (collision_resolution - 1)) * terrain_size.x - half_size_x
			var world_z = (float(z) / (collision_resolution - 1)) * terrain_size.y - half_size_y
			var height = get_height_at(Vector2(world_x, world_z))
			height_data[z * collision_resolution + x] = height
	
	shape.map_data = height_data
	
	# Create collision shape node
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape
	
	# Scale collision shape to match terrain size
	var scale_x = terrain_size.x / float(collision_resolution - 1)
	var scale_z = terrain_size.y / float(collision_resolution - 1)
	collision_shape.scale = Vector3(scale_x, 1.0, scale_z)
	
	static_body.add_child(collision_shape)


func _get_nearest_power_of_two(value: int) -> int:
	"""Get the nearest power of two less than or equal to value"""
	var power = 1
	while power * 2 <= value:
		power *= 2
	return power



func _process(_delta: float) -> void:
	if not initialized:
		return
	
	# Update LOD based on camera distance
	if camera:
		update_lod(camera.global_position)


func update_lod(camera_position: Vector3) -> void:
	"""Update terrain LOD based on camera distance"""
	if not terrain_mesh or lod_meshes.size() == 0:
		return
	
	# Calculate distance from camera to terrain center
	var terrain_center = global_position
	var distance = camera_position.distance_to(terrain_center)
	
	# Determine appropriate LOD level
	var new_lod = 0
	var lod_distance = base_lod_distance
	
	for i in range(lod_levels):
		if distance > lod_distance:
			new_lod = i
		lod_distance *= lod_distance_multiplier
	
	new_lod = clamp(new_lod, 0, lod_meshes.size() - 1)
	
	# Switch LOD if needed
	if new_lod != current_lod:
		current_lod = new_lod
		terrain_mesh.mesh = lod_meshes[current_lod]


func get_height_at(world_pos: Vector2) -> float:
	"""Get terrain height at a specific world position (XZ plane)"""
	if not heightmap:
		return 0.0
	
	# Convert world position to heightmap UV
	var half_size_x = terrain_size.x / 2.0
	var half_size_y = terrain_size.y / 2.0
	
	var u = (world_pos.x + half_size_x) / terrain_size.x
	var v = (world_pos.y + half_size_y) / terrain_size.y
	
	# Clamp to valid range
	u = clamp(u, 0.0, 1.0)
	v = clamp(v, 0.0, 1.0)
	
	# Convert to pixel coordinates
	var _px = int(u * (heightmap.get_width() - 1))
	var _py = int(v * (heightmap.get_height() - 1))
	
	# Sample heightmap (bilinear interpolation for smoother results)
	var height_normalized = _sample_heightmap_bilinear(u, v)
	
	# Convert to world height
	return height_normalized * (max_height - min_height) + min_height


func _sample_heightmap_bilinear(u: float, v: float) -> float:
	"""Sample heightmap with bilinear interpolation"""
	if not heightmap:
		return 0.0
	
	var width = heightmap.get_width()
	var height = heightmap.get_height()
	
	# Get pixel coordinates
	var px = u * (width - 1)
	var py = v * (height - 1)
	
	var x0 = int(floor(px))
	var y0 = int(floor(py))
	var x1 = min(x0 + 1, width - 1)
	var y1 = min(y0 + 1, height - 1)
	
	var fx = px - x0
	var fy = py - y0
	
	# Sample four corners
	var h00 = heightmap.get_pixel(x0, y0).r
	var h10 = heightmap.get_pixel(x1, y0).r
	var h01 = heightmap.get_pixel(x0, y1).r
	var h11 = heightmap.get_pixel(x1, y1).r
	
	# Bilinear interpolation
	var h0 = lerp(h00, h10, fx)
	var h1 = lerp(h01, h11, fx)
	return lerp(h0, h1, fy)


func get_height_at_3d(world_pos: Vector3) -> float:
	"""Get terrain height at a specific 3D world position"""
	return get_height_at(Vector2(world_pos.x, world_pos.z))


func check_collision(world_position: Vector3, radius: float = 0.0) -> bool:
	"""Check if a position collides with terrain"""
	var terrain_height = get_height_at_3d(world_position)
	return world_position.y - radius < terrain_height


func get_collision_response(world_position: Vector3, radius: float = 0.0) -> Vector3:
	"""Get collision response vector to push object out of terrain"""
	var terrain_height = get_height_at_3d(world_position)
	var penetration = terrain_height - (world_position.y - radius)
	
	if penetration > 0:
		return Vector3(0, penetration + collision_margin, 0)
	return Vector3.ZERO


func get_normal_at(world_pos: Vector2) -> Vector3:
	"""Get terrain normal at a specific world position"""
	if not heightmap:
		return Vector3.UP
	
	var sample_distance = float(terrain_size.x) / float(terrain_resolution)
	
	var h_left = get_height_at(world_pos - Vector2(sample_distance, 0))
	var h_right = get_height_at(world_pos + Vector2(sample_distance, 0))
	var h_down = get_height_at(world_pos - Vector2(0, sample_distance))
	var h_up = get_height_at(world_pos + Vector2(0, sample_distance))
	
	var normal = Vector3(h_left - h_right, 2.0 * sample_distance, h_down - h_up)
	return normal.normalized()


# ============================================================================
# External Heightmap Loading
# ============================================================================

## Path to external heightmap image (e.g., "res://src_assets/World_elevation_map.png")
@export var external_heightmap_path: String = "res://src_assets/World_elevation_map.png"

## Region of the external heightmap to use (in UV coordinates 0-1)
## Default: Mediterranean region (good mix of land and water)
@export var heightmap_region: Rect2 = Rect2(0.25, 0.3, 0.1, 0.1)

## Whether to use external heightmap instead of procedural generation
@export var use_external_heightmap: bool = true


func load_heightmap_from_file(path: String, region: Rect2 = Rect2(0, 0, 1, 1)) -> bool:
	"""Load heightmap from an external image file"""
	var image = Image.new()
	var error = image.load(path)
	
	if error != OK:
		push_error("TerrainRenderer: Failed to load heightmap from " + path)
		return false
	
	# Extract region from the image
	var src_width = image.get_width()
	var src_height = image.get_height()
	
	var region_x = int(region.position.x * src_width)
	var region_y = int(region.position.y * src_height)
	var region_w = int(region.size.x * float(src_width))
	var region_h = int(region.size.y * float(src_height))
	
	# Clamp region to image bounds
	region_x = clamp(region_x, 0, src_width - 1)
	region_y = clamp(region_y, 0, src_height - 1)
	region_w = clamp(region_w, 1, src_width - region_x)
	region_h = clamp(region_h, 1, src_height - region_y)
	
	# Extract and resize region to terrain resolution
	var region_image = image.get_region(Rect2i(region_x, region_y, region_w, region_h))
	region_image.resize(terrain_resolution, terrain_resolution, Image.INTERPOLATE_LANCZOS)
	
	# Initialize micro-detail noise if enabled
	var micro_noise: FastNoiseLite = null
	if enable_micro_detail:
		micro_noise = FastNoiseLite.new()
		micro_noise.seed = noise_seed + 1000  # Different seed for micro detail
		micro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		micro_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		micro_noise.fractal_octaves = 3  # Fewer octaves for fine detail
		micro_noise.frequency = micro_detail_frequency
		micro_noise.fractal_lacunarity = 2.0
		micro_noise.fractal_gain = 0.5
	
	# Convert to grayscale heightmap (use red channel or luminance)
	heightmap = Image.create(terrain_resolution, terrain_resolution, false, Image.FORMAT_RF)
	
	var half_size_x = terrain_size.x / 2.0
	var half_size_y = terrain_size.y / 2.0
	
	for y in range(terrain_resolution):
		for x in range(terrain_resolution):
			var pixel = region_image.get_pixel(x, y)
			# Use luminance for grayscale conversion
			var base_height = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			
			# Add micro detail if enabled
			if enable_micro_detail and micro_noise:
				# Convert pixel coordinates to world coordinates for noise sampling
				var world_x = (float(x) / terrain_resolution) * terrain_size.x - half_size_x
				var world_z = (float(y) / terrain_resolution) * terrain_size.y - half_size_y
				
				# Get micro detail noise (-1 to 1)
				var detail_noise = micro_noise.get_noise_2d(world_x, world_z)
				
				# Scale micro detail based on the base height to preserve original terrain shape
				# Less detail in flat areas (water), more detail on slopes
				var detail_amount = micro_detail_scale / (max_height - min_height)
				var height_variation = detail_noise * detail_amount * 0.5  # Keep it subtle
				
				# Add detail while clamping to valid range
				base_height = clamp(base_height + height_variation, 0.0, 1.0)
			
			heightmap.set_pixel(x, y, Color(base_height, 0, 0, 1))
	
	# Create texture from heightmap
	heightmap_texture = ImageTexture.create_from_image(heightmap)
	
	# Update material if it exists
	if terrain_material:
		terrain_material.set_shader_parameter("heightmap", heightmap_texture)
	
	var detail_status = " (with micro detail)" if enable_micro_detail else ""
	print("TerrainRenderer: Loaded heightmap from ", path, " (region: ", region, ")", detail_status)
	return true


func load_world_elevation_map(region: Rect2 = Rect2(0.25, 0.3, 0.1, 0.1)) -> bool:
	"""Load terrain from the world elevation map asset
	
	Default region is roughly the Mediterranean area.
	Adjust region to select different parts of the world:
	- North Atlantic: Rect2(0.2, 0.2, 0.15, 0.15)
	- Pacific: Rect2(0.6, 0.3, 0.2, 0.2)
	- Caribbean: Rect2(0.15, 0.35, 0.1, 0.1)
	"""
	return load_heightmap_from_file("res://src_assets/World_elevation_map.png", region)


func regenerate_terrain() -> void:
	"""Regenerate terrain mesh and collision after heightmap change"""
	if not heightmap:
		return
	
	# Regenerate LOD meshes
	_generate_lod_meshes()
	
	# Update terrain mesh
	if terrain_mesh and lod_meshes.size() > 0:
		terrain_mesh.mesh = lod_meshes[current_lod]
	
	# Regenerate collision
	if collision_enabled and static_body:
		static_body.queue_free()
		static_body = null
		collision_shape = null
		_create_collision_geometry()


func set_terrain_region(region: Rect2) -> void:
	"""Set the region of the external heightmap to use and regenerate terrain"""
	heightmap_region = region
	if use_external_heightmap and external_heightmap_path != "":
		load_heightmap_from_file(external_heightmap_path, region)
		regenerate_terrain()


func find_safe_spawn_position(preferred_position: Vector3 = Vector3.ZERO, search_radius: float = 500.0, min_depth: float = -50.0) -> Vector3:
	"""Find a safe spawn position in water (below sea level, above sea floor)
	
	Args:
		preferred_position: Preferred spawn location (will search nearby)
		search_radius: How far to search for a valid position
		min_depth: Minimum depth below sea level for safe spawning
	
	Returns:
		A safe spawn position in water, or preferred_position if no valid position found
	"""
	if not initialized or not heightmap:
		push_warning("TerrainRenderer: Cannot find spawn position - terrain not initialized")
		return preferred_position
	
	# Try the preferred position first
	var terrain_height = get_height_at(Vector2(preferred_position.x, preferred_position.z))
	if terrain_height < sea_level + min_depth:
		# Position is underwater and safe
		var safe_depth = (terrain_height + sea_level + min_depth) / 2.0
		return Vector3(preferred_position.x, safe_depth, preferred_position.z)
	
	# Search in a spiral pattern for a valid water position
	var search_steps = 16
	var angle_step = TAU / 8.0  # 8 directions
	
	for ring in range(1, search_steps):
		var radius = (float(ring) / search_steps) * search_radius
		
		for angle_idx in range(8):
			var angle = angle_idx * angle_step
			var test_pos = Vector2(
				preferred_position.x + cos(angle) * radius,
				preferred_position.z + sin(angle) * radius
			)
			
			var test_height = get_height_at(test_pos)
			if test_height < sea_level + min_depth:
				# Found a valid water position
				var safe_depth = (test_height + sea_level + min_depth) / 2.0
				print("TerrainRenderer: Found safe spawn position at ", Vector3(test_pos.x, safe_depth, test_pos.y))
				return Vector3(test_pos.x, safe_depth, test_pos.y)
	
	# No valid position found, return a position well below sea level
	push_warning("TerrainRenderer: Could not find safe spawn position, using default depth")
	return Vector3(preferred_position.x, sea_level + min_depth, preferred_position.z)


func is_position_underwater(world_position: Vector3, margin: float = 5.0) -> bool:
	"""Check if a position is safely underwater (below sea level, above sea floor)
	
	Args:
		world_position: Position to check
		margin: Safety margin above sea floor
	
	Returns:
		True if position is safely underwater
	"""
	var terrain_height = get_height_at_3d(world_position)
	return world_position.y < sea_level and world_position.y > terrain_height + margin

