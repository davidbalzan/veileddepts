extends GutTest
## Unit tests for PeriscopeView class
## Tests periscope camera positioning, rotation, zoom, and underwater mode

var periscope_view: PeriscopeView
var simulation_state: SimulationState


func before_each():
	"""Setup test environment before each test."""
	# Create simulation state
	simulation_state = SimulationState.new()
	add_child_autofree(simulation_state)
	
	# Create periscope view
	periscope_view = PeriscopeView.new()
	add_child_autofree(periscope_view)
	
	# Create camera for periscope view
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	periscope_view.add_child(camera)
	
	# Manually set references (since we're not using the full scene tree)
	periscope_view.camera = camera
	periscope_view.simulation_state = simulation_state
	
	# Initialize camera FOV
	periscope_view.camera.fov = periscope_view.zoom_level


func test_camera_position_tracks_submarine_mast():
	"""Test that camera position is at submarine mast position.
	Requirement 5.1: Camera should be at submarine mast position."""
	# Set submarine position
	simulation_state.submarine_position = Vector3(100, 0, 200)
	
	# Update camera position
	periscope_view.update_camera_position()
	
	# Camera should be at submarine position + mast height
	var expected_position = Vector3(100, 10, 200)  # MAST_HEIGHT = 10
	assert_almost_eq(periscope_view.camera.global_position, expected_position, Vector3(0.01, 0.01, 0.01),
		"Camera should be at submarine mast position")


func test_rotation_input_updates_camera():
	"""Test that rotation input updates camera rotation.
	Requirement 5.2: Rotate periscope based on player input."""
	# Initial rotation should be 0
	assert_eq(periscope_view.periscope_rotation, 0.0, "Initial rotation should be 0")
	
	# Apply rotation input
	periscope_view.handle_rotation_input(45.0)
	
	# Rotation should be updated
	assert_eq(periscope_view.periscope_rotation, 45.0, "Rotation should be updated to 45 degrees")
	
	# Camera rotation should match
	var expected_rotation_rad = deg_to_rad(45.0)
	assert_almost_eq(periscope_view.camera.rotation.y, expected_rotation_rad, 0.01,
		"Camera rotation should match periscope rotation")


func test_rotation_wraps_around_360():
	"""Test that rotation wraps around at 360 degrees."""
	# Set rotation to 350
	periscope_view.periscope_rotation = 350.0
	
	# Add 20 degrees
	periscope_view.handle_rotation_input(20.0)
	
	# Should wrap to 10 degrees
	assert_eq(periscope_view.periscope_rotation, 10.0, "Rotation should wrap around 360 degrees")


func test_rotation_wraps_around_0():
	"""Test that rotation wraps around at 0 degrees."""
	# Set rotation to 10
	periscope_view.periscope_rotation = 10.0
	
	# Subtract 20 degrees
	periscope_view.handle_rotation_input(-20.0)
	
	# Should wrap to 350 degrees
	assert_eq(periscope_view.periscope_rotation, 350.0, "Rotation should wrap around 0 degrees")


func test_zoom_input_updates_fov():
	"""Test that zoom input updates camera FOV.
	Requirement 5.3: Adjust field of view within operational limits (15° to 90°)."""
	# Initial FOV should be 60
	assert_eq(periscope_view.zoom_level, 60.0, "Initial FOV should be 60 degrees")
	
	# Zoom in (decrease FOV)
	periscope_view.handle_zoom_input(10.0)
	
	# FOV should decrease
	assert_eq(periscope_view.zoom_level, 50.0, "FOV should decrease when zooming in")
	assert_eq(periscope_view.camera.fov, 50.0, "Camera FOV should match zoom level")


func test_zoom_clamped_to_min():
	"""Test that zoom is clamped to minimum FOV (15 degrees)."""
	# Set zoom to near minimum
	periscope_view.zoom_level = 20.0
	periscope_view.camera.fov = 20.0
	
	# Try to zoom in beyond minimum
	periscope_view.handle_zoom_input(10.0)
	
	# Should be clamped to minimum
	assert_eq(periscope_view.zoom_level, 15.0, "Zoom should be clamped to minimum FOV")
	assert_eq(periscope_view.camera.fov, 15.0, "Camera FOV should be clamped to minimum")


func test_zoom_clamped_to_max():
	"""Test that zoom is clamped to maximum FOV (90 degrees)."""
	# Set zoom to near maximum
	periscope_view.zoom_level = 85.0
	periscope_view.camera.fov = 85.0
	
	# Try to zoom out beyond maximum
	periscope_view.handle_zoom_input(-10.0)
	
	# Should be clamped to maximum
	assert_eq(periscope_view.zoom_level, 90.0, "Zoom should be clamped to maximum FOV")
	assert_eq(periscope_view.camera.fov, 90.0, "Camera FOV should be clamped to maximum")


func test_is_underwater_returns_false_at_surface():
	"""Test that is_underwater returns false when submarine is at surface."""
	# Set submarine at surface
	simulation_state.submarine_depth = 0.0
	
	# Should not be underwater
	assert_false(periscope_view.is_underwater(), "Should not be underwater at surface")


func test_is_underwater_returns_false_at_periscope_depth():
	"""Test that is_underwater returns false at periscope depth."""
	# Set submarine at periscope depth
	simulation_state.submarine_depth = 10.0
	
	# Should not be underwater (exactly at threshold)
	assert_false(periscope_view.is_underwater(), "Should not be underwater at periscope depth")


func test_is_underwater_returns_true_below_periscope_depth():
	"""Test that is_underwater returns true when below periscope depth.
	Requirement 5.5: Display underwater environment when depth > 10m."""
	# Set submarine below periscope depth
	simulation_state.submarine_depth = 15.0
	
	# Should be underwater
	assert_true(periscope_view.is_underwater(), "Should be underwater below periscope depth")


func test_underwater_mode_switches_environment():
	"""Test that underwater mode switches camera environment."""
	# Setup underwater environment
	periscope_view.setup_underwater_environment()
	
	# Start at surface
	simulation_state.submarine_depth = 0.0
	periscope_view.update_underwater_mode()
	
	# Should not have underwater environment
	assert_null(periscope_view.camera.environment, "Camera should not have underwater environment at surface")
	
	# Go underwater
	simulation_state.submarine_depth = 20.0
	periscope_view.update_underwater_mode()
	
	# Should have underwater environment
	assert_not_null(periscope_view.camera.environment, "Camera should have underwater environment when submerged")
	assert_eq(periscope_view.camera.environment, periscope_view.underwater_environment,
		"Camera should use underwater environment")
