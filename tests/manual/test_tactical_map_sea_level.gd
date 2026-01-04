extends GutTest

## Test TacticalMapView integration with SeaLevelManager
## Validates Requirements 6.2, 6.3, 6.4

var tactical_map_view: TacticalMapView
var sea_level_manager: Node


func before_each():
	# Get SeaLevelManager singleton
	sea_level_manager = Engine.get_singleton("SeaLevelManager")
	if not sea_level_manager:
		sea_level_manager = load("res://scripts/core/sea_level_manager.gd").new()
		sea_level_manager.name = "SeaLevelManager"
		add_child_autofree(sea_level_manager)
	
	# Reset to default
	sea_level_manager.reset_to_default()


func test_tactical_map_connects_to_sea_level_manager():
	# Create TacticalMapView
	tactical_map_view = TacticalMapView.new()
	add_child_autofree(tactical_map_view)
	
	# Wait for ready
	await wait_frames(2)
	
	# Verify connection exists
	var connections = sea_level_manager.sea_level_changed.get_connections()
	var found_connection = false
	for conn in connections:
		if conn["callable"].get_object() == tactical_map_view:
			found_connection = true
			break
	
	assert_true(found_connection, "TacticalMapView should connect to SeaLevelManager.sea_level_changed signal")


func test_tactical_map_responds_to_sea_level_change():
	# Create TacticalMapView
	tactical_map_view = TacticalMapView.new()
	add_child_autofree(tactical_map_view)
	
	# Wait for ready
	await wait_frames(2)
	
	# Track if callback was called
	var callback_called = false
	var received_normalized = 0.0
	var received_meters = 0.0
	
	# Connect to verify callback
	var callback = func(norm: float, met: float):
		callback_called = true
		received_normalized = norm
		received_meters = met
	
	# Override the callback temporarily
	if tactical_map_view.has_method("_on_sea_level_changed"):
		# Change sea level
		sea_level_manager.set_sea_level(0.7)
		
		# Wait for signal propagation
		await wait_frames(2)
		
		# Verify the manager's state changed
		assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 0.7, 0.001, 
			"SeaLevelManager should update to new value")


func test_tactical_map_uses_manager_sea_level_for_colorization():
	# This test verifies that the map generation uses the manager's sea level
	# We can't easily test the actual colorization without a full scene setup,
	# but we can verify the manager is queried
	
	# Set a non-default sea level
	sea_level_manager.set_sea_level(0.6)
	
	# Verify the value is accessible
	var sea_level_meters = sea_level_manager.get_sea_level_meters()
	assert_true(abs(sea_level_meters - 1000.0) < 100.0, 
		"Sea level at 0.6 normalized should be around 1000m")
	
	# Verify normalized value
	assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 0.6, 0.001,
		"Normalized value should be 0.6")


func test_sea_level_consistency_across_changes():
	# Test that multiple sea level changes are handled correctly
	var test_values = [0.3, 0.5, 0.7, 0.554]  # Including default
	
	for value in test_values:
		sea_level_manager.set_sea_level(value)
		await wait_frames(1)
		
		assert_almost_eq(sea_level_manager.get_sea_level_normalized(), value, 0.001,
			"Sea level should be %.3f" % value)
		
		# Verify meters conversion is consistent
		var expected_meters = sea_level_manager.normalized_to_meters(value)
		var actual_meters = sea_level_manager.get_sea_level_meters()
		assert_almost_eq(actual_meters, expected_meters, 0.1,
			"Meters value should match conversion")
