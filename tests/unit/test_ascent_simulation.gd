extends GutTest
## Unit tests for submarine ascent from depth to surface
## Simulates the ballast system physics to diagnose ascent issues

# Test constants
const PHYSICS_DELTA: float = 1.0 / 60.0  # 60 Hz physics
const SUBMARINE_MASS: float = 8000000.0  # 8000 tons in kg
const GRAVITY: float = 9.81

# Systems under test
var ballast_system: BallastSystem
var buoyancy_system: BuoyancySystem


func before_each() -> void:
	ballast_system = BallastSystem.new()
	buoyancy_system = BuoyancySystem.new()


func test_ascent_from_200m_to_surface() -> void:
	# Initial conditions
	var current_depth: float = 200.0  # Start at 200m depth
	var target_depth: float = 0.0     # Want to surface
	var vertical_velocity: float = 0.0  # Start stationary
	var position_y: float = -200.0    # Y position (negative = underwater)

	var time_elapsed: float = 0.0
	var max_time: float = 120.0  # 2 minutes max

	# Tracking
	var depth_history: Array[float] = []
	var velocity_history: Array[float] = []
	var force_history: Array[float] = []
	var time_to_50m: float = -1.0
	var time_to_10m: float = -1.0
	var time_to_surface: float = -1.0

	print("\n" + "=".repeat(60))
	print("ASCENT SIMULATION: 200m -> 0m (surface)")
	print("=".repeat(60))
	print("Ballast config: max_force=%.0f N, kp=%.2f, ki=%.3f, kd=%.2f" % [
		ballast_system.max_ballast_force,
		ballast_system.kp,
		ballast_system.ki,
		ballast_system.kd
	])
	print("                 max_depth_rate=%.1f m/s, depth_rate_gain=%.2f" % [
		ballast_system.max_depth_rate,
		ballast_system.depth_rate_gain
	])
	print("-".repeat(60))

	# Simulation loop
	while time_elapsed < max_time and current_depth > 0.5:
		# Calculate ballast force (positive = downward in ballast system convention)
		var ballast_force = ballast_system.calculate_ballast_force(
			current_depth, target_depth, -vertical_velocity, PHYSICS_DELTA
		)

		# In submarine_physics_v2, ballast force is applied as: Vector3(0, -ballast_force, 0)
		# So negative ballast_force = upward force
		var net_vertical_force = -ballast_force

		# Add buoyancy approximation (neutrally buoyant when deep)
		# At depth > 10m, buoyancy ≈ weight, so net buoyancy ≈ 0
		# Deep stabilization from buoyancy_system: -velocity * 5000
		var deep_stabilization = -vertical_velocity * buoyancy_system.deep_stabilization_coefficient
		net_vertical_force += deep_stabilization

		# Calculate acceleration (F = ma)
		var acceleration = net_vertical_force / SUBMARINE_MASS

		# Update velocity (Euler integration)
		vertical_velocity += acceleration * PHYSICS_DELTA

		# Clamp velocity to reasonable bounds
		vertical_velocity = clamp(vertical_velocity, -20.0, 20.0)

		# Update position
		position_y += vertical_velocity * PHYSICS_DELTA

		# Update depth (depth = -position_y when sea level at y=0)
		current_depth = -position_y

		# Track history (every 0.5 seconds)
		if int(time_elapsed * 2) != int((time_elapsed - PHYSICS_DELTA) * 2):
			depth_history.append(current_depth)
			velocity_history.append(vertical_velocity)
			force_history.append(ballast_force)

		# Track milestones
		if time_to_50m < 0 and current_depth <= 50.0:
			time_to_50m = time_elapsed
			print("t=%.1fs: Reached 50m depth, velocity=%.2f m/s" % [time_elapsed, vertical_velocity])
		if time_to_10m < 0 and current_depth <= 10.0:
			time_to_10m = time_elapsed
			print("t=%.1fs: Reached 10m depth, velocity=%.2f m/s" % [time_elapsed, vertical_velocity])
		if time_to_surface < 0 and current_depth <= 1.0:
			time_to_surface = time_elapsed
			print("t=%.1fs: Reached surface! velocity=%.2f m/s" % [time_elapsed, vertical_velocity])

		time_elapsed += PHYSICS_DELTA

	# Print summary
	print("-".repeat(60))
	print("SIMULATION RESULTS:")
	print("  Final depth: %.2f m" % current_depth)
	print("  Final velocity: %.2f m/s" % vertical_velocity)
	print("  Time elapsed: %.1f s" % time_elapsed)
	print("  Time to 50m: %s" % ("%.1fs" % time_to_50m if time_to_50m >= 0 else "NOT REACHED"))
	print("  Time to 10m: %s" % ("%.1fs" % time_to_10m if time_to_10m >= 0 else "NOT REACHED"))
	print("  Time to surface: %s" % ("%.1fs" % time_to_surface if time_to_surface >= 0 else "NOT REACHED"))

	# Print depth history sample
	print("\nDepth history (every 0.5s):")
	for i in range(min(20, depth_history.size())):
		print("  t=%.1fs: depth=%.1fm, vel=%.2fm/s, ballast=%.0fN" % [
			i * 0.5, depth_history[i], velocity_history[i], force_history[i]
		])
	if depth_history.size() > 20:
		print("  ... (%d more samples)" % (depth_history.size() - 20))

	print("=".repeat(60))

	# Assertions
	assert_lt(current_depth, 10.0, "Should reach near surface (< 10m) within 2 minutes. Got: %.1fm" % current_depth)
	assert_lt(time_to_50m, 60.0, "Should reach 50m within 60 seconds")


func test_ballast_force_at_depth() -> void:
	# Test what force the ballast system generates at various depths
	print("\n" + "=".repeat(60))
	print("BALLAST FORCE TEST AT VARIOUS DEPTHS")
	print("=".repeat(60))
	print("Target depth: 0m (surface)")
	print("-".repeat(60))

	var target_depth = 0.0
	var vertical_velocity = 0.0  # Stationary

	var test_depths = [200.0, 150.0, 137.0, 100.0, 50.0, 20.0, 10.0, 5.0, 1.0]

	for depth in test_depths:
		# Reset PID state for clean test
		ballast_system.reset_pid_state()

		var force = ballast_system.calculate_ballast_force(
			depth, target_depth, vertical_velocity, PHYSICS_DELTA
		)

		# Calculate expected acceleration
		var acceleration = -force / SUBMARINE_MASS  # Negative because upward

		print("Depth: %6.1fm -> Ballast force: %12.0f N, Accel: %6.3f m/s²" % [
			depth, force, acceleration
		])

	print("=".repeat(60))

	# Test at 137m specifically (user's stuck depth)
	ballast_system.reset_pid_state()
	var force_at_137 = ballast_system.calculate_ballast_force(137.0, 0.0, 0.0, PHYSICS_DELTA)

	# Force should be significantly negative (upward) when trying to surface from 137m
	assert_lt(force_at_137, -1000000.0, "Ballast force at 137m should be strongly negative (upward). Got: %.0f" % force_at_137)


func test_ballast_pid_accumulation() -> void:
	# Test if PID integral term is accumulating correctly
	print("\n" + "=".repeat(60))
	print("BALLAST PID ACCUMULATION TEST")
	print("=".repeat(60))

	var current_depth = 137.0
	var target_depth = 0.0
	var vertical_velocity = 0.0

	print("Simulating stationary sub at 137m, target 0m:")
	print("-".repeat(60))

	for i in range(10):
		var force = ballast_system.calculate_ballast_force(
			current_depth, target_depth, vertical_velocity, PHYSICS_DELTA
		)

		print("Step %2d: force=%12.0f N, integral=%.2f, last_error=%.2f" % [
			i, force, ballast_system.depth_error_integral, ballast_system.last_depth_error
		])

	print("=".repeat(60))

	# After 10 steps, integral should be building up
	assert_lt(ballast_system.depth_error_integral, -1.0, "Integral term should be negative (accumulating ascend error)")


func test_ascent_with_forward_speed() -> void:
	# Test ascent while moving forward (dive planes should help)
	print("\n" + "=".repeat(60))
	print("ASCENT WITH FORWARD SPEED (5 m/s)")
	print("=".repeat(60))

	var dive_plane_system = DivePlaneSystem.new()

	var current_depth: float = 200.0
	var target_depth: float = 0.0
	var vertical_velocity: float = 0.0
	var forward_speed: float = 5.0  # Moving forward
	var current_pitch: float = 0.0
	var position_y: float = -200.0

	var time_elapsed: float = 0.0
	var max_time: float = 120.0

	print("With dive planes active at %.1f m/s forward speed" % forward_speed)
	print("-".repeat(60))

	while time_elapsed < max_time and current_depth > 0.5:
		# Ballast force
		var ballast_force = ballast_system.calculate_ballast_force(
			current_depth, target_depth, -vertical_velocity, PHYSICS_DELTA
		)

		# Dive plane torque (would cause pitch change, simplified here)
		var dive_torque = dive_plane_system.calculate_dive_plane_torque(
			current_depth, target_depth, -vertical_velocity, forward_speed, current_pitch
		)

		# Simplified: dive planes add vertical force proportional to torque and speed
		var dive_plane_lift = dive_torque * forward_speed * 0.001  # Simplified conversion

		var net_vertical_force = -ballast_force + dive_plane_lift
		net_vertical_force += -vertical_velocity * 5000.0  # Deep stabilization

		var acceleration = net_vertical_force / SUBMARINE_MASS
		vertical_velocity += acceleration * PHYSICS_DELTA
		vertical_velocity = clamp(vertical_velocity, -20.0, 20.0)

		position_y += vertical_velocity * PHYSICS_DELTA
		current_depth = -position_y

		# Print progress every 10 seconds
		if int(time_elapsed) % 10 == 0 and int(time_elapsed) != int(time_elapsed - PHYSICS_DELTA):
			print("t=%3.0fs: depth=%6.1fm, vel=%5.2fm/s, dive_torque=%10.0f" % [
				time_elapsed, current_depth, vertical_velocity, dive_torque
			])

		time_elapsed += PHYSICS_DELTA

	print("-".repeat(60))
	print("Final depth: %.1fm after %.1fs" % [current_depth, time_elapsed])
	print("=".repeat(60))

	assert_lt(current_depth, 10.0, "Should reach near surface with forward speed")
