extends GutTest
## Unit tests for StreamingManager
##
## Tests the basic functionality of the streaming manager including:
## - Initialization and configuration
## - Load queue management
## - Unload queue management
## - Priority sorting
## - Frame time budget enforcement

var streaming_manager: StreamingManager = null
var chunk_manager: ChunkManager = null


func before_each() -> void:
	# Create a test scene tree structure
	var root = Node.new()
	add_child_autofree(root)

	# Create ChunkManager
	chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	chunk_manager.chunk_size = 512.0
	root.add_child(chunk_manager)

	# Create StreamingManager
	streaming_manager = StreamingManager.new()
	streaming_manager.name = "StreamingManager"
	streaming_manager.chunk_size = 512.0
	streaming_manager.load_distance = 1024.0
	streaming_manager.unload_distance = 2048.0
	streaming_manager.max_chunks_per_frame = 2
	streaming_manager.max_load_time_ms = 2.0
	root.add_child(streaming_manager)

	# Disable async loading for deterministic tests
	streaming_manager.set_async_loading(false)

	# Wait for ready
	await wait_frames(1)


func test_initialization() -> void:
	assert_not_null(streaming_manager, "StreamingManager should be created")
	assert_not_null(streaming_manager._chunk_manager, "StreamingManager should find ChunkManager")
	assert_eq(streaming_manager.chunk_size, 512.0, "Chunk size should be set")


func test_load_queue_population() -> void:
	# Position submarine at origin
	var submarine_pos = Vector3(0, 0, 0)

	# Update streaming manager
	streaming_manager.update(submarine_pos)

	# Should have chunks in load queue (within load_distance)
	var loaded_chunks = streaming_manager.get_loaded_chunks()
	assert_gt(loaded_chunks.size(), 0, "Should have loaded some chunks near origin")


func test_chunk_loading_proximity() -> void:
	# Position submarine at a specific location
	var submarine_pos = Vector3(256, 0, 256)  # Center of chunk (0, 0)

	# Update streaming manager
	streaming_manager.update(submarine_pos)
	await wait_frames(2)

	# Check that chunk (0, 0) is loaded
	var loaded_chunks = streaming_manager.get_loaded_chunks()
	assert_true(
		loaded_chunks.has(Vector2i(0, 0)),
		"Chunk (0,0) should be loaded when submarine is at (256, 256)"
	)


func test_chunk_unloading_distance() -> void:
	# Start at origin
	var submarine_pos = Vector3(256, 0, 256)
	streaming_manager.update(submarine_pos)
	await wait_frames(2)

	# Verify chunk is loaded
	assert_true(
		streaming_manager.get_loaded_chunks().has(Vector2i(0, 0)),
		"Chunk should be loaded initially"
	)

	# Move submarine far away (beyond unload_distance)
	submarine_pos = Vector3(5000, 0, 5000)
	streaming_manager.update(submarine_pos)
	await wait_frames(2)

	# Verify chunk is unloaded
	assert_false(
		streaming_manager.get_loaded_chunks().has(Vector2i(0, 0)),
		"Chunk should be unloaded when submarine is far away"
	)


func test_load_prioritization() -> void:
	# Position submarine at origin
	var submarine_pos = Vector3(0, 0, 0)

	# Update streaming manager
	streaming_manager.update(submarine_pos)
	await wait_frames(1)

	# Get loaded chunks
	var loaded_chunks = streaming_manager.get_loaded_chunks()

	# Verify that closer chunks are loaded first
	# Chunk (0, 0) should be loaded before distant chunks
	if loaded_chunks.size() > 0:
		var has_origin_chunk = loaded_chunks.has(Vector2i(0, 0))
		assert_true(
			has_origin_chunk, "Origin chunk should be prioritized when submarine is at origin"
		)


func test_max_chunks_per_frame() -> void:
	# Set a low limit
	streaming_manager.max_chunks_per_frame = 1

	# Position submarine at origin
	var submarine_pos = Vector3(0, 0, 0)

	# Count chunks before
	var chunks_before = streaming_manager.get_loaded_chunks().size()

	# Single update should load at most max_chunks_per_frame
	streaming_manager.update(submarine_pos)

	var chunks_after = streaming_manager.get_loaded_chunks().size()
	var chunks_loaded = chunks_after - chunks_before

	assert_lte(
		chunks_loaded,
		streaming_manager.max_chunks_per_frame,
		"Should not load more than max_chunks_per_frame in one update"
	)


func test_loading_progress() -> void:
	# Position submarine at origin
	var submarine_pos = Vector3(0, 0, 0)

	# Initial progress should be 1.0 (nothing to load yet)
	var initial_progress = streaming_manager.get_loading_progress()
	assert_eq(initial_progress, 1.0, "Initial progress should be 1.0")

	# After update, progress should reflect loading state
	streaming_manager.update(submarine_pos)
	var progress = streaming_manager.get_loading_progress()
	assert_between(progress, 0.0, 1.0, "Progress should be between 0 and 1")


func test_force_load_chunk() -> void:
	# Force load a specific chunk
	var chunk_coord = Vector2i(5, 5)
	streaming_manager.load_chunk(chunk_coord)

	# Process the load queue
	streaming_manager.update(Vector3(0, 0, 0))
	await wait_frames(2)

	# Verify chunk is loaded
	var loaded_chunks = streaming_manager.get_loaded_chunks()
	assert_true(loaded_chunks.has(chunk_coord), "Force-loaded chunk should be in loaded chunks")


func test_force_unload_chunk() -> void:
	# Load a chunk first
	var submarine_pos = Vector3(256, 0, 256)
	streaming_manager.update(submarine_pos)
	await wait_frames(2)

	var chunk_coord = Vector2i(0, 0)
	assert_true(
		streaming_manager.get_loaded_chunks().has(chunk_coord), "Chunk should be loaded initially"
	)

	# Force unload it
	streaming_manager.unload_chunk(chunk_coord)
	await wait_frames(1)

	# Verify it's unloaded
	assert_false(
		streaming_manager.get_loaded_chunks().has(chunk_coord),
		"Force-unloaded chunk should not be in loaded chunks"
	)


func test_async_loading_toggle() -> void:
	# Test enabling/disabling async loading
	streaming_manager.set_async_loading(true)
	assert_true(streaming_manager.is_async_loading_enabled(), "Async loading should be enabled")

	streaming_manager.set_async_loading(false)
	assert_false(streaming_manager.is_async_loading_enabled(), "Async loading should be disabled")
