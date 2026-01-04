extends SceneTree
## Test script to verify terrain loading and safe spawn positioning


func _init():
	print("\n=== Terrain & Spawn Position Test ===\n")

	# Load the main scene
	var main_scene_path = "res://scenes/main.tscn"
	var main_scene_resource = load(main_scene_path)

	if not main_scene_resource:
		print("✗ Failed to load main scene")
		quit()
		return

	var main_scene = main_scene_resource.instantiate()
	root.add_child(main_scene)

	# Wait for terrain to initialize
	await create_timer(0.1).timeout
	await create_timer(0.1).timeout

	# Get references
	var terrain_renderer = main_scene.get_node_or_null("TerrainRenderer")
	var submarine_body = main_scene.get_node_or_null("SubmarineModel")

	if not terrain_renderer:
		print("✗ TerrainRenderer not found")
		quit()
		return

	if not submarine_body:
		print("✗ SubmarineModel not found")
		quit()
		return

	# Test 1: Verify terrain loaded with world elevation map
	print("--- Test 1: Terrain Configuration ---")
	if terrain_renderer.initialized:
		print("✓ Terrain initialized")
		print("  Using external heightmap: ", terrain_renderer.use_external_heightmap)
		print("  Heightmap path: ", terrain_renderer.external_heightmap_path)
		print("  Region: ", terrain_renderer.heightmap_region)
		print("  Micro detail enabled: ", terrain_renderer.enable_micro_detail)
		print("  Micro detail scale: %.2f meters" % terrain_renderer.micro_detail_scale)
		print(
			(
				"  Height range: %.1f to %.1f meters"
				% [terrain_renderer.min_height, terrain_renderer.max_height]
			)
		)
		print("  Sea level: %.1f meters" % terrain_renderer.sea_level)
	else:
		print("✗ Terrain not initialized")

	# Test 2: Sample terrain heights to verify micro detail
	print("\n--- Test 2: Terrain Height Sampling ---")
	var sample_positions = [
		Vector2(0, 0),
		Vector2(100, 100),
		Vector2(-100, -100),
		Vector2(200, -200),
		Vector2(-200, 200)
	]

	print("Sampling terrain heights (should show variation from micro detail):")
	for pos in sample_positions:
		var height = terrain_renderer.get_height_at(pos)
		var is_underwater = height < terrain_renderer.sea_level
		var status = "underwater" if is_underwater else "above water"
		print("  Position %s: %.2f meters (%s)" % [pos, height, status])

	# Test 3: Verify submarine spawn position
	print("\n--- Test 3: Submarine Spawn Position ---")
	var sub_pos = submarine_body.global_position
	var terrain_height = terrain_renderer.get_height_at(Vector2(sub_pos.x, sub_pos.z))
	var is_underwater = terrain_renderer.is_position_underwater(sub_pos)

	print("Submarine position: ", sub_pos)
	print("Terrain height below: %.2f meters" % terrain_height)
	print("Sea level: %.2f meters" % terrain_renderer.sea_level)
	print("Depth below sea level: %.2f meters" % (terrain_renderer.sea_level - sub_pos.y))
	print("Clearance above sea floor: %.2f meters" % (sub_pos.y - terrain_height))

	if is_underwater:
		print("✓ Submarine is safely underwater")
	else:
		print("✗ Submarine is NOT underwater!")

	if sub_pos.y > terrain_height + 5.0:
		print("✓ Submarine has safe clearance above sea floor")
	else:
		print("✗ Submarine is too close to sea floor!")

	# Test 4: Test safe spawn position finder
	print("\n--- Test 4: Safe Spawn Position Finder ---")
	var test_positions = [Vector3(0, 0, 0), Vector3(500, 0, 500), Vector3(-500, 0, -500)]

	for test_pos in test_positions:
		var safe_pos = terrain_renderer.find_safe_spawn_position(test_pos, 1000.0, -50.0)
		var safe_terrain_height = terrain_renderer.get_height_at(Vector2(safe_pos.x, safe_pos.z))
		print("  Test position %s:" % test_pos)
		print("    Safe spawn: %s" % safe_pos)
		print("    Terrain height: %.2f meters" % safe_terrain_height)
		print("    Depth: %.2f meters below sea level" % (terrain_renderer.sea_level - safe_pos.y))
		print("    Clearance: %.2f meters above sea floor" % (safe_pos.y - safe_terrain_height))

	# Test 5: Verify micro detail variation
	print("\n--- Test 5: Micro Detail Verification ---")
	if terrain_renderer.enable_micro_detail:
		# Sample very close positions to see micro detail
		var base_pos = Vector2(100, 100)
		var heights = []
		for i in range(5):
			var offset = Vector2(i * 2.0, 0)  # 2 meter spacing
			var height = terrain_renderer.get_height_at(base_pos + offset)
			heights.append(height)

		print("Heights at 2-meter intervals (should show small variations):")
		for i in range(heights.size()):
			print("  %d meters: %.3f meters" % [i * 2, heights[i]])

		# Calculate variation
		var min_h = heights.min()
		var max_h = heights.max()
		var variation = max_h - min_h
		print("  Height variation: %.3f meters" % variation)

		if variation > 0.01 and variation < 10.0:
			print("✓ Micro detail is working (subtle height variations present)")
		elif variation < 0.01:
			print("⚠ Very little variation detected (might be flat area)")
		else:
			print("⚠ Large variation detected (%.3f meters)" % variation)
	else:
		print("Micro detail is disabled")

	print("\n=== Test Complete ===\n")
	quit()
