extends GutTest

# Unit tests for CoordinateSystem utility module
# Validates: Requirements 1.1, 1.4

const CoordinateSystem = preload("res://scripts/physics/coordinate_system.gd")

func test_calculate_heading_north():
	var north = Vector3(0, 0, -1)
	var heading = CoordinateSystem.calculate_heading(north)
	assert_almost_eq(heading, 0.0, 0.1, "North should be 0°")

func test_calculate_heading_east():
	var east = Vector3(1, 0, 0)
	var heading = CoordinateSystem.calculate_heading(east)
	assert_almost_eq(heading, 90.0, 0.1, "East should be 90°")

func test_calculate_heading_south():
	var south = Vector3(0, 0, 1)
	var heading = CoordinateSystem.calculate_heading(south)
	assert_almost_eq(heading, 180.0, 0.1, "South should be 180°")

func test_calculate_heading_west():
	var west = Vector3(-1, 0, 0)
	var heading = CoordinateSystem.calculate_heading(west)
	assert_almost_eq(heading, 270.0, 0.1, "West should be 270°")

func test_calculate_heading_zero_vector():
	var zero = Vector3.ZERO
	var heading = CoordinateSystem.calculate_heading(zero)
	assert_eq(heading, 0.0, "Zero vector should return 0°")

func test_normalize_heading_negative():
	var normalized = CoordinateSystem.normalize_heading(-45.0)
	assert_almost_eq(normalized, 315.0, 0.1, "-45° should normalize to 315°")

func test_normalize_heading_over_360():
	var normalized = CoordinateSystem.normalize_heading(450.0)
	assert_almost_eq(normalized, 90.0, 0.1, "450° should normalize to 90°")

func test_normalize_heading_720():
	var normalized = CoordinateSystem.normalize_heading(720.0)
	assert_almost_eq(normalized, 0.0, 0.1, "720° should normalize to 0°")

func test_normalize_heading_already_normalized():
	var normalized = CoordinateSystem.normalize_heading(180.0)
	assert_almost_eq(normalized, 180.0, 0.1, "180° should remain 180°")

func test_heading_error_wrap_around_positive():
	var error = CoordinateSystem.heading_error(350.0, 10.0)
	assert_almost_eq(error, 20.0, 0.1, "350° to 10° should be +20° (turn right)")

func test_heading_error_wrap_around_negative():
	var error = CoordinateSystem.heading_error(10.0, 350.0)
	assert_almost_eq(error, -20.0, 0.1, "10° to 350° should be -20° (turn left)")

func test_heading_error_180_degrees():
	var error = CoordinateSystem.heading_error(0.0, 180.0)
	# Either 180 or -180 is acceptable for exactly opposite directions
	assert_true(abs(abs(error) - 180.0) < 0.1, "0° to 180° should be ±180°")

func test_heading_error_same_heading():
	var error = CoordinateSystem.heading_error(90.0, 90.0)
	assert_almost_eq(error, 0.0, 0.1, "Same heading should have 0° error")

func test_forward_direction_from_transform_default():
	var transform = Transform3D()
	var forward = CoordinateSystem.forward_direction_from_transform(transform)
	assert_almost_eq(forward.x, 0.0, 0.01, "Default forward X should be 0")
	assert_almost_eq(forward.y, 0.0, 0.01, "Default forward Y should be 0")
	assert_almost_eq(forward.z, -1.0, 0.01, "Default forward Z should be -1")

func test_forward_direction_from_transform_rotated():
	var transform = Transform3D()
	transform = transform.rotated(Vector3.UP, deg_to_rad(90.0))
	var forward = CoordinateSystem.forward_direction_from_transform(transform)
	# After 90° rotation around Y, forward should point East
	assert_almost_eq(forward.x, 1.0, 0.01, "90° rotated forward X should be 1")
	assert_almost_eq(forward.z, 0.0, 0.01, "90° rotated forward Z should be 0")

func test_heading_to_vector2_north():
	var vec = CoordinateSystem.heading_to_vector2(0.0)
	assert_almost_eq(vec.x, 0.0, 0.01, "North X should be 0")
	assert_almost_eq(vec.y, -1.0, 0.01, "North Y should be -1")

func test_heading_to_vector2_east():
	var vec = CoordinateSystem.heading_to_vector2(90.0)
	assert_almost_eq(vec.x, 1.0, 0.01, "East X should be 1")
	assert_almost_eq(vec.y, 0.0, 0.01, "East Y should be 0")

func test_heading_to_vector2_south():
	var vec = CoordinateSystem.heading_to_vector2(180.0)
	assert_almost_eq(vec.x, 0.0, 0.01, "South X should be 0")
	assert_almost_eq(vec.y, 1.0, 0.01, "South Y should be 1")

func test_heading_to_vector2_west():
	var vec = CoordinateSystem.heading_to_vector2(270.0)
	assert_almost_eq(vec.x, -1.0, 0.01, "West X should be -1")
	assert_almost_eq(vec.y, 0.0, 0.01, "West Y should be 0")
