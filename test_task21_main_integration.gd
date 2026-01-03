extends SceneTree
## Task 21 Main Scene Integration Test
##
## Verifies that DevConsole and systems are properly integrated in main scene

func _init() -> void:
	print("\n=== Task 21 Main Scene Integration Test ===\n")
	
	# Load the main scene
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		print("✗ Failed to load main scene")
		quit(1)
		return
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	# Wait for initialization
	await create_timer(0.5).timeout
	
	var all_passed = true
	
	# Test 1: Verify LogRouter autoload exists
	print("Test 1: Checking LogRouter autoload...")
	var log_router = root.get_node_or_null("/root/LogRouter")
	if log_router:
		print("  ✓ LogRouter autoload found")
	else:
		print("  ✗ LogRouter autoload NOT found")
		all_passed = false
	
	# Test 2: Verify DebugPanelManager autoload exists
	print("\nTest 2: Checking DebugPanelManager autoload...")
	var debug_panel_manager = root.get_node_or_null("/root/DebugPanelManager")
	if debug_panel_manager:
		print("  ✓ DebugPanelManager autoload found")
	else:
		print("  ✗ DebugPanelManager autoload NOT found")
		all_passed = false
	
	# Test 3: Verify DevConsole exists in main scene
	print("\nTest 3: Checking DevConsole in main scene...")
	var dev_console = main.get_node_or_null("DevConsole")
	if dev_console:
		print("  ✓ DevConsole found in main scene")
		print("    - Type: ", dev_console.get_class())
		print("    - Layer: ", dev_console.layer)
		
		# Check if it's a CanvasLayer with layer 10
		if dev_console is CanvasLayer:
			print("    - Is CanvasLayer: ✓")
			if dev_console.layer == 10:
				print("    - Layer is 10: ✓")
			else:
				print("    - Layer is NOT 10: ✗ (actual: ", dev_console.layer, ")")
				all_passed = false
		else:
			print("    - Is NOT CanvasLayer: ✗")
			all_passed = false
	else:
		print("  ✗ DevConsole NOT found in main scene")
		all_passed = false
	
	# Test 4: Verify DevConsole has references to autoloads
	print("\nTest 4: Checking DevConsole references...")
	if dev_console:
		# Wait for _ready to complete
		await create_timer(0.2).timeout
		
		# Check if DevConsole can access LogRouter
		var has_log_router = dev_console.get("_log_router") != null
		if has_log_router:
			print("  ✓ DevConsole has LogRouter reference")
		else:
			print("  ✗ DevConsole does NOT have LogRouter reference")
			all_passed = false
		
		# Check if DevConsole can access DebugPanelManager
		var has_debug_manager = dev_console.get("_debug_panel_manager") != null
		if has_debug_manager:
			print("  ✓ DevConsole has DebugPanelManager reference")
		else:
			print("  ✗ DevConsole does NOT have DebugPanelManager reference")
			all_passed = false
	
	# Test 5: Verify signals are connected
	print("\nTest 5: Checking signal connections...")
	if log_router and dev_console:
		# Check if log_added signal is connected
		var log_added_connections = log_router.get_signal_connection_list("log_added")
		var has_log_connection = false
		for connection in log_added_connections:
			if connection["callable"].get_object() == dev_console:
				has_log_connection = true
				break
		
		if has_log_connection:
			print("  ✓ DevConsole connected to LogRouter.log_added signal")
		else:
			print("  ✗ DevConsole NOT connected to LogRouter.log_added signal")
			all_passed = false
	
	# Test 6: Test basic functionality - log a message
	print("\nTest 6: Testing basic logging functionality...")
	if log_router:
		log_router.log("Test message from Task 21 integration test", LogRouter.LogLevel.INFO, "test")
		print("  ✓ Log message sent successfully")
	
	# Test 7: Verify ViewInputHandler (should not exist yet - task 14)
	print("\nTest 7: Checking ViewInputHandler (expected to not exist)...")
	var view_input_handler = main.get_node_or_null("ViewInputHandler")
	if view_input_handler:
		print("  ⚠ ViewInputHandler found (task 14 must have been completed)")
	else:
		print("  ✓ ViewInputHandler not found (as expected - task 14 not yet implemented)")
	
	# Summary
	print("\n=== Test Summary ===")
	if all_passed:
		print("✓ All integration tests PASSED")
		print("\nTask 21 is COMPLETE:")
		print("  - LogRouter autoload: ✓")
		print("  - DebugPanelManager autoload: ✓")
		print("  - DevConsole in main.tscn: ✓")
		print("  - All references wired up: ✓")
		print("  - Signals connected: ✓")
		print("\nNote: ViewInputHandler will be added in task 14")
	else:
		print("✗ Some integration tests FAILED")
		print("Please review the failures above")
	
	print("\n=== Test Complete ===\n")
	
	# Exit
	quit(0 if all_passed else 1)
