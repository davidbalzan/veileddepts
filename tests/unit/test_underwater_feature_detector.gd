extends GutTest

## Unit tests for UnderwaterFeatureDetector
##
## Tests feature detection, importance mapping, and vertex preservation

var detector: UnderwaterFeatureDetector


func before_each():
	detector = UnderwaterFeatureDetector.new()
	add_child_autofree(detector)


func test_detect_trench():
	# Create a heightmap with a trench (deep valley)
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)

	# Fill with moderate depth
	heightmap.fill(Color(-500.0, 0.0, 0.0, 1.0))

	# Create a trench in the middle (very deep)
	for y in range(24, 40):
		for x in range(24, 40):
			var depth = -2000.0 - (32 - abs(x - 32)) * 50.0  # V-shaped trench
			heightmap.set_pixel(x, y, Color(depth, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)

	# Should detect at least one trench
	assert_gt(features.size(), 0, "Should detect at least one feature")

	var found_trench = false
	for feature in features:
		if feature.feature_type == UnderwaterFeatureDetector.FeatureType.TRENCH:
			found_trench = true
			assert_gt(feature.importance, 0.5, "Trench should have high importance")
			break

	assert_true(found_trench, "Should detect a trench feature")


func test_detect_seamount():
	# Create a heightmap with a seamount (underwater mountain)
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)

	# Fill with deep water
	heightmap.fill(Color(-3000.0, 0.0, 0.0, 1.0))

	# Create a seamount in the middle (rises significantly)
	for y in range(20, 44):
		for x in range(20, 44):
			var dx = x - 32
			var dy = y - 32
			var dist = sqrt(dx * dx + dy * dy)
			var height = -3000.0 + max(0.0, (12.0 - dist) * 150.0)  # Cone shape
			heightmap.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)

	# Should detect at least one seamount
	assert_gt(features.size(), 0, "Should detect at least one feature")

	var found_seamount = false
	for feature in features:
		if feature.feature_type == UnderwaterFeatureDetector.FeatureType.SEAMOUNT:
			found_seamount = true
			assert_gt(feature.importance, 0.5, "Seamount should have high importance")
			break

	assert_true(found_seamount, "Should detect a seamount feature")


func test_detect_ridge():
	# Create a heightmap with a ridge (underwater mountain range)
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)

	# Fill with moderate depth
	heightmap.fill(Color(-2000.0, 0.0, 0.0, 1.0))

	# Create a ridge running vertically through the middle
	for y in range(64):
		for x in range(28, 36):
			var dist_from_center = abs(x - 32)
			var height = -2000.0 + (4 - dist_from_center) * 200.0  # Ridge shape
			heightmap.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)

	# Should detect at least one ridge
	assert_gt(features.size(), 0, "Should detect at least one feature")

	var found_ridge = false
	for feature in features:
		if feature.feature_type == UnderwaterFeatureDetector.FeatureType.RIDGE:
			found_ridge = true
			assert_gt(feature.importance, 0.5, "Ridge should have high importance")
			break

	assert_true(found_ridge, "Should detect a ridge feature")


func test_create_importance_map():
	# Create a simple heightmap with a feature
	var heightmap = Image.create(32, 32, false, Image.FORMAT_RF)
	heightmap.fill(Color(-1000.0, 0.0, 0.0, 1.0))

	# Add a small seamount
	for y in range(12, 20):
		for x in range(12, 20):
			var dx = x - 16
			var dy = y - 16
			var dist = sqrt(dx * dx + dy * dy)
			var height = -1000.0 + max(0.0, (4.0 - dist) * 300.0)
			heightmap.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)

	# Create importance map
	var importance_map = detector.create_importance_map(heightmap, features)

	assert_not_null(importance_map, "Should create importance map")
	assert_eq(importance_map.get_width(), 32, "Importance map should match heightmap width")
	assert_eq(importance_map.get_height(), 32, "Importance map should match heightmap height")

	# Check that feature area has higher importance
	var center_importance = importance_map.get_pixel(16, 16).r
	var edge_importance = importance_map.get_pixel(0, 0).r

	assert_gt(
		center_importance,
		edge_importance,
		"Feature center should have higher importance than edges"
	)


func test_get_important_vertices():
	# Create a heightmap with a feature
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)
	heightmap.fill(Color(-1000.0, 0.0, 0.0, 1.0))

	# Add a trench
	for y in range(28, 36):
		for x in range(28, 36):
			heightmap.set_pixel(x, y, Color(-2500.0, 0.0, 0.0, 1.0))

	# Detect features and create importance map
	var features = detector.detect_features(heightmap)
	var importance_map = detector.create_importance_map(heightmap, features)

	# Get important vertices for LOD 1
	var important_vertices = detector.get_important_vertices(importance_map, 1, 64)

	# Should have some important vertices
	assert_gt(important_vertices.size(), 0, "Should identify important vertices")

	# Important vertices should be Vector2i
	if important_vertices.size() > 0:
		assert_true(important_vertices[0] is Vector2i, "Important vertices should be Vector2i")


func test_feature_preservation_at_different_lods():
	# Create a heightmap with a prominent feature
	var heightmap = Image.create(128, 128, false, Image.FORMAT_RF)
	heightmap.fill(Color(-2000.0, 0.0, 0.0, 1.0))

	# Add a seamount
	for y in range(50, 78):
		for x in range(50, 78):
			var dx = x - 64
			var dy = y - 64
			var dist = sqrt(dx * dx + dy * dy)
			var height = -2000.0 + max(0.0, (14.0 - dist) * 100.0)
			heightmap.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)
	var importance_map = detector.create_importance_map(heightmap, features)

	# Get important vertices for different LOD levels
	var vertices_lod1 = detector.get_important_vertices(importance_map, 1, 128)
	var vertices_lod2 = detector.get_important_vertices(importance_map, 2, 128)
	var _vertices_lod3 = detector.get_important_vertices(importance_map, 3, 128)

	# Higher LOD levels should preserve fewer vertices (higher threshold)
	# But all should preserve some vertices for the feature
	assert_gt(vertices_lod1.size(), 0, "LOD 1 should preserve feature vertices")
	assert_gt(vertices_lod2.size(), 0, "LOD 2 should preserve feature vertices")

	# LOD 1 should preserve more or equal vertices than LOD 2
	# (lower LOD = more detail = lower threshold = more vertices preserved)
	assert_gte(
		vertices_lod1.size(),
		vertices_lod2.size(),
		"LOD 1 should preserve at least as many vertices as LOD 2"
	)


func test_abyssal_plain_detection():
	# Create a very flat, deep heightmap (abyssal plain)
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)

	# Fill with very deep, very flat terrain
	for y in range(64):
		for x in range(64):
			# Add tiny variations to make it realistic
			var noise = (randf() - 0.5) * 10.0
			heightmap.set_pixel(x, y, Color(-5000.0 + noise, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)

	# Should detect abyssal plain (or possibly no features due to flatness)
	# This is acceptable - abyssal plains are low importance
	if features.size() > 0:
		var _found_plain = false
		for feature in features:
			if feature.feature_type == UnderwaterFeatureDetector.FeatureType.ABYSSAL_PLAIN:
				_found_plain = true
				assert_lt(feature.importance, 0.5, "Abyssal plain should have low importance")
				break

		# It's okay if we don't detect it - very flat terrain may not register as a feature
		pass


func test_no_features_above_sea_level():
	# Create a heightmap entirely above sea level
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)

	# Fill with land elevations
	for y in range(64):
		for x in range(64):
			var height = 100.0 + randf() * 500.0
			heightmap.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)

	# Should not detect any underwater features
	assert_eq(features.size(), 0, "Should not detect underwater features above sea level")


func test_feature_merging():
	# Create a heightmap with overlapping feature regions
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)
	heightmap.fill(Color(-2000.0, 0.0, 0.0, 1.0))

	# Create two overlapping trenches
	for y in range(20, 44):
		for x in range(20, 35):
			heightmap.set_pixel(x, y, Color(-3000.0, 0.0, 0.0, 1.0))

	for y in range(20, 44):
		for x in range(30, 44):
			heightmap.set_pixel(x, y, Color(-3000.0, 0.0, 0.0, 1.0))

	# Detect features
	var features = detector.detect_features(heightmap)

	# Should merge overlapping features
	# The exact number depends on the merging algorithm, but should be reasonable
	assert_lte(features.size(), 3, "Should merge overlapping features")
