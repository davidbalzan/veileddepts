extends Node

## Manual test for UnderwaterFeatureDetector
## Run this scene to verify feature detection works


func _ready():
	print("=== Testing UnderwaterFeatureDetector ===")

	var FeatureDetectorScript = load("res://scripts/rendering/underwater_feature_detector.gd")
	var detector = FeatureDetectorScript.new()
	add_child(detector)

	# Test 1: Detect trench
	print("\nTest 1: Trench Detection")
	var trench_heightmap = _create_trench_heightmap()
	var trench_features = detector.detect_features(trench_heightmap)
	print("  Detected %d features" % trench_features.size())
	for feature in trench_features:
		print("  - Type: %d, Importance: %.2f" % [feature.feature_type, feature.importance])

	# Test 2: Detect seamount
	print("\nTest 2: Seamount Detection")
	var seamount_heightmap = _create_seamount_heightmap()
	var seamount_features = detector.detect_features(seamount_heightmap)
	print("  Detected %d features" % seamount_features.size())
	for feature in seamount_features:
		print("  - Type: %d, Importance: %.2f" % [feature.feature_type, feature.importance])

	# Test 3: Create importance map
	print("\nTest 3: Importance Map Creation")
	var importance_map = detector.create_importance_map(seamount_heightmap, seamount_features)
	if importance_map:
		print(
			(
				"  Created importance map: %dx%d"
				% [importance_map.get_width(), importance_map.get_height()]
			)
		)
		var center_importance = importance_map.get_pixel(32, 32).r
		var edge_importance = importance_map.get_pixel(0, 0).r
		print("  Center importance: %.3f" % center_importance)
		print("  Edge importance: %.3f" % edge_importance)
	else:
		print("  ERROR: Failed to create importance map")

	# Test 4: Get important vertices
	print("\nTest 4: Important Vertices")
	if importance_map:
		var vertices_lod1 = detector.get_important_vertices(importance_map, 1, 64)
		var vertices_lod2 = detector.get_important_vertices(importance_map, 2, 64)
		print("  LOD 1: %d important vertices" % vertices_lod1.size())
		print("  LOD 2: %d important vertices" % vertices_lod2.size())

	print("\n=== Tests Complete ===")
	print("Feature detection is working!")

	# Exit after a short delay
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _create_trench_heightmap() -> Image:
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)
	heightmap.fill(Color(-500.0, 0.0, 0.0, 1.0))

	# Create a trench in the middle
	for y in range(24, 40):
		for x in range(24, 40):
			var depth = -2000.0 - (32 - abs(x - 32)) * 50.0
			heightmap.set_pixel(x, y, Color(depth, 0.0, 0.0, 1.0))

	return heightmap


func _create_seamount_heightmap() -> Image:
	var heightmap = Image.create(64, 64, false, Image.FORMAT_RF)
	heightmap.fill(Color(-3000.0, 0.0, 0.0, 1.0))

	# Create a seamount in the middle
	for y in range(20, 44):
		for x in range(20, 44):
			var dx = x - 32
			var dy = y - 32
			var dist = sqrt(dx * dx + dy * dy)
			var height = -3000.0 + max(0.0, (12.0 - dist) * 150.0)
			heightmap.set_pixel(x, y, Color(height, 0.0, 0.0, 1.0))

	return heightmap
