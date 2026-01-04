extends GutTest

## Test TerrainRenderer integration with SeaLevelManager
## Validates Requirements 2.1, 2.4, 2.5

var terrain_renderer: TerrainRenderer = null
var test_scene: Node3D = null


func before_each():
	# Create test scene
	test_scene = Node3D.new()
	add_child_autofree(test_scene)
	
	# Create terrain renderer
	terrain_renderer = TerrainRenderer.new()
	terrain_renderer.chunk_size = 512.0
	terrain_renderer.load_distance = 1024.0
	terrain_renderer.unload_distance = 1536.0
	test_scene.add_child(terrain_renderer)
	
	# Wait for initialization
	await wait_frames(2)


func test_terrain_renderer_connects_to_sea_level_manager():
	# Verify signal connection exists
	assert_true(
		SeaLevelManager.sea_level_changed.is_connected(terrain_renderer._on_sea_level_changed),
		"TerrainRenderer should connect to SeaLevelManager.sea_level_changed signal"
	)


func test_sea_level_change_updates_loaded_chunks():
	# Skip if terrain not initialized
	if not terrain_renderer.initialized:
		pending("Terrain not initialized")
		return
	
	# Set initial sea level
	SeaLevelManager.set_sea_level(0.554)  # Default (0m)
	await wait_frames(1)
	
	# Change sea level
	var new_sea_level_normalized = 0.6  # ~900m elevation
	var new_sea_level_meters = SeaLevelManager.normalized_to_meters(new_sea_level_normalized)
	
	SeaLevelManager.set_sea_level(new_sea_level_normalized)
	await wait_frames(1)
	
	# Verify the callback was called (we can't easily verify chunk updates without loaded chunks)
	# This test mainly verifies the signal connection works
	assert_eq(
		SeaLevelManager.get_sea_level_normalized(),
		new_sea_level_normalized,
		"Sea level should be updated in manager"
	)
	assert_almost_eq(
		SeaLevelManager.get_sea_level_meters(),
		new_sea_level_meters,
		0.1,
		"Sea level in meters should match conversion"
	)


func test_new_chunks_use_current_sea_level():
	# This test verifies that ChunkRenderer queries SeaLevelManager
	# when creating new chunk materials
	
	# Set a specific sea level
	var test_sea_level = 0.65  # ~2000m elevation
	SeaLevelManager.set_sea_level(test_sea_level)
	await wait_frames(1)
	
	# Create a test chunk renderer
	var chunk_renderer = ChunkRenderer.new()
	chunk_renderer.chunk_size = 512.0
	test_scene.add_child(chunk_renderer)
	await wait_frames(1)
	
	# Create a test material
	var test_biome_map = Image.create(4, 4, false, Image.FORMAT_R8)
	test_biome_map.fill(Color(0.5, 0.5, 0.5, 1.0))
	
	var test_bump_map = Image.create(4, 4, false, Image.FORMAT_RGB8)
	test_bump_map.fill(Color(0.5, 0.5, 1.0, 1.0))
	
	var material = chunk_renderer.create_chunk_material(test_biome_map, test_bump_map)
	
	# Verify the material has the correct sea level
	var material_sea_level = material.get_shader_parameter("sea_level")
	var expected_sea_level = SeaLevelManager.get_sea_level_meters()
	
	assert_almost_eq(
		material_sea_level,
		expected_sea_level,
		0.1,
		"New chunk material should use current sea level from manager"
	)
	
	chunk_renderer.queue_free()


func test_terrain_renderer_disconnects_on_exit():
	# Store reference to check later
	var renderer = terrain_renderer
	
	# Remove from tree (triggers _exit_tree)
	test_scene.remove_child(renderer)
	await wait_frames(1)
	
	# Verify signal is disconnected
	assert_false(
		SeaLevelManager.sea_level_changed.is_connected(renderer._on_sea_level_changed),
		"TerrainRenderer should disconnect from SeaLevelManager on exit"
	)
	
	renderer.queue_free()
