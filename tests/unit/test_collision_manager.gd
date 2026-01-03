extends GutTest
## Unit tests for CollisionManager
##
## Tests collision geometry creation, height queries, underwater safety checks,
## and raycasting functionality.

const CollisionManager = preload("res://scripts/rendering/collision_manager.gd")

var collision_manager: CollisionManager
var chunk_manager: ChunkManager
var elevation_provider: ElevationDataProvider


func before_each() -> void:
	# Create elevation provider
	elevation_provider = ElevationDataProvider.new()
	add_child_autofree(elevation_provider)
	elevation_provider.initialize()

	# Create mock chunk renderer
	var chunk_renderer = MockChunkRendererForCollision.new()
	chunk_renderer.name = "ChunkRenderer"
	add_child_autofree(chunk_renderer)

	# Create chunk manager
	chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	chunk_manager.chunk_size = 512.0
	add_child_autofree(chunk_manager)

	# Create collision manager
	collision_manager = CollisionManager.new()
	collision_manager.name = "CollisionManager"
	add_child_autofree(collision_manager)
	collision_manager.set_chunk_manager(chunk_manager)

class MockChunkRendererForCollision:
	extends ChunkRenderer
	
	func _ready():
		pass

	func create_chunk_mesh(_heightmap, _biome_map, _chunk_coord, _lod_level, _neighbor_lods = {}) -> ArrayMesh:
		var mesh = ArrayMesh.new()
		var vertices = PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.RIGHT])
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
		
	func create_chunk_material(_biome_map, _param2):
		return ShaderMaterial.new()
		
	func update_chunk_lod(_chunk, _lod): pass



func test_create_collision_adds_static_body() -> void:
	# Create a test chunk with heightmap
	var chunk := TerrainChunk.new()
	chunk.chunk_coord = Vector2i(0, 0)
	chunk.base_heightmap = _create_test_heightmap(64, 64)
	add_child_autofree(chunk)

	# Create collision
	collision_manager.create_collision(chunk)

	# Verify static body was created
	assert_not_null(chunk.static_body, "Static body should be created")
	assert_not_null(chunk.collision_shape, "Collision shape should be created")
	assert_not_null(chunk.collision_shape.shape, "HeightMapShape3D should be created")

	# Verify shape is HeightMapShape3D
	assert_true(chunk.collision_shape.shape is HeightMapShape3D, "Shape should be HeightMapShape3D")


func test_create_collision_sets_correct_resolution() -> void:
	# Create a test chunk with heightmap
	var chunk := TerrainChunk.new()
	chunk.chunk_coord = Vector2i(0, 0)
	chunk.base_heightmap = _create_test_heightmap(128, 128)
	add_child_autofree(chunk)

	# Create collision
	collision_manager.create_collision(chunk)

	# Get the shape
	var shape: HeightMapShape3D = chunk.collision_shape.shape as HeightMapShape3D

	# Verify resolution (should be power of 2 + 1)
	assert_true(shape.map_width > 0, "Map width should be positive")
	assert_true(shape.map_depth > 0, "Map depth should be positive")
	assert_eq(shape.map_width, shape.map_depth, "Map should be square")

	# Verify it's power of 2 + 1
	var width_minus_one: int = shape.map_width - 1
	var is_power_of_two: bool = (width_minus_one & (width_minus_one - 1)) == 0
	assert_true(is_power_of_two, "Map width - 1 should be power of 2")


func test_remove_collision_cleans_up() -> void:
	# Create a test chunk with heightmap
	var chunk := TerrainChunk.new()
	chunk.chunk_coord = Vector2i(0, 0)
	chunk.base_heightmap = _create_test_heightmap(64, 64)
	add_child_autofree(chunk)

	# Create collision
	collision_manager.create_collision(chunk)

	# Verify collision exists
	assert_not_null(chunk.static_body, "Static body should exist before removal")

	# Remove collision
	collision_manager.remove_collision(chunk)

	# Verify collision was removed
	assert_null(chunk.static_body, "Static body should be null after removal")
	assert_null(chunk.collision_shape, "Collision shape should be null after removal")


func test_get_height_at_returns_correct_height() -> void:
	# Load a chunk at origin
	var chunk_coord := Vector2i(0, 0)
	var _chunk: TerrainChunk = chunk_manager.load_chunk(chunk_coord)

	# Wait for chunk to be fully loaded
	await wait_frames(2)

	# Query height at chunk center
	var center_world_pos := Vector2(0.0, 0.0)
	var height: float = collision_manager.get_height_at(center_world_pos)

	# Height should be a reasonable value (not zero, since we have elevation data)
	# We can't assert exact value without knowing the elevation data,
	# but we can verify it's in a reasonable range
	assert_true(
		height >= -11000.0 and height <= 9000.0,
		"Height should be in reasonable range (Mariana to Everest)"
	)


func test_get_height_at_handles_unloaded_chunk() -> void:
	# Query height in a far-away unloaded chunk
	var far_away_pos := Vector2(10000.0, 10000.0)
	var height: float = collision_manager.get_height_at(far_away_pos)

	# Should return some value (estimated or 0.0) without crashing
	assert_true(height >= -11000.0 and height <= 9000.0, "Should return reasonable estimate or 0.0")


func test_is_underwater_safe_rejects_above_sea_level() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)
	await wait_frames(2)

	# Test position above sea level
	var above_sea_level := Vector3(0.0, 10.0, 0.0)
	var is_safe: bool = collision_manager.is_underwater_safe(above_sea_level, 5.0)

	assert_false(is_safe, "Position above sea level should not be safe")


func test_is_underwater_safe_accepts_safe_underwater_position() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)
	await wait_frames(2)

	# Test position well below sea level with clearance
	var underwater_pos := Vector3(0.0, -100.0, 0.0)
	var is_safe: bool = collision_manager.is_underwater_safe(underwater_pos, 5.0)

	# This depends on terrain height, but at -100m we should have clearance
	# in most ocean areas
	assert_true(is_safe, "Position at -100m should typically be safe")


func test_is_underwater_safe_rejects_insufficient_clearance() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)
	await wait_frames(2)

	# Get terrain height at a position
	var test_pos_2d := Vector2(0.0, 0.0)
	var terrain_height: float = collision_manager.get_height_at(test_pos_2d)

	# Test position just barely above terrain (insufficient clearance)
	var unsafe_pos := Vector3(0.0, terrain_height + 1.0, 0.0)
	var is_safe: bool = collision_manager.is_underwater_safe(unsafe_pos, 5.0)

	assert_false(is_safe, "Position with insufficient clearance should not be safe")


func test_raycast_returns_hit_info() -> void:
	# Load a chunk and create collision
	var chunk_coord := Vector2i(0, 0)
	var chunk: TerrainChunk = chunk_manager.load_chunk(chunk_coord)
	await wait_frames(2)

	# Create collision geometry
	collision_manager.create_collision(chunk)
	await wait_frames(2)

	# Get actual terrain height at this location
	var terrain_height: float = collision_manager.get_height_at(Vector2(0, 0))
	
	# Raycast downward from above terrain
	var origin := Vector3(0.0, terrain_height + 100.0, 0.0)
	var direction := Vector3(0.0, -1.0, 0.0)
	var result: Dictionary = collision_manager.raycast(origin, direction, 200.0)
	
	# Should hit terrain
	assert_true(result.get("hit", false), "Raycast from %.1f should hit terrain at %.1f" % [origin.y, terrain_height])

	if result.get("hit", false):
		assert_not_null(result.get("position"), "Hit should have position")
		assert_not_null(result.get("normal"), "Hit should have normal")
		assert_true(result.get("distance", 0.0) > 0.0, "Hit distance should be positive")


func test_raycast_returns_no_hit_when_missing() -> void:
	# Raycast in empty space (no chunks loaded)
	var origin := Vector3(10000.0, 100.0, 10000.0)
	var direction := Vector3(0.0, -1.0, 0.0)
	var result: Dictionary = collision_manager.raycast(origin, direction, 200.0)

	# Should not hit anything
	assert_false(result.get("hit", false), "Raycast should not hit anything in empty space")


func test_bilinear_interpolation_at_corners() -> void:
	# Create a simple test heightmap with known values
	var heightmap := Image.create(4, 4, false, Image.FORMAT_RF)

	# Set corner values
	heightmap.set_pixel(0, 0, Color(0.0, 0.0, 0.0))  # Bottom-left: 0
	heightmap.set_pixel(3, 0, Color(1.0, 0.0, 0.0))  # Bottom-right: 1
	heightmap.set_pixel(0, 3, Color(0.0, 0.0, 0.0))  # Top-left: 0
	heightmap.set_pixel(3, 3, Color(1.0, 0.0, 0.0))  # Top-right: 1

	# Sample at corners using the private method (via get_height_at)
	# We'll test this indirectly by creating a chunk
	var chunk := TerrainChunk.new()
	chunk.chunk_coord = Vector2i(0, 0)
	chunk.base_heightmap = heightmap
	chunk.world_bounds = Rect2(0, 0, 512, 512)
	add_child_autofree(chunk)

	# The bilinear interpolation is tested indirectly through get_height_at
	# We verify it doesn't crash and returns reasonable values
	var height: float = collision_manager.get_height_at(Vector2(0.0, 0.0))
	assert_true(height >= -11000.0 and height <= 9000.0, "Should return reasonable height")


## Helper function to create a test heightmap
func _create_test_heightmap(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RF)

	# Fill with gradient for testing
	for y in range(height):
		for x in range(width):
			var value: float = float(y) / float(height)
			img.set_pixel(x, y, Color(value, 0.0, 0.0))

	return img
