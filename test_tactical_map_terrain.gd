extends SceneTree
## Test script to verify tactical map terrain visualization

func _init():
	print("\n=== Tactical Map Terrain Visualization Test ===\n")
	
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
	var terrain_renderer = main_scene.get_node_or_null("TerrainRenderer")
	var tactical_map = main_scene.get_node_or_null("TacticalMapView")
	var view_manager = main_scene.get_node_or_null("ViewManager")
	
	if not terrain_renderer:
		print("✗ TerrainRenderer not found")
		quit()
		return
	
	if not tactical_map:
		print("✗ TacticalMapView not found")
		quit()
		return
	
	# Test 1: Verify terrain renderer is initialized
	print("--- Test 1: Terrain Renderer ---")
	if terrain_renderer.initialized:
		print("✓ Terrain renderer initialized")
		print("  Heightmap size: ", terrain_renderer.heightmap.get_width(), "x", terrain_renderer.heightmap.get_height())
		print("  Terrain size: ", terrain_renderer.terrain_size)
		print("  Height range: %.1f to %.1f meters" % [terrain_renderer.min_height, terrain_renderer.max_height])
	else:
		print("✗ Terrain renderer not initialized")
	
	# Test 2: Verify tactical map has terrain reference
	print("\n--- Test 2: Tactical Map Terrain Integration ---")
	if tactical_map.terrain_renderer:
		print("✓ Tactical map has terrain renderer reference")
	else:
		print("✗ Tactical map missing terrain renderer reference")
	
	if tactical_map.terrain_texture:
		print("✓ Terrain texture generated")
		print("  Texture size: ", tactical_map.terrain_image.get_width(), "x", tactical_map.terrain_image.get_height())
	else:
		print("✗ Terrain texture not generated")
	
	print("  Terrain visibility: ", tactical_map.show_terrain)
	
	# Test 3: Sample terrain colors at various positions
	print("\n--- Test 3: Terrain Color Sampling ---")
	if tactical_map.terrain_image:
		var sample_positions = [
			Vector2i(64, 64),
			Vector2i(128, 128),
			Vector2i(192, 192),
			Vector2i(32, 200)
		]
		
		print("Sampling terrain colors (should show variation):")
		for pos in sample_positions:
			if pos.x < tactical_map.terrain_image.get_width() and pos.y < tactical_map.terrain_image.get_height():
				var color = tactical_map.terrain_image.get_pixel(pos.x, pos.y)
				var brightness = (color.r + color.g + color.b) / 3.0
				var color_desc = "water" if color.b > 0.3 else "land"
				print("  Position %s: RGB(%.2f, %.2f, %.2f) - %s" % [pos, color.r, color.g, color.b, color_desc])
	
	# Test 4: Verify world-to-screen conversion with terrain
	print("\n--- Test 4: Coordinate Conversion ---")
	var test_world_positions = [
		Vector3(0, 0, 0),
		Vector3(500, 0, 500),
		Vector3(-500, 0, -500)
	]
	
	for world_pos in test_world_positions:
		var screen_pos = tactical_map.world_to_screen(world_pos)
		var back_to_world = tactical_map.screen_to_world(screen_pos)
		var error = world_pos.distance_to(back_to_world)
		
		print("  World %s → Screen %s → World %s (error: %.2f)" % [world_pos, screen_pos, back_to_world, error])
		
		if error < 1.0:
			print("    ✓ Conversion accurate")
		else:
			print("    ✗ Conversion error too large")
	
	# Test 5: Verify terrain rendering bounds
	print("\n--- Test 5: Terrain Rendering Bounds ---")
	var terrain_size = terrain_renderer.terrain_size
	var half_size_x = terrain_size.x / 2.0
	var half_size_y = terrain_size.y / 2.0
	
	var corners = [
		Vector3(-half_size_x, 0, -half_size_y),
		Vector3(half_size_x, 0, -half_size_y),
		Vector3(-half_size_x, 0, half_size_y),
		Vector3(half_size_x, 0, half_size_y)
	]
	
	print("Terrain corners in screen space:")
	for i in range(corners.size()):
		var corner_name = ["Top-Left", "Top-Right", "Bottom-Left", "Bottom-Right"][i]
		var screen_pos = tactical_map.world_to_screen(corners[i])
		print("  %s: World %s → Screen %s" % [corner_name, corners[i], screen_pos])
	
	# Test 6: Toggle terrain visibility
	print("\n--- Test 6: Terrain Toggle ---")
	print("Initial terrain visibility: ", tactical_map.show_terrain)
	tactical_map._on_terrain_toggle()
	print("After toggle: ", tactical_map.show_terrain)
	tactical_map._on_terrain_toggle()
	print("After second toggle: ", tactical_map.show_terrain)
	
	if tactical_map.show_terrain:
		print("✓ Terrain toggle working correctly")
	else:
		print("✗ Terrain toggle not working as expected")
	
	print("\n=== Test Complete ===")
	print("\nTo view the tactical map with terrain:")
	print("1. Run the game normally")
	print("2. Press '1' to switch to Tactical Map view")
	print("3. Press 'T' to toggle terrain visibility")
	print("4. Use mouse wheel to zoom in/out")
	print("5. Middle mouse button to pan")
	
	quit()
