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
var physics_validator: PhysicsValidator

# Cached values for performance (Requirement 12.4, 15.2)
var _cached_forward_direction: Vector3 = Vector3.FORWARD
var _cache_frame: int = -1

# Configuration parameters (Requirement 13.1)
var mass: float = 8000.0  # tons
var max_speed: float = 10.3  # m/s (20 knots)
var max_depth: float = 400.0  # meters
var map_boundary: float = 974.0  # ±974m from origin (50m buffer from 1024m terrain edge)

# Debug mode (Requirement 14.1)
var debug_mode: bool = false:
	set(value):
		debug_mode = value
		_update_component_debug_mode()

# Submarine class presets (Requirement 13.2)
const SUBMARINE_CLASSES = {
	"Los_Angeles_Class": {
		"class_name": "Los Angeles Class (SSN-688)",
		"mass": 6000.0,
		"max_speed": 15.4,  # 30 knots
		"max_depth": 450.0,
		"propulsion": {
			"max_thrust": 45000000.0,
			"kp_speed": 1.5,
			"max_speed": 15.4
		},
		"drag": {
			"base_forward_drag": 4500.0,
			"sideways_drag": 1800000.0
		},
		"rudder": {
			"torque_coefficient": 2500000.0,
			"max_turn_rate": 6.0
		},
		"dive_planes": {
			"torque_coefficient": 1200000.0
		},
		"ballast": {
			"max_ballast_force": 45000000.0
		},
		"buoyancy": {
			"submarine_volume": 6000.0
		}
	},
	"Ohio_Class": {
		"class_name": "Ohio Class (SSBN-726)",
		"mass": 18000.0,
		"max_speed": 12.9,  # 25 knots
		"max_depth": 300.0,
		"propulsion": {
			"max_thrust": 60000000.0,
			"kp_speed": 1.3,
			"max_speed": 12.9
		},
		"drag": {
			"base_forward_drag": 6000.0,
			"sideways_drag": 2400000.0
		},
		"rudder": {
			"torque_coefficient": 1500000.0,
			"max_turn_rate": 3.0
		},
		"dive_planes": {
			"torque_coefficient": 1500000.0
		},
		"ballast": {
			"max_ballast_force": 70000000.0
		},
		"buoyancy": {
			"submarine_volume": 18000.0
		}
	},
	"Virginia_Class": {
		"class_name": "Virginia Class (SSN-774)",
		"mass": 7800.0,
		"max_speed": 12.9,  # 25 knots
		"max_depth": 490.0,
		"propulsion": {
			"max_thrust": 40000000.0,
			"kp_speed": 1.5,
			"max_speed": 12.9
		},
		"drag": {
			"base_forward_drag": 4800.0,
			"sideways_drag": 1920000.0
		},
		"rudder": {
			"torque_coefficient": 2300000.0,
			"max_turn_rate": 5.5
		},
		"dive_planes": {
			"torque_coefficient": 1100000.0
		},
		"ballast": {
			"max_ballast_force": 48000000.0
		},
		"buoyancy": {
			"submarine_volume": 7800.0
		}
	},
	"Seawolf_Class": {
		"class_name": "Seawolf Class (SSN-21)",
		"mass": 9100.0,
		"max_speed": 18.0,  # 35 knots
		"max_depth": 600.0,
		"propulsion": {
			"max_thrust": 55000000.0,
			"kp_speed": 1.6,
			"max_speed": 18.0
		},
		"drag": {
			"base_forward_drag": 4200.0,
			"sideways_drag": 1680000.0
		},
		"rudder": {
			"torque_coefficient": 3000000.0,
			"max_turn_rate": 7.0
		},
		"dive_planes": {
			"torque_coefficient": 1300000.0
		},
		"ballast": {
			"max_ballast_force": 52000000.0
		},
		"buoyancy": {
			"submarine_volume": 9100.0
		}
	},
	"Default": {
		"class_name": "Generic Attack Submarine",
		"mass": 8000.0,
		"max_speed": 10.3,
		"max_depth": 400.0,
		"propulsion": {
			"max_thrust": 50000000.0,
			"kp_speed": 1.5,
			"max_speed": 10.3
		},
		"drag": {
			"base_forward_drag": 5000.0,
			"sideways_drag": 2000000.0
		},
		"rudder": {
			"torque_coefficient": 2000000.0,
			"max_turn_rate": 5.0
		},
		"dive_planes": {
			"torque_coefficient": 1000000.0
		},
		"ballast": {
			"max_ballast_force": 50000000.0
		},
		"buoyancy": {
			"submarine_volume": 8000.0
		}
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
	propulsion_system = PropulsionSystem.new({
		"max_thrust": 50000000.0,
		"kp_speed": 1.5,
		"max_speed": max_speed
	})
	
	# Create rudder system
	rudder_system = RudderSystem.new({
		"torque_coefficient": 2000000.0,
		"max_turn_rate": 5.0
	})
	rudder_system.debug_mode = debug_mode
	rudder_system.log_callback = _log_debug
	
	# Create dive plane system
	dive_plane_system = DivePlaneSystem.new({
		"torque_coefficient": 1000000.0
	})
	
	# Create ballast system
	ballast_system = BallastSystem.new({
		"max_ballast_force": 50000000.0
	})
	
	# Create buoyancy system
	buoyancy_system = BuoyancySystem.new({
		"submarine_volume": 8000.0
	})
	
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
				submarine_body.global_transform = Transform3D(Basis(), submarine_body.global_position)
	
	return _cached_forward_direction

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
	var depth = -position.y  # Depth is negative Y
	var forward_speed = velocity.dot(forward_dir)
	
	# Get control inputs from simulation state
	var target_speed = simulation_state.target_speed if simulation_state else 0.0
	var target_heading = simulation_state.target_heading if simulation_state else 0.0
	var target_depth = simulation_state.target_depth if simulation_state else 0.0
	
	# Calculate current heading
	var current_heading = CoordinateSystem.calculate_heading(forward_dir)
	
	# Step 3: Calculate and apply buoyancy forces - Requirement 12.1
	var buoyancy_result = buoyancy_system.calculate_buoyancy_force(
		position,
		velocity,
		target_depth,
		ocean_renderer
	)
	if physics_validator.validate_vector(buoyancy_result.force, "buoyancy_force"):
		submarine_body.apply_central_force(buoyancy_result.force)
	if physics_validator.validate_vector(buoyancy_result.torque, "buoyancy_torque"):
		submarine_body.apply_torque(buoyancy_result.torque)
	
	# Step 4: Calculate and apply drag forces - Requirement 12.1
	var drag_force = hydrodynamic_drag.calculate_drag_force(
		velocity,
		forward_dir,
		depth,
		appendage_drag_registry
	)
	if physics_validator.validate_vector(drag_force, "drag_force"):
		submarine_body.apply_central_force(drag_force)
	
	# Step 5: Calculate and apply propulsion forces - Requirement 12.1
	var propulsion_force = propulsion_system.calculate_propulsion_force(
		forward_dir,
		velocity,
		target_speed,
		target_heading,
		delta
	)
	if physics_validator.validate_vector(propulsion_force, "propulsion_force"):
		submarine_body.apply_central_force(propulsion_force)
	
	# Step 6: Calculate and apply rudder torques - Requirement 12.1
	var angular_velocity = submarine_body.angular_velocity.y
	var steering_torque = rudder_system.calculate_steering_torque(
		current_heading,
		target_heading,
		forward_speed,
		angular_velocity
	)
	if is_finite(steering_torque):
		submarine_body.apply_torque(Vector3(0, steering_torque, 0))
	
	# Step 7: Calculate and apply dive plane torques - Requirement 12.1
	var current_pitch = submarine_body.rotation.x
	var vertical_velocity = velocity.y
	var dive_plane_torque = dive_plane_system.calculate_dive_plane_torque(
		depth,
		target_depth,
		vertical_velocity,
		abs(forward_speed),
		rad_to_deg(current_pitch)
	)
	if is_finite(dive_plane_torque):
		submarine_body.apply_torque(Vector3(dive_plane_torque, 0, 0))
	
	# Step 8: Calculate and apply ballast forces - Requirement 12.1
	var ballast_force = ballast_system.calculate_ballast_force(
		depth,
		target_depth,
		vertical_velocity,
		delta
	)
	if is_finite(ballast_force):
		submarine_body.apply_central_force(Vector3(0, -ballast_force, 0))  # Negative because ballast is positive down
	
	# Step 9: Apply sideways velocity elimination - Requirement 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
	_apply_sideways_velocity_elimination(forward_dir)
	
	# Step 10: Apply velocity alignment - Requirement 7.1, 7.2, 7.3, 7.4, 7.5, 7.6
	_apply_velocity_alignment(forward_dir)
	
	# Step 11: Clamp velocity - Requirement 10.1
	physics_validator.clamp_velocity(submarine_body, max_speed)
	
	# Step 12: Enforce boundaries - Requirement 11.1
	physics_validator.enforce_boundaries(submarine_body, map_boundary)

## Get current submarine state for synchronization
## Requirement 17.3: Same interface as SubmarinePhysics
func get_submarine_state() -> Dictionary:
	if not submarine_body:
		return {}
	
	var pos = submarine_body.global_position
	var vel = submarine_body.linear_velocity
	
	# Calculate depth (negative Y position)
	var depth = -pos.y
	
	# Calculate horizontal speed (exclude vertical component)
	var horizontal_velocity = Vector2(vel.x, vel.z)
	var speed = horizontal_velocity.length()
	
	# Calculate heading using coordinate system utility
	var forward_dir = _get_forward_direction()
	var heading = CoordinateSystem.calculate_heading(forward_dir)
	
	return {
		"position": pos,
		"velocity": vel,
		"depth": depth,
		"heading": heading,
		"speed": speed
	}

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
	var corrected_velocity = Vector3(corrected_horizontal.x, vertical_velocity, corrected_horizontal.z)
	
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
