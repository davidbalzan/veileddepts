class_name CoordinateSystem
extends Object

## Coordinate System Utility Module
##
## Provides static utility functions for coordinate transformations and heading calculations
## using the unified coordinate system where North=0°, East=90°, South=180°, West=270°.
##
## All heading calculations use the standard formula: atan2(forward.x, -forward.z)
## to ensure consistency across the entire physics system.


## Calculate heading from a forward direction vector
## Returns heading in degrees [0, 360) where North=0°, East=90°, South=180°, West=270°
static func calculate_heading(forward_dir: Vector3) -> float:
	if forward_dir.length_squared() < 0.0001:
		return 0.0

	# Standard heading formula: atan2(x, -z)
	# This maps: North (0,0,-1) -> 0°, East (1,0,0) -> 90°, South (0,0,1) -> 180°, West (-1,0,0) -> 270°
	var heading_rad = atan2(forward_dir.x, -forward_dir.z)
	var heading_deg = rad_to_deg(heading_rad)

	# Normalize to [0, 360) range
	return normalize_heading(heading_deg)


## Normalize a heading angle to the range [0, 360)
## Handles negative angles and angles >= 360°
static func normalize_heading(heading: float) -> float:
	# Use fmod to handle large values efficiently
	var normalized = fmod(heading, 360.0)

	# Handle negative angles
	if normalized < 0.0:
		normalized += 360.0

	return normalized


## Calculate the shortest path heading error between current and target headings
## Returns error in degrees [-180, 180] where positive = turn right, negative = turn left
static func heading_error(current: float, target: float) -> float:
	# Normalize both headings first
	var current_norm = normalize_heading(current)
	var target_norm = normalize_heading(target)

	# Calculate raw difference
	var error = target_norm - current_norm

	# Find shortest path (wrap around at ±180°)
	if error > 180.0:
		error -= 360.0
	elif error < -180.0:
		error += 360.0

	return error


## Extract forward direction vector from a Transform3D
## Returns the -Z axis of the transform (submarine's longitudinal axis pointing toward bow)
static func forward_direction_from_transform(transform: Transform3D) -> Vector3:
	# In Godot, -Z is forward for 3D objects
	return -transform.basis.z


## Convert heading angle to a 2D vector for UI display
## Returns Vector2 where x=East-West, y=North-South
## Useful for tactical map displays and 2D navigation
static func heading_to_vector2(heading: float) -> Vector2:
	var heading_rad = deg_to_rad(heading)

	# Convert heading to 2D vector
	# North (0°) -> (0, -1), East (90°) -> (1, 0), South (180°) -> (0, 1), West (270°) -> (-1, 0)
	var x = sin(heading_rad)  # East-West component
	var y = -cos(heading_rad)  # North-South component (negative because Y increases downward in 2D)

	return Vector2(x, y)
