## ChunkCoordinates utility class for chunk coordinate system management
##
## Provides conversion between world coordinates and chunk grid coordinates.
## Uses a consistent grid-based coordinate system:
## - Origin (0, 0) at world origin
## - Positive X = East, Positive Z = North
## - Chunk (x, z) covers world region [x*size, (x+1)*size] × [z*size, (z+1)*size]
## - Supports negative coordinates for regions west/south of origin
## - Consistent rounding: floor(world_pos / chunk_size)

class_name ChunkCoordinates

## Chunk size in meters
var chunk_size: float = 512.0


func _init(p_chunk_size: float = 512.0) -> void:
	chunk_size = p_chunk_size


## Convert world position to chunk coordinates
##
## Uses floor division to ensure consistent rounding.
## Negative world positions map to negative chunk coordinates.
##
## @param world_pos: World position (uses X and Z components)
## @return: Chunk coordinates as Vector2i
func world_to_chunk(world_pos: Vector3) -> Vector2i:
	var chunk_x: int = floori(world_pos.x / chunk_size)
	var chunk_z: int = floori(world_pos.z / chunk_size)
	return Vector2i(chunk_x, chunk_z)


## Convert chunk coordinates to world position (center of chunk)
##
## Returns the center point of the chunk in world space.
##
## @param chunk_coord: Chunk coordinates
## @return: World position at chunk center
func chunk_to_world(chunk_coord: Vector2i) -> Vector3:
	var world_x: float = (chunk_coord.x + 0.5) * chunk_size
	var world_z: float = (chunk_coord.y + 0.5) * chunk_size
	return Vector3(world_x, 0.0, world_z)


## Get the world bounds (Rect2) for a chunk
##
## Returns a Rect2 representing the chunk's coverage in world XZ plane.
##
## @param chunk_coord: Chunk coordinates
## @return: Rect2 with position and size in world coordinates
func get_chunk_bounds(chunk_coord: Vector2i) -> Rect2:
	var world_x: float = chunk_coord.x * chunk_size
	var world_z: float = chunk_coord.y * chunk_size
	return Rect2(world_x, world_z, chunk_size, chunk_size)


## Get the corner position (minimum X, Z) of a chunk
##
## @param chunk_coord: Chunk coordinates
## @return: World position at chunk corner (min X, min Z)
func get_chunk_corner(chunk_coord: Vector2i) -> Vector3:
	var world_x: float = chunk_coord.x * chunk_size
	var world_z: float = chunk_coord.y * chunk_size
	return Vector3(world_x, 0.0, world_z)


## Check if a world position is within a chunk's bounds
##
## @param world_pos: World position to check
## @param chunk_coord: Chunk coordinates
## @return: True if position is within chunk bounds
func is_position_in_chunk(world_pos: Vector3, chunk_coord: Vector2i) -> bool:
	var bounds: Rect2 = get_chunk_bounds(chunk_coord)
	return bounds.has_point(Vector2(world_pos.x, world_pos.z))


## Get all chunk coordinates within a radius of a world position
##
## @param world_pos: Center world position
## @param radius: Radius in meters
## @return: Array of Vector2i chunk coordinates
func get_chunks_in_radius(world_pos: Vector3, radius: float) -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	var center_chunk: Vector2i = world_to_chunk(world_pos)
	
	# Calculate how many chunks to check in each direction
	var chunk_radius: int = ceili(radius / chunk_size) + 1
	
	for x in range(center_chunk.x - chunk_radius, center_chunk.x + chunk_radius + 1):
		for z in range(center_chunk.y - chunk_radius, center_chunk.y + chunk_radius + 1):
			var chunk_coord: Vector2i = Vector2i(x, z)
			var chunk_center: Vector3 = chunk_to_world(chunk_coord)
			
			# Check if chunk center is within radius
			var distance: float = world_pos.distance_to(chunk_center)
			if distance <= radius + chunk_size * 0.707:  # Add diagonal tolerance
				chunks.append(chunk_coord)
	
	return chunks


## Get the distance from a world position to the nearest point in a chunk
##
## @param world_pos: World position
## @param chunk_coord: Chunk coordinates
## @return: Distance in meters
func get_distance_to_chunk(world_pos: Vector3, chunk_coord: Vector2i) -> float:
	var bounds: Rect2 = get_chunk_bounds(chunk_coord)
	var pos_2d: Vector2 = Vector2(world_pos.x, world_pos.z)
	
	# Find closest point in bounds to position
	var closest_x: float = clampf(pos_2d.x, bounds.position.x, bounds.position.x + bounds.size.x)
	var closest_z: float = clampf(pos_2d.y, bounds.position.y, bounds.position.y + bounds.size.y)
	var closest_point: Vector2 = Vector2(closest_x, closest_z)
	
	return pos_2d.distance_to(closest_point)
