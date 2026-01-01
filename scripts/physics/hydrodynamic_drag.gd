class_name HydrodynamicDrag
extends RefCounted

## Hydrodynamic Drag Component
##
## Calculates drag forces opposing submarine motion through water.
## Implements forward/sideways velocity decomposition, surface drag penalties,
## and extensible appendage drag system.
##
## Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 20.1, 20.2, 20.3

# Drag coefficients
var base_forward_drag: float = 5000.0  # Base drag coefficient for forward motion
var sideways_drag: float = 2000000.0  # Sideways drag coefficient (400x forward)
var surface_drag_depth_threshold: float = 5.0  # Depth below which surface drag applies (meters)
var surface_drag_multiplier: float = 1.5  # Drag increase at surface (1.5 = 50% increase)

# Performance optimization
const MIN_SPEED_THRESHOLD: float = 0.01  # Skip calculations below this speed (m/s)


func _init(
	p_base_forward_drag: float = 5000.0,
	p_sideways_drag: float = 2000000.0,
	p_surface_drag_depth_threshold: float = 5.0,
	p_surface_drag_multiplier: float = 1.5
) -> void:
	base_forward_drag = p_base_forward_drag
	sideways_drag = p_sideways_drag
	surface_drag_depth_threshold = p_surface_drag_depth_threshold
	surface_drag_multiplier = p_surface_drag_multiplier
	
	# Validate that sideways drag is at least 400x forward drag (Requirement 3.3)
	assert(sideways_drag >= base_forward_drag * 400.0, 
		"Sideways drag coefficient must be at least 400x forward drag coefficient")


## Calculate drag force opposing submarine motion
##
## @param velocity: Current submarine velocity vector
## @param forward_dir: Submarine's forward direction (normalized)
## @param depth: Current depth below surface (positive = deeper)
## @param appendage_registry: Registry containing active appendage drag contributions
## @return: Drag force vector opposing motion
func calculate_drag_force(
	velocity: Vector3,
	forward_dir: Vector3,
	depth: float,
	appendage_registry
) -> Vector3:
	# Early exit for very low speeds (Requirement 3.6)
	var speed_squared: float = velocity.length_squared()
	if speed_squared < MIN_SPEED_THRESHOLD * MIN_SPEED_THRESHOLD:
		return Vector3.ZERO
	
	# Decompose velocity into forward and sideways components (Requirement 3.4)
	var forward_speed: float = velocity.dot(forward_dir)
	var forward_velocity: Vector3 = forward_dir * forward_speed
	var sideways_velocity: Vector3 = velocity - forward_velocity
	
	var forward_speed_abs: float = abs(forward_speed)
	var sideways_speed: float = sideways_velocity.length()
	
	# Calculate surface drag factor based on depth (Requirements 20.1, 20.2, 20.3)
	var surface_drag_factor: float = _calculate_surface_drag_factor(depth)
	
	# Get appendage drag from registry (returns additional drag, not a multiplier)
	var appendage_drag_addition: float = 0.0
	if appendage_registry != null:
		appendage_drag_addition = appendage_registry.get_total_drag_multiplier()
	
	# Calculate forward drag: (base + appendage + surface) * speed^2 (Requirement 3.1)
	# Note: appendage_drag_addition is a fraction (e.g., 0.25 = 25% increase)
	# surface_drag_factor is a multiplier (e.g., 1.5 = 50% increase)
	var base_with_appendages: float = base_forward_drag * (1.0 + appendage_drag_addition)
	var total_forward_drag_coef: float = base_with_appendages * surface_drag_factor
	var forward_drag_magnitude: float = total_forward_drag_coef * forward_speed_abs * forward_speed_abs
	
	# Apply drag opposing forward motion
	var forward_drag_force: Vector3 = Vector3.ZERO
	if forward_speed_abs > 0.001:
		forward_drag_force = -forward_velocity.normalized() * forward_drag_magnitude
	
	# Calculate sideways drag: sideways_coef * speed^2 (Requirement 3.2)
	var sideways_drag_magnitude: float = sideways_drag * sideways_speed * sideways_speed
	
	# Apply drag opposing sideways motion
	var sideways_drag_force: Vector3 = Vector3.ZERO
	if sideways_speed > 0.001:
		sideways_drag_force = -sideways_velocity.normalized() * sideways_drag_magnitude
	
	# Combine drag forces (Requirement 3.5)
	return forward_drag_force + sideways_drag_force


## Calculate surface drag factor based on depth
##
## Surface drag increases linearly from 0% at threshold depth to 50% at surface
##
## @param depth: Current depth below surface (positive = deeper)
## @return: Drag multiplier (1.0 = no increase, 1.5 = 50% increase)
func _calculate_surface_drag_factor(depth: float) -> float:
	# No surface drag when deep (Requirement 20.3)
	if depth >= surface_drag_depth_threshold:
		return 1.0
	
	# At surface: full surface drag penalty (Requirement 20.2)
	if depth <= 0.0:
		return surface_drag_multiplier
	
	# Linear interpolation between surface and threshold depth (Requirement 20.3)
	var depth_ratio: float = depth / surface_drag_depth_threshold
	return lerp(surface_drag_multiplier, 1.0, depth_ratio)
