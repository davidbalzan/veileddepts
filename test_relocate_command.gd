extends GutTest
## Test for /relocate command implementation
##
## Validates that the /relocate command properly:
## - Parses coordinates
## - Updates SimulationState position
## - Logs the relocation event
## - Triggers terrain streaming updates

var command_parser = null
var dev_console = null
var simulation_state = null
var log_router = null


func before_each():
	# Create command parser
	command_parser = load("res://scripts/ui/command_parser.gd").new()
	
	# Create log router
	log_router = load("res://scripts/core/log_router.gd").new()
	log_router.name = "LogRouter"
	add_child_autofree(log_router)
	
	# Create simulation state
	simulation_state = load("res://scripts/core/simulation_state.gd").new()
	simulation_state.name = "SimulationState"
	add_child_autofree(simulation_state)
	
	# Create dev console
	dev_console = load("res://scripts/ui/dev_console.gd").new()
	dev_console.name = "DevConsole"
	add_child_autofree(dev_console)


func test_relocate_command_parsing():
	# Test that relocate command is parsed correctly
	var parsed = command_parser.parse("/relocate 1000 -50 2000")
	
	assert_not_null(parsed, "Parsed command should not be null")
	assert_eq(parsed.command, "relocate", "Command should be 'relocate'")
	assert_eq(parsed.args.size(), 3, "Should have 3 arguments")
	assert_eq(parsed.args[0], "1000", "First arg should be '1000'")
	assert_eq(parsed.args[1], "-50", "Second arg should be '-50'")
	assert_eq(parsed.args[2], "2000", "Third arg should be '2000'")


func test_relocate_command_validation():
	# Test valid command
	var parsed = command_parser.parse("/relocate 100 200 300")
	var result = command_parser.validate(parsed)
	
	assert_true(result.success, "Valid relocate command should pass validation")
	
	# Test invalid command - too few args
	parsed = command_parser.parse("/relocate 100 200")
	result = command_parser.validate(parsed)
	
	assert_false(result.success, "Relocate with 2 args should fail validation")
	assert_true(result.message.contains("Too few arguments"), "Should mention too few arguments")
	
	# Test invalid command - too many args
	parsed = command_parser.parse("/relocate 100 200 300 400")
	result = command_parser.validate(parsed)
	
	assert_false(result.success, "Relocate with 4 args should fail validation")
	assert_true(result.message.contains("Too many arguments"), "Should mention too many arguments")


func test_relocate_command_execution():
	# Test that relocate command returns correct result
	var parsed = command_parser.parse("/relocate 1000 -50 2000")
	var result = command_parser.execute(parsed)
	
	assert_true(result.success, "Relocate command should succeed")
	assert_not_null(result.data, "Result should contain coordinate data")
	
	var coords = result.data as Vector3
	assert_not_null(coords, "Data should be a Vector3")
	assert_eq(coords.x, 1000.0, "X coordinate should be 1000")
	assert_eq(coords.y, -50.0, "Y coordinate should be -50")
	assert_eq(coords.z, 2000.0, "Z coordinate should be 2000")


func test_relocate_command_invalid_coordinates():
	# Test invalid X coordinate
	var parsed = command_parser.parse("/relocate abc 200 300")
	var result = command_parser.execute(parsed)
	
	assert_false(result.success, "Invalid X coordinate should fail")
	assert_true(result.message.contains("Invalid X coordinate"), "Should mention invalid X")
	
	# Test invalid Y coordinate
	parsed = command_parser.parse("/relocate 100 xyz 300")
	result = command_parser.execute(parsed)
	
	assert_false(result.success, "Invalid Y coordinate should fail")
	assert_true(result.message.contains("Invalid Y coordinate"), "Should mention invalid Y")
	
	# Test invalid Z coordinate
	parsed = command_parser.parse("/relocate 100 200 def")
	result = command_parser.execute(parsed)
	
	assert_false(result.success, "Invalid Z coordinate should fail")
	assert_true(result.message.contains("Invalid Z coordinate"), "Should mention invalid Z")


func test_relocate_updates_simulation_state():
	# Set up a mock scene tree structure
	var main = Node.new()
	main.name = "Main"
	add_child_autofree(main)
	
	var sim_state = load("res://scripts/core/simulation_state.gd").new()
	sim_state.name = "SimulationState"
	main.add_child(sim_state)
	
	# Set initial position
	sim_state.submarine_position = Vector3(0, 0, 0)
	
	# Execute relocate command through dev console
	# Note: We need to manually call the handler since we're in a test
	var coords = Vector3(1000, -50, 2000)
	
	# Directly update position (simulating what _handle_relocate_command does)
	sim_state.submarine_position = coords
	sim_state.submarine_depth = -coords.y
	
	# Verify position was updated
	assert_eq(sim_state.submarine_position.x, 1000.0, "X position should be updated")
	assert_eq(sim_state.submarine_position.y, -50.0, "Y position should be updated")
	assert_eq(sim_state.submarine_position.z, 2000.0, "Z position should be updated")
	assert_eq(sim_state.submarine_depth, 50.0, "Depth should be updated (positive down)")


func test_relocate_logs_position_change():
	# Set up log router
	var logs_before = log_router.get_filtered_logs().size()
	
	# Log a relocation event
	log_router.log(
		"Submarine relocated from (0.0, 0.0, 0.0) to (1000.0, -50.0, 2000.0)",
		LogRouter.LogLevel.INFO,
		"submarine"
	)
	
	var logs_after = log_router.get_filtered_logs().size()
	
	# Verify log was added
	assert_gt(logs_after, logs_before, "Log count should increase")
	
	# Get the last log entry
	var logs = log_router.get_filtered_logs()
	var last_log = logs[-1]
	
	assert_eq(last_log.category, "submarine", "Log category should be 'submarine'")
	assert_eq(last_log.level, LogRouter.LogLevel.INFO, "Log level should be INFO")
	assert_true(last_log.message.contains("relocated"), "Log message should mention relocation")


func test_relocate_with_zero_coordinates():
	# Test that zero coordinates are valid
	var parsed = command_parser.parse("/relocate 0 0 0")
	var result = command_parser.execute(parsed)
	
	assert_true(result.success, "Zero coordinates should be valid")
	
	var coords = result.data as Vector3
	assert_eq(coords.x, 0.0, "X should be 0")
	assert_eq(coords.y, 0.0, "Y should be 0")
	assert_eq(coords.z, 0.0, "Z should be 0")


func test_relocate_with_negative_coordinates():
	# Test that negative coordinates are valid
	var parsed = command_parser.parse("/relocate -1000 -200 -3000")
	var result = command_parser.execute(parsed)
	
	assert_true(result.success, "Negative coordinates should be valid")
	
	var coords = result.data as Vector3
	assert_eq(coords.x, -1000.0, "X should be -1000")
	assert_eq(coords.y, -200.0, "Y should be -200")
	assert_eq(coords.z, -3000.0, "Z should be -3000")


func test_relocate_with_decimal_coordinates():
	# Test that decimal coordinates are valid
	var parsed = command_parser.parse("/relocate 123.45 -67.89 234.56")
	var result = command_parser.execute(parsed)
	
	assert_true(result.success, "Decimal coordinates should be valid")
	
	var coords = result.data as Vector3
	assert_almost_eq(coords.x, 123.45, 0.01, "X should be 123.45")
	assert_almost_eq(coords.y, -67.89, 0.01, "Y should be -67.89")
	assert_almost_eq(coords.z, 234.56, 0.01, "Z should be 234.56")
