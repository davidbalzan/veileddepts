class_name PhysicsValidator
extends RefCounted

## Physics Validator Component
##
## Ensures numerical stability by validating vectors, detecting NaN values,
## clamping velocities, and enforcing map boundaries.
##
## Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 11.1, 11.2, 11.3, 11.4, 11.5,
##               16.1, 16.2, 16.3, 16.4, 16.5

# Error tracking to prevent console spam
var _last_error_time: Dictionary = {}
var _error_cooldown: float = 5.0  # Seconds between repeated error messages

## Validates that a vector contains finite values (no NaN or Inf)
## Returns true if valid, false if invalid
func validate_vector(v: Vector3, name: String) -> bool:
	if not v.is_finite():
		_log_error_throttled("validate_vector", "Invalid vector '%s': %s" % [name, v])
		return false
	return true

## Validates and fixes submarine state if NaN or invalid values are detected
## Returns true if state was valid, false if fixes were applied
func validate_and_fix_submarine_state(body: RigidBody3D) -> bool:
	var was_valid: bool = true
	
	# Check position
	if not body.global_position.is_finite():
		_log_error_throttled("position_nan", "NaN detected in submarine position, resetting to origin")
		body.global_position = Vector3.ZERO
		was_valid = false
	
	# Check linear velocity
	if not body.linear_velocity.is_finite():
		_log_error_throttled("velocity_nan", "NaN detected in submarine velocity, resetting to zero")
		body.linear_velocity = Vector3.ZERO
		was_valid = false
	
	# Check angular velocity
	if not body.angular_velocity.is_finite():
		_log_error_throttled("angular_velocity_nan", "NaN detected in submarine angular velocity, resetting to zero")
		body.angular_velocity = Vector3.ZERO
		was_valid = false
	
	return was_valid

## Clamps velocity magnitude to maximum speed (110% of max_speed)
## Preserves velocity direction while limiting magnitude
func clamp_velocity(body: RigidBody3D, max_speed: float) -> void:
	var velocity: Vector3 = body.linear_velocity
	var speed: float = velocity.length()
	
	# Allow 110% of max speed before clamping
	var clamp_threshold: float = max_speed * 1.1
	
	if speed > clamp_threshold:
		# Only log if significantly over limit (120%)
		if speed > max_speed * 1.2:
			_log_error_throttled("velocity_clamp", "Velocity clamped from %.2f to %.2f m/s" % [speed, clamp_threshold])
		
		# Normalize and scale to clamp threshold
		if speed > 0.001:  # Avoid division by zero
			body.linear_velocity = velocity.normalized() * clamp_threshold

## Enforces map boundaries at ±boundary meters from origin
## Clamps position and zeros outward velocity components
func enforce_boundaries(body: RigidBody3D, boundary: float) -> void:
	var position: Vector3 = body.global_position
	var velocity: Vector3 = body.linear_velocity
	var hit_boundary: bool = false
	
	# Check X boundary
	if position.x < -boundary:
		position.x = -boundary
		if velocity.x < 0:
			velocity.x = 0
		hit_boundary = true
	elif position.x > boundary:
		position.x = boundary
		if velocity.x > 0:
			velocity.x = 0
		hit_boundary = true
	
	# Check Z boundary
	if position.z < -boundary:
		position.z = -boundary
		if velocity.z < 0:
			velocity.z = 0
		hit_boundary = true
	elif position.z > boundary:
		position.z = boundary
		if velocity.z > 0:
			velocity.z = 0
		hit_boundary = true
	
	# Apply changes if boundary was hit
	if hit_boundary:
		_log_error_throttled("boundary_hit", "Submarine hit map boundary at position: (%.1f, %.1f)" % [position.x, position.z])
		body.global_position = position
		body.linear_velocity = velocity

## Validates vector length before normalization to prevent division by zero
## Returns true if vector can be safely normalized
func can_normalize(v: Vector3) -> bool:
	return v.length_squared() > 0.000001  # Epsilon for safe normalization

## Logs error message with throttling to prevent console spam
func _log_error_throttled(error_key: String, message: String) -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	
	# Check if we've logged this error recently
	if _last_error_time.has(error_key):
		var time_since_last: float = current_time - _last_error_time[error_key]
		if time_since_last < _error_cooldown:
			return  # Skip logging to prevent spam
	
	# Log the error and update timestamp
	push_error("[PhysicsValidator] " + message)
	_last_error_time[error_key] = current_time
