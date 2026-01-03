extends GutTest
## Unit tests for FogOfWarSystem class
##
## Tests visibility rules for contacts based on detection and identification status

var fog_of_war: FogOfWarSystem
var simulation_state: SimulationState


func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	simulation_state.name = "SimulationState"
	add_child_autofree(simulation_state)

	# Create fog of war system
	fog_of_war = FogOfWarSystem.new()
	fog_of_war.name = "FogOfWarSystem"
	fog_of_war.simulation_state = simulation_state
	add_child_autofree(fog_of_war)


func test_fog_of_war_initializes():
	assert_not_null(fog_of_war, "FogOfWarSystem should be created")
	assert_not_null(fog_of_war.simulation_state, "SimulationState should be assigned")


func test_contact_visible_when_detected_and_identified():
	# Create contact that is both detected and identified
	var contact = Contact.new()
	contact.detected = true
	contact.identified = true

	# Should be visible
	assert_true(
		fog_of_war.is_contact_visible(contact),
		"Contact should be visible when detected AND identified"
	)


func test_contact_not_visible_when_only_detected():
	# Create contact that is detected but not identified
	var contact = Contact.new()
	contact.detected = true
	contact.identified = false

	# Should NOT be visible
	assert_false(
		fog_of_war.is_contact_visible(contact), "Contact should NOT be visible when only detected"
	)


func test_contact_not_visible_when_only_identified():
	# Create contact that is identified but not detected
	var contact = Contact.new()
	contact.detected = false
	contact.identified = true

	# Should NOT be visible
	assert_false(
		fog_of_war.is_contact_visible(contact), "Contact should NOT be visible when only identified"
	)


func test_contact_not_visible_when_neither_detected_nor_identified():
	# Create contact that is neither detected nor identified
	var contact = Contact.new()
	contact.detected = false
	contact.identified = false

	# Should NOT be visible
	assert_false(
		fog_of_war.is_contact_visible(contact),
		"Contact should NOT be visible when neither detected nor identified"
	)


func test_null_contact_not_visible():
	# Null contact should not be visible
	assert_false(fog_of_war.is_contact_visible(null), "Null contact should not be visible")


func test_get_visible_contacts_filters_correctly():
	# Create multiple contacts with different visibility states
	var contact1 = Contact.new()
	contact1.id = 1
	contact1.detected = true
	contact1.identified = true  # Visible

	var contact2 = Contact.new()
	contact2.id = 2
	contact2.detected = true
	contact2.identified = false  # Not visible

	var contact3 = Contact.new()
	contact3.id = 3
	contact3.detected = false
	contact3.identified = true  # Not visible

	var contact4 = Contact.new()
	contact4.id = 4
	contact4.detected = true
	contact4.identified = true  # Visible

	# Add contacts to simulation state
	simulation_state.add_contact(contact1)
	simulation_state.add_contact(contact2)
	simulation_state.add_contact(contact3)
	simulation_state.add_contact(contact4)

	# Get visible contacts
	var visible_contacts = fog_of_war.get_visible_contacts()

	# Should have exactly 2 visible contacts
	assert_eq(visible_contacts.size(), 2, "Should have 2 visible contacts")

	# Check that the correct contacts are visible
	var visible_ids = []
	for contact in visible_contacts:
		visible_ids.append(contact.id)

	assert_has(visible_ids, 1, "Contact 1 should be visible")
	assert_has(visible_ids, 4, "Contact 4 should be visible")
	assert_does_not_have(visible_ids, 2, "Contact 2 should not be visible")
	assert_does_not_have(visible_ids, 3, "Contact 3 should not be visible")


func test_environment_always_visible():
	# Environmental elements should always be visible
	assert_true(fog_of_war.is_environment_visible("terrain"), "Terrain should always be visible")
	assert_true(fog_of_war.is_environment_visible("ocean"), "Ocean should always be visible")
	assert_true(
		fog_of_war.is_environment_visible("atmosphere"), "Atmosphere should always be visible"
	)
	assert_true(fog_of_war.is_environment_visible("sealife"), "Sealife should always be visible")
	assert_true(
		fog_of_war.is_environment_visible(""), "Any environmental element should be visible"
	)


func test_visibility_changes_with_detection_status():
	# Create contact
	var contact = Contact.new()
	contact.detected = false
	contact.identified = false

	# Initially not visible
	assert_false(fog_of_war.is_contact_visible(contact), "Contact should not be visible initially")

	# Detect but don't identify - still not visible
	contact.detected = true
	assert_false(
		fog_of_war.is_contact_visible(contact), "Contact should not be visible when only detected"
	)

	# Identify - now visible
	contact.identified = true
	assert_true(
		fog_of_war.is_contact_visible(contact),
		"Contact should be visible when detected and identified"
	)

	# Lose detection - not visible again
	contact.detected = false
	assert_false(
		fog_of_war.is_contact_visible(contact),
		"Contact should not be visible when detection is lost"
	)
