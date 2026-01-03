extends Node

## LogRouter - Centralized logging system for the developer console
##
## This singleton routes all game system logs to the developer console,
## providing filtering by level and category, color-coding, and a circular buffer.

# Log levels
enum LogLevel { DEBUG, INFO, WARNING, ERROR }  # Detailed diagnostic information (gray)  # General informational messages (white)  # Warning messages (yellow)  # Error messages (red)


# LogEntry class - represents a single log message
class LogEntry:
	var timestamp: float
	var level: LogLevel
	var category: String
	var message: String
	var color: Color

	func _init(p_timestamp: float, p_level: LogLevel, p_category: String, p_message: String):
		timestamp = p_timestamp
		level = p_level
		category = p_category
		message = p_message
		color = _get_color_for_level(p_level)

	func _get_color_for_level(p_level: LogLevel) -> Color:
		match p_level:
			LogLevel.DEBUG:
				return Color(0.6, 0.6, 0.6)  # Gray
			LogLevel.INFO:
				return Color(1.0, 1.0, 1.0)  # White
			LogLevel.WARNING:
				return Color(1.0, 1.0, 0.0)  # Yellow
			LogLevel.ERROR:
				return Color(1.0, 0.0, 0.0)  # Red
			_:
				return Color(1.0, 1.0, 1.0)  # Default white


# Signals
signal log_added(entry: LogEntry)
signal filters_changed

# Circular buffer for log entries (max 1000)
const MAX_BUFFER_SIZE = 1000
var _log_buffer: Array[LogEntry] = []
var _buffer_start_index: int = 0

# Filtering
var _min_level: LogLevel = LogLevel.DEBUG
var _category_filter: String = ""  # Empty means all categories
var _hide_warnings: bool = false
var _hide_errors: bool = false


func _ready():
	name = "LogRouter"
	print("LogRouter initialized")


## Add a log entry to the buffer
func log(message: String, level: LogLevel = LogLevel.INFO, category: String = "system") -> void:
	var entry = LogEntry.new(Time.get_ticks_msec() / 1000.0, level, category, message)

	# Add to circular buffer
	if _log_buffer.size() < MAX_BUFFER_SIZE:
		_log_buffer.append(entry)
	else:
		# Overwrite oldest entry
		_log_buffer[_buffer_start_index] = entry
		_buffer_start_index = (_buffer_start_index + 1) % MAX_BUFFER_SIZE

	# Emit signal if entry passes filters
	if _passes_filters(entry):
		log_added.emit(entry)


## Set minimum log level filter
func set_min_level(level: LogLevel) -> void:
	_min_level = level
	filters_changed.emit()


## Get current minimum log level
func get_min_level() -> LogLevel:
	return _min_level


## Set category filter (empty string = all categories)
func set_category_filter(category: String) -> void:
	_category_filter = category
	filters_changed.emit()


## Get current category filter
func get_category_filter() -> String:
	return _category_filter


## Set whether to hide warnings
func set_hide_warnings(hide: bool) -> void:
	_hide_warnings = hide
	filters_changed.emit()


## Get whether warnings are hidden
func get_hide_warnings() -> bool:
	return _hide_warnings


## Set whether to hide errors
func set_hide_errors(hide: bool) -> void:
	_hide_errors = hide
	filters_changed.emit()


## Get whether errors are hidden
func get_hide_errors() -> bool:
	return _hide_errors


## Clear all filters
func clear_filters() -> void:
	_min_level = LogLevel.DEBUG
	_category_filter = ""
	_hide_warnings = false
	_hide_errors = false
	filters_changed.emit()


## Get all log entries that pass current filters
func get_filtered_logs() -> Array[LogEntry]:
	var filtered: Array[LogEntry] = []

	# Iterate through circular buffer in correct order
	var count = _log_buffer.size()
	for i in range(count):
		var index = (_buffer_start_index + i) % count
		var entry = _log_buffer[index]
		if _passes_filters(entry):
			filtered.append(entry)

	return filtered


## Get all log entries (unfiltered)
func get_all_logs() -> Array[LogEntry]:
	var all_logs: Array[LogEntry] = []

	# Iterate through circular buffer in correct order
	var count = _log_buffer.size()
	for i in range(count):
		var index = (_buffer_start_index + i) % count
		all_logs.append(_log_buffer[index])

	return all_logs


## Clear the log buffer
func clear_logs() -> void:
	_log_buffer.clear()
	_buffer_start_index = 0


## Get current buffer size
func get_buffer_size() -> int:
	return _log_buffer.size()


## Check if a log entry passes current filters
func _passes_filters(entry: LogEntry) -> bool:
	# Check log level
	if entry.level < _min_level:
		return false

	# Check specific level hiding
	if _hide_warnings and entry.level == LogLevel.WARNING:
		return false
	if _hide_errors and entry.level == LogLevel.ERROR:
		return false

	# Check category filter
	if _category_filter != "" and entry.category != _category_filter:
		return false

	return true


## Get filter status as a string for display
func get_filter_status() -> String:
	var status_parts: Array[String] = []

	# Log level
	var level_name = LogLevel.keys()[_min_level]
	if _min_level != LogLevel.DEBUG:
		status_parts.append("Level: " + level_name)

	# Category
	if _category_filter != "":
		status_parts.append("Category: " + _category_filter)

	# Hidden types
	if _hide_warnings:
		status_parts.append("Warnings: OFF")
	if _hide_errors:
		status_parts.append("Errors: OFF")

	if status_parts.is_empty():
		return "All"
	else:
		return ", ".join(status_parts)
