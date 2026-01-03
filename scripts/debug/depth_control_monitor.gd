extends Node
## Debug monitor for submarine depth control
## Displays real-time depth control metrics and logs oscillation behavior

var simulation_state: SimulationState
var submarine_physics: SubmarinePhysics
var submarine_body: RigidBody3D

# Monitoring data
var depth_history: Array[float] = []
var time_history: Array[float] = []
var velocity_history: Array[float] = []

var current_time: float = 0.0
var sample_interval: float = 0.1  # Sample every 100ms
var last_sample_time: float = 0.0

var max_samples: int = 1200  # Keep 2 minutes of data at 100ms intervals

# Oscillation detection
var oscillation_count: int = 0
var last_error_sign: float = 0.0

# UI
var label: Label


func _ready() -> void:
	# Find required nodes
	simulation_state = get_node_or_null("/root/Main/SimulationState")
	submarine_physics = get_node_or_null("/root/Main/SubmarinePhysics")
	submarine_body = get_node_or_null("/root/Main/SubmarineModel")

	if not simulation_state or not submarine_body:
		push_warning("DepthControlMonitor: Could not find required nodes, will retry...")
		# Try again after scene is fully loaded
		call_deferred("_find_nodes")
		return

	_setup_ui()


func _find_nodes() -> void:
	simulation_state = get_node_or_null("/root/Main/SimulationState")
	submarine_body = get_node_or_null("/root/Main/SubmarineModel")

	if simulation_state and submarine_body:
		_setup_ui()
	else:
		push_error("DepthControlMonitor: Could not find required nodes")


func _setup_ui() -> void:
	# Create UI label
	label = Label.new()
	label.position = Vector2(10, 100)
	label.add_theme_font_size_override("font_size", 14)
	get_tree().root.add_child(label)

	print("\n=== Depth Control Monitor Started ===")
	print("Monitoring submarine depth control behavior...")
	print("Press ESC to export data to user://depth_control_log.csv")


func _process(delta: float) -> void:
	current_time += delta

	# Sample data
	if current_time - last_sample_time >= sample_interval:
		_sample_data()
		last_sample_time = current_time

	# Update UI
	_update_display()

	# Export data on ESC
	if Input.is_action_just_pressed("ui_cancel"):
		_export_data()


func _sample_data() -> void:
	if not submarine_body or not simulation_state:
		return

	var depth = -submarine_body.global_position.y
	var velocity = submarine_body.linear_velocity.y
	var target = simulation_state.target_depth
	var error = target - depth

	# Detect oscillation (zero crossing)
	if depth_history.size() > 0:
		var current_sign = sign(error)
		if current_sign != last_error_sign and abs(error) > 1.0:
			oscillation_count += 1
			print(
				(
					"Oscillation detected at t=%.2fs, depth=%.2fm, target=%.2fm"
					% [current_time, depth, target]
				)
			)
		last_error_sign = current_sign

	# Store data
	depth_history.append(depth)
	velocity_history.append(velocity)
	time_history.append(current_time)

	# Limit history size
	if depth_history.size() > max_samples:
		depth_history.pop_front()
		velocity_history.pop_front()
		time_history.pop_front()


func _update_display() -> void:
	if not label or not submarine_body or not simulation_state:
		return

	var depth = -submarine_body.global_position.y
	var velocity = submarine_body.linear_velocity.y
	var target = simulation_state.target_depth
	var error = target - depth

	# Calculate statistics
	var avg_depth = 0.0
	var max_depth = 0.0
	var min_depth = 999999.0

	if depth_history.size() > 0:
		for d in depth_history:
			avg_depth += d
			max_depth = max(max_depth, d)
			min_depth = min(min_depth, d)
		avg_depth /= depth_history.size()

	var text = "=== DEPTH CONTROL MONITOR ===\n"
	text += "Time: %.1fs\n" % current_time
	text += "\n"
	text += "Current Depth: %.2fm\n" % depth
	text += "Target Depth: %.2fm\n" % target
	text += "Error: %.2fm\n" % error
	text += "Vertical Velocity: %.2f m/s\n" % velocity
	text += "\n"
	text += "Statistics (last %.0fs):\n" % (depth_history.size() * sample_interval)
	text += "  Avg Depth: %.2fm\n" % avg_depth
	text += "  Max Depth: %.2fm\n" % max_depth
	text += "  Min Depth: %.2fm\n" % min_depth
	text += "  Oscillations: %d\n" % oscillation_count
	text += "\n"
	text += "Press ESC to export data"

	label.text = text


func _export_data() -> void:
	var file = FileAccess.open("user://depth_control_log.csv", FileAccess.WRITE)
	if not file:
		push_error("Could not open file for writing")
		return

	# Write header
	file.store_line("Time,Depth,Velocity,Target,Error")

	# Write data
	for i in range(depth_history.size()):
		var target = simulation_state.target_depth
		var error = target - depth_history[i]
		file.store_line(
			(
				"%.3f,%.3f,%.3f,%.3f,%.3f"
				% [time_history[i], depth_history[i], velocity_history[i], target, error]
			)
		)

	file.close()

	var path = ProjectSettings.globalize_path("user://depth_control_log.csv")
	print("\n=== Data exported to: %s ===" % path)
	print("Total samples: %d" % depth_history.size())
	if time_history.size() > 1:
		print("Duration: %.1fs" % (time_history[-1] - time_history[0]))
	print("Oscillations detected: %d" % oscillation_count)
