extends Node
## Manual test for ProceduralDetailGenerator


func _ready():
	print("=== ProceduralDetailGenerator Manual Test ===")

	# Create generator
	var generator = ProceduralDetailGenerator.new()
	add_child(generator)

	# Test 1: Amplitude calculation
	print("\n1. Testing amplitude calculation:")
	var amp_0 = generator.calculate_amplitude(0.0)
	var amp_50 = generator.calculate_amplitude(50.0)
	var amp_100 = generator.calculate_amplitude(100.0)
	print("  Amplitude at 0m: %.3f" % amp_0)
	print("  Amplitude at 50m: %.3f" % amp_50)
	print("  Amplitude at 100m: %.3f" % amp_100)
	print("  ✓ Amplitude decreases with distance: %s" % (amp_0 > amp_50 and amp_50 > amp_100))

	# Test 2: Generate detail
	print("\n2. Testing detail generation:")
	var base_map = Image.create(32, 32, false, Image.FORMAT_RF)
	for y in range(32):
		for x in range(32):
			var height = float(y) / 32.0
			base_map.set_pixel(x, y, Color(height, 0, 0, 1))

	var detail_map = generator.generate_detail(base_map, Vector2i(0, 0), 50.0)
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

	# Test 3: Generate bump map
	print("\n3. Testing bump map generation:")
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

	# Test 4: Consistency
	print("\n4. Testing consistency:")
	var detail_map1 = generator.generate_detail(base_map, Vector2i(5, 7), 50.0)
	var detail_map2 = generator.generate_detail(base_map, Vector2i(5, 7), 50.0)

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

	print("\n=== All Tests Complete ===")
	get_tree().quit()
