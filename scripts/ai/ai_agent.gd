class_name AIAgent extends Node3D

## AIAgent represents an individual AI-controlled entity (aircraft or helicopter)
## performing anti-submarine warfare operations. It uses a state machine to
## transition between patrol, search, and attack behaviors.

enum State {
	PATROL,   # Following waypoint route, scanning for submarine
	SEARCH,   # Investigating last known submarine position
	ATTACK    # Within attack range, executing attack patterns
}

## Current AI state
var current_state: State = State.PATROL

## Navigation agent for pathfinding
var navigation_agent: NavigationAgent3D

## Detection range in meters (2000m for aircraft, 5000m for radar)
@export var detection_range: float = 2000.0

## Attack range in meters (500m for dipping sonar)
@export var attack_range: float = 500.0

## Reference to the submarine (target)
var target: Node3D = null

## Patrol route waypoints
var patrol_waypoints: Array[Vector3] = []

## Current waypoint index in patrol route
var current_waypoint_index: int = 0

## Whether patrol route should loop
var patrol_loop: bool = true

## Patrol speed in m/s
var patrol_speed: float = 50.0  # ~100 knots for aircraft

## Last known submarine position
var last_known_target_position: Vector3 = Vector3.ZERO

## Search timeout timer (60 seconds)
var search_timer: float = 0.0
const SEARCH_TIMEOUT: float = 60.0

## Arrival threshold for waypoints (meters)
const WAYPOINT_ARRIVAL_THRESHOLD: float = 50.0

## Reference to simulation state for submarine detection
var simulation_state: SimulationState = null

## Contact ID for this AI agent (so it appears on tactical map)
var contact_id: int = -1

## Visual effects
var contrail_particles: GPUParticles3D = null
var shadow_projector: Decal = null


func _ready() -> void:
	# Create and configure navigation agent
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
	
	# Configure navigation agent
	navigation_agent.path_desired_distance = 10.0
	navigation_agent.target_desired_distance = WAYPOINT_ARRIVAL_THRESHOLD
	navigation_agent.max_speed = patrol_speed
	navigation_agent.avoidance_enabled = false  # Simple AI, no avoidance
	
	# Create visual effects
	_create_contrails()
	_create_shadow()
	
	# Start in patrol state
	transition_to_state(State.PATROL)


## Create contrail particle effects
func _create_contrails() -> void:
	contrail_particles = GPUParticles3D.new()
	add_child(contrail_particles)
	
	# Configure particle system for contrails
	contrail_particles.emitting = true
	contrail_particles.amount = 100
	contrail_particles.lifetime = 5.0
	contrail_particles.explosiveness = 0.0
	contrail_particles.randomness = 0.2
	contrail_particles.local_coords = false
	
	# Create particle material
	var particle_material = ParticleProcessMaterial.new()
	
	# Emission
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 5.0
	
	# Initial velocity
	particle_material.initial_velocity_min = 2.0
	particle_material.initial_velocity_max = 5.0
	
	# Gravity
	particle_material.gravity = Vector3(0, -2.0, 0)
	
	# Scale
	particle_material.scale_min = 2.0
	particle_material.scale_max = 4.0
	
	# Color (white/gray for contrails)
	particle_material.color = Color(0.9, 0.9, 0.9, 0.8)
	
	# Fade out over lifetime
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 0.8))
	gradient.add_point(1.0, Color(1, 1, 1, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_material.color_ramp = gradient_texture
	
	contrail_particles.process_material = particle_material
	
	# Create simple quad mesh for particles
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(1.0, 1.0)
	contrail_particles.draw_pass_1 = quad_mesh
	
	# Position contrails behind aircraft
	contrail_particles.position = Vector3(0, 0, -5)


## Create shadow projector on ocean surface
func _create_shadow() -> void:
	shadow_projector = Decal.new()
	add_child(shadow_projector)
	
	# Configure decal for shadow projection
	shadow_projector.size = Vector3(20, 100, 20)  # Width, height (projection distance), depth
	shadow_projector.cull_mask = 1  # Only project on layer 1 (ocean)
	
	# Create shadow texture (simple dark circle)
	var shadow_texture = GradientTexture2D.new()
	shadow_texture.gradient = Gradient.new()
	shadow_texture.gradient.add_point(0.0, Color(0, 0, 0, 0.5))
	shadow_texture.gradient.add_point(1.0, Color(0, 0, 0, 0.0))
	shadow_texture.fill = GradientTexture2D.FILL_RADIAL
	
	# Apply texture to decal
	shadow_projector.texture_albedo = shadow_texture
	
	# Position shadow projector to point downward
	shadow_projector.rotation_degrees = Vector3(-90, 0, 0)


## Transition to a new state
func transition_to_state(new_state: State) -> void:
	# Exit current state
	match current_state:
		State.PATROL:
			pass  # No cleanup needed
		State.SEARCH:
			search_timer = 0.0
		State.ATTACK:
			pass  # No cleanup needed
	
	# Enter new state
	current_state = new_state
	
	match new_state:
		State.PATROL:
			# Resume patrol route
			if patrol_waypoints.size() > 0:
				if navigation_agent and is_inside_tree():
					_set_next_patrol_waypoint()
				else:
					call_deferred("_set_next_patrol_waypoint")
		State.SEARCH:
			# Start search timer
			search_timer = 0.0
			# Navigate to last known target position
			if navigation_agent and is_inside_tree():
				navigation_agent.target_position = last_known_target_position
		State.ATTACK:
			# Attack behavior will track target directly
			pass


## Update AI behavior based on current state
func _physics_process(delta: float) -> void:
	if not simulation_state:
		return
	
	# Check for state transitions based on submarine detection
	_check_state_transitions()
	
	# Update behavior based on current state
	match current_state:
		State.PATROL:
			update_patrol(delta)
		State.SEARCH:
			update_search(delta)
		State.ATTACK:
			update_attack(delta)
	
	# Move toward navigation target
	_move_toward_target(delta)


## Check for state transitions based on submarine detection and range
func _check_state_transitions() -> void:
	var submarine_position = simulation_state.submarine_position
	var distance_to_submarine = global_position.distance_to(submarine_position)
	
	match current_state:
		State.PATROL:
			# Transition to SEARCH if submarine detected within detection range
			if distance_to_submarine <= detection_range:
				last_known_target_position = submarine_position
				transition_to_state(State.SEARCH)
		
		State.SEARCH:
			# Transition to ATTACK if within attack range
			if distance_to_submarine <= attack_range:
				transition_to_state(State.ATTACK)
			# Transition back to PATROL if search timeout expires
			elif search_timer >= SEARCH_TIMEOUT:
				transition_to_state(State.PATROL)
		
		State.ATTACK:
			# Transition back to SEARCH if submarine leaves attack range
			if distance_to_submarine > attack_range:
				last_known_target_position = submarine_position
				transition_to_state(State.SEARCH)


## Update patrol behavior - follow waypoint route and scan for submarine
func update_patrol(_delta: float) -> void:
	# Check if we've reached the current waypoint
	if navigation_agent and not navigation_agent.is_navigation_finished():
		return
	
	# Move to next waypoint
	_set_next_patrol_waypoint()


## Update search behavior - investigate last known position
func update_search(delta: float) -> void:
	# Increment search timer
	search_timer += delta
	
	# Update last known position if submarine is still in detection range
	var submarine_position = simulation_state.submarine_position
	var distance_to_submarine = global_position.distance_to(submarine_position)
	
	if distance_to_submarine <= detection_range:
		last_known_target_position = submarine_position
		navigation_agent.target_position = last_known_target_position
		# Reset search timer since we still have contact
		search_timer = 0.0


## Update attack behavior - execute dipping sonar pattern
func update_attack(_delta: float) -> void:
	# Track submarine position directly
	var submarine_position = simulation_state.submarine_position
	last_known_target_position = submarine_position
	
	# Navigate to position above submarine for dipping sonar
	# Offset slightly to simulate attack pattern
	var attack_position = submarine_position
	attack_position.y = 100.0  # Hover at 100m altitude
	
	navigation_agent.target_position = attack_position


## Set the next patrol waypoint
func _set_next_patrol_waypoint() -> void:
	if patrol_waypoints.size() == 0:
		return
	
	# Ensure navigation agent is ready
	if not navigation_agent or not is_inside_tree():
		return
	
	# Set navigation target to current waypoint
	navigation_agent.target_position = patrol_waypoints[current_waypoint_index]
	
	# Advance to next waypoint
	current_waypoint_index += 1
	
	# Handle looping or end of route
	if current_waypoint_index >= patrol_waypoints.size():
		if patrol_loop:
			current_waypoint_index = 0
		else:
			current_waypoint_index = patrol_waypoints.size() - 1


## Move toward navigation target
func _move_toward_target(delta: float) -> void:
	if not navigation_agent or navigation_agent.is_navigation_finished():
		return
	
	# Get next position from navigation agent
	var next_position = navigation_agent.get_next_path_position()
	
	# Calculate direction to next position
	var direction = (next_position - global_position).normalized()
	
	# Move toward next position
	var velocity = direction * patrol_speed * delta
	global_position += velocity
	
	# Rotate to face movement direction
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 5.0 * delta)


## Set patrol route for this AI agent
func set_patrol_route(waypoints: Array[Vector3], loop: bool = true) -> void:
	patrol_waypoints = waypoints
	patrol_loop = loop
	current_waypoint_index = 0
	
	# Only set navigation target if agent is ready and we have waypoints
	if waypoints.size() > 0 and current_state == State.PATROL:
		if navigation_agent and is_inside_tree():
			_set_next_patrol_waypoint()
		else:
			# Will be set when navigation agent is ready
			call_deferred("_set_next_patrol_waypoint")


## Set reference to simulation state
func set_simulation_state(state: SimulationState) -> void:
	simulation_state = state


## Set the target (submarine) to track
func set_target(target_node: Node3D) -> void:
	target = target_node


## Get current state as string (for debugging)
func get_state_name() -> String:
	match current_state:
		State.PATROL:
			return "PATROL"
		State.SEARCH:
			return "SEARCH"
		State.ATTACK:
			return "ATTACK"
	return "UNKNOWN"
