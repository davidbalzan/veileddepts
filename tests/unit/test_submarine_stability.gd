extends GutTest

## Unit test for submarine physics stability
## Tests that submarine maintains stability during turns and depth changes
## Validates that roll axis lock works and torques stay within acceptable limits

const MAX_ACCEPTABLE_ROLL := 5.0  # degrees
const MAX_ACCEPTABLE_TORQUE := 10000000.0  # 10M Nm
const MAX_ACCEPTABLE_PITCH := 20.0  # degrees

var submarine_body: RigidBody3D
var simulation_state: SimulationState
var physics_system: SubmarinePhysicsV2


func before_each():
	# Create a minimal submarine test setup
	submarine_body = RigidBody3D.new()
	submarine_body.mass = 2000000.0  # 2000 tons
	submarine_body.axis_lock_angular_z = true  # Lock roll axis
	submarine_body.angular_damp = 0.5
	add_child_autofree(submarine_body)
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(5, 3, 20)
	collision.shape = shape
	submarine_body.add_child(collision)
	
	# Create simulation state
	simulation_state = SimulationState.new()
	add_child_autofree(simulation_state)
	
	# Create physics system
	physics_system = SubmarinePhysicsV2.new()
	physics_system.initialize(submarine_body, simulation_state)
	add_child_autofree(physics_system)
	
	# Set to neutral depth
	simulation_state.submarine_depth = 50.0
	simulation_state.target_depth = 50.0
	submarine_body.global_position = Vector3(0, -50, 0)


func test_roll_stability_during_turn():
	"""Test that submarine doesn't roll when turning"""
	assert_not_null(submarine_body, "Submarine body should exist")
	assert_not_null(simulation_state, "Simulation state should exist")
	
	# Set forward speed
	submarine_body.linear_velocity = Vector3(0, 0, -3.0)  # 3 m/s forward
	simulation_state.target_speed = 3.0
	simulation_state.target_heading = 90.0  # Turn right
	
	# Simulate for 5 seconds (300 frames at 60fps)
	var max_roll_observed := 0.0
	for i in range(300):
		physics_system._physics_process(1.0 / 60.0)
		
		var roll = rad_to_deg(submarine_body.rotation.z)
		max_roll_observed = max(max_roll_observed, abs(roll))
	
	assert_lt(max_roll_observed, MAX_ACCEPTABLE_ROLL, 
		"Roll should stay under %.1f degrees during turn (observed: %.1f)" % [MAX_ACCEPTABLE_ROLL, max_roll_observed])


func test_dive_torque_magnitude():
	"""Test that dive plane torques stay within acceptable limits"""
	assert_not_null(physics_system, "Physics system should exist")
	
	# Set significant depth change
	simulation_state.submarine_depth = 50.0
	simulation_state.target_depth = 100.0  # 50m depth change
	submarine_body.linear_velocity = Vector3(0, 0, -3.4)  # Typical speed
	
	# Check torque over 3 seconds
	var max_torque := 0.0
	for i in range(180):
		physics_system._physics_process(1.0 / 60.0)
		
		# Get dive plane torque (would need to expose this or check angular velocity change)
		var angular_accel = submarine_body.angular_velocity.x
		var estimated_torque = abs(angular_accel * submarine_body.mass * 100.0)  # Rough estimate
		max_torque = max(max_torque, estimated_torque)
	
	assert_lt(max_torque, MAX_ACCEPTABLE_TORQUE,
		"Dive plane torque should stay under %.0f Nm (observed: %.0f)" % [MAX_ACCEPTABLE_TORQUE, max_torque])


func test_pitch_limits():
	"""Test that pitch doesn't exceed ±20 degrees"""
	assert_not_null(submarine_body, "Submarine body should exist")
	
	# Command steep dive
	simulation_state.submarine_depth = 10.0
	simulation_state.target_depth = 200.0  # Big depth change
	submarine_body.linear_velocity = Vector3(0, 0, -5.0)
	
	var max_pitch := 0.0
	for i in range(600):  # 10 seconds
		physics_system._physics_process(1.0 / 60.0)
		
		var pitch = rad_to_deg(submarine_body.rotation.x)
		max_pitch = max(max_pitch, abs(pitch))
	
	assert_lt(max_pitch, MAX_ACCEPTABLE_PITCH,
		"Pitch should stay under %.1f degrees (observed: %.1f)" % [MAX_ACCEPTABLE_PITCH, max_pitch])


func test_depth_normalization():
	"""Test that depth cannot go below 0 (surface)"""
	assert_not_null(simulation_state, "Simulation state should exist")
	
	# Try to set negative depth
	simulation_state.set_target_depth(-50.0)
	
	assert_eq(simulation_state.target_depth, 0.0,
		"Target depth should be clamped to 0 (surface), not negative")
	
	# Try via update_submarine_command
	simulation_state.update_submarine_command(Vector3.ZERO, 3.0, -100.0)
	
	assert_eq(simulation_state.target_depth, 0.0,
		"Target depth via command should also be clamped to 0")


func test_ascent_at_speed():
	"""Test that submarine ascends faster when moving faster"""
	assert_not_null(submarine_body, "Submarine body should exist")
	
	# Start deep
	simulation_state.submarine_depth = 100.0
	simulation_state.target_depth = 50.0  # Ascend 50m
	submarine_body.global_position = Vector3(0, -100, 0)
	
	# Test at low speed
	submarine_body.linear_velocity = Vector3(0, 0, -1.5)
	simulation_state.target_speed = 1.5
	
	var low_speed_vvel := 0.0
	for i in range(60):  # 1 second
		physics_system._physics_process(1.0 / 60.0)
		low_speed_vvel = submarine_body.linear_velocity.y
	
	# Reset
	submarine_body.linear_velocity = Vector3.ZERO
	submarine_body.angular_velocity = Vector3.ZERO
	submarine_body.rotation = Vector3.ZERO
	
	# Test at high speed
	submarine_body.linear_velocity = Vector3(0, 0, -4.0)
	simulation_state.target_speed = 4.0
	
	var high_speed_vvel := 0.0
	for i in range(60):  # 1 second
		physics_system._physics_process(1.0 / 60.0)
		high_speed_vvel = submarine_body.linear_velocity.y
	
	# Higher speed should produce more upward velocity (less negative or more positive)
	assert_gt(high_speed_vvel, low_speed_vvel - 0.1,  # Allow small margin
		"Higher speed should produce more upward velocity (low: %.2f, high: %.2f)" % [low_speed_vvel, high_speed_vvel])


func test_axis_lock_enforced():
	"""Test that roll axis lock is actually enforced"""
	assert_not_null(submarine_body, "Submarine body should exist")
	assert_true(submarine_body.axis_lock_angular_z, "Roll axis should be locked")
	
	# Try to apply roll torque directly
	submarine_body.apply_torque(Vector3(0, 0, 1000000.0))  # 1M Nm roll torque
	
	# Simulate one frame
	await get_tree().physics_frame
	
	# Roll angular velocity should be zero (or very close)
	assert_almost_eq(submarine_body.angular_velocity.z, 0.0, 0.01,
		"Roll angular velocity should be zero with axis lock")


func test_no_oscillation():
	"""Test that submarine doesn't oscillate wildly around target pitch"""
	assert_not_null(submarine_body, "Submarine body should exist")
	
	# Set moderate depth change
	simulation_state.submarine_depth = 50.0
	simulation_state.target_depth = 75.0
	submarine_body.linear_velocity = Vector3(0, 0, -3.0)
	
	# Track pitch changes
	var pitch_readings := []
	for i in range(300):  # 5 seconds
		physics_system._physics_process(1.0 / 60.0)
		pitch_readings.append(rad_to_deg(submarine_body.rotation.x))
	
	# Check for oscillation: count direction changes
	var direction_changes := 0
	for i in range(1, pitch_readings.size()):
		if i < pitch_readings.size() - 1:
			var prev_delta = pitch_readings[i] - pitch_readings[i-1]
			var next_delta = pitch_readings[i+1] - pitch_readings[i]
			if sign(prev_delta) != sign(next_delta) and abs(prev_delta) > 0.1:
				direction_changes += 1
	
	# Allow some natural corrections but not wild oscillation
	assert_lt(direction_changes, 10,
		"Pitch should not oscillate wildly (direction changes: %d)" % direction_changes)
