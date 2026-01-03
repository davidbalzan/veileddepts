extends SceneTree
## Simple test for console commands

func _init() -> void:
	print("\n=== Simple Console Commands Test ===\n")
	
	# Test CommandParser directly
	var CommandParserScript = preload("res://scripts/ui/command_parser.gd")
	var parser = CommandParserScript.new()
	
	print("Test 1: Parse /help command")
	var parsed = parser.parse("/help")
	if parsed and parsed.command == "help":
		print("  ✓ Parsed correctly")
	else:
		print("  ✗ Parse failed")
	
	print("\nTest 2: Execute /help command")
	var result = parser.execute(parsed)
	if result.success:
		print("  ✓ Executed successfully")
		print("  Result: " + result.message.substr(0, 50) + "...")
	else:
		print("  ✗ Execution failed: " + result.message)
	
	print("\nTest 3: Parse /log warning command")
	parsed = parser.parse("/log warning")
	if parsed and parsed.command == "log" and parsed.args.size() == 1:
		print("  ✓ Parsed correctly")
	else:
		print("  ✗ Parse failed")
	
	print("\nTest 4: Execute /log warning command")
	result = parser.execute(parsed)
	if result.success:
		print("  ✓ Executed successfully")
		print("  Result: " + result.message)
	else:
		print("  ✗ Execution failed: " + result.message)
	
	print("\nTest 5: Parse /filter warnings off command")
	parsed = parser.parse("/filter warnings off")
	if parsed and parsed.command == "filter" and parsed.args.size() == 2:
		print("  ✓ Parsed correctly")
	else:
		print("  ✗ Parse failed")
	
	print("\nTest 6: Execute /filter warnings off command")
	result = parser.execute(parsed)
	if result.success:
		print("  ✓ Executed successfully")
		print("  Result: " + result.message)
	else:
		print("  ✗ Execution failed: " + result.message)
	
	print("\nTest 7: Invalid command")
	parsed = parser.parse("/invalidcmd")
	result = parser.execute(parsed)
	if not result.success:
		print("  ✓ Invalid command rejected correctly")
		print("  Error: " + result.message.split("\n")[0])
	else:
		print("  ✗ Invalid command should have failed")
	
	print("\n=== All tests completed ===\n")
	quit()
