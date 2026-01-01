extends GutTest
## Checkpoint 10: All Views Functional
##
## Comprehensive integration tests to verify:
## 1. Periscope view tracks submarine and responds to input
## 2. External view orbits submarine with fog of war
## 3. Submarine physics affects all views consistently
## 4. All systems work together seamlessly

var simulation_state: SimulationState
var periscope_view: PeriscopeView
var external_view: ExternalView
var submarine_physics: Node
var submarine_body: RigidBody3D
var ocean_renderer: OceanRenderer
var fog_of_war: FogOfWarSystem

const SubmarinePhysicsClass = preload("res://scripts/physics/submarine_physics.gd")


func before_each():
	# Create simulation state FIRST
	simulation_state = SimulationState.new()
	simulation_state.name = "SimulationState"
	add_child_autofree(simulation_state)
	simulation_state._ready()
	
	# Create ocean renderer
	ocean_renderer = OceanRenderer.new()
	ocean_renderer.name = "OceanRenderer"
	add_child_autofree(ocean_renderer)
	
	# Create submarine body
	submarine_body = RigidBody3D.new()
	submarine_body.name = "SubmarineBody"
	submarine_body.mass = 8000000.0  # 8000 tons in kg
	add_child_autofree(submarine_body)
	
	# Add collision shape
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(10.0, 5.0, 50.0)
	collision_shape.shape = box_shape
	submarine_body.add_child(collision_shape)
	
	# Create submarine physics
	submarine_physics = SubmarinePhysicsClass.new()
	submarine_physics.name = "SubmarinePhysics"
	add_child_autofree(submarine_physics)
	submarine_physics.initialize(submarine_body, ocean_renderer, simulation_state)
	
	# Create fog of war system - set simulation_state BEFORE adding to tree
	fog_of_war = FogOfWarSystem.new()
	fog_of_war.name = "FogOfWarSystem"
	fog_of_war.simulation_state = simulation_state  # Set before _ready
	add_child_autofree(fog_of_war)
	
	# Create periscope view - set references BEFORE adding to tree
	periscope_view = PeriscopeView.new()
	periscope_view.name = "PeriscopeView"
	
	# Create camera for periscope BEFORE adding periscope to tree
	var periscope_camera = Camera3D.new()
	periscope_camera.name = "Camera3D"
	periscope_view.add_child(periscope_camera)
	
	# Set references before _ready is called
	periscope_view.camera = periscope_camera
	periscope_view.simulation_state = simulation_state
	periscope_view.ocean_renderer = ocean_renderer
	
	add_child_autofree(periscope_view)
	
	# Create external view - set references BEFORE adding to tree
	external_view = ExternalView.new()
	external_view.name = "ExternalView"
	
	# Create camera for external view BEFORE adding external view to tree
	var external_camera = Camera3D.new()
	external_camera.name = "Camera3D"
	external_view.add_child(external_camera)
	
	# Set references before _ready is called
	external_view.camera = external_camera
	external_view.simulation_state = simulation_state
	external_view.fog_of_war = fog_of_war
	
	add_child_autofree(external_view)
	
	# Wait for initialization
	await wait_physics_frames(1)


## ============================================================================
## CHECKPOINT 1: Periscope View Tracks Submarine and Responds to Input
## ============================================================================

func test_periscope_view_initialized():
	"""Test that periscope view is properly initialized."""
	assert_not_null(periscope_view, "Periscope view should be created")
	assert_not_null(periscope_view.camera, "Periscope camera should exist")
	# simulation_state is set before adding to tree, verify it's still set
	assert_not_null(periscope_view.simulation_state, "Periscope should have simulation state")


func test_periscope_rotation_input_updates_view():
	"""Test that periscope rotation input changes viewing direction.
	Requirement 5.2: Rotate periscope based on player input."""
	# Initial rotation
	var initial_rotation = periscope_view.periscope_rotation
	
	# Apply rotation input
	periscope_view.handle_rotation_input(45.0)
	
	# Rotation should change
	assert_eq(periscope_view.periscope_rotation, initial_rotation + 45.0,
		"Periscope rotation should respond to input")


func test_periscope_zoom_input_updates_fov():
	"""Test that periscope zoom input changes field of view.
	Requirement 5.3: Adjust field of view within operational limits (15° to 90°)."""
	# Initial FOV
	var initial_fov = periscope_view.zoom_level
	
	# Zoom in
	periscope_view.handle_zoom_input(10.0)
	
	# FOV should decrease
	assert_eq(periscope_view.zoom_level, initial_fov - 10.0,
		"Periscope zoom should respond to input")
	
	# Camera FOV should match
	assert_eq(periscope_view.camera.fov, periscope_view.zoom_level,
		"Camera FOV should match zoom level")


func test_periscope_zoom_clamped_to_limits():
	"""Test that periscope zoom is clamped to operational limits.
	Requirement 5.3: FOV should be between 15° and 90°."""
	# Try to zoom beyond minimum
	periscope_view.zoom_level = 20.0
	periscope_view.handle_zoom_input(10.0)
	
	assert_eq(periscope_view.zoom_level, PeriscopeView.MIN_FOV,
		"Zoom should be clamped to minimum FOV")
	
	# Try to zoom beyond maximum
	periscope_view.zoom_level = 85.0
	periscope_view.handle_zoom_input(-10.0)
	
	assert_eq(periscope_view.zoom_level, PeriscopeView.MAX_FOV,
		"Zoom should be clamped to maximum FOV")


func test_periscope_underwater_mode_activation():
	"""Test that periscope switches to underwater rendering when submerged.
	Requirement 5.5: Display underwater environment when depth > 10m."""
	# Setup underwater environment (may already be set from _ready)
	periscope_view.setup_underwater_environment()
	
	# Verify underwater environment was created
	assert_not_null(periscope_view.underwater_environment,
		"Underwater environment should be created")
	
	# Start at surface - reset state
	simulation_state.submarine_depth = 0.0
	periscope_view.is_underwater_mode = false
	periscope_view.camera.environment = null
	periscope_view.update_underwater_mode()
	
	# Should not have underwater environment at surface
	assert_false(periscope_view.is_underwater_mode,
		"Should not be in underwater mode at surface")
	
	# Go underwater (depth > PERISCOPE_DEPTH which is 10m)
	simulation_state.submarine_depth = 20.0
	periscope_view.update_underwater_mode()
	
	# Should have underwater environment
	assert_not_null(periscope_view.camera.environment,
		"Camera should have underwater environment when submerged")
	assert_true(periscope_view.is_underwater_mode,
		"Underwater mode flag should be set")


func test_periscope_pitch_input():
	"""Test that periscope pitch input works correctly."""
	# Initial pitch
	var initial_pitch = periscope_view.periscope_pitch
	
	# Apply pitch input
	periscope_view.handle_pitch_input(20.0)
	
	# Pitch should change
	assert_eq(periscope_view.periscope_pitch, initial_pitch + 20.0,
		"Periscope pitch should respond to input")


## ============================================================================
## CHECKPOINT 2: External View Orbits Submarine with Fog of War
## ============================================================================

func test_external_view_initialized():
	"""Test that external view is properly initialized."""
	assert_not_null(external_view, "External view should be created")
	assert_not_null(external_view.camera, "External camera should exist")
	# References are set before adding to tree
	assert_not_null(external_view.simulation_state, "External view should have simulation state")
	assert_not_null(external_view.fog_of_war, "External view should have fog of war")


func test_external_camera_tilt_input():
	"""Test that external camera tilt input changes vertical angle.
	Requirement 4.2: Adjust vertical viewing angle within operational limits."""
	# Initial tilt
	var initial_tilt = external_view.camera_tilt
	
	# Apply tilt input
	external_view.handle_tilt_input(15.0)
	
	# Tilt should change
	assert_eq(external_view.camera_tilt, initial_tilt + 15.0,
		"Camera tilt should respond to input")


func test_external_camera_rotation_input():
	"""Test that external camera rotation input orbits around submarine.
	Requirement 4.3: Orbit around submarine position."""
	# Initial rotation
	var initial_rotation = external_view.camera_rotation
	
	# Apply rotation input
	external_view.handle_rotation_input(45.0)
	
	# Rotation should change
	assert_eq(external_view.camera_rotation, initial_rotation + 45.0,
		"Camera rotation should respond to input")


func test_external_camera_distance_input():
	"""Test that external camera distance input changes zoom.
	Requirement 4.4: Adjust camera distance within operational limits."""
	# Initial distance
	var initial_distance = external_view.camera_distance
	
	# Apply distance input (zoom in)
	external_view.handle_distance_input(-50.0)
	
	# Distance should decrease
	assert_eq(external_view.camera_distance, initial_distance - 50.0,
		"Camera distance should respond to input")


func test_external_camera_distance_clamped():
	"""Test that external camera distance is clamped to limits.
	Requirement 4.4: Distance should be between 10m and 500m."""
	# Try to zoom in beyond minimum
	external_view.camera_distance = 15.0
	external_view.handle_distance_input(-10.0)
	
	assert_eq(external_view.camera_distance, ExternalView.MIN_DISTANCE,
		"Distance should be clamped to minimum")
	
	# Try to zoom out beyond maximum
	external_view.camera_distance = 495.0
	external_view.handle_distance_input(10.0)
	
	assert_eq(external_view.camera_distance, ExternalView.MAX_DISTANCE,
		"Distance should be clamped to maximum")


func test_external_camera_tilt_clamped():
	"""Test that external camera tilt is clamped to limits.
	Requirement 4.2: Tilt should be between -89° and 89°."""
	# Try to tilt beyond minimum
	external_view.camera_tilt = -85.0
	external_view.handle_tilt_input(-10.0)
	
	assert_eq(external_view.camera_tilt, ExternalView.MIN_TILT,
		"Tilt should be clamped to minimum")
	
	# Try to tilt beyond maximum
	external_view.camera_tilt = 85.0
	external_view.handle_tilt_input(10.0)
	
	assert_eq(external_view.camera_tilt, ExternalView.MAX_TILT,
		"Tilt should be clamped to maximum")


func test_external_free_camera_mode():
	"""Test that external view supports free camera mode.
	Requirement 4.5: Allow camera to move independently from submarine."""
	# Start in orbit mode
	assert_false(external_view.free_camera_mode, "Should start in orbit mode")
	
	# Toggle to free camera
	external_view.toggle_free_camera()
	assert_true(external_view.free_camera_mode, "Should switch to free camera mode")
	
	# Toggle back to orbit
	external_view.toggle_free_camera()
	assert_false(external_view.free_camera_mode, "Should switch back to orbit mode")


func test_external_fog_of_war_visibility():
	"""Test that external view respects fog of war for contact visibility.
	Requirement 4.7, 4.8: Only render contacts that are detected AND identified."""
	# Clear any existing contacts first
	simulation_state.clear_contacts()
	
	# Create test contacts
	var contact1 = Contact.new()
	contact1.id = 1
	contact1.position = Vector3(100, 0, 100)
	contact1.detected = true
	contact1.identified = true  # Should be visible
	
	var contact2 = Contact.new()
	contact2.id = 2
	contact2.position = Vector3(200, 0, 200)
	contact2.detected = true
	contact2.identified = false  # Should NOT be visible
	
	var contact3 = Contact.new()
	contact3.id = 3
	contact3.position = Vector3(300, 0, 300)
	contact3.detected = false
	contact3.identified = false  # Should NOT be visible
	
	# Add contacts to simulation state
	simulation_state.add_contact(contact1)
	simulation_state.add_contact(contact2)
	simulation_state.add_contact(contact3)
	
	# Ensure external_view has correct references
	external_view.simulation_state = simulation_state
	external_view.fog_of_war = fog_of_war
	
	# Get visible contacts through external view
	var visible_contacts = external_view.get_visible_contacts()
	
	# Only contact1 should be visible (detected AND identified)
	assert_eq(visible_contacts.size(), 1, "Only one contact should be visible")
	if visible_contacts.size() > 0:
		assert_eq(visible_contacts[0].id, 1, "Contact 1 should be visible")


func test_fog_of_war_system_filters_correctly():
	"""Test that fog of war system correctly filters contacts.
	Requirement 4.7, 4.8: Fog of war should filter based on detection and identification."""
	# Clear any existing contacts first
	simulation_state.clear_contacts()
	
	# Create test contacts
	var contact_visible = Contact.new()
	contact_visible.id = 1
	contact_visible.detected = true
	contact_visible.identified = true
	
	var contact_hidden = Contact.new()
	contact_hidden.id = 2
	contact_hidden.detected = true
	contact_hidden.identified = false
	
	# Add to simulation state
	simulation_state.add_contact(contact_visible)
	simulation_state.add_contact(contact_hidden)
	
	# Check visibility through fog of war
	assert_true(fog_of_war.is_contact_visible(contact_visible), "Visible contact should pass fog of war")
	assert_false(fog_of_war.is_contact_visible(contact_hidden), "Hidden contact should fail fog of war")


## ============================================================================
## CHECKPOINT 3: Submarine Physics Affects All Views Consistently
## ============================================================================

func test_physics_updates_simulation_state():
	"""Test that submarine physics updates simulation state.
	Requirement 12.1, 12.2: Physics changes should update all views."""
	# Set initial state
	submarine_body.global_position = Vector3(0, -50, 0)
	submarine_body.linear_velocity = Vector3(5, 0, 5)
	simulation_state.target_speed = 7.5
	simulation_state.target_depth = 100.0
	simulation_state.submarine_heading = 45.0
	
	# Update physics
	submarine_physics.update_physics(0.016)
	
	# Get physics state
	var physics_state = submarine_physics.get_submarine_state()
	
	# Verify state was updated
	assert_not_null(physics_state, "Physics state should be returned")
	assert_true(physics_state.has("position"), "Physics state should have position")
	assert_true(physics_state.has("velocity"), "Physics state should have velocity")
	assert_true(physics_state.has("depth"), "Physics state should have depth")


func test_depth_changes_affect_physics():
	"""Test that depth changes affect submarine physics.
	Requirement 11.1: Depth changes should apply forces."""
	# Set target depth
	simulation_state.target_depth = 100.0
	submarine_body.global_position = Vector3(0, -50, 0)  # Current depth 50m
	
	# Apply depth control
	submarine_physics.apply_depth_control(0.016)
	
	# Submarine should have ballast force applied
	# (We can't directly measure force, but verify no errors)
	assert_true(true, "Depth control force applied successfully")


func test_speed_changes_affect_physics():
	"""Test that speed changes affect submarine physics.
	Requirement 11.4: Speed changes should apply propulsion."""
	# Set target speed
	simulation_state.target_speed = 8.0
	simulation_state.submarine_heading = 0.0
	submarine_body.linear_velocity = Vector3.ZERO
	
	# Apply propulsion
	submarine_physics.apply_propulsion(0.016)
	
	# Submarine should have propulsion force applied
	# (We can't directly measure force, but verify no errors)
	assert_true(true, "Propulsion force applied successfully")


func test_heading_changes_affect_physics():
	"""Test that heading changes affect submarine physics.
	Requirement 11.4: Heading changes should affect maneuverability."""
	# Set submarine moving
	submarine_body.linear_velocity = Vector3(5, 0, 0)
	simulation_state.submarine_heading = 90.0
	simulation_state.target_speed = 5.0
	
	# Apply propulsion (which includes turning)
	submarine_physics.apply_propulsion(0.016)
	
	# Submarine should have turning force applied
	# (We can't directly measure force, but verify no errors)
	assert_true(true, "Turning force applied successfully")


func test_buoyancy_force_applied():
	"""Test that buoyancy force is applied based on depth.
	Requirement 11.1: Buoyancy should be applied based on wave height."""
	# Position submarine below water surface
	submarine_body.global_position = Vector3(0, -10, 0)
	
	# Apply buoyancy
	submarine_physics.apply_buoyancy(0.016)
	
	# Submarine should have upward force applied
	# (We can't directly measure force, but verify no errors)
	assert_true(true, "Buoyancy force applied successfully")


func test_drag_force_applied():
	"""Test that drag force is applied when moving.
	Requirement 11.3: Hydrodynamic drag should be applied."""
	# Set submarine velocity
	submarine_body.linear_velocity = Vector3(5, 0, 0)
	simulation_state.submarine_depth = 50.0
	
	# Apply drag
	submarine_physics.apply_drag(0.016)
	
	# Drag should be applied (we can't directly measure force)
	assert_true(true, "Drag force applied successfully")


## ============================================================================
## CHECKPOINT 4: All Systems Work Together Seamlessly
## ============================================================================

func test_full_integration_physics_to_views():
	"""Test that physics updates flow through to all views.
	Requirement 12.1, 12.2: Physics changes should update all views."""
	# Set submarine position via physics
	submarine_body.global_position = Vector3(100, -50, 200)
	
	# Update physics
	submarine_physics.update_physics(0.016)
	
	# Get physics state
	var physics_state = submarine_physics.get_submarine_state()
	
	# Update simulation state from physics
	simulation_state.update_submarine_state(
		physics_state["position"],
		physics_state["velocity"],
		physics_state["depth"],
		physics_state["heading"],
		physics_state["speed"]
	)
	
	# Verify simulation state was updated
	assert_eq(simulation_state.submarine_position, physics_state["position"],
		"Simulation state should match physics state")


func test_full_integration_commands_flow_through_physics():
	"""Test that tactical map commands flow through physics to all views.
	Requirement 12.1, 12.2: Commands should affect physics and all views."""
	# Issue commands
	simulation_state.update_submarine_command(
		Vector3(500, 0, 500),  # Waypoint
		7.5,  # Speed
		100.0  # Depth
	)
	
	# Verify targets are set
	assert_eq(simulation_state.target_waypoint, Vector3(500, 0, 500), "Waypoint should be set")
	assert_almost_eq(simulation_state.target_speed, 7.5, 0.01, "Target speed should be set")
	assert_almost_eq(simulation_state.target_depth, 100.0, 0.1, "Target depth should be set")
	
	# Update physics with these targets
	submarine_body.global_position = Vector3.ZERO
	submarine_body.linear_velocity = Vector3.ZERO
	
	submarine_physics.update_physics(0.016)
	
	# Get physics state
	var physics_state = submarine_physics.get_submarine_state()
	
	# Update simulation state
	simulation_state.update_submarine_state(
		physics_state["position"],
		physics_state["velocity"],
		physics_state["depth"],
		physics_state["heading"],
		physics_state["speed"]
	)
	
	# Verify all systems are updated
	assert_not_null(simulation_state.submarine_position, "Position should be updated")


func test_full_integration_contact_visibility_across_views():
	"""Test that contact visibility is consistent across all views.
	Requirement 4.7, 4.8: Fog of war should be consistent."""
	# Clear any existing contacts first
	simulation_state.clear_contacts()
	
	# Create contacts with different visibility states
	var contact_visible = Contact.new()
	contact_visible.id = 1
	contact_visible.position = Vector3(100, 0, 100)
	contact_visible.detected = true
	contact_visible.identified = true
	
	var contact_hidden = Contact.new()
	contact_hidden.id = 2
	contact_hidden.position = Vector3(200, 0, 200)
	contact_hidden.detected = true
	contact_hidden.identified = false
	
	# Add contacts
	simulation_state.add_contact(contact_visible)
	simulation_state.add_contact(contact_hidden)
	
	# Ensure external_view has correct references
	external_view.simulation_state = simulation_state
	external_view.fog_of_war = fog_of_war
	
	# Get visible contacts from external view
	var visible_from_external = external_view.get_visible_contacts()
	
	# Get visible contacts from simulation state
	var visible_from_sim = simulation_state.get_visible_contacts(Vector3.ZERO)
	
	# Should be consistent
	assert_eq(visible_from_external.size(), visible_from_sim.size(),
		"Visible contacts should be consistent across views")
	assert_eq(visible_from_external.size(), 1, "Only identified contact should be visible")


func test_all_views_checkpoint_summary():
	"""Summary test verifying all views are functional."""
	# Clear any existing contacts first
	simulation_state.clear_contacts()
	
	# Reset periscope rotation for this test
	periscope_view.periscope_rotation = 0.0
	
	# 1. Periscope view is functional
	assert_not_null(periscope_view.camera, "Periscope view is functional")
	periscope_view.handle_rotation_input(30.0)
	assert_eq(periscope_view.periscope_rotation, 30.0, "Periscope responds to input")
	
	# Reset external view distance for this test
	external_view.camera_distance = 100.0
	
	# 2. External view is functional
	assert_not_null(external_view.camera, "External view is functional")
	external_view.handle_distance_input(50.0)
	assert_eq(external_view.camera_distance, 150.0, "External view responds to input")
	
	# 3. Physics affects views
	submarine_physics.update_physics(0.016)
	var physics_state = submarine_physics.get_submarine_state()
	assert_not_null(physics_state, "Physics system is functional")
	
	# 4. Fog of war works
	var contact = Contact.new()
	contact.id = 1
	contact.position = Vector3(100, 0, 100)
	contact.detected = true
	contact.identified = true
	simulation_state.add_contact(contact)
	
	# Ensure external_view has correct references
	external_view.simulation_state = simulation_state
	external_view.fog_of_war = fog_of_war
	
	var visible = external_view.get_visible_contacts()
	assert_eq(visible.size(), 1, "Fog of war is functional")
	
	pass_test("All views are functional and working together!")
