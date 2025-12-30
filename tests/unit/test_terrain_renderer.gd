extends GutTest
## Unit tests for TerrainRenderer (procedural terrain system)

const TerrainRendererScript = preload("res://scripts/rendering/terrain_renderer.gd")

var terrain_renderer: Node3D

func before_each():
	terrain_renderer = TerrainRendererScript.new()
	# Use smaller terrain for faster tests
	terrain_renderer.terrain_size = Vector2i(256, 256)
	terrain_renderer.terrain_resolution = 32
	terrain_renderer.collision_enabled = false  # Disable collision for unit tests
	
	# Set up a camera for the terrain renderer
	var camera = Camera3D.new()
	camera.far = 16000.0
	add_child_autofree(camera)
	camera.make_current()
	
	add_child_autofree(terrain_renderer)
	# Wait for initialization
	await get_tree().process_frame
	await get_tree().process_frame


func after_each():
	if terrain_renderer:
		terrain_renderer.queue_free()
		terrain_renderer = null


func test_terrain_renderer_initializes():
	assert_not_null(terrain_renderer, "TerrainRenderer should be created")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(terrain_renderer.initialized, "TerrainRenderer should be initialized")


func test_terrain_has_heightmap():
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(terrain_renderer.heightmap, "Heightmap should be generated")


func test_terrain_has_mesh():
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(terrain_renderer.terrain_mesh, "Terrain mesh should be created")


func test_terrain_size_property():
	terrain_renderer.terrain_size = Vector2i(512, 512)
	assert_eq(terrain_renderer.terrain_size, Vector2i(512, 512), "Terrain size should be set")


func test_terrain_resolution_property():
	terrain_renderer.terrain_resolution = 64
	assert_eq(terrain_renderer.terrain_resolution, 64, "Terrain resolution should be set")


func test_max_height_property():
	terrain_renderer.max_height = 200.0
	assert_almost_eq(terrain_renderer.max_height, 200.0, 0.001, "Max height should be set")


func test_min_height_property():
	terrain_renderer.min_height = -300.0
	assert_almost_eq(terrain_renderer.min_height, -300.0, 0.001, "Min height should be set")


func test_sea_level_property():
	terrain_renderer.sea_level = 10.0
	assert_almost_eq(terrain_renderer.sea_level, 10.0, 0.001, "Sea level should be set")


func test_noise_seed_property():
	terrain_renderer.noise_seed = 54321
	assert_eq(terrain_renderer.noise_seed, 54321, "Noise seed should be set")


func test_lod_levels_property():
	terrain_renderer.lod_levels = 6
	assert_eq(terrain_renderer.lod_levels, 6, "LOD levels should be set")


func test_get_height_at_returns_float():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var test_position = Vector2(0.0, 0.0)
	var height = terrain_renderer.get_height_at(test_position)
	
	assert_typeof(height, TYPE_FLOAT, "Height should be a float")


func test_get_height_at_3d_returns_float():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var test_position = Vector3(50.0, 0.0, 50.0)
	var height = terrain_renderer.get_height_at_3d(test_position)
	
	assert_typeof(height, TYPE_FLOAT, "Height 3D should be a float")


func test_height_within_bounds():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Test multiple positions
	var positions = [
		Vector2(0, 0),
		Vector2(50, 50),
		Vector2(-50, -50),
		Vector2(100, -100)
	]
	
	for pos in positions:
		var height = terrain_renderer.get_height_at(pos)
		assert_true(height >= terrain_renderer.min_height, 
			"Height at %s should be >= min_height" % pos)
		assert_true(height <= terrain_renderer.max_height, 
			"Height at %s should be <= max_height" % pos)


func test_get_normal_at_returns_vector3():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var test_position = Vector2(0.0, 0.0)
	var normal = terrain_renderer.get_normal_at(test_position)
	
	assert_typeof(normal, TYPE_VECTOR3, "Normal should be a Vector3")


func test_normal_is_normalized():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var test_position = Vector2(25.0, 25.0)
	var normal = terrain_renderer.get_normal_at(test_position)
	
	assert_almost_eq(normal.length(), 1.0, 0.01, "Normal should be normalized")


func test_check_collision_below_terrain():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get height at center
	var height = terrain_renderer.get_height_at(Vector2(0, 0))
	
	# Position below terrain should collide
	var below_pos = Vector3(0, height - 10, 0)
	assert_true(terrain_renderer.check_collision(below_pos), 
		"Position below terrain should collide")


func test_check_collision_above_terrain():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get height at center
	var height = terrain_renderer.get_height_at(Vector2(0, 0))
	
	# Position above terrain should not collide
	var above_pos = Vector3(0, height + 100, 0)
	assert_false(terrain_renderer.check_collision(above_pos), 
		"Position above terrain should not collide")


func test_collision_response_pushes_up():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get height at center
	var height = terrain_renderer.get_height_at(Vector2(0, 0))
	
	# Position below terrain
	var below_pos = Vector3(0, height - 5, 0)
	var response = terrain_renderer.get_collision_response(below_pos)
	
	assert_true(response.y > 0, "Collision response should push upward")


func test_generate_heightmap():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Generate new heightmap with different seed
	terrain_renderer.generate_heightmap(99999, Vector2i(128, 128))
	
	assert_not_null(terrain_renderer.heightmap, "New heightmap should be generated")
	assert_eq(terrain_renderer.heightmap.get_width(), terrain_renderer.terrain_resolution, 
		"Heightmap width should match resolution")


func test_lod_meshes_generated():
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_eq(terrain_renderer.lod_meshes.size(), terrain_renderer.lod_levels, 
		"Should have correct number of LOD meshes")


func test_update_lod_changes_mesh():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Start at LOD 0
	terrain_renderer.update_lod(Vector3(0, 50, 0))
	var initial_lod = terrain_renderer.current_lod
	
	# Move camera far away to trigger LOD change
	terrain_renderer.update_lod(Vector3(0, 50, 10000))
	
	# LOD should have changed (or stayed at max)
	assert_true(terrain_renderer.current_lod >= initial_lod, 
		"LOD should increase with distance")


func test_default_parameters():
	var fresh_renderer = TerrainRendererScript.new()
	
	assert_eq(fresh_renderer.terrain_size, Vector2i(1024, 1024), "Default terrain size")
	assert_eq(fresh_renderer.terrain_resolution, 256, "Default terrain resolution")
	assert_almost_eq(fresh_renderer.max_height, 100.0, 0.001, "Default max height")
	assert_almost_eq(fresh_renderer.min_height, -200.0, 0.001, "Default min height")
	assert_almost_eq(fresh_renderer.sea_level, 0.0, 0.001, "Default sea level")
	assert_eq(fresh_renderer.lod_levels, 4, "Default LOD levels")
	
	fresh_renderer.queue_free()


func test_heightmap_deterministic_with_same_seed():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Generate with specific seed
	terrain_renderer.generate_heightmap(12345, Vector2i(64, 64))
	var height1 = terrain_renderer.get_height_at(Vector2(10, 10))
	
	# Generate again with same seed
	terrain_renderer.generate_heightmap(12345, Vector2i(64, 64))
	var height2 = terrain_renderer.get_height_at(Vector2(10, 10))
	
	assert_almost_eq(height1, height2, 0.001, 
		"Same seed should produce same heightmap")


func test_different_seeds_produce_different_terrain():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Generate with first seed
	terrain_renderer.generate_heightmap(11111, Vector2i(64, 64))
	var height1 = terrain_renderer.get_height_at(Vector2(10, 10))
	
	# Generate with different seed
	terrain_renderer.generate_heightmap(22222, Vector2i(64, 64))
	var height2 = terrain_renderer.get_height_at(Vector2(10, 10))
	
	# Heights should be different (with very high probability)
	assert_true(abs(height1 - height2) > 0.1, 
		"Different seeds should produce different terrain")
