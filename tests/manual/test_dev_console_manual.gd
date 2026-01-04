extends Node
## Manual test for DevConsole UI component
##
## This test verifies that the DevConsole can be instantiated,
## displays logs correctly, and responds to input.

const DevConsoleScript = preload("res://scripts/ui/dev_console.gd")

var console
var test_count: int = 0
var passed_count: int = 0


func _ready() -> void:
	print("\n=== DevConsole Manual Test ===\n")

	# Wait a frame for LogRouter to be ready
	await get_tree().process_frame

	run_tests()


func run_tests() -> void:
	test_console_creation()
	test_console_visibility()
	test_log_display()
	test_command_history()
	test_auto_scroll()

	print("\n=== Test Results ===")
	print("Passed: %d/%d tests" % [passed_count, test_count])

	if passed_count == test_count:
		print("✓ All tests passed!")
		print("\nManual verification steps:")
		print("1. Press ~ to toggle console visibility")
		print("2. Type some text and press Enter")
		print("3. Press Up arrow to see command history")
		print("4. Verify logs appear with color coding")
		print("5. Press ~ again to close console")
	else:
		print("✗ Some tests failed")

	# Keep console around for manual testing
	if console:
		add_child(console)


func test_console_creation() -> void:
	test_count += 1
	print("Test 1: Console creation...")

	console = DevConsoleScript.new()

	if console != null:
		print("  ✓ Console created successfully")
		passed_count += 1
	else:
		print("  ✗ Failed to create console")


func test_console_visibility() -> void:
	test_count += 1
	print("Test 2: Console visibility toggle...")

	if not console:
		print("  ✗ Console not available")
		return

	var initial_visible = console.is_console_visible
	console.toggle_visibility()
	var after_toggle = console.is_console_visible

	if initial_visible != after_toggle:
		print("  ✓ Visibility toggles correctly")
		passed_count += 1
	else:
		print("  ✗ Visibility did not toggle")


func test_log_display() -> void:
	test_count += 1
	print("Test 3: Log display...")

	if not console:
		print("  ✗ Console not available")
		return

	# Add console to tree so it can receive signals
	add_child(console)
	await get_tree().process_frame

	# Make console visible
	console.toggle_visibility()
	await get_tree().process_frame

	# Add a test log
	var log_router = get_node_or_null("/root/LogRouter")
	if log_router:
		log_router.log("Test log message", LogRouter.LogLevel.INFO, "test")
		await get_tree().process_frame

		print("  ✓ Log added (check console display)")
		passed_count += 1
	else:
		print("  ✗ LogRouter not found")

	# Remove from tree for now
	remove_child(console)


func test_command_history() -> void:
	test_count += 1
	print("Test 4: Command history...")

	if not console:
		print("  ✗ Console not available")
		return

	# Simulate adding commands to history
	console._add_to_history("test command 1")
	console._add_to_history("test command 2")
	console._add_to_history("test command 3")

	var history = console.get_command_history()

	if history.size() == 3 and history[0] == "test command 1":
		print("  ✓ Command history works correctly")
		passed_count += 1
	else:
		print("  ✗ Command history failed (size: %d)" % history.size())


func test_auto_scroll() -> void:
	test_count += 1
	print("Test 5: Auto-scroll setting...")

	if not console:
		print("  ✗ Console not available")
		return

	console.set_auto_scroll(false)
	if not console.auto_scroll:
		console.set_auto_scroll(true)
		if console.auto_scroll:
			print("  ✓ Auto-scroll setting works")
			passed_count += 1
		else:
			print("  ✗ Auto-scroll enable failed")
	else:
		print("  ✗ Auto-scroll disable failed")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("\nTest ended by user")
			get_tree().quit()
