extends GutTest
## Unit tests for PerformanceMonitor
##
## Tests frame time tracking, performance state transitions,
## and adaptive performance triggers.

var performance_monitor: PerformanceMonitor


func before_each() -> void:
	performance_monitor = PerformanceMonitor.new()
	add_child_autofree(performance_monitor)

	# Use shorter window for faster tests
	performance_monitor.performance_window_frames = 10
	performance_monitor.frame_budget_ms = 16.67
	performance_monitor.terrain_budget_ms = 5.0


func after_each() -> void:
	if performance_monitor:
		performance_monitor.queue_free()
		performance_monitor = null


func test_initial_state() -> void:
	assert_eq(
		performance_monitor.get_performance_state(),
		PerformanceMonitor.PerformanceState.NORMAL,
		"Should start in NORMAL state"
	)
	assert_eq(
		performance_monitor.get_average_frame_time_ms(),
		0.0,
		"Should start with zero average frame time"
	)
	assert_eq(
		performance_monitor.get_average_terrain_time_ms(),
		0.0,
		"Should start with zero average terrain time"
	)


func test_frame_time_tracking() -> void:
	# Simulate some frames
	for i in range(5):
		performance_monitor.begin_frame()
		OS.delay_msec(2)  # Simulate 2ms of work
		performance_monitor.end_frame()

	var avg_frame_time: float = performance_monitor.get_average_frame_time_ms()
	assert_gt(avg_frame_time, 0.0, "Should track frame time")
	assert_lt(avg_frame_time, 10.0, "Frame time should be reasonable")


func test_terrain_operation_tracking() -> void:
	# Simulate terrain operations
	for i in range(5):
		performance_monitor.begin_terrain_operation()
		OS.delay_msec(1)  # Simulate 1ms of terrain work
		performance_monitor.end_terrain_operation()

	var avg_terrain_time: float = performance_monitor.get_average_terrain_time_ms()
	assert_gt(avg_terrain_time, 0.0, "Should track terrain operation time")


func test_fps_calculation() -> void:
	# Simulate frames with known timing
	for i in range(10):
		performance_monitor.begin_frame()
		OS.delay_msec(10)  # 10ms = 100 FPS
		performance_monitor.end_frame()

	var fps: float = performance_monitor.get_current_fps()
	# Should be around 100 FPS (1000ms / 10ms)
	# Allow some tolerance for timing variations
	assert_gt(fps, 50.0, "FPS should be calculated")
	assert_lt(fps, 150.0, "FPS should be reasonable")


func test_terrain_budget_usage() -> void:
	# Simulate terrain operations using 50% of budget
	performance_monitor.terrain_budget_ms = 10.0

	for i in range(10):
		performance_monitor.begin_terrain_operation()
		OS.delay_msec(5)  # 5ms out of 10ms budget = 50%
		performance_monitor.end_terrain_operation()

	var usage: float = performance_monitor.get_terrain_budget_usage()
	# Should be around 50%, but OS.delay_msec() isn't precise, so be lenient
	assert_gt(usage, 20.0, "Should calculate budget usage")
	assert_lt(usage, 100.0, "Budget usage should be reasonable")


func test_lod_reduction_signal() -> void:
	# This test verifies that the performance monitor can detect degradation
	# and emit the appropriate signal
	watch_signals(performance_monitor)

	# Configure for LOD reduction (NOT emergency)
	performance_monitor.terrain_budget_ms = 10.0  # Higher budget
	performance_monitor.lod_reduction_threshold = 0.8  # 80% of budget
	performance_monitor.emergency_unload_threshold = 1.5  # 150% - much higher
	performance_monitor.performance_window_frames = 3

	# Fill window with terrain operations at 90% of budget (over LOD threshold, under emergency)
	for i in range(3):
		performance_monitor.begin_terrain_operation()
		OS.delay_msec(9)  # 9ms / 10ms budget = 90% (over LOD threshold, under emergency)
		performance_monitor.end_terrain_operation()

	# Simulate consecutive overbudget frames (need 5 for LOD reduction)
	for i in range(6):
		performance_monitor.begin_frame()
		OS.delay_msec(20)  # Exceed frame budget to increment consecutive counter
		performance_monitor.end_frame()

	# Should have emitted LOD reduction signal
	assert_signal_emitted(
		performance_monitor,
		"lod_reduction_requested",
		"Should emit LOD reduction signal when over budget"
	)


func test_emergency_unload_signal() -> void:
	# This test verifies emergency unload triggering
	watch_signals(performance_monitor)

	# Configure for emergency triggering
	performance_monitor.terrain_budget_ms = 2.0
	performance_monitor.emergency_unload_threshold = 1.2  # 120% of budget
	performance_monitor.performance_window_frames = 3

	# Fill window with terrain operations way over budget
	for i in range(3):
		performance_monitor.begin_terrain_operation()
		OS.delay_msec(3)  # 3ms / 2ms budget = 150% (over emergency threshold)
		performance_monitor.end_terrain_operation()

	# Simulate consecutive overbudget frames (need 3 for emergency)
	for i in range(4):
		performance_monitor.begin_frame()
		OS.delay_msec(20)  # Exceed frame budget
		performance_monitor.end_frame()

	# Should have emitted emergency signal
	assert_signal_emitted(
		performance_monitor,
		"emergency_unload_requested",
		"Should emit emergency unload signal when severely over budget"
	)


func test_performance_state_transitions() -> void:
	assert_eq(
		performance_monitor.get_performance_state(),
		PerformanceMonitor.PerformanceState.NORMAL,
		"Should start in NORMAL state"
	)

	# Configure for easy triggering
	performance_monitor.terrain_budget_ms = 2.0
	performance_monitor.lod_reduction_threshold = 0.8
	performance_monitor.performance_window_frames = 3

	# Fill window with high terrain times
	for i in range(3):
		performance_monitor.begin_terrain_operation()
		OS.delay_msec(2)  # At budget limit
		performance_monitor.end_terrain_operation()

	# Trigger state change with consecutive overbudget frames
	for i in range(6):
		performance_monitor.begin_frame()
		OS.delay_msec(20)  # Exceed frame budget
		performance_monitor.end_frame()

	# State should have changed
	var state: int = performance_monitor.get_performance_state()
	assert_true(
		state != PerformanceMonitor.PerformanceState.NORMAL,
		"State should change when performance degrades"
	)


func test_performance_metrics() -> void:
	# Simulate some activity
	for i in range(5):
		performance_monitor.begin_frame()
		performance_monitor.begin_terrain_operation()
		OS.delay_msec(2)
		performance_monitor.end_terrain_operation()
		performance_monitor.end_frame()

	var metrics: Dictionary = performance_monitor.get_performance_metrics()

	assert_has(metrics, "average_frame_time_ms", "Should include average frame time")
	assert_has(metrics, "average_terrain_time_ms", "Should include average terrain time")
	assert_has(metrics, "current_fps", "Should include current FPS")
	assert_has(metrics, "terrain_budget_usage_percent", "Should include budget usage")
	assert_has(metrics, "performance_state", "Should include performance state")


func test_reset() -> void:
	# Add some data
	for i in range(5):
		performance_monitor.begin_frame()
		OS.delay_msec(2)
		performance_monitor.end_frame()

	assert_gt(performance_monitor.get_average_frame_time_ms(), 0.0, "Should have frame time data")

	# Reset
	performance_monitor.reset()

	assert_eq(performance_monitor.get_average_frame_time_ms(), 0.0, "Should reset frame time data")
	assert_eq(
		performance_monitor.get_performance_state(),
		PerformanceMonitor.PerformanceState.NORMAL,
		"Should reset to NORMAL state"
	)


func test_cooldown_prevents_rapid_triggers() -> void:
	watch_signals(performance_monitor)

	# Configure for LOD reduction (not emergency)
	performance_monitor.terrain_budget_ms = 10.0
	performance_monitor.lod_reduction_threshold = 0.8
	performance_monitor.emergency_unload_threshold = 1.5
	performance_monitor.performance_window_frames = 3

	# Fill window with high terrain times (over LOD threshold, under emergency)
	for i in range(3):
		performance_monitor.begin_terrain_operation()
		OS.delay_msec(9)  # 90% of budget
		performance_monitor.end_terrain_operation()

	# Trigger LOD reduction multiple times - should only fire once due to cooldown
	for i in range(20):
		performance_monitor.begin_frame()
		OS.delay_msec(20)  # Exceed frame budget
		performance_monitor.end_frame()

	var signal_count: int = get_signal_emit_count(performance_monitor, "lod_reduction_requested")

	# Should only trigger once due to cooldown
	assert_eq(signal_count, 1, "Should only trigger once due to cooldown")
