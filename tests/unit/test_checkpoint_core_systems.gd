extends GutTest
## Checkpoint 5: Core Systems Functional
##
## Comprehensive integration tests to verify:
## 1. Simulation state updates correctly
## 2. View switching works between all three views
## 3. Tactical map displays submarine and accepts commands
## 4. All systems work together

var simulation_state: SimulationState
var view_manager: ViewManager
var tactical_map_view: TacticalMapView


func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	simulation_state._ready()
	add_child_autofree(simulation_state)

	# Create view manager
	view_manager = ViewManager.new()
	view_manager.simulation_state = simulation_state

	# Create mock cameras
	view_manager.tactical_map_camera = Camera2D.new()
	view_manager.periscope_camera = Camera3D.new()
	view_manager.external_camera = Camera3D.new()

	# Create mock view containers
	view_manager.tactical_map_view = CanvasLayer.new()
	view_manager.periscope_view = Node3D.new()
	view_manager.external_view = Node3D.new()

	# Add nodes to tree
	add_child_autofree(view_manager.tactical_map_camera)
	add_child_autofree(view_manager.periscope_camera)
	add_child_autofree(view_manager.external_camera)
	add_child_autofree(view_manager.tactical_map_view)
	add_child_autofree(view_manager.periscope_view)
	add_child_autofree(view_manager.external_view)

	# Create tactical map view
	tactical_map_view = TacticalMapView.new()
	tactical_map_view.simulation_state = simulation_state
	add_child_autofree(tactical_map_view)

	# Wait for ready to complete
	await wait_physics_frames(1)


## CHECKPOINT 1: Verify simulation state updates correctly
func test_simulation_state_updates_submarine_position():
	# Set initial position
	simulation_state.submarine_position = Vector3(100, 0, 200)

	# Update submarine state
	simulation_state.update_submarine_state(Vector3(150, 0, 250), Vector3(5, 0, 5), 50.0, 45.0, 7.5)

	# Verify state was updated
	assert_eq(
		simulation_state.submarine_position, Vector3(150, 0, 250), "Position should be updated"
	)
	assert_eq(simulation_state.submarine_velocity, Vector3(5, 0, 5), "Velocity should be updated")
	assert_eq(simulation_state.submarine_depth, 50.0, "Depth should be updated")
	assert_eq(simulation_state.submarine_heading, 45.0, "Heading should be updated")
	assert_eq(simulation_state.submarine_speed, 7.5, "Speed should be updated")


func test_simulation_state_clamps_depth_to_limits():
	# Try to set depth beyond max
	simulation_state.update_submarine_state(Vector3.ZERO, Vector3.ZERO, 500.0, 0.0, 0.0)  # Beyond MAX_DEPTH (400m)

	assert_eq(
		simulation_state.submarine_depth,
		SimulationState.MAX_DEPTH,
		"Depth should be clamped to max"
	)

	# Try to set depth below min
	simulation_state.update_submarine_state(Vector3.ZERO, Vector3.ZERO, -10.0, 0.0, 0.0)  # Below MIN_DEPTH (0m)

	assert_eq(
		simulation_state.submarine_depth,
		SimulationState.MIN_DEPTH,
		"Depth should be clamped to min"
	)


func test_simulation_state_clamps_speed_to_limits():
	# Try to set speed beyond max
	simulation_state.update_submarine_state(Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 20.0)  # Beyond MAX_SPEED (10.3 m/s)

	assert_eq(
		simulation_state.submarine_speed,
		SimulationState.MAX_SPEED,
		"Speed should be clamped to max"
	)


func test_simulation_state_normalizes_heading():
	# Test negative heading
	simulation_state.update_submarine_state(Vector3.ZERO, Vector3.ZERO, 0.0, -45.0, 0.0)

	assert_eq(
		simulation_state.submarine_heading, 315.0, "Negative heading should be normalized to 0-360"
	)

	# Test heading > 360
	simulation_state.update_submarine_state(Vector3.ZERO, Vector3.ZERO, 0.0, 405.0, 0.0)

	assert_eq(
		simulation_state.submarine_heading, 45.0, "Heading > 360 should be normalized to 0-360"
	)


func test_simulation_state_updates_waypoint_and_heading():
	# Set submarine at origin
	simulation_state.submarine_position = Vector3.ZERO

	# Set waypoint to northeast
	var waypoint = Vector3(100, 0, 100)
	simulation_state.update_submarine_command(waypoint, 5.0, 50.0)

	# Verify waypoint was set
	assert_eq(simulation_state.target_waypoint, waypoint, "Waypoint should be set")

	# Verify heading was updated (should be 45 degrees for northeast)
	assert_almost_eq(
		simulation_state.submarine_heading, 45.0, 1.0, "Heading should point toward waypoint"
	)


func test_simulation_state_contact_management():
	# Create test contacts
	var contact1 = Contact.new()
	contact1.type = Contact.ContactType.SURFACE_SHIP
	contact1.position = Vector3(100, 0, 100)
	contact1.detected = true
	contact1.identified = false

	var contact2 = Contact.new()
	contact2.type = Contact.ContactType.AIRCRAFT
	contact2.position = Vector3(200, 50, 200)
	contact2.detected = true
	contact2.identified = true

	# Add contacts
	var id1 = simulation_state.add_contact(contact1)
	var id2 = simulation_state.add_contact(contact2)

	assert_gt(id1, 0, "Contact 1 should be assigned valid ID")
	assert_gt(id2, 0, "Contact 2 should be assigned valid ID")
	assert_ne(id1, id2, "Contacts should have unique IDs")

	# Verify contacts were added
	assert_eq(simulation_state.contacts.size(), 2, "Should have 2 contacts")

	# Get detected contacts
	var detected = simulation_state.get_detected_contacts(Vector3.ZERO)
	assert_eq(detected.size(), 2, "Should have 2 detected contacts")

	# Get visible contacts (only identified ones)
	var visible = simulation_state.get_visible_contacts(Vector3.ZERO)
	assert_eq(visible.size(), 1, "Should have 1 visible contact (detected AND identified)")

	# Update contact
	var updated = simulation_state.update_contact(id1, Vector3(150, 0, 150), true, true)
	assert_true(updated, "Contact should be updated")

	# Verify update
	var updated_contact = simulation_state.get_contact(id1)
	assert_eq(updated_contact.position, Vector3(150, 0, 150), "Contact position should be updated")
	assert_true(updated_contact.identified, "Contact should now be identified")

	# Remove contact
	var removed = simulation_state.remove_contact(id1)
	assert_true(removed, "Contact should be removed")
	assert_eq(simulation_state.contacts.size(), 1, "Should have 1 contact remaining")


## CHECKPOINT 2: Verify view switching works between all three views
func test_view_switching_cycle():
	# Start in tactical map
	assert_eq(
		view_manager.current_view, ViewManager.ViewType.TACTICAL_MAP, "Should start in tactical map"
	)

	# Switch to periscope
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	assert_eq(
		view_manager.current_view, ViewManager.ViewType.PERISCOPE, "Should switch to periscope"
	)

	# Switch to external
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)
	assert_eq(view_manager.current_view, ViewManager.ViewType.EXTERNAL, "Should switch to external")

	# Switch back to tactical
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
	assert_eq(
		view_manager.current_view,
		ViewManager.ViewType.TACTICAL_MAP,
		"Should switch back to tactical"
	)


func test_view_switching_preserves_simulation_state():
	# Set submarine state
	simulation_state.submarine_position = Vector3(50, 0, 100)
	simulation_state.submarine_speed = 5.0
	simulation_state.submarine_depth = 75.0
	simulation_state.submarine_heading = 90.0

	var original_position = simulation_state.submarine_position
	var original_speed = simulation_state.submarine_speed
	var original_depth = simulation_state.submarine_depth
	var original_heading = simulation_state.submarine_heading

	# Switch through all views
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)

	# Verify state is preserved
	assert_eq(
		simulation_state.submarine_position, original_position, "Position should be preserved"
	)
	assert_eq(simulation_state.submarine_speed, original_speed, "Speed should be preserved")
	assert_eq(simulation_state.submarine_depth, original_depth, "Depth should be preserved")
	assert_eq(simulation_state.submarine_heading, original_heading, "Heading should be preserved")


func test_view_switching_completes_quickly():
	# Measure transition time for each view switch
	var start_time = Time.get_ticks_msec()

	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	var periscope_time = Time.get_ticks_msec() - start_time

	start_time = Time.get_ticks_msec()
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)
	var external_time = Time.get_ticks_msec() - start_time

	start_time = Time.get_ticks_msec()
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
	var tactical_time = Time.get_ticks_msec() - start_time

	# Requirement 3.5: Transitions should complete within 100ms
	assert_lt(periscope_time, 100, "Periscope transition should be < 100ms")
	assert_lt(external_time, 100, "External transition should be < 100ms")
	assert_lt(tactical_time, 100, "Tactical transition should be < 100ms")


func test_active_camera_matches_current_view():
	# Tactical map
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
	assert_eq(
		view_manager.get_active_camera(),
		view_manager.tactical_map_camera,
		"Active camera should be tactical"
	)

	# Periscope
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	assert_eq(
		view_manager.get_active_camera(),
		view_manager.periscope_camera,
		"Active camera should be periscope"
	)

	# External
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)
	assert_eq(
		view_manager.get_active_camera(),
		view_manager.external_camera,
		"Active camera should be external"
	)


## CHECKPOINT 3: Verify tactical map displays submarine and accepts commands
func test_tactical_map_displays_submarine_info():
	# Set submarine state
	simulation_state.submarine_position = Vector3(123, 0, 456)
	simulation_state.submarine_heading = 90.0
	simulation_state.submarine_speed = 7.5
	simulation_state.submarine_depth = 100.0

	# Process one frame to update display
	await wait_physics_frames(1)

	# Check that info label contains submarine data
	var info_text = tactical_map_view.submarine_info_label.text
	assert_string_contains(info_text, "123", "Info should contain X position")
	assert_string_contains(info_text, "456", "Info should contain Z position")
	assert_string_contains(info_text, "90", "Info should contain heading")
	assert_string_contains(info_text, "7.5", "Info should contain speed")
	assert_string_contains(info_text, "100", "Info should contain depth")


func test_tactical_map_accepts_speed_commands():
	# Set initial state
	simulation_state.target_waypoint = Vector3(100, 0, 100)
	simulation_state.target_depth = 50.0

	# Simulate speed slider change
	tactical_map_view.speed_slider.value = 8.0
	tactical_map_view._on_speed_changed(8.0)

	# Verify simulation state was updated
	assert_almost_eq(simulation_state.target_speed, 8.0, 0.01, "Target speed should be updated")


func test_tactical_map_accepts_depth_commands():
	# Set initial state
	simulation_state.target_waypoint = Vector3(100, 0, 100)
	simulation_state.target_speed = 5.0

	# Simulate depth slider change
	tactical_map_view.depth_slider.value = 150.0
	tactical_map_view._on_depth_changed(150.0)

	# Verify simulation state was updated
	assert_almost_eq(simulation_state.target_depth, 150.0, 0.1, "Target depth should be updated")


func test_tactical_map_accepts_waypoint_commands():
	# Set initial state
	simulation_state.submarine_position = Vector3.ZERO
	simulation_state.target_speed = 5.0
	simulation_state.target_depth = 50.0

	# Simulate waypoint click (offset from center)
	var screen_pos = Vector2(1060, 640)
	tactical_map_view._handle_waypoint_placement(screen_pos)

	# Verify waypoint was set
	var waypoint = simulation_state.target_waypoint
	assert_gt(waypoint.x, 0.0, "Waypoint X should be positive")
	assert_gt(waypoint.z, 0.0, "Waypoint Z should be positive")

	# Verify heading was updated
	assert_gt(simulation_state.submarine_heading, 0.0, "Heading should be updated")


func test_tactical_map_coordinate_conversion():
	# Test world to screen conversion
	var world_pos = Vector3(100, 0, 200)
	var screen_pos = tactical_map_view.world_to_screen(world_pos)

	# Convert back to world
	var world_pos_back = tactical_map_view.screen_to_world(screen_pos)

	# Should round trip correctly
	assert_almost_eq(world_pos_back.x, world_pos.x, 1.0, "X should round trip")
	assert_almost_eq(world_pos_back.z, world_pos.z, 1.0, "Z should round trip")


## CHECKPOINT 4: Integration test - all systems working together
func test_full_integration_submarine_command_flow():
	# Start in tactical map view
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)

	# Set submarine at origin
	simulation_state.submarine_position = Vector3.ZERO
	simulation_state.submarine_heading = 0.0
	simulation_state.submarine_speed = 0.0
	simulation_state.submarine_depth = 0.0

	# Issue commands via tactical map
	tactical_map_view._on_speed_changed(5.0)
	tactical_map_view._on_depth_changed(50.0)
	tactical_map_view._handle_waypoint_placement(Vector2(1060, 640))

	# Verify commands were received by simulation state
	assert_almost_eq(simulation_state.target_speed, 5.0, 0.01, "Speed command should be received")
	assert_almost_eq(simulation_state.target_depth, 50.0, 0.1, "Depth command should be received")
	assert_gt(simulation_state.target_waypoint.length(), 0.0, "Waypoint should be set")

	# Switch to periscope view
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)

	# Verify state is still consistent
	assert_almost_eq(simulation_state.target_speed, 5.0, 0.01, "Speed should be preserved")
	assert_almost_eq(simulation_state.target_depth, 50.0, 0.1, "Depth should be preserved")

	# Switch to external view
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)

	# Verify state is still consistent
	assert_almost_eq(simulation_state.target_speed, 5.0, 0.01, "Speed should be preserved")
	assert_almost_eq(simulation_state.target_depth, 50.0, 0.1, "Depth should be preserved")


func test_full_integration_contact_tracking():
	# Add contacts to simulation state
	var contact1 = Contact.new()
	contact1.type = Contact.ContactType.SURFACE_SHIP
	contact1.position = Vector3(500, 0, 500)
	contact1.detected = true
	contact1.identified = true

	var contact2 = Contact.new()
	contact2.type = Contact.ContactType.AIRCRAFT
	contact2.position = Vector3(-300, 100, 400)
	contact2.detected = true
	contact2.identified = false

	simulation_state.add_contact(contact1)
	simulation_state.add_contact(contact2)

	# Verify contacts are tracked
	assert_eq(simulation_state.contacts.size(), 2, "Should have 2 contacts")

	# Verify detected contacts (both should be detected)
	var detected = simulation_state.get_detected_contacts(Vector3.ZERO)
	assert_eq(detected.size(), 2, "Should have 2 detected contacts")

	# Verify visible contacts (only identified ones)
	var visible = simulation_state.get_visible_contacts(Vector3.ZERO)
	assert_eq(visible.size(), 1, "Should have 1 visible contact")

	# Verify the visible contact is the identified one
	assert_true(visible[0].identified, "Visible contact should be identified")


func test_core_systems_summary():
	# This test serves as a summary verification that all core systems are functional

	# 1. Simulation state is working
	simulation_state.submarine_position = Vector3(100, 0, 200)
	assert_eq(simulation_state.submarine_position, Vector3(100, 0, 200), "Simulation state works")

	# 2. View switching is working
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	assert_eq(view_manager.current_view, ViewManager.ViewType.PERISCOPE, "View switching works")

	# 3. Tactical map is working
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
	tactical_map_view._on_speed_changed(5.0)
	assert_almost_eq(simulation_state.target_speed, 5.0, 0.01, "Tactical map commands work")

	# 4. All systems integrated
	pass_test("All core systems are functional!")
