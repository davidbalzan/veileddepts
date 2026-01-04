class_name BuoyancySystem
extends RefCounted

## Buoyancy System Component
##
## Simulates Archimedes' principle and wave interaction.
## Provides buoyancy forces based on displaced volume and submersion ratio.
## Applies wave-following behavior at surface and stabilization when deep.
##
## Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6

# Configuration parameters
var water_density: float = 1025.0  # Seawater density (kg/m³)
var submarine_volume: float = 8000.0  # Displacement volume (m³)
var buoyancy_coefficient: float = 1.0  # Neutral buoyancy factor
var wave_influence_depth: float = 10.0  # Depth where wave influence fades (m)
var wave_spring_coefficient: float = 80000.0  # Spring force to follow waves (N/m) - increased for surface riding
var wave_damping_coefficient: float = 25000.0  # Damping for wave following (N·s/m) - increased to prevent bouncing
var wave_torque_coefficient: float = 500000.0  # Wave-induced roll/pitch torque (N·m)
var deep_stabilization_coefficient: float = 5000.0  # Vertical stabilization when deep (N·s/m)
var hull_height: float = 10.0  # Submarine hull height for submersion calculation (m)
var surface_threshold: float = 2.0  # Depth below which submarine is considered at surface (m)
var surface_riding_boost: float = 1.3  # Extra buoyancy when riding at surface (1.3 = 30% extra)


func _init(config: Dictionary = {}):
	if config.has("water_density"):
		water_density = config.water_density
	if config.has("submarine_volume"):
		submarine_volume = config.submarine_volume
	if config.has("buoyancy_coefficient"):
		buoyancy_coefficient = config.buoyancy_coefficient
	if config.has("wave_influence_depth"):
		wave_influence_depth = config.wave_influence_depth
	if config.has("wave_spring_coefficient"):
		wave_spring_coefficient = config.wave_spring_coefficient
	if config.has("wave_damping_coefficient"):
		wave_damping_coefficient = config.wave_damping_coefficient
	if config.has("wave_torque_coefficient"):
		wave_torque_coefficient = config.wave_torque_coefficient
	if config.has("deep_stabilization_coefficient"):
		deep_stabilization_coefficient = config.deep_stabilization_coefficient
	if config.has("hull_height"):
		hull_height = config.hull_height
	if config.has("surface_threshold"):
		surface_threshold = config.surface_threshold
	if config.has("surface_riding_boost"):
		surface_riding_boost = config.surface_riding_boost


## Calculate buoyancy force and wave interaction
##
## Parameters:
##   position: Submarine position in world space
##   velocity: Current velocity vector
##   target_depth: Desired depth (for surfacing behavior)
##   ocean_renderer: Reference to ocean renderer for wave height
##
## Returns:
##   Dictionary with:
##     - force: Buoyancy force vector (Vector3)
##     - torque: Wave-induced torque vector (Vector3)
##
## Validates: Requirements 9.1, 9.5 (dynamic sea level)
func calculate_buoyancy_force(
	position: Vector3, velocity: Vector3, target_depth: float, ocean_renderer
) -> Dictionary:
	var result = {"force": Vector3.ZERO, "torque": Vector3.ZERO}

	# Requirement 9.5: Get current sea level from SeaLevelManager
	var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0

	# Requirement 9.1: Get wave height from ocean renderer (relative to current sea level)
	var wave_height: float = sea_level_meters  # Default to current sea level
	if ocean_renderer and ocean_renderer.has_method("get_wave_height_3d"):
		wave_height = ocean_renderer.get_wave_height_3d(position)

	# Calculate submarine's hull depth (center position relative to water surface)
	var hull_depth: float = wave_height - position.y

	# Requirement 9.2: Calculate submersion ratio based on hull depth vs water surface
	var submersion_ratio: float = _calculate_submersion_ratio(hull_depth)

	# Requirement 9.1: Calculate buoyancy using Archimedes' principle
	# Buoyancy = density * volume * submersion * gravity
	var buoyancy_force: float = (
		water_density * submarine_volume * submersion_ratio * 9.81 * buoyancy_coefficient
	)

	# Apply surface riding boost when submarine wants to stay at surface
	# This helps the submarine ride waves instead of sinking back down
	if target_depth < surface_threshold and hull_depth < surface_threshold * 2:
		buoyancy_force *= surface_riding_boost
		# Also apply upward velocity damping to prevent flying over waves
		if velocity.y > 0.5:
			result.force.y -= velocity.y * wave_damping_coefficient * 0.5

	# Buoyancy acts upward (positive Y)
	result.force.y += buoyancy_force

	# Requirement 9.4: Calculate wave influence factor (fades with depth >10m)
	var wave_influence: float = _calculate_wave_influence(hull_depth)

	# Requirement 9.3, 9.5: Apply wave interaction when at surface
	if wave_influence > 0.01:
		var wave_forces = _calculate_wave_interaction(
			position, velocity, wave_height, wave_influence
		)
		result.force += wave_forces.force
		result.torque += wave_forces.torque

	# Requirement 9.6: Apply vertical stabilization when deep
	if hull_depth > wave_influence_depth:
		var stabilization_force: float = -velocity.y * deep_stabilization_coefficient
		result.force.y += stabilization_force

	# Requirement 9.6: Allow surfacing when target depth < 1m
	# (This is handled by the caller, but we ensure buoyancy doesn't prevent it)

	return result


## Calculate submersion ratio based on hull depth
##
## Requirement 9.2: Submersion ratio calculation
##
## Parameters:
##   hull_depth: Depth of submarine center below water surface (positive = submerged)
##
## Returns:
##   Submersion ratio [0.0, 1.0]
func _calculate_submersion_ratio(hull_depth: float) -> float:
	# If submarine is completely above water, no buoyancy
	if hull_depth < -hull_height * 0.5:
		return 0.0

	# If submarine is completely submerged, full buoyancy
	if hull_depth > hull_height * 0.5:
		return 1.0

	# Linear interpolation for partial submersion
	# When hull_depth = -hull_height/2 (top of hull at surface), ratio = 0
	# When hull_depth = +hull_height/2 (bottom of hull at surface), ratio = 1
	var ratio: float = (hull_depth + hull_height * 0.5) / hull_height
	return clamp(ratio, 0.0, 1.0)


## Calculate wave influence factor based on depth
##
## Requirement 9.4: Wave influence fades with depth >10m
##
## Parameters:
##   hull_depth: Depth of submarine center below water surface
##
## Returns:
##   Wave influence factor [0.0, 1.0]
func _calculate_wave_influence(hull_depth: float) -> float:
	# No wave influence when above water
	if hull_depth < 0.0:
		return 0.0

	# Full wave influence at surface
	if hull_depth < surface_threshold:
		return 1.0

	# Requirement 9.4: Fade wave influence from surface to wave_influence_depth
	if hull_depth >= wave_influence_depth:
		return 0.0

	# Linear fade from 1.0 at surface_threshold to 0.0 at wave_influence_depth
	var fade_range: float = wave_influence_depth - surface_threshold
	var depth_in_range: float = hull_depth - surface_threshold
	var influence: float = 1.0 - (depth_in_range / fade_range)

	return clamp(influence, 0.0, 1.0)


## Calculate wave interaction forces and torques
##
## Requirements 9.3, 9.5: Spring force to follow waves and wave-induced roll/pitch
##
## Parameters:
##   position: Submarine position
##   velocity: Submarine velocity
##   wave_height: Current wave height at position
##   wave_influence: Wave influence factor [0.0, 1.0]
##
## Returns:
##   Dictionary with force and torque vectors
func _calculate_wave_interaction(
	position: Vector3, velocity: Vector3, wave_height: float, wave_influence: float
) -> Dictionary:
	var result = {"force": Vector3.ZERO, "torque": Vector3.ZERO}

	# Requirement 9.3: Apply spring force to follow wave height
	var height_error: float = wave_height - position.y
	var spring_force: float = height_error * wave_spring_coefficient * wave_influence

	# Apply damping to prevent oscillation
	var damping_force: float = -velocity.y * wave_damping_coefficient * wave_influence

	result.force.y = spring_force + damping_force

	# Requirement 9.5: Apply wave-induced roll and pitch torques
	# Simplified model: waves create small random torques at surface
	# In a more advanced model, we would sample wave gradient to determine torque direction
	# For now, use a simple damping-based approach to create realistic surface motion

	# Wave-induced pitch torque (around X-axis)
	# Proportional to forward velocity and wave influence
	var pitch_torque: float = velocity.z * wave_torque_coefficient * wave_influence * 0.01
	result.torque.x = pitch_torque

	# Wave-induced roll torque (around Z-axis)
	# Proportional to sideways velocity and wave influence
	var roll_torque: float = velocity.x * wave_torque_coefficient * wave_influence * 0.01
	result.torque.z = roll_torque

	return result


## Update configuration parameters
func configure(config: Dictionary) -> void:
	if config.has("water_density"):
		water_density = config.water_density
	if config.has("submarine_volume"):
		submarine_volume = config.submarine_volume
	if config.has("buoyancy_coefficient"):
		buoyancy_coefficient = config.buoyancy_coefficient
	if config.has("wave_influence_depth"):
		wave_influence_depth = config.wave_influence_depth
	if config.has("wave_spring_coefficient"):
		wave_spring_coefficient = config.wave_spring_coefficient
	if config.has("wave_damping_coefficient"):
		wave_damping_coefficient = config.wave_damping_coefficient
	if config.has("wave_torque_coefficient"):
		wave_torque_coefficient = config.wave_torque_coefficient
	if config.has("deep_stabilization_coefficient"):
		deep_stabilization_coefficient = config.deep_stabilization_coefficient
	if config.has("hull_height"):
		hull_height = config.hull_height
	if config.has("surface_threshold"):
		surface_threshold = config.surface_threshold
	if config.has("surface_riding_boost"):
		surface_riding_boost = config.surface_riding_boost
