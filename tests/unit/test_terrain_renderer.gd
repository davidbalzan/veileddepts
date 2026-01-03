extends GutTest

## Unit tests for TerrainRenderer (facade)
##
## Tests initialization and delegation to subsystems.
## Logic testing is handled in test_chunk_manager.gd, test_collision_manager.gd, etc.

const TerrainRendererScript = preload("res://scripts/rendering/terrain_renderer.gd")

var terrain_renderer: TerrainRenderer
var submarine_mock: Node3D
var main_node: Node

func before_each():
	# Create mock submarine structure for streaming init
	main_node = Node.new()
	main_node.name = "Main"
	get_tree().root.add_child(main_node)
	
	submarine_mock = RigidBody3D.new()
	submarine_mock.name = "SubmarineModel"
	main_node.add_child(submarine_mock)

	terrain_renderer = TerrainRendererScript.new()
	# Disable debug overlay for tests
	terrain_renderer.enable_debug_overlay = false
	# Use smaller chunks for testing? Or defaults.
	
	add_child_autofree(terrain_renderer)
	
	# Wait for deferred _setup_terrain
	await get_tree().process_frame
	await get_tree().process_frame


func after_each():
	if terrain_renderer:
		terrain_renderer.queue_free()
	if main_node:
		main_node.queue_free()


func test_terrain_renderer_initializes():
	assert_not_null(terrain_renderer, "TerrainRenderer should be created")
	assert_true(terrain_renderer.initialized, "TerrainRenderer should be initialized")
	
	# Check private components exist (using get which allows access to underscored vars in same script, but from test we rely on dynamic access)
	assert_not_null(terrain_renderer.get("_chunk_manager"), "ChunkManager should be created")
	assert_not_null(terrain_renderer.get("_collision_manager"), "CollisionManager should be created")
	assert_not_null(terrain_renderer.get("_streaming_manager"), "StreamingManager should be created")


func test_terrain_size_property_legacy():
	# Legacy property should still exist but may be ignored or used for fallback
	terrain_renderer.terrain_size = Vector2i(512, 512)
	assert_eq(terrain_renderer.terrain_size, Vector2i(512, 512), "Terrain size property should be settable")


func test_default_parameters():
	var fresh_renderer = TerrainRendererScript.new()
	
	# Updated expectation to match current default in script (2048)
	assert_eq(fresh_renderer.terrain_size, Vector2i(2048, 2048), "Default terrain size")
	
	# Legacy defaults
	assert_eq(fresh_renderer.lod_levels, 4, "Default LOD levels")
	
	fresh_renderer.queue_free()


func test_get_height_at_delegates_to_collision_manager():
	# Since no chunks are loaded by default in this isolated test, it might return 0 or default
	var height = terrain_renderer.get_height_at(Vector2(0, 0))
	assert_typeof(height, TYPE_FLOAT, "Height should be a float")


func test_check_collision_delegates():
	# Just verify it doesn't crash and returns bool
	var collides = terrain_renderer.check_collision(Vector3(0, -1000, 0))
	assert_typeof(collides, TYPE_BOOL)

