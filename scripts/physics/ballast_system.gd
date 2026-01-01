class_name BallastSystem
extends RefCounted

## Ballast System Component
##
## Controls buoyancy for depth changes using PID control.
## Especially effective at low speeds where dive planes are ineffective.
## Implements dead zone to prevent oscillation around target depth.
##
## Requirements: 8.1, 8.2, 8.3, 8.4, 8.6

# Configuration parameters
var max_ballast_force: float = 50000000.0  # Maximum vertical force (N)
var kp: float = 0.3  # Proportional gain
var ki: float = 0.005  # Integral gain
var kd: float = 1.2  # Derivative gain
var dead_zone: float = 0.5  # Depth tolerance (meters)
var vertical_damping_coefficient: float = 80000.0  # Damping force coefficient
var max_depth_rate: float = 5.0  # Maximum desired depth rate (m/s)
var depth_rate_gain: float = 0.1  # Gain for converting depth error to desired rate
var ballast_lerp_rate: float = 0.1  # Smoothing rate for ballast force changes

# PID state
var depth_error_integral: float = 0.0
var last_depth_error: float = 0.0
var last_ballast_force: float = 0.0

func _init(config: Dictionary = {}):
	if config.has("max_ballast_force"):
		max_ballast_force = config.max_ballast_force
	if config.has("kp"):
		kp = config.kp
	if config.has("ki"):
		ki = config.ki
	if config.has("kd"):
		kd = config.kd
	if config.has("dead_zone"):
		dead_zone = config.dead_zone
	if config.has("vertical_damping_coefficient"):
		vertical_damping_coefficient = config.vertical_damping_coefficient
	if config.has("max_depth_rate"):
		max_depth_rate = config.max_depth_rate
	if config.has("depth_rate_gain"):
		depth_rate_gain = config.depth_rate_gain
	if config.has("ballast_lerp_rate"):
		ballast_lerp_rate = config.ballast_lerp_rate

## Calculate ballast force for depth control
##
## Parameters:
##   current_depth: Current depth below surface (positive = deeper, meters)
##   target_depth: Desired depth below surface (meters)
##   vertical_velocity: Current vertical velocity (positive = descending, m/s)
##   delta: Time step in seconds
##
## Returns:
##   Vertical force to apply (positive = downward, N)
func calculate_ballast_force(
	current_depth: float,
	target_depth: float,
	vertical_velocity: float,
	delta: float
) -> float:
	# Requirement 8.1: Calculate depth error
	var depth_error: float = target_depth - current_depth
	
	# Requirement 8.2: Implement dead zone of ±0.5m around target depth
	var effective_error: float = depth_error
	if abs(depth_error) < dead_zone:
		effective_error = 0.0
		# Requirement 8.3: Reset integral term when in dead zone
		depth_error_integral = 0.0
	
	# Requirement 8.4: Calculate desired depth rate from depth error
	# Positive error (need to go deeper) = positive rate (descending)
	# Negative error (need to go shallower) = negative rate (ascending)
	var desired_depth_rate: float = clamp(
		effective_error * depth_rate_gain,
		-max_depth_rate,
		max_depth_rate
	)
	
	# Calculate rate error
	# Vertical velocity is positive when descending, which matches our convention
	var rate_error: float = desired_depth_rate - vertical_velocity
	
	# Update integral term (only when outside dead zone)
	if abs(depth_error) >= dead_zone and delta > 0.0:
		depth_error_integral += effective_error * delta
		# Implement integral windup protection
		var max_integral: float = max_ballast_force / (ki * 30.0) if ki > 0.0 else 1000.0
		depth_error_integral = clamp(depth_error_integral, -max_integral, max_integral)
	
	# Calculate derivative term
	var derivative: float = 0.0
	if delta > 0.0:
		derivative = (effective_error - last_depth_error) / delta
	last_depth_error = effective_error
	
	# Requirement 8.1: Calculate PID output
	var pid_output: float = (kp * effective_error) + (ki * depth_error_integral) + (kd * rate_error)
	
	# Convert PID output to ballast force
	# Normalize by a scaling factor to get reasonable force values
	var ballast_force: float = clamp(pid_output / 30.0, -1.0, 1.0) * max_ballast_force
	
	# Requirement 8.4: Apply vertical damping: -vertical_velocity * 80000
	var damping_force: float = -vertical_velocity * vertical_damping_coefficient
	
	# Combine ballast and damping forces
	var total_force: float = ballast_force + damping_force
	
	# Requirement 8.6: Smooth ballast force changes with lerp
	total_force = lerp(last_ballast_force, total_force, ballast_lerp_rate)
	last_ballast_force = total_force
	
	return total_force

## Reset PID state (useful when changing modes or after major disturbances)
func reset_pid_state() -> void:
	depth_error_integral = 0.0
	last_depth_error = 0.0
	last_ballast_force = 0.0

## Update configuration parameters
func configure(config: Dictionary) -> void:
	if config.has("max_ballast_force"):
		max_ballast_force = config.max_ballast_force
	if config.has("kp"):
		kp = config.kp
	if config.has("ki"):
		ki = config.ki
	if config.has("kd"):
		kd = config.kd
	if config.has("dead_zone"):
		dead_zone = config.dead_zone
	if config.has("vertical_damping_coefficient"):
		vertical_damping_coefficient = config.vertical_damping_coefficient
	if config.has("max_depth_rate"):
		max_depth_rate = config.max_depth_rate
	if config.has("depth_rate_gain"):
		depth_rate_gain = config.depth_rate_gain
	if config.has("ballast_lerp_rate"):
		ballast_lerp_rate = config.ballast_lerp_rate
