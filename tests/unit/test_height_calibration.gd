extends GutTest
## Unit tests for HeightCalibration class
##
## Tests calibration data management, pixel-to-elevation conversion,
## and file save/load functionality.

const HeightCalibration = preload("res://scripts/rendering/height_calibration.gd")

var calibration: HeightCalibration
var test_heightmap: Image


func before_each():
	calibration = HeightCalibration.new()
	
	# Create a test heightmap with known values
	test_heightmap = Image.create(4, 4, false, Image.FORMAT_RGB8)
	
	# Set pixels to known grayscale values
	# Row 0: black (0.0)
	test_heightmap.set_pixel(0, 0, Color(0.0, 0.0, 0.0))
	test_heightmap.set_pixel(1, 0, Color(0.0, 0.0, 0.0))
	test_heightmap.set_pixel(2, 0, Color(0.0, 0.0, 0.0))
	test_heightmap.set_pixel(3, 0, Color(0.0, 0.0, 0.0))
	
	# Row 1: dark gray (0.25)
	test_heightmap.set_pixel(0, 1, Color(0.25, 0.25, 0.25))
	test_heightmap.set_pixel(1, 1, Color(0.25, 0.25, 0.25))
	test_heightmap.set_pixel(2, 1, Color(0.25, 0.25, 0.25))
	test_heightmap.set_pixel(3, 1, Color(0.25, 0.25, 0.25))
	
	# Row 2: medium gray (0.5)
	test_heightmap.set_pixel(0, 2, Color(0.5, 0.5, 0.5))
	test_heightmap.set_pixel(1, 2, Color(0.5, 0.5, 0.5))
	test_heightmap.set_pixel(2, 2, Color(0.5, 0.5, 0.5))
	test_heightmap.set_pixel(3, 2, Color(0.5, 0.5, 0.5))
	
	# Row 3: white (1.0)
	test_heightmap.set_pixel(0, 3, Color(1.0, 1.0, 1.0))
	test_heightmap.set_pixel(1, 3, Color(1.0, 1.0, 1.0))
	test_heightmap.set_pixel(2, 3, Color(1.0, 1.0, 1.0))
	test_heightmap.set_pixel(3, 3, Color(1.0, 1.0, 1.0))


func after_each():
	calibration = null
	test_heightmap = null


func test_default_calibration_values():
	assert_eq(calibration.min_pixel_value, 0.0, "Default min pixel value should be 0.0")
	assert_eq(calibration.max_pixel_value, 1.0, "Default max pixel value should be 1.0")
	assert_eq(calibration.min_elevation_meters, HeightCalibration.MARIANA_TRENCH_DEPTH, 
		"Default min elevation should be Mariana Trench depth")
	assert_eq(calibration.max_elevation_meters, HeightCalibration.MOUNT_EVEREST_HEIGHT,
		"Default max elevation should be Mount Everest height")
	assert_false(calibration.is_calibrated, "Should not be calibrated by default")
	assert_eq(calibration.sea_level_offset_meters, 0.0, "Default sea level offset should be 0.0")


func test_from_heightmap_scans_correctly():
	var cal = HeightCalibration.from_heightmap(test_heightmap)
	
	assert_not_null(cal, "Should create calibration from heightmap")
	assert_true(cal.is_calibrated, "Should be marked as calibrated")
	assert_almost_eq(cal.min_pixel_value, 0.0, 0.01, "Should find min pixel value")
	assert_almost_eq(cal.max_pixel_value, 1.0, 0.01, "Should find max pixel value")


func test_from_heightmap_handles_null():
	var cal = HeightCalibration.from_heightmap(null)
	assert_null(cal, "Should return null for null heightmap")


func test_pixel_to_elevation_conversion():
	calibration.min_pixel_value = 0.0
	calibration.max_pixel_value = 1.0
	calibration.is_calibrated = true
	
	# Test min value
	var min_elev = calibration.pixel_to_elevation(0.0)
	assert_almost_eq(min_elev, HeightCalibration.MARIANA_TRENCH_DEPTH, 1.0,
		"Min pixel should map to Mariana Trench depth")
	
	# Test max value
	var max_elev = calibration.pixel_to_elevation(1.0)
	assert_almost_eq(max_elev, HeightCalibration.MOUNT_EVEREST_HEIGHT, 1.0,
		"Max pixel should map to Mount Everest height")
	
	# Test mid value (should be near sea level)
	var mid_elev = calibration.pixel_to_elevation(0.5)
	var expected_mid = (HeightCalibration.MARIANA_TRENCH_DEPTH + HeightCalibration.MOUNT_EVEREST_HEIGHT) / 2.0
	assert_almost_eq(mid_elev, expected_mid, 1.0,
		"Mid pixel should map to midpoint elevation")


func test_elevation_to_pixel_conversion():
	calibration.min_pixel_value = 0.0
	calibration.max_pixel_value = 1.0
	calibration.is_calibrated = true
	
	# Test min elevation
	var min_pixel = calibration.elevation_to_pixel(HeightCalibration.MARIANA_TRENCH_DEPTH)
	assert_almost_eq(min_pixel, 0.0, 0.01,
		"Mariana Trench depth should map to min pixel")
	
	# Test max elevation
	var max_pixel = calibration.elevation_to_pixel(HeightCalibration.MOUNT_EVEREST_HEIGHT)
	assert_almost_eq(max_pixel, 1.0, 0.01,
		"Mount Everest height should map to max pixel")
	
	# Test sea level (0m)
	var sea_level_pixel = calibration.elevation_to_pixel(0.0)
	var expected_pixel = inverse_lerp(
		HeightCalibration.MARIANA_TRENCH_DEPTH,
		HeightCalibration.MOUNT_EVEREST_HEIGHT,
		0.0
	)
	assert_almost_eq(sea_level_pixel, expected_pixel, 0.01,
		"Sea level should map to correct pixel value")


func test_round_trip_conversion():
	calibration.min_pixel_value = 0.0
	calibration.max_pixel_value = 1.0
	calibration.is_calibrated = true
	
	# Test round trip: pixel -> elevation -> pixel
	var test_pixels = [0.0, 0.25, 0.5, 0.75, 1.0]
	for pixel in test_pixels:
		var elevation = calibration.pixel_to_elevation(pixel)
		var back_to_pixel = calibration.elevation_to_pixel(elevation)
		assert_almost_eq(back_to_pixel, pixel, 0.01,
			"Round trip conversion should preserve pixel value: %.2f" % pixel)


func test_sea_level_offset_affects_conversion():
	calibration.min_pixel_value = 0.0
	calibration.max_pixel_value = 1.0
	calibration.is_calibrated = true
	
	# Get elevation without offset
	var elev_no_offset = calibration.pixel_to_elevation(0.5)
	
	# Set offset
	calibration.set_sea_level_offset(10.0)
	
	# Get elevation with offset
	var elev_with_offset = calibration.pixel_to_elevation(0.5)
	
	# Should be 10m higher
	assert_almost_eq(elev_with_offset, elev_no_offset + 10.0, 0.1,
		"Sea level offset should shift elevation by offset amount")


func test_get_elevation_range():
	calibration.min_elevation_meters = -200.0
	calibration.max_elevation_meters = 100.0
	calibration.sea_level_offset_meters = 5.0
	
	var range = calibration.get_elevation_range()
	
	assert_almost_eq(range.x, -195.0, 0.1, "Min range should include offset")
	assert_almost_eq(range.y, 105.0, 0.1, "Max range should include offset")


func test_get_pixel_range():
	calibration.min_pixel_value = 0.1
	calibration.max_pixel_value = 0.9
	
	var range = calibration.get_pixel_range()
	
	assert_almost_eq(range.x, 0.1, 0.01, "Should return min pixel value")
	assert_almost_eq(range.y, 0.9, 0.01, "Should return max pixel value")


func test_to_dict_and_from_dict():
	calibration.min_pixel_value = 0.1
	calibration.max_pixel_value = 0.9
	calibration.min_elevation_meters = -500.0
	calibration.max_elevation_meters = 200.0
	calibration.sea_level_offset_meters = 15.0
	calibration.is_calibrated = true
	
	# Convert to dict
	var data = calibration.to_dict()
	
	# Create new calibration from dict
	var new_cal = HeightCalibration.from_dict(data)
	
	assert_not_null(new_cal, "Should create calibration from dict")
	assert_almost_eq(new_cal.min_pixel_value, 0.1, 0.01, "Should preserve min pixel value")
	assert_almost_eq(new_cal.max_pixel_value, 0.9, 0.01, "Should preserve max pixel value")
	assert_almost_eq(new_cal.min_elevation_meters, -500.0, 0.1, "Should preserve min elevation")
	assert_almost_eq(new_cal.max_elevation_meters, 200.0, 0.1, "Should preserve max elevation")
	assert_almost_eq(new_cal.sea_level_offset_meters, 15.0, 0.1, "Should preserve sea level offset")
	assert_true(new_cal.is_calibrated, "Should preserve calibrated state")


func test_save_and_load_from_file():
	var test_path = "user://test_calibration.cfg"
	
	# Setup calibration
	calibration.min_pixel_value = 0.2
	calibration.max_pixel_value = 0.8
	calibration.sea_level_offset_meters = 20.0
	calibration.is_calibrated = true
	
	# Save to file
	var save_success = calibration.save_to_file(test_path)
	assert_true(save_success, "Should save calibration to file")
	
	# Load from file
	var loaded = HeightCalibration.load_from_file(test_path)
	assert_not_null(loaded, "Should load calibration from file")
	assert_almost_eq(loaded.min_pixel_value, 0.2, 0.01, "Should load min pixel value")
	assert_almost_eq(loaded.max_pixel_value, 0.8, 0.01, "Should load max pixel value")
	assert_almost_eq(loaded.sea_level_offset_meters, 20.0, 0.1, "Should load sea level offset")
	assert_true(loaded.is_calibrated, "Should load calibrated state")
	
	# Clean up
	DirAccess.remove_absolute(test_path)


func test_load_from_nonexistent_file():
	var loaded = HeightCalibration.load_from_file("user://nonexistent_file.cfg")
	assert_null(loaded, "Should return null for nonexistent file")


func test_get_summary():
	calibration.min_pixel_value = 0.0
	calibration.max_pixel_value = 1.0
	calibration.min_elevation_meters = -200.0
	calibration.max_elevation_meters = 100.0
	calibration.sea_level_offset_meters = 5.0
	calibration.is_calibrated = true
	
	var summary = calibration.get_summary()
	
	assert_string_contains(summary, "0.000000", "Summary should contain min pixel value")
	assert_string_contains(summary, "1.000000", "Summary should contain max pixel value")
	assert_string_contains(summary, "-195.0m", "Summary should contain adjusted min elevation")
	assert_string_contains(summary, "105.0m", "Summary should contain adjusted max elevation")
	assert_string_contains(summary, "5.0m", "Summary should contain offset")


func test_get_summary_not_calibrated():
	calibration.is_calibrated = false
	var summary = calibration.get_summary()
	assert_eq(summary, "Not calibrated", "Should return 'Not calibrated' when not calibrated")
