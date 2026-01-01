## Unit tests for chunk coordinate conversion
##
## Tests the ChunkCoordinates utility class for converting between
## world positions and chunk grid coordinates.
## Requirements: 7.1, 7.2, 7.3, 7.4

extends GutTest

const ChunkCoordinates = preload("res://scripts/rendering/chunk_coordinates.gd")


func test_world_to_chunk_positive_coordinates():
	# Test conversion of positive world coordinates to chunk coordinates
	var coords = ChunkCoordinates.new(512.0)
	
	# Test origin
	assert_eq(coords.world_to_chunk(Vector3(0, 0, 0)), Vector2i(0, 0), "Origin should be chunk (0,0)")
	
	# Test positive coordinates
	assert_eq(coords.world_to_chunk(Vector3(256, 0, 256)), Vector2i(0, 0), "Center of chunk (0,0)")
	assert_eq(coords.world_to_chunk(Vector3(512, 0, 512)), Vector2i(1, 1), "Start of chunk (1,1)")
	assert_eq(coords.world_to_chunk(Vector3(1024, 0, 1024)), Vector2i(2, 2), "Start of chunk (2,2)")


func test_world_to_chunk_negative_coordinates():
	# Test conversion of negative world coordinates to chunk coordinates
	var coords = ChunkCoordinates.new(512.0)
	
	# Test negative coordinates
	assert_eq(coords.world_to_chunk(Vector3(-1, 0, -1)), Vector2i(-1, -1), "Negative position should map to negative chunk")
	assert_eq(coords.world_to_chunk(Vector3(-256, 0, -256)), Vector2i(-1, -1), "Center of chunk (-1,-1)")
	assert_eq(coords.world_to_chunk(Vector3(-512, 0, -512)), Vector2i(-1, -1), "Edge of chunk (-1,-1)")
	assert_eq(coords.world_to_chunk(Vector3(-513, 0, -513)), Vector2i(-2, -2), "Start of chunk (-2,-2)")


func test_world_to_chunk_boundaries():
	# Test conversion at exact chunk boundaries
	var coords = ChunkCoordinates.new(512.0)
	
	# Test boundaries (floor behavior)
	assert_eq(coords.world_to_chunk(Vector3(511.9, 0, 511.9)), Vector2i(0, 0), "Just before boundary")
	assert_eq(coords.world_to_chunk(Vector3(512.0, 0, 512.0)), Vector2i(1, 1), "Exactly at boundary")
	assert_eq(coords.world_to_chunk(Vector3(512.1, 0, 512.1)), Vector2i(1, 1), "Just after boundary")


func test_chunk_to_world_center():
	# Test conversion of chunk coordinates to world center position
	var coords = ChunkCoordinates.new(512.0)
	
	# Test chunk centers
	assert_eq(coords.chunk_to_world(Vector2i(0, 0)), Vector3(256, 0, 256), "Center of chunk (0,0)")
	assert_eq(coords.chunk_to_world(Vector2i(1, 1)), Vector3(768, 0, 768), "Center of chunk (1,1)")
	assert_eq(coords.chunk_to_world(Vector2i(-1, -1)), Vector3(-256, 0, -256), "Center of chunk (-1,-1)")


func test_coordinate_round_trip():
	# Test that converting world -> chunk -> world stays in same chunk
	# Requirements: 7.2, 7.3
	var coords = ChunkCoordinates.new(512.0)
	
	var test_positions = [
		Vector3(100, 0, 200),
		Vector3(500, 0, 300),
		Vector3(-100, 0, -200),
		Vector3(1000, 0, 2000),
		Vector3(-1500, 0, -2500)
	]
	
	for pos in test_positions:
		var chunk_coord = coords.world_to_chunk(pos)
		var world_center = coords.chunk_to_world(chunk_coord)
		var chunk_coord_again = coords.world_to_chunk(world_center)
		
		assert_eq(chunk_coord, chunk_coord_again, 
			"Round trip should return to same chunk for position " + str(pos))


func test_get_chunk_bounds():
	# Test getting world bounds for a chunk
	var coords = ChunkCoordinates.new(512.0)
	
	var bounds = coords.get_chunk_bounds(Vector2i(0, 0))
	assert_eq(bounds.position, Vector2(0, 0), "Chunk (0,0) should start at origin")
	assert_eq(bounds.size, Vector2(512, 512), "Chunk size should be 512x512")
	
	bounds = coords.get_chunk_bounds(Vector2i(1, 1))
	assert_eq(bounds.position, Vector2(512, 512), "Chunk (1,1) should start at (512,512)")
	
	bounds = coords.get_chunk_bounds(Vector2i(-1, -1))
	assert_eq(bounds.position, Vector2(-512, -512), "Chunk (-1,-1) should start at (-512,-512)")


func test_get_chunk_corner():
	# Test getting corner position of a chunk
	var coords = ChunkCoordinates.new(512.0)
	
	assert_eq(coords.get_chunk_corner(Vector2i(0, 0)), Vector3(0, 0, 0), "Corner of chunk (0,0)")
	assert_eq(coords.get_chunk_corner(Vector2i(1, 1)), Vector3(512, 0, 512), "Corner of chunk (1,1)")
	assert_eq(coords.get_chunk_corner(Vector2i(-1, -1)), Vector3(-512, 0, -512), "Corner of chunk (-1,-1)")


func test_is_position_in_chunk():
	# Test checking if a position is within a chunk
	var coords = ChunkCoordinates.new(512.0)
	
	# Test positions in chunk (0,0)
	assert_true(coords.is_position_in_chunk(Vector3(0, 0, 0), Vector2i(0, 0)), "Origin in chunk (0,0)")
	assert_true(coords.is_position_in_chunk(Vector3(256, 0, 256), Vector2i(0, 0)), "Center in chunk (0,0)")
	assert_true(coords.is_position_in_chunk(Vector3(511, 0, 511), Vector2i(0, 0)), "Near edge in chunk (0,0)")
	
	# Test positions outside chunk (0,0)
	assert_false(coords.is_position_in_chunk(Vector3(512, 0, 512), Vector2i(0, 0)), "Outside chunk (0,0)")
	assert_false(coords.is_position_in_chunk(Vector3(-1, 0, -1), Vector2i(0, 0)), "Negative outside chunk (0,0)")


func test_get_distance_to_chunk():
	# Test calculating distance to a chunk
	var coords = ChunkCoordinates.new(512.0)
	
	# Position inside chunk should have distance 0
	var dist = coords.get_distance_to_chunk(Vector3(256, 0, 256), Vector2i(0, 0))
	assert_almost_eq(dist, 0.0, 0.01, "Distance to chunk containing position should be 0")
	
	# Position outside chunk
	dist = coords.get_distance_to_chunk(Vector3(1024, 0, 1024), Vector2i(0, 0))
	assert_gt(dist, 0.0, "Distance to chunk not containing position should be > 0")


func test_get_chunks_in_radius():
	# Test getting all chunks within a radius
	var coords = ChunkCoordinates.new(512.0)
	
	# Small radius should return just the center chunk
	var chunks = coords.get_chunks_in_radius(Vector3(256, 0, 256), 100.0)
	assert_true(chunks.has(Vector2i(0, 0)), "Should include center chunk")
	
	# Larger radius should return multiple chunks
	chunks = coords.get_chunks_in_radius(Vector3(256, 0, 256), 600.0)
	assert_gt(chunks.size(), 1, "Larger radius should return multiple chunks")
	assert_true(chunks.has(Vector2i(0, 0)), "Should include center chunk")


func test_different_chunk_sizes():
	# Test that coordinate system works with different chunk sizes
	var coords_256 = ChunkCoordinates.new(256.0)
	var coords_1024 = ChunkCoordinates.new(1024.0)
	
	# Same position, different chunk sizes
	var pos = Vector3(500, 0, 500)
	
	var chunk_256 = coords_256.world_to_chunk(pos)
	var chunk_1024 = coords_1024.world_to_chunk(pos)
	
	assert_eq(chunk_256, Vector2i(1, 1), "256m chunks: position should be in chunk (1,1)")
	assert_eq(chunk_1024, Vector2i(0, 0), "1024m chunks: position should be in chunk (0,0)")
