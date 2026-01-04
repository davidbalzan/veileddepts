class_name CollisionManager extends Node3D
## Manages terrain collision geometry and height queries
##
## Responsibilities:
## - Create and remove collision shapes for terrain chunks
## - Query terrain height at world positions
## - Handle chunk boundary cases for collision
## - Provide underwater safety checks
## - Support raycasting against terrain

## Reference to ChunkManager for accessing chunks
var _chunk_manager: ChunkManager = null


func _ready() -> void:
	# Find ChunkManager
	_chunk_manager = get_node_or_null("../ChunkManager")
	if not _chunk_manager:
		push_error("CollisionManager: ChunkManager not found")


## Set the ChunkManager reference (useful for testing)
##
## @param chunk_manager: ChunkManager instance
func set_chunk_manager(chunk_manager: ChunkManager) -> void:
	_chunk_manager = chunk_manager


## Create collision shape for chunk
##
## Generates a HeightMapShape3D from the chunk's heightmap and adds
## collision geometry to the chunk.
##
## @param chunk: TerrainChunk to create collision for
func create_collision(chunk: TerrainChunk) -> void:
	if not chunk:
		push_error("CollisionManager: Cannot create collision for null chunk")
		return

	if not chunk.base_heightmap:
		push_error("CollisionManager: Chunk %s has no heightmap" % chunk.chunk_coord)
		return

	# Remove existing collision if present
	if chunk.static_body:
		remove_collision(chunk)

	# Create StaticBody3D
	var static_body := StaticBody3D.new()
	static_body.name = "CollisionBody"
	chunk.add_child(static_body)
	chunk.static_body = static_body

	# Create CollisionShape3D
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	static_body.add_child(collision_shape)
	chunk.collision_shape = collision_shape

	# Create HeightMapShape3D from heightmap
	var shape := HeightMapShape3D.new()

	# HeightMapShape3D requires square dimensions that are power of 2 + 1
	var _heightmap_width: int = chunk.base_heightmap.get_width()
	var _heightmap_height: int = chunk.base_heightmap.get_height()

	# Find nearest power of 2 + 1 for collision resolution
	var collision_resolution: int = _get_nearest_power_of_two(_heightmap_width) + 1

	# Extract height data from heightmap
	var height_data: PackedFloat32Array = _extract_height_data(
		chunk.base_heightmap, collision_resolution
	)

	# Configure HeightMapShape3D
	shape.map_width = collision_resolution
	shape.map_depth = collision_resolution
	shape.map_data = height_data

	# Set the shape
	collision_shape.shape = shape

	# Position collision shape at chunk origin (relative to chunk node)
	# The chunk node is already positioned at the correct world location
	collision_shape.position = Vector3.ZERO

	print(
		(
			"CollisionManager: Created collision for chunk %s (resolution: %d)"
			% [chunk.chunk_coord, collision_resolution]
		)
	)


## Remove collision shape for chunk
##
## Cleans up collision geometry and frees resources.
##
## @param chunk: TerrainChunk to remove collision from
func remove_collision(chunk: TerrainChunk) -> void:
	if not chunk:
		return

	# Remove collision shape
	if chunk.collision_shape:
		chunk.collision_shape.queue_free()
		chunk.collision_shape = null

	# Remove static body
	if chunk.static_body:
		chunk.static_body.queue_free()
		chunk.static_body = null

	print("CollisionManager: Removed collision for chunk %s" % chunk.chunk_coord)


## Query terrain height at world position
##
## Identifies the correct chunk and samples its heightmap with bilinear interpolation.
## Handles positions at chunk boundaries correctly.
##
## @param world_pos: World position (2D, uses X and Z)
## @return: Terrain height at position, or 0.0 if no chunk loaded
func get_height_at(world_pos: Vector2) -> float:
	if not _chunk_manager:
		push_error("CollisionManager: ChunkManager not available")
		return 0.0

	# Convert to 3D position for chunk lookup
	var pos_3d := Vector3(world_pos.x, 0.0, world_pos.y)
	var chunk_coord: Vector2i = _chunk_manager.world_to_chunk(pos_3d)

	# Check if chunk is loaded
	if not _chunk_manager.is_chunk_loaded(chunk_coord):
		# Try to estimate from nearest loaded chunk
		return _estimate_height_from_nearest_chunk(world_pos)

	# Get the chunk
	var chunk: TerrainChunk = _chunk_manager.get_chunk(chunk_coord)
	if not chunk or not chunk.base_heightmap:
		return 0.0

	# Convert world position to local chunk coordinates
	var chunk_world_pos: Vector3 = _chunk_manager.chunk_to_world(chunk_coord)
	var local_x: float = world_pos.x - chunk_world_pos.x + (_chunk_manager.chunk_size * 0.5)
	var local_z: float = world_pos.y - chunk_world_pos.z + (_chunk_manager.chunk_size * 0.5)

	# Convert to heightmap coordinates (0 to 1)
	var uv_x: float = local_x / _chunk_manager.chunk_size
	var uv_y: float = local_z / _chunk_manager.chunk_size

	# Sample heightmap with bilinear interpolation
	var height: float = _sample_heightmap_bilinear(chunk.base_heightmap, uv_x, uv_y)

	return height


## Check if position is underwater with clearance above sea floor
##
## Verifies that a position is:
## 1. Below sea level (using current dynamic sea level from SeaLevelManager)
## 2. Has sufficient clearance above the terrain
##
## @param world_pos: World position (3D)
## @param clearance: Required clearance above terrain in meters
## @return: True if position is safe underwater
func is_underwater_safe(world_pos: Vector3, clearance: float) -> bool:
	# Get current sea level from manager
	var sea_level: float = 0.0
	var sea_level_manager = get_node_or_null("/root/SeaLevelManager")
	if sea_level_manager:
		sea_level = sea_level_manager.get_sea_level_meters()
	else:
		push_warning("CollisionManager: SeaLevelManager not available, using default sea level (0m)")
	
	# Check if below sea level
	if world_pos.y >= sea_level:
		return false

	# Get terrain height at this position
	var terrain_height: float = get_height_at(Vector2(world_pos.x, world_pos.z))

	# Check if we have sufficient clearance above terrain
	var height_above_terrain: float = world_pos.y - terrain_height

	return height_above_terrain >= clearance


## Find a safe spawn position underwater
##
## Searches for a position that is:
## 1. Below current sea level
## 2. Above terrain with sufficient clearance
## 3. Within search radius of preferred position
##
## @param preferred_position: Preferred spawn location (will search nearby)
## @param search_radius: How far to search for a valid position (meters)
## @param clearance: Required clearance above terrain (meters)
## @param depth_below_sea_level: Desired depth below sea level (meters, positive value)
## @return: Safe spawn position, or preferred_position adjusted to safe depth if no valid position found
func find_safe_spawn_position(
	preferred_position: Vector3 = Vector3.ZERO,
	search_radius: float = 500.0,
	clearance: float = 50.0,
	depth_below_sea_level: float = 50.0
) -> Vector3:
	# Get current sea level from manager
	var sea_level: float = 0.0
	var sea_level_manager = get_node_or_null("/root/SeaLevelManager")
	if sea_level_manager:
		sea_level = sea_level_manager.get_sea_level_meters()
	else:
		push_warning("CollisionManager: SeaLevelManager not available, using default sea level (0m)")
	
	# Calculate target depth (below sea level)
	var target_depth: float = sea_level - depth_below_sea_level
	
	# Try the preferred position first
	var terrain_height: float = get_height_at(Vector2(preferred_position.x, preferred_position.z))
	
	# Check if preferred position is valid
	if terrain_height < sea_level:  # Underwater terrain
		# Calculate safe depth between terrain and sea level
		var min_safe_y: float = terrain_height + clearance
		var max_safe_y: float = sea_level
		
		if min_safe_y < max_safe_y:
			# Clamp target depth to safe range
			var safe_y: float = clamp(target_depth, min_safe_y, max_safe_y - 1.0)
			return Vector3(preferred_position.x, safe_y, preferred_position.z)
	
	# Search in a spiral pattern for a valid underwater position
	var search_steps: int = 16
	var angle_step: float = TAU / 8.0  # 8 directions
	
	for ring in range(1, search_steps):
		var radius: float = (float(ring) / float(search_steps)) * search_radius
		
		for angle_idx in range(8):
			var angle: float = float(angle_idx) * angle_step
			var test_pos := Vector2(
				preferred_position.x + cos(angle) * radius,
				preferred_position.z + sin(angle) * radius
			)
			
			var test_height: float = get_height_at(test_pos)
			
			# Check if this position is underwater
			if test_height < sea_level:
				# Calculate safe depth
				var min_safe_y: float = test_height + clearance
				var max_safe_y: float = sea_level
				
				if min_safe_y < max_safe_y:
					var safe_y: float = clamp(target_depth, min_safe_y, max_safe_y - 1.0)
					print(
						"CollisionManager: Found safe spawn position at ",
						Vector3(test_pos.x, safe_y, test_pos.y),
						" (sea level: %.1fm, terrain: %.1fm)" % [sea_level, test_height]
					)
					return Vector3(test_pos.x, safe_y, test_pos.y)
	
	# No valid position found, return a position at target depth
	# This might not be safe, but it's the best we can do
	push_warning(
		"CollisionManager: Could not find safe spawn position within search radius, using target depth (%.1fm below sea level)" % depth_below_sea_level
	)
	return Vector3(preferred_position.x, target_depth, preferred_position.z)


## Raycast against terrain
##
## Uses Godot's physics raycast to test intersection with terrain collision.
##
## @param origin: Ray origin in world space
## @param direction: Ray direction (should be normalized)
## @param max_distance: Maximum ray distance
## @return: Dictionary with hit info {hit: bool, position: Vector3, normal: Vector3, distance: float}
func raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	# Get the world's physics space
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	if not space_state:
		return {"hit": false, "position": Vector3.ZERO, "normal": Vector3.ZERO, "distance": 0.0}

	# Create ray query
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction.normalized() * max_distance
	)

	# Perform raycast
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return {"hit": false, "position": Vector3.ZERO, "normal": Vector3.ZERO, "distance": 0.0}

	# Extract hit information
	var hit_position: Vector3 = result.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = result.get("normal", Vector3.ZERO)
	var distance: float = origin.distance_to(hit_position)

	return {"hit": true, "position": hit_position, "normal": hit_normal, "distance": distance}


## Extract height data from heightmap for HeightMapShape3D
##
## Samples the heightmap at the specified resolution and converts to
## the format required by HeightMapShape3D.
##
## @param heightmap: Source heightmap image
## @param resolution: Target resolution (must be power of 2 + 1)
## @return: PackedFloat32Array of height values
func _extract_height_data(heightmap: Image, resolution: int) -> PackedFloat32Array:
	var height_data := PackedFloat32Array()
	height_data.resize(resolution * resolution)

	var _heightmap_width: int = heightmap.get_width()
	var _heightmap_height: int = heightmap.get_height()

	# Sample heightmap at regular intervals
	for z in range(resolution):
		for x in range(resolution):
			# Calculate UV coordinates
			var u: float = float(x) / float(resolution - 1)
			var v: float = float(z) / float(resolution - 1)

			# Sample heightmap
			var height: float = _sample_heightmap_bilinear(heightmap, u, v)

			# Store in height data array
			var index: int = z * resolution + x
			height_data[index] = height

	return height_data


## Sample heightmap with bilinear interpolation
##
## @param heightmap: Heightmap image to sample
## @param u: U coordinate (0 to 1)
## @param v: V coordinate (0 to 1)
## @return: Interpolated height value
func _sample_heightmap_bilinear(heightmap: Image, u: float, v: float) -> float:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Clamp UV coordinates
	u = clampf(u, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)

	# Convert to pixel coordinates
	var px: float = u * float(width - 1)
	var py: float = v * float(height - 1)

	# Get integer and fractional parts
	var x0: int = int(floor(px))
	var y0: int = int(floor(py))
	var x1: int = mini(x0 + 1, width - 1)
	var y1: int = mini(y0 + 1, height - 1)

	var fx: float = px - float(x0)
	var fy: float = py - float(y0)

	# Sample four corners
	var h00: float = _get_pixel_height(heightmap, x0, y0)
	var h10: float = _get_pixel_height(heightmap, x1, y0)
	var h01: float = _get_pixel_height(heightmap, x0, y1)
	var h11: float = _get_pixel_height(heightmap, x1, y1)

	# Bilinear interpolation
	var h0: float = lerpf(h00, h10, fx)
	var h1: float = lerpf(h01, h11, fx)
	var result: float = lerpf(h0, h1, fy)

	return result


# Constants for vertical scaling (must match ElevationDataProvider)
const MARIANA_TRENCH_DEPTH: float = -10994.0
const MOUNT_EVEREST_HEIGHT: float = 8849.0


## Get height value from a pixel in the heightmap (scaled to world units)
##
## @param heightmap: Heightmap image
## @param x: Pixel X coordinate
## @param y: Pixel Y coordinate
## @return: Height value in meters
func _get_pixel_height(heightmap: Image, x: int, y: int) -> float:
	var color: Color = heightmap.get_pixel(x, y)
	# Red channel contains normalized height (0.0 to 1.0)
	var normalized_height: float = color.r
	
	# Scale to world units
	return lerpf(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, normalized_height)


## Estimate height from nearest loaded chunk
##
## Used as fallback when query position in unloaded chunk.
##
## @param world_pos: World position (2D)
## @return: Estimated height, or 0.0 if no chunks loaded
func _estimate_height_from_nearest_chunk(world_pos: Vector2) -> float:
	if not _chunk_manager:
		return 0.0

	var loaded_chunks: Array[Vector2i] = _chunk_manager.get_loaded_chunks()
	
	if loaded_chunks.is_empty():
		return 0.0
		
	# Find nearest loaded chunk
	var nearest_coord: Vector2i = loaded_chunks[0]
	var nearest_distance: float = INF
	
	var pos_3d := Vector3(world_pos.x, 0.0, world_pos.y)
	
	for chunk_coord in loaded_chunks:
		var distance: float = _chunk_manager.get_distance_to_chunk(pos_3d, chunk_coord)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_coord = chunk_coord
			
	# Get height from nearest chunk (at closest edge point)
	var chunk: TerrainChunk = _chunk_manager.get_chunk(nearest_coord)
	if not chunk or not chunk.base_heightmap:
		return 0.0
		
	# Use center height as rough estimate
	# Note: _sample_heightmap_bilinear returns scaled height because it calls _get_pixel_height (which we updated)
	# Wait, _sample_heightmap_bilinear calls _get_pixel_height multiple times and lerps.
	# The lerp works correctly on scaled values.
	var center_height: float = _sample_heightmap_bilinear(chunk.base_heightmap, 0.5, 0.5)
	
	push_warning("CollisionManager: Estimating height from nearest chunk %s (distance: %.1f m)" % [nearest_coord, nearest_distance])
	
	return center_height


## Get nearest power of two for a given value
##
## @param value: Input value
## @return: Nearest power of 2
func _get_nearest_power_of_two(value: int) -> int:
	var power: int = 1
	while power < value:
		power *= 2
		
	# Return the closer of the two surrounding powers of 2
	var lower: int = int(power / 2.0)
	var upper: int = power
	
	if abs(value - lower) < abs(value - upper):
		return lower
	else:
		return upper


# ============================================================================
# Sonar Integration Interface
# ============================================================================


## Get terrain geometry for sonar system
##
## Returns simplified terrain geometry within sonar range for performance.
## Filters out terrain beyond the specified range.
##
## @param origin: Sonar origin position (submarine position)
## @param max_range: Maximum sonar range in meters
## @param simplification_level: Level of geometry simplification (0=full detail, 3=very simplified)
## @return: Dictionary with terrain data {positions: PackedVector3Array, normals: PackedVector3Array}
func get_terrain_geometry_for_sonar(origin: Vector3, max_range: float, simplification_level: int = 1) -> Dictionary:
	if not _chunk_manager:
		return {"positions": PackedVector3Array(), "normals": PackedVector3Array()}
		
	# Get chunks within sonar range
	var chunks_in_range: Array[Vector2i] = _chunk_manager.get_chunks_in_radius(origin, max_range)
	
	if chunks_in_range.is_empty():
		return {"positions": PackedVector3Array(), "normals": PackedVector3Array()}
		
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	
	# Determine sampling resolution based on simplification level
	var sample_step: int = 1 << simplification_level # 1, 2, 4, 8...
	
	# Extract geometry from each chunk
	for chunk_coord in chunks_in_range:
		if not _chunk_manager.is_chunk_loaded(chunk_coord):
			continue
			
		var chunk: TerrainChunk = _chunk_manager.get_chunk(chunk_coord)
		if not chunk or not chunk.base_heightmap:
			continue
			
		# Sample heightmap at reduced resolution
		var heightmap: Image = chunk.base_heightmap
		var width: int = heightmap.get_width()
		var height: int = heightmap.get_height()
		
		var chunk_world_pos: Vector3 = _chunk_manager.chunk_to_world(chunk_coord)
		var chunk_size: float = _chunk_manager.chunk_size
		
		# Sample points from heightmap
		for z in range(0, height, sample_step):
			for x in range(0, width, sample_step):
				# Convert to world position
				var local_x: float = (float(x) / float(width - 1)) * chunk_size - (chunk_size * 0.5)
				var local_z: float = (float(z) / float(height - 1)) * chunk_size - (chunk_size * 0.5)
				
				var world_x: float = chunk_world_pos.x + local_x
				var world_z: float = chunk_world_pos.z + local_z
				
				# Get height at this position (now scaled)
				var terrain_height: float = _get_pixel_height(heightmap, x, z)
				var world_pos := Vector3(world_x, terrain_height, world_z)
				
				# Filter by range
				var distance: float = origin.distance_to(world_pos)
				if distance > max_range:
					continue
					
				# Calculate normal at this position
				var normal: Vector3 = _calculate_normal_at_pixel(heightmap, x, z, chunk_size)
				
				positions.append(world_pos)
				normals.append(normal)
				
	return {"positions": positions, "normals": normals}


## Get surface normal at a specific world position for sonar
##
## Returns the terrain surface normal for realistic sonar reflection calculation.
##
## @param world_pos: World position to query (3D)
## @return: Surface normal vector (normalized)
func get_surface_normal_for_sonar(world_pos: Vector3) -> Vector3:
	if not _chunk_manager:
		return Vector3.UP
		
	# Convert to 2D position
	var chunk_coord: Vector2i = _chunk_manager.world_to_chunk(world_pos)
	
	# Check if chunk is loaded
	if not _chunk_manager.is_chunk_loaded(chunk_coord):
		return Vector3.UP # Default normal if chunk not loaded
		
	# Get the chunk
	var chunk: TerrainChunk = _chunk_manager.get_chunk(chunk_coord)
	if not chunk or not chunk.base_heightmap:
		return Vector3.UP
		
	# Convert world position to local chunk coordinates
	var chunk_world_pos: Vector3 = _chunk_manager.chunk_to_world(chunk_coord)
	var local_x: float = world_pos.x - chunk_world_pos.x + (_chunk_manager.chunk_size * 0.5)
	var local_z: float = world_pos.z - chunk_world_pos.z + (_chunk_manager.chunk_size * 0.5)
	
	# Convert to heightmap pixel coordinates
	var width: int = chunk.base_heightmap.get_width()
	var height: int = chunk.base_heightmap.get_height()
	
	var px: float = (local_x / _chunk_manager.chunk_size) * float(width - 1)
	var pz: float = (local_z / _chunk_manager.chunk_size) * float(height - 1)
	
	var x: int = clampi(int(round(px)), 0, width - 1)
	var z: int = clampi(int(round(pz)), 0, height - 1)
	
	# Calculate normal at this pixel
	return _calculate_normal_at_pixel(chunk.base_heightmap, x, z, _chunk_manager.chunk_size)


## Query terrain within sonar range
##
## Returns terrain positions and normals within the specified range, 
## filtered and simplified for sonar processing.
##
## @param origin: Sonar origin position
## @param direction: Sonar beam direction (normalized)
## @param max_range: Maximum sonar range in meters
## @param beam_width: Sonar beam width in radians (cone angle)
## @return: Array of dictionaries with {position: Vector3, normal: Vector3, distance: float}
func query_terrain_for_sonar_beam(origin: Vector3, direction: Vector3, max_range: float, beam_width: float = PI/6.0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	if not _chunk_manager:
		return results
		
	# Get chunks within sonar range
	var chunks_in_range: Array[Vector2i] = _chunk_manager.get_chunks_in_radius(origin, max_range)
	
	if chunks_in_range.is_empty():
		return results
		
	var direction_normalized: Vector3 = direction.normalized()
	var cos_beam_width: float = cos(beam_width * 0.5)
	
	# Sample terrain points within beam
	for chunk_coord in chunks_in_range:
		if not _chunk_manager.is_chunk_loaded(chunk_coord):
			continue
			
		var chunk: TerrainChunk = _chunk_manager.get_chunk(chunk_coord)
		if not chunk or not chunk.base_heightmap:
			continue
			
		var heightmap: Image = chunk.base_heightmap
		var width: int = heightmap.get_width()
		var height: int = heightmap.get_height()
		
		var chunk_world_pos: Vector3 = _chunk_manager.chunk_to_world(chunk_coord)
		var chunk_size: float = _chunk_manager.chunk_size
		
		# Sample at reduced resolution for performance
		var sample_step: int = 4
		
		for z in range(0, height, sample_step):
			for x in range(0, width, sample_step):
				# Convert to world position
				var local_x: float = (float(x) / float(width - 1)) * chunk_size - (chunk_size * 0.5)
				var local_z: float = (float(z) / float(height - 1)) * chunk_size - (chunk_size * 0.5)
				
				var world_x: float = chunk_world_pos.x + local_x
				var world_z: float = chunk_world_pos.z + local_z
				
				# Get height (scaled)
				var terrain_height: float = _get_pixel_height(heightmap, x, z)
				var world_pos := Vector3(world_x, terrain_height, world_z)
				
				# Calculate direction to point
				var to_point: Vector3 = world_pos - origin
				var distance: float = to_point.length()
				
				# Filter by range
				if distance > max_range or distance < 0.1:
					continue
					
				# Filter by beam cone
				var to_point_normalized: Vector3 = to_point / distance
				var dot: float = direction_normalized.dot(to_point_normalized)
				
				if dot < cos_beam_width:
					continue
					
				# Calculate normal
				var normal: Vector3 = _calculate_normal_at_pixel(heightmap, x, z, chunk_size)
				
				results.append({
					"position": world_pos,
					"normal": normal,
					"distance": distance
				})
				
	return results


## Calculate normal at a specific pixel in heightmap
##
## Uses finite differences to compute the surface normal.
##
## @param heightmap: Heightmap image
## @param x: Pixel X coordinate
## @param z: Pixel Z coordinate
## @param chunk_size: Size of chunk in world units
## @return: Normalized surface normal
func _calculate_normal_at_pixel(heightmap: Image, x: int, z: int, chunk_size: float) -> Vector3:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()
	
	# Sample neighboring heights
	var x_left: int = maxi(x - 1, 0)
	var x_right: int = mini(x + 1, width - 1)
	var z_down: int = maxi(z - 1, 0)
	var z_up: int = mini(z + 1, height - 1)
	
	# These will now return SCALED world heights, which is correct for normal calculation
	var h_left: float = _get_pixel_height(heightmap, x_left, z)
	var h_right: float = _get_pixel_height(heightmap, x_right, z)
	var h_down: float = _get_pixel_height(heightmap, x, z_down)
	var h_up: float = _get_pixel_height(heightmap, x, z_up)
	
	# Calculate world-space step size
	var step_size: float = chunk_size / float(width - 1)
	
	# Compute normal using finite differences
	var dx: float = (h_right - h_left) / (2.0 * step_size)
	var dz: float = (h_up - h_down) / (2.0 * step_size)
	
	var normal := Vector3(-dx, 1.0, -dz)
	return normal.normalized()
