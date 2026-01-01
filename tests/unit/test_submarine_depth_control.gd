extends GutTest
## Unit tests for submarine depth control and buoyancy physics
## Tests the PID controller behavior and stability over time

var submarine_physics: SubmarinePhysics
var submarine_body: RigidBody3D
var simulation_state: SimulationState
var mock_ocean_renderer: Node

# Test constants
const TEST_DURATION: float = 60.0  # Test for 60 seconds
const PHYSICS_DELTA: float = 1.0 / 60.0  # 60 Hz physics
const TARGET_DEPTH: float = 50.0  # Target depth in meters
const ACCEPTABLE_OVERSHOOT: float = 5.0  # Allow 5m overshoot
const SETTLING_TIME: float = 30.0  # Should settle within 30 seconds
const STEADY_STATE_ERROR: float = 2.0  # Allow 2m steady-state error

class MockOceanRenderer extends Node:
	var initialized: bool = true
	
	func get_wave_height(_pos: Vector2) -> float:
		return 0.0  # Flat ocean for testing

func before_each() -> void:
	# Create submarine body
	submarine_body = RigidBody3D.new()
	submarine_body.mass = 8000000.0  # 8000 tons in kg
	submarine_body.global_position = Vector3(0, 0, 0)  # Start at surface
	add_child_autofree(submarine_body)
	
	# Create simulation state
	simulation_state = SimulationState.new()
	add_child_autofree(simulation_state)
	
	# Create mock ocean renderer
	mock_ocean_renderer = MockOceanRenderer.new()
	add_child_autofree(mock_ocean_renderer)
	
	# Create submarine physics
	submarine_physics = SubmarinePhysics.new()
	add_child_autofree(submarine_physics)
	submarine_physics.initialize(submarine_body, mock_ocean_renderer, simulation_state)

func test_depth_control_reaches_target() -> void:
	# Set target depth
	simulation_state.target_depth = TARGET_DEPTH
	simulation_state.target_speed = 0.0  # Stationary
	
	var time_elapsed: float = 0.0
	var depth_history: Array[float] = []
	var max_depth_reached: float = 0.0
	
	# Simulate physics for TEST_DURATION
	while time_elapsed < TEST_DURATION:
		submarine_physics.update_physics(PHYSICS_DELTA)
		
		# Note: Forces are applied but won't move the body without actual physics process
		# We simulate position changes based on applied forces
		
		var current_depth = -submarine_body.global_position.y
		depth_history.append(current_depth)
		max_depth_reached = max(max_depth_reached, current_depth)
		
		# Update simulation state
		var state = submarine_physics.get_submarine_state()
		simulation_state.update_submarine_state(
			state.position,
			state.velocity,
			state.depth,
			state.heading,
			state.speed
		)
		
		time_elapsed += PHYSICS_DELTA
	
	# Get final depth
	var final_depth = -submarine_body.global_position.y
	
	# Assertions
	assert_almost_eq(final_depth, TARGET_DEPTH, STEADY_STATE_ERROR,
		"Final depth should be within %fm of target. Got: %.2fm, Expected: %.2fm" % [STEADY_STATE_ERROR, final_depth, TARGET_DEPTH])
	
	assert_lt(max_depth_reached, TARGET_DEPTH + ACCEPTABLE_OVERSHOOT,
		"Maximum depth should not overshoot target by more than %fm. Max: %.2fm, Target: %.2fm" % [ACCEPTABLE_OVERSHOOT, max_depth_reached, TARGET_DEPTH])
	
	# Print depth history for analysis
	print("\n=== Depth Control Test Results ===")
	print("Target Depth: %.2fm" % TARGET_DEPTH)
	print("Final Depth: %.2fm" % final_depth)
	print("Max Depth Reached: %.2fm" % max_depth_reached)
	print("Overshoot: %.2fm" % (max_depth_reached - TARGET_DEPTH))
	print("Steady-State Error: %.2fm" % abs(final_depth - TARGET_DEPTH))

func test_depth_control_no_oscillation() -> void:
	# Set target depth
	simulation_state.target_depth = TARGET_DEPTH
	simulation_state.target_speed = 0.0
	
	var time_elapsed: float = 0.0
	var depth_history: Array[float] = []
	var velocity_history: Array[float] = []
	
	# Simulate physics
	while time_elapsed < TEST_DURATION:
		submarine_physics.update_physics(PHYSICS_DELTA)
		
		var current_depth = -submarine_body.global_position.y
		var vertical_velocity = submarine_body.linear_velocity.y
		
		depth_history.append(current_depth)
		velocity_history.append(vertical_velocity)
		
		# Update simulation state
		var state = submarine_physics.get_submarine_state()
		simulation_state.update_submarine_state(
			state.position,
			state.velocity,
			state.depth,
			state.heading,
			state.speed
		)
		
		time_elapsed += PHYSICS_DELTA
	
	# Check for oscillations after settling time
	var settling_index = int(SETTLING_TIME / PHYSICS_DELTA)
	var oscillation_count = 0
	var previous_error = 0.0
	
	for i in range(settling_index, depth_history.size()):
		var current_error = TARGET_DEPTH - depth_history[i]
		
		# Detect zero crossing (sign change in error)
		if i > settling_index and sign(current_error) != sign(previous_error) and abs(current_error) > 1.0:
			oscillation_count += 1
		
		previous_error = current_error
	
	# Should have minimal oscillations (allow 2-3 crossings for settling)
	assert_lt(oscillation_count, 5,
		"Should have minimal oscillations after settling. Found %d zero crossings" % oscillation_count)
	
	print("\n=== Oscillation Test Results ===")
	print("Oscillations detected: %d" % oscillation_count)
	print("Test duration: %.1fs" % TEST_DURATION)
	print("Settling time: %.1fs" % SETTLING_TIME)

func test_buoyancy_at_surface() -> void:
	# Submarine at surface should experience balanced forces
	submarine_body.global_position = Vector3(0, 0, 0)
	simulation_state.target_depth = 0.0
	simulation_state.target_speed = 0.0
	
	var time_elapsed: float = 0.0
	var max_vertical_displacement: float = 0.0
	
	# Simulate for 10 seconds
	while time_elapsed < 10.0:
		submarine_physics.update_physics(PHYSICS_DELTA)
		
		var current_y = submarine_body.global_position.y
		max_vertical_displacement = max(max_vertical_displacement, abs(current_y))
		
		time_elapsed += PHYSICS_DELTA
	
	# Should stay near surface (within 5m)
	assert_lt(max_vertical_displacement, 5.0,
		"Submarine should stay near surface. Max displacement: %.2fm" % max_vertical_displacement)
	
	print("\n=== Surface Buoyancy Test Results ===")
	print("Max vertical displacement: %.2fm" % max_vertical_displacement)

func test_pid_controller_gains() -> void:
	# Test that PID gains are reasonable
	simulation_state.target_depth = TARGET_DEPTH
	simulation_state.target_speed = 0.0
	
	var time_elapsed: float = 0.0
	var rise_time: float = 0.0
	var reached_90_percent: bool = false
	
	# Measure rise time (time to reach 90% of target)
	while time_elapsed < TEST_DURATION:
		submarine_physics.update_physics(PHYSICS_DELTA)
		
		var current_depth = -submarine_body.global_position.y
		
		if not reached_90_percent and current_depth >= TARGET_DEPTH * 0.9:
			rise_time = time_elapsed
			reached_90_percent = true
		
		# Update simulation state
		var state = submarine_physics.get_submarine_state()
		simulation_state.update_submarine_state(
			state.position,
			state.velocity,
			state.depth,
			state.heading,
			state.speed
		)
		
		time_elapsed += PHYSICS_DELTA
	
	# Rise time should be reasonable (not too fast, not too slow)
	assert_gt(rise_time, 5.0, "Rise time should be > 5s for realistic behavior. Got: %.2fs" % rise_time)
	assert_lt(rise_time, 25.0, "Rise time should be < 25s for responsive control. Got: %.2fs" % rise_time)
	
	print("\n=== PID Gains Test Results ===")
	print("Rise time (to 90%%): %.2fs" % rise_time)
	print("Target depth: %.2fm" % TARGET_DEPTH)

func test_depth_control_with_speed() -> void:
	# Test depth control while moving forward
	simulation_state.target_depth = TARGET_DEPTH
	simulation_state.target_speed = 5.0  # 5 m/s forward
	simulation_state.submarine_heading = 0.0  # North
	
	var time_elapsed: float = 0.0
	var final_depth: float = 0.0
	
	# Simulate for 60 seconds
	while time_elapsed < TEST_DURATION:
		submarine_physics.update_physics(PHYSICS_DELTA)
		
		final_depth = -submarine_body.global_position.y
		
		# Update simulation state
		var state = submarine_physics.get_submarine_state()
		simulation_state.update_submarine_state(
			state.position,
			state.velocity,
			state.depth,
			state.heading,
			state.speed
		)
		
		time_elapsed += PHYSICS_DELTA
	
	# Should still reach target depth while moving
	assert_almost_eq(final_depth, TARGET_DEPTH, STEADY_STATE_ERROR * 2,
		"Should reach target depth while moving. Got: %.2fm, Expected: %.2fm" % [final_depth, TARGET_DEPTH])
	
	print("\n=== Depth Control with Speed Test Results ===")
	print("Final depth: %.2fm" % final_depth)
	print("Target depth: %.2fm" % TARGET_DEPTH)
	print("Forward speed: 5.0 m/s")

func test_depth_change_response() -> void:
	# Test changing depth target mid-simulation
	simulation_state.target_depth = 25.0
	simulation_state.target_speed = 0.0
	
	var time_elapsed: float = 0.0
	var depth_history: Array[float] = []
	
	# Simulate for 60 seconds, changing target at 30s
	while time_elapsed < TEST_DURATION:
		# Change target depth halfway through
		if time_elapsed >= 30.0 and simulation_state.target_depth == 25.0:
			simulation_state.target_depth = 75.0
			print("\n=== Target depth changed to 75m at t=30s ===")
		
		submarine_physics.update_physics(PHYSICS_DELTA)
		
		var current_depth = -submarine_body.global_position.y
		depth_history.append(current_depth)
		
		# Update simulation state
		var state = submarine_physics.get_submarine_state()
		simulation_state.update_submarine_state(
			state.position,
			state.velocity,
			state.depth,
			state.heading,
			state.speed
		)
		
		time_elapsed += PHYSICS_DELTA
	
	var final_depth = -submarine_body.global_position.y
	
	# Should reach new target depth
	assert_almost_eq(final_depth, 75.0, STEADY_STATE_ERROR * 2,
		"Should reach new target depth. Got: %.2fm, Expected: 75.0m" % final_depth)
	
	print("\n=== Depth Change Response Test Results ===")
	print("Final depth: %.2fm" % final_depth)
	print("Expected: 75.0m")
