extends Node
class_name BlackBoxLogger

## Black Box Flight Recorder
## Logs critical submarine events to file for debugging
## Logs: commands, depth changes, physics state, critical events

const LOG_FILE_PATH: String = "user://submarine_black_box.log"
const MAX_LOG_SIZE: int = 500000  # 500KB max

var _file: FileAccess
var _last_depth: float = 0.0
var _last_pitch: float = 0.0
var _log_buffer: Array[String] = []
var _buffer_size: int = 10  # Write every 10 entries


func _ready() -> void:
	_print_last_session()
	_open_log_file()
	_write_header()


func _print_last_session() -> void:
	# Read and print last session's log if it exists
	var old_log = FileAccess.open(LOG_FILE_PATH, FileAccess.READ)
	if old_log:
		print("\n=== PREVIOUS BLACK BOX LOG ===")
		var line_count = 0
		while not old_log.eof_reached() and line_count < 100:  # Last 100 lines
			var line = old_log.get_line()
			if line.length() > 0:
				print(line)
				line_count += 1
		old_log.close()
		print("=== END PREVIOUS LOG ===\n")
	else:
		print("BlackBox: No previous log found")


func _exit_tree() -> void:
	_flush_buffer()
	if _file:
		_file.close()


func _open_log_file() -> void:
	_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if not _file:
		push_error("BlackBox: Failed to open log file")


func _write_header() -> void:
	_write_immediate("=== SUBMARINE BLACK BOX LOG ===")
	_write_immediate("Started: %s" % Time.get_datetime_string_from_system())
	_write_immediate("Format: [TIME] EVENT | data")
	_write_immediate("========================================")


func _write_immediate(line: String) -> void:
	if _file:
		_file.store_line(line)
		_file.flush()
	print("[BB] ", line)  # Also print to console


func _write_buffered(line: String) -> void:
	_log_buffer.append(line)
	if _log_buffer.size() >= _buffer_size:
		_flush_buffer()


func _flush_buffer() -> void:
	if _file and _log_buffer.size() > 0:
		for line in _log_buffer:
			_file.store_line(line)
			print("[BB] ", line)  # Also print to console
		_file.flush()
		_log_buffer.clear()


func _get_timestamp() -> String:
	var time = Time.get_ticks_msec() / 1000.0
	return "%.2f" % time


## Log submarine command
func log_command(cmd_type: String, data: Dictionary) -> void:
	var msg = "[%s] CMD:%s" % [_get_timestamp(), cmd_type]
	for key in data:
		msg += " %s=%.1f" % [key, data[key]]
	_write_immediate(msg)


## Log submarine state (called periodically, buffered)
func log_state(depth: float, pitch: float, heading: float, speed: float, v_vel: float) -> void:
	# Only log if significant change
	if abs(depth - _last_depth) > 1.0 or abs(pitch - _last_pitch) > 2.0:
		var msg = "[%s] STATE d=%.1f p=%.1f h=%.0f s=%.1f vv=%.2f" % [
			_get_timestamp(), depth, pitch, heading, speed, v_vel
		]
		_write_buffered(msg)
		_last_depth = depth
		_last_pitch = pitch


## Log physics forces
func log_forces(lift: float, buoy: float, dive_torque: float) -> void:
	var msg = "[%s] FORCE lift=%.0f buoy=%.0f dt=%.0f" % [
		_get_timestamp(), lift, buoy, dive_torque
	]
	_write_buffered(msg)


## Log critical event
func log_event(event: String) -> void:
	_write_immediate("[%s] EVENT: %s" % [_get_timestamp(), event])


## Log error/warning
func log_error(error: String) -> void:
	_write_immediate("[%s] ERROR: %s" % [_get_timestamp(), error])


## Get log file path for user
func get_log_path() -> String:
	return ProjectSettings.globalize_path(LOG_FILE_PATH)
