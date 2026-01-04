extends GutTest
## Unit tests for ProceduralDetailGenerator

var generator: ProceduralDetailGenerator


func before_each():
	"""Setup before each test"""
	generator = ProceduralDetailGenerator.new()
	add_child_autofree(generator)


func test_initialization():
	"""Test that generator initializes correctly"""
	assert_not_null(generator, "Generator should be created")
	assert_gt(generator.detail_scale, 0.0, "Detail scale should be positive")
	assert_eq(generator.detail_scale, 30.0, "Detail scale should be 30.0 meters")
	assert_eq(generator.detail_contribution, 0.5, "Detail contribution should be 50%")
	assert_eq(generator.flat_terrain_threshold, 0.05, "Flat terrain threshold should be 0.05")
	assert_eq(generator.flat_terrain_amplitude, 35.0, "Flat terrain amplitude should be 35.0 meters")


func test_get_heightmap_stats_basic():
	"""Test heightmap statistics calculation"""
	var heightmap = Image.create(16, 16, false, Image.FORMAT_RF)
	
	# Fill with values from 0.2 to 0.8
	for y in range(16):
		for x in range(16):
			var value = 0.2 + (float(x + y) / 30.0) * 0.6
			heightmap.set_pixel(x, y, Color(value, 0, 0, 1))
	
	var stats = generator.get_heightmap_stats(heightmap)
	
	assert_almost_eq(stats.min_value, 0.2, 0.01, "Min value should be ~0.2")
	assert_almost_eq(stats.max_value, 0.8, 0.01, "Max value should be ~0.8")
	assert_almost_eq(stats.range, 0.6, 0.02, "Range should be ~0.6")
	assert_false(stats.is_flat, "Terrain with 60% range should not be flat")


func test_is_flat_terrain_detection():
	"""Test flat terrain detection"""
	# Create a flat heightmap (< 5% variation)
	var flat_map = Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			var value = 0.5 + (float(x) / 16.0) * 0.03  # Only 3% variation
			flat_map.set_pixel(x, y, Color(value, 0, 0, 1))
	
	assert_true(generator.is_flat_terrain(flat_map), "Terrain with 3% variation should be flat")
	
	# Create a varied heightmap (> 5% variation)
	var varied_map = Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			var value = 0.3 + (float(x) / 16.0) * 0.4  # 40% variation
			varied_map.set_pixel(x, y, Color(value, 0, 0, 1))
	
	assert_false(generator.is_flat_terrain(varied_map), "Terrain with 40% variation should not be flat")


func test_generate_detail_basic():
	"""Test basic detail generation"""
	# Create a simple base heightmap
	var base_map = Image.create(32, 32, false, Image.FORMAT_RF)

	# Fill with a simple gradient
	for y in range(32):
		for x in range(32):
			var height = float(y) / 32.0
			base_map.set_pixel(x, y, Color(height, 0, 0, 1))

	# Generate detail with new signature (no submarine_distance)
	var chunk_coord = Vector2i(0, 0)
	var chunk_size_meters = 512.0
	var detail_map = generator.generate_detail(base_map, chunk_coord, chunk_size_meters)

	assert_not_null(detail_map, "Detail map should be generated")
	assert_eq(detail_map.get_width(), 32, "Detail map width should match base")
	assert_eq(detail_map.get_height(), 32, "Detail map height should match base")


func test_generate_detail_follows_base():
	"""Test that detail follows base elevation (no major inversions)"""
	# Create a base heightmap with a clear gradient
	var base_map = Image.create(32, 32, false, Image.FORMAT_RF)

	for y in range(32):
		for x in range(32):
			var height = float(y) / 32.0  # Increases from 0 to 1 along Y
			base_map.set_pixel(x, y, Color(height, 0, 0, 1))

	# Generate detail
	var detail_map = generator.generate_detail(base_map, Vector2i(0, 0), 512.0)

	# Check that general trend is preserved
	# Bottom row should still be lower than top row on average
	var bottom_avg = 0.0
	var top_avg = 0.0

	for x in range(32):
		bottom_avg += detail_map.get_pixel(x, 0).r
		top_avg += detail_map.get_pixel(x, 31).r

	bottom_avg /= 32.0
	top_avg /= 32.0

	assert_lt(bottom_avg, top_avg, "Detail should preserve general elevation trend (bottom < top)")


func test_generate_detail_with_null_input():
	"""Test that null input is handled gracefully"""
	# This test verifies error handling - errors are expected
	var detail_map = generator.generate_detail(null, Vector2i(0, 0), 512.0)
	assert_null(detail_map, "Should return null for null input")


func test_generate_detail_consistency():
	"""Test that same chunk coordinates produce consistent detail"""
	var base_map = Image.create(16, 16, false, Image.FORMAT_RF)

	# Fill with constant height
	for y in range(16):
		for x in range(16):
			base_map.set_pixel(x, y, Color(0.5, 0, 0, 1))

	# Generate detail twice with same chunk coordinates
	var chunk_coord = Vector2i(5, 7)
	var detail_map1 = generator.generate_detail(base_map, chunk_coord, 512.0)
	var detail_map2 = generator.generate_detail(base_map, chunk_coord, 512.0)

	# Sample a few pixels and verify they match
	for i in range(5):
		var x = i * 3
		var y = i * 3
		var pixel1 = detail_map1.get_pixel(x, y).r
		var pixel2 = detail_map2.get_pixel(x, y).r
		assert_almost_eq(
			pixel1,
			pixel2,
			0.0001,
			"Same chunk coordinates should produce identical detail at (%d, %d)" % [x, y]
		)


func test_flat_terrain_gets_enhanced():
	"""Test that flat terrain receives aggressive enhancement"""
	# Create a very flat heightmap (< 5% variation)
	var flat_map = Image.create(32, 32, false, Image.FORMAT_RF)
	for y in range(32):
		for x in range(32):
			var value = 0.5 + (float(x) / 32.0) * 0.02  # Only 2% variation
			flat_map.set_pixel(x, y, Color(value, 0, 0, 1))
	
	# Verify it's detected as flat
	assert_true(generator.is_flat_terrain(flat_map), "Test map should be detected as flat")
	
	# Generate detail
	var detail_map = generator.generate_detail(flat_map, Vector2i(0, 0), 512.0)
	
	# The output should have more variation than the input
	var input_stats = generator.get_heightmap_stats(flat_map)
	var output_stats = generator.get_heightmap_stats(detail_map)
	
	assert_gt(output_stats.range, input_stats.range, 
		"Enhanced flat terrain should have more variation than input")


func test_generate_bump_map_basic():
	"""Test basic bump map generation"""
	# Create a simple base heightmap
	var base_map = Image.create(32, 32, false, Image.FORMAT_RF)

	# Fill with a simple gradient
	for y in range(32):
		for x in range(32):
			var height = float(y) / 32.0
			base_map.set_pixel(x, y, Color(height, 0, 0, 1))

	# Generate bump map
	var bump_map = generator.generate_bump_map(base_map, Vector2i(0, 0))

	assert_not_null(bump_map, "Bump map should be generated")
	assert_eq(bump_map.get_width(), 32, "Bump map width should match base")
	assert_eq(bump_map.get_height(), 32, "Bump map height should match base")
	assert_eq(bump_map.get_format(), Image.FORMAT_RGBA8, "Bump map should be RGBA8")


func test_bump_map_contains_valid_normals():
	"""Test that bump map contains valid normal data"""
	var base_map = Image.create(16, 16, false, Image.FORMAT_RF)

	# Create a simple slope
	for y in range(16):
		for x in range(16):
			var height = float(x + y) / 32.0
			base_map.set_pixel(x, y, Color(height, 0, 0, 1))

	var bump_map = generator.generate_bump_map(base_map, Vector2i(0, 0))

	# Check that normals are in valid range [0, 1] (stored normalized)
	for y in range(16):
		for x in range(16):
			var pixel = bump_map.get_pixel(x, y)
			assert_between(pixel.r, 0.0, 1.0, "Normal X should be in [0, 1]")
			assert_between(pixel.g, 0.0, 1.0, "Normal Y should be in [0, 1]")
			assert_between(pixel.b, 0.0, 1.0, "Normal Z should be in [0, 1]")

			# Z component should generally be positive (pointing up)
			# In normalized space, 0.5 = 0, so > 0.5 means pointing up
			assert_gt(pixel.b, 0.3, "Normal Z should generally point upward")


func test_bump_map_with_null_input():
	"""Test that null input is handled gracefully"""
	var bump_map = generator.generate_bump_map(null, Vector2i(0, 0))
	assert_null(bump_map, "Should return null for null input")


func test_bump_map_flat_surface():
	"""Test bump map for a perfectly flat surface"""
	var base_map = Image.create(16, 16, false, Image.FORMAT_RF)

	# Fill with constant height (flat surface)
	for y in range(16):
		for x in range(16):
			base_map.set_pixel(x, y, Color(0.5, 0, 0, 1))

	var bump_map = generator.generate_bump_map(base_map, Vector2i(0, 0))

	# For a flat surface, normals should point straight up
	# In normalized space: (0.5, 0.5, 1.0) represents (0, 0, 1)
	var center_pixel = bump_map.get_pixel(8, 8)

	# X and Y should be close to 0.5 (representing 0)
	assert_almost_eq(center_pixel.r, 0.5, 0.1, "Flat surface normal X should be ~0.5")
	assert_almost_eq(center_pixel.g, 0.5, 0.1, "Flat surface normal Y should be ~0.5")
	# Z should be close to 1.0 (pointing up)
	assert_gt(center_pixel.b, 0.9, "Flat surface normal Z should be close to 1.0")


func test_boundary_consistency_horizontal():
	"""Test that procedural detail matches at horizontal chunk boundaries
	
	This verifies that the same world position generates the same noise
	value regardless of which chunk it's generated from.
	Requirements: 6.1, 6.2
	"""
	var chunk_size_meters = 512.0  # Match ChunkManager default
	var chunk_size_pixels = 32

	# Create two adjacent chunks horizontally (chunk 0,0 and chunk 1,0)
	var base_map1 = Image.create(chunk_size_pixels, chunk_size_pixels, false, Image.FORMAT_RF)
	var base_map2 = Image.create(chunk_size_pixels, chunk_size_pixels, false, Image.FORMAT_RF)

	# Fill with constant height for simplicity
	for y in range(chunk_size_pixels):
		for x in range(chunk_size_pixels):
			base_map1.set_pixel(x, y, Color(0.5, 0, 0, 1))
			base_map2.set_pixel(x, y, Color(0.5, 0, 0, 1))

	# Generate detail for both chunks (new signature without submarine_distance)
	var chunk_coord1 = Vector2i(0, 0)
	var chunk_coord2 = Vector2i(1, 0)
	var detail_map1 = generator.generate_detail(base_map1, chunk_coord1, chunk_size_meters)
	var detail_map2 = generator.generate_detail(base_map2, chunk_coord2, chunk_size_meters)

	# The right edge of chunk1 should match the left edge of chunk2
	# because they represent the same world positions
	for y in range(chunk_size_pixels):
		var edge1_value = detail_map1.get_pixel(chunk_size_pixels - 1, y).r
		var edge2_value = detail_map2.get_pixel(0, y).r

		assert_almost_eq(
			edge1_value,
			edge2_value,
			0.0001,
			"Horizontal boundary at y=%d should have matching detail values" % y
		)


func test_boundary_consistency_vertical():
	"""Test that procedural detail matches at vertical chunk boundaries
	
	This verifies that the same world position generates the same noise
	value regardless of which chunk it's generated from.
	Requirements: 6.1, 6.2
	"""
	var chunk_size_meters = 512.0  # Match ChunkManager default
	var chunk_size_pixels = 32

	# Create two adjacent chunks vertically (chunk 0,0 and chunk 0,1)
	var base_map1 = Image.create(chunk_size_pixels, chunk_size_pixels, false, Image.FORMAT_RF)
	var base_map2 = Image.create(chunk_size_pixels, chunk_size_pixels, false, Image.FORMAT_RF)

	# Fill with constant height for simplicity
	for y in range(chunk_size_pixels):
		for x in range(chunk_size_pixels):
			base_map1.set_pixel(x, y, Color(0.5, 0, 0, 1))
			base_map2.set_pixel(x, y, Color(0.5, 0, 0, 1))

	# Generate detail for both chunks
	var chunk_coord1 = Vector2i(0, 0)
	var chunk_coord2 = Vector2i(0, 1)
	var detail_map1 = generator.generate_detail(base_map1, chunk_coord1, chunk_size_meters)
	var detail_map2 = generator.generate_detail(base_map2, chunk_coord2, chunk_size_meters)

	# The bottom edge of chunk1 should match the top edge of chunk2
	# because they represent the same world positions
	for x in range(chunk_size_pixels):
		var edge1_value = detail_map1.get_pixel(x, chunk_size_pixels - 1).r
		var edge2_value = detail_map2.get_pixel(x, 0).r

		assert_almost_eq(
			edge1_value,
			edge2_value,
			0.0001,
			"Vertical boundary at x=%d should have matching detail values" % x
		)


func test_boundary_consistency_diagonal():
	"""Test that procedural detail matches at diagonal chunk corners
	
	This verifies consistency at the corner where four chunks meet.
	Requirements: 6.1, 6.2
	"""
	var chunk_size_meters = 512.0  # Match ChunkManager default
	var chunk_size_pixels = 32

	# Create four chunks that meet at a corner
	var base_map = Image.create(chunk_size_pixels, chunk_size_pixels, false, Image.FORMAT_RF)

	# Fill with constant height
	for y in range(chunk_size_pixels):
		for x in range(chunk_size_pixels):
			base_map.set_pixel(x, y, Color(0.5, 0, 0, 1))

	# Generate detail for all four chunks
	var chunk_coords = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

	var detail_maps = []
	for coord in chunk_coords:
		var detail = generator.generate_detail(base_map, coord, chunk_size_meters)
		detail_maps.append(detail)

	# Check that the corner values all match
	# Bottom-left chunk: bottom-right corner
	var val_bl = detail_maps[0].get_pixel(chunk_size_pixels - 1, chunk_size_pixels - 1).r
	# Bottom-right chunk: bottom-left corner
	var val_br = detail_maps[1].get_pixel(0, chunk_size_pixels - 1).r
	# Top-left chunk: top-right corner
	var val_tl = detail_maps[2].get_pixel(chunk_size_pixels - 1, 0).r
	# Top-right chunk: top-left corner
	var val_tr = detail_maps[3].get_pixel(0, 0).r

	assert_almost_eq(val_bl, val_br, 0.0001, "Corner values should match (BL vs BR)")
	assert_almost_eq(val_bl, val_tl, 0.0001, "Corner values should match (BL vs TL)")
	assert_almost_eq(val_bl, val_tr, 0.0001, "Corner values should match (BL vs TR)")


func test_boundary_consistency_with_varying_base():
	"""Test boundary consistency when base heightmap varies
	
	This ensures that even when the base terrain is different,
	the procedural detail component remains consistent at boundaries.
	Requirements: 6.1, 6.2
	"""
	var chunk_size_meters = 512.0  # Match ChunkManager default
	var chunk_size_pixels = 32

	# Create two adjacent chunks with different base heights
	var base_map1 = Image.create(chunk_size_pixels, chunk_size_pixels, false, Image.FORMAT_RF)
	var base_map2 = Image.create(chunk_size_pixels, chunk_size_pixels, false, Image.FORMAT_RF)

	# Chunk 1: gradient from 0.3 to 0.5
	for y in range(chunk_size_pixels):
		for x in range(chunk_size_pixels):
			var height = 0.3 + (float(x) / chunk_size_pixels) * 0.2
			base_map1.set_pixel(x, y, Color(height, 0, 0, 1))

	# Chunk 2: gradient from 0.5 to 0.7
	for y in range(chunk_size_pixels):
		for x in range(chunk_size_pixels):
			var height = 0.5 + (float(x) / chunk_size_pixels) * 0.2
			base_map2.set_pixel(x, y, Color(height, 0, 0, 1))

	# Generate detail for both chunks
	var chunk_coord1 = Vector2i(0, 0)
	var chunk_coord2 = Vector2i(1, 0)
	var detail_map1 = generator.generate_detail(base_map1, chunk_coord1, chunk_size_meters)
	var detail_map2 = generator.generate_detail(base_map2, chunk_coord2, chunk_size_meters)

	# Extract the procedural detail component by subtracting base
	# At the boundary, the detail component should match
	for y in range(chunk_size_pixels):
		var base1 = base_map1.get_pixel(chunk_size_pixels - 1, y).r
		var detail1 = detail_map1.get_pixel(chunk_size_pixels - 1, y).r
		var noise1 = detail1 - base1

		var base2 = base_map2.get_pixel(0, y).r
		var detail2 = detail_map2.get_pixel(0, y).r
		var noise2 = detail2 - base2

		# The noise component should be identical at the boundary
		assert_almost_eq(
			noise1, noise2, 0.0001, "Procedural detail component should match at boundary y=%d" % y
		)
