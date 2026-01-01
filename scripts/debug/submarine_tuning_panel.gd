extends CanvasLayer
## Debug panel for tuning submarine physics parameters in real-time
## Press F4 to toggle visibility

var submarine_physics: Node
var panel_container: PanelContainer
var sliders: Dictionary = {}
var value_labels: Dictionary = {}

# Parameter definitions: [min, max, step, default]
var parameters = {
	"mass": [1000.0, 20000.0, 100.0, 8000.0],
	"max_speed": [5.0, 25.0, 0.1, 10.3],
	"max_depth": [100.0, 800.0, 10.0, 400.0],
	"propulsion_force_max": [10000000.0, 100000000.0, 1000000.0, 35000000.0],
	"forward_drag": [500.0, 10000.0, 100.0, 2000.0],
	"sideways_drag": [100000.0, 2000000.0, 10000.0, 800000.0],
	"rudder_effectiveness": [50000.0, 500000.0, 10000.0, 250000.0],
	"stabilizer_effectiveness": [1000.0, 50000.0, 1000.0, 10000.0],
	"mid_stabilizer_effectiveness": [50000.0, 500000.0, 10000.0, 250000.0],
	"ballast_force_max": [10000000.0, 100000000.0, 1000000.0, 50000000.0],
	"submarine_volume": [2000.0, 20000.0, 100.0, 8000.0]
}

func _ready() -> void:
	# Find submarine physics (retry a few times as it's initialized async)
	var main_node = get_parent()
	for i in range(20): # Try for 10 seconds
		submarine_physics = main_node.get_node_or_null("SubmarinePhysics")
		if submarine_physics:
			print("SubmarineTuningPanel: Found SubmarinePhysics")
			break
		await get_tree().create_timer(0.5).timeout
	
	if not submarine_physics:
		push_error("SubmarineTuningPanel: SubmarinePhysics not found after waiting")
		return
	
	# Create UI
	_create_ui()
	
	# Start hidden
	visible = false
	
	# Set process mode to always process input
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	print("SubmarineTuningPanel: Ready (Press F5 to toggle)")
	print("SubmarineTuningPanel: Node path = ", get_path())

func _create_ui() -> void:
	# Create main panel container (positioned on the right side)
	panel_container = PanelContainer.new()
	panel_container.name = "TuningPanel"
	panel_container.position = Vector2(1500, 20)  # Right side of 1920x1080 screen
	panel_container.custom_minimum_size = Vector2(400, 700)
	add_child(panel_container)
	
	# Create scroll container
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 680)
	panel_container.add_child(scroll)
	
	# Create main VBox
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(360, 0)
	scroll.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "SUBMARINE PHYSICS TUNING"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Add separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Create sliders for each parameter
	for param_name in parameters.keys():
		var param_data = parameters[param_name]
		_create_parameter_slider(vbox, param_name, param_data[0], param_data[1], param_data[2], param_data[3])
	
	# Add separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Buttons container
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)
	
	# Dump config button
	var dump_button = Button.new()
	dump_button.text = "Dump Config to Console"
	dump_button.custom_minimum_size = Vector2(180, 40)
	dump_button.pressed.connect(_on_dump_config)
	button_hbox.add_child(dump_button)
	
	# Reset button
	var reset_button = Button.new()
	reset_button.text = "Reset to Defaults"
	reset_button.custom_minimum_size = Vector2(150, 40)
	reset_button.pressed.connect(_on_reset_defaults)
	button_hbox.add_child(reset_button)

func _create_parameter_slider(parent: VBoxContainer, param_name: String, min_val: float, max_val: float, step: float, default_val: float) -> void:
	# Parameter container
	var param_vbox = VBoxContainer.new()
	parent.add_child(param_vbox)
	
	# Label with current value
	var label = Label.new()
	label.text = "%s: %.2f" % [param_name.replace("_", " ").capitalize(), default_val]
	param_vbox.add_child(label)
	value_labels[param_name] = label
	
	# Slider
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.custom_minimum_size = Vector2(340, 30)
	slider.value_changed.connect(_on_slider_changed.bind(param_name))
	param_vbox.add_child(slider)
	sliders[param_name] = slider
	
	# Min/Max labels
	var minmax_hbox = HBoxContainer.new()
	var min_label = Label.new()
	min_label.text = "%.0f" % min_val
	min_label.add_theme_font_size_override("font_size", 10)
	minmax_hbox.add_child(min_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minmax_hbox.add_child(spacer)
	
	var max_label = Label.new()
	max_label.text = "%.0f" % max_val
	max_label.add_theme_font_size_override("font_size", 10)
	minmax_hbox.add_child(max_label)
	
	param_vbox.add_child(minmax_hbox)

func _on_slider_changed(value: float, param_name: String) -> void:
	# Update label
	value_labels[param_name].text = "%s: %.2f" % [param_name.replace("_", " ").capitalize(), value]
	
	# Update submarine physics
	if submarine_physics:
		submarine_physics.set(param_name, value)
		
		# Special case: update mass on rigid body
		if param_name == "mass" and submarine_physics.submarine_body:
			submarine_physics.submarine_body.mass = value * 1000.0

func _on_dump_config() -> void:
	print("\n========== SUBMARINE CONFIGURATION ==========")
	print("submarine_physics.configure_submarine_class({")
	print("    \"class_name\": \"Custom Tuned\",")
	
	for param_name in parameters.keys():
		var value = sliders[param_name].value
		print("    \"%s\": %.2f," % [param_name, value])
	
	print("})")
	print("=============================================\n")

func _on_reset_defaults() -> void:
	for param_name in parameters.keys():
		var default_val = parameters[param_name][3]
		sliders[param_name].value = default_val
		_on_slider_changed(default_val, param_name)
	
	print("SubmarineTuningPanel: Reset to default values")

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F5:
				visible = not visible
				print("SubmarineTuningPanel: F5 pressed - ", "Visible" if visible else "Hidden")
