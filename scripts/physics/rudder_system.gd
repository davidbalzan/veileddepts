class_name RudderSystem
extends RefCounted

## Rudder System Component
##
## Generates yaw torque for steering based on water flow speed.
## Implements speed-dependent steering effectiveness, turn rate limiting,
## and stability damping.
##
## Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 14.4

# Configuration parameters
var torque_coefficient: float = 250000.0  # Base torque multiplier (N·m) - reduced from 2M for realistic turning
var max_rudder_angle: float = 30.0  # Maximum rudder deflection (degrees)
var max_turn_rate: float = 3.0  # Maximum angular velocity (degrees/second) - submarines turn slowly
var min_steering_speed: float = 0.5  # Minimum speed for effective steering (m/s)
var max_steering_speed: float = 8.0  # Speed cap for steering effectiveness (m/s)
var low_speed_effectiveness: float = 0.2  # Effectiveness multiplier below min_steering_speed (20%)
var stability_damping_coefficient: float = 100000.0  # Damping torque coefficient - increased for stability

# Debug mode (Requirement 14.1, 14.4)
var debug_mode: bool = false

# Callback for logging (set by parent system)
var log_callback: Callable = Callable()


func _init(config: Dictionary = {}):
	if config.has("torque_coefficient"):
		torque_coefficient = config.torque_coefficient
	if config.has("max_rudder_angle"):
		max_rudder_angle = config.max_rudder_angle
	if config.has("max_turn_rate"):
		max_turn_rate = config.max_turn_rate
	if config.has("min_steering_speed"):
		min_steering_speed = config.min_steering_speed
	if config.has("max_steering_speed"):
		max_steering_speed = config.max_steering_speed
	if config.has("low_speed_effectiveness"):
		low_speed_effectiveness = config.low_speed_effectiveness
	if config.has("stability_damping_coefficient"):
		stability_damping_coefficient = config.stability_damping_coefficient


## Calculate steering torque for heading control
##
## Parameters:
##   current_heading: Current heading in degrees [0, 360)
##   target_heading: Desired heading in degrees [0, 360)
##   forward_speed: Forward velocity component (m/s)
##   angular_velocity: Current angular velocity around Y-axis (rad/s)
##
## Returns:
##   Torque value to apply around Y-axis (N·m)
func calculate_steering_torque(
	current_heading: float, target_heading: float, forward_speed: float, angular_velocity: float
) -> float:
	# Requirement 4.1: Calculate heading error (shortest path)
	var heading_error_deg: float = CoordinateSystem.heading_error(current_heading, target_heading)

	# Requirement 4.5: Calculate rudder angle proportional to error, clamp to ±30°
	# Use a proportional factor to map heading error to rudder angle
	# Full rudder deflection at ~60° heading error
	var rudder_angle_deg: float = clamp(
		heading_error_deg / 2.0, -max_rudder_angle, max_rudder_angle
	)

	# Requirement 4.2: Calculate water flow speed from forward velocity
	# Simplified model: water flow speed = absolute value of forward velocity
	var water_flow_speed: float = abs(forward_speed)

	# Requirement 4.6: Cap speed factor at 8.0 m/s
	var speed_factor: float = min(water_flow_speed, max_steering_speed)

	# Requirement 4.3: Apply low-speed penalty: <0.5 m/s = 20% effectiveness
	var effectiveness: float = 1.0
	if water_flow_speed < min_steering_speed:
		effectiveness = low_speed_effectiveness
		# Requirement 14.4: Log low-speed steering only when heading error > 10°
		if abs(heading_error_deg) > 10.0:
			_log_debug(
				(
					"Low-speed steering: %.2f m/s, heading error: %.1f°, effectiveness: %.0f%%"
					% [water_flow_speed, heading_error_deg, effectiveness * 100.0]
				)
			)

	# Requirement 4.1: Calculate torque: -speed_factor * rudder_angle * torque_coef
	# Negative sign accounts for Godot's left-hand Y-axis rotation
	# (positive heading error = need to turn right = negative torque in Godot)
	var base_torque: float = -speed_factor * rudder_angle_deg * torque_coefficient * effectiveness

	# Requirement 5.3: Apply stability damping proportional to angular velocity
	var damping_torque: float = -angular_velocity * stability_damping_coefficient

	# Requirement 5.1, 5.2: Implement turn rate limiting
	var total_torque: float = base_torque + damping_torque

	# Convert angular velocity from rad/s to deg/s for comparison
	var current_turn_rate_deg: float = rad_to_deg(angular_velocity)

	# If exceeding max turn rate, apply strong damping
	if abs(current_turn_rate_deg) > max_turn_rate:
		var excess_rate: float = abs(current_turn_rate_deg) - max_turn_rate
		var limiting_torque: float = (
			-sign(angular_velocity) * excess_rate * stability_damping_coefficient * 2.0
		)
		total_torque += limiting_torque

	# Requirement 5.4: Reduce steering input when heading error is small to prevent oscillation
	if abs(heading_error_deg) < 5.0:
		# Reduce torque proportionally when close to target
		var reduction_factor: float = abs(heading_error_deg) / 5.0
		total_torque *= reduction_factor

	return total_torque


## Update configuration parameters
func configure(config: Dictionary) -> void:
	if config.has("torque_coefficient"):
		torque_coefficient = config.torque_coefficient
	if config.has("max_rudder_angle"):
		max_rudder_angle = config.max_rudder_angle
	if config.has("max_turn_rate"):
		max_turn_rate = config.max_turn_rate
	if config.has("min_steering_speed"):
		min_steering_speed = config.min_steering_speed
	if config.has("max_steering_speed"):
		max_steering_speed = config.max_steering_speed
	if config.has("low_speed_effectiveness"):
		low_speed_effectiveness = config.low_speed_effectiveness
	if config.has("stability_damping_coefficient"):
		stability_damping_coefficient = config.stability_damping_coefficient


## Log debug message if debug mode is enabled
## Requirement 14.1, 14.4: Implement debug logging
func _log_debug(message: String) -> void:
	if debug_mode and log_callback.is_valid():
		log_callback.call(message)
