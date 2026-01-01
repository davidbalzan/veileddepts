class_name ChunkManager extends Node
## Manages terrain chunk lifecycle, coordinate system, and caching
##
## Responsibilities:
## - Chunk grid storage and coordinate conversion
## - LRU cache with configurable memory limit
## - Chunk state tracking
## - Memory usage monitoring

# Chunk cache configuration
@export var max_cache_memory_mb: int = 512
@export var chunk_size: float = 512.0

# Internal state
var _chunk_grid: Dictionary = {}  # Vector2i -> TerrainChunk
var _chunk_coordinates: ChunkCoordinates = null
var _elevation_provider: ElevationDataProvider = null
var _total_memory_bytes: int = 0
var _lru_list: Array[Vector2i] = []  # Least recently used order


func _init() -> void:
	_chunk_coordinates = ChunkCoordinates.new(chunk_size)


func _ready() -> void:
	# Find or create elevation provider
	_elevation_provider = get_node_or_null("/root/ElevationDataProvider")
	if not _elevation_provider:
		_elevation_provider = ElevationDataProvider.new()
		add_child(_elevation_provider)
	
	# Initialize if not already done
	if not _elevation_provider._initialized:
		_elevation_provider.initialize()


## Convert world position to chunk coordinates
##
## Uses floor division to ensure consistent rounding.
## Negative world positions map to negative chunk coordinates.
##
## @param world_pos: World position (uses X and Z components)
## @return: Chunk coordinates as Vector2i
func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return _chunk_coordinates.world_to_chunk(world_pos)


## Convert chunk coordinates to world position (center of chunk)
##
## Returns the center point of the chunk in world space.
##
## @param chunk_coord: Chunk coordinates
## @return: World position at chunk center
func chunk_to_world(chunk_coord: Vector2i) -> Vector3:
	return _chunk_coordinates.chunk_to_world(chunk_coord)


## Get chunk at coordinates (load if needed)
##
## Implements lazy loading: if chunk is not loaded, it will be loaded.
## Updates LRU cache on access.
##
## @param chunk_coord: Chunk coordinates
## @return: TerrainChunk instance (may be in LOADING state)
func get_chunk(chunk_coord: Vector2i) -> TerrainChunk:
	# Check if chunk exists
	if _chunk_grid.has(chunk_coord):
		var chunk: TerrainChunk = _chunk_grid[chunk_coord]
		_touch_chunk(chunk_coord)
		return chunk
	
	# Chunk doesn't exist, load it
	return load_chunk(chunk_coord)


## Check if chunk is loaded
##
## @param chunk_coord: Chunk coordinates
## @return: True if chunk is loaded (state == LOADED)
func is_chunk_loaded(chunk_coord: Vector2i) -> bool:
	if not _chunk_grid.has(chunk_coord):
		return false
	
	var chunk: TerrainChunk = _chunk_grid[chunk_coord]
	return chunk.state == ChunkState.State.LOADED


## Load a chunk at the specified coordinates
##
## Creates a new TerrainChunk, generates its heightmap, and adds it to the cache.
## Enforces memory limits by unloading distant chunks if necessary.
##
## @param chunk_coord: Chunk coordinates
## @return: TerrainChunk instance (in LOADING or LOADED state)
func load_chunk(chunk_coord: Vector2i) -> TerrainChunk:
	# Check if already exists
	if _chunk_grid.has(chunk_coord):
		return _chunk_grid[chunk_coord]
	
	# Enforce memory limit before loading
	_enforce_memory_limit()
	
	# Create new chunk
	var chunk: TerrainChunk = TerrainChunk.new()
	chunk.chunk_coord = chunk_coord
	chunk.world_bounds = _chunk_coordinates.get_chunk_bounds(chunk_coord)
	chunk.state = ChunkState.State.LOADING
	
	# Add to scene tree
	add_child(chunk)
	
	# Position chunk in world
	var world_pos: Vector3 = _chunk_coordinates.get_chunk_corner(chunk_coord)
	chunk.position = world_pos
	
	# Generate heightmap
	_generate_heightmap(chunk)
	
	# Update state
	chunk.state = ChunkState.State.LOADED
	chunk.touch()
	
	# Add to grid and LRU
	_chunk_grid[chunk_coord] = chunk
	_lru_list.append(chunk_coord)
	
	# Update memory tracking
	var chunk_memory: int = chunk.calculate_memory_size()
	_total_memory_bytes += chunk_memory
	
	print("ChunkManager: Loaded chunk %s (memory: %.2f MB, total: %.2f MB)" % [
		chunk_coord,
		chunk_memory / 1048576.0,
		_total_memory_bytes / 1048576.0
	])
	
	return chunk


## Unload chunk and free memory
##
## Removes chunk from cache, cleans up resources, and updates memory tracking.
##
## @param chunk_coord: Chunk coordinates
func unload_chunk(chunk_coord: Vector2i) -> void:
	if not _chunk_grid.has(chunk_coord):
		return
	
	var chunk: TerrainChunk = _chunk_grid[chunk_coord]
	
	# Update memory tracking before cleanup
	_total_memory_bytes -= chunk.memory_size_bytes
	
	# Mark as unloading
	chunk.state = ChunkState.State.UNLOADING
	
	# Clean up resources
	chunk.cleanup()
	
	# Remove from scene tree
	chunk.queue_free()
	
	# Remove from grid and LRU
	_chunk_grid.erase(chunk_coord)
	_lru_list.erase(chunk_coord)
	
	print("ChunkManager: Unloaded chunk %s (total memory: %.2f MB)" % [
		chunk_coord,
		_total_memory_bytes / 1048576.0
	])


## Get current memory usage in megabytes
##
## @return: Memory usage in MB
func get_memory_usage_mb() -> float:
	return _total_memory_bytes / 1048576.0


## Get chunk state (unloaded, loading, loaded)
##
## @param chunk_coord: Chunk coordinates
## @return: ChunkState.State enum value
func get_chunk_state(chunk_coord: Vector2i) -> int:
	if not _chunk_grid.has(chunk_coord):
		return ChunkState.State.UNLOADED
	
	var chunk: TerrainChunk = _chunk_grid[chunk_coord]
	return chunk.state


## Get all loaded chunk coordinates
##
## @return: Array of Vector2i chunk coordinates
func get_loaded_chunks() -> Array[Vector2i]:
	var loaded: Array[Vector2i] = []
	for coord in _chunk_grid.keys():
		if is_chunk_loaded(coord):
			loaded.append(coord)
	return loaded


## Get total number of chunks in cache (any state)
##
## @return: Number of chunks
func get_chunk_count() -> int:
	return _chunk_grid.size()


## Generate heightmap for a chunk using ElevationDataProvider
##
## @param chunk: TerrainChunk to generate heightmap for
func _generate_heightmap(chunk: TerrainChunk) -> void:
	if not _elevation_provider:
		push_error("ChunkManager: No elevation provider available")
		return
	
	# Extract elevation data for this chunk's world bounds
	var resolution: int = 128  # Default heightmap resolution
	chunk.base_heightmap = _elevation_provider.extract_region(chunk.world_bounds, resolution)
	
	if not chunk.base_heightmap:
		push_error("ChunkManager: Failed to generate heightmap for chunk %s" % chunk.chunk_coord)


## Update LRU list when chunk is accessed
##
## @param chunk_coord: Chunk coordinates
func _touch_chunk(chunk_coord: Vector2i) -> void:
	# Remove from current position in LRU list
	var index: int = _lru_list.find(chunk_coord)
	if index >= 0:
		_lru_list.remove_at(index)
	
	# Add to end (most recently used)
	_lru_list.append(chunk_coord)
	
	# Update chunk's access time
	if _chunk_grid.has(chunk_coord):
		var chunk: TerrainChunk = _chunk_grid[chunk_coord]
		chunk.touch()


## Enforce memory limit by unloading least recently used chunks
func _enforce_memory_limit() -> void:
	var max_bytes: int = max_cache_memory_mb * 1048576
	
	# Unload chunks until we're under the limit
	while _total_memory_bytes > max_bytes and _lru_list.size() > 0:
		# Get least recently used chunk
		var lru_coord: Vector2i = _lru_list[0]
		
		print("ChunkManager: Memory limit reached (%.2f MB / %d MB), unloading LRU chunk %s" % [
			_total_memory_bytes / 1048576.0,
			max_cache_memory_mb,
			lru_coord
		])
		
		unload_chunk(lru_coord)


## Get distance from a world position to a chunk
##
## @param world_pos: World position
## @param chunk_coord: Chunk coordinates
## @return: Distance in meters
func get_distance_to_chunk(world_pos: Vector3, chunk_coord: Vector2i) -> float:
	return _chunk_coordinates.get_distance_to_chunk(world_pos, chunk_coord)


## Get all chunks within a radius of a world position
##
## @param world_pos: Center world position
## @param radius: Radius in meters
## @return: Array of Vector2i chunk coordinates
func get_chunks_in_radius(world_pos: Vector3, radius: float) -> Array[Vector2i]:
	return _chunk_coordinates.get_chunks_in_radius(world_pos, radius)
