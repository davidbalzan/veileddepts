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
var min_effective_speed: float = 0.3  # TASK-003: Reduced from 1.0 to allow low-speed pitch control
var max_effective_speed: float = 5.0  # Speed for full plane effectiveness (m/s)
var torque_coefficient: float = 3000.0  # TASK-004: Increased from 1500 for stronger pitch authority
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
##   max_pitch_limit: Maximum allowed pitch angle (degrees), passed from physics controller
##
## Returns:
##   Torque value to apply around X-axis (N·m, positive = nose up)
func calculate_dive_plane_torque(
	current_depth: float,
	target_depth: float,
	vertical_velocity: float,
	forward_speed: float,
	current_pitch: float,
	pitch_angular_velocity: float = 0.0,
	max_pitch_limit: float = 15.0
) -> float:
	# Requirement 8.5: Calculate depth error
	var depth_error: float = target_depth - current_depth
	
	# REALISTIC SUBMARINE PITCH CONTROL
	# Based on actual submarine operations:
	# - Routine ascent/descent: 5-10° pitch (we'll use 8°)
	# - Emergency maneuvers: 10-20° (we'll allow up to 15°)
	# - Approach target: reduce pitch smoothly
	# - At target: level out (0°)
	
	# Determine if surfacing and calculate effective target
	var is_surfacing = target_depth < 5.0
	var effective_target = target_depth
	
	# For surfacing, use staged approach to prevent broaching
	if is_surfacing:
		if current_depth > 50.0:
			effective_target = 50.0  # First waypoint
		elif current_depth > 25.0:
			effective_target = 25.0  # Second waypoint
		else:
			effective_target = 0.0   # Final approach
		depth_error = effective_target - current_depth
	
	var distance_to_target = abs(depth_error)
	var is_ascending = depth_error < 0  # Need to go up (shallower)
	var is_descending = depth_error > 0  # Need to go down (deeper)
	
	# PREDICTIVE CONTROL: Where will we be in 3 seconds?
	var prediction_time = 3.0
	var predicted_depth = current_depth + (vertical_velocity * prediction_time)
	var predicted_error = effective_target - predicted_depth
	var will_overshoot = sign(predicted_error) != sign(depth_error) and distance_to_target > 2.0
	
	# BASE PITCH based on distance to target
	# This is the "normal operating" pitch - like a real sub
	var target_pitch_deg: float
	
	if distance_to_target < 5.0:
		# AT TARGET: Level out completely
		target_pitch_deg = 0.0
	elif distance_to_target < 20.0:
		# APPROACHING: Reduce pitch linearly (20m->5m = 8°->0°)
		var approach_factor = (distance_to_target - 5.0) / 15.0  # 0 at 5m, 1 at 20m
		target_pitch_deg = 8.0 * approach_factor
	elif distance_to_target < 50.0:
		# CLOSE: Moderate pitch
		target_pitch_deg = 8.0
	else:
		# FAR: Full operational pitch (like real sub routine maneuvers)
		target_pitch_deg = 10.0  # 10° for normal ops, can be overridden by max_pitch_limit
	
	# Apply max pitch limit from physics controller
	target_pitch_deg = min(target_pitch_deg, max_pitch_limit)
	
	# Special handling for surfacing - more conservative
	if is_surfacing:
		if current_depth < 10.0:
			target_pitch_deg = min(target_pitch_deg, 3.0)  # Very gentle near surface
		elif current_depth < 25.0:
			target_pitch_deg = min(target_pitch_deg, 5.0)
		elif current_depth < 50.0:
			target_pitch_deg = min(target_pitch_deg, 8.0)
	
	# Calculate desired pitch angle (sign determines direction)
	var desired_pitch_angle: float
	
	if distance_to_target < 5.0:
		# At target - level
		desired_pitch_angle = 0.0
	elif will_overshoot:
		# About to overshoot - counter-pitch to slow down
		var overshoot_amount = abs(predicted_error)
		var counter_strength = clamp(overshoot_amount / 10.0, 0.0, 1.0)
		# Pitch opposite to current motion to slow down
		var current_motion = sign(vertical_velocity)  # +1 descending, -1 ascending
		desired_pitch_angle = current_motion * 5.0 * counter_strength  # Nose up if descending too fast
	elif is_ascending:
		# Going up - nose up (positive pitch)
		desired_pitch_angle = target_pitch_deg
	elif is_descending:
		# Going down - nose down (negative pitch)
		desired_pitch_angle = -target_pitch_deg
	else:
		desired_pitch_angle = 0.0
	
	var desired_pitch = desired_pitch_angle

	# Calculate pitch error
	var pitch_error: float = desired_pitch - current_pitch
	
	# CRITICAL: Pitch limit rolloff - reduce dive plane authority as we approach pitch limits
	# This reserves control authority to counter overshoot and prevents saturation
	# At extreme pitch angles, we need planes at neutral to correct back
	var pitch_limit_rolloff_start = 15.0  # Start reducing authority at 15°
	var pitch_limit_max = 25.0  # Zero authority at 25°
	
	var abs_pitch = abs(current_pitch)
	var pitch_authority_factor = 1.0
	
	if abs_pitch > pitch_limit_rolloff_start:
		# Calculate rolloff factor (1.0 at 15°, 0.0 at 25°)
		var rolloff_range = pitch_limit_max - pitch_limit_rolloff_start
		var rolloff_progress = (abs_pitch - pitch_limit_rolloff_start) / rolloff_range
		pitch_authority_factor = 1.0 - clamp(rolloff_progress, 0.0, 1.0)
		
		# At extreme pitch, we want planes to help level, not maintain pitch
		# If pitch and pitch_error have same sign, we're trying to pitch MORE - block it
		if sign(current_pitch) == sign(pitch_error):
			pitch_authority_factor *= 0.1  # Strongly reduce
	
	# Apply authority factor to pitch error
	pitch_error *= pitch_authority_factor
	
	# PREDICTIVE DAMPING: Consider where pitch will be, not just where it is
	# If pitch is rotating toward desired, reduce command to prevent overshoot
	var pitch_prediction = current_pitch + (pitch_angular_velocity * 2.0)  # 2 second prediction
	var predicted_pitch_error = desired_pitch - pitch_prediction
	
	# If we're heading in the right direction, reduce command proportionally
	if (pitch_error * predicted_pitch_error) > 0 and abs(pitch_error) > 0.01:
		# Same sign = we'll overshoot, reduce command
		var overshoot_reduction = abs(predicted_pitch_error) / abs(pitch_error)
		pitch_error *= clamp(overshoot_reduction, 0.3, 1.0)  # Keep at least 30%
	
	# Angular velocity damping - oppose current pitch rotation
	var angular_damping: float = -rad_to_deg(pitch_angular_velocity) * 2.0 * pitch_authority_factor
	pitch_error += angular_damping

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
