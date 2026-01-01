extends GutTest

## Unit tests for AISystem
## Tests AI agent spawning, management, and integration with simulation state

var ai_system: Node
var simulation_state: SimulationState
var submarine_body: Node3D

func before_each():
	# Create simulation state
	simulation_state = SimulationState.new()
	add_child_autofree(simulation_state)
	
	# Create submarine body
	submarine_body = Node3D.new()
	submarine_body.name = "SubmarineBody"
	add_child_autofree(submarine_body)
	
	# Create AI system
	ai_system = load("res://scripts/ai/ai_system.gd").new()
	ai_system.name = "AISystem"
	add_child_autofree(ai_system)
	
	# Initialize AI system
	ai_system.set_simulation_state(simulation_state)
	ai_system.set_submarine_node(submarine_body)


func test_ai_system_initialization():
	assert_not_null(ai_system, "AISystem should be created")
	assert_eq(ai_system.get_agent_count(), 0, "AISystem should start with no agents")


func test_spawn_air_patrol():
	# Spawn a patrol
	var spawn_position = Vector3(100, 200, 100)
	var patrol_route: Array[Vector3] = [
		Vector3(100, 200, 100),
		Vector3(200, 200, 200),
		Vector3(100, 200, 300)
	]
	
	var agent = ai_system.spawn_air_patrol(spawn_position, patrol_route, true)
	
	assert_not_null(agent, "Agent should be spawned")
	assert_eq(ai_system.get_agent_count(), 1, "AISystem should have 1 agent")
	assert_eq(agent.patrol_waypoints.size(), 3, "Agent should have 3 waypoints")


func test_spawn_circular_patrol():
	# Spawn a circular patrol
	var center = Vector3(0, 0, 0)
	var radius = 500.0
	var num_waypoints = 6
	var altitude = 200.0
	
	var agent = ai_system.spawn_circular_patrol(center, radius, num_waypoints, altitude)
	
	assert_not_null(agent, "Agent should be spawned")
	assert_eq(ai_system.get_agent_count(), 1, "AISystem should have 1 agent")
	assert_eq(agent.patrol_waypoints.size(), num_waypoints, "Agent should have correct number of waypoints")
	
	# Verify waypoints are at correct altitude
	for waypoint in agent.patrol_waypoints:
		assert_almost_eq(waypoint.y, altitude, 0.1, "Waypoint should be at correct altitude")


func test_spawn_linear_patrol():
	# Spawn a linear patrol
	var start_point = Vector3(-500, 0, 0)
	var end_point = Vector3(500, 0, 0)
	var altitude = 150.0
	
	var agent = ai_system.spawn_linear_patrol(start_point, end_point, altitude)
	
	assert_not_null(agent, "Agent should be spawned")
	assert_eq(ai_system.get_agent_count(), 1, "AISystem should have 1 agent")
	assert_eq(agent.patrol_waypoints.size(), 2, "Agent should have 2 waypoints")


func test_spawn_grid_patrol():
	# Spawn a grid patrol
	var center = Vector3(0, 0, 0)
	var grid_size = Vector2(2, 2)  # 2x2 grid
	var spacing = 500.0
	var altitude = 200.0
	
	var agents = ai_system.spawn_grid_patrol(center, grid_size, spacing, altitude)
	
	assert_eq(agents.size(), 4, "Should spawn 4 agents in 2x2 grid")
	assert_eq(ai_system.get_agent_count(), 4, "AISystem should have 4 agents")


func test_remove_agent():
	# Spawn an agent
	var spawn_position = Vector3(100, 200, 100)
	var patrol_route: Array[Vector3] = [Vector3(100, 200, 100)]
	var agent = ai_system.spawn_air_patrol(spawn_position, patrol_route, true)
	
	assert_eq(ai_system.get_agent_count(), 1, "Should have 1 agent")
	
	# Remove the agent
	ai_system.remove_agent(agent)
	
	assert_eq(ai_system.get_agent_count(), 0, "Should have 0 agents after removal")


func test_clear_agents():
	# Spawn multiple agents
	for i in range(3):
		var spawn_position = Vector3(i * 100, 200, 0)
		var patrol_route: Array[Vector3] = [spawn_position]
		ai_system.spawn_air_patrol(spawn_position, patrol_route, true)
	
	assert_eq(ai_system.get_agent_count(), 3, "Should have 3 agents")
	
	# Clear all agents
	ai_system.clear_agents()
	
	assert_eq(ai_system.get_agent_count(), 0, "Should have 0 agents after clearing")


func test_agent_registered_as_contact():
	# Spawn an agent
	var spawn_position = Vector3(100, 200, 100)
	var patrol_route: Array[Vector3] = [spawn_position]
	var agent = ai_system.spawn_air_patrol(spawn_position, patrol_route, true)
	
	# Wait for physics process to update contact
	await wait_frames(2)
	
	# Verify agent is registered as a contact
	assert_true(agent.contact_id >= 0, "Agent should have a contact ID")
	
	var contact = simulation_state.get_contact(agent.contact_id)
	assert_not_null(contact, "Agent should be registered as a contact")
	assert_eq(contact.type, Contact.ContactType.AIRCRAFT, "Contact should be AIRCRAFT type")


func test_contact_detection_updates():
	# Set submarine position
	simulation_state.submarine_position = Vector3(0, 0, 0)
	
	# Spawn an agent far away (not detected)
	var spawn_position = Vector3(10000, 200, 0)  # 10km away
	var patrol_route: Array[Vector3] = [spawn_position]
	var agent = ai_system.spawn_air_patrol(spawn_position, patrol_route, true)
	
	# Wait for physics process to update contact
	await wait_frames(2)
	
	var contact = simulation_state.get_contact(agent.contact_id)
	assert_not_null(contact, "Contact should exist")
	assert_false(contact.detected, "Contact should not be detected at 10km")
	assert_false(contact.identified, "Contact should not be identified at 10km")
	
	# Move agent closer (within radar range but not visual range)
	agent.global_position = Vector3(3000, 200, 0)  # 3km away
	
	# Wait for physics process to update contact
	await wait_frames(2)
	
	contact = simulation_state.get_contact(agent.contact_id)
	assert_true(contact.detected, "Contact should be detected at 3km (radar range)")
	assert_false(contact.identified, "Contact should not be identified at 3km (beyond visual range)")
	
	# Move agent even closer (within visual range)
	agent.global_position = Vector3(1000, 200, 0)  # 1km away
	
	# Wait for physics process to update contact
	await wait_frames(2)
	
	contact = simulation_state.get_contact(agent.contact_id)
	assert_true(contact.detected, "Contact should be detected at 1km")
	assert_true(contact.identified, "Contact should be identified at 1km (visual range)")
