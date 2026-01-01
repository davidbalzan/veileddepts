## Unit tests for terrain chunk core data structures
##
## Tests basic functionality of TerrainChunk, ChunkState, BiomeType,
## and BiomeTextureParams classes.

extends GutTest

const ChunkState = preload("res://scripts/rendering/chunk_state.gd")
const BiomeType = preload("res://scripts/rendering/biome_type.gd")
const BiomeTextureParams = preload("res://scripts/rendering/biome_texture_params.gd")
const TerrainChunk = preload("res://scripts/rendering/terrain_chunk.gd")


func test_chunk_state_enum_values():
	# Test that ChunkState enum has expected values
	assert_eq(ChunkState.State.UNLOADED, 0, "UNLOADED should be 0")
	assert_eq(ChunkState.State.LOADING, 1, "LOADING should be 1")
	assert_eq(ChunkState.State.LOADED, 2, "LOADED should be 2")
	assert_eq(ChunkState.State.UNLOADING, 3, "UNLOADING should be 3")


func test_biome_type_enum_values():
	# Test that BiomeType enum has expected values
	assert_eq(BiomeType.Type.DEEP_WATER, 0, "DEEP_WATER should be 0")
	assert_eq(BiomeType.Type.SHALLOW_WATER, 1, "SHALLOW_WATER should be 1")
	assert_eq(BiomeType.Type.BEACH, 2, "BEACH should be 2")
	assert_eq(BiomeType.Type.CLIFF, 3, "CLIFF should be 3")
	assert_eq(BiomeType.Type.GRASS, 4, "GRASS should be 4")
	assert_eq(BiomeType.Type.ROCK, 5, "ROCK should be 5")
	assert_eq(BiomeType.Type.SNOW, 6, "SNOW should be 6")


func test_biome_texture_params_creation():
	# Test BiomeTextureParams can be created with default values
	var params = BiomeTextureParams.new()
	assert_not_null(params, "BiomeTextureParams should be created")
	assert_eq(params.albedo_color, Color.WHITE, "Default albedo should be white")
	assert_eq(params.roughness, 0.5, "Default roughness should be 0.5")
	assert_eq(params.metallic, 0.0, "Default metallic should be 0.0")
	assert_eq(params.normal_strength, 1.0, "Default normal strength should be 1.0")


func test_biome_texture_params_custom_values():
	# Test BiomeTextureParams can be set with custom values
	var params = BiomeTextureParams.new()
	params.albedo_color = Color.RED
	params.roughness = 0.8
	params.metallic = 0.2
	params.normal_strength = 1.5
	
	assert_eq(params.albedo_color, Color.RED, "Albedo should be red")
	assert_eq(params.roughness, 0.8, "Roughness should be 0.8")
	assert_eq(params.metallic, 0.2, "Metallic should be 0.2")
	assert_eq(params.normal_strength, 1.5, "Normal strength should be 1.5")


func test_terrain_chunk_creation():
	# Test TerrainChunk can be created
	var chunk = TerrainChunk.new()
	assert_not_null(chunk, "TerrainChunk should be created")
	assert_eq(chunk.chunk_coord, Vector2i.ZERO, "Default chunk coord should be zero")
	assert_eq(chunk.state, 0, "Default state should be UNLOADED (0)")
	assert_eq(chunk.current_lod, 0, "Default LOD should be 0")
	assert_eq(chunk.memory_size_bytes, 0, "Default memory size should be 0")
	chunk.free()


func test_terrain_chunk_touch():
	# Test that touch() updates last_access_time
	var chunk = TerrainChunk.new()
	var initial_time = chunk.last_access_time
	
	# Wait a tiny bit
	await get_tree().create_timer(0.01).timeout
	
	chunk.touch()
	var new_time = chunk.last_access_time
	
	assert_gt(new_time, initial_time, "Touch should update access time")
	chunk.free()


func test_terrain_chunk_cleanup():
	# Test that cleanup() properly clears resources
	var chunk = TerrainChunk.new()
	
	# Set some data
	chunk.chunk_coord = Vector2i(1, 2)
	chunk.state = ChunkState.State.LOADED
	chunk.memory_size_bytes = 1000
	
	# Cleanup
	chunk.cleanup()
	
	# Verify cleanup
	assert_null(chunk.base_heightmap, "Base heightmap should be null")
	assert_null(chunk.detail_heightmap, "Detail heightmap should be null")
	assert_null(chunk.biome_map, "Biome map should be null")
	assert_null(chunk.bump_map, "Bump map should be null")
	assert_eq(chunk.lod_meshes.size(), 0, "LOD meshes should be empty")
	assert_eq(chunk.memory_size_bytes, 0, "Memory size should be 0")
	assert_eq(chunk.state, 0, "State should be UNLOADED (0)")
	
	chunk.free()
