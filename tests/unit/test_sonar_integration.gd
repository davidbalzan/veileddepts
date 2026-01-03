extends GutTest
## Unit tests for sonar integration with terrain system

var collision_manager
var chunk_manager
var elevation_provider
var chunk_renderer


func before_each() -> void:
	# Create elevation provider
	elevation_provider = preload("res://scripts/rendering/elevation_data_provider.gd").new()
	add_child_autofree(elevation_provider)
	elevation_provider.initialize()

	# Create chunk manager
	chunk_manager = preload("res://scripts/rendering/chunk_manager.gd").new()
	chunk_manager.chunk_size = 512.0
	chunk_manager.max_cache_memory_mb = 128
	chunk_manager.max_cache_memory_mb = 128
	add_child_autofree(chunk_manager)

	# Create chunk renderer (required by ChunkManager)
	chunk_renderer = preload("res://scripts/rendering/chunk_renderer.gd").new()
	chunk_renderer.name = "ChunkRenderer"
	add_child_autofree(chunk_renderer)

	# Create collision manager
	collision_manager = preload("res://scripts/rendering/collision_manager.gd").new()
	add_child_autofree(collision_manager)
	collision_manager.set_chunk_manager(chunk_manager)

	# Wait for initialization
	await wait_frames(2)


func test_get_surface_normal_returns_valid_normal() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	var _chunk = chunk_manager.load_chunk(chunk_coord)
	await wait_frames(1)

	assert_not_null(_chunk, "Chunk should be loaded")
	assert_eq(
		_chunk.state,
		preload("res://scripts/rendering/chunk_state.gd").State.LOADED,
		"Chunk should be in LOADED state"
	)

	# Query surface normal at chunk center
	var world_pos := Vector3(0.0, 0.0, 0.0)
	var normal: Vector3 = collision_manager.get_surface_normal_for_sonar(world_pos)

	# Normal should be normalized
	assert_almost_eq(normal.length(), 1.0, 0.01, "Normal should be normalized")

	# Normal should generally point upward (y component positive)
	assert_gt(normal.y, 0.0, "Normal should point generally upward")


func test_get_surface_normal_for_unloaded_chunk_returns_default() -> void:
	# Query position in unloaded chunk
	var world_pos := Vector3(10000.0, 0.0, 10000.0)
	var normal: Vector3 = collision_manager.get_surface_normal_for_sonar(world_pos)

	# Should return default UP normal
	assert_eq(normal, Vector3.UP, "Should return default UP normal for unloaded chunk")


func test_get_terrain_geometry_for_sonar_returns_data() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	var _chunk = chunk_manager.load_chunk(chunk_coord)
	await wait_frames(1)

	assert_not_null(_chunk, "Chunk should be loaded")

	# Query terrain geometry within range
	var origin := Vector3(0.0, -50.0, 0.0)
	var max_range: float = 500.0
	var simplification_level: int = 1

	var result: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, max_range, simplification_level
	)

	# Should return positions and normals
	assert_true(result.has("positions"), "Result should have positions")
	assert_true(result.has("normals"), "Result should have normals")

	var positions: PackedVector3Array = result["positions"]
	var normals: PackedVector3Array = result["normals"]

	# Should have some data
	assert_gt(positions.size(), 0, "Should return some positions")
	assert_eq(positions.size(), normals.size(), "Positions and normals should have same count")

	# All normals should be normalized
	for i in range(normals.size()):
		var normal: Vector3 = normals[i]
		assert_almost_eq(normal.length(), 1.0, 0.01, "Normal %d should be normalized" % i)


func test_get_terrain_geometry_filters_by_range() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	var _chunk = chunk_manager.load_chunk(chunk_coord)
	await wait_frames(1)

	# Query with small range
	var origin := Vector3(0.0, -50.0, 0.0)
	var small_range: float = 50.0

	var result_small: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, small_range, 1
	)

	# Query with large range
	var large_range: float = 500.0
	var result_large: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, large_range, 1
	)

	var positions_small: PackedVector3Array = result_small["positions"]
	var positions_large: PackedVector3Array = result_large["positions"]

	# Larger range should return more points
	assert_gt(
		positions_large.size(), positions_small.size(), "Larger range should return more points"
	)

	# All points in small range result should be within range
	for pos in positions_small:
		var distance: float = origin.distance_to(pos)
		assert_lte(distance, small_range, "Point should be within small range")


func test_get_terrain_geometry_simplification_reduces_points() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	var _chunk = chunk_manager.load_chunk(chunk_coord)
	await wait_frames(1)

	var origin := Vector3(0.0, -50.0, 0.0)
	var max_range: float = 500.0

	# Query with low simplification (more detail)
	var result_detailed: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, max_range, 0  # No simplification
	)

	# Query with high simplification (less detail)
	var result_simplified: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, max_range, 2  # High simplification
	)

	var positions_detailed: PackedVector3Array = result_detailed["positions"]
	var positions_simplified: PackedVector3Array = result_simplified["positions"]

	# Simplified should have fewer points
	assert_gt(
		positions_detailed.size(),
		positions_simplified.size(),
		"Detailed geometry should have more points than simplified"
	)


func test_query_terrain_for_sonar_beam_filters_by_cone() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	var _chunk = chunk_manager.load_chunk(chunk_coord)
	await wait_frames(1)

	var origin := Vector3(0.0, -50.0, 0.0)
	var direction := Vector3(0.0, 1.0, 0.0)  # Pointing up
	var max_range: float = 500.0
	var beam_width: float = PI / 6.0  # 30 degrees

	var results: Array[Dictionary] = collision_manager.query_terrain_for_sonar_beam(
		origin, direction, max_range, beam_width
	)

	# Should return some results
	assert_gt(results.size(), 0, "Should return some terrain points in beam")

	# All results should have required fields
	for result in results:
		assert_true(result.has("position"), "Result should have position")
		assert_true(result.has("normal"), "Result should have normal")
		assert_true(result.has("distance"), "Result should have distance")

		# Distance should be within range
		var distance: float = result["distance"]
		assert_lte(distance, max_range, "Distance should be within max range")

		# Normal should be normalized
		var normal: Vector3 = result["normal"]
		assert_almost_eq(normal.length(), 1.0, 0.01, "Normal should be normalized")


func test_query_terrain_for_sonar_beam_narrow_vs_wide() -> void:
	# Load a chunk
	var chunk_coord := Vector2i(0, 0)
	var _chunk = chunk_manager.load_chunk(chunk_coord)
	await wait_frames(1)

	var origin := Vector3(0.0, -50.0, 0.0)
	var direction := Vector3(0.0, 1.0, 0.0)
	var max_range: float = 500.0

	# Narrow beam
	var narrow_beam: float = PI / 12.0  # 15 degrees
	var results_narrow: Array[Dictionary] = collision_manager.query_terrain_for_sonar_beam(
		origin, direction, max_range, narrow_beam
	)

	# Wide beam
	var wide_beam: float = PI / 3.0  # 60 degrees
	var results_wide: Array[Dictionary] = collision_manager.query_terrain_for_sonar_beam(
		origin, direction, max_range, wide_beam
	)

	# Wide beam should return more points
	assert_gt(
		results_wide.size(),
		results_narrow.size(),
		"Wide beam should return more points than narrow beam"
	)


func test_sonar_integration_with_no_chunks_loaded() -> void:
	# Query without loading any chunks
	var origin := Vector3(0.0, -50.0, 0.0)
	var max_range: float = 500.0

	var result: Dictionary = collision_manager.get_terrain_geometry_for_sonar(origin, max_range, 1)

	# Should return empty arrays
	var positions: PackedVector3Array = result["positions"]
	var normals: PackedVector3Array = result["normals"]

	assert_eq(positions.size(), 0, "Should return no positions when no chunks loaded")
	assert_eq(normals.size(), 0, "Should return no normals when no chunks loaded")


func test_sonar_beam_query_with_no_chunks_loaded() -> void:
	# Query without loading any chunks
	var origin := Vector3(0.0, -50.0, 0.0)
	var direction := Vector3(0.0, 1.0, 0.0)
	var max_range: float = 500.0

	var results: Array[Dictionary] = collision_manager.query_terrain_for_sonar_beam(
		origin, direction, max_range
	)

	# Should return empty array
	assert_eq(results.size(), 0, "Should return no results when no chunks loaded")
