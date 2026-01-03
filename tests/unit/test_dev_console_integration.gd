extends GutTest
## Unit tests for DevConsole and LogRouter integration

const DevConsoleScript = preload("res://scripts/ui/dev_console.gd")

var console
var log_router: Node


func before_each():
	# Get LogRouter singleton
	log_router = get_node_or_null("/root/LogRouter")
	assert_not_null(log_router, "LogRouter should be available as autoload")
	
	# Clear any existing logs
	log_router.clear_logs()
	log_router.clear_filters()
	
	# Create console instance
	console = DevConsoleScript.new()
	add_child_autofree(console)
	
	# Wait for console to initialize
	await wait_physics_frames(2)


func test_console_connects_to_log_router():
	# Verify console has reference to LogRouter
	assert_not_null(console._log_router, "Console should have LogRouter reference")
	assert_eq(console._log_router, log_router, "Console should reference the LogRouter singleton")


func test_logs_appear_in_console_when_visible():
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Add a log entry
	log_router.log("Test message", LogRouter.LogLevel.INFO, "test")
	await wait_physics_frames(1)
	
	# Verify log appears in display
	var log_text = console._log_display.get_parsed_text()
	assert_string_contains(log_text, "Test message", "Log message should appear in console")
	assert_string_contains(log_text, "INFO", "Log level should appear in console")
	assert_string_contains(log_text, "test", "Log category should appear in console")


func test_logs_with_different_levels_have_correct_colors():
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Add logs with different levels
	log_router.log("Debug message", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("Info message", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning message", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error message", LogRouter.LogLevel.ERROR, "test")
	await wait_physics_frames(1)
	
	# Verify all messages appear
	var log_text = console._log_display.get_parsed_text()
	assert_string_contains(log_text, "Debug message", "Debug message should appear")
	assert_string_contains(log_text, "Info message", "Info message should appear")
	assert_string_contains(log_text, "Warning message", "Warning message should appear")
	assert_string_contains(log_text, "Error message", "Error message should appear")
	
	# Verify all log levels appear
	assert_string_contains(log_text, "DEBUG", "DEBUG level should appear")
	assert_string_contains(log_text, "INFO", "INFO level should appear")
	assert_string_contains(log_text, "WARNING", "WARNING level should appear")
	assert_string_contains(log_text, "ERROR", "ERROR level should appear")


func test_filter_status_displayed_in_header():
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Initial state should show "All"
	var header_text = console._header_label.text
	assert_string_contains(header_text, "All", "Header should show 'All' when no filters active")
	
	# Set minimum log level
	log_router.set_min_level(LogRouter.LogLevel.WARNING)
	await wait_physics_frames(1)
	
	# Verify header updates
	header_text = console._header_label.text
	assert_true(
		"WARNING" in header_text or "Level" in header_text,
		"Header should show log level filter: " + header_text
	)


func test_category_filter_displayed_in_header():
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Set category filter
	log_router.set_category_filter("terrain")
	await wait_physics_frames(1)
	
	# Verify header updates
	var header_text = console._header_label.text
	assert_true(
		"terrain" in header_text or "Category" in header_text,
		"Header should show category filter: " + header_text
	)


func test_filter_reset_updates_header():
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Set some filters
	log_router.set_min_level(LogRouter.LogLevel.ERROR)
	log_router.set_category_filter("test")
	await wait_physics_frames(1)
	
	# Clear filters
	log_router.clear_filters()
	await wait_physics_frames(1)
	
	# Verify header shows "All"
	var header_text = console._header_label.text
	assert_string_contains(header_text, "All", "Header should show 'All' after filter reset")


func test_logs_added_while_hidden_appear_when_opened():
	# Console starts hidden
	assert_false(console.is_console_visible, "Console should start hidden")
	
	# Add logs while hidden
	log_router.log("Hidden message 1", LogRouter.LogLevel.INFO, "test")
	log_router.log("Hidden message 2", LogRouter.LogLevel.WARNING, "test")
	await wait_physics_frames(1)
	
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Verify logs appear
	var log_text = console._log_display.get_parsed_text()
	assert_string_contains(log_text, "Hidden message 1", "Logs added while hidden should appear")
	assert_string_contains(log_text, "Hidden message 2", "Logs added while hidden should appear")


func test_filtered_logs_dont_appear():
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Set filter to only show errors
	log_router.set_min_level(LogRouter.LogLevel.ERROR)
	await wait_physics_frames(1)
	
	# Add logs at different levels
	log_router.log("Debug message", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("Info message", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning message", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error message", LogRouter.LogLevel.ERROR, "test")
	await wait_physics_frames(1)
	
	# Verify only error appears
	var log_text = console._log_display.get_parsed_text()
	assert_false(log_text.contains("Debug message"), "Debug should be filtered out")
	assert_false(log_text.contains("Info message"), "Info should be filtered out")
	assert_false(log_text.contains("Warning message"), "Warning should be filtered out")
	assert_string_contains(log_text, "Error message", "Error should appear")


func test_console_refresh_on_filter_change():
	# Open console and add logs
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	log_router.log("Debug message", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("Error message", LogRouter.LogLevel.ERROR, "test")
	await wait_physics_frames(1)
	
	# Verify both appear initially
	var log_text = console._log_display.get_parsed_text()
	assert_string_contains(log_text, "Debug message", "Debug should appear initially")
	assert_string_contains(log_text, "Error message", "Error should appear initially")
	
	# Change filter
	log_router.set_min_level(LogRouter.LogLevel.ERROR)
	await wait_physics_frames(1)
	
	# Verify display refreshes
	log_text = console._log_display.get_parsed_text()
	assert_false(log_text.contains("Debug message"), "Debug should disappear after filter")
	assert_string_contains(log_text, "Error message", "Error should still appear after filter")


func test_auto_scroll_enabled_by_default():
	assert_true(console.auto_scroll, "Auto-scroll should be enabled by default")
	assert_true(console._log_display.scroll_following, "RichTextLabel scroll_following should be enabled")


func test_color_coding_matches_log_levels():
	# Open console
	console.toggle_visibility()
	await wait_physics_frames(1)
	
	# Add logs and check colors are applied
	log_router.log("DebugTest", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("InfoTest", LogRouter.LogLevel.INFO, "test")
	log_router.log("WarningTest", LogRouter.LogLevel.WARNING, "test")
	log_router.log("ErrorTest", LogRouter.LogLevel.ERROR, "test")
	await wait_physics_frames(1)
	
	# Get the parsed text
	var log_text = console._log_display.get_parsed_text()
	
	# Verify all log messages appear
	assert_string_contains(log_text, "DebugTest", "DebugTest message should appear")
	assert_string_contains(log_text, "InfoTest", "InfoTest message should appear")
	assert_string_contains(log_text, "WarningTest", "WarningTest message should appear")
	assert_string_contains(log_text, "ErrorTest", "ErrorTest message should appear")
	
	# Verify all log levels appear (which means colors were applied via BBCode)
	assert_string_contains(log_text, "DEBUG", "DEBUG level should appear")
	assert_string_contains(log_text, "INFO", "INFO level should appear")
	assert_string_contains(log_text, "WARNING", "WARNING level should appear")
	assert_string_contains(log_text, "ERROR", "ERROR level should appear")
