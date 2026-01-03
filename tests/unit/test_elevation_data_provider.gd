extends GutTest
## Unit tests for ElevationDataProvider

const ElevationDataProvider = preload("res://scripts/rendering/elevation_data_provider.gd")

var provider: ElevationDataProvider


func before_each():
	"""Setup before each test"""
	provider = ElevationDataProvider.new()
	add_child_autofree(provider)


func test_initialization():
	"""Test that provider initializes correctly"""
	var success = provider.initialize()
	# Should either succeed with map or fallback to procedural
	assert_true(provider != null, "Provider should be created")
	# Check that reference values are correct
	assert_eq(provider.get_mariana_depth(), -10994.0, "Mariana Trench depth should be -10994m")
	assert_eq(provider.get_everest_height(), 8849.0, "Mount Everest height should be 8849m")


func test_metadata_loading():
	"""Test that metadata is loaded without loading full image"""
	provider.initialize()
	var dimensions = provider.get_map_dimensions()

	if not provider.is_using_procedural():
		# If using real map, dimensions should be non-zero
		assert_gt(dimensions.x, 0, "Map width should be positive")
		assert_gt(dimensions.y, 0, "Map height should be positive")
		print("Map dimensions: ", dimensions)
	else:
		print("Using procedural fallback")


func test_vertical_scale():
	"""Test that vertical scale is calculated"""
	provider.initialize()
	var scale = provider.get_vertical_scale()

	if not provider.is_using_procedural():
		assert_gt(scale, 0.0, "Vertical scale should be positive")
		print("Vertical scale: %.2f m/pixel" % scale)


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
	var resolution = 64
	var region_image = provider.extract_region(test_bounds, resolution)

	assert_not_null(region_image, "Region image should be created")
	assert_eq(region_image.get_width(), resolution, "Region width should match resolution")
	assert_eq(region_image.get_height(), resolution, "Region height should match resolution")

	# Check that pixels contain valid normalized values (0-1)
	for y in range(min(10, resolution)):
		for x in range(min(10, resolution)):
			var pixel = region_image.get_pixel(x, y)
			assert_between(pixel.r, 0.0, 1.0, "Pixel value should be normalized (0-1)")


func test_fallback_to_procedural():
	"""Test that procedural fallback works when map is missing"""
	# Create provider with invalid path
	var fallback_provider = ElevationDataProvider.new()
	fallback_provider.elevation_map_path = "res://nonexistent_map.png"
	add_child_autofree(fallback_provider)

	var success = fallback_provider.initialize()
	assert_false(success, "Should return false when falling back to procedural")
	assert_true(fallback_provider.is_using_procedural(), "Should be using procedural generation")

	# Should still be able to get elevations
	var elevation = fallback_provider.get_elevation(Vector2(0, 0))
	assert_between(elevation, -11000.0, 9000.0, "Procedural elevation should be in valid range")
