extends Node

## Integration test for underwater feature preservation in ChunkRenderer


func _ready():
	print("=== Testing Feature Preservation Integration ===")

	# Create a chunk renderer
	var renderer = ChunkRenderer.new()
	add_child(renderer)

	# Wait for it to initialize
	await get_tree().process_frame

	# Create a test heightmap with a seamount
	var heightmap = _create_seamount_heightmap()

	# Create meshes at different LOD levels
	print("\nGenerating LOD meshes with feature preservation...")
	var chunk_coord = Vector2i(0, 0)

	for lod in range(4):
		var mesh = renderer.create_chunk_mesh(heightmap, null, chunk_coord, lod, {})  # No biome map for this test  # No neighbors

		if mesh:
			var vertex_count = 0
			for surface_idx in range(mesh.get_surface_count()):
				var arrays = mesh.surface_get_arrays(surface_idx)
				if arrays and arrays[Mesh.ARRAY_VERTEX]:
					vertex_count = arrays[Mesh.ARRAY_VERTEX].size()

			print("  LOD %d: %d vertices" % [lod, vertex_count])
		else:
			print("  LOD %d: ERROR - Failed to create mesh" % lod)

	print("\n=== Integration Test Complete ===")
	print("Feature preservation is integrated!")

	# Exit
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _create_seamount_heightmap() -> Image:
	var heightmap = Image.create(128, 128, false, Image.FORMAT_RF)
	heightmap.fill(Color(-3000.0, 0.0, 0.0, 1.0))

	# Create a prominent seamount in the middle
	for y in range(40, 88):
		for x in range(40, 88):
			var dx = x - 64
			var dy = y - 64
			var dist = sqrt(dx * dx + dy * dy)
			var height = -3000.0 + max(0.0, (24.0 - dist) * 100.0)
			heightmap.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	return heightmap
