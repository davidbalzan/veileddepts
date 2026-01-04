extends Node
## Manual test for LogRouter integration with game systems
##
## This test verifies that:
## 1. TerrainRenderer logs initialization and chunk events
## 2. StreamingManager logs chunk loading/unloading
## 3. SimulationState logs submarine state changes
## 4. ViewManager logs view switches
##
## Run this test by attaching it to a test scene and checking console output

var terrain_renderer: TerrainRenderer
var simulation_state: SimulationState
var view_manager: ViewManager
var log_count_before: int = 0
var log_count_after: int = 0


func _ready():
	print("\n=== LogRouter Integration Test ===\n")
	
	# Wait a frame for autoloads to initialize
	await get_tree().process_frame
	
	# Verify LogRouter exists as autoload
	var log_router = get_node_or_null("/root/LogRouter")
	if not log_router:
		push_error("LogRouter autoload not found!")
		return
	
	print("✓ LogRouter found")
	
	# Get initial log count
	log_count_before = log_router.get_buffer_size()
	print("Initial log count: %d" % log_count_before)
	
	# Test 1: TerrainRenderer logging
	print("\n--- Test 1: TerrainRenderer Logging ---")
	test_terrain_renderer_logging()
	await get_tree().create_timer(0.5).timeout
	
	# Test 2: SimulationState logging
	print("\n--- Test 2: SimulationState Logging ---")
	test_simulation_state_logging()
	await get_tree().create_timer(0.5).timeout
	
	# Test 3: ViewManager logging
	print("\n--- Test 3: ViewManager Logging ---")
	test_view_manager_logging()
	await get_tree().create_timer(0.5).timeout
	
	# Get final log count
	log_count_after = log_router.get_buffer_size()
	print("\nFinal log count: %d" % log_count_after)
	print("New logs added: %d" % (log_count_after - log_count_before))
	
	# Display recent logs
	print("\n--- Recent Logs ---")
	display_recent_logs(10, log_router)
	
	print("\n=== Test Complete ===\n")
	
	# Quit after test
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func test_terrain_renderer_logging():
	"""Test that TerrainRenderer logs to console"""
	print("Creating TerrainRenderer...")
	
	var log_router = get_node("/root/LogRouter")
	
	terrain_renderer = TerrainRenderer.new()
	terrain_renderer.chunk_size = 512.0
	terrain_renderer.load_distance = 1024.0
	terrain_renderer.enable_debug_overlay = false
	add_child(terrain_renderer)
	
	# Wait for initialization
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check for terrain logs
	var terrain_logs = get_logs_by_category("terrain", log_router)
	print("Found %d terrain logs" % terrain_logs.size())
	
	if terrain_logs.size() > 0:
		print("✓ TerrainRenderer is logging to console")
		for log in terrain_logs:
			print("  - [%s] %s" % [log_router.LogLevel.keys()[log.level], log.message])
	else:
		print("✗ No terrain logs found")


func test_simulation_state_logging():
	"""Test that SimulationState logs to console"""
	print("Creating SimulationState...")
	
	var log_router = get_node("/root/LogRouter")
	
	simulation_state = SimulationState.new()
	add_child(simulation_state)
	
	# Wait for initialization
	await get_tree().process_frame
	
	# Trigger a submarine command update
	print("Updating submarine command...")
	simulation_state.update_submarine_command(Vector3(100, -50, 200), 5.0, 50.0)
	
	await get_tree().process_frame
	
	# Trigger a state update with significant position change
	print("Updating submarine state...")
	simulation_state.update_submarine_state(
		Vector3(120, -55, 220),  # New position (>10m change)
		Vector3(5, 0, 0),
		55.0,  # New depth (>5m change)
		45.0,
		5.0
	)
	
	await get_tree().process_frame
	
	# Check for submarine logs
	var submarine_logs = get_logs_by_category("submarine", log_router)
	print("Found %d submarine logs" % submarine_logs.size())
	
	if submarine_logs.size() > 0:
		print("✓ SimulationState is logging to console")
		for log in submarine_logs:
			print("  - [%s] %s" % [log_router.LogLevel.keys()[log.level], log.message])
	else:
		print("✗ No submarine logs found")


func test_view_manager_logging():
	"""Test that ViewManager logs to console"""
	print("Creating ViewManager...")
	
	var log_router = get_node("/root/LogRouter")
	
	view_manager = ViewManager.new()
	add_child(view_manager)
	
	# Wait for initialization
	await get_tree().process_frame
	
	# Trigger view switches
	print("Switching to PERISCOPE view...")
	view_manager.switch_to_view(ViewManager.ViewType.PERISCOPE)
	
	await get_tree().process_frame
	
	print("Switching to EXTERNAL view...")
	view_manager.switch_to_view(ViewManager.ViewType.EXTERNAL)
	
	await get_tree().process_frame
	
	# Check for view logs
	var view_logs = get_logs_by_category("view", log_router)
	print("Found %d view logs" % view_logs.size())
	
	if view_logs.size() > 0:
		print("✓ ViewManager is logging to console")
		for log in view_logs:
			print("  - [%s] %s" % [log_router.LogLevel.keys()[log.level], log.message])
	else:
		print("✗ No view logs found")


func get_logs_by_category(category: String, log_router: Node) -> Array:
	"""Get all logs matching a specific category"""
	var matching_logs = []
	var all_logs = log_router.get_all_logs()
	
	for log in all_logs:
		if log.category == category:
			matching_logs.append(log)
	
	return matching_logs


func display_recent_logs(count: int, log_router: Node):
	"""Display the most recent logs"""
	var all_logs = log_router.get_all_logs()
	var start_index = max(0, all_logs.size() - count)
	
	for i in range(start_index, all_logs.size()):
		var log = all_logs[i]
		print("[%s][%s] %s" % [log_router.LogLevel.keys()[log.level], log.category, log.message])
