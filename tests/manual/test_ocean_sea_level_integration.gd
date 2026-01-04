extends Node
## Manual test for OceanRenderer sea level integration

var ocean_renderer: OceanRenderer
var test_results: Array[String] = []


func _ready() -> void:
	print("\n=== OceanRenderer Sea Level Integration Test ===\n")
	
	# Create ocean renderer
	ocean_renderer = OceanRenderer.new()
	add_child(ocean_renderer)
	
	# Wait for initialization
	await get_tree().create_timer(0.5).timeout
	
	# Run tests
	test_initial_position()
	test_sea_level_change()
	test_wave_height_uses_manager()
	test_underwater_check()
	
	# Print results
	print("\n=== Test Results ===")
	for result in test_results:
		print(result)
	
	print("\n=== Test Complete ===\n")
	get_tree().quit()


func test_initial_position() -> void:
	var expected_sea_level = SeaLevelManager.get_sea_level_meters()
	var actual_position = ocean_renderer.global_position.y
	
	if abs(actual_position - expected_sea_level) < 0.01:
		test_results.append("✓ Initial position matches SeaLevelManager (%.2fm)" % expected_sea_level)
	else:
		test_results.append("✗ Initial position mismatch: expected %.2fm, got %.2fm" % [expected_sea_level, actual_position])


func test_sea_level_change() -> void:
	# Change sea level
	var new_sea_level_normalized = 0.6  # Higher than default
	SeaLevelManager.set_sea_level(new_sea_level_normalized)
	
	# Wait for signal propagation
	await get_tree().process_frame
	
	var expected_meters = SeaLevelManager.get_sea_level_meters()
	var actual_position = ocean_renderer.global_position.y
	
	if abs(actual_position - expected_meters) < 0.01:
		test_results.append("✓ Position updates on sea level change (%.2fm)" % expected_meters)
	else:
		test_results.append("✗ Position update failed: expected %.2fm, got %.2fm" % [expected_meters, actual_position])
	
	# Reset to default
	SeaLevelManager.reset_to_default()
	await get_tree().process_frame


func test_wave_height_uses_manager() -> void:
	# Set a specific sea level
	SeaLevelManager.set_sea_level(0.7)
	await get_tree().process_frame
	
	var test_pos = Vector3(100, 0, 100)
	var wave_height = ocean_renderer.get_wave_height_3d(test_pos)
	var manager_sea_level = SeaLevelManager.get_sea_level_meters()
	
	# Wave height should be at or near the manager's sea level (plus wave displacement)
	# Since we can't predict exact wave displacement, just check it's reasonable
	if abs(wave_height - manager_sea_level) < 10.0:  # Within 10m is reasonable for waves
		test_results.append("✓ Wave height uses manager's sea level (base: %.2fm, wave: %.2fm)" % [manager_sea_level, wave_height])
	else:
		test_results.append("✗ Wave height doesn't use manager: base %.2fm, wave %.2fm" % [manager_sea_level, wave_height])
	
	# Reset
	SeaLevelManager.reset_to_default()
	await get_tree().process_frame


func test_underwater_check() -> void:
	# Set sea level to 100m
	var test_sea_level = 100.0
	var normalized = SeaLevelManager.meters_to_normalized(test_sea_level)
	SeaLevelManager.set_sea_level(normalized)
	await get_tree().process_frame
	
	# Test position below sea level
	var underwater_pos = Vector3(0, 50, 0)  # 50m below 100m sea level
	var is_underwater = ocean_renderer.is_position_underwater(underwater_pos)
	
	if is_underwater:
		test_results.append("✓ Correctly identifies underwater position")
	else:
		test_results.append("✗ Failed to identify underwater position")
	
	# Test position above sea level
	var above_water_pos = Vector3(0, 150, 0)  # 50m above 100m sea level
	var is_above = not ocean_renderer.is_position_underwater(above_water_pos)
	
	if is_above:
		test_results.append("✓ Correctly identifies above-water position")
	else:
		test_results.append("✗ Failed to identify above-water position")
	
	# Reset
	SeaLevelManager.reset_to_default()
	await get_tree().process_frame
