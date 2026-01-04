extends SceneTree
## Test DevConsole integration with commands

var console
var log_router
var initialized = false

func _init() -> void:
	print("\n=== DevConsole Integration Test ===\n")


func _process(_delta: float) -> bool:
	if not initialized:
		# Try to get LogRouter
		log_router = get_root().get_node_or_null("LogRouter")
		if not log_router:
			return true  # Keep processing
		
		print("✓ LogRouter found")
		
		# Create DevConsole
		var DevConsoleScript = preload("res://scripts/ui/dev_console.gd")
		console = DevConsoleScript.new()
		get_root().add_child(console)
		
		print("✓ DevConsole created")
		
		# Make console visible
		console.toggle_visibility()
		
		print("✓ Console toggled visible")
		
		# Run tests
		run_tests()
		
		initialized = true
	
	return true


func run_tests() -> void:
	# Test /help command
	print("\nTest 1: /help command")
	console._execute_command("/help")
	print("  ✓ /help executed")
	
	# Test /log command
	print("\nTest 2: /log warning command")
	var level_before = log_router.get_min_level()
	console._execute_command("/log warning")
	var level_after = log_router.get_min_level()
	if level_after == 2:  # WARNING level
		print("  ✓ Log level changed to WARNING")
	else:
		print("  ✗ Log level not changed (before: %d, after: %d)" % [level_before, level_after])
	
	# Reset log level
	log_router.set_min_level(0)  # DEBUG
	
	# Test /filter command
	print("\nTest 3: /filter warnings off command")
	console._execute_command("/filter warnings off")
	if log_router.get_hide_warnings():
		print("  ✓ Warnings filter enabled")
	else:
		print("  ✗ Warnings filter not enabled")
	
	# Test /filter reset
	print("\nTest 4: /filter reset command")
	console._execute_command("/filter reset")
	if not log_router.get_hide_warnings():
		print("  ✓ Filters reset")
	else:
		print("  ✗ Filters not reset")
	
	# Test /clear command
	print("\nTest 5: /clear command")
	log_router.log("Test message 1", 1, "test")
	log_router.log("Test message 2", 1, "test")
	var size_before = log_router.get_buffer_size()
	console._execute_command("/clear")
	var size_after = log_router.get_buffer_size()
	if size_after < size_before:
		print("  ✓ Logs cleared (before: %d, after: %d)" % [size_before, size_after])
	else:
		print("  ✗ Logs not cleared (before: %d, after: %d)" % [size_before, size_after])
	
	# Test /history command
	print("\nTest 6: /history command")
	console._add_to_history("/help")
	console._add_to_history("/clear")
	console._execute_command("/history")
	print("  ✓ /history executed")
	
	print("\n=== All integration tests completed ===\n")
	quit()
