extends SceneTree
## Quick test script to demonstrate submarine movement and terrain features
## Run this with: godot --headless --script test_submarine_movement.gd


func _init():
	print("\n=== Submarine Movement & Terrain Test ===\n")

	# Load the main scene
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)

	# Wait for initialization
	await root.process_frame
	await root.process_frame

	# Get references
	var submarine_body = main_scene.get_node_or_null("SubmarineBody")
	var submarine_physics = main_scene.get_node_or_null("SubmarinePhysics")
	var simulation_state = main_scene.get_node_or_null("SimulationState")
	var terrain_renderer = main_scene.get_node_or_null("TerrainRenderer")

	if not submarine_body:
		print("ERROR: Submarine body not found!")
		quit()
		return

	print("✓ Submarine initialized at position: ", submarine_body.global_position)
	print("✓ Submarine mass: ", submarine_body.mass / 1000.0, " tons")

	# Test 1: Set submarine speed and watch it move
	print("\n--- Test 1: Submarine Movement ---")
	if simulation_state:
		simulation_state.set_target_speed(5.0)  # 5 m/s forward
		simulation_state.set_target_heading(45.0)  # Northeast
		print("Set target speed: 5.0 m/s")
		print("Set target heading: 45°")

		# Simulate a few physics frames
		var initial_pos = submarine_body.global_position
		for i in range(60):  # 1 second at 60 FPS
			submarine_physics.update_physics(1.0 / 60.0)
			await root.process_frame

		var final_pos = submarine_body.global_position
		var distance_moved = initial_pos.distance_to(final_pos)
		print("Initial position: ", initial_pos)
		print("Final position: ", final_pos)
		print("Distance moved: %.2f meters" % distance_moved)

		if distance_moved > 0.1:
			print("✓ Submarine is moving!")
		else:
			print("✗ Submarine didn't move (might need more time)")

	# Test 2: Terrain height queries
	print("\n--- Test 2: Terrain System ---")
	if terrain_renderer and terrain_renderer.initialized:
		print("✓ Terrain initialized")
		print("  Size: ", terrain_renderer.terrain_size)
		print("  Resolution: ", terrain_renderer.terrain_resolution)
		print(
			(
				"  Height range: %.1f to %.1f meters"
				% [terrain_renderer.min_height, terrain_renderer.max_height]
			)
		)

		# Sample terrain heights at various positions
		var test_positions = [
			Vector2(0, 0), Vector2(100, 100), Vector2(-200, 300), Vector2(500, -500)
		]

		print("\n  Terrain heights at sample positions:")
		for pos in test_positions:
			var height = terrain_renderer.get_height_at(pos)
			print("    Position %s: %.2f meters" % [pos, height])

		# Check collision
		var sub_pos = submarine_body.global_position
		var terrain_height = terrain_renderer.get_height_at(Vector2(sub_pos.x, sub_pos.z))
		var is_colliding = terrain_renderer.check_collision(sub_pos)
		print("\n  Submarine position: ", sub_pos)
		print("  Terrain height below: %.2f meters" % terrain_height)
		print("  Collision detected: ", is_colliding)

	# Test 3: Show how to load elevation map
	print("\n--- Test 3: World Elevation Map ---")
	print("The world elevation map is available at: res://src_assets/World_elevation_map.png")
	print("To use it, you can:")
	print("  1. In the editor: Set TerrainRenderer properties:")
	print("     - use_external_heightmap = true")
	print("     - external_heightmap_path = 'res://src_assets/World_elevation_map.png'")
	print("     - heightmap_region = Rect2(0.25, 0.3, 0.1, 0.1)  # Mediterranean region")
	print("\n  2. Or call in code:")
	if terrain_renderer:
		print("     terrain_renderer.load_world_elevation_map(Rect2(0.25, 0.3, 0.1, 0.1))")
		print("\n  Available regions:")
		print("     - North Atlantic: Rect2(0.2, 0.2, 0.15, 0.15)")
		print("     - Pacific: Rect2(0.6, 0.3, 0.2, 0.2)")
		print("     - Caribbean: Rect2(0.15, 0.35, 0.1, 0.1)")
		print("     - Mediterranean: Rect2(0.25, 0.3, 0.1, 0.1)")

	print("\n=== Test Complete ===\n")
	quit()
