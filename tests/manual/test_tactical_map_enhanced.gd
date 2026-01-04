extends SceneTree
## Test script to verify enhanced tactical map features


func _init():
	print("\n=== Enhanced Tactical Map Test ===\n")

	# Load the main scene
	var main_scene_path = "res://scenes/main.tscn"
	var main_scene_resource = load(main_scene_path)

	if not main_scene_resource:
		print("✗ Failed to load main scene")
		quit()
		return

	var main_scene = main_scene_resource.instantiate()
	root.add_child(main_scene)

	# Wait for initialization
	await create_timer(0.2).timeout

	# Get references
	var tactical_map = main_scene.get_node_or_null("TacticalMapView")

	if not tactical_map:
		print("✗ TacticalMapView not found")
		quit()
		return

	# Test 1: Verify increased map scale
	print("--- Test 1: Map Scale ---")
	print("Map scale: ", tactical_map.map_scale)
	if tactical_map.map_scale >= 0.5:
		print("✓ Map scale increased (was 0.1, now ", tactical_map.map_scale, ")")
		print("  Map is now 5x bigger")
	else:
		print("✗ Map scale not increased")

	# Test 2: Verify increased zoom range
	print("\n--- Test 2: Zoom Range ---")
	print("Min zoom: ", tactical_map.MIN_ZOOM)
	print("Max zoom: ", tactical_map.MAX_ZOOM)
	if tactical_map.MAX_ZOOM >= 10.0:
		print("✓ Max zoom increased to ", tactical_map.MAX_ZOOM, "x")
	else:
		print("✗ Max zoom not increased")

	# Test 3: Verify help overlay exists
	print("\n--- Test 3: Help Overlay ---")
	if tactical_map.help_overlay:
		print("✓ Help overlay created")
		print("  Initial visibility: ", tactical_map.help_overlay.visible)
		print("  Show help flag: ", tactical_map.show_help)

		# Test toggle
		tactical_map._toggle_help()
		print("  After toggle: ", tactical_map.show_help)

		if tactical_map.show_help:
			print("✓ Help toggle working")
		else:
			print("✗ Help toggle not working")

		# Toggle back
		tactical_map._toggle_help()
	else:
		print("✗ Help overlay not created")

	# Test 4: Verify recenter function
	print("\n--- Test 4: Recenter Function ---")
	# Set some pan offset
	tactical_map.map_pan_offset = Vector2(100, 200)
	tactical_map.map_zoom = 2.5
	print("Before recenter:")
	print("  Pan offset: ", tactical_map.map_pan_offset)
	print("  Zoom: ", tactical_map.map_zoom)

	tactical_map._on_recenter()
	print("After recenter:")
	print("  Pan offset: ", tactical_map.map_pan_offset)
	print("  Zoom: ", tactical_map.map_zoom)

	if tactical_map.map_pan_offset == Vector2.ZERO and tactical_map.map_zoom == 1.0:
		print("✓ Recenter function working")
	else:
		print("✗ Recenter function not working properly")

	# Test 5: Verify terrain visibility
	print("\n--- Test 5: Terrain Visibility ---")
	print("Terrain visible: ", tactical_map.show_terrain)
	if tactical_map.terrain_texture:
		print("✓ Terrain texture available")
		var texture_size = tactical_map.terrain_image.get_size()
		print("  Texture size: ", texture_size)
	else:
		print("⚠ Terrain texture not available (may not be initialized yet)")

	# Test 6: Calculate visible area
	print("\n--- Test 6: Visible Map Area ---")
	var screen_size = Vector2(1920, 1080)
	var visible_world_size = screen_size / (tactical_map.map_scale * tactical_map.map_zoom)
	print("At default zoom (1.0):")
	print("  Visible area: %.0f x %.0f meters" % [visible_world_size.x, visible_world_size.y])
	print("  (was 19200 x 10800 meters at scale 0.1)")

	# At max zoom
	var max_zoom_visible = screen_size / (tactical_map.map_scale * tactical_map.MAX_ZOOM)
	print("At max zoom (%.1fx):" % tactical_map.MAX_ZOOM)
	print("  Visible area: %.0f x %.0f meters" % [max_zoom_visible.x, max_zoom_visible.y])

	# At min zoom
	var min_zoom_visible = screen_size / (tactical_map.map_scale * tactical_map.MIN_ZOOM)
	print("At min zoom (%.1fx):" % tactical_map.MIN_ZOOM)
	print("  Visible area: %.0f x %.0f meters" % [min_zoom_visible.x, min_zoom_visible.y])

	# Test 7: Test coordinate conversion at new scale
	print("\n--- Test 7: Coordinate Conversion at New Scale ---")
	var test_positions = [Vector3(0, 0, 0), Vector3(1000, 0, 1000), Vector3(-1000, 0, -1000)]

	for world_pos in test_positions:
		var screen_pos = tactical_map.world_to_screen(world_pos)
		var back_to_world = tactical_map.screen_to_world(screen_pos)
		var error = world_pos.distance_to(back_to_world)

		if error < 1.0:
			print("✓ Position %s converts accurately" % world_pos)
		else:
			print("✗ Position %s has error: %.2f meters" % [world_pos, error])

	print("\n=== Test Complete ===")
	print("\nEnhancements Summary:")
	print("• Map is now 5x bigger (scale 0.5 vs 0.1)")
	print("• Max zoom increased to 10x (was 5x)")
	print("• F1 help overlay with all shortcuts")
	print("• Right mouse button panning added")
	print("• C key to recenter on submarine")
	print("• Better panning - doesn't auto-follow when exploring")
	print("\nTo test in-game:")
	print("1. Launch the game")
	print("2. Press '1' for Tactical Map")
	print("3. Press 'F1' to see help")
	print("4. Use mouse wheel to zoom")
	print("5. Right-click and drag to pan")
	print("6. Press 'C' to recenter")

	quit()
