class_name PerformanceMonitor extends Node
## Monitors frame time for terrain operations and triggers adaptive performance adjustments
##
## Responsibilities:
## - Track frame time spent on terrain operations
## - Detect when frame time exceeds budget
## - Trigger LOD reduction when performance degrades
## - Trigger chunk unloading as last resort
## - Provide performance metrics for debugging

## Performance configuration
@export var target_fps: float = 60.0
@export var frame_budget_ms: float = 16.67  # 60 FPS = 16.67ms per frame
@export var terrain_budget_ms: float = 5.0  # Max time for terrain operations per frame
@export var performance_window_frames: int = 30  # Number of frames to average
@export var lod_reduction_threshold: float = 0.8  # Reduce LOD when using 80% of budget
@export var emergency_unload_threshold: float = 1.2  # Unload chunks when exceeding budget by 20%

## Internal state
var _frame_times: Array[float] = []
var _terrain_times: Array[float] = []
var _current_frame_start: int = 0
var _terrain_operation_start: int = 0
var _is_measuring_terrain: bool = false
var _performance_state: PerformanceState = PerformanceState.NORMAL
var _consecutive_overbudget_frames: int = 0
var _lod_reduction_cooldown: int = 0
var _unload_cooldown: int = 0

## Performance state enum
enum PerformanceState { NORMAL, LOD_REDUCED, EMERGENCY_UNLOAD }  # Performance is good  # LOD has been reduced to maintain performance  # Chunks are being unloaded to maintain performance

## Signals
signal performance_degraded(state: PerformanceState)
signal performance_recovered
signal lod_reduction_requested
signal emergency_unload_requested


func _ready() -> void:
	# Initialize frame time tracking
	_frame_times.resize(performance_window_frames)
	_terrain_times.resize(performance_window_frames)
	_frame_times.fill(0.0)
	_terrain_times.fill(0.0)


func _process(_delta: float) -> void:
	# Update cooldowns
	if _lod_reduction_cooldown > 0:
		_lod_reduction_cooldown -= 1
	if _unload_cooldown > 0:
		_unload_cooldown -= 1


## Start measuring frame time
func begin_frame() -> void:
	_current_frame_start = Time.get_ticks_usec()


## End measuring frame time and check performance
func end_frame() -> void:
	var frame_time_us: int = Time.get_ticks_usec() - _current_frame_start
	var frame_time_ms: float = frame_time_us / 1000.0

	# Add to rolling window
	_frame_times.pop_front()
	_frame_times.append(frame_time_ms)

	# Check if we're over budget
	if frame_time_ms > frame_budget_ms:
		_consecutive_overbudget_frames += 1
	else:
		_consecutive_overbudget_frames = 0

	# Trigger adaptive performance if needed
	_check_performance()


## Start measuring terrain operation time
func begin_terrain_operation() -> void:
	_terrain_operation_start = Time.get_ticks_usec()
	_is_measuring_terrain = true


## End measuring terrain operation time
func end_terrain_operation() -> void:
	if not _is_measuring_terrain:
		return

	var terrain_time_us: int = Time.get_ticks_usec() - _terrain_operation_start
	var terrain_time_ms: float = terrain_time_us / 1000.0

	# Add to rolling window
	_terrain_times.pop_front()
	_terrain_times.append(terrain_time_ms)

	_is_measuring_terrain = false


## Get average frame time over the performance window
func get_average_frame_time_ms() -> float:
	var sum: float = 0.0
	for time in _frame_times:
		sum += time
	return sum / float(performance_window_frames)


## Get average terrain operation time over the performance window
func get_average_terrain_time_ms() -> float:
	var sum: float = 0.0
	for time in _terrain_times:
		sum += time
	return sum / float(performance_window_frames)


## Get current FPS based on average frame time
func get_current_fps() -> float:
	var avg_frame_time: float = get_average_frame_time_ms()
	if avg_frame_time <= 0.0:
		return 0.0
	return 1000.0 / avg_frame_time


## Get percentage of frame budget used by terrain operations
func get_terrain_budget_usage() -> float:
	var avg_terrain_time: float = get_average_terrain_time_ms()
	return (avg_terrain_time / terrain_budget_ms) * 100.0


## Get current performance state
func get_performance_state() -> PerformanceState:
	return _performance_state


## Check performance and trigger adaptive adjustments
func _check_performance() -> void:
	var avg_terrain_time: float = get_average_terrain_time_ms()
	var terrain_budget_ratio: float = avg_terrain_time / terrain_budget_ms

	# Check if we need to take action
	if terrain_budget_ratio >= emergency_unload_threshold:
		# Emergency: unload chunks
		if _consecutive_overbudget_frames >= 3 and _unload_cooldown == 0:
			_trigger_emergency_unload()
	elif terrain_budget_ratio >= lod_reduction_threshold:
		# Warning: reduce LOD
		if _consecutive_overbudget_frames >= 5 and _lod_reduction_cooldown == 0:
			_trigger_lod_reduction()
	else:
		# Performance is good, recover if needed
		if _performance_state != PerformanceState.NORMAL:
			_recover_performance()


## Trigger LOD reduction to improve performance
func _trigger_lod_reduction() -> void:
	if _performance_state == PerformanceState.NORMAL:
		print("PerformanceMonitor: Performance degraded, reducing LOD levels")
		_performance_state = PerformanceState.LOD_REDUCED
		performance_degraded.emit(PerformanceState.LOD_REDUCED)
		lod_reduction_requested.emit()
		_lod_reduction_cooldown = 60  # Wait 60 frames before next reduction
	elif _performance_state == PerformanceState.LOD_REDUCED:
		# Already reduced LOD, escalate to emergency unload
		_trigger_emergency_unload()


## Trigger emergency chunk unloading
func _trigger_emergency_unload() -> void:
	print("PerformanceMonitor: Emergency performance issue, unloading distant chunks")
	_performance_state = PerformanceState.EMERGENCY_UNLOAD
	performance_degraded.emit(PerformanceState.EMERGENCY_UNLOAD)
	emergency_unload_requested.emit()
	_unload_cooldown = 120  # Wait 120 frames before next unload


## Recover from performance degradation
func _recover_performance() -> void:
	print("PerformanceMonitor: Performance recovered to normal")
	_performance_state = PerformanceState.NORMAL
	performance_recovered.emit()
	_consecutive_overbudget_frames = 0


## Get performance metrics as a dictionary
func get_performance_metrics() -> Dictionary:
	return {
		"average_frame_time_ms": get_average_frame_time_ms(),
		"average_terrain_time_ms": get_average_terrain_time_ms(),
		"current_fps": get_current_fps(),
		"terrain_budget_usage_percent": get_terrain_budget_usage(),
		"performance_state": _performance_state,
		"consecutive_overbudget_frames": _consecutive_overbudget_frames,
		"frame_budget_ms": frame_budget_ms,
		"terrain_budget_ms": terrain_budget_ms
	}


## Reset performance tracking
func reset() -> void:
	_frame_times.fill(0.0)
	_terrain_times.fill(0.0)
	_consecutive_overbudget_frames = 0
	_performance_state = PerformanceState.NORMAL
	_lod_reduction_cooldown = 0
	_unload_cooldown = 0
