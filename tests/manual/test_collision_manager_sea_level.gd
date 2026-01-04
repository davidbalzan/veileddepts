extends SceneTree
## Manual test for CollisionManager dynamic sea level integration

var sea_level_manager
var collision_manager

func _init():
	print("\n=== CollisionManager Dynamic Sea Level Test ===\n")
	
	# Load SeaLevelManager manually for testing
	var sea_level_manager_script = load("res://scripts/core/sea_level_manager.gd")
	sea_level_manager = sea_level_manager_script.new()
	sea_level_manager.name = "SeaLevelManager"
	root.add_child(sea_level_manager)
	
	# Load CollisionManager
	var collision_manager_script = load("res://scripts/rendering/collision_manager.gd")
	collision_manager = collision_manager_script.new()
	collision_manager.name = "CollisionManager"
	root.add_child(collision_manager)
	
	# Wait one frame for nodes to be properly added to tree
	call_deferred("run_tests")

func run_tests():
	# Test 1: Verify SeaLevelManager is available
	print("--- Test 1: SeaLevelManager Availability ---")
	print("✓ SeaLevelManager is available")
	print("  Default sea level: %.3f normalized (%.1fm)" % [
		sea_level_manager.get_sea_level_normalized(),
		sea_level_manager.get_sea_level_meters()
	])
	
	# Test 2: Test is_underwater_safe with default sea level
	print("\n--- Test 2: is_underwater_safe with Default Sea Level (0m) ---")
	
	var test_positions = [
		Vector3(0, 10, 0),    # Above sea level
		Vector3(0, -10, 0),   # Below sea level
		Vector3(0, -100, 0),  # Deep underwater
	]
	
	for pos in test_positions:
		var is_safe = collision_manager.is_underwater_safe(pos, 5.0)
		print("  Position %s: %s" % [pos, "SAFE" if is_safe else "NOT SAFE"])
	
	# Test 3: Change sea level and test again
	print("\n--- Test 3: is_underwater_safe with Raised Sea Level (+100m) ---")
	sea_level_manager.set_sea_level(sea_level_manager.meters_to_normalized(100.0))
	print("  New sea level: %.3f normalized (%.1fm)" % [
		sea_level_manager.get_sea_level_normalized(),
		sea_level_manager.get_sea_level_meters()
	])
	
	for pos in test_positions:
		var is_safe = collision_manager.is_underwater_safe(pos, 5.0)
		print("  Position %s: %s" % [pos, "SAFE" if is_safe else "NOT SAFE"])
	
	# Test 4: Test find_safe_spawn_position with default sea level
	print("\n--- Test 4: find_safe_spawn_position with Default Sea Level (0m) ---")
	sea_level_manager.reset_to_default()
	print("  Reset to default sea level: %.1fm" % sea_level_manager.get_sea_level_meters())
	
	var spawn_pos = collision_manager.find_safe_spawn_position(
		Vector3.ZERO,
		500.0,
		50.0,
		50.0
	)
	print("  Safe spawn position: %s" % spawn_pos)
	print("  Expected depth: %.1fm below sea level" % (sea_level_manager.get_sea_level_meters() - spawn_pos.y))
	
	# Test 5: Test find_safe_spawn_position with raised sea level
	print("\n--- Test 5: find_safe_spawn_position with Raised Sea Level (+100m) ---")
	sea_level_manager.set_sea_level(sea_level_manager.meters_to_normalized(100.0))
	print("  New sea level: %.1fm" % sea_level_manager.get_sea_level_meters())
	
	spawn_pos = collision_manager.find_safe_spawn_position(
		Vector3.ZERO,
		500.0,
		50.0,
		50.0
	)
	print("  Safe spawn position: %s" % spawn_pos)
	print("  Expected depth: %.1fm below sea level" % (sea_level_manager.get_sea_level_meters() - spawn_pos.y))
	
	# Test 6: Test find_safe_spawn_position with lowered sea level
	print("\n--- Test 6: find_safe_spawn_position with Lowered Sea Level (-100m) ---")
	sea_level_manager.set_sea_level(sea_level_manager.meters_to_normalized(-100.0))
	print("  New sea level: %.1fm" % sea_level_manager.get_sea_level_meters())
	
	spawn_pos = collision_manager.find_safe_spawn_position(
		Vector3.ZERO,
		500.0,
		50.0,
		50.0
	)
	print("  Safe spawn position: %s" % spawn_pos)
	print("  Expected depth: %.1fm below sea level" % (sea_level_manager.get_sea_level_meters() - spawn_pos.y))
	
	print("\n=== All Tests Complete ===\n")
	
	cleanup()

func cleanup():
	if collision_manager:
		collision_manager.free()
	if sea_level_manager:
		sea_level_manager.free()
	quit()
