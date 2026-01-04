class_name DevConsole extends CanvasLayer
## Developer Console UI
##
## A tilde (~) activated command-line interface for developer commands and log viewing.
## Displays system logs with color-coding and provides command execution capabilities.

# Preload CommandParser
const CommandParserScript = preload("res://scripts/ui/command_parser.gd")

signal command_executed(command: String)

# Command history
const MAX_HISTORY_SIZE = 50

# Console visibility state
var is_console_visible: bool = false

# Command history
var command_history: Array[String] = []
var history_index: int = -1

# Auto-scroll setting
var auto_scroll: bool = true

# UI elements
var _background_panel: Panel
var _header_label: Label
var _log_display: RichTextLabel
var _command_input: LineEdit

# Reference to LogRouter
var _log_router: Node = null

# Reference to DebugPanelManager
var _debug_panel_manager: Node = null

# Command parser
var _command_parser = null


func _ready() -> void:
	# Set layer to 10 (above everything)
	layer = 10

	# Get LogRouter reference
	_log_router = get_node_or_null("/root/LogRouter")
	if not _log_router:
		push_error("DevConsole: LogRouter not found!")
		return

	# Get DebugPanelManager reference
	_debug_panel_manager = get_node_or_null("/root/DebugPanelManager")
	if not _debug_panel_manager:
		push_warning("DevConsole: DebugPanelManager not found - debug commands will not work")

	# Create command parser
	_command_parser = CommandParserScript.new()

	# Create UI
	_create_ui()

	# Connect to LogRouter signals
	_log_router.log_added.connect(_on_log_added)
	_log_router.filters_changed.connect(_on_filters_changed)

	# Connect to DebugPanelManager signals if available
	if _debug_panel_manager:
		_debug_panel_manager.debug_mode_changed.connect(_on_debug_mode_changed)
		_debug_panel_manager.panel_toggled.connect(_on_panel_toggled)

	# Start hidden
	visible = false
	is_console_visible = false

	# Load existing logs
	_refresh_log_display()

	print("DevConsole initialized")


func _create_ui() -> void:
	# Background panel (semi-transparent, blocks mouse input)
	_background_panel = Panel.new()
	_background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_panel.anchor_top = 0.0
	_background_panel.anchor_bottom = 0.6  # Take up top 60% of screen
	_background_panel.anchor_left = 0.0
	_background_panel.anchor_right = 1.0
	_background_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to game

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.95)  # Semi-transparent dark blue
	panel_style.border_color = Color(0.3, 0.4, 0.5, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(0)
	_background_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_background_panel)

	# Header label with filter status
	_header_label = Label.new()
	_header_label.text = "Dev Console [Filter: All] [Debug: OFF]"
	_header_label.add_theme_font_size_override("font_size", 16)
	_header_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_header_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_header_label.anchor_left = 0.0
	_header_label.anchor_right = 1.0
	_header_label.offset_top = 10
	_header_label.offset_bottom = 35
	_header_label.offset_left = 15
	_header_label.offset_right = -15
	_background_panel.add_child(_header_label)

	# Log display area (scrollable RichTextLabel with BBCode support)
	_log_display = RichTextLabel.new()
	_log_display.bbcode_enabled = true
	_log_display.scroll_following = true  # Auto-scroll to bottom
	_log_display.selection_enabled = true
	_log_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_log_display.anchor_top = 0.0
	_log_display.anchor_bottom = 1.0
	_log_display.anchor_left = 0.0
	_log_display.anchor_right = 1.0
	_log_display.offset_top = 40  # Below header
	_log_display.offset_bottom = -45  # Above command input
	_log_display.offset_left = 10
	_log_display.offset_right = -10
	_log_display.add_theme_font_size_override("normal_font_size", 14)
	_log_display.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
	_log_display.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow scrolling
	_background_panel.add_child(_log_display)

	# Command input at bottom
	_command_input = LineEdit.new()
	_command_input.placeholder_text = "Type command here (e.g., /help)..."
	_command_input.add_theme_font_size_override("font_size", 14)
	_command_input.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_command_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	_command_input.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_command_input.anchor_left = 0.0
	_command_input.anchor_right = 1.0
	_command_input.offset_top = -40
	_command_input.offset_bottom = -10
	_command_input.offset_left = 10
	_command_input.offset_right = -10

	# Style the LineEdit
	var line_edit_style = StyleBoxFlat.new()
	line_edit_style.bg_color = Color(0.1, 0.12, 0.15, 0.9)
	line_edit_style.border_color = Color(0.3, 0.4, 0.5, 0.8)
	line_edit_style.set_border_width_all(1)
	line_edit_style.set_corner_radius_all(3)
	line_edit_style.content_margin_left = 8
	line_edit_style.content_margin_right = 8
	_command_input.add_theme_stylebox_override("normal", line_edit_style)
	_command_input.add_theme_stylebox_override("focus", line_edit_style)

	_background_panel.add_child(_command_input)

	# Connect command input signals
	_command_input.text_submitted.connect(_on_command_submitted)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Toggle console with tilde (~) key
		if event.keycode == KEY_QUOTELEFT:  # ~ key (backtick/grave)
			toggle_visibility()
			get_viewport().set_input_as_handled()
		# Handle input when console is visible
		elif is_console_visible:
			# Up arrow - navigate history backward
			if event.keycode == KEY_UP:
				_navigate_history(-1)
				get_viewport().set_input_as_handled()
			# Down arrow - navigate history forward
			elif event.keycode == KEY_DOWN:
				_navigate_history(1)
				get_viewport().set_input_as_handled()
			# Tab - auto-complete (placeholder for future implementation)
			elif event.keycode == KEY_TAB:
				# TODO: Implement auto-complete in future task
				get_viewport().set_input_as_handled()


func toggle_visibility() -> void:
	"""Toggle console visibility and update input capture state"""
	is_console_visible = not is_console_visible
	visible = is_console_visible

	if is_console_visible:
		# Focus command input when opening
		_command_input.grab_focus()
		# Refresh display in case logs were added while hidden
		_refresh_log_display()
	else:
		# Release focus when closing
		_command_input.release_focus()

	# Log the toggle action
	if _log_router:
		var action = "opened" if is_console_visible else "closed"
		_log_router.log("Console " + action, LogRouter.LogLevel.DEBUG, "system")


func _on_command_submitted(command_text: String) -> void:
	"""Handle command submission from LineEdit"""
	if command_text.strip_edges().is_empty():
		return

	# Add to history
	_add_to_history(command_text)

	# Log the command
	if _log_router:
		_log_router.log("> " + command_text, LogRouter.LogLevel.INFO, "console")

	# Parse and execute command
	_execute_command(command_text)

	# Clear input
	_command_input.clear()
	history_index = -1


func _execute_command(command_text: String) -> void:
	"""Parse and execute a console command"""
	if not _command_parser:
		_log_router.log("Command parser not initialized", LogRouter.LogLevel.ERROR, "console")
		return

	# Parse command
	var parsed = _command_parser.parse(command_text)
	if parsed == null:
		_log_router.log("Invalid command format. Commands must start with /", LogRouter.LogLevel.ERROR, "console")
		return

	# Execute command
	var result = _command_parser.execute(parsed)

	# Handle result based on command type
	if result.success:
		# Special handling for specific commands
		match parsed.command:
			"clear":
				clear_logs()
				_log_router.log("Console cleared", LogRouter.LogLevel.INFO, "console")
			"log":
				# Set log level in LogRouter
				if result.data != null:
					_log_router.set_min_level(result.data)
					var level_name = LogRouter.LogLevel.keys()[result.data]
					_log_router.log("Log level set to " + level_name, LogRouter.LogLevel.INFO, "console")
			"filter":
				# Handle filter commands
				_handle_filter_command(parsed.args)
			"history":
				# Display command history
				_display_command_history()
			"help":
				# Display help text
				_log_router.log(result.message, LogRouter.LogLevel.INFO, "console")
			"debug":
				# Handle debug commands
				_handle_debug_command(result.data)
			"relocate":
				# Handle relocate command
				_handle_relocate_command(result.data)
			"terrain":
				# Handle terrain command
				_handle_terrain_command(result.data)
			_:
				# For other commands, just log the result message
				_log_router.log(result.message, LogRouter.LogLevel.INFO, "console")
	else:
		# Log error message
		_log_router.log(result.message, LogRouter.LogLevel.ERROR, "console")

	# Emit signal for external handlers (e.g., debug panel manager, simulation state)
	command_executed.emit(command_text)


func _handle_filter_command(args: Array[String]) -> void:
	"""Handle filter command execution"""
	if args.is_empty():
		return

	var filter_type = args[0].to_lower()

	match filter_type:
		"reset":
			_log_router.clear_filters()
			_log_router.log("All filters cleared", LogRouter.LogLevel.INFO, "console")

		"warnings":
			if args.size() >= 2:
				var enabled = (args[1].to_lower() == "on")
				_log_router.set_hide_warnings(not enabled)
				var state = "enabled" if enabled else "disabled"
				_log_router.log("Warnings filter " + state, LogRouter.LogLevel.INFO, "console")

		"errors":
			if args.size() >= 2:
				var enabled = (args[1].to_lower() == "on")
				_log_router.set_hide_errors(not enabled)
				var state = "enabled" if enabled else "disabled"
				_log_router.log("Errors filter " + state, LogRouter.LogLevel.INFO, "console")

		"category":
			if args.size() >= 2:
				var category = args[1].to_lower()
				if category == "all":
					_log_router.set_category_filter("")
					_log_router.log("Showing all categories", LogRouter.LogLevel.INFO, "console")
				else:
					_log_router.set_category_filter(category)
					_log_router.log("Category filter set to '" + category + "'", LogRouter.LogLevel.INFO, "console")


func _handle_debug_command(mode: String) -> void:
	"""Handle debug command execution"""
	if not _debug_panel_manager:
		_log_router.log("DebugPanelManager not available", LogRouter.LogLevel.ERROR, "console")
		return

	match mode:
		"on":
			_debug_panel_manager.enable_all()
			# Log message is handled by DebugPanelManager
		"off":
			_debug_panel_manager.disable_all()
			# Log message is handled by DebugPanelManager
		"terrain":
			var success = _debug_panel_manager.toggle_panel("terrain")
			if not success:
				_log_router.log("Terrain debug panel not registered", LogRouter.LogLevel.WARNING, "console")
		"performance":
			var success = _debug_panel_manager.toggle_panel("performance")
			if not success:
				_log_router.log("Performance monitor panel not registered", LogRouter.LogLevel.WARNING, "console")


func _handle_relocate_command(coords: Vector3) -> void:
	"""Handle relocate command execution"""
	# Get SimulationState reference
	var simulation_state = get_node_or_null("/root/Main/SimulationState")
	if not simulation_state:
		_log_router.log("SimulationState not found - cannot relocate submarine", LogRouter.LogLevel.ERROR, "console")
		return
	
	# Store old position for logging
	var old_position = simulation_state.submarine_position
	
	# Update submarine position directly
	simulation_state.submarine_position = coords
	
	# Also update the depth component separately to ensure consistency
	simulation_state.submarine_depth = -coords.y  # Y is up in Godot, depth is positive down
	
	# Log the relocation
	_log_router.log(
		"Submarine relocated from (%.1f, %.1f, %.1f) to (%.1f, %.1f, %.1f)" % [
			old_position.x, old_position.y, old_position.z,
			coords.x, coords.y, coords.z
		],
		LogRouter.LogLevel.INFO,
		"submarine"
	)
	
	# Check if StreamingManager exists and trigger terrain streaming update
	var streaming_manager = get_node_or_null("/root/Main/TerrainRenderer/StreamingManager")
	if streaming_manager:
		# Log that we're triggering a streaming update
		_log_router.log(
			"Triggering terrain streaming update for new position",
			LogRouter.LogLevel.INFO,
			"streaming"
		)
		
		# Call the streaming manager's update method with the new position
		# This will trigger chunk loading/unloading as needed
		streaming_manager.update(coords)
	else:
		_log_router.log(
			"StreamingManager not found - terrain streaming not updated",
			LogRouter.LogLevel.WARNING,
			"streaming"
		)


func _display_command_history() -> void:
	"""Display command history in console"""
	if command_history.is_empty():
		_log_router.log("Command history is empty", LogRouter.LogLevel.INFO, "console")
		return

	_log_router.log("Command history:", LogRouter.LogLevel.INFO, "console")
	var count = command_history.size()
	for i in range(count):
		var index = count - i  # Show most recent first
		_log_router.log("  %d. %s" % [index, command_history[count - 1 - i]], LogRouter.LogLevel.INFO, "console")


func _add_to_history(command: String) -> void:
	"""Add command to history, maintaining max size"""
	# Don't add duplicate of most recent command
	if command_history.size() > 0 and command_history[-1] == command:
		return

	command_history.append(command)

	# Trim history if too large
	while command_history.size() > MAX_HISTORY_SIZE:
		command_history.pop_front()


func _navigate_history(direction: int) -> void:
	"""Navigate through command history (direction: -1 = up/back, 1 = down/forward)"""
	if command_history.is_empty():
		return

	# Update history index
	if history_index == -1:
		# Starting navigation from current input
		if direction < 0:
			history_index = command_history.size() - 1
	else:
		history_index += direction

	# Clamp to valid range
	if history_index < 0:
		history_index = -1
		_command_input.text = ""
		return

	if history_index >= command_history.size():
		history_index = command_history.size() - 1

	# Set command input to history entry
	_command_input.text = command_history[history_index]
	_command_input.caret_column = _command_input.text.length()


func _on_log_added(entry) -> void:
	"""Handle new log entry from LogRouter"""
	if not is_console_visible:
		return  # Don't update display if console is hidden

	_add_log_entry_to_display(entry)


func _on_filters_changed() -> void:
	"""Handle filter changes from LogRouter"""
	_update_header()
	_refresh_log_display()


func _on_debug_mode_changed(enabled: bool) -> void:
	"""Handle debug mode changes from DebugPanelManager"""
	_update_header()


func _on_panel_toggled(panel_name: String, visible: bool) -> void:
	"""Handle individual panel toggle from DebugPanelManager"""
	# Update header to reflect current debug state
	_update_header()


func _add_log_entry_to_display(entry) -> void:
	"""Add a single log entry to the display with color coding"""
	var timestamp = "[%.2f]" % entry.timestamp
	var level_name = LogRouter.LogLevel.keys()[entry.level]
	var color_hex = entry.color.to_html(false)

	var formatted_line = (
		"[color=#%s]%s [%s] [%s] %s[/color]"
		% [color_hex, timestamp, level_name, entry.category, entry.message]
	)

	_log_display.append_text(formatted_line + "\n")

	# Auto-scroll to bottom if enabled
	if auto_scroll:
		_log_display.scroll_to_line(_log_display.get_line_count() - 1)


func _refresh_log_display() -> void:
	"""Refresh the entire log display from LogRouter's filtered logs"""
	_log_display.clear()

	if not _log_router:
		return

	var filtered_logs = _log_router.get_filtered_logs()
	for entry in filtered_logs:
		_add_log_entry_to_display(entry)

	_update_header()


func _update_header() -> void:
	"""Update header with current filter status and debug mode"""
	if not _log_router:
		return

	var filter_status = _log_router.get_filter_status()
	
	# Get debug mode status
	var debug_status = "OFF"
	if _debug_panel_manager and _debug_panel_manager.is_debug_enabled():
		debug_status = "ON"
	
	_header_label.text = "Dev Console [Filter: %s] [Debug: %s]" % [filter_status, debug_status]


func clear_logs() -> void:
	"""Clear the log display"""
	_log_display.clear()
	if _log_router:
		_log_router.clear_logs()


func add_log(message: String, level = LogRouter.LogLevel.INFO, category: String = "system") -> void:
	"""Convenience method to add a log entry"""
	if _log_router:
		_log_router.log(message, level, category)


# Public API for external systems


func get_command_history() -> Array[String]:
	"""Get the command history array"""
	return command_history.duplicate()


func is_console_open() -> bool:
	"""Check if console is currently visible"""
	return is_console_visible


func set_auto_scroll(enabled: bool) -> void:
	"""Enable or disable auto-scroll"""
	auto_scroll = enabled
	if _log_display:
		_log_display.scroll_following = enabled


func _handle_terrain_command(action: String) -> void:
	"""Handle terrain command execution"""
	var terrain_renderer = get_node_or_null("/root/Main/TerrainRenderer")
	if not terrain_renderer:
		_log_router.log("TerrainRenderer not found", LogRouter.LogLevel.ERROR, "console")
		return
	
	match action:
		"status":
			# Display terrain status
			var status_msg = "=== Terrain Status ===\n"
			status_msg += "Initialized: %s\n" % terrain_renderer.initialized
			
			if terrain_renderer.initialized:
				# Get submarine reference
				var submarine = get_node_or_null("/root/Main/SubmarineModel")
				if submarine:
					status_msg += "Submarine position: %s\n" % submarine.global_position
				else:
					status_msg += "Submarine: NOT FOUND\n"
				
				# Get chunk manager info
				var chunk_manager = terrain_renderer.get_node_or_null("ChunkManager")
				if chunk_manager:
					status_msg += "Loaded chunks: %d\n" % chunk_manager.get_chunk_count()
					status_msg += "Memory usage: %.1f MB\n" % chunk_manager.get_memory_usage_mb()
				else:
					status_msg += "ChunkManager: NOT FOUND\n"
				
				# Get streaming manager info
				var streaming_manager = terrain_renderer.get_node_or_null("StreamingManager")
				if streaming_manager:
					status_msg += "Streaming: ACTIVE\n"
					status_msg += "Load distance: %.1f m\n" % terrain_renderer.load_distance
				else:
					status_msg += "StreamingManager: NOT FOUND\n"
				
				# Check if submarine is set
				if terrain_renderer._submarine:
					status_msg += "Submarine reference: SET\n"
				else:
					status_msg += "Submarine reference: NOT SET (terrain won't load!)\n"
			
			_log_router.log(status_msg, LogRouter.LogLevel.INFO, "terrain")
		
		"reload":
			# Force reload chunks
			var chunk_manager = terrain_renderer.get_node_or_null("ChunkManager")
			if chunk_manager:
				chunk_manager.unload_all_chunks()
				_log_router.log("All terrain chunks unloaded - will reload on next update", LogRouter.LogLevel.INFO, "terrain")
			else:
				_log_router.log("ChunkManager not found", LogRouter.LogLevel.ERROR, "terrain")
