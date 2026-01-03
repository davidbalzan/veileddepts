extends GutTest

## Unit tests for SonarSystem
## Tests detection ranges, update frequencies, and thermal layer effects

var sonar_system: Node
var simulation_state: SimulationState


func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	simulation_state.name = "SimulationState"
	add_child_autofree(simulation_state)

	# Create sonar system
	sonar_system = load("res://scripts/core/sonar_system.gd").new()
	sonar_system.name = "SonarSystem"
	sonar_system.simulation_state = simulation_state
	add_child_autofree(sonar_system)

	# Set submarine position
	simulation_state.submarine_position = Vector3.ZERO
	simulation_state.submarine_depth = 50.0


func test_passive_sonar_detects_submarine_in_range():
	# Create a submarine contact within passive sonar range
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SUBMARINE
	contact.position = Vector3(5000, -50, 0)  # 5km away, at 50m depth
	contact.detected = false
	simulation_state.add_contact(contact)

	# Force update passive sonar
	sonar_system._update_passive_sonar()

	# Contact should be detected
	assert_true(contact.detected, "Submarine should be detected by passive sonar")


func test_passive_sonar_does_not_detect_aircraft():
	# Create an aircraft contact
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.AIRCRAFT
	contact.position = Vector3(5000, 200, 0)  # 5km away, at 200m altitude
	contact.detected = false
	simulation_state.add_contact(contact)

	# Force update passive sonar
	sonar_system._update_passive_sonar()

	# Aircraft should not be detected by passive sonar
	assert_false(contact.detected, "Aircraft should not be detected by passive sonar")


func test_active_sonar_detects_and_identifies():
	# Enable active sonar
	sonar_system.enable_active_sonar()

	# Create a surface ship contact within active sonar range
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SURFACE_SHIP
	contact.position = Vector3(3000, 0, 0)  # 3km away, at surface
	contact.detected = false
	contact.identified = false
	simulation_state.add_contact(contact)

	# Force update active sonar
	sonar_system._update_active_sonar()

	# Contact should be detected and identified
	assert_true(contact.detected, "Surface ship should be detected by active sonar")
	assert_true(contact.identified, "Surface ship should be identified by active sonar")


func test_radar_only_works_at_periscope_depth():
	# Enable radar
	sonar_system.enable_radar()

	# Create an aircraft contact within radar range
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.AIRCRAFT
	contact.position = Vector3(10000, 200, 0)  # 10km away, at 200m altitude
	contact.detected = false
	simulation_state.add_contact(contact)

	# Test at deep depth (radar should not work)
	simulation_state.submarine_depth = 50.0
	sonar_system._update_radar()
	assert_false(contact.detected, "Radar should not work at 50m depth")

	# Test at periscope depth (radar should work)
	simulation_state.submarine_depth = 5.0
	sonar_system._update_radar()
	assert_true(contact.detected, "Radar should work at periscope depth")


func test_thermal_layer_reduces_detection_range():
	# Set thermal layer at 100m depth with 50% strength
	sonar_system.set_thermal_layer(100.0, 0.5)

	# Submarine at 50m depth
	simulation_state.submarine_depth = 50.0

	# Create a contact below thermal layer
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SUBMARINE
	contact.position = Vector3(7000, -150, 0)  # 7km away, at 150m depth (below thermal layer)
	contact.detected = false
	simulation_state.add_contact(contact)

	# Force update passive sonar
	sonar_system._update_passive_sonar()

	# Contact should not be detected due to thermal layer reducing range
	# Base range is 10km, but thermal layer reduces it by 50% to 5km
	# Contact at 7km should not be detected
	assert_false(contact.detected, "Contact beyond thermal layer should not be detected")


func test_thermal_layer_does_not_affect_same_side():
	# Set thermal layer at 100m depth with 50% strength
	sonar_system.set_thermal_layer(100.0, 0.5)

	# Submarine at 50m depth (above thermal layer)
	simulation_state.submarine_depth = 50.0

	# Create a contact also above thermal layer
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SUBMARINE
	contact.position = Vector3(7000, -50, 0)  # 7km away, at 50m depth (above thermal layer)
	contact.detected = false
	simulation_state.add_contact(contact)

	# Force update passive sonar
	sonar_system._update_passive_sonar()

	# Contact should be detected (no thermal layer between them)
	assert_true(contact.detected, "Contact on same side of thermal layer should be detected")


func test_update_intervals_are_correct():
	# Test that update intervals match requirements
	assert_eq(
		sonar_system.PASSIVE_SONAR_UPDATE_INTERVAL,
		5.0,
		"Passive sonar should update every 5 seconds"
	)
	assert_eq(
		sonar_system.ACTIVE_SONAR_UPDATE_INTERVAL, 2.0, "Active sonar should update every 2 seconds"
	)
	assert_eq(sonar_system.RADAR_UPDATE_INTERVAL, 1.0, "Radar should update every 1 second")


func test_detection_type_returns_correct_type():
	# Create a surface ship contact
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SURFACE_SHIP
	contact.position = Vector3(3000, 0, 0)
	contact.detected = true
	simulation_state.add_contact(contact)

	# Test with only passive sonar
	var detection_type = sonar_system.get_detection_type(contact)
	assert_eq(
		detection_type, sonar_system.DetectionType.PASSIVE_SONAR, "Should return passive sonar type"
	)

	# Enable active sonar
	sonar_system.enable_active_sonar()
	detection_type = sonar_system.get_detection_type(contact)
	assert_eq(
		detection_type, sonar_system.DetectionType.ACTIVE_SONAR, "Should return active sonar type"
	)

	# Enable radar at periscope depth
	sonar_system.enable_radar()
	simulation_state.submarine_depth = 5.0
	detection_type = sonar_system.get_detection_type(contact)
	assert_eq(detection_type, sonar_system.DetectionType.RADAR, "Should return radar type")


func test_contact_out_of_range_not_detected():
	# Create a contact far beyond passive sonar range
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SUBMARINE
	contact.position = Vector3(20000, -50, 0)  # 20km away (beyond 10km passive range)
	contact.detected = false
	simulation_state.add_contact(contact)

	# Force update passive sonar
	sonar_system._update_passive_sonar()

	# Contact should not be detected
	assert_false(contact.detected, "Contact beyond detection range should not be detected")


func test_is_contact_in_range_checks_all_sensors():
	# Create a surface ship contact
	var contact = Contact.new()
	contact.id = 1
	contact.type = Contact.ContactType.SURFACE_SHIP
	contact.position = Vector3(15000, 0, 0)  # 15km away
	simulation_state.add_contact(contact)

	# Should not be in passive sonar range (10km)
	assert_false(sonar_system.is_contact_in_range(contact), "Should not be in passive sonar range")

	# Enable radar at periscope depth (20km range)
	sonar_system.enable_radar()
	simulation_state.submarine_depth = 5.0
	assert_true(sonar_system.is_contact_in_range(contact), "Should be in radar range")
