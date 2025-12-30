extends GutTest
## Unit tests for ExternalView class
##
## Tests camera orbit controls, free camera mode, and fog of war integration

var external_view: ExternalView
var simulation_state: SimulationState
var fog_of_war: FogOfWarSystem
var camera: Camera3D


func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	simulation_state.name = "SimulationState"
	add_child_autofree(simulation_state)
	
	# Set submarine at origin
	simulation_state.submarine_position = Vector3.ZERO
	simulation_state.submarine_heading = 0.0
	
	# Create fog of war system
	fog_of_war = FogOfWarSystem.new()
	fog_of_war.name = "FogOfWarSystem"
	fog_of_war.simulation_state = simulation_state
	add_child_autofree(fog_of_war)
	
	# Create external view
	external_view = ExternalView.new()
	external_view.name = "ExternalView"
	external_view.simulation_state = simulation_state
	external_view.fog_of_war = fog_of_war
	
	# Create camera
	camera = Camera3D.new()
	camera.name = "Camera3D"
	external_view.add_child(camera)
	external_view.camera = camera
	
	add_child_autofree(external_view)


func test_external_view_initializes():
	assert_not_null(external_view, "ExternalView should be created")
	assert_not_null(external_view.camera, "Camera should be assigned")
	assert_not_null(external_view.simulation_state, "SimulationState should be assigned")
	assert_not_null(external_view.fog_of_war, "FogOfWarSystem should be assigned")


func test_camera_distance_clamping():
	# Test minimum distance clamping
	external_view.camera_distance = 5.0
	external_view.handle_distance_input(-10.0)
	assert_eq(external_view.camera_distance, ExternalView.MIN_DISTANCE, 
		"Distance should be clamped to minimum")
	
	# Test maximum distance clamping
	external_view.camera_distance = 495.0
	external_view.handle_distance_input(10.0)
	assert_eq(external_view.camera_distance, ExternalView.MAX_DISTANCE, 
		"Distance should be clamped to maximum")
	
	# Test normal distance adjustment
	external_view.camera_distance = 100.0
	external_view.handle_distance_input(50.0)
	assert_eq(external_view.camera_distance, 150.0, 
		"Distance should increase by delta")


func test_camera_tilt_clamping():
	# Test minimum tilt clamping
	external_view.camera_tilt = -85.0
	external_view.handle_tilt_input(-10.0)
	assert_eq(external_view.camera_tilt, ExternalView.MIN_TILT, 
		"Tilt should be clamped to minimum")
	
	# Test maximum tilt clamping
	external_view.camera_tilt = 85.0
	external_view.handle_tilt_input(10.0)
	assert_eq(external_view.camera_tilt, ExternalView.MAX_TILT, 
		"Tilt should be clamped to maximum")
	
	# Test normal tilt adjustment
	external_view.camera_tilt = 30.0
	external_view.handle_tilt_input(15.0)
	assert_eq(external_view.camera_tilt, 45.0, 
		"Tilt should increase by delta")


func test_camera_rotation_normalization():
	# Test rotation wraps around at 360
	external_view.camera_rotation = 350.0
	external_view.handle_rotation_input(20.0)
	assert_almost_eq(external_view.camera_rotation, 10.0, 0.01, 
		"Rotation should wrap around at 360")
	
	# Test rotation wraps around at 0
	external_view.camera_rotation = 10.0
	external_view.handle_rotation_input(-20.0)
	assert_almost_eq(external_view.camera_rotation, 350.0, 0.01, 
		"Rotation should wrap around at 0")


func test_orbit_camera_positioning():
	# Set known orbit parameters
	external_view.camera_distance = 100.0
	external_view.camera_tilt = 0.0  # Horizontal
	external_view.camera_rotation = 0.0  # North
	external_view.free_camera_mode = false
	
	# Update camera position
	external_view.update_camera_position()
	
	# Camera should be 100m north of submarine
	var expected_pos = Vector3(0, 0, 100)
	assert_almost_eq(camera.global_position.x, expected_pos.x, 0.1, 
		"Camera X position should match orbit calculation")
	assert_almost_eq(camera.global_position.z, expected_pos.z, 0.1, 
		"Camera Z position should match orbit calculation")


func test_free_camera_toggle():
	# Start in orbit mode
	assert_false(external_view.free_camera_mode, "Should start in orbit mode")
	
	# Toggle to free camera
	external_view.toggle_free_camera()
	assert_true(external_view.free_camera_mode, "Should switch to free camera mode")
	
	# Toggle back to orbit
	external_view.toggle_free_camera()
	assert_false(external_view.free_camera_mode, "Should switch back to orbit mode")


func test_fog_of_war_integration():
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
	
	# Get visible contacts through external view
	var visible_contacts = external_view.get_visible_contacts()
	
	# Only contact1 should be visible (detected AND identified)
	assert_eq(visible_contacts.size(), 1, "Only one contact should be visible")
	assert_eq(visible_contacts[0].id, 1, "Contact 1 should be visible")


func test_camera_looks_at_submarine_in_orbit_mode():
	# Set submarine at a known position
	simulation_state.submarine_position = Vector3(50, 0, 50)
	
	# Set camera in orbit mode
	external_view.free_camera_mode = false
	external_view.camera_distance = 100.0
	external_view.camera_rotation = 90.0  # East
	external_view.camera_tilt = 0.0
	
	# Update camera position
	external_view.update_camera_position()
	
	# Camera should be looking at submarine
	# We can verify this by checking the camera's forward direction
	var camera_forward = -camera.global_transform.basis.z
	var to_submarine = (simulation_state.submarine_position - camera.global_position).normalized()
	
	# Forward direction should be roughly aligned with direction to submarine
	var dot_product = camera_forward.dot(to_submarine)
	assert_gt(dot_product, 0.9, "Camera should be looking at submarine")
