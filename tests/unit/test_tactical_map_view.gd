extends GutTest

## Unit tests for TacticalMapView
## Tests coordinate conversion, UI creation, and waypoint placement

var tactical_map_view: TacticalMapView
var simulation_state: SimulationState


func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	simulation_state._ready()
	add_child_autofree(simulation_state)

	# Create tactical map view
	tactical_map_view = TacticalMapView.new()
	add_child_autofree(tactical_map_view)

	# Set simulation state reference after adding to tree
	tactical_map_view.simulation_state = simulation_state

	# Wait for ready to complete
	await wait_physics_frames(1)


func after_each():
	# Cleanup is handled by autofree
	pass


## Test coordinate conversion: world to screen
func test_world_to_screen_at_origin():
	# Submarine at origin should map to screen center
	var world_pos = Vector3(0, 0, 0)
	var screen_pos = tactical_map_view.world_to_screen(world_pos)

	# Should be at map center (960, 540)
	assert_almost_eq(screen_pos.x, 960.0, 1.0, "Screen X should be at center")
	assert_almost_eq(screen_pos.y, 540.0, 1.0, "Screen Y should be at center")


## Test coordinate conversion: screen to world
func test_screen_to_world_at_center():
	# Screen center should map to world origin
	var screen_pos = Vector2(960, 540)
	var world_pos = tactical_map_view.screen_to_world(screen_pos)

	# Should be at origin
	assert_almost_eq(world_pos.x, 0.0, 1.0, "World X should be at origin")
	assert_almost_eq(world_pos.z, 0.0, 1.0, "World Z should be at origin")
	assert_almost_eq(world_pos.y, 0.0, 0.1, "World Y should be 0 (surface)")


## Test coordinate conversion: round trip
func test_coordinate_round_trip():
	# Test that world -> screen -> world preserves position
	var original_world = Vector3(100, 0, 200)
	var screen_pos = tactical_map_view.world_to_screen(original_world)
	var final_world = tactical_map_view.screen_to_world(screen_pos)

	assert_almost_eq(final_world.x, original_world.x, 1.0, "X coordinate should round trip")
	assert_almost_eq(final_world.z, original_world.z, 1.0, "Z coordinate should round trip")
	assert_almost_eq(final_world.y, 0.0, 0.1, "Y should be 0 (surface)")


## Test zoom affects coordinate conversion
func test_zoom_affects_scale():
	var world_pos = Vector3(100, 0, 0)

	# Get screen position at default zoom
	tactical_map_view.map_zoom = 1.0
	var screen_pos_zoom1 = tactical_map_view.world_to_screen(world_pos)

	# Get screen position at 2x zoom
	tactical_map_view.map_zoom = 2.0
	var screen_pos_zoom2 = tactical_map_view.world_to_screen(world_pos)

	# Distance from center should be doubled
	var dist1 = (screen_pos_zoom1 - tactical_map_view.map_center).length()
	var dist2 = (screen_pos_zoom2 - tactical_map_view.map_center).length()

	assert_almost_eq(dist2, dist1 * 2.0, 1.0, "Zoom should double distance from center")


## Test pan offset affects coordinate conversion
func test_pan_affects_position():
	var world_pos = Vector3(0, 0, 0)

	# Get screen position with no pan
	tactical_map_view.map_pan_offset = Vector2.ZERO
	var screen_pos_no_pan = tactical_map_view.world_to_screen(world_pos)

	# Get screen position with pan
	tactical_map_view.map_pan_offset = Vector2(50, 30)
	var screen_pos_with_pan = tactical_map_view.world_to_screen(world_pos)

	# Position should be offset by pan amount
	assert_almost_eq(screen_pos_with_pan.x, screen_pos_no_pan.x + 50, 0.1, "Pan should offset X")
	assert_almost_eq(screen_pos_with_pan.y, screen_pos_no_pan.y + 30, 0.1, "Pan should offset Y")


## Test submarine info display updates
func test_submarine_info_display():
	# Set submarine state
	simulation_state.submarine_position = Vector3(100, 0, 200)
	simulation_state.submarine_heading = 45.0
	simulation_state.submarine_speed = 5.0
	simulation_state.submarine_depth = 50.0

	# Process one frame to update display
	await wait_physics_frames(1)

	# Check that info label contains submarine data
	var info_text = tactical_map_view.submarine_info_label.text
	assert_string_contains(info_text, "100", "Info should contain X position")
	assert_string_contains(info_text, "200", "Info should contain Z position")
	assert_string_contains(info_text, "45", "Info should contain heading")
	assert_string_contains(info_text, "5.0", "Info should contain speed")
	assert_string_contains(info_text, "50", "Info should contain depth")


## Test speed slider updates simulation state
func test_speed_slider_updates_state():
	# Set initial waypoint and depth
	simulation_state.target_waypoint = Vector3(100, 0, 100)
	simulation_state.target_depth = 50.0

	# Simulate speed slider change
	tactical_map_view.speed_slider.value = 7.5
	tactical_map_view._on_speed_changed(7.5)

	# Check that simulation state was updated
	assert_almost_eq(simulation_state.target_speed, 7.5, 0.01, "Target speed should be updated")


## Test depth slider updates simulation state
func test_depth_slider_updates_state():
	# Set initial waypoint and speed
	simulation_state.target_waypoint = Vector3(100, 0, 100)
	simulation_state.target_speed = 5.0

	# Simulate depth slider change
	tactical_map_view.depth_slider.value = 100.0
	tactical_map_view._on_depth_changed(100.0)

	# Check that simulation state was updated
	assert_almost_eq(simulation_state.target_depth, 100.0, 0.1, "Target depth should be updated")


## Test waypoint placement updates submarine command
func test_waypoint_placement():
	# Set initial state
	simulation_state.submarine_position = Vector3.ZERO
	simulation_state.target_speed = 5.0
	simulation_state.target_depth = 50.0

	# Simulate waypoint click at screen position (offset from center)
	var screen_pos = Vector2(1060, 640)  # 100 pixels right and down from center
	tactical_map_view._handle_waypoint_placement(screen_pos)

	# Check that waypoint was set (should be non-zero since we clicked offset from center)
	var waypoint = simulation_state.target_waypoint

	# The waypoint should be in the positive X and Z direction
	assert_gt(waypoint.x, 0.0, "Waypoint X should be positive (right of center)")
	assert_gt(waypoint.z, 0.0, "Waypoint Z should be positive (down from center)")

	# Check that heading was updated toward waypoint
	# Since waypoint is in +X, +Z quadrant, heading should be between 0 and 90 degrees
	assert_gt(simulation_state.submarine_heading, 0.0, "Heading should be positive")
	assert_lt(simulation_state.submarine_heading, 90.0, "Heading should be less than 90")


## Test zoom clamping
func test_zoom_clamping():
	# Test zoom in beyond max
	tactical_map_view.map_zoom = 1.0
	for i in range(20):
		tactical_map_view._handle_zoom(1.5)

	assert_lte(tactical_map_view.map_zoom, tactical_map_view.MAX_ZOOM, "Zoom should not exceed max")

	# Test zoom out beyond min
	tactical_map_view.map_zoom = 1.0
	for i in range(20):
		tactical_map_view._handle_zoom(0.5)

	assert_gte(
		tactical_map_view.map_zoom, tactical_map_view.MIN_ZOOM, "Zoom should not go below min"
	)


## Test UI elements are created
func test_ui_elements_created():
	assert_not_null(tactical_map_view.map_canvas, "Map canvas should be created")
	assert_not_null(
		tactical_map_view.submarine_info_label, "Submarine info label should be created"
	)
	assert_not_null(tactical_map_view.speed_slider, "Speed slider should be created")
	assert_not_null(tactical_map_view.depth_slider, "Depth slider should be created")
	assert_not_null(tactical_map_view.speed_value_label, "Speed value label should be created")
	assert_not_null(tactical_map_view.depth_value_label, "Depth value label should be created")


## Test speed slider range matches simulation limits
func test_speed_slider_range():
	assert_almost_eq(tactical_map_view.speed_slider.min_value, 0.0, 0.01, "Speed min should be 0")
	assert_almost_eq(
		tactical_map_view.speed_slider.max_value,
		SimulationState.MAX_SPEED,
		0.01,
		"Speed max should match simulation"
	)


## Test depth slider range matches simulation limits
func test_depth_slider_range():
	assert_almost_eq(
		tactical_map_view.depth_slider.min_value,
		SimulationState.MIN_DEPTH,
		0.01,
		"Depth min should match simulation"
	)
	assert_almost_eq(
		tactical_map_view.depth_slider.max_value,
		SimulationState.MAX_DEPTH,
		0.01,
		"Depth max should match simulation"
	)
