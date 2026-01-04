extends GutTest

## Test performance optimizations for sea level changes
## Tests throttling, incremental updates, and progress reporting

var sea_level_manager: Node = null


func before_each():
	# Get the SeaLevelManager singleton
	sea_level_manager = get_node("/root/SeaLevelManager")
	assert_not_null(sea_level_manager, "SeaLevelManager should be available")
	
	# Reset to default
	sea_level_manager.reset_to_default()
	await wait_frames(2)


func test_throttling_prevents_rapid_updates():
	"""Test that rapid slider changes are throttled"""
	var signal_count = [0]  # Use array to avoid lambda capture warning
	var signal_callback = func(_n, _m): signal_count[0] += 1
	
	sea_level_manager.sea_level_changed.connect(signal_callback)
	
	# Rapidly change sea level 10 times
	for i in range(10):
		sea_level_manager.set_sea_level(0.5 + i * 0.01)
	
	# Should only emit once or twice due to throttling
	await wait_frames(2)
	
	assert_lt(signal_count[0], 5, "Throttling should limit signal emissions")
	
	sea_level_manager.sea_level_changed.disconnect(signal_callback)


func test_progress_signal_emitted():
	"""Test that progress signals are emitted during updates"""
	var progress_updates = []
	var progress_callback = func(progress, operation):
		progress_updates.append({"progress": progress, "operation": operation})
	
	sea_level_manager.update_progress.connect(progress_callback)
	
	# Change sea level
	sea_level_manager.set_sea_level(0.7, true)  # Force immediate
	
	# Wait for update to complete
	await wait_frames(5)
	
	# Should have received progress updates
	assert_gt(progress_updates.size(), 0, "Should emit progress updates")
	
	# First update should be 0.0 (start)
	if progress_updates.size() > 0:
		assert_almost_eq(progress_updates[0].progress, 0.0, 0.1, "First progress should be near 0.0")
	
	# Last update should be 1.0 (complete)
	if progress_updates.size() > 0:
		assert_almost_eq(progress_updates[-1].progress, 1.0, 0.1, "Last progress should be near 1.0")
	
	sea_level_manager.update_progress.disconnect(progress_callback)


func test_performance_stats_available():
	"""Test that performance statistics are available"""
	var stats = sea_level_manager.get_performance_stats()
	
	assert_not_null(stats, "Performance stats should be available")
	assert_has(stats, "update_in_progress", "Stats should include update_in_progress")
	assert_has(stats, "last_update_duration_ms", "Stats should include last_update_duration_ms")
	assert_has(stats, "current_memory_mb", "Stats should include current_memory_mb")
	assert_has(stats, "peak_memory_mb", "Stats should include peak_memory_mb")
	assert_has(stats, "pending_update", "Stats should include pending_update")
	assert_has(stats, "throttle_active", "Stats should include throttle_active")


func test_memory_monitoring():
	"""Test that memory usage is monitored"""
	# Get initial stats
	var stats_before = sea_level_manager.get_performance_stats()
	var memory_before = stats_before.current_memory_mb
	
	assert_gt(memory_before, 0.0, "Memory usage should be positive")
	
	# Change sea level
	sea_level_manager.set_sea_level(0.8, true)
	await wait_frames(2)
	
	# Get stats after update
	var stats_after = sea_level_manager.get_performance_stats()
	
	# Peak memory should be tracked
	assert_true(stats_after.peak_memory_mb >= memory_before, "Peak memory should be at least initial memory")


func test_update_duration_tracked():
	"""Test that update duration is tracked"""
	# Change sea level
	sea_level_manager.set_sea_level(0.6, true)
	await wait_frames(2)
	
	var stats = sea_level_manager.get_performance_stats()
	
	# Should have recorded update duration (may be 0.0 if very fast, which is fine)
	assert_true(stats.last_update_duration_ms >= 0.0, "Update duration should be non-negative")
	assert_lt(stats.last_update_duration_ms, 1000.0, "Update should complete in reasonable time")


func test_is_update_in_progress():
	"""Test that update progress can be queried"""
	# Should not be in progress initially
	assert_false(sea_level_manager.is_update_in_progress(), "Should not be updating initially")
	
	# Start an update
	sea_level_manager.set_sea_level(0.75, true)
	
	# May or may not catch it in progress (update is fast)
	# Just verify the method works
	var in_progress = sea_level_manager.is_update_in_progress()
	assert_typeof(in_progress, TYPE_BOOL, "is_update_in_progress should return bool")


func test_force_immediate_bypasses_throttle():
	"""Test that force_immediate parameter bypasses throttling"""
	var signal_count = [0]  # Use array to avoid lambda capture warning
	var signal_callback = func(_n, _m): signal_count[0] += 1
	
	sea_level_manager.sea_level_changed.connect(signal_callback)
	
	# Rapidly change with force_immediate
	for i in range(5):
		sea_level_manager.set_sea_level(0.5 + i * 0.02, true)
		await wait_frames(1)
	
	# Should emit for each change (allow for 1 extra due to timing)
	assert_true(signal_count[0] >= 5, "force_immediate should bypass throttling (got %d signals)" % signal_count[0])
	assert_true(signal_count[0] <= 6, "Should not emit significantly more than expected (got %d signals)" % signal_count[0])
	
	sea_level_manager.sea_level_changed.disconnect(signal_callback)
