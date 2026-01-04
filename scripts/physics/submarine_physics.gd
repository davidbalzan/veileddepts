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
var buoyancy_point_offset: float = 2.0  # meters below center - positive = sub sits lower in water

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

# Cached values for performance
var _cached_forward_direction: Vector3 = Vector3.FORWARD
var _cache_frame: int = -1

# Submarine class presets
const SUBMARINE_CLASSES = {
	"Los_Angeles_Class":
	{
		"class_name": "Los Angeles Class (SSN-688)",
		"mass": 6000.0,  # tons
		"max_speed": 15.4,  # 30 knots
		"max_depth": 450.0,
		"propulsion_force_max": 45000000.0,
		"forward_drag": 1800.0,
		"sideways_drag": 700000.0,
		"rudder_effectiveness": 300000.0,
		"stabilizer_effectiveness": 12000.0,
		"mid_stabilizer_effectiveness": 200000.0,
		"ballast_force_max": 45000000.0,
		"submarine_volume": 6000.0
	},
	"Ohio_Class":
	{
		"class_name": "Ohio Class (SSBN-726)",
		"mass": 18000.0,  # tons
		"max_speed": 12.9,  # 25 knots
		"max_depth": 300.0,
		"propulsion_force_max": 60000000.0,
		"forward_drag": 2500.0,
		"sideways_drag": 1000000.0,
		"rudder_effectiveness": 150000.0,
		"stabilizer_effectiveness": 8000.0,
		"mid_stabilizer_effectiveness": 300000.0,
		"ballast_force_max": 70000000.0,
		"submarine_volume": 18000.0
	},
	"Virginia_Class":
	{
		"class_name": "Virginia Class (SSN-774)",
		"mass": 7800.0,  # tons
		"max_speed": 12.9,  # 25 knots
		"max_depth": 490.0,
		"propulsion_force_max": 40000000.0,
		"forward_drag": 1900.0,
		"sideways_drag": 750000.0,
		"rudder_effectiveness": 280000.0,
		"stabilizer_effectiveness": 11000.0,
		"mid_stabilizer_effectiveness": 220000.0,
		"ballast_force_max": 48000000.0,
		"submarine_volume": 7800.0
	},
	"Seawolf_Class":
	{
		"class_name": "Seawolf Class (SSN-21)",
		"mass": 9100.0,  # tons
		"max_speed": 18.0,  # 35 knots
		"max_depth": 600.0,
		"propulsion_force_max": 55000000.0,
		"forward_drag": 1700.0,
		"sideways_drag": 650000.0,
		"rudder_effectiveness": 350000.0,
		"stabilizer_effectiveness": 13000.0,
		"mid_stabilizer_effectiveness": 180000.0,
		"ballast_force_max": 52000000.0,
		"submarine_volume": 9100.0
	},
	"Default":
	{
		"class_name": "Generic Attack Submarine",
		"mass": 8000.0,
		"max_speed": 10.3,
		"max_depth": 400.0,
		"propulsion_force_max": 35000000.0,
		"forward_drag": 2000.0,
		"sideways_drag": 800000.0,
		"rudder_effectiveness": 250000.0,
		"stabilizer_effectiveness": 10000.0,
		"mid_stabilizer_effectiveness": 250000.0,
		"ballast_force_max": 50000000.0,
		"submarine_volume": 8000.0
	}
}


func _ready() -> void:
	# Physics will be initialized when connected to other systems
	pass


## Get cached forward direction (recalculated once per frame)
func _get_forward_direction() -> Vector3:
	var frame = Engine.get_process_frames()
	if _cache_frame != frame:
		_cached_forward_direction = -submarine_body.global_transform.basis.z
		_cache_frame = frame

		# Safety check for NaN values
		if not _cached_forward_direction.is_finite():
			push_error("SubmarinePhysics: Forward direction is NaN! Resetting to default.")
			_cached_forward_direction = Vector3.FORWARD
			# Reset submarine transform to prevent cascading NaN
			if submarine_body:
				submarine_body.global_transform = Transform3D(
					Basis(), submarine_body.global_position
				)

	return _cached_forward_direction


## Initialize the physics system with required references
func initialize(
	p_submarine_body: RigidBody3D,
	p_ocean_renderer: OceanRenderer,
	p_simulation_state: SimulationState
) -> void:
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


## Load a predefined submarine class by name
func load_submarine_class(sub_class: String) -> bool:
	if not SUBMARINE_CLASSES.has(sub_class):
		push_error("SubmarinePhysics: Unknown submarine class '%s'" % sub_class)
		return false

	configure_submarine_class(SUBMARINE_CLASSES[sub_class])
	return true


## Get list of available submarine class names
func get_available_classes() -> Array:
	return SUBMARINE_CLASSES.keys()


## Apply buoyancy force based on ocean wave heights and submarine displacement
## Validates: Requirements 11.1, 11.5, 9.5 (dynamic sea level)
func apply_buoyancy(delta: float) -> void:
	if not submarine_body:
		return

	var sub_pos = submarine_body.global_position
	
	# Get current sea level from SeaLevelManager (Requirement 9.5)
	var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0
	var current_depth = sea_level_meters - sub_pos.y  # Depth is positive going down from sea level

	# Calculate buoyancy reference point (offset below submarine center)
	# This makes the submarine sit lower in the water
	var buoyancy_sample_pos = sub_pos - Vector3(0, buoyancy_point_offset, 0)

	# Get wave height at buoyancy reference point
	var wave_height: float = sea_level_meters  # Default to current sea level
	if ocean_renderer and ocean_renderer.initialized:
		# Use buoyancy sample position for wave height
		wave_height = ocean_renderer.get_wave_height_3d(buoyancy_sample_pos)

	# Calculate water level at submarine position (wave height is relative to current sea level)
	var water_level = wave_height

	# Calculate how deep the buoyancy point is below the water surface
	# Positive = underwater, Negative = above water
	var depth_below_surface = water_level - buoyancy_sample_pos.y

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

	# Calculate wave influence factor - decreases with depth but allows surfacing
	# At surface (depth=0): full wave influence (1.0)
	# At depth > 10m: minimal wave influence, BUT still allow surfacing if target is shallow
	var depth_factor = 1.0 - clamp(current_depth / 10.0, 0.0, 1.0)
	var target_factor = 1.0 - clamp(target_depth / 5.0, 0.0, 1.0)

	# Allow wave influence when trying to surface, even from depth
	var surfacing_factor = 0.0
	if target_depth < 2.0:  # If trying to get to shallow depth
		surfacing_factor = clamp((2.0 - target_depth) / 2.0, 0.0, 1.0)  # 0 to 1 based on how shallow target is

	var wave_influence = max(depth_factor * target_factor, surfacing_factor * 0.3)  # Allow some wave influence when surfacing

	# Early exit if deep underwater - skip expensive wave sampling
	if wave_influence < 0.01:
		# Apply underwater stabilization only
		if current_depth > 5.0:
			var stabilization_factor = clamp((current_depth - 5.0) / 10.0, 0.0, 1.0)
			var vertical_damping = (
				-submarine_body.linear_velocity.y * 40000.0 * stabilization_factor
			)
			submarine_body.apply_central_force(Vector3.UP * vertical_damping)
		return

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
func _apply_wave_motion(
	sub_pos: Vector3, _wave_height: float, _delta: float, wave_influence: float
) -> void:
	if not ocean_renderer or not ocean_renderer.initialized:
		return

	if wave_influence < 0.01:
		return

	# Sample wave heights at bow and stern to calculate pitch
	# Use Vector3 positions for get_wave_height_3d
	var bow_pos = Vector3(sub_pos.x, 0, sub_pos.z + 10.0)  # 10m forward
	var stern_pos = Vector3(sub_pos.x, 0, sub_pos.z - 10.0)  # 10m back
	var port_pos = Vector3(sub_pos.x - 5.0, 0, sub_pos.z)  # 5m left
	var starboard_pos = Vector3(sub_pos.x + 5.0, 0, sub_pos.z)  # 5m right

	var bow_height = ocean_renderer.get_wave_height_3d(bow_pos)
	var stern_height = ocean_renderer.get_wave_height_3d(stern_pos)
	var port_height = ocean_renderer.get_wave_height_3d(port_pos)
	var starboard_height = ocean_renderer.get_wave_height_3d(starboard_pos)

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

	# Get submarine's forward direction from cache
	var forward_direction = _get_forward_direction()

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

	# Apply drag forces separately along forward and sideways axes (more physically accurate)
	# Safety: Check vector length BEFORE normalizing to prevent NaN
	var forward_drag_vec = Vector2.ZERO
	if forward_2d.length_squared() > 0.0001:  # Use length_squared for efficiency
		forward_drag_vec = -forward_2d.normalized() * forward_drag_force

	var sideways_drag_vec = Vector2.ZERO
	if right_2d.length_squared() > 0.0001:
		sideways_drag_vec = -right_2d.normalized() * sideways_drag_force

	var drag_force_2d = forward_drag_vec + sideways_drag_vec
	var drag_force = Vector3(drag_force_2d.x, 0, drag_force_2d.y)

	# Safety check for NaN
	if not drag_force.is_finite():
		push_warning("SubmarinePhysics: Drag force is NaN, skipping")
		return

	submarine_body.apply_central_force(drag_force)


## Apply propulsion force to reach target speed
## Propulsion always pushes along the submarine's longitudinal axis
## Validates: Requirements 11.4
func apply_propulsion(delta: float) -> void:
	if not submarine_body or not simulation_state:
		return

	var target_speed = simulation_state.target_speed
	var target_heading = simulation_state.target_heading

	# Get submarine's current forward direction from cache
	var forward_direction = _get_forward_direction()

	# Calculate current speed along submarine's axis
	var current_velocity = submarine_body.linear_velocity
	var speed_along_axis = current_velocity.dot(forward_direction)

	# Calculate heading alignment using same method as get_submarine_state
	var current_heading = rad_to_deg(atan2(forward_direction.x, -forward_direction.z))
	while current_heading < 0:
		current_heading += 360.0
	while current_heading >= 360:
		current_heading -= 360.0

	# Calculate heading error in degrees
	var heading_error_deg = target_heading - current_heading
	while heading_error_deg > 180:
		heading_error_deg -= 360
	while heading_error_deg < -180:
		heading_error_deg += 360

	# Calculate alignment factor (1.0 = perfectly aligned, 0.0 = 90° off)
	var alignment_factor = cos(deg_to_rad(heading_error_deg))
	alignment_factor = max(0.0, alignment_factor)  # Only positive alignment

	# Reduce propulsion when not aligned with target heading
	# This prevents sideways movement during turns, but allows forward motion to build up speed
	# for effective steering (submarines need water flow over rudder to turn)
	var heading_threshold = 15.0  # 15° tolerance
	var propulsion_multiplier = 1.0
	if abs(heading_error_deg) > heading_threshold:
		# At low speeds, allow more propulsion to build up speed for steering
		# Real submarines often need to accelerate before they can turn effectively
		var speed_ratio = clamp(abs(speed_along_axis) / 3.0, 0.0, 1.0)  # 0 to 1 over 0-3 m/s
		var min_propulsion = 0.7 + (0.2 * (1.0 - speed_ratio))  # 90% at stop, 70% at speed

		# Gradually reduce propulsion as heading error increases, but maintain minimum for steering
		propulsion_multiplier = alignment_factor * 0.3 + min_propulsion

	# Calculate speed error
	var speed_error = target_speed - speed_along_axis

	# PID controller for propulsion with alignment-based modulation
	var kp = 1.5  # Proportional gain
	var propulsion_force = kp * speed_error * propulsion_force_max / max_speed

	# Apply propulsion multiplier to reduce force during turns
	propulsion_force *= propulsion_multiplier

	# Add feedforward term only when well-aligned and significant speed error
	# This prevents force accumulation during turns
	var speed_error_threshold = 0.5  # m/s
	var alignment_threshold = 0.9  # cos(~25°)
	if abs(speed_error) > speed_error_threshold and alignment_factor > alignment_threshold:
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

	# Safety check for NaN
	if not force_vector.is_finite():
		push_warning("SubmarinePhysics: Propulsion force vector is NaN, skipping")
		return

	# Apply force at center of mass, along submarine's forward direction
	submarine_body.apply_central_force(force_vector)

	# Apply turning torque to steer toward target heading
	_apply_steering_torque(target_heading, speed_along_axis, delta)


## Apply steering torque to turn submarine toward target heading
## Uses rudder physics: turning force proportional to speed and rudder angle
func _apply_steering_torque(target_heading: float, current_speed: float, _delta: float) -> void:
	if not submarine_body:
		return

	# Calculate current heading from forward direction (same as get_submarine_state)
	var forward_dir = -submarine_body.global_transform.basis.z
	var current_heading = rad_to_deg(atan2(forward_dir.x, -forward_dir.z))
	while current_heading < 0:
		current_heading += 360.0
	while current_heading >= 360:
		current_heading -= 360.0

	# Calculate heading error in degrees
	var heading_error_deg = target_heading - current_heading

	# Normalize to [-180, 180] - take shortest path
	while heading_error_deg > 180:
		heading_error_deg -= 360
	while heading_error_deg < -180:
		heading_error_deg += 360

	# If error is very close to ±180°, pick a direction consistently
	if abs(abs(heading_error_deg) - 180) < 6:  # Within 6° of 180°
		heading_error_deg = 180  # Always turn right when ambiguous

	# Convert to radians for torque calculation
	var heading_error_rad = deg_to_rad(heading_error_deg)

	# Calculate rudder angle based on heading error (max ±30°)
	var max_rudder_angle = deg_to_rad(30.0)
	var rudder_angle = clamp(heading_error_rad, -max_rudder_angle, max_rudder_angle)

	# Realistic rudder physics: steering effectiveness depends on water flow speed
	# No flow = no steering (submarines can't turn when stationary)
	var water_speed = abs(current_speed)

	# Minimum speed required for effective steering (about 1 knot = 0.5 m/s)
	var min_steering_speed = 0.5
	if water_speed < min_steering_speed:
		# Very limited steering at low speeds - submarines use bow/stern thrusters for this
		# For now, allow minimal steering for gameplay, but make it very weak
		water_speed = water_speed * 0.2  # 20% effectiveness at low speeds

	# Use linear speed relationship for more reasonable steering
	# Cap the speed factor to prevent excessive turning at high speeds
	var max_steering_speed = 8.0  # m/s - beyond this, steering doesn't get more effective
	var capped_speed = min(water_speed, max_steering_speed)
	var speed_factor = capped_speed

	# Apply steering as pure torque around Y-axis
	# In Godot: positive Y torque = counter-clockwise rotation (left turn)
	# Navigation: positive heading error = need to turn right (clockwise)
	# So we NEGATE the torque to get correct turn direction
	var torque_coefficient = 2000000.0  # Reduced from 8M to 2M for much slower, realistic turning
	var steering_torque = -speed_factor * rudder_angle * torque_coefficient  # NEGATED

	# Apply torque directly
	var torque_vector = Vector3(0, steering_torque, 0)
	submarine_body.apply_torque(torque_vector)

	# Debug output for low-speed steering attempts (less frequent)
	if abs(heading_error_deg) > 10.0 and water_speed < min_steering_speed:
		print("Low-speed steering: speed=%.2f m/s, limited effectiveness" % water_speed)

	# Forward stabilizers - resist unwanted rotation and limit turn rate
	var angular_velocity = submarine_body.angular_velocity.y

	# Realistic maximum turn rate for a large submarine
	var max_turn_rate = deg_to_rad(5.0)  # 5°/s max turn rate (much more realistic for large submarine)

	if abs(angular_velocity) > max_turn_rate:
		# Apply strong damping when exceeding maximum turn rate
		var excess_rotation = abs(angular_velocity) - max_turn_rate
		var damping_torque = -sign(angular_velocity) * excess_rotation * 50000000.0  # Strong damping
		submarine_body.apply_torque(Vector3(0, damping_torque, 0))
	elif abs(angular_velocity) > 0.01:
		# Apply light damping for stability even at normal turn rates
		var stability_damping = -angular_velocity * 8000000.0  # Increased damping for stability
		submarine_body.apply_torque(Vector3(0, stability_damping, 0))

	# Anti-slip system - eliminate sideways velocity using direct velocity manipulation
	# This is more stable than applying forces that fight each other
	var velocity_2d = Vector2(submarine_body.linear_velocity.x, submarine_body.linear_velocity.z)
	var current_heading_rad = deg_to_rad(current_heading)
	var forward_2d = Vector2(sin(current_heading_rad), -cos(current_heading_rad))
	var right_2d = Vector2(forward_2d.y, -forward_2d.x)
	var sideways_velocity = velocity_2d.dot(right_2d)

	# Apply direct velocity correction for significant sideways movement
	if abs(sideways_velocity) > 0.5:  # Only correct significant sideways drift
		# Calculate forward speed to preserve
		var forward_speed = velocity_2d.dot(forward_2d)

		# Gradually reduce sideways component while preserving forward motion
		var sideways_reduction = 0.8  # Remove 80% of sideways velocity per frame
		var corrected_sideways = sideways_velocity * (1.0 - sideways_reduction)

		# Reconstruct velocity with reduced sideways component
		var corrected_velocity_2d = forward_2d * forward_speed + right_2d * corrected_sideways
		submarine_body.linear_velocity.x = corrected_velocity_2d.x
		submarine_body.linear_velocity.z = corrected_velocity_2d.y

		# Debug output only for very significant sideways movement
		if abs(sideways_velocity) > 3.0:
			print("Anti-slip: correcting sideways velocity %.2f m/s" % sideways_velocity)


## Apply depth control forces to reach target depth
## Validates: Requirements 11.1, 9.1, 9.3 (dynamic sea level)
func apply_depth_control(delta: float) -> void:
	if not submarine_body or not simulation_state:
		return

	# Get current sea level from SeaLevelManager (Requirement 9.1)
	var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0
	var current_depth = sea_level_meters - submarine_body.global_position.y  # Depth relative to current sea level
	var target_depth = simulation_state.target_depth

	# Calculate depth error
	var depth_error = target_depth - current_depth

	# PID control parameters - tuned for critically damped response
	const KP: float = 0.3  # Proportional gain - reduced significantly for stability
	const KI: float = 0.005  # Integral gain - very small to prevent windup
	const KD: float = 1.2  # Derivative gain - increased for better damping

	# Apply dead zone to prevent oscillation near target
	const DEAD_ZONE: float = 0.5  # meters - reduced for better surface precision
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
	current_ballast_force = lerp(
		current_ballast_force, target_ballast, delta / (depth_control_response_time * 0.5)
	)

	# Apply vertical force (positive ballast_force = dive down)
	submarine_body.apply_central_force(Vector3.DOWN * current_ballast_force)

	# Enhanced vertical damping for stability - critical for preventing oscillation
	var vertical_velocity = submarine_body.linear_velocity.y
	var base_damping = 80000.0

	# Surface approach damping - progressively stronger as sub nears surface while ascending
	# This prevents breaching when coming up from depth
	if current_depth < 20.0 and vertical_velocity > 0:  # Within 20m of surface and ascending
		var surface_proximity = 1.0 - (current_depth / 20.0)  # 0 at 20m, 1 at surface
		var ascent_speed = vertical_velocity

		# Exponentially increase damping near surface
		var surface_damping_multiplier = 1.0 + (surface_proximity * surface_proximity * 5.0)
		base_damping *= surface_damping_multiplier

		# Also limit maximum ascent rate near surface
		var max_ascent_rate = lerp(depth_change_rate, 0.5, surface_proximity)
		if ascent_speed > max_ascent_rate:
			submarine_body.linear_velocity.y = max_ascent_rate

	var damping_force = -vertical_velocity * base_damping
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

	# Clamp depth to operational limits (Requirement 9.3 - surface breach prevention)
	# Allow surfacing when target depth is shallow (< 1m)
	var surface_limit = 2.0  # Default: stay 2m below surface
	if simulation_state.target_depth < 1.0:
		# When trying to surface, allow reaching actual surface (Y = sea_level)
		surface_limit = 0.0

	if current_depth < -surface_limit:  # Above allowed surface limit
		# Force submarine to stay at or below allowed surface (relative to current sea level)
		var max_y_position = sea_level_meters + surface_limit
		submarine_body.global_position.y = min(submarine_body.global_position.y, max_y_position)
		if submarine_body.linear_velocity.y > 0:  # Moving upward
			submarine_body.linear_velocity.y *= 0.3  # Damping when hitting surface
	elif current_depth > max_depth:
		# Emergency surface if exceeding max depth
		submarine_body.global_position.y = sea_level_meters - max_depth
		if submarine_body.linear_velocity.y < 0:
			submarine_body.linear_velocity.y = 0
		push_warning("Submarine exceeded maximum depth!")


## Update all physics forces
## Called from _physics_process
func update_physics(delta: float) -> void:
	if not submarine_body:
		return

	# Safety check: Detect and fix NaN in submarine state
	var pos = submarine_body.global_position
	var vel = submarine_body.linear_velocity
	var ang_vel = submarine_body.angular_velocity

	if not pos.is_finite() or not vel.is_finite() or not ang_vel.is_finite():
		push_error("SubmarinePhysics: NaN detected in submarine state! Resetting to safe values.")
		# Reset to safe state
		submarine_body.global_position = Vector3(0, 0, 0) if not pos.is_finite() else pos
		submarine_body.linear_velocity = Vector3.ZERO if not vel.is_finite() else vel
		submarine_body.angular_velocity = Vector3.ZERO if not ang_vel.is_finite() else ang_vel
		submarine_body.global_transform = Transform3D(Basis(), submarine_body.global_position)
		return  # Skip this frame to allow reset

	# Apply all physics systems
	apply_buoyancy(delta)
	apply_drag(delta)
	apply_propulsion(delta)  # Now uses velocity manipulation
	apply_depth_control(delta)

	# Align velocity with heading to prevent sideways movement
	_align_velocity_with_heading(delta)

	# Clamp velocity to prevent excessive speeds
	_clamp_velocity()

	# Enforce map boundaries
	_enforce_map_boundaries()


## Get current submarine state for synchronization
## Validates: Requirement 9.1 (depth reading relative to sea level)
func get_submarine_state() -> Dictionary:
	if not submarine_body:
		return {}

	var pos = submarine_body.global_position
	var vel = submarine_body.linear_velocity

	# Calculate depth relative to current sea level (Requirement 9.1)
	var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0
	var depth = sea_level_meters - pos.y  # Depth is positive going down from sea level

	# Calculate horizontal speed (exclude vertical component)
	var horizontal_velocity = Vector2(vel.x, vel.z)
	var speed = horizontal_velocity.length()

	# Calculate heading from actual forward direction (from transform basis)
	var forward_dir = -submarine_body.global_transform.basis.z
	# Standard navigation: atan2(x, -z) where +X is East, -Z is North
	# This gives: North=0°, East=90°, South=180°, West=270°
	var heading = rad_to_deg(atan2(forward_dir.x, -forward_dir.z))

	# Normalize to 0-360 range
	while heading < 0:
		heading += 360.0
	while heading >= 360:
		heading -= 360.0

	return {"position": pos, "velocity": vel, "depth": depth, "heading": heading, "speed": speed}


## Clamp velocity to prevent excessive speeds that can cause the submarine to run off the map
func _clamp_velocity() -> void:
	if not submarine_body or not simulation_state:
		return

	var velocity = submarine_body.linear_velocity
	var speed = velocity.length()

	# Clamp to maximum allowed speed (with small buffer for physics stability)
	var max_allowed_speed = max_speed * 1.1  # 10% buffer
	if speed > max_allowed_speed:
		submarine_body.linear_velocity = velocity.normalized() * max_allowed_speed
		# Only warn for significant speed violations to reduce spam
		if speed > max_allowed_speed * 1.2:
			push_warning(
				(
					"SubmarinePhysics: Velocity clamped from %.1f to %.1f m/s"
					% [speed, max_allowed_speed]
				)
			)


## Enforce map boundaries to prevent submarine from running off the map
func _enforce_map_boundaries() -> void:
	if not submarine_body:
		return

	var pos = submarine_body.global_position
	var velocity = submarine_body.linear_velocity
	var boundary_changed = false

	# Map boundaries based on terrain size (2048x2048 meters, centered at origin)
	var map_half_size = 1024.0  # Half of 2048m terrain size
	var boundary_buffer = 50.0  # Keep submarine 50m from edge for safety
	var max_boundary = map_half_size - boundary_buffer
	var min_boundary = -max_boundary

	# Check X boundary
	if pos.x > max_boundary:
		submarine_body.global_position.x = max_boundary
		if velocity.x > 0:
			submarine_body.linear_velocity.x = 0  # Stop outward movement
		boundary_changed = true
	elif pos.x < min_boundary:
		submarine_body.global_position.x = min_boundary
		if velocity.x < 0:
			submarine_body.linear_velocity.x = 0  # Stop outward movement
		boundary_changed = true

	# Check Z boundary
	if pos.z > max_boundary:
		submarine_body.global_position.z = max_boundary
		if velocity.z > 0:
			submarine_body.linear_velocity.z = 0  # Stop outward movement
		boundary_changed = true
	elif pos.z < min_boundary:
		submarine_body.global_position.z = min_boundary
		if velocity.z < 0:
			submarine_body.linear_velocity.z = 0  # Stop outward movement
		boundary_changed = true

	if boundary_changed:
		push_warning(
			(
				"SubmarinePhysics: Submarine hit map boundary at position (%.1f, %.1f, %.1f)"
				% [pos.x, pos.y, pos.z]
			)
		)


## Align velocity direction with submarine heading to prevent sideways movement
func _align_velocity_with_heading(_delta: float) -> void:
	if not submarine_body:
		return

	var velocity = submarine_body.linear_velocity
	var speed = velocity.length()

	# Only apply alignment if submarine is moving at reasonable speed
	if speed < 1.0:
		return

	# Get submarine's forward direction
	var forward_direction = _get_forward_direction()

	# Calculate current velocity direction
	var velocity_direction = velocity.normalized()

	# If velocity is too small, normalized() returns zero vector - skip alignment
	if velocity_direction.length_squared() < 0.01:
		return

	# Calculate alignment between velocity and heading
	var alignment = velocity_direction.dot(forward_direction)

	# Only correct very poor alignment to avoid fighting with other systems
	var alignment_threshold = 0.7  # cos(~45°) - only correct major misalignment
	if alignment > alignment_threshold:
		return

	# Don't apply velocity alignment if speed is being clamped
	if speed > max_speed * 1.05:
		return

	# Direct velocity correction for major misalignment
	# This is more stable than applying forces
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var desired_horizontal = (
		Vector2(forward_direction.x, forward_direction.z).normalized() * horizontal_speed
	)

	# Gradually align velocity direction (preserve vertical component)
	var alignment_rate = 0.1  # 10% correction per frame - very gentle
	submarine_body.linear_velocity.x = lerp(velocity.x, desired_horizontal.x, alignment_rate)
	submarine_body.linear_velocity.z = lerp(velocity.z, desired_horizontal.y, alignment_rate)

	# Debug output only for severe misalignment (throttled to avoid spam)
	if alignment < 0.3 and Engine.get_physics_frames() % 60 == 0:
		print("Velocity alignment: severe misalignment %.3f, correcting" % alignment)
