class_name DivePlaneSystem
extends RefCounted

## Dive Plane System Component
##
## Generates pitch torque for depth control based on water flow speed.
## Implements speed-dependent dive plane effectiveness with bow/stern plane split.
##
## Requirements: 8.5, 8.7, 8.8, 8.9, 8.10, 8.11, 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 19.7, 19.8

# Configuration parameters
var bow_plane_effectiveness: float = 0.4  # Bow plane contribution (40%)
var stern_plane_effectiveness: float = 0.6  # Stern plane contribution (60%)
var max_plane_angle: float = 15.0  # Maximum plane deflection (degrees)
var min_effective_speed: float = 1.0  # Minimum speed for plane effectiveness (m/s)
var max_effective_speed: float = 5.0  # Speed for full plane effectiveness (m/s)
var torque_coefficient: float = 1500.0  # Base torque multiplier - balanced for 8M kg submarine
var depth_to_pitch_ratio: float = 75.0  # Depth error to pitch angle (was 150, now more aggressive)
var derivative_damping: float = 2.0  # Damping coefficient for pitch rate (increased from 0.8)
var max_torque_limit: float = 10000000.0  # Hard limit: 10M Nm maximum torque (prevents saturation)


func _init(config: Dictionary = {}):
	if config.has("bow_plane_effectiveness"):
		bow_plane_effectiveness = config.bow_plane_effectiveness
	if config.has("stern_plane_effectiveness"):
		stern_plane_effectiveness = config.stern_plane_effectiveness
	if config.has("max_plane_angle"):
		max_plane_angle = config.max_plane_angle
	if config.has("min_effective_speed"):
		min_effective_speed = config.min_effective_speed
	if config.has("max_effective_speed"):
		max_effective_speed = config.max_effective_speed
	if config.has("torque_coefficient"):
		torque_coefficient = config.torque_coefficient
	if config.has("depth_to_pitch_ratio"):
		depth_to_pitch_ratio = config.depth_to_pitch_ratio


## Calculate dive plane pitch torque for depth control
##
## Parameters:
##   current_depth: Current depth below surface (positive = deeper, meters)
##   target_depth: Desired depth below surface (meters)
##   vertical_velocity: Current vertical velocity (positive = descending, m/s)
##   forward_speed: Forward velocity component (m/s)
##   current_pitch: Current pitch angle (degrees, positive = nose up)
##   pitch_angular_velocity: Current pitch rotation rate (rad/s, positive = pitching up)
##
## Returns:
##   Torque value to apply around X-axis (N·m, positive = nose up)
func calculate_dive_plane_torque(
	current_depth: float,
	target_depth: float,
	vertical_velocity: float,
	forward_speed: float,
	current_pitch: float,
	pitch_angular_velocity: float = 0.0
) -> float:
	# Requirement 8.5: Calculate depth error
	var depth_error: float = target_depth - current_depth

	# Requirement 8.10: Calculate desired pitch angle from depth error
	# Positive depth error (need to go deeper) = negative pitch (nose down)
	# Negative depth error (need to go shallower) = positive pitch (nose up)
	var desired_pitch: float = -depth_error / depth_to_pitch_ratio

	# CRITICAL: Only force level when breaching (< 0.1m), not at all shallow depths
	if current_depth < 0.1:  # Breaching surface
		desired_pitch = 0.0
	elif abs(depth_error) < 1.0:
		desired_pitch = 0.0
	elif abs(depth_error) < 5.0:
		# Gradual leveling zone - reduce pitch angle proportionally
		var level_factor = abs(depth_error) / 5.0  # 0.2 to 1.0
		desired_pitch *= level_factor
	else:
		# Requirement 8.8: Clamp plane angles to ±15°
		desired_pitch = clamp(desired_pitch, -max_plane_angle, max_plane_angle)

	# Calculate pitch error
	var pitch_error: float = desired_pitch - current_pitch
	
	# Apply derivative damping based on vertical velocity to prevent oscillation
	# If we're moving in the direction we want, reduce the correction
	# vertical_velocity > 0 means descending, < 0 means ascending
	var pitch_rate_damping: float = 0.0
	if depth_error > 0.0 and vertical_velocity > 0.0:
		# We want to descend and we are descending - reduce correction
		pitch_rate_damping = -abs(vertical_velocity) * derivative_damping
	elif depth_error < 0.0 and vertical_velocity < 0.0:
		# We want to ascend and we are ascending - reduce correction
		pitch_rate_damping = abs(vertical_velocity) * derivative_damping
	
	# Add angular velocity damping - oppose current pitch rotation
	# This is the most important damping to prevent oscillation
	var angular_damping: float = -rad_to_deg(pitch_angular_velocity) * 3.0
	
	# Apply damping to pitch error
	pitch_error += pitch_rate_damping + angular_damping

	# Calculate plane angle from pitch error
	# Use proportional control to determine plane deflection
	var plane_angle: float = clamp(pitch_error, -max_plane_angle, max_plane_angle)

	# Requirement 19.2: Calculate water flow speed effectiveness
	var water_flow_speed: float = abs(forward_speed)
	var speed_effectiveness: float = _calculate_speed_effectiveness(water_flow_speed)

	# Requirement 19.1, 19.9: Calculate pitch torque: angle * speed^2 * effectiveness
	# Using speed squared for hydrodynamic lift force
	var speed_factor: float = water_flow_speed * water_flow_speed

	# Calculate base torque from hydrodynamic force on planes
	var base_torque: float = plane_angle * speed_factor * torque_coefficient * speed_effectiveness

	# Requirement 19.8, 19.7: Split torque: 40% bow planes, 60% stern planes
	# Both contribute to the same direction of pitch torque
	var bow_torque: float = base_torque * bow_plane_effectiveness
	var stern_torque: float = base_torque * stern_plane_effectiveness

	# SAFETY: Clamp total torque to prevent runaway oscillation
	var total_torque: float = bow_torque + stern_torque
	total_torque = clamp(total_torque, -max_torque_limit, max_torque_limit)

	# Return clamped torque
	return total_torque


## Calculate speed effectiveness factor for dive planes
##
## Requirements 19.2, 19.3:
##   - Below 1 m/s: < 10% effectiveness
##   - 1-5 m/s: linear scaling
##   - Above 5 m/s: 100% effectiveness
##
## Parameters:
##   speed: Water flow speed over planes (m/s)
##
## Returns:
##   Effectiveness factor [0.0, 1.0]
func _calculate_speed_effectiveness(speed: float) -> float:
	# Requirement 19.3: Below min_effective_speed (1 m/s), minimal effectiveness (<10%)
	if speed < min_effective_speed:
		# Linear scaling from 0% at 0 m/s to 10% at 1 m/s
		return 0.1 * (speed / min_effective_speed)

	# Requirement 19.2: Above max_effective_speed (5 m/s), full effectiveness (100%)
	if speed >= max_effective_speed:
		return 1.0

	# Requirement 19.2: Between 1-5 m/s, linear scaling from 10% to 100%
	var speed_range: float = max_effective_speed - min_effective_speed
	var speed_above_min: float = speed - min_effective_speed
	var effectiveness_range: float = 1.0 - 0.1  # 100% - 10%

	return 0.1 + (speed_above_min / speed_range) * effectiveness_range


## Update configuration parameters
func configure(config: Dictionary) -> void:
	if config.has("bow_plane_effectiveness"):
		bow_plane_effectiveness = config.bow_plane_effectiveness
	if config.has("stern_plane_effectiveness"):
		stern_plane_effectiveness = config.stern_plane_effectiveness
	if config.has("max_plane_angle"):
		max_plane_angle = config.max_plane_angle
	if config.has("min_effective_speed"):
		min_effective_speed = config.min_effective_speed
	if config.has("max_effective_speed"):
		max_effective_speed = config.max_effective_speed
	if config.has("torque_coefficient"):
		torque_coefficient = config.torque_coefficient
	if config.has("depth_to_pitch_ratio"):
		depth_to_pitch_ratio = config.depth_to_pitch_ratio
