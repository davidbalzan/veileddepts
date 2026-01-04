extends Node
## Manual test for ProceduralDetailGenerator


func _ready():
	print("=== ProceduralDetailGenerator Manual Test ===")

	# Create generator
	var generator = ProceduralDetailGenerator.new()
	add_child(generator)

	# Test 1: Configuration values
	print("\n1. Testing configuration values:")
	print("  Detail scale: %.1f meters (expected: 30.0)" % generator.detail_scale)
	print("  Detail contribution: %.1f%% (expected: 50%%)" % (generator.detail_contribution * 100))
	print("  Flat terrain threshold: %.2f (expected: 0.05)" % generator.flat_terrain_threshold)
	print("  Flat terrain amplitude: %.1f meters (expected: 35.0)" % generator.flat_terrain_amplitude)
	print("  ✓ Configuration correct: %s" % (
		generator.detail_scale == 30.0 and 
		generator.detail_contribution == 0.5 and
		generator.flat_terrain_threshold == 0.05 and
		generator.flat_terrain_amplitude == 35.0
	))

	# Test 2: Generate detail
	print("\n2. Testing detail generation:")
	var base_map = Image.create(32, 32, false, Image.FORMAT_RF)
	for y in range(32):
		for x in range(32):
			var height = float(y) / 32.0
			base_map.set_pixel(x, y, Color(height, 0, 0, 1))

	var detail_map = generator.generate_detail(base_map, Vector2i(0, 0), 512.0)
	if detail_map:
		print("  ✓ Detail map generated: %dx%d" % [detail_map.get_width(), detail_map.get_height()])

		# Check that detail follows base
		var bottom_avg = 0.0
		var top_avg = 0.0
		for x in range(32):
			bottom_avg += detail_map.get_pixel(x, 0).r
			top_avg += detail_map.get_pixel(x, 31).r
		bottom_avg /= 32.0
		top_avg /= 32.0
		print("  Bottom average: %.3f, Top average: %.3f" % [bottom_avg, top_avg])
		print("  ✓ Detail preserves trend: %s" % (bottom_avg < top_avg))
	else:
		print("  ✗ Failed to generate detail map")

	# Test 3: Flat terrain detection
	print("\n3. Testing flat terrain detection:")
	var flat_map = Image.create(16, 16, false, Image.FORMAT_RF)
	for y in range(16):
		for x in range(16):
			flat_map.set_pixel(x, y, Color(0.5 + (float(x) / 16.0) * 0.02, 0, 0, 1))  # 2% variation
	
	var is_flat = generator.is_flat_terrain(flat_map)
	var stats = generator.get_heightmap_stats(flat_map)
	print("  Flat map range: %.4f" % stats.range)
	print("  ✓ Flat terrain detected: %s" % is_flat)

	# Test 4: Generate bump map
	print("\n4. Testing bump map generation:")
	var bump_map = generator.generate_bump_map(base_map, Vector2i(0, 0))
	if bump_map:
		print("  ✓ Bump map generated: %dx%d" % [bump_map.get_width(), bump_map.get_height()])
		print("  Format: %s" % bump_map.get_format())

		# Check a sample pixel
		var sample = bump_map.get_pixel(16, 16)
		print("  Sample normal (stored): (%.3f, %.3f, %.3f)" % [sample.r, sample.g, sample.b])
		print("  ✓ Normal Z component > 0.3: %s" % (sample.b > 0.3))
	else:
		print("  ✗ Failed to generate bump map")

	# Test 5: Consistency
	print("\n5. Testing consistency:")
	var detail_map1 = generator.generate_detail(base_map, Vector2i(5, 7), 512.0)
	var detail_map2 = generator.generate_detail(base_map, Vector2i(5, 7), 512.0)

	if detail_map1 and detail_map2:
		var matches = true
		for i in range(5):
			var x = i * 6
			var y = i * 6
			var p1 = detail_map1.get_pixel(x, y).r
			var p2 = detail_map2.get_pixel(x, y).r
			if abs(p1 - p2) > 0.0001:
				matches = false
				break
		print("  ✓ Same chunk coordinates produce identical detail: %s" % matches)
	else:
		print("  ✗ Failed to generate detail maps for consistency test")

	# Test 6: Flat terrain enhancement
	print("\n6. Testing flat terrain enhancement:")
	var enhanced_map = generator.generate_detail(flat_map, Vector2i(0, 0), 512.0)
	if enhanced_map:
		var input_stats = generator.get_heightmap_stats(flat_map)
		var output_stats = generator.get_heightmap_stats(enhanced_map)
		print("  Input range: %.4f" % input_stats.range)
		print("  Output range: %.4f" % output_stats.range)
		print("  ✓ Enhancement increased variation: %s" % (output_stats.range > input_stats.range))
	else:
		print("  ✗ Failed to generate enhanced detail map")

	print("\n=== All Tests Complete ===")
	get_tree().quit()
