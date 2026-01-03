extends GutTest

## Unit tests for submarine class preset configurations
## Tests Requirements 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7

var physics: SubmarinePhysicsV2
var submarine_body: RigidBody3D
var mock_ocean_renderer
var mock_simulation_state


func before_each():
	# Create mock submarine body
	submarine_body = RigidBody3D.new()
	add_child_autofree(submarine_body)

	# Create mock ocean renderer (minimal implementation)
	mock_ocean_renderer = Node3D.new()
	mock_ocean_renderer.set_script(load("res://scripts/rendering/ocean_renderer.gd"))
	add_child_autofree(mock_ocean_renderer)

	# Create mock simulation state
	mock_simulation_state = Node.new()
	mock_simulation_state.set("target_speed", 0.0)
	mock_simulation_state.set("target_heading", 0.0)
	mock_simulation_state.set("target_depth", 0.0)
	add_child_autofree(mock_simulation_state)

	# Create physics system
	physics = SubmarinePhysicsV2.new()
	add_child_autofree(physics)
	physics.initialize(submarine_body, mock_ocean_renderer, mock_simulation_state)


func test_get_available_classes():
	# Requirement 13.5: get_available_classes should return all class names
	var classes = physics.get_available_classes()

	assert_eq(classes.size(), 5, "Should have 5 submarine classes")
	assert_true(classes.has("Los_Angeles_Class"), "Should include Los Angeles Class")
	assert_true(classes.has("Ohio_Class"), "Should include Ohio Class")
	assert_true(classes.has("Virginia_Class"), "Should include Virginia Class")
	assert_true(classes.has("Seawolf_Class"), "Should include Seawolf Class")
	assert_true(classes.has("Default"), "Should include Default class")


func test_load_submarine_class_los_angeles():
	# Requirement 13.4: load_submarine_class should load predefined configurations
	var success = physics.load_submarine_class("Los_Angeles_Class")

	assert_true(success, "Should successfully load Los Angeles Class")
	assert_eq(physics.mass, 6000.0, "Mass should be 6000 tons")
	assert_eq(physics.max_speed, 15.4, "Max speed should be 15.4 m/s (30 knots)")
	assert_eq(physics.max_depth, 450.0, "Max depth should be 450 meters")


func test_load_submarine_class_ohio():
	# Requirement 13.4: load_submarine_class should load predefined configurations
	var success = physics.load_submarine_class("Ohio_Class")

	assert_true(success, "Should successfully load Ohio Class")
	assert_eq(physics.mass, 18000.0, "Mass should be 18000 tons")
	assert_eq(physics.max_speed, 12.9, "Max speed should be 12.9 m/s (25 knots)")
	assert_eq(physics.max_depth, 300.0, "Max depth should be 300 meters")


func test_load_submarine_class_virginia():
	# Requirement 13.4: load_submarine_class should load predefined configurations
	var success = physics.load_submarine_class("Virginia_Class")

	assert_true(success, "Should successfully load Virginia Class")
	assert_eq(physics.mass, 7800.0, "Mass should be 7800 tons")
	assert_eq(physics.max_speed, 12.9, "Max speed should be 12.9 m/s (25 knots)")
	assert_eq(physics.max_depth, 490.0, "Max depth should be 490 meters")


func test_load_submarine_class_seawolf():
	# Requirement 13.4: load_submarine_class should load predefined configurations
	var success = physics.load_submarine_class("Seawolf_Class")

	assert_true(success, "Should successfully load Seawolf Class")
	assert_eq(physics.mass, 9100.0, "Mass should be 9100 tons")
	assert_eq(physics.max_speed, 18.0, "Max speed should be 18.0 m/s (35 knots)")
	assert_eq(physics.max_depth, 600.0, "Max depth should be 600 meters")


func test_load_submarine_class_default():
	# Requirement 13.4: load_submarine_class should load predefined configurations
	var success = physics.load_submarine_class("Default")

	assert_true(success, "Should successfully load Default class")
	assert_eq(physics.mass, 8000.0, "Mass should be 8000 tons")
	assert_eq(physics.max_speed, 10.3, "Max speed should be 10.3 m/s (20 knots)")
	assert_eq(physics.max_depth, 400.0, "Max depth should be 400 meters")


func test_load_invalid_submarine_class():
	# Requirement 13.4: load_submarine_class should return false for invalid class
	var success = physics.load_submarine_class("NonExistent_Class")

	assert_false(success, "Should return false for invalid class name")


func test_configure_submarine_class_updates_mass():
	# Requirement 13.3: configure_submarine_class should update parameters
	var custom_config = {
		"class_name": "Test Submarine", "mass": 5000.0, "max_speed": 20.0, "max_depth": 500.0
	}

	physics.configure_submarine_class(custom_config)

	assert_eq(physics.mass, 5000.0, "Mass should be updated to 5000 tons")
	assert_eq(physics.max_speed, 20.0, "Max speed should be updated to 20.0 m/s")
	assert_eq(physics.max_depth, 500.0, "Max depth should be updated to 500 meters")


func test_submarine_body_mass_updated():
	# Requirement 13.6: Component parameters should be updated when class is loaded
	physics.load_submarine_class("Seawolf_Class")

	# Mass should be converted from tons to kg
	assert_eq(
		submarine_body.mass, 9100000.0, "Submarine body mass should be 9100000 kg (9100 tons)"
	)


func test_class_configurations_include_all_parameters():
	# Requirement 13.1: Each class should include all required parameters
	var classes := ["Los_Angeles_Class", "Ohio_Class", "Virginia_Class", "Seawolf_Class", "Default"]

	for class_name_str in classes:
		var config = physics.SUBMARINE_CLASSES[class_name_str]

		# Check main parameters
		assert_true(config.has("class_name"), "%s should have class_name" % class_name_str)
		assert_true(config.has("mass"), "%s should have mass" % class_name_str)
		assert_true(config.has("max_speed"), "%s should have max_speed" % class_name_str)
		assert_true(config.has("max_depth"), "%s should have max_depth" % class_name_str)

		# Check component configurations
		assert_true(config.has("propulsion"), "%s should have propulsion config" % class_name_str)
		assert_true(config.has("drag"), "%s should have drag config" % class_name_str)
		assert_true(config.has("rudder"), "%s should have rudder config" % class_name_str)
		assert_true(config.has("dive_planes"), "%s should have dive_planes config" % class_name_str)
		assert_true(config.has("ballast"), "%s should have ballast config" % class_name_str)
		assert_true(config.has("buoyancy"), "%s should have buoyancy config" % class_name_str)


func test_turn_rate_varies_by_class():
	# Requirement 13.4: Different classes should have different turn rates
	physics.load_submarine_class("Ohio_Class")
	var ohio_turn_rate = physics.rudder_system.max_turn_rate

	physics.load_submarine_class("Seawolf_Class")
	var seawolf_turn_rate = physics.rudder_system.max_turn_rate

	# Ohio is larger and slower turning (3.0 deg/s)
	# Seawolf is smaller and faster turning (7.0 deg/s)
	assert_lt(ohio_turn_rate, seawolf_turn_rate, "Ohio should turn slower than Seawolf")
