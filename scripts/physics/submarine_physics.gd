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

# Physics parameters (from design document) - can be overridden per submarine class
var mass: float = 8000.0  # tons (converted to kg in calculations)
var drag_coefficient: float = 0.5
var max_speed: float = 10.3  # 20 knots in m/s
var max_depth: float = 400.0  # meters
var depth_change_rate: float = 5.0  # m/s
var turn_rate_fast: float = 3.0  # degrees/second at full speed
var turn_rate_slow: float = 10.0  # degrees/second at slow speed

# Buoyancy parameters
var water_density: float = 1025.0  # kg/m^3 (seawater)
var submarine_volume: float = 8000.0  # m^3 (approximate displacement)
var buoyancy_coefficient: float = 1.0  # Balanced for neutral buoyancy at surface

# Propulsion parameters
var propulsion_force_max: float = 35000000.0  # Newtons - 35 MN
var propulsion_response_time: float = 2.0  # seconds to reach target speed

# Drag parameters
var forward_drag: float = 2000.0  # Forward drag coefficient
var sideways_drag: float = 800000.0  # Sideways drag coefficient (400x forward)

# Steering parameters
var rudder_effectiveness: float = 250000.0  # Rudder turning force multiplier
var stabilizer_effectiveness: float = 10000.0  # Forward stabilizer resistance
var mid_stabilizer_effectiveness: float = 250000.0  # Mid-body slip resistance

# Depth control parameters
var ballast_force_max: float = 50000000.0  # Newtons
var depth_control_response_time: float = 5.0  # seconds

# Current physics state
var current_propulsion_force: float = 0.0
var current_ballast_force: float = 0.0

# PID control state for depth
var depth_error_integral: float = 0.0
var previous_depth_error: float = 0.0

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
	submarine_body.mass = mass * 1000.0  # Convert tons to kg
	
	print("SubmarinePhysics initialized")


## Configure physics parameters for a specific submarine class
## Call this after initialize() to override default parameters
func configure_submarine_class(config: Dictionary) -> void:
	if config.has("mass"):
		mass = config["mass"]
		if submarine_body:
			submarine_body.mass = mass * 1000.0
	
	if config.has("max_speed"):
		max_speed = config["max_speed"]
	
	if config.has("max_depth"):
		max_depth = config["max_depth"]
	
	if config.has("propulsion_force_max"):
		propulsion_force_max = config["propulsion_force_max"]
	
	if config.has("forward_drag"):
		forward_drag = config["forward_drag"]
	
	if config.has("sideways_drag"):
		sideways_drag = config["sideways_drag"]
	
	if config.has("rudder_effectiveness"):
		rudder_effectiveness = config["rudder_effectiveness"]
	
	if config.has("stabilizer_effectiveness"):
		stabilizer_effectiveness = config["stabilizer_effectiveness"]
	
	if config.has("mid_stabilizer_effectiveness"):
		mid_stabilizer_effectiveness = config["mid_stabilizer_effectiveness"]
	
	if config.has("ballast_force_max"):
		ballast_force_max = config["ballast_force_max"]
	
	if config.has("submarine_volume"):
		submarine_volume = config["submarine_volume"]
	
	print("SubmarinePhysics configured for class: ", config.get("class_name", "Custom"))

## Apply buoyancy force based on ocean wave heights and submarine displacement
## Validates: Requirements 11.1, 11.5
func apply_buoyancy(delta: float) -> void:
	if not submarine_body:
		return
	
	var sub_pos = submarine_body.global_position
	var current_depth = -sub_pos.y  # Depth is positive going down
	
	# Get wave height at submarine position
	var wave_height: float = 0.0
	if ocean_renderer and ocean_renderer.initialized:
		wave_height = ocean_renderer.get_wave_height(Vector2(sub_pos.x, sub_pos.z))
	
	# Calculate water level at submarine position (wave height is relative to y=0)
	var water_level = wave_height
	
	# Calculate how deep the submarine center is below the water surface
	# Positive = underwater, Negative = above water
	var depth_below_surface = water_level - sub_pos.y
	
	# Submarine hull height (approximate)
	const HULL_HEIGHT: float = 5.0  # meters
	const HALF_HULL: float = HULL_HEIGHT / 2.0
	
	# Calculate submersion ratio based on how much of the hull is underwater
	var submersion_ratio = clamp((depth_below_surface + HALF_HULL) / HULL_HEIGHT, 0.0, 1.0)
	
	# Calculate buoyancy force using Archimedes' principle
	var displaced_volume = submarine_volume * submersion_ratio
	var buoyancy_force = water_density * displaced_volume * 9.81 * buoyancy_coefficient
	
	# Apply buoyancy force
	submarine_body.apply_central_force(Vector3.UP * buoyancy_force)
	
	# Get target depth from simulation state
	var target_depth = simulation_state.target_depth if simulation_state else 0.0
	
	# Calculate wave influence factor - decreases with depth and target depth
	# At surface (depth=0, target=0): full wave influence (1.0)
	# At depth > 10m or target > 5m: minimal wave influence (0.0)
	var depth_factor = 1.0 - clamp(current_depth / 10.0, 0.0, 1.0)
	var target_factor = 1.0 - clamp(target_depth / 5.0, 0.0, 1.0)
	var wave_influence = depth_factor * target_factor
	
	# Debug output for diving attempts (remove after testing)
	# if target_depth > 0.1:
	#	print("Diving: depth=%.1f target=%.1f wave_influence=%.3f buoyancy=%.0f" % [current_depth, target_depth, wave_influence, buoyancy_force])
	
	# Surface behavior: Apply spring force to follow wave surface
	# Strength depends on wave_influence (weaker when diving)
	if wave_influence > 0.01:
		var surface_error = water_level - sub_pos.y
		
		# Scale spring constant by wave influence - allows diving to override
		# Further reduced spring constant for better surface stability
		var spring_constant = 80000.0 * wave_influence  # N/m - reduced for stability
		var damping = 60000.0 * wave_influence  # Reduced damping
		
		var spring_force = surface_error * spring_constant
		var damping_force = -submarine_body.linear_velocity.y * damping
		
		submarine_body.apply_central_force(Vector3.UP * (spring_force + damping_force))
		
		# Apply wave-induced roll and pitch for realism (scaled by wave influence)
		_apply_wave_motion(sub_pos, wave_height, delta, wave_influence)
	
	# Underwater stabilization: Apply vertical damping when deep
	# This helps stabilize depth when submerged
	if current_depth > 5.0:
		var stabilization_factor = clamp((current_depth - 5.0) / 10.0, 0.0, 1.0)
		var vertical_damping = -submarine_body.linear_velocity.y * 40000.0 * stabilization_factor
		submarine_body.apply_central_force(Vector3.UP * vertical_damping)


## Apply wave-induced motion (roll/pitch) when at surface
## wave_influence: 0.0 to 1.0, how much waves affect the submarine
func _apply_wave_motion(sub_pos: Vector3, _wave_height: float, _delta: float, wave_influence: float) -> void:
	if not ocean_renderer or not ocean_renderer.initialized:
		return
	
	if wave_influence < 0.01:
		return
	
	# Sample wave heights at bow and stern to calculate pitch
	var bow_pos = Vector2(sub_pos.x, sub_pos.z + 10.0)  # 10m forward
	var stern_pos = Vector2(sub_pos.x, sub_pos.z - 10.0)  # 10m back
	var port_pos = Vector2(sub_pos.x - 5.0, sub_pos.z)  # 5m left
	var starboard_pos = Vector2(sub_pos.x + 5.0, sub_pos.z)  # 5m right
	
	var bow_height = ocean_renderer.get_wave_height(bow_pos)
	var stern_height = ocean_renderer.get_wave_height(stern_pos)
	var port_height = ocean_renderer.get_wave_height(port_pos)
	var starboard_height = ocean_renderer.get_wave_height(starboard_pos)
	
	# Calculate pitch torque (bow vs stern) - scaled by wave influence
	var pitch_diff = bow_height - stern_height
	var pitch_torque = pitch_diff * 40000.0 * wave_influence
	
	# Calculate roll torque (port vs starboard) - scaled by wave influence
	var roll_diff = port_height - starboard_height
	var roll_torque = roll_diff * 25000.0 * wave_influence
	
	# Apply torques
	submarine_body.apply_torque(Vector3(pitch_torque, 0, roll_torque))
	
	# Apply restoring torque to level the submarine (stronger when diving)
	var restore_factor = 1.0 - wave_influence  # Stronger restoration when diving
	if restore_factor > 0.1:
		var current_rotation = submarine_body.rotation
		var restore_torque = Vector3(
			-current_rotation.x * 20000.0 * restore_factor,
			0,
			-current_rotation.z * 20000.0 * restore_factor
		)
		submarine_body.apply_torque(restore_torque)

## Apply hydrodynamic drag based on velocity squared
## Validates: Requirements 11.3
func apply_drag(_delta: float) -> void:
	if not submarine_body:
		return
	
	var velocity = submarine_body.linear_velocity
	var speed = velocity.length()
	
	if speed < 0.01:
		return  # No drag at very low speeds
	
	# Get submarine's forward direction from transform basis (consistent with propulsion)
	var forward_direction = -submarine_body.global_transform.basis.z
	
	# Calculate velocity components relative to submarine orientation
	var velocity_2d = Vector2(velocity.x, velocity.z)
	var forward_2d = Vector2(forward_direction.x, forward_direction.z)
	
	# Speed along submarine's length (forward/backward)
	var forward_speed = velocity_2d.dot(forward_2d)
	
	# Speed perpendicular to submarine (sideways)
	var right_2d = Vector2(-forward_2d.y, forward_2d.x)
	var sideways_speed = abs(velocity_2d.dot(right_2d))
	
	# Drag coefficients - configurable per submarine class
	var forward_drag_coef = forward_drag
	var sideways_drag_coef = sideways_drag
	
	# Calculate drag for each component
	var forward_drag_force = forward_drag_coef * abs(forward_speed) * forward_speed
	var sideways_drag_force = sideways_drag_coef * sideways_speed * sideways_speed
	
	# Total drag magnitude
	var drag_magnitude = abs(forward_drag_force) + sideways_drag_force
	
	# Apply drag as a force (not velocity change!)
	var drag_force = -velocity.normalized() * drag_magnitude
	submarine_body.apply_central_force(drag_force)

## Apply propulsion force to reach target speed
## Propulsion always pushes along the submarine's longitudinal axis
## Validates: Requirements 11.4
func apply_propulsion(delta: float) -> void:
	if not submarine_body or not simulation_state:
		return
	
	var target_speed = simulation_state.target_speed
	var target_heading = simulation_state.target_heading
	
	# Get submarine's current forward direction from transform basis (NOT from rotation.y)
	# This ensures we match the actual model orientation
	var forward_direction = -submarine_body.global_transform.basis.z
	
	# Calculate current speed along submarine's axis
	var current_velocity = submarine_body.linear_velocity
	var speed_along_axis = current_velocity.dot(forward_direction)
	
	# Calculate speed error
	var speed_error = target_speed - speed_along_axis
	
	# PID controller for propulsion with feedforward drag compensation
	# P term: proportional to error
	var kp = 1.5  # Proportional gain (increased for stronger response)
	var propulsion_force = kp * speed_error * propulsion_force_max / max_speed
	
	# Add feedforward term to counteract drag at target speed
	# This ensures we maintain speed even when error is small
	var drag_compensation = target_speed * abs(target_speed) * forward_drag
	if target_speed > 0:
		propulsion_force += drag_compensation
	elif target_speed < 0:
		propulsion_force -= drag_compensation
	
	# Clamp total force
	propulsion_force = clamp(propulsion_force, -propulsion_force_max * 0.5, propulsion_force_max)
	
	# Safety check for NaN or infinite values
	if is_nan(propulsion_force) or is_inf(propulsion_force):
		propulsion_force = 0.0
	
	# Calculate the actual force vector being applied
	var force_vector = forward_direction * propulsion_force
	
	# Apply force at center of mass, along submarine's forward direction
	submarine_body.apply_central_force(force_vector)
	
	# Apply turning torque to steer toward target heading
	_apply_steering_torque(target_heading, speed_along_axis, delta)


## Apply steering torque to turn submarine toward target heading
## Uses rudder physics: turning force proportional to speed and rudder angle
func _apply_steering_torque(target_heading: float, current_speed: float, _delta: float) -> void:
	if not submarine_body:
		return
	
	# Calculate heading error
	var current_heading_rad = submarine_body.rotation.y
	var target_heading_rad = deg_to_rad(target_heading)
	var heading_error = target_heading_rad - current_heading_rad
	
	# Normalize to [-PI, PI] - take shortest path
	while heading_error > PI:
		heading_error -= TAU
	while heading_error < -PI:
		heading_error += TAU
	
	# If error is very close to ±180°, pick a direction consistently
	if abs(abs(heading_error) - PI) < 0.1:  # Within ~6° of 180°
		# Always turn right (positive) when ambiguous
		heading_error = abs(heading_error)
	
	# Calculate rudder angle based on heading error (max ±30°)
	var max_rudder_angle = deg_to_rad(30.0)
	var rudder_angle = clamp(heading_error, -max_rudder_angle, max_rudder_angle)
	
	# Rudder force at stern (turning force)
	# Proportional to speed² and rudder angle
	var speed_factor = abs(current_speed) * abs(current_speed)
	var rudder_force = speed_factor * rudder_angle * rudder_effectiveness
	
	# Apply rudder force at stern (10m behind center)
	var stern_offset = Vector3(0, 0, 10)  # 10m back from center
	var stern_position = submarine_body.global_transform.basis * stern_offset
	
	# Force is perpendicular to submarine axis (sideways at stern)
	# Right direction in submarine's local space (perpendicular to forward)
	var body_heading_rad = submarine_body.rotation.y
	var sideways_direction = Vector3(-cos(body_heading_rad), 0, sin(body_heading_rad))
	var rudder_force_vector = sideways_direction * rudder_force
	
	# Apply rudder force at stern
	submarine_body.apply_force(rudder_force_vector, stern_position)
	
	# Forward stabilizers (fairwater planes) - resist rotation
	# These create opposing force when submarine is rotating
	var angular_velocity = submarine_body.angular_velocity.y
	if abs(angular_velocity) > 0.01:
		# Stabilizer force opposes rotation, proportional to speed and angular velocity
		var stabilizer_force = -speed_factor * angular_velocity * stabilizer_effectiveness
		
		# Apply at bow (forward position, 8m ahead of center)
		var bow_offset = Vector3(0, 0, -8)  # 8m forward
		var bow_position = submarine_body.global_transform.basis * bow_offset
		var stabilizer_force_vector = sideways_direction * stabilizer_force
		
		submarine_body.apply_force(stabilizer_force_vector, bow_position)
	
	# Mid-body stabilizers - provide damping to prevent oscillation
	# These resist any sideways velocity (slip angle)
	var velocity_2d = Vector2(submarine_body.linear_velocity.x, submarine_body.linear_velocity.z)
	var forward_2d = Vector2(sin(body_heading_rad), -cos(body_heading_rad))
	var right_2d = Vector2(forward_2d.y, -forward_2d.x)
	var sideways_velocity = velocity_2d.dot(right_2d)
	
	if abs(sideways_velocity) > 0.1:
		# Stabilizer opposes sideways motion - very strong to eliminate slip
		var mid_stabilizer_force = -sideways_velocity * abs(current_speed) * mid_stabilizer_effectiveness
		var mid_stabilizer_vector = sideways_direction * mid_stabilizer_force
		
		# Apply at center of mass (no torque, just damping)
		submarine_body.apply_central_force(mid_stabilizer_vector)
	
	# Optional: Thrust vectoring (small lateral component to propulsion)
	if abs(current_speed) > 1.0:
		var thrust_vector_force = sideways_direction * rudder_angle * 100000.0
		submarine_body.apply_force(thrust_vector_force, stern_position)

## Apply depth control forces to reach target depth
## Validates: Requirements 11.1
func apply_depth_control(delta: float) -> void:
	if not submarine_body or not simulation_state:
		return
	
	var current_depth = -submarine_body.global_position.y  # Depth is negative Y
	var target_depth = simulation_state.target_depth
	
	# Calculate depth error
	var depth_error = target_depth - current_depth
	
	# PID control parameters - tuned for critically damped response
	const KP: float = 0.3  # Proportional gain - reduced significantly for stability
	const KI: float = 0.005  # Integral gain - very small to prevent windup
	const KD: float = 1.2   # Derivative gain - increased for better damping
	
	# Apply dead zone to prevent oscillation near target
	const DEAD_ZONE: float = 1.5  # meters - increased dead zone
	var effective_error = depth_error
	if abs(depth_error) < DEAD_ZONE:
		effective_error = 0.0  # Complete stop in dead zone
		depth_error_integral = 0.0  # Reset integral when in dead zone
	
	# Update integral term (with windup protection)
	depth_error_integral += effective_error * delta
	depth_error_integral = clamp(depth_error_integral, -100.0, 100.0)  # Prevent windup
	
	# Calculate derivative term (use velocity for better stability)
	var depth_rate = -submarine_body.linear_velocity.y  # Rate of depth change
	var desired_rate = clamp(effective_error * 0.1, -depth_change_rate, depth_change_rate)
	var rate_error = desired_rate - depth_rate
	
	# PID output using rate-based derivative
	var pid_output = KP * effective_error + KI * depth_error_integral + KD * rate_error
	
	# Convert PID output to ballast ratio (clamp to reasonable range)
	var ballast_ratio = clamp(pid_output / 30.0, -1.0, 1.0)  # Normalize to [-1, 1]
	
	# Smooth ballast force changes with faster response
	var target_ballast = ballast_ratio * ballast_force_max
	current_ballast_force = lerp(current_ballast_force, target_ballast, delta / (depth_control_response_time * 0.5))
	
	# Apply vertical force (positive ballast_force = dive down)
	submarine_body.apply_central_force(Vector3.DOWN * current_ballast_force)
	
	# Enhanced vertical damping for stability - critical for preventing oscillation
	var vertical_velocity = submarine_body.linear_velocity.y
	var damping_force = -vertical_velocity * 80000.0  # Increased damping significantly
	submarine_body.apply_central_force(Vector3.UP * damping_force)
	
	# Apply pitch for diving/surfacing (submarines pitch down to dive, up to surface)
	# Only apply pitch when outside dead zone
	if abs(depth_error) > DEAD_ZONE * 2.0:  # Only pitch if significant depth change needed
		var pitch_for_depth = clamp(depth_error / 150.0, -0.1, 0.1)  # Reduced max pitch (5.7 degrees)
		var current_pitch = submarine_body.rotation.x
		var pitch_error = pitch_for_depth - current_pitch
		var pitch_torque = pitch_error * 30000.0  # Further reduced torque
		submarine_body.apply_torque(Vector3(pitch_torque, 0, 0))
	else:
		# Level out when near target depth
		var current_pitch = submarine_body.rotation.x
		var level_torque = -current_pitch * 40000.0
		submarine_body.apply_torque(Vector3(level_torque, 0, 0))
	
	# Clamp depth to operational limits
	if current_depth < -2.0:  # Allow slight surfacing above water
		# Force submarine to stay at or below surface
		submarine_body.global_position.y = min(submarine_body.global_position.y, 2.0)
		if submarine_body.linear_velocity.y > 0 and current_depth < 0:
			submarine_body.linear_velocity.y *= 0.3  # More aggressive damping at surface
	elif current_depth > max_depth:
		# Emergency surface if exceeding max depth
		submarine_body.global_position.y = -max_depth
		if submarine_body.linear_velocity.y < 0:
			submarine_body.linear_velocity.y = 0
		push_warning("Submarine exceeded maximum depth!")

## Update all physics forces
## Called from _physics_process
func update_physics(delta: float) -> void:
	if not submarine_body:
		return
	
	# Debug: Check if called multiple times
	var frame = Engine.get_process_frames()
	if not has_meta("last_physics_frame"):
		set_meta("last_physics_frame", frame)
	elif get_meta("last_physics_frame") == frame:
		push_warning("update_physics called MULTIPLE TIMES in frame %d!" % frame)
	set_meta("last_physics_frame", frame)
	
	# Apply all physics systems
	apply_buoyancy(delta)
	apply_drag(delta)
	apply_propulsion(delta)  # Now uses velocity manipulation
	apply_depth_control(delta)

## Get current submarine state for synchronization
func get_submarine_state() -> Dictionary:
	if not submarine_body:
		return {}
	
	var pos = submarine_body.global_position
	var vel = submarine_body.linear_velocity
	
	# Calculate depth (negative Y position)
	var depth = -pos.y
	
	# Calculate horizontal speed (exclude vertical component)
	var horizontal_velocity = Vector2(vel.x, vel.z)
	var speed = horizontal_velocity.length()
	
	# Calculate heading from actual forward direction (from transform basis)
	var forward_dir = -submarine_body.global_transform.basis.z
	var heading = rad_to_deg(atan2(forward_dir.x, -forward_dir.z))
	
	# Normalize to 0-360 range
	while heading < 0:
		heading += 360.0
	while heading >= 360:
		heading -= 360.0
	
	return {
		"position": pos,
		"velocity": vel,
		"depth": depth,
		"heading": heading,
		"speed": speed
	}
