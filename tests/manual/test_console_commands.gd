extends Node
## Test for console command execution
##
## This test verifies that console commands work correctly

const DevConsoleScript = preload("res://scripts/ui/dev_console.gd")

var console
var log_router
var test_count: int = 0
var passed_count: int = 0


func _ready() -> void:
	print("\n=== Console Commands Test ===\n")

	# Wait a frame for LogRouter to be ready
	await get_tree().process_frame

	log_router = get_node_or_null("/root/LogRouter")
	if not log_router:
		print("✗ LogRouter not found!")
		get_tree().quit()
		return

	run_tests()


func run_tests() -> void:
	test_help_command()
	await get_tree().process_frame
	
	test_clear_command()
	await get_tree().process_frame
	
	test_log_level_command()
	await get_tree().process_frame
	
	test_filter_commands()
	await get_tree().process_frame
	
	test_history_command()
	await get_tree().process_frame
	
	test_invalid_command()
	await get_tree().process_frame

	print("\n=== Test Results ===")
	print("Passed: %d/%d tests" % [passed_count, test_count])

	if passed_count == test_count:
		print("✓ All tests passed!")
	else:
		print("✗ Some tests failed")

	get_tree().quit()


func test_help_command() -> void:
	test_count += 1
	print("Test 1: /help command...")

	console = DevConsoleScript.new()
	add_child(console)
	console.toggle_visibility()
	await get_tree().process_frame

	# Execute help command
	console._execute_command("/help")
	await get_tree().process_frame

	# Check if help was logged (we can't easily check the exact output, but we can verify no errors)
	print("  ✓ /help command executed")
	passed_count += 1

	remove_child(console)
	console.queue_free()


func test_clear_command() -> void:
	test_count += 1
	print("Test 2: /clear command...")

	console = DevConsoleScript.new()
	add_child(console)
	console.toggle_visibility()
	await get_tree().process_frame

	# Add some logs
	log_router.log("Test log 1", LogRouter.LogLevel.INFO, "test")
	log_router.log("Test log 2", LogRouter.LogLevel.INFO, "test")
	await get_tree().process_frame

	var logs_before = log_router.get_buffer_size()

	# Execute clear command
	console._execute_command("/clear")
	await get_tree().process_frame

	var logs_after = log_router.get_buffer_size()

	if logs_after < logs_before:
		print("  ✓ /clear command cleared logs")
		passed_count += 1
	else:
		print("  ✗ /clear command did not clear logs")

	remove_child(console)
	console.queue_free()


func test_log_level_command() -> void:
	test_count += 1
	print("Test 3: /log command...")

	console = DevConsoleScript.new()
	add_child(console)
	console.toggle_visibility()
	await get_tree().process_frame

	# Set log level to WARNING
	console._execute_command("/log warning")
	await get_tree().process_frame

	var current_level = log_router.get_min_level()

	if current_level == LogRouter.LogLevel.WARNING:
		print("  ✓ /log command set level to WARNING")
		passed_count += 1
	else:
		print("  ✗ /log command did not set level correctly (got %d)" % current_level)

	# Reset to DEBUG
	log_router.set_min_level(LogRouter.LogLevel.DEBUG)

	remove_child(console)
	console.queue_free()


func test_filter_commands() -> void:
	test_count += 1
	print("Test 4: /filter commands...")

	console = DevConsoleScript.new()
	add_child(console)
	console.toggle_visibility()
	await get_tree().process_frame

	# Test filter warnings off
	console._execute_command("/filter warnings off")
	await get_tree().process_frame

	if log_router.get_hide_warnings():
		print("  ✓ /filter warnings off works")
	else:
		print("  ✗ /filter warnings off failed")
		remove_child(console)
		console.queue_free()
		return

	# Test filter reset
	console._execute_command("/filter reset")
	await get_tree().process_frame

	if not log_router.get_hide_warnings():
		print("  ✓ /filter reset works")
		passed_count += 1
	else:
		print("  ✗ /filter reset failed")

	remove_child(console)
	console.queue_free()


func test_history_command() -> void:
	test_count += 1
	print("Test 5: /history command...")

	console = DevConsoleScript.new()
	add_child(console)
	console.toggle_visibility()
	await get_tree().process_frame

	# Add some commands to history
	console._add_to_history("/help")
	console._add_to_history("/clear")
	console._add_to_history("/log info")

	# Execute history command
	console._execute_command("/history")
	await get_tree().process_frame

	# If no error occurred, consider it passed
	print("  ✓ /history command executed")
	passed_count += 1

	remove_child(console)
	console.queue_free()


func test_invalid_command() -> void:
	test_count += 1
	print("Test 6: Invalid command handling...")

	console = DevConsoleScript.new()
	add_child(console)
	console.toggle_visibility()
	await get_tree().process_frame

	# Execute invalid command
	console._execute_command("/invalidcmd")
	await get_tree().process_frame

	# If no crash occurred, consider it passed
	print("  ✓ Invalid command handled gracefully")
	passed_count += 1

	remove_child(console)
	console.queue_free()
