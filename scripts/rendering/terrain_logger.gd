class_name TerrainLogger extends Node
## Centralized logging system for the terrain streaming system
##
## Provides structured logging with timestamps, context, and severity levels.
## Logs chunk loading/unloading, memory usage, performance warnings, and errors.
##
## Validates: Requirements 13.4

## Log levels
enum LogLevel { DEBUG, INFO, WARNING, ERROR, CRITICAL }  # Detailed information for debugging  # General information  # Warning messages  # Error messages  # Critical errors

## Configuration
@export var enabled: bool = true
@export var min_log_level: LogLevel = LogLevel.INFO
@export var log_to_console: bool = true
@export var log_to_file: bool = false
@export var log_file_path: String = "user://terrain_system.log"
@export var include_timestamps: bool = true
@export var include_context: bool = true

## Internal state
var _log_file: FileAccess = null
var _session_start_time: int = 0


func _ready() -> void:
	_session_start_time = Time.get_ticks_msec()

	if log_to_file:
		_open_log_file()

	log_info("TerrainLogger", "Logging system initialized")


func _exit_tree() -> void:
	if _log_file:
		log_info("TerrainLogger", "Logging system shutting down")
		_log_file.close()
		_log_file = null


## Log a debug message
##
## @param context: Context string (e.g., "ChunkManager", "StreamingManager")
## @param message: Log message
## @param data: Optional dictionary of additional data
func log_debug(context: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.DEBUG, context, message, data)


## Log an info message
##
## @param context: Context string (e.g., "ChunkManager", "StreamingManager")
## @param message: Log message
## @param data: Optional dictionary of additional data
func log_info(context: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.INFO, context, message, data)


## Log a warning message
##
## @param context: Context string (e.g., "ChunkManager", "StreamingManager")
## @param message: Log message
## @param data: Optional dictionary of additional data
func log_warning(context: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.WARNING, context, message, data)


## Log an error message
##
## @param context: Context string (e.g., "ChunkManager", "StreamingManager")
## @param message: Log message
## @param data: Optional dictionary of additional data
func log_error(context: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.ERROR, context, message, data)


## Log a critical error message
##
## @param context: Context string (e.g., "ChunkManager", "StreamingManager")
## @param message: Log message
## @param data: Optional dictionary of additional data
func log_critical(context: String, message: String, data: Dictionary = {}) -> void:
	_log(LogLevel.CRITICAL, context, message, data)


## Log chunk loading event
##
## @param chunk_coord: Chunk coordinates
## @param memory_mb: Memory used by chunk in MB
## @param total_memory_mb: Total memory used by all chunks in MB
func log_chunk_loaded(chunk_coord: Vector2i, memory_mb: float, total_memory_mb: float) -> void:
	log_info(
		"ChunkManager",
		"Chunk loaded",
		{
			"chunk": chunk_coord,
			"memory_mb": "%.2f" % memory_mb,
			"total_memory_mb": "%.2f" % total_memory_mb
		}
	)


## Log chunk unloading event
##
## @param chunk_coord: Chunk coordinates
## @param reason: Reason for unloading (e.g., "distance", "memory_limit", "emergency")
## @param total_memory_mb: Total memory used after unloading in MB
func log_chunk_unloaded(chunk_coord: Vector2i, reason: String, total_memory_mb: float) -> void:
	log_info(
		"ChunkManager",
		"Chunk unloaded",
		{"chunk": chunk_coord, "reason": reason, "total_memory_mb": "%.2f" % total_memory_mb}
	)


## Log memory usage change
##
## @param old_memory_mb: Previous memory usage in MB
## @param new_memory_mb: New memory usage in MB
## @param limit_mb: Memory limit in MB
func log_memory_change(old_memory_mb: float, new_memory_mb: float, limit_mb: int) -> void:
	var change_mb: float = new_memory_mb - old_memory_mb
	var change_str: String = "+%.2f" % change_mb if change_mb >= 0 else "%.2f" % change_mb

	var level: LogLevel = LogLevel.INFO
	if new_memory_mb > limit_mb * 0.9:
		level = LogLevel.WARNING

	_log(
		level,
		"MemoryManager",
		"Memory usage changed",
		{
			"old_mb": "%.2f" % old_memory_mb,
			"new_mb": "%.2f" % new_memory_mb,
			"change_mb": change_str,
			"limit_mb": str(limit_mb),
			"usage_percent": "%.1f%%" % ((new_memory_mb / limit_mb) * 100.0)
		}
	)


## Log performance warning
##
## @param operation: Operation that exceeded budget (e.g., "chunk_load", "lod_update")
## @param actual_ms: Actual time taken in milliseconds
## @param budget_ms: Time budget in milliseconds
func log_performance_warning(operation: String, actual_ms: float, budget_ms: float) -> void:
	log_warning(
		"PerformanceMonitor",
		"Operation exceeded time budget",
		{
			"operation": operation,
			"actual_ms": "%.2f" % actual_ms,
			"budget_ms": "%.2f" % budget_ms,
			"overage_ms": "%.2f" % (actual_ms - budget_ms),
			"overage_percent": "%.1f%%" % (((actual_ms - budget_ms) / budget_ms) * 100.0)
		}
	)


## Log LOD change event
##
## @param chunk_coord: Chunk coordinates
## @param old_lod: Previous LOD level
## @param new_lod: New LOD level
## @param distance: Distance from viewer in meters
func log_lod_change(chunk_coord: Vector2i, old_lod: int, new_lod: int, distance: float) -> void:
	log_debug(
		"ChunkRenderer",
		"LOD changed",
		{
			"chunk": chunk_coord,
			"old_lod": str(old_lod),
			"new_lod": str(new_lod),
			"distance_m": "%.1f" % distance
		}
	)


## Log streaming event
##
## @param event_type: Type of event (e.g., "queue_updated", "load_started", "load_completed")
## @param data: Event-specific data
func log_streaming_event(event_type: String, data: Dictionary = {}) -> void:
	log_debug("StreamingManager", event_type, data)


## Internal logging function
##
## @param level: Log level
## @param context: Context string
## @param message: Log message
## @param data: Additional data dictionary
func _log(level: LogLevel, context: String, message: String, data: Dictionary) -> void:
	if not enabled:
		return

	if level < min_log_level:
		return

	# Build log entry
	var log_entry: String = _format_log_entry(level, context, message, data)

	# Output to console
	if log_to_console:
		_output_to_console(level, log_entry)

	# Output to file
	if log_to_file and _log_file:
		_output_to_file(log_entry)


## Format a log entry
##
## @param level: Log level
## @param context: Context string
## @param message: Log message
## @param data: Additional data dictionary
## @return: Formatted log entry string
func _format_log_entry(
	level: LogLevel, context: String, message: String, data: Dictionary
) -> String:
	var parts: Array[String] = []

	# Add timestamp
	if include_timestamps:
		var timestamp: String = _get_timestamp()
		parts.append("[%s]" % timestamp)

	# Add log level
	var level_str: String = _get_level_string(level)
	parts.append("[%s]" % level_str)

	# Add context
	if include_context:
		parts.append("[%s]" % context)

	# Add message
	parts.append(message)

	# Add data if present
	if not data.is_empty():
		var data_str: String = _format_data(data)
		parts.append("- %s" % data_str)

	return " ".join(parts)


## Get timestamp string
##
## @return: Timestamp string in format "HH:MM:SS.mmm"
func _get_timestamp() -> String:
	var elapsed_ms: int = Time.get_ticks_msec() - _session_start_time
	var total_seconds: int = elapsed_ms / 1000
	var milliseconds: int = elapsed_ms % 1000

	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60

	return "%02d:%02d:%02d.%03d" % [hours, minutes, seconds, milliseconds]


## Get log level string
##
## @param level: Log level
## @return: Level string (e.g., "INFO", "ERROR")
func _get_level_string(level: LogLevel) -> String:
	match level:
		LogLevel.DEBUG:
			return "DEBUG"
		LogLevel.INFO:
			return "INFO"
		LogLevel.WARNING:
			return "WARN"
		LogLevel.ERROR:
			return "ERROR"
		LogLevel.CRITICAL:
			return "CRIT"
		_:
			return "UNKNOWN"


## Format data dictionary as string
##
## @param data: Data dictionary
## @return: Formatted string
func _format_data(data: Dictionary) -> String:
	var parts: Array[String] = []

	for key in data:
		var value = data[key]
		var value_str: String = str(value)
		parts.append("%s=%s" % [key, value_str])

	return ", ".join(parts)


## Output log entry to console
##
## @param level: Log level
## @param entry: Formatted log entry
func _output_to_console(level: LogLevel, entry: String) -> void:
	match level:
		LogLevel.DEBUG, LogLevel.INFO:
			print(entry)
		LogLevel.WARNING:
			push_warning(entry)
		LogLevel.ERROR, LogLevel.CRITICAL:
			push_error(entry)


## Output log entry to file
##
## @param entry: Formatted log entry
func _output_to_file(entry: String) -> void:
	if not _log_file:
		return

	_log_file.store_line(entry)
	_log_file.flush()  # Ensure it's written immediately


## Open log file for writing
func _open_log_file() -> void:
	_log_file = FileAccess.open(log_file_path, FileAccess.WRITE)

	if not _log_file:
		push_error("TerrainLogger: Failed to open log file: %s" % log_file_path)
		log_to_file = false
		return

	# Write header
	var datetime: Dictionary = Time.get_datetime_dict_from_system()
	_log_file.store_line("=== Terrain System Log ===")
	_log_file.store_line(
		(
			"Session started: %04d-%02d-%02d %02d:%02d:%02d"
			% [
				datetime.year,
				datetime.month,
				datetime.day,
				datetime.hour,
				datetime.minute,
				datetime.second
			]
		)
	)
	_log_file.store_line("=".repeat(50))
	_log_file.store_line("")
	_log_file.flush()


## Get singleton instance (if registered as autoload)
static func get_instance() -> TerrainLogger:
	if Engine.has_singleton("TerrainLogger"):
		return Engine.get_singleton("TerrainLogger")
	return null
