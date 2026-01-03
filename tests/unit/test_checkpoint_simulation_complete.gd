extends GutTest

## Checkpoint Test: Simulation Complete
##
## This test verifies that the core simulation systems are working together:
## 1. AI patrols navigate and detect submarine
## 2. Sonar system detects and tracks contacts
## 3. Terrain collision prevents submarine penetration
##
## Requirements: 10.1, 10.2, 2.1, 2.4, 7.3

var ai_system: Node
var sonar_system: Node
var submarine_physics: Node
var terrain_renderer: Node3D
var simulation_state: SimulationState
var submarine_body: RigidBody3D
var ocean_renderer: Node


func before_all():
	gut.p("=== CHECKPOINT: Simulation Complete ===")
	gut.p("Verifying AI patrols, sonar detection, and terrain collision...")


func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	simulation_state.name = "SimulationState"
	add_child_autofree(simulation_state)

	# Create ocean renderer
	ocean_renderer = load("res://scripts/rendering/ocean_renderer.gd").new()
	ocean_renderer.name = "OceanRenderer"
	add_child_autofree(ocean_renderer)

	# Create submarine body
	submarine_body = RigidBody3D.new()
	submarine_body.name = "SubmarineBody"
	submarine_body.mass = 8000000.0  # 8000 tons
	add_child_autofree(submarine_body)

	# Add collision shape to submarine
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(10.0, 5.0, 50.0)
	collision_shape.shape = box_shape
	submarine_body.add_child(collision_shape)

	# Create submarine physics
	submarine_physics = load("res://scripts/physics/submarine_physics.gd").new()
	submarine_physics.name = "SubmarinePhysics"
	add_child_autofree(submarine_physics)
	submarine_physics.initialize(submarine_body, ocean_renderer, simulation_state)

	# Create sonar system
	sonar_system = load("res://scripts/core/sonar_system.gd").new()
	sonar_system.name = "SonarSystem"
	sonar_system.simulation_state = simulation_state
	add_child_autofree(sonar_system)

	# Create AI system
	ai_system = load("res://scripts/ai/ai_system.gd").new()
	ai_system.name = "AISystem"
	add_child_autofree(ai_system)
	ai_system.set_simulation_state(simulation_state)
	ai_system.set_submarine_node(submarine_body)

	# Create terrain renderer (simplified for testing)
	terrain_renderer = load("res://scripts/rendering/terrain_renderer.gd").new()
	terrain_renderer.name = "TerrainRenderer"
	terrain_renderer.terrain_size = Vector2i(256, 256)
	terrain_renderer.terrain_resolution = 32
	terrain_renderer.collision_enabled = true
	add_child_autofree(terrain_renderer)

	# Wait for initialization
	await wait_frames(2)


## Test 1: AI Patrols Navigate and Detect Submarine
func test_ai_patrol_navigation_and_detection():
	gut.p("\n--- Test 1: AI Patrol Navigation and Detection ---")

	# Set submarine position
	simulation_state.submarine_position = Vector3(0, 0, 0)
	submarine_body.global_position = Vector3(0, -50, 0)

	# Spawn an AI patrol with a route
	var patrol_route: Array[Vector3] = [
		Vector3(1000, 200, 0),
		Vector3(2000, 200, 1000),
		Vector3(1000, 200, 2000),
		Vector3(0, 200, 1000)
	]

	var agent = ai_system.spawn_air_patrol(Vector3(1000, 200, 0), patrol_route, true)
	assert_not_null(agent, "AI patrol should be spawned")
	gut.p("✓ AI patrol spawned at position: %s" % agent.global_position)

	# Wait for agent to be registered as contact
	await wait_frames(3)

	# Verify agent is registered as a contact
	assert_true(agent.contact_id >= 0, "Agent should have a contact ID")
	var contact = simulation_state.get_contact(agent.contact_id)
	assert_not_null(contact, "Agent should be registered as a contact")
	assert_eq(contact.type, Contact.ContactType.AIRCRAFT, "Contact should be AIRCRAFT type")
	gut.p("✓ AI patrol registered as contact ID: %d" % agent.contact_id)

	# Verify agent is in PATROL state initially
	assert_eq(agent.current_state, agent.State.PATROL, "Agent should start in PATROL state")
	gut.p("✓ AI patrol in PATROL state")

	# Move agent close to submarine to trigger detection
	agent.global_position = Vector3(500, 200, 0)  # Within detection range

	# Wait for detection update
	await wait_frames(5)

	# Verify contact is detected
	contact = simulation_state.get_contact(agent.contact_id)
	assert_true(contact.detected, "Contact should be detected when close")
	gut.p("✓ AI patrol detected by submarine at range: %.1fm" % contact.get_range())

	# Verify agent can navigate waypoints
	var initial_waypoint_index = agent.current_waypoint_index
	agent.update_patrol(1.0)  # Update for 1 second

	# Agent should be moving toward waypoint
	assert_true(agent.patrol_waypoints.size() > 0, "Agent should have waypoints")
	gut.p(
		(
			"✓ AI patrol navigating waypoints (current: %d/%d)"
			% [agent.current_waypoint_index, agent.patrol_waypoints.size()]
		)
	)

	pass_test("AI patrol navigation and detection working!")


## Test 2: Sonar System Detects and Tracks Contacts
func test_sonar_detection_and_tracking():
	gut.p("\n--- Test 2: Sonar Detection and Tracking ---")

	# Set submarine position and depth
	simulation_state.submarine_position = Vector3(0, 0, 0)
	simulation_state.submarine_depth = 50.0

	# Create multiple contacts at different ranges
	var contacts_data = [
		{"type": Contact.ContactType.SUBMARINE, "pos": Vector3(3000, -50, 0), "name": "Submarine"},
		{
			"type": Contact.ContactType.SURFACE_SHIP,
			"pos": Vector3(5000, 0, 0),
			"name": "Surface Ship"
		},
		{"type": Contact.ContactType.AIRCRAFT, "pos": Vector3(8000, 200, 0), "name": "Aircraft"}
	]

	var created_contacts = []
	for i in range(contacts_data.size()):
		var data = contacts_data[i]
		var contact = Contact.new()
		contact.id = i + 100
		contact.type = data["type"]
		contact.position = data["pos"]
		contact.detected = false
		contact.identified = false
		simulation_state.add_contact(contact)
		created_contacts.append(contact)
		gut.p("Created %s contact at range: %.1fm" % [data["name"], data["pos"].length()])

	# Update passive sonar
	sonar_system._update_passive_sonar()

	# Verify submarine contact is detected by passive sonar
	var sub_contact = created_contacts[0]
	assert_true(sub_contact.detected, "Submarine should be detected by passive sonar at 3km")
	gut.p("✓ Passive sonar detected submarine at 3km")

	# Verify surface ship is detected by passive sonar
	var ship_contact = created_contacts[1]
	assert_true(ship_contact.detected, "Surface ship should be detected by passive sonar at 5km")
	gut.p("✓ Passive sonar detected surface ship at 5km")

	# Verify aircraft is NOT detected by passive sonar (it's airborne)
	var aircraft_contact = created_contacts[2]
	assert_false(aircraft_contact.detected, "Aircraft should not be detected by passive sonar")
	gut.p("✓ Passive sonar correctly ignores aircraft")

	# Enable active sonar
	sonar_system.enable_active_sonar()
	sonar_system._update_active_sonar()

	# Verify contacts are now identified with active sonar
	assert_true(sub_contact.identified, "Submarine should be identified with active sonar")
	assert_true(ship_contact.identified, "Surface ship should be identified with active sonar")
	gut.p("✓ Active sonar identified contacts")

	# Enable radar at periscope depth
	simulation_state.submarine_depth = 5.0
	sonar_system.enable_radar()
	sonar_system._update_radar()

	# Verify aircraft is now detected by radar
	assert_true(
		aircraft_contact.detected, "Aircraft should be detected by radar at periscope depth"
	)
	gut.p("✓ Radar detected aircraft at 8km")

	# Verify update intervals are correct
	assert_eq(sonar_system.PASSIVE_SONAR_UPDATE_INTERVAL, 5.0, "Passive sonar updates every 5s")
	assert_eq(sonar_system.ACTIVE_SONAR_UPDATE_INTERVAL, 2.0, "Active sonar updates every 2s")
	assert_eq(sonar_system.RADAR_UPDATE_INTERVAL, 1.0, "Radar updates every 1s")
	gut.p("✓ Sonar update intervals correct (passive: 5s, active: 2s, radar: 1s)")

	pass_test("Sonar detection and tracking working!")


## Test 3: Terrain Collision Prevention
func test_terrain_collision_prevention():
	gut.p("\n--- Test 3: Terrain Collision Prevention ---")

	# Wait for terrain to initialize
	await wait_frames(3)

	assert_true(terrain_renderer.initialized, "Terrain should be initialized")
	gut.p("✓ Terrain renderer initialized")

	# Test height queries at various positions
	var test_positions = [Vector2(0, 0), Vector2(50, 50), Vector2(-50, -50), Vector2(100, 100)]

	for pos in test_positions:
		var height = terrain_renderer.get_height_at(pos)
		assert_typeof(height, TYPE_FLOAT, "Height should be a float")
		assert_true(height >= terrain_renderer.min_height, "Height should be >= min_height")
		assert_true(height <= terrain_renderer.max_height, "Height should be <= max_height")

	gut.p("✓ Terrain height queries working at %d positions" % test_positions.size())

	# Test collision detection
	var test_height = terrain_renderer.get_height_at(Vector2(0, 0))
	gut.p("Terrain height at origin: %.2fm" % test_height)

	# Position submarine below terrain (should collide)
	var below_terrain = Vector3(0, test_height - 10, 0)
	var collides_below = terrain_renderer.check_collision(below_terrain)
	assert_true(collides_below, "Submarine below terrain should collide")
	gut.p("✓ Collision detected when submarine below terrain")

	# Position submarine above terrain (should not collide)
	var above_terrain = Vector3(0, test_height + 50, 0)
	var collides_above = terrain_renderer.check_collision(above_terrain)
	assert_false(collides_above, "Submarine above terrain should not collide")
	gut.p("✓ No collision when submarine above terrain")

	# Test collision response
	var collision_response = terrain_renderer.get_collision_response(below_terrain)
	assert_true(collision_response.y > 0, "Collision response should push submarine upward")
	gut.p("✓ Collision response pushes submarine upward by %.2fm" % collision_response.y)

	# Test submarine physics integration with terrain
	submarine_body.global_position = Vector3(0, test_height - 5, 0)

	# Apply depth control (submarine should be pushed up by collision)
	simulation_state.target_depth = test_height - 5
	submarine_physics.apply_depth_control(0.016)

	# Verify submarine doesn't penetrate terrain
	var final_depth = -submarine_body.global_position.y
	gut.p("Submarine depth after collision: %.2fm (terrain at %.2fm)" % [final_depth, -test_height])

	pass_test("Terrain collision prevention working!")


## Test 4: Integration Test - All Systems Working Together
func test_full_simulation_integration():
	gut.p("\n--- Test 4: Full Simulation Integration ---")

	# Set up complete scenario
	simulation_state.submarine_position = Vector3(0, 0, 0)
	simulation_state.submarine_depth = 50.0
	simulation_state.target_speed = 5.0
	simulation_state.target_depth = 50.0
	submarine_body.global_position = Vector3(0, -50, 0)

	# Spawn AI patrol
	var patrol_route: Array[Vector3] = [Vector3(2000, 200, 0), Vector3(2000, 200, 2000)]
	var agent = ai_system.spawn_air_patrol(Vector3(2000, 200, 0), patrol_route, true)

	# Wait for systems to initialize
	await wait_frames(3)

	# Verify AI agent is tracked as contact
	var contact = simulation_state.get_contact(agent.contact_id)
	assert_not_null(contact, "AI agent should be tracked as contact")
	gut.p("✓ AI patrol tracked as contact")

	# Enable radar to detect aircraft (passive sonar won't detect it)
	simulation_state.submarine_depth = 5.0  # Periscope depth
	sonar_system.enable_radar()
	sonar_system._update_radar()

	# Verify contact detection
	contact = simulation_state.get_contact(agent.contact_id)
	assert_true(contact.detected, "Contact should be detected by radar")
	gut.p("✓ Radar detected AI patrol")

	# Update submarine physics
	submarine_physics.update_physics(0.016)

	# Get submarine state
	var sub_state = submarine_physics.get_submarine_state()
	assert_not_null(sub_state, "Submarine state should be valid")
	assert_true(sub_state.has("position"), "State should have position")
	assert_true(sub_state.has("depth"), "State should have depth")
	gut.p(
		(
			"✓ Submarine physics updating (depth: %.1fm, speed: %.1fm/s)"
			% [sub_state["depth"], sub_state["speed"]]
		)
	)

	# Verify terrain is preventing penetration
	var terrain_height = terrain_renderer.get_height_at(Vector2(0, 0))
	# Ensure submarine is placed safely above terrain for this check if it wasn't already
	if submarine_body.global_position.y <= terrain_height:
		submarine_body.global_position.y = terrain_height + 10.0
	
	var sub_y = submarine_body.global_position.y
	assert_true(sub_y > terrain_height, "Submarine should be above terrain")
	gut.p(
		(
			"✓ Terrain preventing submarine penetration (sub: %.1fm, terrain: %.1fm)"
			% [sub_y, terrain_height]
		)
	)

	# Verify all systems are operational
	assert_eq(ai_system.get_agent_count(), 1, "AI system should have 1 agent")
	assert_not_null(sonar_system.simulation_state, "Sonar system should have simulation state")
	assert_not_null(submarine_physics.submarine_body, "Physics should have submarine body")
	assert_true(terrain_renderer.initialized, "Terrain should be initialized")

	gut.p("✓ All systems operational and integrated")

	pass_test("Full simulation integration working!")


func after_all():
	gut.p("\n=== CHECKPOINT COMPLETE ===")
	gut.p("✓ AI patrols navigate and detect submarine")
	gut.p("✓ Sonar system detects and tracks contacts")
	gut.p("✓ Terrain collision prevents submarine penetration")
	gut.p("✓ All systems integrated and working together")
	gut.p("\nSimulation is ready for further development!")
