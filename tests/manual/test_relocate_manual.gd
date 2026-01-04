extends Node
## Manual test for /relocate command
##
## This script demonstrates the /relocate command functionality.
## Run the game and press F6 to execute the relocate command.

var dev_console: DevConsole = null
var simulation_state: SimulationState = null


func _ready():
	print("\n=== Relocate Command Manual Test ===")
	print("Press F6 to test the /relocate command")
	print("Press F7 to check submarine position")
	print("Press F8 to relocate to a far location")
	print("=====================================\n")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	# Find DevConsole
	dev_console = get_node_or_null("/root/Main/DevConsole")
	if not dev_console:
		print("ERROR: DevConsole not found!")
		return
	
	# Find SimulationState
	simulation_state = get_node_or_null("/root/Main/SimulationState")
	if not simulation_state:
		print("ERROR: SimulationState not found!")
		return
	
	print("Manual test ready!")
	print("Current submarine position: ", simulation_state.submarine_position)


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			test_relocate_basic()
		elif event.keycode == KEY_F7:
			check_position()
		elif event.keycode == KEY_F8:
			test_relocate_far()


func test_relocate_basic():
	print("\n--- Testing basic relocate ---")
	print("Current position: ", simulation_state.submarine_position)
	
	# Simulate typing the command
	var command = "/relocate 1000 -50 2000"
	print("Executing command: ", command)
	
	# Execute through dev console (simulating user input)
	if dev_console:
		dev_console._on_command_submitted(command)
	
	# Wait a frame for the command to process
	await get_tree().process_frame
	
	print("New position: ", simulation_state.submarine_position)
	print("Expected: (1000, -50, 2000)")
	
	# Verify
	if simulation_state.submarine_position.is_equal_approx(Vector3(1000, -50, 2000)):
		print("✓ Relocate successful!")
	else:
		print("✗ Relocate failed - position mismatch")


func check_position():
	print("\n--- Current Submarine Position ---")
	print("Position: ", simulation_state.submarine_position)
	print("Depth: ", simulation_state.submarine_depth, " meters")
	print("Heading: ", simulation_state.submarine_heading, " degrees")
	print("Speed: ", simulation_state.submarine_speed, " m/s")


func test_relocate_far():
	print("\n--- Testing far relocate ---")
	print("Current position: ", simulation_state.submarine_position)
	
	# Relocate to a far location
	var command = "/relocate 5000 -100 -3000"
	print("Executing command: ", command)
	
	if dev_console:
		dev_console._on_command_submitted(command)
	
	await get_tree().process_frame
	
	print("New position: ", simulation_state.submarine_position)
	print("Expected: (5000, -100, -3000)")
	
	# Verify
	if simulation_state.submarine_position.is_equal_approx(Vector3(5000, -100, -3000)):
		print("✓ Far relocate successful!")
	else:
		print("✗ Far relocate failed - position mismatch")
