class_name SubmarinePhysics extends Node
## Submarine physics system handling movement, buoyancy, and hydrodynamics
##
## This system simulates realistic submarine behavior including:
## - Buoyancy forces based on ocean wave heights
## - Hydrodynamic drag proportional to velocity squared
## - Propulsion to reach target speed
## - Depth control through ballast simulation
## - Speed-dependent maneuverability

# References to other systems
var submarine_body: RigidBody3D
var ocean_renderer: OceanRenderer
var simulation_state: SimulationState

# Physics parameters (from design document)
const MASS: float = 8000.0  # tons (converted to kg in calculations)
const DRAG_COEFFICIENT: float = 0.04
const MAX_SPEED: float = 10.3  # 20 knots in m/s
const MAX_DEPTH: float = 400.0  # meters
const DEPTH_CHANGE_RATE: float = 5.0  # m/s
const TURN_RATE_FAST: float = 3.0  # degrees/second at full speed
const TURN_RATE_SLOW: float = 10.0  # degrees/second at slow speed
const SLOW_SPEED_THRESHOLD: float = 2.0  # m/s

# Buoyancy parameters
const WATER_DENSITY: float = 1025.0  # kg/m^3 (seawater)
const SUBMARINE_VOLUME: float = 8000.0  # m^3 (approximate displacement)
const BUOYANCY_COEFFICIENT: float = 1.0

# Propulsion parameters
const PROPULSION_FORCE_MAX: float = 500000.0  # Newtons
const PROPULSION_RESPONSE_TIME: float = 2.0  # seconds to reach target speed

# Depth control parameters
const BALLAST_FORCE_MAX: float = 200000.0  # Newtons
const DEPTH_CONTROL_RESPONSE_TIME: float = 3.0  # seconds

# Current physics state
var current_propulsion_force: float = 0.0
var current_ballast_force: float = 0.0

func _ready() -> void:
	# Physics will be initialized when connected to other systems
	pass

## Initialize the physics system with required references
func initialize(p_submarine_body: RigidBody3D, p_ocean_renderer: OceanRenderer, p_simulation_state: SimulationState) -> void:
	submarine_body = p_submarine_body
	ocean_renderer = p_ocean_renderer
	simulation_state = p_simulation_state
	
	if not submarine_body:
		push_error("SubmarinePhysics: submarine_body is null")
		return
	
	if not ocean_renderer:
		push_error("SubmarinePhysics: ocean_renderer is null")
		return
	
	if not simulation_state:
		push_error("SubmarinePhysics: simulation_state is null")
		return
	
	# Set submarine mass
	submarine_body.mass = MASS * 1000.0  # Convert tons to kg
	
	print("SubmarinePhysics initialized")

## Apply buoyancy force based on ocean wave heights and submarine displacement
## Validates: Requirements 11.1, 11.5
func apply_buoyancy(_delta: float) -> void:
	if not submarine_body or not ocean_renderer:
		return
	
	var sub_pos = submarine_body.global_position
	var wave_height = ocean_renderer.get_wave_height(Vector2(sub_pos.x, sub_pos.z))
	
	# Calculate water level at submarine position
	var water_level = wave_height
	
	# Calculate submersion depth
	var submersion_depth = water_level - sub_pos.y
	
	# Calculate buoyancy force using Archimedes' principle
	# F_buoyancy = ρ * V * g * submersion_ratio
	var submersion_ratio = clamp(submersion_depth / 10.0, 0.0, 1.0)  # Assume 10m submarine height
	
	var buoyancy_force = WATER_DENSITY * SUBMARINE_VOLUME * 9.81 * submersion_ratio * BUOYANCY_COEFFICIENT
	
	# Apply upward force
	submarine_body.apply_central_force(Vector3.UP * buoyancy_force)
	
	# For surface submarines (depth < 5m), apply wave-induced motion
	if simulation_state.submarine_depth < 5.0:
		# Apply vertical wave motion
		var wave_force = Vector3.UP * (wave_height - sub_pos.y) * 50000.0
		submarine_body.apply_central_force(wave_force)

## Apply hydrodynamic drag based on velocity squared
## Validates: Requirements 11.3
func apply_drag(_delta: float) -> void:
	if not submarine_body:
		return
	
	var velocity = submarine_body.linear_velocity
	var speed = velocity.length()
	
	if speed < 0.01:
		return  # No drag at very low speeds
	
	# Calculate drag force: F_drag = 0.5 * ρ * v^2 * C_d * A
	# Simplified: F_drag = k * v^2 where k includes all constants
	var depth = simulation_state.submarine_depth
	
	# Water density increases slightly with depth (simplified)
	var depth_density_factor = 1.0 + (depth / 1000.0) * 0.05
	
	# Drag force magnitude
	var drag_magnitude = 0.5 * WATER_DENSITY * depth_density_factor * speed * speed * DRAG_COEFFICIENT * 100.0
	
	# Apply drag force opposite to velocity direction
	var drag_force = -velocity.normalized() * drag_magnitude
	submarine_body.apply_central_force(drag_force)

## Apply propulsion force to reach target speed
## Validates: Requirements 11.4
func apply_propulsion(delta: float) -> void:
	if not submarine_body or not simulation_state:
		return
	
	var current_speed = submarine_body.linear_velocity.length()
	var target_speed = simulation_state.target_speed
	
	# Calculate speed error
	var speed_error = target_speed - current_speed
	
	# Proportional control for propulsion
	var propulsion_ratio = clamp(speed_error / MAX_SPEED, -1.0, 1.0)
	
	# Smooth propulsion force changes
	var target_propulsion = propulsion_ratio * PROPULSION_FORCE_MAX
	current_propulsion_force = lerp(current_propulsion_force, target_propulsion, delta / PROPULSION_RESPONSE_TIME)
	
	# Apply propulsion force in heading direction
	var heading_rad = deg_to_rad(simulation_state.submarine_heading)
	var forward_direction = Vector3(sin(heading_rad), 0.0, cos(heading_rad))
	
	submarine_body.apply_central_force(forward_direction * current_propulsion_force)
	
	# Apply turning force based on speed (slower = tighter turns)
	_apply_turning_force(delta)

## Apply turning force based on speed-dependent maneuverability
## Validates: Requirements 11.4
func _apply_turning_force(delta: float) -> void:
	if not submarine_body or not simulation_state:
		return
	
	var current_speed = submarine_body.linear_velocity.length()
	
	# Calculate current heading from velocity
	var velocity_2d = Vector2(submarine_body.linear_velocity.x, submarine_body.linear_velocity.z)
	if velocity_2d.length() < 0.1:
		return  # No turning at very low speeds
	
	var current_heading_rad = atan2(velocity_2d.x, velocity_2d.y)
	var current_heading_deg = rad_to_deg(current_heading_rad)
	
	# Normalize to 0-360
	while current_heading_deg < 0:
		current_heading_deg += 360.0
	while current_heading_deg >= 360:
		current_heading_deg -= 360.0
	
	# Calculate heading error
	var target_heading = simulation_state.submarine_heading
	var heading_error = target_heading - current_heading_deg
	
	# Normalize heading error to [-180, 180]
	while heading_error > 180:
		heading_error -= 360
	while heading_error < -180:
		heading_error += 360
	
	# Calculate turn rate based on speed (inverse relationship)
	var speed_ratio = clamp(current_speed / MAX_SPEED, 0.0, 1.0)
	var max_turn_rate = lerp(TURN_RATE_SLOW, TURN_RATE_FAST, speed_ratio)
	
	# Apply turn rate limit
	var turn_amount = clamp(heading_error, -max_turn_rate * delta, max_turn_rate * delta)
	
	# Apply torque to turn the submarine
	if abs(heading_error) > 1.0:  # Only turn if error is significant
		var torque_magnitude = turn_amount * 100000.0  # Scale factor for torque
		submarine_body.apply_torque(Vector3.UP * torque_magnitude)

## Apply depth control forces to reach target depth
## Validates: Requirements 11.1
func apply_depth_control(delta: float) -> void:
	if not submarine_body or not simulation_state:
		return
	
	var current_depth = -submarine_body.global_position.y  # Depth is negative Y
	var target_depth = simulation_state.target_depth
	
	# Calculate depth error
	var depth_error = target_depth - current_depth
	
	# Proportional control for ballast
	var ballast_ratio = clamp(depth_error / 50.0, -1.0, 1.0)  # 50m is the control range
	
	# Smooth ballast force changes
	var target_ballast = ballast_ratio * BALLAST_FORCE_MAX
	current_ballast_force = lerp(current_ballast_force, target_ballast, delta / DEPTH_CONTROL_RESPONSE_TIME)
	
	# Apply vertical force (negative = down, positive = up)
	# Ballast force is negative to go down, positive to go up
	submarine_body.apply_central_force(Vector3.DOWN * current_ballast_force)
	
	# Clamp depth to operational limits
	if current_depth < 0.0:
		# Force submarine to stay at or below surface
		submarine_body.global_position.y = min(submarine_body.global_position.y, 0.0)
		if submarine_body.linear_velocity.y > 0:
			submarine_body.linear_velocity.y = 0
	elif current_depth > MAX_DEPTH:
		# Emergency surface if exceeding max depth
		submarine_body.global_position.y = -MAX_DEPTH
		if submarine_body.linear_velocity.y < 0:
			submarine_body.linear_velocity.y = 0
		push_warning("Submarine exceeded maximum depth!")

## Update all physics forces
## Called from _physics_process
func update_physics(delta: float) -> void:
	if not submarine_body:
		return
	
	# Apply all physics forces
	apply_buoyancy(delta)
	apply_drag(delta)
	apply_propulsion(delta)
	apply_depth_control(delta)

## Get current submarine state for synchronization
func get_submarine_state() -> Dictionary:
	if not submarine_body:
		return {}
	
	var pos = submarine_body.global_position
	var vel = submarine_body.linear_velocity
	
	# Calculate depth (negative Y position)
	var depth = -pos.y
	
	# Calculate speed
	var speed = vel.length()
	
	# Calculate heading from velocity
	var velocity_2d = Vector2(vel.x, vel.z)
	var heading = 0.0
	if velocity_2d.length() > 0.1:
		heading = rad_to_deg(atan2(velocity_2d.x, velocity_2d.y))
		while heading < 0:
			heading += 360.0
		while heading >= 360:
			heading -= 360.0
	else:
		# Use simulation state heading if not moving
		heading = simulation_state.submarine_heading if simulation_state else 0.0
	
	return {
		"position": pos,
		"velocity": vel,
		"depth": depth,
		"heading": heading,
		"speed": speed
	}
