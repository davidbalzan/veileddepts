extends GutTest
## Unit tests for ChunkManager
##
## Tests chunk loading, unloading, coordinate conversion, and memory management.

var chunk_manager: ChunkManager = null


func before_each() -> void:
	chunk_manager = ChunkManager.new()
	chunk_manager.chunk_size = 512.0
	chunk_manager.max_cache_memory_mb = 10  # Small limit for testing
	add_child_autofree(chunk_manager)


func test_world_to_chunk_positive_coordinates() -> void:
	var world_pos = Vector3(1000, 0, 2000)
	var chunk_coord = chunk_manager.world_to_chunk(world_pos)
	
	assert_eq(chunk_coord.x, 1, "X coordinate should be 1")
	assert_eq(chunk_coord.y, 3, "Y coordinate should be 3")


func test_world_to_chunk_negative_coordinates() -> void:
	var world_pos = Vector3(-1000, 0, -2000)
	var chunk_coord = chunk_manager.world_to_chunk(world_pos)
	
	assert_eq(chunk_coord.x, -2, "X coordinate should be -2")
	assert_eq(chunk_coord.y, -4, "Y coordinate should be -4")


func test_world_to_chunk_at_origin() -> void:
	var world_pos = Vector3(0, 0, 0)
	var chunk_coord = chunk_manager.world_to_chunk(world_pos)
	
	assert_eq(chunk_coord.x, 0, "X coordinate should be 0")
	assert_eq(chunk_coord.y, 0, "Y coordinate should be 0")


func test_chunk_to_world_returns_center() -> void:
	var chunk_coord = Vector2i(2, 3)
	var world_pos = chunk_manager.chunk_to_world(chunk_coord)
	
	# Center of chunk (2, 3) should be at (2.5 * 512, 0, 3.5 * 512)
	assert_almost_eq(world_pos.x, 1280.0, 0.1, "X should be at chunk center")
	assert_almost_eq(world_pos.z, 1792.0, 0.1, "Z should be at chunk center")


func test_is_chunk_loaded_returns_false_for_unloaded() -> void:
	var chunk_coord = Vector2i(0, 0)
	assert_false(chunk_manager.is_chunk_loaded(chunk_coord), "Unloaded chunk should return false")


func test_load_chunk_creates_chunk() -> void:
	var chunk_coord = Vector2i(0, 0)
	var chunk = chunk_manager.load_chunk(chunk_coord)
	
	assert_not_null(chunk, "Chunk should be created")
	assert_eq(chunk.chunk_coord, chunk_coord, "Chunk should have correct coordinates")
	assert_eq(chunk.state, ChunkState.State.LOADED, "Chunk should be in LOADED state")


func test_load_chunk_generates_heightmap() -> void:
	var chunk_coord = Vector2i(0, 0)
	var chunk = chunk_manager.load_chunk(chunk_coord)
	
	assert_not_null(chunk.base_heightmap, "Chunk should have heightmap")


func test_is_chunk_loaded_returns_true_after_loading() -> void:
	var chunk_coord = Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)
	
	assert_true(chunk_manager.is_chunk_loaded(chunk_coord), "Loaded chunk should return true")


func test_get_chunk_returns_existing_chunk() -> void:
	var chunk_coord = Vector2i(0, 0)
	var chunk1 = chunk_manager.load_chunk(chunk_coord)
	var chunk2 = chunk_manager.get_chunk(chunk_coord)
	
	assert_same(chunk1, chunk2, "get_chunk should return same instance")


func test_get_chunk_loads_if_not_exists() -> void:
	var chunk_coord = Vector2i(1, 1)
	var chunk = chunk_manager.get_chunk(chunk_coord)
	
	assert_not_null(chunk, "get_chunk should load chunk if not exists")
	assert_true(chunk_manager.is_chunk_loaded(chunk_coord), "Chunk should be loaded")


func test_unload_chunk_removes_chunk() -> void:
	var chunk_coord = Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)
	
	chunk_manager.unload_chunk(chunk_coord)
	
	assert_false(chunk_manager.is_chunk_loaded(chunk_coord), "Chunk should be unloaded")


func test_unload_chunk_frees_memory() -> void:
	var chunk_coord = Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)
	
	var memory_before = chunk_manager.get_memory_usage_mb()
	chunk_manager.unload_chunk(chunk_coord)
	var memory_after = chunk_manager.get_memory_usage_mb()
	
	assert_lt(memory_after, memory_before, "Memory should decrease after unload")


func test_get_chunk_state_unloaded() -> void:
	var chunk_coord = Vector2i(5, 5)
	var state = chunk_manager.get_chunk_state(chunk_coord)
	
	assert_eq(state, ChunkState.State.UNLOADED, "State should be UNLOADED")


func test_get_chunk_state_loaded() -> void:
	var chunk_coord = Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)
	
	var state = chunk_manager.get_chunk_state(chunk_coord)
	assert_eq(state, ChunkState.State.LOADED, "State should be LOADED")


func test_get_loaded_chunks_returns_loaded_only() -> void:
	chunk_manager.load_chunk(Vector2i(0, 0))
	chunk_manager.load_chunk(Vector2i(1, 1))
	
	var loaded = chunk_manager.get_loaded_chunks()
	
	assert_eq(loaded.size(), 2, "Should have 2 loaded chunks")
	assert_has(loaded, Vector2i(0, 0), "Should contain (0, 0)")
	assert_has(loaded, Vector2i(1, 1), "Should contain (1, 1)")


func test_get_chunk_count() -> void:
	chunk_manager.load_chunk(Vector2i(0, 0))
	chunk_manager.load_chunk(Vector2i(1, 1))
	
	assert_eq(chunk_manager.get_chunk_count(), 2, "Should have 2 chunks")


func test_memory_tracking_increases_on_load() -> void:
	var memory_before = chunk_manager.get_memory_usage_mb()
	chunk_manager.load_chunk(Vector2i(0, 0))
	var memory_after = chunk_manager.get_memory_usage_mb()
	
	assert_gt(memory_after, memory_before, "Memory should increase after loading")


func test_get_chunks_in_radius() -> void:
	var world_pos = Vector3(0, 0, 0)
	var radius = 1000.0  # Should cover multiple chunks
	
	var chunks = chunk_manager.get_chunks_in_radius(world_pos, radius)
	
	assert_gt(chunks.size(), 0, "Should find chunks in radius")
	assert_has(chunks, Vector2i(0, 0), "Should include origin chunk")


func test_get_distance_to_chunk() -> void:
	var world_pos = Vector3(0, 0, 0)
	var chunk_coord = Vector2i(0, 0)
	
	var distance = chunk_manager.get_distance_to_chunk(world_pos, chunk_coord)
	
	assert_eq(distance, 0.0, "Distance to containing chunk should be 0")


func test_get_distance_to_distant_chunk() -> void:
	var world_pos = Vector3(0, 0, 0)
	var chunk_coord = Vector2i(5, 5)
	
	var distance = chunk_manager.get_distance_to_chunk(world_pos, chunk_coord)
	
	assert_gt(distance, 0.0, "Distance to distant chunk should be positive")
