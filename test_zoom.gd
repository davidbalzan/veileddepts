extends SceneTree
## Test script to verify zoom works correctly


func _init():
	print("\n=== Zoom Test ===\n")

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
	var simulation_state = main_scene.get_node_or_null("SimulationState")

	if not tactical_map:
		print("✗ TacticalMapView not found")
		quit()
		return

	if not simulation_state:
		print("✗ SimulationState not found")
		quit()
		return

	# Test 1: Basic zoom
	print("--- Test 1: Basic Zoom ---")
	print("Initial zoom: ", tactical_map.map_zoom)

	tactical_map._handle_zoom(2.0)
	print("After 2x zoom: ", tactical_map.map_zoom)

	if abs(tactical_map.map_zoom - 2.0) < 0.01:
		print("✓ Basic zoom working")
	else:
		print("✗ Basic zoom not working")

	# Reset
	tactical_map.map_zoom = 1.0
	tactical_map.map_pan_offset = Vector2.ZERO

	# Test 2: Zoom limits
	print("\n--- Test 2: Zoom Limits ---")
	tactical_map._handle_zoom(0.01)  # Try to zoom way out
	print("Min zoom attempt: ", tactical_map.map_zoom)

	if tactical_map.map_zoom >= tactical_map.MIN_ZOOM:
		print("✓ Min zoom limit working (", tactical_map.MIN_ZOOM, ")")
	else:
		print("✗ Min zoom limit not working")

	tactical_map.map_zoom = 1.0
	tactical_map._handle_zoom(100.0)  # Try to zoom way in
	print("Max zoom attempt: ", tactical_map.map_zoom)

	if tactical_map.map_zoom <= tactical_map.MAX_ZOOM:
		print("✓ Max zoom limit working (", tactical_map.MAX_ZOOM, ")")
	else:
		print("✗ Max zoom limit not working")

	# Reset
	tactical_map.map_zoom = 1.0
	tactical_map.map_pan_offset = Vector2.ZERO

	# Test 3: Zoom toward mouse position
	print("\n--- Test 3: Zoom Toward Mouse ---")
	var sub_pos = simulation_state.submarine_position

	# Point 500m east of submarine
	var east_point = Vector3(sub_pos.x + 500, 0, sub_pos.z)
	var east_screen = tactical_map.world_to_screen(east_point)

	print("Point 500m east at screen: ", east_screen)
	print("Before zoom - pan offset: ", tactical_map.map_pan_offset)

	# Zoom in toward that point
	tactical_map._handle_zoom(2.0, east_screen)

	print("After 2x zoom toward point:")
	print("  Zoom: ", tactical_map.map_zoom)
	print("  Pan offset: ", tactical_map.map_pan_offset)

	# The point should still be at roughly the same screen position
	var east_screen_after = tactical_map.world_to_screen(east_point)
	print("  Point now at screen: ", east_screen_after)

	var screen_delta = east_screen.distance_to(east_screen_after)
	print("  Screen position delta: ", screen_delta, " pixels")

	if screen_delta < 50.0:  # Allow some tolerance
		print("✓ Zoom toward mouse working (point stayed near cursor)")
	else:
		print("⚠ Zoom toward mouse may need adjustment (delta: ", screen_delta, ")")

	# Reset
	tactical_map.map_zoom = 1.0
	tactical_map.map_pan_offset = Vector2.ZERO

	# Test 4: Visible area calculation
	print("\n--- Test 4: Visible Area at Different Zooms ---")
	var screen_size = Vector2(1920, 1080)

	var zooms = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
	for zoom in zooms:
		tactical_map.map_zoom = zoom
		var visible_size = screen_size / (tactical_map.map_scale * zoom)
		print("Zoom %.1fx: %.0f x %.0f meters visible" % [zoom, visible_size.x, visible_size.y])

	# Test 5: Submarine icon size at different zooms
	print("\n--- Test 5: Icon Sizes ---")
	print("Submarine icon size: ", tactical_map.SUBMARINE_ICON_SIZE, " pixels (constant)")
	print("Contact icon size: ", tactical_map.CONTACT_ICON_SIZE, " pixels (constant)")
	print(
		"Note: Icons stay same pixel size, but represent different world sizes at different zooms"
	)

	var icon_world_sizes = []
	for zoom in [1.0, 2.0, 5.0, 10.0]:
		var world_size = tactical_map.SUBMARINE_ICON_SIZE / (tactical_map.map_scale * zoom)
		icon_world_sizes.append("%.1fm at %dx zoom" % [world_size, zoom])

	print("Submarine icon represents:")
	for size in icon_world_sizes:
		print("  ", size)

	# Test 6: Multiple zoom steps
	print("\n--- Test 6: Multiple Zoom Steps ---")
	tactical_map.map_zoom = 1.0
	tactical_map.map_pan_offset = Vector2.ZERO

	print("Starting zoom: ", tactical_map.map_zoom)

	# Zoom in 5 times
	for i in range(5):
		tactical_map._handle_zoom(1.2)

	print("After 5x zoom in (1.2x each): ", tactical_map.map_zoom)
	print("Expected: ~", pow(1.2, 5), "x")

	# Zoom out 5 times
	for i in range(5):
		tactical_map._handle_zoom(0.833)  # ~1/1.2

	print("After 5x zoom out: ", tactical_map.map_zoom)
	print("Should be back near 1.0x")

	if abs(tactical_map.map_zoom - 1.0) < 0.1:
		print("✓ Multiple zoom steps working")
	else:
		print("⚠ Zoom accumulation may have drift")

	print("\n=== Test Complete ===")
	print("\nZoom Behavior:")
	print("• Mouse wheel zooms in/out")
	print("• Zoom is centered on mouse cursor position")
	print("• Zoom range: 0.1x to 10.0x")
	print("• Icons stay same pixel size")
	print("• More zoom = more detail, less area visible")
	print("\nTo test in-game:")
	print("1. Launch game and press '1' for Tactical Map")
	print("2. Move mouse over terrain feature")
	print("3. Scroll mouse wheel up to zoom in")
	print("4. Feature under cursor should stay under cursor")
	print("5. Scroll down to zoom out")

	quit()
