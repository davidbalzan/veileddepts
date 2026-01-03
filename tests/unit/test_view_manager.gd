extends GutTest
## Unit tests for ViewManager
##
## Tests view switching, camera activation, and state preservation

var view_manager: ViewManager
var simulation_state: SimulationState


func before_each():
	# Create ViewManager instance
	view_manager = ViewManager.new()

	# Create SimulationState instance
	simulation_state = SimulationState.new()

	# Create mock cameras
	view_manager.tactical_map_camera = Camera2D.new()
	view_manager.periscope_camera = Camera3D.new()
	view_manager.external_camera = Camera3D.new()

	# Create mock view containers
	view_manager.tactical_map_view = CanvasLayer.new()
	view_manager.periscope_view = Node3D.new()
	view_manager.external_view = Node3D.new()

	# Set simulation state reference
	view_manager.simulation_state = simulation_state

	# Add nodes to tree
	add_child_autofree(view_manager.tactical_map_camera)
	add_child_autofree(view_manager.periscope_camera)
	add_child_autofree(view_manager.external_camera)
	add_child_autofree(view_manager.tactical_map_view)
	add_child_autofree(view_manager.periscope_view)
	add_child_autofree(view_manager.external_view)
	add_child_autofree(simulation_state)


func test_initial_view_is_tactical_map():
	assert_eq(
		view_manager.current_view,
		ViewManager.ViewType.TACTICAL_MAP,
		"Initial view should be TACTICAL_MAP"
	)


func test_switch_to_periscope_view():
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	assert_eq(
		view_manager.current_view,
		ViewManager.ViewType.PERISCOPE,
		"Current view should be PERISCOPE after switch"
	)


func test_switch_to_external_view():
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)
	assert_eq(
		view_manager.current_view,
		ViewManager.ViewType.EXTERNAL,
		"Current view should be EXTERNAL after switch"
	)


func test_switch_back_to_tactical_map():
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
	assert_eq(
		view_manager.current_view,
		ViewManager.ViewType.TACTICAL_MAP,
		"Should be able to switch back to TACTICAL_MAP"
	)


func test_get_active_camera_tactical():
	view_manager.current_view = ViewManager.ViewType.TACTICAL_MAP
	var camera = view_manager.get_active_camera()
	assert_eq(
		camera,
		view_manager.tactical_map_camera,
		"Active camera should be tactical_map_camera when in TACTICAL_MAP view"
	)


func test_get_active_camera_periscope():
	view_manager.current_view = ViewManager.ViewType.PERISCOPE
	var camera = view_manager.get_active_camera()
	assert_eq(
		camera,
		view_manager.periscope_camera,
		"Active camera should be periscope_camera when in PERISCOPE view"
	)


func test_get_active_camera_external():
	view_manager.current_view = ViewManager.ViewType.EXTERNAL
	var camera = view_manager.get_active_camera()
	assert_eq(
		camera,
		view_manager.external_camera,
		"Active camera should be external_camera when in EXTERNAL view"
	)


func test_periscope_camera_positioned_at_mast():
	# Set submarine position
	simulation_state.submarine_position = Vector3(100, 0, 200)
	simulation_state.submarine_heading = 45.0

	# Switch to periscope view (triggers camera positioning)
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)

	# Check camera is at mast position (submarine + 10m height)
	var expected_position = Vector3(100, 10, 200)
	assert_almost_eq(
		view_manager.periscope_camera.global_position,
		expected_position,
		Vector3(0.1, 0.1, 0.1),
		"Periscope camera should be at submarine mast position"
	)


func test_external_camera_orbits_submarine():
	# Set submarine position
	simulation_state.submarine_position = Vector3(50, 0, 100)

	# Switch to external view (triggers camera positioning)
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)

	# Check camera is positioned away from submarine
	var distance = view_manager.external_camera.global_position.distance_to(
		simulation_state.submarine_position
	)
	assert_gt(distance, 50.0, "External camera should be positioned away from submarine")
	assert_lt(distance, 150.0, "External camera should not be too far from submarine")


func test_submarine_state_preserved_during_view_switch():
	# Set submarine state
	simulation_state.submarine_position = Vector3(10, 0, 20)
	simulation_state.submarine_speed = 5.0
	simulation_state.submarine_depth = 50.0
	simulation_state.submarine_heading = 90.0

	var original_position = simulation_state.submarine_position
	var original_speed = simulation_state.submarine_speed
	var original_depth = simulation_state.submarine_depth
	var original_heading = simulation_state.submarine_heading

	# Switch views
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)

	# Verify state is preserved
	assert_eq(
		simulation_state.submarine_position,
		original_position,
		"Submarine position should be preserved during view switches"
	)
	assert_eq(
		simulation_state.submarine_speed,
		original_speed,
		"Submarine speed should be preserved during view switches"
	)
	assert_eq(
		simulation_state.submarine_depth,
		original_depth,
		"Submarine depth should be preserved during view switches"
	)
	assert_eq(
		simulation_state.submarine_heading,
		original_heading,
		"Submarine heading should be preserved during view switches"
	)


func test_no_switch_when_already_in_target_view():
	view_manager.current_view = ViewManager.ViewType.TACTICAL_MAP
	view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
	assert_eq(
		view_manager.current_view,
		ViewManager.ViewType.TACTICAL_MAP,
		"Should remain in TACTICAL_MAP when switching to same view"
	)
