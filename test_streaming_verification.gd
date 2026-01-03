extends Node
## Verification script for Task 5: Basic Streaming System Checkpoint
##
## This script verifies that:
## 1. Chunks load/unload based on submarine position
## 2. Memory management works correctly
## 3. Coordinate system is correct
##
## Run this script to verify the basic streaming system is working.

# Test configuration
const TEST_DURATION_SECONDS: float = 10.0
const SUBMARINE_SPEED: float = 50.0  # meters per second
const MEMORY_LIMIT_MB: int = 50

# Components
var streaming_manager: StreamingManager = null
var chunk_manager: ChunkManager = null
var submarine_position: Vector3 = Vector3.ZERO
var test_start_time: float = 0.0
var test_phase: int = 0

# Test results
var test_results: Dictionary = {
	"coordinate_system": false,
	"chunk_loading": false,
	"chunk_unloading": false,
	"memory_management": false,
	"priority_sorting": false
}

# UI
var label: Label = null


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("STREAMING SYSTEM VERIFICATION - TASK 5 CHECKPOINT")
	print("=".repeat(60))

	# Create UI
	_setup_ui()

	# Create streaming system
	_setup_streaming_system()

	# Start test
	test_start_time = Time.get_ticks_msec() / 1000.0
	submarine_position = Vector3(256, 0, 256)  # Start at center of chunk (0, 0)

	print("\nStarting verification tests...")
	print("Initial submarine position: %s" % submarine_position)


func _setup_ui() -> void:
	# Create a label to display test status
	label = Label.new()
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)


func _setup_streaming_system() -> void:
	# Create ChunkManager
	chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	chunk_manager.chunk_size = 512.0
	chunk_manager.max_cache_memory_mb = MEMORY_LIMIT_MB
	add_child(chunk_manager)

	# Create StreamingManager
	streaming_manager = StreamingManager.new()
	streaming_manager.name = "StreamingManager"
	streaming_manager.chunk_size = 512.0
	streaming_manager.load_distance = 1024.0  # 2 chunks
	streaming_manager.unload_distance = 2048.0  # 4 chunks
	streaming_manager.max_chunks_per_frame = 2
	streaming_manager.max_load_time_ms = 2.0
	add_child(streaming_manager)

	# Disable async loading for deterministic testing
	streaming_manager.set_async_loading(false)

	print("\nStreaming system initialized:")
	print("  Chunk size: %.0f m" % chunk_manager.chunk_size)
	print("  Load distance: %.0f m" % streaming_manager.load_distance)
	print("  Unload distance: %.0f m" % streaming_manager.unload_distance)
	print("  Memory limit: %d MB" % MEMORY_LIMIT_MB)


func _process(delta: float) -> void:
	var elapsed = Time.get_ticks_msec() / 1000.0 - test_start_time

	# Run different test phases
	match test_phase:
		0:
			_test_coordinate_system()
			test_phase = 1
		1:
			_test_chunk_loading()
			test_phase = 2
		2:
			if elapsed > 2.0:
				_test_chunk_unloading()
				test_phase = 3
		3:
			if elapsed > 4.0:
				_test_memory_management()
				test_phase = 4
		4:
			if elapsed > 6.0:
				_test_priority_sorting()
				test_phase = 5
		5:
			if elapsed > 8.0:
				_print_final_results()
				test_phase = 6
		6:
			# Tests complete
			pass

	# Update streaming manager
	streaming_manager.update(submarine_position)

	# Update UI
	_update_ui()


func _test_coordinate_system() -> void:
	print("\n--- Test 1: Coordinate System ---")

	# Test 1: World to chunk conversion
	var test_pos = Vector3(1000, 0, 2000)
	var chunk_coord = chunk_manager.world_to_chunk(test_pos)
	var expected = Vector2i(1, 3)

	print("  World pos %s -> Chunk %s (expected %s)" % [test_pos, chunk_coord, expected])

	if chunk_coord == expected:
		print("  ✓ World to chunk conversion correct")
	else:
		print("  ✗ World to chunk conversion FAILED")
		return

	# Test 2: Chunk to world conversion
	var world_pos = chunk_manager.chunk_to_world(chunk_coord)
	var expected_world = Vector3(1280, 0, 1792)  # Center of chunk (1, 3)

	print("  Chunk %s -> World pos %s (expected %s)" % [chunk_coord, world_pos, expected_world])

	if world_pos.distance_to(expected_world) < 0.1:
		print("  ✓ Chunk to world conversion correct")
	else:
		print("  ✗ Chunk to world conversion FAILED")
		return

	# Test 3: Round trip
	var round_trip_chunk = chunk_manager.world_to_chunk(world_pos)
	print("  Round trip: %s -> %s -> %s" % [chunk_coord, world_pos, round_trip_chunk])

	if round_trip_chunk == chunk_coord:
		print("  ✓ Round trip conversion correct")
		test_results["coordinate_system"] = true
	else:
		print("  ✗ Round trip conversion FAILED")


func _test_chunk_loading() -> void:
	print("\n--- Test 2: Chunk Loading ---")

	# Position submarine at origin
	submarine_position = Vector3(256, 0, 256)
	streaming_manager.update(submarine_position)

	# Wait a frame for loading
	await get_tree().process_frame

	var loaded_chunks = streaming_manager.get_loaded_chunks()
	print("  Submarine at %s" % submarine_position)
	print("  Loaded chunks: %d" % loaded_chunks.size())
	print("  Chunks: %s" % loaded_chunks)

	# Check that chunk (0, 0) is loaded
	if loaded_chunks.has(Vector2i(0, 0)):
		print("  ✓ Chunk (0, 0) loaded when submarine nearby")
		test_results["chunk_loading"] = true
	else:
		print("  ✗ Chunk (0, 0) NOT loaded when submarine nearby")

	# Check that chunks are within load distance
	var all_within_distance = true
	for chunk_coord in loaded_chunks:
		var distance = chunk_manager.get_distance_to_chunk(submarine_position, chunk_coord)
		if distance > streaming_manager.load_distance:
			print(
				(
					"  ✗ Chunk %s loaded but distance %.0f > load_distance %.0f"
					% [chunk_coord, distance, streaming_manager.load_distance]
				)
			)
			all_within_distance = false

	if all_within_distance:
		print("  ✓ All loaded chunks within load distance")


func _test_chunk_unloading() -> void:
	print("\n--- Test 3: Chunk Unloading ---")

	# Move submarine far away
	submarine_position = Vector3(5000, 0, 5000)
	streaming_manager.update(submarine_position)

	# Wait a frame for unloading
	await get_tree().process_frame

	var loaded_chunks = streaming_manager.get_loaded_chunks()
	print("  Submarine moved to %s" % submarine_position)
	print("  Loaded chunks: %d" % loaded_chunks.size())
	print("  Chunks: %s" % loaded_chunks)

	# Check that chunk (0, 0) is unloaded
	if not loaded_chunks.has(Vector2i(0, 0)):
		print("  ✓ Chunk (0, 0) unloaded when submarine far away")
		test_results["chunk_unloading"] = true
	else:
		print("  ✗ Chunk (0, 0) still loaded when submarine far away")

	# Check that no chunks are beyond unload distance
	var all_within_unload = true
	for chunk_coord in loaded_chunks:
		var distance = chunk_manager.get_distance_to_chunk(submarine_position, chunk_coord)
		if distance > streaming_manager.unload_distance:
			print(
				(
					"  ✗ Chunk %s still loaded but distance %.0f > unload_distance %.0f"
					% [chunk_coord, distance, streaming_manager.unload_distance]
				)
			)
			all_within_unload = false

	if all_within_unload:
		print("  ✓ No chunks beyond unload distance")


func _test_memory_management() -> void:
	print("\n--- Test 4: Memory Management ---")

	# Load many chunks to test memory limit
	submarine_position = Vector3(256, 0, 256)

	# Force load many chunks
	for x in range(-5, 6):
		for z in range(-5, 6):
			streaming_manager.load_chunk(Vector2i(x, z))
			streaming_manager.update(submarine_position)
			await get_tree().process_frame

	var memory_usage = chunk_manager.get_memory_usage_mb()
	var loaded_count = streaming_manager.get_loaded_chunks().size()

	print("  Attempted to load 121 chunks")
	print("  Actually loaded: %d chunks" % loaded_count)
	print("  Memory usage: %.2f MB / %d MB" % [memory_usage, MEMORY_LIMIT_MB])

	if memory_usage <= MEMORY_LIMIT_MB:
		print("  ✓ Memory usage within limit")
		test_results["memory_management"] = true
	else:
		print("  ✗ Memory usage EXCEEDS limit")

	if loaded_count < 121:
		print("  ✓ LRU eviction working (not all chunks loaded)")
	else:
		print("  ⚠ All chunks loaded (memory limit may be too high)")


func _test_priority_sorting() -> void:
	print("\n--- Test 5: Priority Sorting ---")

	# Position submarine and check that closest chunks are loaded first
	submarine_position = Vector3(0, 0, 0)

	# Clear all chunks first
	for chunk_coord in streaming_manager.get_loaded_chunks():
		streaming_manager.unload_chunk(chunk_coord)

	await get_tree().process_frame

	# Update with limited chunks per frame
	streaming_manager.max_chunks_per_frame = 1
	streaming_manager.update(submarine_position)
	await get_tree().process_frame

	var loaded_chunks = streaming_manager.get_loaded_chunks()

	if loaded_chunks.size() > 0:
		var first_chunk = loaded_chunks[0]
		var distance = chunk_manager.get_distance_to_chunk(submarine_position, first_chunk)

		print("  First chunk loaded: %s (distance: %.0f m)" % [first_chunk, distance])

		# Check if it's the closest chunk (should be (0, 0) or (-1, -1) depending on position)
		if distance < 100.0:  # Should be very close
			print("  ✓ Closest chunk loaded first")
			test_results["priority_sorting"] = true
		else:
			print("  ✗ First loaded chunk not the closest")
	else:
		print("  ✗ No chunks loaded")


func _print_final_results() -> void:
	print("\n" + "=".repeat(60))
	print("VERIFICATION RESULTS")
	print("=".repeat(60))

	var all_passed = true

	for test_name in test_results.keys():
		var passed = test_results[test_name]
		var status = "✓ PASS" if passed else "✗ FAIL"
		print("  %s: %s" % [test_name.capitalize().replace("_", " "), status])
		if not passed:
			all_passed = false

	print("=".repeat(60))

	if all_passed:
		print("✓ ALL TESTS PASSED - Basic streaming system is working!")
	else:
		print("✗ SOME TESTS FAILED - Please review the output above")

	print("\nPress ESC to exit")


func _update_ui() -> void:
	if not label:
		return

	var loaded_chunks = streaming_manager.get_loaded_chunks()
	var memory_usage = chunk_manager.get_memory_usage_mb()
	var progress = streaming_manager.get_loading_progress()

	var text = "STREAMING SYSTEM VERIFICATION\n\n"
	text += (
		"Submarine Position: (%.0f, %.0f, %.0f)\n"
		% [submarine_position.x, submarine_position.y, submarine_position.z]
	)
	text += "Loaded Chunks: %d\n" % loaded_chunks.size()
	text += "Memory Usage: %.2f / %d MB\n" % [memory_usage, MEMORY_LIMIT_MB]
	text += "Loading Progress: %.0f%%\n\n" % (progress * 100)

	text += "Test Results:\n"
	for test_name in test_results.keys():
		var passed = test_results[test_name]
		var status = "✓" if passed else "⏳"
		text += "  %s %s\n" % [status, test_name.capitalize().replace("_", " ")]

	label.text = text


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("\nExiting verification...")
			get_tree().quit()
