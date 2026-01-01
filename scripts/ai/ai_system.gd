class_name AISystem extends Node

## AISystem manages multiple AI agents (aircraft and helicopters) performing
## anti-submarine warfare operations. It handles spawning, updating, and
## coordinating AI agents with the simulation state.

## Preload AIAgent class
const AIAgentScript = preload("res://scripts/ai/ai_agent.gd")

## Array of active AI agents
var ai_agents: Array = []

## Reference to simulation state for submarine detection
var simulation_state: SimulationState = null

## Reference to submarine node (target for AI agents)
var submarine_node: Node3D = null

## Next agent ID for contact tracking
var _next_agent_id: int = 1000  # Start at 1000 to avoid collision with other contacts


func _ready() -> void:
	# AI system will be initialized by main scene
	pass


## Set reference to simulation state
func set_simulation_state(state: SimulationState) -> void:
	simulation_state = state
	
	# Update all existing agents
	for agent in ai_agents:
		agent.set_simulation_state(state)


## Set reference to submarine node
func set_submarine_node(submarine: Node3D) -> void:
	submarine_node = submarine
	
	# Update all existing agents
	for agent in ai_agents:
		agent.set_target(submarine)


## Spawn an air patrol at the specified position with patrol route
## Returns the spawned AIAgent
func spawn_air_patrol(spawn_position: Vector3, patrol_route: Array[Vector3], loop: bool = true):
	# Create new AI agent
	var agent = AIAgentScript.new()
	agent.name = "AIAgent_%d" % _next_agent_id
	
	# Add agent to scene first so it's in the tree
	add_child(agent)
	ai_agents.append(agent)
	
	# Now we can safely set global position and configure
	agent.global_position = spawn_position
	
	# Configure agent
	agent.set_simulation_state(simulation_state)
	agent.set_target(submarine_node)
	agent.set_patrol_route(patrol_route, loop)
	
	# Register agent as a contact in simulation state
	if simulation_state:
		var contact = Contact.new()
		contact.id = _next_agent_id
		contact.type = Contact.ContactType.AIRCRAFT
		contact.position = spawn_position
		contact.velocity = Vector3.ZERO
		contact.detected = false  # Not detected initially
		contact.identified = false
		
		simulation_state.add_contact(contact)
		agent.contact_id = _next_agent_id
	
	_next_agent_id += 1
	
	return agent


## Update all AI agents
func _physics_process(_delta: float) -> void:
	# Update contact positions in simulation state
	for agent in ai_agents:
		if simulation_state and agent.contact_id >= 0:
			var contact = simulation_state.get_contact(agent.contact_id)
			if contact:
				# Update contact position to match agent position
				contact.position = agent.global_position
				contact.velocity = Vector3.ZERO  # Simplified - could calculate from movement
				
				# Determine detection status based on range to submarine
				if simulation_state.submarine_position:
					var distance = agent.global_position.distance_to(simulation_state.submarine_position)
					
					# Aircraft are detected by radar at long range (5000m)
					# They are identified visually at shorter range (2000m)
					contact.detected = distance <= 5000.0
					contact.identified = distance <= 2000.0


## Remove an AI agent
func remove_agent(agent) -> void:
	if agent in ai_agents:
		# Remove contact from simulation state
		if simulation_state and agent.contact_id >= 0:
			simulation_state.remove_contact(agent.contact_id)
		
		# Remove agent from scene
		ai_agents.erase(agent)
		agent.queue_free()


## Remove all AI agents
func clear_agents() -> void:
	for agent in ai_agents:
		# Remove contact from simulation state
		if simulation_state and agent.contact_id >= 0:
			simulation_state.remove_contact(agent.contact_id)
		
		# Remove agent from scene
		agent.queue_free()
	
	ai_agents.clear()


## Get number of active AI agents
func get_agent_count() -> int:
	return ai_agents.size()


## Get all AI agents
func get_agents() -> Array:
	return ai_agents


## Spawn a simple patrol pattern around a center point
## Creates a circular patrol route with specified radius and number of waypoints
func spawn_circular_patrol(center: Vector3, radius: float, num_waypoints: int = 4, altitude: float = 200.0):
	var patrol_route: Array[Vector3] = []
	
	# Generate waypoints in a circle
	for i in range(num_waypoints):
		var angle = (float(i) / float(num_waypoints)) * TAU  # TAU = 2*PI
		var x = center.x + radius * cos(angle)
		var z = center.z + radius * sin(angle)
		var waypoint = Vector3(x, altitude, z)
		patrol_route.append(waypoint)
	
	# Spawn at first waypoint
	var spawn_position = patrol_route[0] if patrol_route.size() > 0 else center
	
	return spawn_air_patrol(spawn_position, patrol_route, true)


## Spawn a linear patrol pattern between two points
## Creates a back-and-forth patrol route
func spawn_linear_patrol(start_point: Vector3, end_point: Vector3, altitude: float = 200.0):
	var patrol_route: Array[Vector3] = []
	
	# Set altitude for both points
	start_point.y = altitude
	end_point.y = altitude
	
	# Create route: start -> end -> start (for looping)
	patrol_route.append(start_point)
	patrol_route.append(end_point)
	
	return spawn_air_patrol(start_point, patrol_route, true)


## Spawn multiple patrols in a grid pattern
## Useful for creating a search pattern over an area
func spawn_grid_patrol(center: Vector3, grid_size: Vector2, spacing: float, altitude: float = 200.0) -> Array[AIAgent]:
	var agents: Array[AIAgent] = []
	
	var half_width = (grid_size.x - 1) * spacing * 0.5
	var half_depth = (grid_size.y - 1) * spacing * 0.5
	
	for x in range(int(grid_size.x)):
		for z in range(int(grid_size.y)):
			var offset_x = (x * spacing) - half_width
			var offset_z = (z * spacing) - half_depth
			
			var patrol_center = center + Vector3(offset_x, 0, offset_z)
			var agent = spawn_circular_patrol(patrol_center, spacing * 0.3, 4, altitude)
			agents.append(agent)
	
	return agents
