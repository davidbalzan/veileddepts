extends Node

## SeaLevelManager
##
## Central authority for sea level state and change propagation.
## Manages the current sea level in both normalized (0.0-1.0) and metric (meters) formats.
## Emits signals when sea level changes to notify all dependent systems.
##
## Performance Features:
## - Update throttling (100ms minimum between updates)
## - Memory usage monitoring
## - Progress tracking for long operations

# Signal emitted when sea level changes
# @param normalized_value: Sea level in normalized range (0.0-1.0)
# @param meters_value: Sea level in meters relative to real-world datum
signal sea_level_changed(normalized_value: float, meters_value: float)

# Signal emitted to report update progress (0.0 to 1.0)
# @param progress: Progress value from 0.0 (started) to 1.0 (complete)
# @param operation: Description of the operation in progress
signal update_progress(progress: float, operation: String)

# Constants for elevation scaling
const MARIANA_TRENCH_DEPTH: float = -10994.0  # Lowest point on Earth (meters)
const MOUNT_EVEREST_HEIGHT: float = 8849.0    # Highest point on Earth (meters)
const DEFAULT_SEA_LEVEL: float = 0.554        # Normalized value for 0m elevation

# Performance constants
const UPDATE_THROTTLE_MS: float = 100.0  # Minimum time between updates (milliseconds)

# Current sea level state
var current_sea_level_normalized: float = DEFAULT_SEA_LEVEL
var current_sea_level_meters: float = 0.0

# Throttling state
var _pending_sea_level: float = -1.0  # -1 means no pending update
var _last_update_time: int = 0  # Time in milliseconds
var _throttle_timer: Timer = null

# Performance monitoring
var _update_in_progress: bool = false
var _last_update_duration_ms: float = 0.0
var _peak_memory_usage_mb: float = 0.0


func _ready() -> void:
	# Initialize with default sea level
	current_sea_level_meters = normalized_to_meters(DEFAULT_SEA_LEVEL)
	
	# Create throttle timer
	_throttle_timer = Timer.new()
	_throttle_timer.name = "ThrottleTimer"
	_throttle_timer.one_shot = true
	_throttle_timer.timeout.connect(_on_throttle_timer_timeout)
	add_child(_throttle_timer)
	
	print("SeaLevelManager: Initialized with throttling (%.0fms minimum between updates)" % UPDATE_THROTTLE_MS)


## Set the sea level to a new normalized value
## @param normalized: Sea level in normalized range (0.0-1.0)
## @param force_immediate: If true, bypass throttling and update immediately
func set_sea_level(normalized: float, force_immediate: bool = false) -> void:
	# Validate and clamp input
	if normalized < 0.0 or normalized > 1.0:
		push_warning("SeaLevelManager: Attempted to set sea level outside valid range [0.0, 1.0]: %.3f. Clamping." % normalized)
		normalized = clamp(normalized, 0.0, 1.0)
	
	# Only update if value actually changed (avoid unnecessary signal emissions)
	if abs(normalized - current_sea_level_normalized) < 0.0001:
		return
	
	# Check if we should throttle this update
	var current_time = Time.get_ticks_msec()
	var time_since_last_update = current_time - _last_update_time
	
	if not force_immediate and time_since_last_update < UPDATE_THROTTLE_MS:
		# Queue this update for later
		_pending_sea_level = normalized
		
		# Start or restart the throttle timer
		if not _throttle_timer.is_stopped():
			_throttle_timer.stop()
		
		var wait_time = (UPDATE_THROTTLE_MS - time_since_last_update) / 1000.0
		_throttle_timer.start(wait_time)
		
		return
	
	# Perform the update immediately
	_apply_sea_level_update(normalized)


## Get the current sea level in normalized format (0.0-1.0)
## @return: Current sea level normalized value
func get_sea_level_normalized() -> float:
	return current_sea_level_normalized


## Get the current sea level in meters
## @return: Current sea level in meters
func get_sea_level_meters() -> float:
	return current_sea_level_meters


## Reset sea level to default (0m elevation)
func reset_to_default() -> void:
	set_sea_level(DEFAULT_SEA_LEVEL)


## Convert normalized elevation (0.0-1.0) to meters
## @param normalized: Elevation in normalized range (0.0-1.0)
## @return: Elevation in meters
func normalized_to_meters(normalized: float) -> float:
	return lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, normalized)


## Convert elevation in meters to normalized (0.0-1.0)
## @param meters: Elevation in meters
## @return: Elevation in normalized range (0.0-1.0)
func meters_to_normalized(meters: float) -> float:
	return inverse_lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, meters)


## Internal method to apply sea level update
## @param normalized: Sea level in normalized range (0.0-1.0)
func _apply_sea_level_update(normalized: float) -> void:
	var start_time = Time.get_ticks_msec()
	
	# Mark update as in progress
	_update_in_progress = true
	update_progress.emit(0.0, "Starting sea level update")
	
	# Update state
	current_sea_level_normalized = normalized
	current_sea_level_meters = normalized_to_meters(normalized)
	
	# Monitor memory before update
	var memory_before = _get_memory_usage_mb()
	
	# Emit signal to notify all systems
	update_progress.emit(0.5, "Notifying systems")
	sea_level_changed.emit(current_sea_level_normalized, current_sea_level_meters)
	
	# Monitor memory after update
	var memory_after = _get_memory_usage_mb()
	var memory_delta = memory_after - memory_before
	if memory_after > _peak_memory_usage_mb:
		_peak_memory_usage_mb = memory_after
	
	# Record timing
	_last_update_time = Time.get_ticks_msec()
	_last_update_duration_ms = _last_update_time - start_time
	
	# Mark update as complete
	_update_in_progress = false
	update_progress.emit(1.0, "Update complete")
	
	# Log performance metrics
	print("SeaLevelManager: Update completed in %.1fms (memory: %.1fMB, delta: %+.1fMB)" % [
		_last_update_duration_ms,
		memory_after,
		memory_delta
	])


## Throttle timer callback
func _on_throttle_timer_timeout() -> void:
	if _pending_sea_level >= 0.0:
		var pending_value = _pending_sea_level
		_pending_sea_level = -1.0  # Clear pending update
		_apply_sea_level_update(pending_value)


## Get current memory usage in megabytes
func _get_memory_usage_mb() -> float:
	var mem_info = Performance.get_monitor(Performance.MEMORY_STATIC)
	return mem_info / (1024.0 * 1024.0)


## Get performance statistics
## @return: Dictionary with performance metrics
func get_performance_stats() -> Dictionary:
	return {
		"update_in_progress": _update_in_progress,
		"last_update_duration_ms": _last_update_duration_ms,
		"current_memory_mb": _get_memory_usage_mb(),
		"peak_memory_mb": _peak_memory_usage_mb,
		"pending_update": _pending_sea_level >= 0.0,
		"throttle_active": not _throttle_timer.is_stopped()
	}


## Check if an update is currently in progress
## @return: True if update is in progress
func is_update_in_progress() -> bool:
	return _update_in_progress
