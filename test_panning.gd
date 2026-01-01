extends SceneTree
## Test script to verify panning works correctly

func _init():
	print("\n=== Panning Test ===\n")
	
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
	
	# Test 1: Submarine at origin
	print("--- Test 1: Submarine Position ---")
	var sub_pos = simulation_state.submarine_position
	print("Submarine world position: ", sub_pos)
	
	var sub_screen = tactical_map.world_to_screen(sub_pos)
	print("Submarine screen position: ", sub_screen)
	print("Map center: ", tactical_map.map_center)
	
	if sub_screen.distance_to(tactical_map.map_center) < 1.0:
		print("✓ Submarine is at screen center (no pan)")
	else:
		print("✗ Submarine not at center, distance: ", sub_screen.distance_to(tactical_map.map_center))
	
	# Test 2: Point 100m north of submarine
	print("\n--- Test 2: Relative Positioning ---")
	var north_point = Vector3(sub_pos.x, sub_pos.y, sub_pos.z - 100)  # -Z is north
	var north_screen = tactical_map.world_to_screen(north_point)
	
	print("Point 100m north: ", north_point)
	print("Screen position: ", north_screen)
	print("Expected: above center (y < 540)")
	
	if north_screen.y < tactical_map.map_center.y:
		print("✓ North point is above center")
	else:
		print("✗ North point positioning wrong")
	
	# Test 3: Apply pan offset
	print("\n--- Test 3: Pan Offset ---")
	tactical_map.map_pan_offset = Vector2(100, 50)
	print("Applied pan offset: ", tactical_map.map_pan_offset)
	
	var sub_screen_panned = tactical_map.world_to_screen(sub_pos)
	print("Submarine screen position after pan: ", sub_screen_panned)
	print("Expected: (1060, 590) = center + offset")
	
	var expected = tactical_map.map_center + tactical_map.map_pan_offset
	if sub_screen_panned.distance_to(expected) < 1.0:
		print("✓ Pan offset applied correctly")
	else:
		print("✗ Pan offset not working, expected: ", expected)
	
	# Test 4: Terrain should move with pan
	print("\n--- Test 4: Terrain Movement ---")
	var terrain_origin = Vector3(0, 0, 0)
	var terrain_screen_no_pan = tactical_map.world_to_screen(terrain_origin)
	print("Terrain origin with pan: ", terrain_screen_no_pan)
	
	# Reset pan
	tactical_map.map_pan_offset = Vector2.ZERO
	var terrain_screen_reset = tactical_map.world_to_screen(terrain_origin)
	print("Terrain origin without pan: ", terrain_screen_reset)
	
	var movement = terrain_screen_no_pan - terrain_screen_reset
	print("Movement from pan: ", movement)
	
	if movement.length() > 50:
		print("✓ Terrain moves with pan offset")
	else:
		print("✗ Terrain not moving with pan")
	
	# Test 5: Screen to world conversion
	print("\n--- Test 5: Screen to World Conversion ---")
	tactical_map.map_pan_offset = Vector2.ZERO
	
	var test_screen = Vector2(1060, 640)  # 100 pixels right, 100 pixels down from center
	var world_pos = tactical_map.screen_to_world(test_screen)
	print("Screen position: ", test_screen)
	print("World position: ", world_pos)
	
	# At scale 0.5, 100 pixels = 200 meters
	var expected_offset = 100.0 / (tactical_map.map_scale * tactical_map.map_zoom)
	print("Expected offset from submarine: ~", expected_offset, " meters")
	
	var actual_offset = Vector2(world_pos.x - sub_pos.x, world_pos.z - sub_pos.z)
	print("Actual offset: ", actual_offset)
	
	if abs(actual_offset.x - expected_offset) < 1.0 and abs(actual_offset.y - expected_offset) < 1.0:
		print("✓ Screen to world conversion correct")
	else:
		print("✗ Screen to world conversion incorrect")
	
	# Test 6: Round trip conversion
	print("\n--- Test 6: Round Trip Conversion ---")
	tactical_map.map_pan_offset = Vector2(50, -30)
	
	var test_world = Vector3(sub_pos.x + 500, 0, sub_pos.z - 300)
	var to_screen = tactical_map.world_to_screen(test_world)
	var back_to_world = tactical_map.screen_to_world(to_screen)
	
	print("Original world: ", test_world)
	print("To screen: ", to_screen)
	print("Back to world: ", back_to_world)
	
	var error = test_world.distance_to(back_to_world)
	print("Round trip error: ", error, " meters")
	
	if error < 1.0:
		print("✓ Round trip conversion accurate")
	else:
		print("✗ Round trip error too large")
	
	print("\n=== Test Complete ===")
	print("\nPanning should now work correctly:")
	print("• Submarine stays at center by default")
	print("• Pan offset moves the view, not the canvas")
	print("• Terrain moves with the view")
	print("• All elements pan together")
	
	quit()
