extends GutTest

## Unit tests for SeaLevelManager
##
## Tests the sea level management singleton including:
## - Default initialization
## - Elevation conversion functions (normalized ↔ meters)
## - Signal emission on value changes
## - Input validation and clamping
## - Reset to default functionality

var sea_level_manager: Node


func before_each():
	# Get the SeaLevelManager autoload
	sea_level_manager = get_node("/root/SeaLevelManager")
	# Reset to default state
	sea_level_manager.reset_to_default()


func after_each():
	# Reset to default state
	sea_level_manager.reset_to_default()


## Test default initialization
func test_default_initialization():
	assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 0.554, 0.001, 
		"Default normalized sea level should be 0.554")
	assert_almost_eq(sea_level_manager.get_sea_level_meters(), 0.0, 1.0, 
		"Default sea level in meters should be approximately 0m")


## Test elevation conversion: normalized to meters
func test_normalized_to_meters_conversion():
	# Test known values
	var mariana_trench = sea_level_manager.normalized_to_meters(0.0)
	assert_almost_eq(mariana_trench, -10994.0, 1.0, 
		"0.0 normalized should convert to Mariana Trench depth")
	
	var sea_level = sea_level_manager.normalized_to_meters(0.554)
	assert_almost_eq(sea_level, 0.0, 10.0, 
		"0.554 normalized should convert to approximately 0m")
	
	var everest = sea_level_manager.normalized_to_meters(1.0)
	assert_almost_eq(everest, 8849.0, 1.0, 
		"1.0 normalized should convert to Mount Everest height")


## Test elevation conversion: meters to normalized
func test_meters_to_normalized_conversion():
	# Test known values
	var mariana_normalized = sea_level_manager.meters_to_normalized(-10994.0)
	assert_almost_eq(mariana_normalized, 0.0, 0.001, 
		"Mariana Trench depth should convert to 0.0 normalized")
	
	var sea_level_normalized = sea_level_manager.meters_to_normalized(0.0)
	assert_almost_eq(sea_level_normalized, 0.554, 0.01, 
		"0m should convert to approximately 0.554 normalized")
	
	var everest_normalized = sea_level_manager.meters_to_normalized(8849.0)
	assert_almost_eq(everest_normalized, 1.0, 0.001, 
		"Mount Everest height should convert to 1.0 normalized")


## Test round-trip conversion: normalized -> meters -> normalized
func test_round_trip_normalized_to_meters():
	var test_values = [0.0, 0.25, 0.5, 0.554, 0.75, 1.0]
	
	for normalized in test_values:
		var meters = sea_level_manager.normalized_to_meters(normalized)
		var back_to_normalized = sea_level_manager.meters_to_normalized(meters)
		assert_almost_eq(normalized, back_to_normalized, 0.0001, 
			"Round-trip conversion should preserve value: %.3f" % normalized)


## Test round-trip conversion: meters -> normalized -> meters
func test_round_trip_meters_to_normalized():
	var test_values = [-10994.0, -5000.0, 0.0, 5000.0, 8849.0]
	
	for meters in test_values:
		var normalized = sea_level_manager.meters_to_normalized(meters)
		var back_to_meters = sea_level_manager.normalized_to_meters(normalized)
		assert_almost_eq(meters, back_to_meters, 1.0, 
			"Round-trip conversion should preserve value: %.2f" % meters)


## Test set_sea_level with valid input
func test_set_sea_level_valid_input():
	sea_level_manager.set_sea_level(0.7)
	
	assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 0.7, 0.001, 
		"Sea level should be set to 0.7")
	
	var expected_meters = sea_level_manager.normalized_to_meters(0.7)
	assert_almost_eq(sea_level_manager.get_sea_level_meters(), expected_meters, 1.0, 
		"Sea level in meters should match conversion")


## Test set_sea_level with value above range (should clamp to 1.0)
func test_set_sea_level_clamps_high():
	sea_level_manager.set_sea_level(1.5)
	
	assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 1.0, 0.001, 
		"Sea level should be clamped to 1.0")


## Test set_sea_level with value below range (should clamp to 0.0)
func test_set_sea_level_clamps_low():
	sea_level_manager.set_sea_level(-0.5)
	
	assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 0.0, 0.001, 
		"Sea level should be clamped to 0.0")


## Test signal emission on sea level change
func test_signal_emission():
	var signal_watcher = watch_signals(sea_level_manager)
	
	sea_level_manager.set_sea_level(0.8)
	
	assert_signal_emitted(sea_level_manager, "sea_level_changed", 
		"Signal should be emitted when sea level changes")
	
	# Verify signal parameters
	var signal_params = get_signal_parameters(sea_level_manager, "sea_level_changed", 0)
	assert_almost_eq(signal_params[0], 0.8, 0.001, 
		"Signal should emit correct normalized value")
	assert_almost_eq(signal_params[1], sea_level_manager.normalized_to_meters(0.8), 1.0, 
		"Signal should emit correct meters value")


## Test signal NOT emitted when value doesn't change
func test_signal_not_emitted_when_unchanged():
	sea_level_manager.set_sea_level(0.6)
	var signal_watcher = watch_signals(sea_level_manager)
	
	# Set to same value (within threshold)
	sea_level_manager.set_sea_level(0.6)
	
	assert_signal_not_emitted(sea_level_manager, "sea_level_changed", 
		"Signal should NOT be emitted when value doesn't change")


## Test reset_to_default functionality
func test_reset_to_default():
	# Change sea level
	sea_level_manager.set_sea_level(0.9)
	assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 0.9, 0.001, 
		"Sea level should be changed")
	
	# Reset to default
	sea_level_manager.reset_to_default()
	
	assert_almost_eq(sea_level_manager.get_sea_level_normalized(), 0.554, 0.001, 
		"Sea level should be reset to default (0.554)")
	assert_almost_eq(sea_level_manager.get_sea_level_meters(), 0.0, 1.0, 
		"Sea level in meters should be reset to approximately 0m")


## Test reset_to_default emits signal
func test_reset_to_default_emits_signal():
	# Change sea level first
	sea_level_manager.set_sea_level(0.9)
	
	var signal_watcher = watch_signals(sea_level_manager)
	
	# Reset to default
	sea_level_manager.reset_to_default()
	
	assert_signal_emitted(sea_level_manager, "sea_level_changed", 
		"Signal should be emitted when resetting to default")
