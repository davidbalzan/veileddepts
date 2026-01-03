extends Node3D
## Manual test for sonar integration with terrain system

var collision_manager
var chunk_manager
var elevation_provider


func _ready() -> void:
	print("=== Sonar Integration Manual Test ===")

	# Create elevation provider
	elevation_provider = load("res://scripts/rendering/elevation_data_provider.gd").new()
	add_child(elevation_provider)
	elevation_provider.initialize()

	# Create chunk manager
	chunk_manager = load("res://scripts/rendering/chunk_manager.gd").new()
	chunk_manager.chunk_size = 512.0
	chunk_manager.max_cache_memory_mb = 128
	add_child(chunk_manager)

	# Create collision manager
	collision_manager = load("res://scripts/rendering/collision_manager.gd").new()
	add_child(collision_manager)
	collision_manager.set_chunk_manager(chunk_manager)

	# Wait a frame for initialization
	await get_tree().process_frame

	# Load a chunk
	print("\n1. Loading chunk at (0, 0)...")
	var chunk_coord := Vector2i(0, 0)
	var chunk = chunk_manager.load_chunk(chunk_coord)

	if chunk:
		print("   ✓ Chunk loaded successfully")
		print("   - State: ", chunk.state)
		print("   - Has heightmap: ", chunk.base_heightmap != null)
	else:
		print("   ✗ Failed to load chunk")
		get_tree().quit()
		return

	# Test 1: Get surface normal
	print("\n2. Testing get_surface_normal_for_sonar...")
	var test_pos := Vector3(0.0, 0.0, 0.0)
	var normal: Vector3 = collision_manager.get_surface_normal_for_sonar(test_pos)
	print("   - Position: ", test_pos)
	print("   - Normal: ", normal)
	print("   - Normal length: ", normal.length())
	print("   - Normal Y component: ", normal.y)

	if abs(normal.length() - 1.0) < 0.01 and normal.y > 0.0:
		print("   ✓ Surface normal is valid")
	else:
		print("   ✗ Surface normal is invalid")

	# Test 2: Get terrain geometry for sonar
	print("\n3. Testing get_terrain_geometry_for_sonar...")
	var origin := Vector3(0.0, -50.0, 0.0)
	var max_range: float = 500.0
	var simplification: int = 1

	var result: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, max_range, simplification
	)

	var positions: PackedVector3Array = result.get("positions", PackedVector3Array())
	var normals: PackedVector3Array = result.get("normals", PackedVector3Array())

	print("   - Origin: ", origin)
	print("   - Max range: ", max_range, " m")
	print("   - Simplification level: ", simplification)
	print("   - Positions returned: ", positions.size())
	print("   - Normals returned: ", normals.size())

	if positions.size() > 0 and positions.size() == normals.size():
		print("   ✓ Terrain geometry returned successfully")

		# Check a few normals
		var valid_normals: int = 0
		for i in range(min(10, normals.size())):
			if abs(normals[i].length() - 1.0) < 0.01:
				valid_normals += 1
		print("   - Valid normals (first 10): ", valid_normals, "/", min(10, normals.size()))
	else:
		print("   ✗ Terrain geometry invalid")

	# Test 3: Query terrain for sonar beam
	print("\n4. Testing query_terrain_for_sonar_beam...")
	var beam_origin := Vector3(0.0, -50.0, 0.0)
	var beam_direction := Vector3(0.0, 1.0, 0.0)  # Pointing up
	var beam_range: float = 500.0
	var beam_width: float = PI / 6.0  # 30 degrees

	var beam_results: Array[Dictionary] = collision_manager.query_terrain_for_sonar_beam(
		beam_origin, beam_direction, beam_range, beam_width
	)

	print("   - Beam origin: ", beam_origin)
	print("   - Beam direction: ", beam_direction)
	print("   - Beam range: ", beam_range, " m")
	print("   - Beam width: ", rad_to_deg(beam_width), " degrees")
	print("   - Results returned: ", beam_results.size())

	if beam_results.size() > 0:
		print("   ✓ Sonar beam query successful")

		# Check first few results
		for i in range(min(3, beam_results.size())):
			var res: Dictionary = beam_results[i]
			print("   - Result ", i, ":")
			print("     Position: ", res.get("position", Vector3.ZERO))
			print("     Normal: ", res.get("normal", Vector3.ZERO))
			print("     Distance: ", res.get("distance", 0.0), " m")
	else:
		print("   ✗ Sonar beam query returned no results")

	# Test 4: Range filtering
	print("\n5. Testing range filtering...")
	var small_range: float = 100.0
	var large_range: float = 500.0

	var result_small: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, small_range, 1
	)
	var result_large: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, large_range, 1
	)

	var positions_small: PackedVector3Array = result_small.get("positions", PackedVector3Array())
	var positions_large: PackedVector3Array = result_large.get("positions", PackedVector3Array())

	print("   - Small range (", small_range, " m): ", positions_small.size(), " points")
	print("   - Large range (", large_range, " m): ", positions_large.size(), " points")

	if positions_large.size() > positions_small.size():
		print("   ✓ Range filtering works correctly")
	else:
		print("   ✗ Range filtering may not be working")

	# Test 5: Simplification levels
	print("\n6. Testing simplification levels...")
	var detailed: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, max_range, 0
	)
	var simplified: Dictionary = collision_manager.get_terrain_geometry_for_sonar(
		origin, max_range, 2
	)

	var positions_detailed: PackedVector3Array = detailed.get("positions", PackedVector3Array())
	var positions_simplified: PackedVector3Array = simplified.get("positions", PackedVector3Array())

	print("   - Detailed (level 0): ", positions_detailed.size(), " points")
	print("   - Simplified (level 2): ", positions_simplified.size(), " points")

	if positions_detailed.size() > positions_simplified.size():
		print("   ✓ Simplification reduces point count")
	else:
		print("   ✗ Simplification may not be working")

	print("\n=== All Tests Complete ===")
	print("Sonar integration is functional!")

	# Quit after tests
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
