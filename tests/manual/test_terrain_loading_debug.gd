extends Node

## Debug test to check if terrain is actually loading


func _ready():
	print("\n=== TERRAIN LOADING DEBUG TEST ===\n")

	# Wait for scene to fully load
	await get_tree().create_timer(3.0).timeout

	# Find terrain renderer
	var terrain_renderer = get_node_or_null("/root/Main/TerrainRenderer")
	if not terrain_renderer:
		print("ERROR: TerrainRenderer not found at /root/Main/TerrainRenderer")
		_check_alternate_paths()
		get_tree().quit()
		return

	print("✓ Found TerrainRenderer")
	print("  Initialized: ", terrain_renderer.initialized)

	# Check submarine
	var submarine = get_node_or_null("/root/Main/SubmarineModel")
	if not submarine:
		print("ERROR: Submarine not found at /root/Main/SubmarineModel")
		_check_alternate_paths()
	else:
		print("✓ Found Submarine")
		print("  Position: ", submarine.global_position)

	# Check streaming manager
	var streaming_manager = terrain_renderer.get_node_or_null("StreamingManager")
	if not streaming_manager:
		print("ERROR: StreamingManager not found")
	else:
		print("✓ Found StreamingManager")
		var loaded_chunks = streaming_manager.get_loaded_chunks()
		print("  Loaded chunks: ", loaded_chunks.size())
		print("  Chunks: ", loaded_chunks)

	# Check chunk manager
	var chunk_manager = terrain_renderer.get_node_or_null("ChunkManager")
	if not chunk_manager:
		print("ERROR: ChunkManager not found")
	else:
		print("✓ Found ChunkManager")
		print("  Chunk count: ", chunk_manager.get_chunk_count())
		print("  Memory usage: %.2f MB" % chunk_manager.get_memory_usage_mb())

	# Check elevation provider
	var elevation_provider = terrain_renderer.get_node_or_null("ElevationDataProvider")
	if not elevation_provider:
		print("ERROR: ElevationDataProvider not found")
	else:
		print("✓ Found ElevationDataProvider")
		# Test elevation at submarine position
		if submarine:
			var test_pos = Vector2(submarine.global_position.x, submarine.global_position.z)
			var elevation = elevation_provider.get_elevation(test_pos)
			print("  Elevation at submarine: %.2f m" % elevation)

	# Wait a bit more and check again
	print("\nWaiting 2 more seconds for chunks to load...")
	await get_tree().create_timer(2.0).timeout

	if streaming_manager:
		var loaded_chunks = streaming_manager.get_loaded_chunks()
		print("  Loaded chunks after wait: ", loaded_chunks.size())
		print("  Chunks: ", loaded_chunks)

	# Check if any terrain chunks exist in the scene
	print("\nSearching for TerrainChunk nodes in scene tree...")
	_find_terrain_chunks(get_tree().root)

	print("\n=== TEST COMPLETE ===\n")
	get_tree().quit()


func _check_alternate_paths():
	print("\nChecking alternate paths...")
	var main = get_node_or_null("/root/Main")
	if main:
		print("Found Main node, children:")
		for child in main.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
	else:
		print("Main node not found!")


func _find_terrain_chunks(node: Node, depth: int = 0):
	if node.get_class() == "TerrainChunk" or node.name.begins_with("TerrainChunk"):
		var indent = "  ".repeat(depth)
		print(indent, "Found: ", node.get_path())

	for child in node.get_children():
		_find_terrain_chunks(child, depth + 1)
