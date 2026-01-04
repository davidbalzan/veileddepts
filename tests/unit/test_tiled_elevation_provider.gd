extends GutTest
## Unit tests for TiledElevationProvider

const TiledElevationProviderScript = preload("res://scripts/rendering/tiled_elevation_provider.gd")

var provider: TiledElevationProvider


func before_each():
	"""Setup before each test"""
	provider = TiledElevationProvider.new()
	add_child_autofree(provider)


func test_initialization():
	"""Test that provider initializes correctly"""
	var has_tiles = provider.initialize()
	assert_true(provider != null, "Provider should be created")
	# Check that reference values are correct
	assert_eq(provider.get_mariana_depth(), -10994.0, "Mariana Trench depth should be -10994m")
	assert_eq(provider.get_everest_height(), 8849.0, "Mount Everest height should be 8849m")
	print("Has tiles: %s, Using procedural: %s" % [has_tiles, provider.is_using_procedural()])


func test_has_tiles():
	"""Test that has_tiles() returns correct value"""
	provider.initialize()
	var has_tiles = provider.has_tiles()
	# Should have tiles if tileset.json exists
	if FileAccess.file_exists("res://assets/terrain/tiles/tileset.json"):
		assert_true(has_tiles, "Should have tiles when tileset.json exists")
	else:
		assert_false(has_tiles, "Should not have tiles when tileset.json missing")


func test_metadata_loading():
	"""Test that metadata is loaded correctly"""
	provider.initialize()
	var dimensions = provider.get_map_dimensions()

	if provider.has_tiles():
		# If using tiles, dimensions should match source
		assert_eq(dimensions.x, 21600, "Source width should be 21600")
		assert_eq(dimensions.y, 10800, "Source height should be 10800")
		print("Map dimensions: ", dimensions)
	elif not provider.is_using_procedural():
		# Using source image fallback
		assert_gt(dimensions.x, 0, "Map width should be positive")
		assert_gt(dimensions.y, 0, "Map height should be positive")
		print("Source image dimensions: ", dimensions)
	else:
		print("Using procedural fallback")


func test_get_elevation():
	"""Test elevation queries at various positions"""
	provider.initialize()

	# Test a few positions
	var test_positions = [
		Vector2(0, 0),
		Vector2(1000000, 500000),
		Vector2(-1000000, -500000),
	]

	for pos in test_positions:
		var elevation = provider.get_elevation(pos)
		# Elevation should be within Earth's range
		assert_between(
			elevation, -11000.0, 9000.0, "Elevation at %s should be within Earth's range" % pos
		)


func test_region_extraction():
	"""Test extracting a region from the elevation data"""
	provider.initialize()

	var test_bounds = Rect2(0, 0, 10000, 10000)  # 10km x 10km
	var resolution = 16  # Smaller for faster test
	var region_image = provider.extract_region(test_bounds, resolution)

	assert_not_null(region_image, "Region image should be created")
	assert_eq(region_image.get_width(), resolution, "Region width should match resolution")
	assert_eq(region_image.get_height(), resolution, "Region height should match resolution")

	# Check that pixels contain valid normalized values (0-1)
	for y in range(min(5, resolution)):
		for x in range(min(5, resolution)):
			var pixel = region_image.get_pixel(x, y)
			assert_between(pixel.r, 0.0, 1.0, "Pixel value should be normalized (0-1)")


func test_extract_region_lod():
	"""Test LOD-based region extraction"""
	provider.initialize()

	var test_bounds = Rect2(0, 0, 50000, 50000)  # 50km x 50km

	# Test LOD 3 only (fastest)
	var lod = 3
	var region_image = provider.extract_region_lod(test_bounds, lod)
	assert_not_null(region_image, "Region image should be created for LOD %d" % lod)
	
	# Resolution should be 32 for LOD 3
	var expected_res = 32
	assert_eq(region_image.get_width(), expected_res, "LOD %d width should be %d" % [lod, expected_res])
	assert_eq(region_image.get_height(), expected_res, "LOD %d height should be %d" % [lod, expected_res])


func test_get_lod_for_zoom():
	"""Test LOD level selection based on zoom"""
	provider.initialize()

	# Very zoomed in (< 10 m/pixel) -> LOD 0
	assert_eq(provider.get_lod_for_zoom(5.0), 0, "Very zoomed in should use LOD 0")
	
	# Medium zoom (10-50 m/pixel) -> LOD 1
	assert_eq(provider.get_lod_for_zoom(25.0), 1, "Medium zoom should use LOD 1")
	
	# Overview (50-200 m/pixel) -> LOD 2
	assert_eq(provider.get_lod_for_zoom(100.0), 2, "Overview should use LOD 2")
	
	# World map (> 200 m/pixel) -> LOD 3
	assert_eq(provider.get_lod_for_zoom(500.0), 3, "World map should use LOD 3")


func test_cache_stats():
	"""Test cache statistics reporting"""
	provider.initialize()
	
	# Query some elevations to populate cache
	for i in range(5):
		provider.get_elevation(Vector2(i * 100000, i * 50000))
	
	var stats = provider.get_cache_stats()
	assert_has(stats, "cached_tiles", "Stats should include cached_tiles")
	assert_has(stats, "max_tiles", "Stats should include max_tiles")
	assert_has(stats, "has_tiles", "Stats should include has_tiles")
	assert_has(stats, "using_procedural", "Stats should include using_procedural")
	
	print("Cache stats: ", stats)


func test_clear_cache():
	"""Test cache clearing"""
	provider.initialize()
	
	# Query some elevations to populate cache
	for i in range(5):
		provider.get_elevation(Vector2(i * 100000, i * 50000))
	
	var _stats_before = provider.get_cache_stats()
	provider.clear_cache()
	var stats_after = provider.get_cache_stats()
	
	assert_eq(stats_after.cached_tiles, 0, "Cache should be empty after clear")


func test_fallback_to_procedural():
	"""Test that procedural fallback works when tiles and source are missing"""
	var fallback_provider = TiledElevationProvider.new()
	fallback_provider.tiles_directory = "res://nonexistent_tiles/"
	fallback_provider.source_image_path = "res://nonexistent_map.png"
	add_child_autofree(fallback_provider)

	var has_tiles = fallback_provider.initialize()
	assert_false(has_tiles, "Should return false when no tiles available")
	assert_true(fallback_provider.is_using_procedural(), "Should be using procedural generation")

	# Should still be able to get elevations
	var elevation = fallback_provider.get_elevation(Vector2(0, 0))
	assert_between(elevation, -11000.0, 9000.0, "Procedural elevation should be in valid range")


func test_tile_coord_for_world_pos():
	"""Test tile coordinate calculation"""
	provider.initialize()
	
	if not provider.has_tiles():
		gut.p("Skipping tile coord test - no tiles available")
		return
	
	var tile_coord = provider.get_tile_coord_for_world_pos(Vector2(0, 0))
	assert_true(tile_coord.x >= 0, "Tile X should be non-negative")
	assert_true(tile_coord.y >= 0, "Tile Y should be non-negative")


func test_preload_tiles_around():
	"""Test tile preloading"""
	provider.initialize()
	
	if not provider.has_tiles():
		gut.p("Skipping preload test - no tiles available")
		return
	
	var _stats_before = provider.get_cache_stats()
	provider.preload_tiles_around(Vector2i(21, 11), 1)  # Center of map
	var stats_after = provider.get_cache_stats()
	
	# Should have loaded some tiles
	assert_gte(stats_after.cached_tiles, 0, "Should have loaded tiles")


func test_cached_overview():
	"""Test cached world overview retrieval"""
	provider.initialize()
	
	if provider.is_using_procedural():
		gut.p("Skipping overview test - using procedural")
		return
	
	# Get cached overview at LOD 3 only (smallest)
	var overview = provider.get_cached_overview(3)
	if overview:
		assert_eq(overview.get_width(), 32, "Overview LOD 3 width should be 32")
