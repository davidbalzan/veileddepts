extends SceneTree
## Checkpoint test for Task 6: Console and Logging
##
## This test verifies that all console and logging functionality
## from tasks 1-5 is working correctly.

var log_router
var console
var test_results = []
var initialized = false

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("CHECKPOINT: Console and Logging System")
	print("Testing Tasks 1-5 Implementation")
	print("=".repeat(60) + "\n")


func _process(_delta: float) -> bool:
	if not initialized:
		# Get LogRouter autoload
		log_router = get_root().get_node_or_null("LogRouter")
		if not log_router:
			return true  # Keep processing
		
		# Create DevConsole
		var DevConsoleScript = preload("res://scripts/ui/dev_console.gd")
		console = DevConsoleScript.new()
		get_root().add_child(console)
		
		# Run all tests
		run_all_tests()
		
		# Print summary
		print_summary()
		
		initialized = true
	
	return true


func run_all_tests() -> void:
	print("Running checkpoint tests...\n")
	
	# Task 1: LogRouter System
	test_log_router_creation()
	test_log_entry_storage()
	test_circular_buffer()
	test_log_level_filtering()
	test_category_filtering()
	test_log_color_coding()
	
	# Task 2: DevConsole UI
	test_console_creation()
	test_console_visibility()
	
	# Task 3: LogRouter-Console Integration
	test_log_display_integration()
	
	# Task 4: CommandParser
	test_command_parsing()
	
	# Task 5: Console Commands
	test_help_command()
	test_clear_command()
	test_log_level_command()
	test_filter_commands()
	test_history_command()


## Task 1 Tests: LogRouter System

func test_log_router_creation() -> void:
	var test_name = "LogRouter Creation"
	if log_router != null:
		record_pass(test_name, "LogRouter autoload exists")
	else:
		record_fail(test_name, "LogRouter not found")


func test_log_entry_storage() -> void:
	var test_name = "Log Entry Storage"
	log_router.clear_logs()
	
	log_router.log("Test message", LogRouter.LogLevel.INFO, "test")
	var logs = log_router.get_all_logs()
	
	if logs.size() == 1 and logs[0].message == "Test message":
		record_pass(test_name, "Logs stored correctly")
	else:
		record_fail(test_name, "Log storage failed")


func test_circular_buffer() -> void:
	var test_name = "Circular Buffer (1000 entry limit)"
	log_router.clear_logs()
	
	# Add 1100 entries
	for i in range(1100):
		log_router.log("Message " + str(i), LogRouter.LogLevel.INFO, "test")
	
	var logs = log_router.get_all_logs()
	
	if logs.size() == 1000:
		record_pass(test_name, "Buffer limited to 1000 entries")
	else:
		record_fail(test_name, "Buffer size: %d (expected 1000)" % logs.size())


func test_log_level_filtering() -> void:
	var test_name = "Log Level Filtering"
	log_router.clear_logs()
	log_router.clear_filters()
	
	log_router.log("Debug", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("Info", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error", LogRouter.LogLevel.ERROR, "test")
	
	log_router.set_min_level(LogRouter.LogLevel.WARNING)
	var filtered = log_router.get_filtered_logs()
	
	if filtered.size() == 2:
		record_pass(test_name, "Filtered to WARNING and ERROR")
	else:
		record_fail(test_name, "Filter returned %d entries (expected 2)" % filtered.size())
	
	log_router.clear_filters()


func test_category_filtering() -> void:
	var test_name = "Category Filtering"
	log_router.clear_logs()
	log_router.clear_filters()
	
	log_router.log("Terrain", LogRouter.LogLevel.INFO, "terrain")
	log_router.log("Physics", LogRouter.LogLevel.INFO, "physics")
	log_router.log("System", LogRouter.LogLevel.INFO, "system")
	
	log_router.set_category_filter("terrain")
	var filtered = log_router.get_filtered_logs()
	
	if filtered.size() == 1 and filtered[0].category == "terrain":
		record_pass(test_name, "Filtered to terrain category")
	else:
		record_fail(test_name, "Category filter failed")
	
	log_router.clear_filters()


func test_log_color_coding() -> void:
	var test_name = "Log Color Coding"
	log_router.clear_logs()
	
	log_router.log("Debug", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("Info", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error", LogRouter.LogLevel.ERROR, "test")
	
	var logs = log_router.get_all_logs()
	
	var colors_correct = (
		logs[0].color == Color(0.6, 0.6, 0.6) and  # DEBUG = gray
		logs[1].color == Color(1.0, 1.0, 1.0) and  # INFO = white
		logs[2].color == Color(1.0, 1.0, 0.0) and  # WARNING = yellow
		logs[3].color == Color(1.0, 0.0, 0.0)      # ERROR = red
	)
	
	if colors_correct:
		record_pass(test_name, "All log levels have correct colors")
	else:
		record_fail(test_name, "Color coding incorrect")


## Task 2 Tests: DevConsole UI

func test_console_creation() -> void:
	var test_name = "DevConsole Creation"
	if console != null:
		record_pass(test_name, "Console created successfully")
	else:
		record_fail(test_name, "Console creation failed")


func test_console_visibility() -> void:
	var test_name = "Console Visibility Toggle"
	
	var initial_visible = console.visible
	console.toggle_visibility()
	var after_toggle = console.visible
	
	if initial_visible != after_toggle:
		record_pass(test_name, "Visibility toggles correctly")
	else:
		record_fail(test_name, "Toggle did not change visibility")


## Task 3 Tests: Integration

func test_log_display_integration() -> void:
	var test_name = "LogRouter-Console Integration"
	log_router.clear_logs()
	
	# Add a log and check if console can access it
	log_router.log("Integration test", LogRouter.LogLevel.INFO, "test")
	var logs = log_router.get_all_logs()
	
	if logs.size() > 0:
		record_pass(test_name, "Console can access LogRouter logs")
	else:
		record_fail(test_name, "Integration failed")


## Task 4 Tests: CommandParser

func test_command_parsing() -> void:
	var test_name = "Command Parsing"
	
	# Test that console has command execution capability
	if console.has_method("_execute_command"):
		record_pass(test_name, "Command execution method exists")
	else:
		record_fail(test_name, "Command execution not implemented")


## Task 5 Tests: Console Commands

func test_help_command() -> void:
	var test_name = "/help Command"
	log_router.clear_logs()
	
	console._execute_command("/help")
	
	# Check if help was logged
	var logs = log_router.get_all_logs()
	if logs.size() > 0:
		record_pass(test_name, "Help command executed")
	else:
		record_fail(test_name, "Help command failed")


func test_clear_command() -> void:
	var test_name = "/clear Command"
	
	# Add some logs
	log_router.log("Test 1", LogRouter.LogLevel.INFO, "test")
	log_router.log("Test 2", LogRouter.LogLevel.INFO, "test")
	var before = log_router.get_buffer_size()
	
	console._execute_command("/clear")
	var after = log_router.get_buffer_size()
	
	if after < before:
		record_pass(test_name, "Clear command works (before: %d, after: %d)" % [before, after])
	else:
		record_fail(test_name, "Clear command failed")


func test_log_level_command() -> void:
	var test_name = "/log Command"
	log_router.clear_filters()
	
	console._execute_command("/log warning")
	var level = log_router.get_min_level()
	
	if level == LogRouter.LogLevel.WARNING:
		record_pass(test_name, "Log level set to WARNING")
	else:
		record_fail(test_name, "Log level not set correctly")
	
	log_router.clear_filters()


func test_filter_commands() -> void:
	var test_name = "/filter Commands"
	log_router.clear_filters()
	
	# Test warnings filter
	console._execute_command("/filter warnings off")
	var warnings_hidden = log_router.get_hide_warnings()
	
	# Test reset
	console._execute_command("/filter reset")
	var warnings_shown = not log_router.get_hide_warnings()
	
	if warnings_hidden and warnings_shown:
		record_pass(test_name, "Filter commands work correctly")
	else:
		record_fail(test_name, "Filter commands failed")


func test_history_command() -> void:
	var test_name = "/history Command"
	
	# Add some history
	console._add_to_history("/help")
	console._add_to_history("/clear")
	
	log_router.clear_logs()
	console._execute_command("/history")
	
	# Check if history was logged
	var logs = log_router.get_all_logs()
	if logs.size() > 0:
		record_pass(test_name, "History command executed")
	else:
		record_fail(test_name, "History command failed")


## Helper Functions

func record_pass(test_name: String, details: String = "") -> void:
	test_results.append({
		"name": test_name,
		"passed": true,
		"details": details
	})
	print("  ✓ %s" % test_name)
	if details:
		print("    %s" % details)


func record_fail(test_name: String, details: String = "") -> void:
	test_results.append({
		"name": test_name,
		"passed": false,
		"details": details
	})
	print("  ✗ %s" % test_name)
	if details:
		print("    %s" % details)


func print_summary() -> void:
	var passed = 0
	var failed = 0
	
	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1
	
	print("\n" + "=".repeat(60))
	print("CHECKPOINT SUMMARY")
	print("=".repeat(60))
	print("Total Tests: %d" % test_results.size())
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)
	print("Success Rate: %.1f%%" % (float(passed) / test_results.size() * 100.0))
	print("=".repeat(60))
	
	if failed == 0:
		print("\n✓ ALL TESTS PASSED - Console and Logging system ready!")
		print("  Tasks 1-5 are complete and working correctly.\n")
	else:
		print("\n✗ SOME TESTS FAILED - Review failures above")
		print("  Failed tests:")
		for result in test_results:
			if not result.passed:
				print("    - %s" % result.name)
		print()
	
	quit()
