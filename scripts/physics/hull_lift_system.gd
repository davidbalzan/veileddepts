class_name HullLiftSystem
extends Node

## Hull Lift System
## Calculates vertical lift force generated when the submarine's hull moves at an angle
## through the water. This models the hydrodynamic lift principle where an angled body
## generates lift perpendicular to the flow direction (similar to airplane wings).
##
## Physics principle: Lift = 0.5 * ρ * v² * A * CL * sin(α)
## where:
##   ρ (rho) = fluid density (water = 1000 kg/m³)
##   v = velocity
##   A = reference area (projected hull cross-section)
##   CL = lift coefficient (depends on hull shape)
##   α (alpha) = angle of attack (pitch angle)

## Reference hull cross-sectional area in m²
## Typical submarine: ~50-100m² depending on size
## Seawolf class: approximately 80m² based on 12m diameter and elliptical cross-section
@export var hull_reference_area: float = 80.0

## Lift coefficient for submarine hull shape
## Submarines have lower CL than aircraft wings due to cylindrical shape
## Typical values: 0.3-0.8 for submarine hulls at moderate angles
@export var hull_lift_coefficient: float = 0.5

## Minimum speed (m/s) for lift to take effect
## Below this speed, hull lift is negligible
@export var min_speed_for_lift: float = 1.0

## Water density in kg/m³
const WATER_DENSITY: float = 1000.0


## Calculate hull lift force based on pitch angle and forward velocity
## Returns Vector3 force in world space (primarily vertical component)
func calculate_hull_lift(pitch_angle_rad: float, velocity: Vector3, submarine_basis: Basis) -> Vector3:
	# Get forward speed (magnitude of velocity in submarine's forward direction)
	var submarine_forward = -submarine_basis.z  # Godot's -Z is forward
	var forward_speed = velocity.dot(submarine_forward)
	
	# No lift below minimum speed
	if abs(forward_speed) < min_speed_for_lift:
		return Vector3.ZERO
	
	# Calculate angle of attack (pitch angle relative to motion)
	# Positive pitch (nose up) with forward motion generates upward lift
	var angle_of_attack = pitch_angle_rad
	
	# Lift force magnitude: F = 0.5 * ρ * v² * A * CL * sin(α)
	var dynamic_pressure = 0.5 * WATER_DENSITY * forward_speed * forward_speed
	var lift_magnitude = dynamic_pressure * hull_reference_area * hull_lift_coefficient * sin(angle_of_attack)
	
	# Lift direction is perpendicular to velocity and in the pitch plane
	# For submarine: lift acts primarily in vertical (world up) direction
	# But we need to account for roll and yaw
	var submarine_up = submarine_basis.y
	var lift_force = submarine_up * lift_magnitude
	
	return lift_force


## Calculate lift force with damping for realistic feel
## Adds progressive effectiveness based on speed (similar to dive planes)
func calculate_hull_lift_with_damping(pitch_angle_rad: float, velocity: Vector3, submarine_basis: Basis) -> Vector3:
	var base_lift = calculate_hull_lift(pitch_angle_rad, velocity, submarine_basis)
	
	# Speed effectiveness factor (0.0 to 1.0)
	# Gradually ramps up from min_speed to 2x min_speed
	var submarine_forward = -submarine_basis.z
	var forward_speed = abs(velocity.dot(submarine_forward))
	
	var speed_factor = clamp((forward_speed - min_speed_for_lift) / min_speed_for_lift, 0.0, 1.0)
	
	return base_lift * speed_factor


## Get diagnostic information about hull lift
func get_lift_diagnostics(pitch_angle_rad: float, velocity: Vector3, submarine_basis: Basis) -> Dictionary:
	var submarine_forward = -submarine_basis.z
	var forward_speed = velocity.dot(submarine_forward)
	
	var lift_force = calculate_hull_lift_with_damping(pitch_angle_rad, velocity, submarine_basis)
	var lift_magnitude = lift_force.length()
	
	return {
		"forward_speed": forward_speed,
		"pitch_angle_deg": rad_to_deg(pitch_angle_rad),
		"lift_force_y": lift_force.y,
		"lift_magnitude": lift_magnitude,
		"speed_effective": abs(forward_speed) >= min_speed_for_lift
	}
