extends GutTest

# Property-Based Tests for CoordinateSystem utility module
# Feature: submarine-physics-v2, Property 1: Heading Calculation Consistency
# Validates: Requirements 1.1, 1.4

const CoordinateSystem = preload("res://scripts/physics/coordinate_system.gd")

# Number of random test iterations
const NUM_ITERATIONS = 100

# Property 1: Heading is always in [0, 360) range
func test_property_heading_always_in_valid_range():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		# Generate random yaw rotation
		var yaw = rng.randf_range(0.0, TAU)
		var transform = Transform3D().rotated(Vector3.UP, yaw)
		
		var forward_dir = CoordinateSystem.forward_direction_from_transform(transform)
		var heading = CoordinateSystem.calculate_heading(forward_dir)
		
		assert_true(heading >= 0.0, "Heading should be >= 0 (iteration %d: %.2f)" % [i, heading])
		assert_true(heading < 360.0, "Heading should be < 360 (iteration %d: %.2f)" % [i, heading])

# Property 2: Heading matches expected direction for cardinal points
func test_property_heading_matches_cardinal_directions():
	# Test North (0°)
	var north_transform = Transform3D()
	var north_heading = CoordinateSystem.calculate_heading(
		CoordinateSystem.forward_direction_from_transform(north_transform)
	)
	assert_almost_eq(north_heading, 0.0, 0.1, "Default transform should face North (0°)")
	
	# Test West (270°) - In Godot's left-handed system, +90° Y rotation turns LEFT to West
	var west_transform = Transform3D().rotated(Vector3.UP, deg_to_rad(90.0))
	var west_heading = CoordinateSystem.calculate_heading(
		CoordinateSystem.forward_direction_from_transform(west_transform)
	)
	assert_almost_eq(west_heading, 270.0, 0.1, "90° rotation should face West (270°)")
	
	# Test South (180°)
	var south_transform = Transform3D().rotated(Vector3.UP, deg_to_rad(180.0))
	var south_heading = CoordinateSystem.calculate_heading(
		CoordinateSystem.forward_direction_from_transform(south_transform)
	)
	assert_almost_eq(south_heading, 180.0, 0.1, "180° rotation should face South (180°)")
	
	# Test East (90°) - In Godot's left-handed system, +270° Y rotation (or -90°) turns RIGHT to East
	var east_transform = Transform3D().rotated(Vector3.UP, deg_to_rad(270.0))
	var east_heading = CoordinateSystem.calculate_heading(
		CoordinateSystem.forward_direction_from_transform(east_transform)
	)
	assert_almost_eq(east_heading, 90.0, 0.1, "270° rotation should face East (90°)")

# Property 3: Heading normalization works for negative angles
func test_property_normalization_negative_angles():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		var negative_angle = rng.randf_range(-720.0, 0.0)
		var normalized = CoordinateSystem.normalize_heading(negative_angle)
		
		assert_true(normalized >= 0.0, "Normalized heading should be >= 0 (iteration %d: input=%.2f, output=%.2f)" % [i, negative_angle, normalized])
		assert_true(normalized < 360.0, "Normalized heading should be < 360 (iteration %d: input=%.2f, output=%.2f)" % [i, negative_angle, normalized])

# Property 4: Heading normalization works for angles > 360
func test_property_normalization_large_angles():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		var large_angle = rng.randf_range(360.0, 1440.0)
		var normalized = CoordinateSystem.normalize_heading(large_angle)
		
		assert_true(normalized >= 0.0, "Normalized heading should be >= 0 (iteration %d: input=%.2f, output=%.2f)" % [i, large_angle, normalized])
		assert_true(normalized < 360.0, "Normalized heading should be < 360 (iteration %d: input=%.2f, output=%.2f)" % [i, large_angle, normalized])
		
		# Verify the normalized angle is equivalent (same direction)
		var expected = fmod(large_angle, 360.0)
		assert_almost_eq(normalized, expected, 0.01, "Normalized angle should match fmod result")

# Property 5: Forward direction is always normalized
func test_property_forward_direction_normalized():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		var yaw = rng.randf_range(0.0, TAU)
		var transform = Transform3D().rotated(Vector3.UP, yaw)
		
		var forward_dir = CoordinateSystem.forward_direction_from_transform(transform)
		var length = forward_dir.length()
		
		assert_almost_eq(length, 1.0, 0.01, "Forward direction should be normalized (iteration %d: length=%.4f)" % [i, length])

# Property 6: Heading error calculates shortest path
func test_property_heading_error_shortest_path():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		var current = rng.randf_range(0.0, 360.0)
		var target = rng.randf_range(0.0, 360.0)
		var error = CoordinateSystem.heading_error(current, target)
		
		# Error should always be in range [-180, 180]
		assert_true(error >= -180.0, "Heading error should be >= -180 (iteration %d: %.2f)" % [i, error])
		assert_true(error <= 180.0, "Heading error should be <= 180 (iteration %d: %.2f)" % [i, error])

# Property 7: Heading to Vector2 produces normalized vectors
func test_property_heading_to_vector2_normalized():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		var heading = rng.randf_range(0.0, 360.0)
		var vec = CoordinateSystem.heading_to_vector2(heading)
		var length = vec.length()
		
		assert_almost_eq(length, 1.0, 0.01, "Vector2 should be normalized (iteration %d: heading=%.2f, length=%.4f)" % [i, heading, length])

# Property 8: Heading to Vector2 matches expected directions
func test_property_heading_to_vector2_directions():
	# North (0°) should point up on screen (0, -1)
	var north_vec = CoordinateSystem.heading_to_vector2(0.0)
	assert_almost_eq(north_vec.x, 0.0, 0.01, "North X should be 0")
	assert_almost_eq(north_vec.y, -1.0, 0.01, "North Y should be -1 (up on screen)")
	
	# East (90°) should point right on screen (1, 0)
	var east_vec = CoordinateSystem.heading_to_vector2(90.0)
	assert_almost_eq(east_vec.x, 1.0, 0.01, "East X should be 1 (right on screen)")
	assert_almost_eq(east_vec.y, 0.0, 0.01, "East Y should be 0")
	
	# South (180°) should point down on screen (0, 1)
	var south_vec = CoordinateSystem.heading_to_vector2(180.0)
	assert_almost_eq(south_vec.x, 0.0, 0.01, "South X should be 0")
	assert_almost_eq(south_vec.y, 1.0, 0.01, "South Y should be 1 (down on screen)")
	
	# West (270°) should point left on screen (-1, 0)
	var west_vec = CoordinateSystem.heading_to_vector2(270.0)
	assert_almost_eq(west_vec.x, -1.0, 0.01, "West X should be -1 (left on screen)")
	assert_almost_eq(west_vec.y, 0.0, 0.01, "West Y should be 0")

# Property 9: Round-trip consistency (heading -> vector2 -> heading)
func test_property_round_trip_consistency():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		var original_heading = rng.randf_range(0.0, 360.0)
		var vec2 = CoordinateSystem.heading_to_vector2(original_heading)
		
		# Convert back to 3D direction (assuming Y=0 for horizontal plane)
		# vec2.x = sin(heading), vec2.y = -cos(heading)
		# For heading formula atan2(x, -z), we need: x = sin(heading), -z = cos(heading)
		# So: x = vec2.x, z = -cos(heading) = vec2.y
		var direction_3d = Vector3(vec2.x, 0.0, vec2.y)
		var recovered_heading = CoordinateSystem.calculate_heading(direction_3d)
		
		# Should match within tolerance
		var diff = abs(recovered_heading - original_heading)
		# Handle wrap-around case (e.g., 359° vs 1°)
		if diff > 180.0:
			diff = 360.0 - diff
		
		assert_true(diff < 0.5, "Round-trip heading should match (iteration %d: original=%.2f, recovered=%.2f, diff=%.2f)" % [i, original_heading, recovered_heading, diff])

# Property 10: Forward direction from transform is consistent with heading
func test_property_forward_direction_heading_consistency():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(NUM_ITERATIONS):
		# Create transform with known yaw rotation
		var yaw_degrees = rng.randf_range(0.0, 360.0)
		var transform = Transform3D().rotated(Vector3.UP, deg_to_rad(yaw_degrees))
		
		# Get forward direction and calculate heading
		var forward_dir = CoordinateSystem.forward_direction_from_transform(transform)
		var heading = CoordinateSystem.calculate_heading(forward_dir)
		
		# In Godot's left-handed system, positive Y rotation is counter-clockwise (LEFT turn)
		# So a +90° rotation turns from North (0°) to West (270°), not East (90°)
		# The expected heading is 360° - yaw_degrees (inverted)
		var expected_heading = CoordinateSystem.normalize_heading(360.0 - yaw_degrees)
		
		# Heading should match the expected inverted rotation
		var diff = abs(heading - expected_heading)
		# Handle wrap-around
		if diff > 180.0:
			diff = 360.0 - diff
		
		assert_true(diff < 0.1, "Heading should match inverted yaw rotation (iteration %d: yaw=%.2f, heading=%.2f, expected=%.2f, diff=%.2f)" % [i, yaw_degrees, heading, expected_heading, diff])
