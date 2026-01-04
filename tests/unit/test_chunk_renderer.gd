extends GutTest

## Unit tests for ChunkRenderer
##
## Tests mesh generation, LOD management, edge stitching, and material creation

const ChunkRenderer = preload("res://scripts/rendering/chunk_renderer.gd")

var chunk_renderer: ChunkRenderer
var test_heightmap: Image
var test_biome_map: Image
var test_bump_map: Image


func before_each():
	chunk_renderer = ChunkRenderer.new()
	add_child_autofree(chunk_renderer)

	# Create test heightmap (16x16)
	test_heightmap = Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			var height = sin(x * 0.5) * cos(y * 0.5) * 0.5 + 0.5
			test_heightmap.set_pixel(x, y, Color(height, 0, 0, 1))

	# Create test biome map (16x16)
	test_biome_map = Image.create(16, 16, false, Image.FORMAT_R8)
	test_biome_map.fill(Color(0.0, 0.0, 0.0, 1.0))  # All deep water

	# Create test bump map (16x16)
	test_bump_map = Image.create(16, 16, false, Image.FORMAT_RGB8)
	test_bump_map.fill(Color(0.5, 0.5, 1.0, 1.0))  # Flat normals


func test_chunk_renderer_initialization():
	assert_not_null(chunk_renderer, "ChunkRenderer should be created")
	assert_eq(chunk_renderer.lod_levels, 4, "Should have 4 LOD levels by default")
	assert_eq(chunk_renderer.chunk_size, 512.0, "Chunk size should be 512m by default")


func test_create_chunk_mesh_basic():
	var mesh = chunk_renderer.create_chunk_mesh(test_heightmap, test_biome_map, Vector2i(0, 0), 0)  # LOD 0 (highest detail)

	assert_not_null(mesh, "Should create a mesh")
	assert_gt(mesh.get_surface_count(), 0, "Mesh should have at least one surface")


func test_create_chunk_mesh_different_lods():
	# Test that different LOD levels create meshes with different vertex counts
	var mesh_lod0 = chunk_renderer.create_chunk_mesh(
		test_heightmap, test_biome_map, Vector2i(0, 0), 0
	)
	var mesh_lod1 = chunk_renderer.create_chunk_mesh(
		test_heightmap, test_biome_map, Vector2i(0, 0), 1
	)
	var mesh_lod2 = chunk_renderer.create_chunk_mesh(
		test_heightmap, test_biome_map, Vector2i(0, 0), 2
	)

	assert_not_null(mesh_lod0, "LOD 0 mesh should be created")
	assert_not_null(mesh_lod1, "LOD 1 mesh should be created")
	assert_not_null(mesh_lod2, "LOD 2 mesh should be created")

	# Higher LOD should have fewer vertices (though we can't easily check this)
	# Just verify they're all valid meshes
	assert_gt(mesh_lod0.get_surface_count(), 0, "LOD 0 should have surfaces")
	assert_gt(mesh_lod1.get_surface_count(), 0, "LOD 1 should have surfaces")
	assert_gt(mesh_lod2.get_surface_count(), 0, "LOD 2 should have surfaces")


func test_create_chunk_mesh_with_null_heightmap():
	var mesh = chunk_renderer.create_chunk_mesh(null, test_biome_map, Vector2i(0, 0), 0)

	assert_null(mesh, "Should return null for null heightmap")


func test_update_chunk_lod():
	# Create a test chunk
	var chunk = TerrainChunk.new()
	chunk.chunk_coord = Vector2i(0, 0)
	chunk.base_heightmap = test_heightmap

	# Generate LOD meshes
	for lod in range(4):
		var mesh = chunk_renderer.create_chunk_mesh(
			test_heightmap, test_biome_map, Vector2i(0, 0), lod
		)
		chunk.lod_meshes.append(mesh)

	chunk.current_lod = 0
	chunk.mesh_instance = MeshInstance3D.new()
	chunk.mesh_instance.mesh = chunk.lod_meshes[0]

	# Test LOD update at close distance
	chunk_renderer.update_chunk_lod(chunk, 50.0)
	assert_eq(chunk.current_lod, 0, "Should use LOD 0 at close distance")

	# Test LOD update at medium distance
	chunk_renderer.update_chunk_lod(chunk, 150.0)
	assert_gt(chunk.current_lod, 0, "Should use higher LOD at medium distance")

	# Test LOD update at far distance
	chunk_renderer.update_chunk_lod(chunk, 500.0)
	assert_gt(chunk.current_lod, 1, "Should use even higher LOD at far distance")

	chunk.queue_free()


func test_create_chunk_material():
	var material = chunk_renderer.create_chunk_material(test_biome_map, test_bump_map)

	assert_not_null(material, "Should create a material")
	assert_true(material is ShaderMaterial, "Should be a ShaderMaterial")
	assert_not_null(material.shader, "Material should have a shader")

	# Check shader parameters are set
	var biome_map_param = material.get_shader_parameter("biome_map")
	var bump_map_param = material.get_shader_parameter("bump_map")
	var chunk_size_param = material.get_shader_parameter("chunk_size")

	assert_not_null(biome_map_param, "Should have biome_map parameter")
	assert_not_null(bump_map_param, "Should have bump_map parameter")
	assert_eq(chunk_size_param, 512.0, "Should have correct chunk_size parameter")


func test_create_chunk_material_with_null_maps():
	# Should create default textures when maps are null
	var material = chunk_renderer.create_chunk_material(null, null)

	assert_not_null(material, "Should create a material even with null maps")
	assert_true(material is ShaderMaterial, "Should be a ShaderMaterial")

	# Should have default textures
	var biome_map_param = material.get_shader_parameter("biome_map")
	var bump_map_param = material.get_shader_parameter("bump_map")

	assert_not_null(biome_map_param, "Should have default biome_map")
	assert_not_null(bump_map_param, "Should have default bump_map")


func test_stitch_chunk_edges():
	# Create a test chunk
	var chunk = TerrainChunk.new()
	chunk.chunk_coord = Vector2i(0, 0)
	chunk.base_heightmap = test_heightmap
	chunk.biome_map = test_biome_map

	# Generate LOD meshes
	for lod in range(4):
		var mesh = chunk_renderer.create_chunk_mesh(
			test_heightmap, test_biome_map, Vector2i(0, 0), lod
		)
		chunk.lod_meshes.append(mesh)

	chunk.current_lod = 0

	# Create neighbor chunks
	var neighbor_east = TerrainChunk.new()
	neighbor_east.chunk_coord = Vector2i(1, 0)
	neighbor_east.current_lod = 0

	var neighbors = {Vector2i(1, 0): neighbor_east}

	# Test stitching
	chunk_renderer.stitch_chunk_edges(chunk, neighbors)

	assert_eq(chunk.neighbors.size(), 1, "Should store neighbor reference")
	assert_true(chunk.neighbors.has(Vector2i(1, 0)), "Should have east neighbor")

	chunk.queue_free()
	neighbor_east.queue_free()


func test_mesh_generation_consistency():
	# Generate the same mesh twice and verify consistency
	var mesh1 = chunk_renderer.create_chunk_mesh(test_heightmap, test_biome_map, Vector2i(0, 0), 0)
	var mesh2 = chunk_renderer.create_chunk_mesh(test_heightmap, test_biome_map, Vector2i(0, 0), 0)

	assert_not_null(mesh1, "First mesh should be created")
	assert_not_null(mesh2, "Second mesh should be created")

	# Both meshes should have the same structure
	assert_eq(
		mesh1.get_surface_count(),
		mesh2.get_surface_count(),
		"Meshes should have same surface count"
	)


func test_material_uses_sea_level_manager():
	# Test that materials query SeaLevelManager for current sea level
	# Set a specific sea level
	if SeaLevelManager:
		SeaLevelManager.set_sea_level(0.6)  # Above default
		
		# Create material
		var material = chunk_renderer.create_chunk_material(test_biome_map, test_bump_map)
		
		assert_not_null(material, "Should create a material")
		
		# Check that sea_level parameter matches manager's value
		var sea_level_param = material.get_shader_parameter("sea_level")
		var expected_sea_level = SeaLevelManager.get_sea_level_meters()
		
		assert_almost_eq(sea_level_param, expected_sea_level, 0.01, 
			"Material sea_level should match SeaLevelManager value")
		
		# Reset to default
		SeaLevelManager.reset_to_default()
	else:
		fail_test("SeaLevelManager not available")


func test_material_sea_level_with_different_values():
	# Test that materials reflect different sea level values
	if SeaLevelManager:
		# Test with low sea level
		SeaLevelManager.set_sea_level(0.4)
		var material_low = chunk_renderer.create_chunk_material(test_biome_map, test_bump_map)
		var sea_level_low = material_low.get_shader_parameter("sea_level")
		
		# Test with high sea level
		SeaLevelManager.set_sea_level(0.7)
		var material_high = chunk_renderer.create_chunk_material(test_biome_map, test_bump_map)
		var sea_level_high = material_high.get_shader_parameter("sea_level")
		
		# High sea level should be greater than low sea level
		assert_gt(sea_level_high, sea_level_low, 
			"Higher normalized sea level should result in higher meter value")
		
		# Reset to default
		SeaLevelManager.reset_to_default()
	else:
		fail_test("SeaLevelManager not available")
