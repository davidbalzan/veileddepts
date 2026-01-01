class_name PropulsionSystem
extends RefCounted

## Propulsion System Component
##
## Manages thrust generation along the submarine's longitudinal axis.
## Implements PID speed control with alignment-based thrust reduction.
##
## Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6

# Configuration parameters
var max_thrust: float = 50000000.0  # Maximum propulsion force in Newtons
var kp_speed: float = 1.5  # Proportional gain for speed control
var alignment_threshold: float = 0.9  # Heading alignment required for full thrust
var max_speed: float = 15.0  # Maximum speed for normalization

# PID state
var speed_error_integral: float = 0.0
var last_speed_error: float = 0.0

func _init(config: Dictionary = {}):
	if config.has("max_thrust"):
		max_thrust = config.max_thrust
	if config.has("kp_speed"):
		kp_speed = config.kp_speed
	if config.has("alignment_threshold"):
		alignment_threshold = config.alignment_threshold
	if config.has("max_speed"):
		max_speed = config.max_speed

## Calculate propulsion force along submarine's forward axis
##
## Parameters:
##   forward_dir: Submarine's forward direction vector (normalized)
##   current_velocity: Current velocity vector
##   target_speed: Desired speed in m/s
##   target_heading: Desired heading in degrees (for alignment check)
##   delta: Time step in seconds
##
## Returns:
##   Force vector along forward direction
func calculate_propulsion_force(
	forward_dir: Vector3,
	current_velocity: Vector3,
	target_speed: float,
	target_heading: float,
	delta: float
) -> Vector3:
	# Requirement 2.2: Calculate speed along submarine axis only
	var speed_along_axis: float = current_velocity.dot(forward_dir)
	
	# Calculate speed error
	var speed_error: float = target_speed - speed_along_axis
	
	# Requirement 2.2: Calculate alignment factor (velocity dot forward direction)
	var alignment: float = 1.0
	var velocity_length_sq: float = current_velocity.length_squared()
	if velocity_length_sq > 0.01:  # Avoid division by zero
		var velocity_dir: Vector3 = current_velocity.normalized()
		alignment = velocity_dir.dot(forward_dir)
	
	# Apply PID control
	# Using proportional control only for stability
	var force_magnitude: float = kp_speed * speed_error * max_thrust / max_speed
	
	# Requirement 2.4: Reduce thrust when misaligned > 30° (reduce to 50%)
	# cos(30°) ≈ 0.866
	var alignment_multiplier: float = 1.0
	if alignment < 0.866:  # More than 30° misalignment
		alignment_multiplier = 0.5
	
	# Requirement 2.6: Skip feedforward compensation when alignment < 0.9
	# (We're not using feedforward in this implementation, but this ensures
	# we don't add it in the future when poorly aligned)
	
	# Apply alignment reduction
	force_magnitude *= alignment_multiplier
	
	# Requirement 2.5: Clamp thrust to [-0.5 * max, 1.0 * max]
	var min_thrust: float = -0.5 * max_thrust
	var max_forward_thrust: float = max_thrust
	force_magnitude = clamp(force_magnitude, min_thrust, max_forward_thrust)
	
	# Requirement 2.1: Return force vector along forward direction
	return forward_dir * force_magnitude

## Reset PID state (useful when changing modes or after major disturbances)
func reset_pid_state() -> void:
	speed_error_integral = 0.0
	last_speed_error = 0.0

## Update configuration parameters
func configure(config: Dictionary) -> void:
	if config.has("max_thrust"):
		max_thrust = config.max_thrust
	if config.has("kp_speed"):
		kp_speed = config.kp_speed
	if config.has("alignment_threshold"):
		alignment_threshold = config.alignment_threshold
	if config.has("max_speed"):
		max_speed = config.max_speed
