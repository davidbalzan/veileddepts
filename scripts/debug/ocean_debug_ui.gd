class_name OceanDebugUI extends CanvasLayer
## Debug UI for tweaking ocean parameters in real-time
## Press F3 to toggle visibility

var ocean_renderer: OceanRenderer
var atmosphere_renderer: AtmosphereRenderer
var panel: PanelContainer
var visible_state: bool = false

func _ready() -> void:
	# Defer UI creation to ensure all nodes are ready
	call_deferred("_deferred_setup")

func _deferred_setup() -> void:
	# Find the ocean renderer in the scene
	_find_ocean_renderer()
	_find_atmosphere_renderer()
	_create_ui()
	panel.visible = visible_state

func _find_ocean_renderer() -> void:
	# Search for OceanRenderer in the scene tree
	var nodes = get_tree().get_nodes_in_group("ocean_renderer")
	if nodes.size() > 0:
		ocean_renderer = nodes[0]
	else:
		# Try to find it by class
		ocean_renderer = _find_node_by_class(get_tree().root, "OceanRenderer")

func _find_atmosphere_renderer() -> void:
	# Search for AtmosphereRenderer in the scene tree by group first
	var nodes = get_tree().get_nodes_in_group("atmosphere_renderer")
	if nodes.size() > 0:
		atmosphere_renderer = nodes[0]
		print("OceanDebugUI: Found AtmosphereRenderer via group")
	else:
		# Try to find it by class
		atmosphere_renderer = _find_node_by_class_atmosphere(get_tree().root)
		if atmosphere_renderer:
			print("OceanDebugUI: Found AtmosphereRenderer via class search")
		else:
			print("OceanDebugUI: WARNING - AtmosphereRenderer not found!")

func _find_node_by_class(node: Node, class_name_str: String) -> OceanRenderer:
	if node is OceanRenderer:
		return node
	for child in node.get_children():
		var result = _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null

func _find_node_by_class_atmosphere(node: Node) -> AtmosphereRenderer:
	if node is AtmosphereRenderer:
		return node
	for child in node.get_children():
		var result = _find_node_by_class_atmosphere(child)
		if result:
			return result
	return null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		visible_state = !visible_state
		panel.visible = visible_state

func _create_ui() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "Debug Panel (F3 to toggle)"
	title.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Get initial values from ocean renderer if available
	var init_choppiness = ocean_renderer.choppiness if ocean_renderer else 1.78
	var init_wind_speed = ocean_renderer.wind_speed if ocean_renderer else 9.02
	var init_jacobian = ocean_renderer.foam_jacobian_limit if ocean_renderer else 1.08
	var init_coverage = ocean_renderer.foam_coverage if ocean_renderer else 0.13
	var init_mix = ocean_renderer.foam_mix_strength if ocean_renderer else 1.86
	var init_diffuse = ocean_renderer.foam_diffuse_strength if ocean_renderer else 2.22
	var init_specular = ocean_renderer.specular_strength if ocean_renderer else 1.06
	var init_pbr = ocean_renderer.pbr_specular_strength if ocean_renderer else 0.93
	
	# Wave Settings
	_add_section_label(main_vbox, "Wave Settings")
	_add_slider(main_vbox, "Choppiness", 0.0, 5.0, init_choppiness, _on_choppiness_changed)
	_add_slider(main_vbox, "Wind Speed", 0.0, 50.0, init_wind_speed, _on_wind_speed_changed)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Foam Settings
	_add_section_label(main_vbox, "Foam Settings")
	_add_slider(main_vbox, "Jacobian Limit", 0.0, 2.0, init_jacobian, _on_foam_jacobian_changed)
	_add_slider(main_vbox, "Coverage", 0.0, 2.0, init_coverage, _on_foam_coverage_changed)
	_add_slider(main_vbox, "Mix Strength", 0.0, 5.0, init_mix, _on_foam_mix_changed)
	_add_slider(main_vbox, "Diffuse Strength", 0.0, 3.0, init_diffuse, _on_foam_diffuse_changed)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Specular Settings
	_add_section_label(main_vbox, "Specular Settings")
	_add_slider(main_vbox, "Sun Specular", 0.0, 2.0, init_specular, _on_specular_changed)
	_add_slider(main_vbox, "PBR Specular", 0.0, 1.0, init_pbr, _on_pbr_specular_changed)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Atmosphere Settings
	_add_section_label(main_vbox, "Atmosphere Settings")
	var init_time = atmosphere_renderer.time_of_day if atmosphere_renderer else 12.0
	var init_sun_energy = atmosphere_renderer.sun.light_energy if atmosphere_renderer and atmosphere_renderer.sun else 1.5
	var init_ambient = atmosphere_renderer.environment.ambient_light_energy if atmosphere_renderer else 0.5
	
	_add_slider(main_vbox, "Time of Day", 0.0, 24.0, init_time, _on_time_of_day_changed)
	_add_slider(main_vbox, "Sun Brightness", 0.0, 3.0, init_sun_energy, _on_sun_brightness_changed)
	_add_slider(main_vbox, "Ambient Light", 0.0, 2.0, init_ambient, _on_ambient_light_changed)
	
	# Print values button
	var print_btn = Button.new()
	print_btn.text = "Print Current Values"
	print_btn.pressed.connect(_print_values)
	main_vbox.add_child(print_btn)

func _add_section_label(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	parent.add_child(label)

func _add_slider(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, callback: Callable) -> HSlider:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	hbox.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = default_val
	slider.custom_minimum_size.x = 120
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	
	var value_label = Label.new()
	value_label.text = "%.2f" % default_val
	value_label.custom_minimum_size.x = 50
	hbox.add_child(value_label)
	
	slider.value_changed.connect(func(val):
		value_label.text = "%.2f" % val
		callback.call(val)
	)
	
	return slider


# Callbacks for sliders
func _on_choppiness_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.choppiness = value

func _on_wind_speed_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.wind_speed = value

func _on_foam_jacobian_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.foam_jacobian_limit = value

func _on_foam_coverage_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.foam_coverage = value

func _on_foam_mix_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.foam_mix_strength = value

func _on_foam_diffuse_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.foam_diffuse_strength = value

func _on_specular_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.specular_strength = value

func _on_pbr_specular_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.pbr_specular_strength = value

func _on_time_of_day_changed(value: float) -> void:
	if atmosphere_renderer:
		atmosphere_renderer.set_time_of_day(value)

func _on_sun_brightness_changed(value: float) -> void:
	if atmosphere_renderer and atmosphere_renderer.sun:
		# Store the value and let the time of day system use it as a multiplier
		atmosphere_renderer.sun.light_energy = value

func _on_ambient_light_changed(value: float) -> void:
	if atmosphere_renderer and atmosphere_renderer.environment:
		atmosphere_renderer.environment.ambient_light_energy = value

func _print_values() -> void:
	if ocean_renderer:
		print("=== Current Ocean Settings ===")
		print("choppiness = ", ocean_renderer.choppiness)
		print("wind_speed = ", ocean_renderer.wind_speed)
		print("foam_jacobian_limit = ", ocean_renderer.foam_jacobian_limit)
		print("foam_coverage = ", ocean_renderer.foam_coverage)
		print("foam_mix_strength = ", ocean_renderer.foam_mix_strength)
		print("foam_diffuse_strength = ", ocean_renderer.foam_diffuse_strength)
		print("specular_strength = ", ocean_renderer.specular_strength)
		print("pbr_specular_strength = ", ocean_renderer.pbr_specular_strength)
		print("==============================")
	
	if atmosphere_renderer:
		print("=== Current Atmosphere Settings ===")
		print("time_of_day = ", atmosphere_renderer.time_of_day)
		if atmosphere_renderer.sun:
			print("sun.light_energy = ", atmosphere_renderer.sun.light_energy)
		if atmosphere_renderer.environment:
			print("ambient_light_energy = ", atmosphere_renderer.environment.ambient_light_energy)
		print("=====================================")
