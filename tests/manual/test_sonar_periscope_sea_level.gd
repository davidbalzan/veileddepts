extends GutTest

## Test sonar and periscope adaptation to dynamic sea level
## Validates Requirements 9.2, 9.4

var sonar_system: SonarSystem
var periscope_view: PeriscopeView
var simulation_state: SimulationState
var ocean_renderer: OceanRenderer


func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	simulation_state.submarine_position = Vector3(0, -10, 0)  # 10m below default sea level
	add_child_autofree(simulation_state)
	
	# Create ocean renderer (minimal setup)
	ocean_renderer = OceanRenderer.new()
	add_child_autofree(ocean_renderer)
	
	# Create sonar system
	sonar_system = SonarSystem.new()
	sonar_system.simulation_state = simulation_state
	add_child_autofree(sonar_system)


func test_sonar_depth_calculation_uses_sea_level():
	"""Test that sonar uses current sea level for depth calculations (Requirement 9.4)"""
	# Create a test contact
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SUBMARINE
	contact.position = Vector3(100, -20, 0)  # 20m below default sea level
	simulation_state.add_contact(contact)
	
	# With default sea level (0m), submarine at Y=-10 is 10m deep
	# Contact at Y=-20 is 20m deep
	# Both should be detectable by passive sonar (10km range)
	
	# Update passive sonar
	sonar_system._update_passive_sonar()
	
	# Contact should be detected
	assert_true(contact.detected, "Contact should be detected with default sea level")
	
	# Raise sea level to +15m
	SeaLevelManager.set_sea_level(SeaLevelManager.meters_to_normalized(15.0))
	await get_tree().process_frame
	
	# Now submarine at Y=-10 is 25m deep (15 - (-10))
	# Contact at Y=-20 is 35m deep (15 - (-20))
	# Still within passive sonar range
	
	# Update simulation state depth
	simulation_state.submarine_position = Vector3(0, -10, 0)
	
	# Update passive sonar again
	sonar_system._update_passive_sonar()
	
	# Contact should still be detected
	assert_true(contact.detected, "Contact should be detected with raised sea level")
	
	# Reset sea level
	SeaLevelManager.reset_to_default()


func test_radar_periscope_depth_uses_sea_level():
	"""Test that radar periscope depth check uses current sea level (Requirement 9.2)"""
	# Create a surface ship contact
	var contact = Contact.new()
	contact.id = 2
	contact.type = Contact.ContactType.SURFACE_SHIP
	contact.position = Vector3(1000, 0, 0)  # At default sea level
	simulation_state.add_contact(contact)
	
	# Enable radar
	sonar_system.enable_radar()
	
	# Set submarine at periscope depth (5m below default sea level)
	simulation_state.submarine_position = Vector3(0, -5, 0)
	
	# Update radar
	sonar_system._update_radar()
	
	# Radar should work at periscope depth
	assert_true(contact.detected, "Radar should work at periscope depth with default sea level")
	
	# Raise sea level to +10m
	SeaLevelManager.set_sea_level(SeaLevelManager.meters_to_normalized(10.0))
	await get_tree().process_frame
	
	# Submarine at Y=-5 is now 15m deep (10 - (-5))
	# This is deeper than periscope depth (10m), so radar shouldn't work
	simulation_state.submarine_position = Vector3(0, -5, 0)
	contact.detected = false  # Reset detection
	
	# Update radar
	sonar_system._update_radar()
	
	# Radar should NOT work when too deep
	assert_false(contact.detected, "Radar should not work when deeper than periscope depth")
	
	# Move submarine to new periscope depth (5m below new sea level = Y=5)
	simulation_state.submarine_position = Vector3(0, 5, 0)
	contact.detected = false  # Reset detection
	
	# Update radar
	sonar_system._update_radar()
	
	# Radar should work again at new periscope depth
	assert_true(contact.detected, "Radar should work at periscope depth with raised sea level")
	
	# Reset sea level
	SeaLevelManager.reset_to_default()


func test_periscope_underwater_detection_uses_sea_level():
	"""Test that periscope underwater detection uses current sea level (Requirement 9.2)"""
	# Create periscope view
	periscope_view = PeriscopeView.new()
	periscope_view.simulation_state = simulation_state
	periscope_view.ocean_renderer = ocean_renderer
	add_child_autofree(periscope_view)
	
	# Create camera
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	periscope_view.add_child(camera)
	periscope_view.camera = camera
	
	# Set camera at Y = -5 (5m below default sea level)
	camera.global_position = Vector3(0, -5, 0)
	
	# Check if underwater with default sea level
	var is_underwater = periscope_view.is_underwater()
	assert_true(is_underwater, "Should be underwater at 5m below default sea level")
	
	# Raise sea level to +10m
	SeaLevelManager.set_sea_level(SeaLevelManager.meters_to_normalized(10.0))
	await get_tree().process_frame
	
	# Camera at Y=-5 is now 15m below new sea level
	is_underwater = periscope_view.is_underwater()
	assert_true(is_underwater, "Should be underwater at 15m below raised sea level")
	
	# Move camera above new sea level
	camera.global_position = Vector3(0, 11, 0)  # 1m above new sea level
	periscope_view.is_underwater_mode = false  # Reset state
	
	# Check if underwater
	is_underwater = periscope_view.is_underwater()
	assert_false(is_underwater, "Should not be underwater above raised sea level")
	
	# Reset sea level
	SeaLevelManager.reset_to_default()

