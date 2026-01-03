extends Node
## Manual test for DebugPanelManager integration with DevConsole

func _ready():
	print("\n=== Testing DebugPanelManager Integration ===\n")
	
	# Get references
	var log_router = get_node("/root/LogRouter")
	var debug_panel_manager = get_node("/root/DebugPanelManager")
	
	# Create console
	var console = DevConsole.new()
	add_child(console)
	
	# Wait for console to initialize
	await get_tree().process_frame
	
	print("1. Testing /debug on command...")
	console._execute_command("/debug on")
	await get_tree().process_frame
	
	if debug_panel_manager.is_debug_enabled():
		print("✓ Debug mode enabled successfully")
	else:
		print("✗ FAILED: Debug mode not enabled")
	
	# Check header
	if "Debug: ON" in console._header_label.text:
		print("✓ Console header shows Debug: ON")
	else:
		print("✗ FAILED: Console header doesn't show Debug: ON")
		print("  Header text: " + console._header_label.text)
	
	print("\n2. Testing /debug off command...")
	console._execute_command("/debug off")
	await get_tree().process_frame
	
	if not debug_panel_manager.is_debug_enabled():
		print("✓ Debug mode disabled successfully")
	else:
		print("✗ FAILED: Debug mode still enabled")
	
	# Check header
	if "Debug: OFF" in console._header_label.text:
		print("✓ Console header shows Debug: OFF")
	else:
		print("✗ FAILED: Console header doesn't show Debug: OFF")
		print("  Header text: " + console._header_label.text)
	
	print("\n3. Testing /debug terrain command...")
	# Register a mock terrain panel
	var mock_terrain = CanvasLayer.new()
	mock_terrain.visible = false
	add_child(mock_terrain)
	debug_panel_manager.register_panel("terrain", mock_terrain)
	
	console._execute_command("/debug terrain")
	await get_tree().process_frame
	
	if debug_panel_manager.is_panel_visible("terrain"):
		print("✓ Terrain panel toggled to visible")
	else:
		print("✗ FAILED: Terrain panel not visible")
	
	# Toggle again
	console._execute_command("/debug terrain")
	await get_tree().process_frame
	
	if not debug_panel_manager.is_panel_visible("terrain"):
		print("✓ Terrain panel toggled to hidden")
	else:
		print("✗ FAILED: Terrain panel still visible")
	
	print("\n4. Testing /debug performance command...")
	# Register a mock performance panel
	var mock_performance = CanvasLayer.new()
	mock_performance.visible = false
	add_child(mock_performance)
	debug_panel_manager.register_panel("performance", mock_performance)
	
	console._execute_command("/debug performance")
	await get_tree().process_frame
	
	if debug_panel_manager.is_panel_visible("performance"):
		print("✓ Performance panel toggled to visible")
	else:
		print("✗ FAILED: Performance panel not visible")
	
	print("\n5. Testing header updates on debug mode change...")
	debug_panel_manager.enable_all()
	await get_tree().process_frame
	
	if "Debug: ON" in console._header_label.text:
		print("✓ Header updated to Debug: ON")
	else:
		print("✗ FAILED: Header not updated")
		print("  Header text: " + console._header_label.text)
	
	debug_panel_manager.disable_all()
	await get_tree().process_frame
	
	if "Debug: OFF" in console._header_label.text:
		print("✓ Header updated to Debug: OFF")
	else:
		print("✗ FAILED: Header not updated")
		print("  Header text: " + console._header_label.text)
	
	print("\n=== All Tests Complete ===\n")
	
	# Quit after tests
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
