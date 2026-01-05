extends GutTest
## Property-based test for depth control stability
## Verifies that the submarine reaches and maintains target depth without excessive oscillation

var test_scene: Node3D
var submarine_body: RigidBody3D
var submarine_physics: SubmarinePhysicsV2
var simulation_state: SimulationState

# Data collection for analysis
var depth_samples: Array[float] = []
var velocity_samples: Array[float] = []
var time_samples: Array[float] = []
var current_time: float = 0.0

const TEST_DURATION: float = 120.0  # 2 minutes
const SAMPLE_INTERVAL: float = 0.1  # Sample every 100ms
var last_sample_time: float = 0.0


func before_each() -> void:
	# Create test scene
	test_scene = Node3D.new()
	add_child_autofree(test_scene)

	# Create submarine body with proper physics
	submarine_body = RigidBody3D.new()
	submarine_body.mass = 8000000.0  # 8000 tons
	submarine_body.global_position = Vector3(0, 0, 0)
	submarine_body.gravity_scale = 1.0
	test_scene.add_child(submarine_body)

	# Create simulation state
	simulation_state = SimulationState.new()
	test_scene.add_child(simulation_state)

	# Create submarine physics (without ocean renderer for simplicity)
	submarine_physics = SubmarinePhysicsV2.new()
	test_scene.add_child(submarine_physics)
	submarine_physics.initialize(submarine_body, null, simulation_state)

	# Reset data collection
	depth_samples.clear()
	velocity_samples.clear()
	time_samples.clear()
	current_time = 0.0
	last_sample_time = 0.0


func test_dive_to_50m_stability() -> void:
	# Set target: dive to 50m
	simulation_state.target_depth = 50.0
	simulation_state.target_speed = 0.0

	print("\n=== Starting Dive to 50m Test ===")
	print("Target Depth: 50.0m")
	print("Duration: %.1fs" % TEST_DURATION)

	# Run simulation
	await _run_simulation(TEST_DURATION)

	# Analyze results
	var analysis = _analyze_depth_control()

	print("\n=== Test Results ===")
	print("Final Depth: %.2fm" % analysis.final_depth)
	print("Max Depth: %.2fm" % analysis.max_depth)
	print("Overshoot: %.2fm" % analysis.overshoot)
	print("Oscillations: %d" % analysis.oscillation_count)
	print("Settling Time: %.2fs" % analysis.settling_time)
	print("Steady State Error: %.2fm" % analysis.steady_state_error)

	# Assertions
	assert_almost_eq(analysis.final_depth, 50.0, 3.0, "Final depth should be within 3m of target")

	assert_lt(analysis.overshoot, 10.0, "Overshoot should be less than 10m")

	assert_lt(
		analysis.oscillation_count,
		8,
		"Should have fewer than 8 oscillations (indicates instability)"
	)

	assert_lt(analysis.settling_time, 60.0, "Should settle within 60 seconds")


func test_surface_to_100m_dive() -> void:
	# Test deeper dive
	simulation_state.target_depth = 100.0
	simulation_state.target_speed = 0.0

	print("\n=== Starting Dive to 100m Test ===")

	await _run_simulation(TEST_DURATION)

	var analysis = _analyze_depth_control()

	print("\n=== Test Results ===")
	print("Final Depth: %.2fm" % analysis.final_depth)
	print("Overshoot: %.2fm" % analysis.overshoot)
	print("Oscillations: %d" % analysis.oscillation_count)

	assert_almost_eq(analysis.final_depth, 100.0, 5.0, "Final depth should be within 5m of target")


func test_depth_change_mid_dive() -> void:
	# Start with shallow target
	simulation_state.target_depth = 30.0
	simulation_state.target_speed = 0.0

	print("\n=== Starting Depth Change Test ===")
	print("Initial Target: 30m, will change to 70m at t=40s")

	var change_time: float = 40.0
	var changed: bool = false

	# Run simulation with depth change
	while current_time < TEST_DURATION:
		# Change depth target mid-simulation
		if current_time >= change_time and not changed:
			simulation_state.target_depth = 70.0
			changed = true
			print("Target depth changed to 70m at t=%.1fs" % current_time)

		submarine_physics.update_physics(get_physics_process_delta_time())

		# Sample data
		if current_time - last_sample_time >= SAMPLE_INTERVAL:
			_sample_data()
			last_sample_time = current_time

		current_time += get_physics_process_delta_time()
		await get_tree().physics_frame

	var final_depth = -submarine_body.global_position.y

	print("\n=== Test Results ===")
	print("Final Depth: %.2fm" % final_depth)
	print("Target: 70.0m")

	assert_almost_eq(final_depth, 70.0, 5.0, "Should reach new target depth after change")


func _run_simulation(duration: float) -> void:
	# Run physics simulation for specified duration
	while current_time < duration:
		submarine_physics.update_physics(get_physics_process_delta_time())

		# Sample data periodically
		if current_time - last_sample_time >= SAMPLE_INTERVAL:
			_sample_data()
			last_sample_time = current_time

		current_time += get_physics_process_delta_time()
		await get_tree().physics_frame


func _sample_data() -> void:
	# Record current state
	var depth = -submarine_body.global_position.y
	var velocity = submarine_body.linear_velocity.y

	depth_samples.append(depth)
	velocity_samples.append(velocity)
	time_samples.append(current_time)


func _analyze_depth_control() -> Dictionary:
	# Analyze collected data for stability metrics
	var target = simulation_state.target_depth
	var final_depth = depth_samples[-1] if depth_samples.size() > 0 else 0.0
	var max_depth = 0.0
	var oscillation_count = 0
	var settling_time = 0.0
	var settled = false

	# Find max depth and count oscillations
	var previous_error = 0.0
	for i in range(depth_samples.size()):
		var depth = depth_samples[i]
		max_depth = max(max_depth, depth)

		var error = target - depth

		# Detect zero crossing (oscillation)
		if i > 0 and sign(error) != sign(previous_error) and abs(error) > 1.0:
			oscillation_count += 1

		# Detect settling (within 2m of target for 5 seconds)
		if not settled and abs(error) < 2.0:
			if i > 0 and time_samples[i] - time_samples[0] > 5.0:
				settling_time = time_samples[i]
				settled = true

		previous_error = error

	var overshoot = max(0.0, max_depth - target)
	var steady_state_error = abs(final_depth - target)

	return {
		"final_depth": final_depth,
		"max_depth": max_depth,
		"overshoot": overshoot,
		"oscillation_count": oscillation_count,
		"settling_time": settling_time,
		"steady_state_error": steady_state_error
	}
