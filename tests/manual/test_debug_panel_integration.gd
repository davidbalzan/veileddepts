extends GutTest
## Test DebugPanelManager integration with DevConsole
##
## Verifies that debug commands properly control the DebugPanelManager

var console: DevConsole
var debug_panel_manager: Node
var log_router: Node


func before_each():
	# Get autoload references
	log_router = get_node("/root/LogRouter")
	debug_panel_manager = get_node("/root/DebugPanelManager")
	
	# Create console instance
	console = DevConsole.new()
	add_child_autofree(console)
	
	# Wait for ready
	await wait_frames(1)
	
	# Ensure debug mode starts disabled
	if debug_panel_manager.is_debug_enabled():
		debug_panel_manager.disable_all()


func test_debug_on_command_enables_all_panels():
	# Execute /debug on command
	console._execute_command("/debug on")
	
	# Verify debug mode is enabled
	assert_true(
		debug_panel_manager.is_debug_enabled(),
		"Debug mode should be enabled after /debug on"
	)


func test_debug_off_command_disables_all_panels():
	# Enable debug mode first
	debug_panel_manager.enable_all()
	assert_true(debug_panel_manager.is_debug_enabled(), "Setup: debug should be enabled")
	
	# Execute /debug off command
	console._execute_command("/debug off")
	
	# Verify debug mode is disabled
	assert_false(
		debug_panel_manager.is_debug_enabled(),
		"Debug mode should be disabled after /debug off"
	)


func test_debug_terrain_command_toggles_terrain_panel():
	# Register a mock terrain panel
	var mock_panel = CanvasLayer.new()
	mock_panel.visible = false
	add_child_autofree(mock_panel)
	debug_panel_manager.register_panel("terrain", mock_panel)
	
	# Initial state should be hidden
	assert_false(
		debug_panel_manager.is_panel_visible("terrain"),
		"Terrain panel should start hidden"
	)
	
	# Execute /debug terrain command
	console._execute_command("/debug terrain")
	
	# Verify panel is now visible
	assert_true(
		debug_panel_manager.is_panel_visible("terrain"),
		"Terrain panel should be visible after toggle"
	)
	
	# Toggle again
	console._execute_command("/debug terrain")
	
	# Verify panel is hidden again
	assert_false(
		debug_panel_manager.is_panel_visible("terrain"),
		"Terrain panel should be hidden after second toggle"
	)


func test_debug_performance_command_toggles_performance_panel():
	# Register a mock performance panel
	var mock_panel = CanvasLayer.new()
	mock_panel.visible = false
	add_child_autofree(mock_panel)
	debug_panel_manager.register_panel("performance", mock_panel)
	
	# Initial state should be hidden
	assert_false(
		debug_panel_manager.is_panel_visible("performance"),
		"Performance panel should start hidden"
	)
	
	# Execute /debug performance command
	console._execute_command("/debug performance")
	
	# Verify panel is now visible
	assert_true(
		debug_panel_manager.is_panel_visible("performance"),
		"Performance panel should be visible after toggle"
	)


func test_console_header_shows_debug_status_off():
	# Ensure debug is off
	if debug_panel_manager.is_debug_enabled():
		debug_panel_manager.disable_all()
	
	# Update header
	console._update_header()
	
	# Check header text contains "Debug: OFF"
	assert_string_contains(
		console._header_label.text,
		"Debug: OFF",
		"Header should show Debug: OFF when debug mode is disabled"
	)


func test_console_header_shows_debug_status_on():
	# Enable debug mode
	debug_panel_manager.enable_all()
	
	# Update header
	console._update_header()
	
	# Check header text contains "Debug: ON"
	assert_string_contains(
		console._header_label.text,
		"Debug: ON",
		"Header should show Debug: ON when debug mode is enabled"
	)


func test_console_header_updates_on_debug_mode_change():
	# Start with debug off
	if debug_panel_manager.is_debug_enabled():
		debug_panel_manager.disable_all()
	
	# Initial header should show OFF
	console._update_header()
	assert_string_contains(console._header_label.text, "Debug: OFF")
	
	# Enable debug mode via command
	console._execute_command("/debug on")
	
	# Header should now show ON
	assert_string_contains(
		console._header_label.text,
		"Debug: ON",
		"Header should update to Debug: ON after enabling debug mode"
	)
	
	# Disable debug mode via command
	console._execute_command("/debug off")
	
	# Header should now show OFF again
	assert_string_contains(
		console._header_label.text,
		"Debug: OFF",
		"Header should update to Debug: OFF after disabling debug mode"
	)


func test_invalid_debug_panel_name_logs_warning():
	# Clear logs first
	log_router.clear_logs()
	
	# Try to toggle a non-existent panel
	console._execute_command("/debug nonexistent")
	
	# Check that a warning was logged
	var logs = log_router.get_filtered_logs()
	var found_warning = false
	for entry in logs:
		if entry.level == LogRouter.LogLevel.WARNING and "not registered" in entry.message:
			found_warning = true
			break
	
	assert_true(
		found_warning,
		"Should log warning when trying to toggle non-existent panel"
	)


func test_debug_commands_work_without_debug_panel_manager():
	# Create a console without DebugPanelManager
	var isolated_console = DevConsole.new()
	isolated_console._debug_panel_manager = null
	add_child_autofree(isolated_console)
	await wait_frames(1)
	
	# Clear logs
	log_router.clear_logs()
	
	# Try to execute debug command
	isolated_console._execute_command("/debug on")
	
	# Should log an error about DebugPanelManager not being available
	var logs = log_router.get_filtered_logs()
	var found_error = false
	for entry in logs:
		if entry.level == LogRouter.LogLevel.ERROR and "not available" in entry.message:
			found_error = true
			break
	
	assert_true(
		found_error,
		"Should log error when DebugPanelManager is not available"
	)
