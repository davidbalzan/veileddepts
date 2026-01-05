class_name SubmarinePhysicsV2
extends Node

## Submarine Physics Engine v2
##
## Complete rewrite of submarine physics with improved stability, realistic control surfaces,
## and extensible drag modeling. Maintains API compatibility with SubmarinePhysics.
##
## Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7,
##               17.1, 17.2, 17.3, 17.4, 17.5

# References to other systems (Requirement 17.2)
var submarine_body: RigidBody3D
var ocean_renderer
var simulation_state

# Component systems
var coordinate_system = CoordinateSystem  # Static utility class
var appendage_drag_registry: AppendageDragRegistry
var hydrodynamic_drag: HydrodynamicDrag
var propulsion_system: PropulsionSystem
var rudder_system: RudderSystem
var dive_plane_system: DivePlaneSystem
var ballast_system: BallastSystem
var buoyancy_system: BuoyancySystem
var hull_lift_system: HullLiftSystem
var physics_validator: PhysicsValidator

# Cached values for performance (Requirement 12.4, 15.2)
var _cached_forward_direction: Vector3 = Vector3.FORWARD
var _cache_frame: int = -1

# Configuration parameters (Requirement 13.1)
var mass: float = 8000.0  # tons
var max_speed: float = 10.3  # m/s (20 knots)
var max_depth: float = 400.0  # meters
const MAX_SAFE_PITCH: float = 20.0  # Maximum pitch angle in degrees (hard safety limit)
const SURFACE_MODE_DEPTH: float = 20.0  # Depth below which surface mode activates (start leveling)
const PERISCOPE_DEPTH: float = 12.0  # Target depth for leveling before breach (must be level here)
const SURFACE_FLOAT_DEPTH: float = 2.5  # Final floating depth after breach (conning tower visible)
const HULL_HEIGHT: float = 8.0  # Approximate submarine hull height for clearance calculations
# Note: map_boundary removed - dynamic terrain streaming allows unlimited exploration

# Debug mode (Requirement 14.1)
var debug_mode: bool = false:
	set(value):
		debug_mode = value
		_update_component_debug_mode()

# Submarine class presets (Requirement 13.2)
const SUBMARINE_CLASSES = {
	"Los_Angeles_Class":
	{
		"class_name": "Los Angeles Class (SSN-688)",
		"mass": 6000.0,
		"max_speed": 15.4,  # 30 knots
		"max_depth": 450.0,
		"propulsion": {"max_thrust": 45000000.0, "kp_speed": 1.5, "max_speed": 15.4},
		"drag": {"base_forward_drag": 4500.0, "sideways_drag": 1800000.0},
		"rudder": {"torque_coefficient": 280000.0, "max_turn_rate": 3.0},
		"dive_planes": {"torque_coefficient": 1200000.0},
		"ballast": {"max_ballast_force": 45000000.0},
		"buoyancy": {"submarine_volume": 6000.0}
	},
	"Ohio_Class":
	{
		"class_name": "Ohio Class (SSBN-726)",
		"mass": 18000.0,
		"max_speed": 12.9,  # 25 knots
		"max_depth": 300.0,
		"propulsion": {"max_thrust": 60000000.0, "kp_speed": 1.3, "max_speed": 12.9},
		"drag": {"base_forward_drag": 6000.0, "sideways_drag": 2400000.0},
		"rudder": {"torque_coefficient": 200000.0, "max_turn_rate": 2.0},
		"dive_planes": {"torque_coefficient": 1500000.0},
		"ballast": {"max_ballast_force": 70000000.0},
		"buoyancy": {"submarine_volume": 18000.0}
	},
	"Virginia_Class":
	{
		"class_name": "Virginia Class (SSN-774)",
		"mass": 7800.0,
		"max_speed": 12.9,  # 25 knots
		"max_depth": 490.0,
		"propulsion": {"max_thrust": 40000000.0, "kp_speed": 1.5, "max_speed": 12.9},
		"drag": {"base_forward_drag": 4800.0, "sideways_drag": 1920000.0},
		"rudder": {"torque_coefficient": 260000.0, "max_turn_rate": 3.0},
		"dive_planes": {"torque_coefficient": 1100000.0},
		"ballast": {"max_ballast_force": 48000000.0},
		"buoyancy": {"submarine_volume": 7800.0}
	},
	"Seawolf_Class":
	{
		"class_name": "Seawolf Class (SSN-21)",
		"mass": 9100.0,
		"max_speed": 18.0,  # 35 knots
		"max_depth": 600.0,
		"propulsion": {"max_thrust": 55000000.0, "kp_speed": 1.6, "max_speed": 18.0},
		"drag": {"base_forward_drag": 4200.0, "sideways_drag": 1680000.0},
		"rudder": {"torque_coefficient": 320000.0, "max_turn_rate": 3.5},
		"dive_planes": {"torque_coefficient": 1300000.0},
		"ballast": {"max_ballast_force": 52000000.0},
		"buoyancy": {"submarine_volume": 9100.0}
	},
	"Default":
	{
		"class_name": "Generic Attack Submarine",
		"mass": 8000.0,
		"max_speed": 10.3,
		"max_depth": 400.0,
		"propulsion": {"max_thrust": 50000000.0, "kp_speed": 1.5, "max_speed": 10.3},
		"drag": {"base_forward_drag": 5000.0, "sideways_drag": 2000000.0},
		"rudder": {"torque_coefficient": 250000.0, "max_turn_rate": 3.0},
		"dive_planes": {"torque_coefficient": 1000000.0},
		"ballast": {"max_ballast_force": 50000000.0},
		"buoyancy": {"submarine_volume": 8000.0}
	}
}


func _ready() -> void:
	# Physics will be initialized when connected to other systems
	pass


## Initialize the physics system with required references
## Requirement 17.2: Same initialization parameters as SubmarinePhysics
func initialize(p_submarine_body: RigidBody3D, p_ocean_renderer, p_simulation_state) -> void:
	submarine_body = p_submarine_body
	ocean_renderer = p_ocean_renderer
	simulation_state = p_simulation_state

	if not submarine_body:
		push_error("SubmarinePhysicsV2: submarine_body is null")
		return

	if not ocean_renderer:
		push_error("SubmarinePhysicsV2: ocean_renderer is null")
		return

	if not simulation_state:
		push_error("SubmarinePhysicsV2: simulation_state is null")
		return

	# Set submarine mass
	submarine_body.mass = mass * 1000.0  # Convert tons to kg

	# Instantiate all component systems (Requirement 12.3)
	_instantiate_components()

	print("SubmarinePhysicsV2 initialized")


## Instantiate all component systems with default configurations
func _instantiate_components() -> void:
	# Create appendage drag registry
	appendage_drag_registry = AppendageDragRegistry.new()

	# Create hydrodynamic drag component
	hydrodynamic_drag = HydrodynamicDrag.new()

	# Create propulsion system
	propulsion_system = PropulsionSystem.new(
		{"max_thrust": 50000000.0, "kp_speed": 1.5, "max_speed": max_speed}
	)

	# Create rudder system - use realistic values (submarines turn slowly)
	rudder_system = RudderSystem.new({"torque_coefficient": 250000.0, "max_turn_rate": 3.0})
	rudder_system.debug_mode = debug_mode
	rudder_system.log_callback = _log_debug

	# Create dive plane system
	dive_plane_system = DivePlaneSystem.new({"torque_coefficient": 1500.0})

	# Create ballast system
	ballast_system = BallastSystem.new({"max_ballast_force": 50000000.0})

	# Create buoyancy system
	buoyancy_system = BuoyancySystem.new({"submarine_volume": 8000.0})

	# Create hull lift system
	hull_lift_system = HullLiftSystem.new()

	# Create physics validator
	physics_validator = PhysicsValidator.new()


## Get cached forward direction (recalculated once per frame)
## Requirement 12.4, 15.2: Cache forward direction for performance
func _get_forward_direction() -> Vector3:
	var frame = Engine.get_process_frames()
	if _cache_frame != frame:
		_cached_forward_direction = CoordinateSystem.forward_direction_from_transform(
			submarine_body.global_transform
		)
		_cache_frame = frame

		# Safety check for NaN values (Requirement 16.1)
		if not physics_validator.validate_vector(_cached_forward_direction, "forward_direction"):
			_cached_forward_direction = Vector3.FORWARD
			# Reset submarine transform to prevent cascading NaN
			if submarine_body:
				submarine_body.global_transform = Transform3D(
					Basis(), submarine_body.global_position
				)

	return _cached_forward_direction


## Get local pitch angle in radians (nose up/down)
## Calculates true pitch relative to submarine's local frame, not world Euler angles
## This ensures correct pitch reading regardless of submarine heading
## 
## CRITICAL FIX (TASK-011): Using local frame angles instead of world-frame Euler angles
## Euler rotation.x/z values are world-aligned and become incorrect when submarine turns.
## This was the root cause of "pitch only works after turning" bug.
func _get_local_pitch() -> float:
	if not submarine_body:
		return 0.0
	
	var basis = submarine_body.global_transform.basis
	var forward = -basis.z  # Local forward direction (-Z in Godot)
	
	# Pitch is the angle between forward vector and horizontal plane
	# Positive pitch = nose up, negative pitch = nose down
	var local_pitch = asin(clamp(-forward.y, -1.0, 1.0))
	
	return local_pitch


## Get local roll angle in radians (bank left/right)
## Calculates true roll relative to submarine's local frame, not world Euler angles
## This ensures correct roll reading regardless of submarine heading
func _get_local_roll() -> float:
	if not submarine_body:
		return 0.0
	
	var basis = submarine_body.global_transform.basis
	var forward = -basis.z  # Local forward direction (-Z)
	var up = basis.y        # Local up direction (Y)
	var right = basis.x     # Local right direction (X)
	
	# Project local up onto plane perpendicular to forward
	var up_projected = up - forward * up.dot(forward)
	if up_projected.length_squared() < 0.0001:
		# Submarine is pointing straight up or down, roll is undefined
		return 0.0
	up_projected = up_projected.normalized()
	
	# Project world up onto same plane
	var world_up = Vector3.UP
	var world_up_projected = world_up - forward * world_up.dot(forward)
	if world_up_projected.length_squared() < 0.0001:
		# Edge case: submarine pointing straight up/down
		return 0.0
	world_up_projected = world_up_projected.normalized()
	
	# Calculate angle between projected vectors
	var cos_roll = clamp(up_projected.dot(world_up_projected), -1.0, 1.0)
	var local_roll = acos(cos_roll)
	
	# Determine sign: positive roll = right side down
	if right.dot(world_up) < 0:
		local_roll = -local_roll
	
	return local_roll


## Update all physics forces
## Requirement 12.1: Execute physics updates in correct order
## Requirement 17.2: Same interface as SubmarinePhysics
func update_physics(delta: float) -> void:
	if not submarine_body:
		return

	# Step 1: Validate submarine state (detect NaN) - Requirement 12.1
	if not physics_validator.validate_and_fix_submarine_state(submarine_body):
		_log_debug("Submarine state was invalid and has been reset")
		return  # Skip this frame to allow reset

	# Step 2: Cache forward direction - Requirement 12.4
	var forward_dir = _get_forward_direction()

	# Get current state for calculations
	var position = submarine_body.global_position
	var velocity = submarine_body.linear_velocity
	
	# CRITICAL FIX: Depth must be calculated relative to ACTUAL ocean surface, not just -Y
	# The ocean renderer's Y position IS the sea surface
	var sea_surface_y = 0.0
	if ocean_renderer:
		sea_surface_y = ocean_renderer.get_wave_height_3d(position)
	else:
		# Fallback: use ocean_renderer node Y position if wave height unavailable
		var ocean_node = get_tree().root.get_node_or_null("Main/OceanRenderer")
		if ocean_node:
			sea_surface_y = ocean_node.global_position.y
	
	var depth = sea_surface_y - position.y  # Depth = how far below surface
	depth = max(0.0, depth)  # Clamp to surface - can't fly above water!
	
	# Debug logging every 2 seconds
	if debug_mode and Engine.get_process_frames() % 120 == 0:
		print("[DEPTH DEBUG] pos.y=%.2f, sea_y=%.2f, depth=%.2f" % [position.y, sea_surface_y, depth])
	
	# CRITICAL: When at surface, submarine should be partially submerged, not flying
	# The submarine's pivot is at its center, so when "at surface" the center should be
	# at the waterline (Y = wave_height). This makes the conning tower visible above water.
	if depth <= 0.5 and ocean_renderer:  # At or very near surface
		var ocean_surface_y = ocean_renderer.get_wave_height_3d(position)
		# Target position: submarine center at waterline (so ~half hull is submerged)
		var target_y = ocean_surface_y
		var y_error = position.y - target_y
		
		if abs(y_error) > 0.2:  # More than 20cm off target
			# Smoothly move toward correct position (not instant snap)
			position.y = lerp(position.y, target_y, 0.1)
			submarine_body.global_position = position
			# Dampen vertical velocity when correcting
			velocity.y *= 0.8
			submarine_body.linear_velocity = velocity
	
	var forward_speed = velocity.dot(forward_dir)
	# Use total speed for dive plane effectiveness - water still flows even when turning
	var effective_speed_for_planes = max(abs(forward_speed), velocity.length() * 0.7)

	# Get control inputs from simulation state
	var target_speed = simulation_state.target_speed if simulation_state else 0.0
	var target_heading = simulation_state.target_heading if simulation_state else 0.0
	var target_depth = simulation_state.target_depth if simulation_state else 0.0
	
	# SURFACE MODE: Multi-stage surfacing behavior
	# Stage 1 (20-12m): Level out to periscope depth
	# Stage 2 (12-2.5m): Let buoyancy bring sub to surface naturally
	# Stage 3 (<2.5m): Maintain stable float at surface
	# CRITICAL: Only activate surface mode if BOTH target is shallow AND we're already shallow
	var effective_target_depth = target_depth
	var surface_mode = false
	
	# Surface mode only activates when trying to surface from shallow depth
	# This allows diving back down from surface
	if target_depth < SURFACE_MODE_DEPTH and depth < SURFACE_MODE_DEPTH:
		surface_mode = true
		
		if depth > PERISCOPE_DEPTH:
			# Stage 1: Approaching periscope depth - actively control to PERISCOPE_DEPTH
			effective_target_depth = PERISCOPE_DEPTH
		elif depth > SURFACE_FLOAT_DEPTH:
			# Stage 2: Between periscope and float depth - let buoyancy take over
			# Target slightly above float depth to allow natural settling
			effective_target_depth = SURFACE_FLOAT_DEPTH + 0.5
		else:
			# Stage 3: At surface - maintain float depth
			effective_target_depth = SURFACE_FLOAT_DEPTH
	
	# If target depth is deeper than current, exit surface mode immediately
	if target_depth > depth + 5.0:
		surface_mode = false
		effective_target_depth = target_depth

	# Calculate current heading
	var current_heading = CoordinateSystem.calculate_heading(forward_dir)

	# Step 3: Calculate and apply buoyancy forces - Requirement 12.1
	var buoyancy_result = buoyancy_system.calculate_buoyancy_force(
		position, velocity, target_depth, ocean_renderer
	)
	if physics_validator.validate_vector(buoyancy_result.force, "buoyancy_force"):
		submarine_body.apply_central_force(buoyancy_result.force)
	if physics_validator.validate_vector(buoyancy_result.torque, "buoyancy_torque"):
		submarine_body.apply_torque(buoyancy_result.torque)

	# Step 4: Calculate and apply drag forces - Requirement 12.1
	var drag_force = hydrodynamic_drag.calculate_drag_force(
		velocity, forward_dir, depth, appendage_drag_registry
	)
	if physics_validator.validate_vector(drag_force, "drag_force"):
		submarine_body.apply_central_force(drag_force)

	# Step 5: Calculate and apply propulsion forces - Requirement 12.1
	var propulsion_force = propulsion_system.calculate_propulsion_force(
		forward_dir, velocity, target_speed, target_heading, delta
	)
	if physics_validator.validate_vector(propulsion_force, "propulsion_force"):
		submarine_body.apply_central_force(propulsion_force)

	# Step 6: Calculate and apply rudder torques - Requirement 12.1
	var angular_velocity = submarine_body.angular_velocity.y
	var steering_torque = rudder_system.calculate_steering_torque(
		current_heading, target_heading, forward_speed, angular_velocity
	)
	if is_finite(steering_torque):
		submarine_body.apply_torque(Vector3(0, steering_torque, 0))

	# Step 7: Calculate and apply dive plane torques - Requirement 12.1
	var current_pitch = _get_local_pitch()  # Use local pitch instead of world Euler angle
	var vertical_velocity = velocity.y
	var pitch_angular_velocity = submarine_body.angular_velocity.x
	
	var ascent_rate = -vertical_velocity  # Positive = ascending
	var descent_rate = vertical_velocity  # Positive = descending
	var pitch_deg = rad_to_deg(current_pitch)
	
	# ABSOLUTE HARD PITCH LIMIT - submarines should NEVER exceed ~20° pitch
	# Real submarines rarely exceed 15° even in emergency maneuvers
	const ABSOLUTE_MAX_PITCH: float = 20.0
	
	# S-CURVE DEPTH CONTROL for ALL depth changes
	# Key insight: limit pitch based on distance to target, not just surface
	# This creates smooth approaches to ANY target depth
	
	var dive_plane_torque = 0.0
	var is_surfacing = effective_target_depth < 5.0
	var depth_error = effective_target_depth - depth
	var distance_to_target = abs(depth_error)
	var is_ascending = depth_error < 0  # Need to go up
	var is_descending = depth_error > 0  # Need to go down
	
	# Calculate maximum allowed pitch based on distance to target
	# The closer we are, the more level we need to be (S-curve approach)
	var max_pitch_for_depth = 12.0  # Default cruise pitch (reduced from 15)
	
	if distance_to_target < 10.0:
		max_pitch_for_depth = 3.0  # Very close - almost level
	elif distance_to_target < 25.0:
		max_pitch_for_depth = 5.0  # Approaching - gentle
	elif distance_to_target < 50.0:
		max_pitch_for_depth = 8.0  # Getting close - moderate
	elif distance_to_target < 100.0:
		max_pitch_for_depth = 10.0  # Mid-range
	else:
		max_pitch_for_depth = 12.0  # Far away - still limited
	
	# Extra restriction when surfacing (water surface is hard boundary)
	if is_surfacing:
		if depth < 10.0:
			max_pitch_for_depth = min(max_pitch_for_depth, 3.0)
		elif depth < 25.0:
			max_pitch_for_depth = min(max_pitch_for_depth, 5.0)
	
	# HARD PITCH LIMITER - ALWAYS ACTIVE regardless of depth control phase
	# This is a safety system that overrides everything else
	if abs(pitch_deg) > ABSOLUTE_MAX_PITCH:
		# EMERGENCY: Pitch is dangerously high - apply maximum corrective torque
		var emergency_overshoot = abs(pitch_deg) - ABSOLUTE_MAX_PITCH
		var emergency_strength = 50000000.0 * (1.0 + emergency_overshoot / 5.0)  # Very aggressive
		
		dive_plane_torque = -sign(pitch_deg) * emergency_overshoot * emergency_strength
		dive_plane_torque += -pitch_angular_velocity * 30000000.0  # Strong damping
		dive_plane_torque = clamp(dive_plane_torque, -150000000.0, 150000000.0)
		
		if debug_mode:
			print("[EMERGENCY PITCH] %.1f° exceeds limit! Applying %.0f Nm correction" % [pitch_deg, dive_plane_torque])
	
	# PROACTIVE PITCH LIMITING for all depth changes (kicks in earlier than emergency)
	elif abs(pitch_deg) > max_pitch_for_depth:
		var pitch_overshoot = abs(pitch_deg) - max_pitch_for_depth
		var correction_strength = 40000000.0 * (1.0 + pitch_overshoot / 5.0)  # Increased strength
		
		# Apply correction torque to reduce pitch
		dive_plane_torque = -sign(pitch_deg) * pitch_overshoot * correction_strength
		
		# Add strong damping to prevent oscillation
		dive_plane_torque += -pitch_angular_velocity * 25000000.0
		
		dive_plane_torque = clamp(dive_plane_torque, -120000000.0, 120000000.0)
	else:
		# Normal S-curve control from dive_plane_system
		dive_plane_torque = dive_plane_system.calculate_dive_plane_torque(
			depth, effective_target_depth, vertical_velocity, effective_speed_for_planes, 
			pitch_deg, pitch_angular_velocity, max_pitch_for_depth
		)
	
	# AT TARGET DEPTH: Actively level the submarine (pitch -> 0°)
	# This ensures we don't maintain any pitch once we've reached desired depth
	if distance_to_target < 5.0:
		# We're at target depth - force pitch to zero
		var level_torque = -current_pitch * 40000000.0  # Strong leveling
		level_torque += -pitch_angular_velocity * 20000000.0  # Damping
		dive_plane_torque = level_torque  # Override other commands
	
	# VELOCITY-BASED APPROACH CONTROL - slow down when approaching target
	# Ascending fast toward target
	elif is_ascending and distance_to_target < 50.0 and ascent_rate > 1.5:
		var approach_strength = (ascent_rate / 3.0) * ((50.0 - distance_to_target) / 50.0)
		var approach_torque = -current_pitch * 25000000.0 * approach_strength
		approach_torque += -pitch_angular_velocity * 15000000.0 * approach_strength
		dive_plane_torque += approach_torque
	# Descending fast toward target  
	elif is_descending and distance_to_target < 50.0 and descent_rate > 1.5:
		var approach_strength = (descent_rate / 3.0) * ((50.0 - distance_to_target) / 50.0)
		var approach_torque = -current_pitch * 25000000.0 * approach_strength
		approach_torque += -pitch_angular_velocity * 15000000.0 * approach_strength
		dive_plane_torque += approach_torque
	
	# AT SURFACE: Maximum leveling - dive planes are ineffective above water
	if depth < 3.0:
		dive_plane_torque = -current_pitch * 80000000.0
		dive_plane_torque += -pitch_angular_velocity * 30000000.0
	
	# Debug: Log depth control behavior
	if debug_mode and Engine.get_process_frames() % 120 == 0:
		var mode_str = "SURFACE" if surface_mode else "DIVE"
		var direction_str = "ASC" if is_ascending else ("DESC" if is_descending else "HOLD")
		var at_depth_str = " [AT DEPTH]" if distance_to_target < 5.0 else ""
		print("[PITCH DEBUG] %s %s dist=%.0fm pitch=%.1f° maxPitch=%.0f° fwd=%.1f m/s depth=%.1fm torque=%.0f Nm%s" % [
			mode_str, direction_str, distance_to_target, rad_to_deg(current_pitch), max_pitch_for_depth, forward_speed, depth, dive_plane_torque, at_depth_str
		])
	
	# Log excessive torques
	if abs(dive_plane_torque) > 10000000.0:  # > 10M Nm
		print("[TORQUE WARNING] Excessive dive plane torque: %.0f Nm (speed=%.1f, pitch=%.1f°)" % [
			dive_plane_torque, forward_speed, rad_to_deg(current_pitch)
		])
	
	# CRITICAL FIX: Apply torque in LOCAL coordinates, not world coordinates!
	# The submarine's local X-axis is the pitch axis regardless of heading
	var local_pitch_axis = submarine_body.global_transform.basis.x
	if is_finite(dive_plane_torque):
		submarine_body.apply_torque(local_pitch_axis * dive_plane_torque)
	
	# Roll stabilization - submarines have natural righting moment due to ballast tanks
	# Two components: (1) righting torque proportional to roll angle, (2) damping proportional to angular velocity
	var local_roll_axis = submarine_body.global_transform.basis.z
	var current_roll = _get_local_roll()  # Use local roll instead of world Euler angle
	var roll_angular_velocity = submarine_body.angular_velocity.dot(local_roll_axis)

	# Base righting torque - pushes sub back to level (like a ship's metacentric height)
	var roll_righting_coefficient = 25000000.0  # TASK-001: Increased from 8M to overcome ~100M kg·m² inertia
	
	# CRITICAL: Increase roll stabilization during aggressive pitch maneuvers
	# When dive planes are near max deflection, roll stability is compromised
	var abs_pitch_deg = abs(pitch_deg)  # Use pitch_deg from dive plane section above
	if abs_pitch_deg > 10.0:  # Aggressive pitch maneuver
		# Boost roll stabilization proportionally to pitch angle
		var pitch_factor = 1.0 + (abs_pitch_deg / 15.0) * 2.0  # Up to 3x stronger at 15° pitch
		roll_righting_coefficient *= pitch_factor
	
	# During ascent/descent, further boost roll stabilization
	if abs(vertical_velocity) > 0.5:  # Significant vertical motion
		var velocity_factor = 1.0 + min(abs(vertical_velocity) / 2.0, 1.5)  # Up to 2.5x stronger
		roll_righting_coefficient *= velocity_factor
	
	var roll_righting_torque = -current_roll * roll_righting_coefficient

	# Damping torque - prevents oscillation (also boosted during maneuvers)
	var roll_damping_coefficient = 6000000.0  # Base damping
	if abs_pitch_deg > 10.0 or abs(vertical_velocity) > 0.5:
		roll_damping_coefficient *= 2.0  # Double damping during maneuvers
	var roll_damping_torque = -roll_angular_velocity * roll_damping_coefficient

	# Apply combined roll correction
	submarine_body.apply_torque(local_roll_axis * (roll_righting_torque + roll_damping_torque))
	
	# SURFACE ROLL LEVELING: Also force roll to 0° when at surface
	# Submarines float level in water - both pitch AND roll should be zero
	if depth < 5.0:
		var surface_roll_strength = (5.0 - depth) / 5.0  # 0.0 at 5m, 1.0 at surface
		var surface_roll_torque = -current_roll * 10000000.0 * surface_roll_strength
		submarine_body.apply_torque(local_roll_axis * surface_roll_torque)
		
		# Damp roll angular velocity at surface
		var roll_damping_at_surface = -roll_angular_velocity * 8000000.0 * surface_roll_strength
		submarine_body.apply_torque(local_roll_axis * roll_damping_at_surface)
	
	# Manual pitch damping to prevent oscillation (use local X axis)
	# With torque_coefficient at 1500, we need proportional damping
	# Target: critical damping for smooth pitch response without oscillation
	var pitch_damping_coefficient = 300000.0  # Proportional to current torque coefficient
	var local_pitch_angular_velocity = submarine_body.angular_velocity.dot(local_pitch_axis)
	var pitch_damping_torque = -local_pitch_angular_velocity * pitch_damping_coefficient
	submarine_body.apply_torque(local_pitch_axis * pitch_damping_torque)

	# LOW-SPEED PITCH ASSIST: When moving slowly, use ballast-induced pitch for depth control
	# Real subs use trim tanks to adjust pitch at low speeds - simulate this
	if abs(forward_speed) < 2.0:  # Low speed threshold
		var low_speed_depth_error = target_depth - depth
		# For ascending (depth_error < 0), pitch nose up slightly to help
		# For descending (depth_error > 0), pitch nose down slightly
		var desired_pitch_for_depth = -low_speed_depth_error * 0.01  # Subtle pitch per meter of depth error
		desired_pitch_for_depth = clamp(desired_pitch_for_depth, -0.15, 0.15)  # Max ~8.5 degrees

		var pitch_error_for_assist = desired_pitch_for_depth - current_pitch
		var low_speed_pitch_torque = pitch_error_for_assist * 2000000.0  # Gentle correction

		# Scale by how slow we are (full effect at 0 m/s, none at 2 m/s)
		var low_speed_factor = 1.0 - (abs(forward_speed) / 2.0)
		submarine_body.apply_torque(local_pitch_axis * low_speed_pitch_torque * low_speed_factor)
	
	# SAFETY: Hard pitch angle limiter - prevent submarine from going vertical
	# Clamp pitch to ±30° maximum (anything more is catastrophic for crew)
	var current_pitch_deg = rad_to_deg(current_pitch)  # Already using local pitch
	
	# Get local pitch axis for remaining operations
	var local_pitch_axis_for_safety = submarine_body.global_transform.basis.x
	
	# SURFACE LEVELING: Force pitch to 0° when at/near surface
	# Progressive leveling starts at 10m depth, becomes very strong at surface
	if depth < 10.0:
		var surface_level_strength: float
		
		if depth < 1.0:
			# Very close to surface (< 1m): Maximum leveling force
			surface_level_strength = 1.0
		else:
			# 1-10m: Progressive increase (0.0 at 10m, 1.0 at 1m)
			surface_level_strength = (10.0 - depth) / 9.0
		
		# Strong righting torque proportional to pitch angle
		# Use much higher coefficient for surface leveling
		var level_torque = -current_pitch * 15000000.0 * surface_level_strength
		submarine_body.apply_torque(local_pitch_axis_for_safety * level_torque)
		
		# Aggressively damp pitch angular velocity at surface
		var local_pitch_vel = submarine_body.angular_velocity.dot(local_pitch_axis_for_safety)
		var damping_strength = surface_level_strength * 0.95  # Near-complete damping at surface
		submarine_body.angular_velocity -= local_pitch_axis_for_safety * local_pitch_vel * damping_strength
		
		# At surface (< 0.5m), physically snap to level if pitch is extreme
		if depth < 0.5 and abs(current_pitch) > deg_to_rad(10.0):
			# Emergency level: Directly reduce pitch angle
			var target_basis = Basis()
			target_basis = target_basis.rotated(Vector3.UP, submarine_body.rotation.y)  # Preserve heading
			submarine_body.global_transform.basis = submarine_body.global_transform.basis.slerp(target_basis, 0.3)
			# Zero pitch velocity
			submarine_body.angular_velocity -= local_pitch_axis_for_safety * local_pitch_vel
	
	if abs(current_pitch_deg) > MAX_SAFE_PITCH:
		# EMERGENCY: Force pitch back within limits immediately
		var pitch_overshoot = abs(current_pitch_deg) - MAX_SAFE_PITCH
		# Use VERY strong correction - this is a hard safety limit
		var correction_torque = -sign(current_pitch) * pitch_overshoot * 50000000.0  # 100x stronger
		submarine_body.apply_torque(local_pitch_axis_for_safety * correction_torque)
		# Aggressively damp pitch rotation
		var local_pitch_vel = submarine_body.angular_velocity.dot(local_pitch_axis_for_safety)
		submarine_body.angular_velocity -= local_pitch_axis_for_safety * local_pitch_vel * 0.8  # 80% damping
		if debug_mode or abs(current_pitch_deg) > 25.0:  # Always warn if very extreme
			print("[SAFETY] Pitch limiter engaged: %.1f° exceeds %.1f° limit! Correcting..." % [current_pitch_deg, MAX_SAFE_PITCH])

	# Step 7b: Calculate and apply hull lift forces (from pitch angle + forward speed)
	var hull_lift_force = hull_lift_system.calculate_hull_lift_with_damping(
		current_pitch, velocity, submarine_body.global_transform.basis
	)
	if physics_validator.validate_vector(hull_lift_force, "hull_lift_force"):
		submarine_body.apply_central_force(hull_lift_force)
		
		# Log forces to black box and console every second
		if Engine.get_process_frames() % 60 == 0:
			var main = get_tree().root.get_node_or_null("Main")
			if main and main.has_node("BlackBoxLogger"):
				var bb = main.get_node("BlackBoxLogger")
				var buoy_y = buoyancy_result.force.y if buoyancy_result else 0.0
				bb.log_forces(hull_lift_force.y, buoy_y, dive_plane_torque)
				# Detailed console output with rotation and torques
				var rot = submarine_body.rotation_degrees
				var ang_vel = submarine_body.angular_velocity
				print("[PHYSICS] spd=%.1f pitch=%.1f° roll=%.1f° | lift=%.0fN buoy=%.0fN" % [
					abs(forward_speed), rot.x, rot.z,
					hull_lift_force.y, buoy_y
				])
				print("[TORQUE] dive=%.0f steer=%.0f buoy=(%.1f,%.1f,%.1f) angvel=(%.2f,%.2f,%.2f)" % [
					dive_plane_torque, steering_torque,
					buoyancy_result.torque.x, buoyancy_result.torque.y, buoyancy_result.torque.z,
					ang_vel.x, ang_vel.y, ang_vel.z
				])

	# Step 8: Calculate and apply ballast forces - Requirement 12.1
	# In surface mode, use reduced ballast to allow natural floating
	var ballast_force = ballast_system.calculate_ballast_force(
		depth, effective_target_depth, vertical_velocity, delta
	)
	if surface_mode:
		ballast_force *= 0.3  # Reduce ballast effectiveness at surface
	
	if is_finite(ballast_force):
		submarine_body.apply_central_force(Vector3(0, -ballast_force, 0))  # Negative because ballast is positive down

	# Debug output for ascent troubleshooting (every 60 frames)
	if debug_mode and Engine.get_process_frames() % 60 == 0:
		var buoy_y = buoyancy_result.force.y if buoyancy_result else 0.0
		print("[PhysicsV2] depth=%.1fm, target=%.1fm, vel_y=%.2f, ballast=%.0fN, buoyancy=%.0fN" % [
			depth, target_depth, vertical_velocity, -ballast_force, buoy_y
		])

	# Step 9: Apply sideways velocity elimination - Requirement 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
	_apply_sideways_velocity_elimination(forward_dir)

	# Step 10: Apply velocity alignment - Requirement 7.1, 7.2, 7.3, 7.4, 7.5, 7.6
	_apply_velocity_alignment(forward_dir)

	# Step 11: Clamp velocity - Requirement 10.1
	physics_validator.clamp_velocity(submarine_body, max_speed)

	# Note: Map boundaries removed - dynamic terrain streaming allows unlimited exploration


## Get current submarine state for synchronization
## Requirement 17.3: Same interface as SubmarinePhysics
## Validates: Requirement 9.1 (depth reading relative to sea level)
func get_submarine_state() -> Dictionary:
	if not submarine_body:
		return {}

	var pos = submarine_body.global_position
	var vel = submarine_body.linear_velocity

	# Calculate depth relative to current sea level (Requirement 9.1)
	var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0
	var depth = sea_level_meters - pos.y  # Depth is positive going down from sea level

	# Calculate horizontal speed (exclude vertical component)
	var horizontal_velocity = Vector2(vel.x, vel.z)
	var speed = horizontal_velocity.length()

	# Calculate heading using coordinate system utility
	var forward_dir = _get_forward_direction()
	var heading = CoordinateSystem.calculate_heading(forward_dir)

	return {"position": pos, "velocity": vel, "depth": depth, "heading": heading, "speed": speed}


## Configure physics parameters for a specific submarine class
## Requirement 13.3: Update all physics parameters when class is loaded
func configure_submarine_class(config: Dictionary) -> void:
	# Update main parameters
	if config.has("mass"):
		mass = config["mass"]
		if submarine_body:
			submarine_body.mass = mass * 1000.0

	if config.has("max_speed"):
		max_speed = config["max_speed"]

	if config.has("max_depth"):
		max_depth = config["max_depth"]

	# Update component configurations (Requirement 13.6)
	if config.has("propulsion") and propulsion_system:
		var prop_config = config["propulsion"].duplicate()
		propulsion_system.configure(prop_config)

	if config.has("drag") and hydrodynamic_drag:
		if config["drag"].has("base_forward_drag"):
			hydrodynamic_drag.base_forward_drag = config["drag"]["base_forward_drag"]
		if config["drag"].has("sideways_drag"):
			hydrodynamic_drag.sideways_drag = config["drag"]["sideways_drag"]

	if config.has("rudder") and rudder_system:
		rudder_system.configure(config["rudder"])

	if config.has("dive_planes") and dive_plane_system:
		dive_plane_system.configure(config["dive_planes"])

	if config.has("ballast") and ballast_system:
		ballast_system.configure(config["ballast"])

	if config.has("buoyancy") and buoyancy_system:
		buoyancy_system.configure(config["buoyancy"])

	_log_debug("SubmarinePhysicsV2 configured for class: " + config.get("class_name", "Custom"))


## Load a predefined submarine class by name
## Requirement 13.4: Implement load_submarine_class method
func load_submarine_class(sub_class: String) -> bool:
	if not SUBMARINE_CLASSES.has(sub_class):
		push_error("SubmarinePhysicsV2: Unknown submarine class '%s'" % sub_class)
		return false

	configure_submarine_class(SUBMARINE_CLASSES[sub_class])
	return true


## Get list of available submarine class names
## Requirement 13.5: Implement get_available_classes method
func get_available_classes() -> Array[String]:
	var classes: Array[String] = []
	for key in SUBMARINE_CLASSES.keys():
		classes.append(key)
	return classes


## Level submarine - dampen pitch and roll motion
func level_submarine() -> void:
	if submarine_body:
		var angular_vel = submarine_body.angular_velocity
		# Aggressively dampen pitch (X) and roll (Z) rotation
		submarine_body.angular_velocity = Vector3(
			angular_vel.x * 0.3,  # Dampen pitch
			angular_vel.y,        # Keep yaw unchanged
			angular_vel.z * 0.3   # Dampen roll
		)
		print("SubmarinePhysicsV2: Leveling submarine - dampened pitch and roll")


## Reset ballast system trim
func reset_ballast_trim() -> void:
	if ballast_system:
		ballast_system.reset_pid_state()
		print("SubmarinePhysicsV2: Ballast trim reset")


## Add appendage drag contribution
## Requirement 13.7: Implement appendage drag management methods
func add_appendage_drag(name: String, multiplier: float) -> void:
	if appendage_drag_registry:
		appendage_drag_registry.add_appendage(name, multiplier)
		_log_debug("Added appendage drag: %s (%.2f)" % [name, multiplier])


## Remove appendage drag contribution
## Requirement 13.7: Implement appendage drag management methods
func remove_appendage_drag(name: String) -> void:
	if appendage_drag_registry:
		appendage_drag_registry.remove_appendage(name)
		_log_debug("Removed appendage drag: %s" % name)


## Check if appendage is currently deployed
func has_appendage_drag(name: String) -> bool:
	if appendage_drag_registry:
		return appendage_drag_registry.has_appendage(name)
	return false


## Get total appendage drag multiplier
func get_total_appendage_drag() -> float:
	if appendage_drag_registry:
		return appendage_drag_registry.get_total_drag_multiplier()
	return 0.0


## Clear all appendage drag contributions
func clear_appendage_drag() -> void:
	if appendage_drag_registry:
		appendage_drag_registry.clear_all()
		_log_debug("Cleared all appendage drag")


## Apply sideways velocity elimination to prevent drift
## Requirement 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
func _apply_sideways_velocity_elimination(forward_dir: Vector3) -> void:
	if not submarine_body:
		return

	var velocity = submarine_body.linear_velocity

	# Calculate forward velocity component (Requirement 6.1)
	var forward_speed = velocity.dot(forward_dir)
	var forward_velocity = forward_dir * forward_speed

	# Calculate sideways velocity component perpendicular to forward direction (Requirement 6.1)
	var sideways_velocity = velocity - forward_velocity

	# Get magnitude of sideways velocity
	var sideways_speed = sideways_velocity.length()

	# Only apply correction if sideways velocity exceeds threshold (Requirement 6.2, 6.6)
	if sideways_speed > 0.5:
		# Log only when sideways velocity is significant (Requirement 6.6, 14.2)
		if sideways_speed > 3.0:
			_log_debug("Sideways velocity correction: %.2f m/s" % sideways_speed)

		# Reduce sideways component by 80% per frame (Requirement 6.3)
		# This means we keep only 20% of the sideways velocity
		var corrected_sideways = sideways_velocity * 0.2

		# Reconstruct velocity preserving forward speed (Requirement 6.4)
		var corrected_velocity = forward_velocity + corrected_sideways

		# Directly modify submarine_body.linear_velocity (Requirement 6.5)
		submarine_body.linear_velocity = corrected_velocity


## Apply velocity alignment to gradually align velocity with heading
## Requirement 7.1, 7.2, 7.3, 7.4, 7.5, 7.6
func _apply_velocity_alignment(forward_dir: Vector3) -> void:
	if not submarine_body:
		return

	var velocity = submarine_body.linear_velocity
	var speed = velocity.length()

	# Skip if speed is too low (Requirement 7.2)
	if speed < 1.0:
		return

	# Skip if speed exceeds threshold (Requirement 7.3)
	if speed > max_speed * 1.05:
		return

	# Calculate velocity direction
	var velocity_dir = velocity.normalized()

	# Calculate alignment factor (Requirement 7.1)
	var alignment_factor = velocity_dir.dot(forward_dir)

	# Skip if alignment is already good (Requirement 7.2)
	if alignment_factor > 0.7:
		return

	# Log only when alignment is poor (Requirement 14.3)
	if alignment_factor < 0.3:
		_log_debug("Velocity alignment correction: %.2f" % alignment_factor)

	# Preserve vertical velocity component (Requirement 7.6)
	var vertical_velocity = velocity.y

	# Calculate desired horizontal velocity aligned with heading (Requirement 7.4)
	# Get horizontal speed (magnitude of horizontal velocity)
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var horizontal_speed = horizontal_velocity.length()

	# Create desired velocity aligned with forward direction
	var horizontal_forward = Vector3(forward_dir.x, 0, forward_dir.z).normalized()
	var desired_horizontal_velocity = horizontal_forward * horizontal_speed

	# Apply gradual correction with 10% lerp rate (Requirement 7.5)
	var corrected_horizontal = horizontal_velocity.lerp(desired_horizontal_velocity, 0.1)

	# Reconstruct full velocity preserving vertical component (Requirement 7.6)
	var corrected_velocity = Vector3(
		corrected_horizontal.x, vertical_velocity, corrected_horizontal.z
	)

	# Apply the corrected velocity
	submarine_body.linear_velocity = corrected_velocity


## Log debug message if debug mode is enabled
## Requirement 14.1: Implement debug mode flag
func _log_debug(message: String) -> void:
	if debug_mode:
		print("[SubmarinePhysicsV2] " + message)


## Update debug mode on all components
## Requirement 14.1: Propagate debug mode to components
func _update_component_debug_mode() -> void:
	if rudder_system:
		rudder_system.debug_mode = debug_mode
		rudder_system.log_callback = _log_debug
