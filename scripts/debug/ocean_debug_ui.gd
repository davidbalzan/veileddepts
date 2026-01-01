class_name OceanDebugUI extends CanvasLayer
## Debug UI for tweaking ocean parameters in real-time
## Press F3 to toggle visibility

var ocean_renderer: OceanRenderer
var atmosphere_renderer: AtmosphereRenderer
var terrain_renderer: TerrainRenderer
var panel: PanelContainer
var visible_state: bool = false

# Simple 3D debug markers
var camera_marker: MeshInstance3D
var wave_marker: MeshInstance3D
var debug_label: Label

func _ready() -> void:
	# Ensure this CanvasLayer is on top of other UI
	layer = 128
	# Process input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_deferred_setup")

func _deferred_setup() -> void:
	print("OceanDebugUI: Starting deferred setup...")
	_find_ocean_renderer()
	print("OceanDebugUI: Ocean renderer found: ", ocean_renderer != null)
	_find_atmosphere_renderer()
	print("OceanDebugUI: Atmosphere renderer found: ", atmosphere_renderer != null)
	_find_terrain_renderer()
	print("OceanDebugUI: Terrain renderer found: ", terrain_renderer != null)
	_create_ui()
	print("OceanDebugUI: UI created, panel: ", panel != null)
	_create_debug_markers()
	print("OceanDebugUI: Debug markers created")
	panel.visible = visible_state
	print("OceanDebugUI: Panel visibility set to: ", visible_state)
	_update_marker_visibility()
	print("OceanDebugUI: Setup complete!")

func _find_ocean_renderer() -> void:
	var nodes = get_tree().get_nodes_in_group("ocean_renderer")
	if nodes.size() > 0:
		ocean_renderer = nodes[0] as OceanRenderer
	else:
		var found = _find_node_by_class(get_tree().root)
		ocean_renderer = found as OceanRenderer

func _find_atmosphere_renderer() -> void:
	var nodes = get_tree().get_nodes_in_group("atmosphere_renderer")
	if nodes.size() > 0:
		atmosphere_renderer = nodes[0] as AtmosphereRenderer
	else:
		var found = _find_node_by_class_atmosphere(get_tree().root)
		atmosphere_renderer = found as AtmosphereRenderer

func _find_terrain_renderer() -> void:
	var nodes = get_tree().get_nodes_in_group("terrain_renderer")
	if nodes.size() > 0:
		terrain_renderer = nodes[0]
	else:
		terrain_renderer = _find_node_by_class_terrain(get_tree().root)

func _find_node_by_class(node: Node) -> OceanRenderer:
	if node is OceanRenderer:
		return node
	for child in node.get_children():
		var result = _find_node_by_class(child)
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

func _find_node_by_class_terrain(node: Node) -> TerrainRenderer:
	if node is TerrainRenderer:
		return node
	for child in node.get_children():
		var result = _find_node_by_class_terrain(child)
		if result:
			return result
	return null


func _create_debug_markers() -> void:
	# 3D markers need to be added to the 3D scene tree, not CanvasLayer
	var scene_root = get_tree().root.get_node_or_null("Main")
	if not scene_root:
		push_warning("OceanDebugUI: Could not find Main node for 3D markers")
		return

	# Camera marker (Red sphere)
	camera_marker = MeshInstance3D.new()
	camera_marker.name = "DebugCameraMarker"
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	camera_marker.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0) # Red
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	camera_marker.material_override = mat
	scene_root.add_child(camera_marker)

	# Wave height marker (Blue sphere)
	wave_marker = MeshInstance3D.new()
	wave_marker.name = "DebugWaveMarker"
	var sphere2 = SphereMesh.new()
	sphere2.radius = 0.5
	sphere2.height = 1.0
	wave_marker.mesh = sphere2
	var mat2 = StandardMaterial3D.new()
	mat2.albedo_color = Color(0, 0, 1) # Blue
	mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave_marker.material_override = mat2
	scene_root.add_child(wave_marker)


func _update_marker_visibility() -> void:
	if camera_marker:
		camera_marker.visible = visible_state
	if wave_marker:
		wave_marker.visible = visible_state

func _create_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "OceanDebugPanel"
	panel.custom_minimum_size = Vector2(300, 400) # Increased height
	panel.position = Vector2(20, 20)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Header
	var title = Label.new()
	title.text = "OCEAN / TERRAIN DEBUG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Camera / Periscope Info
	debug_label = Label.new()
	debug_label.text = "Waiting for data..."
	vbox.add_child(debug_label)
	
	vbox.add_child(HSeparator.new())
	
	# Get initial values
	var init_choppiness = 1.5
	var init_wind_speed = 30.0
	var init_wind_dir = 45.0
	var init_time_scale = 1.0
	
	if ocean_renderer:
		init_choppiness = ocean_renderer.choppiness
		init_wind_speed = ocean_renderer.wind_speed
		init_wind_dir = ocean_renderer.wind_direction_degrees
		init_time_scale = ocean_renderer.time_scale
	
	# Wave Settings
	_add_section_label(vbox, "Wave Settings")
	_add_slider(vbox, "Wind Speed", 5.0, 100.0, init_wind_speed, _on_wind_speed_changed)
	_add_slider(vbox, "Wind Direction", 0.0, 360.0, init_wind_dir, _on_wind_direction_changed)
	_add_slider(vbox, "Choppiness", 0.0, 2.5, init_choppiness, _on_choppiness_changed)
	_add_slider(vbox, "Time Scale", 0.1, 3.0, init_time_scale, _on_time_scale_changed)
	
	vbox.add_child(HSeparator.new())
	
	# Atmosphere Settings
	_add_section_label(vbox, "Atmosphere Settings")
	var init_time = 12.0
	if atmosphere_renderer:
		init_time = atmosphere_renderer.time_of_day
	_add_slider(vbox, "Time of Day", 0.0, 24.0, init_time, _on_time_of_day_changed)
	
	vbox.add_child(HSeparator.new())
	
	# Terrain Settings
	_add_section_label(vbox, "Terrain Settings")
	var init_max_h = 100.0
	var init_min_h = -200.0
	var init_size = 2048.0
	
	if terrain_renderer:
		init_max_h = terrain_renderer.max_height
		init_min_h = terrain_renderer.min_height
		init_size = float(terrain_renderer.terrain_size.x)
	
	_add_slider(vbox, "Max Height", 0.0, 500.0, init_max_h, _on_max_height_changed)
	_add_slider(vbox, "Min Height", -1000.0, 0.0, init_min_h, _on_min_height_changed)
	_add_slider(vbox, "Scale (X=Y)", 512.0, 8192.0, init_size, _on_terrain_scale_changed)
	
	vbox.add_child(HSeparator.new())
	
	# Print values button
	var print_btn = Button.new()
	print_btn.text = "Print Current Values"
	print_btn.pressed.connect(_print_values)
	vbox.add_child(print_btn)
	
	# Add underwater status label
	vbox.add_child(HSeparator.new())
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Camera Status: --"
	vbox.add_child(status_label)

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
	label.custom_minimum_size.x = 100
	hbox.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = default_val
	slider.custom_minimum_size.x = 140
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

func _on_wind_speed_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.wind_speed = value

func _on_wind_direction_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.wind_direction_degrees = value

func _on_choppiness_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.choppiness = value

func _on_time_scale_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.time_scale = value

func _on_time_of_day_changed(value: float) -> void:
	if atmosphere_renderer:
		atmosphere_renderer.set_time_of_day(value)

func _on_max_height_changed(value: float) -> void:
	if terrain_renderer:
		terrain_renderer.max_height = value
		terrain_renderer.regenerate_terrain()

func _on_min_height_changed(value: float) -> void:
	if terrain_renderer:
		terrain_renderer.min_height = value
		terrain_renderer.regenerate_terrain()

func _on_terrain_scale_changed(value: float) -> void:
	if terrain_renderer:
		var size_int = int(value)
		terrain_renderer.terrain_size = Vector2i(size_int, size_int)
		terrain_renderer.regenerate_terrain()

func _print_values() -> void:
	if ocean_renderer:
		print("=== Ocean Settings ===")
		print("wind_speed = ", ocean_renderer.wind_speed)
		print("wind_direction_degrees = ", ocean_renderer.wind_direction_degrees)
		print("choppiness = ", ocean_renderer.choppiness)
		print("time_scale = ", ocean_renderer.time_scale)
	if atmosphere_renderer:
		print("=== Atmosphere ===")
		print("time_of_day = ", atmosphere_renderer.time_of_day)


func _input(event: InputEvent) -> void:
	# Handle F3 toggle - match F5 panel approach
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F3:
				visible_state = not visible_state
				if panel:
					panel.visible = visible_state
				_update_marker_visibility()
				print("OceanDebugUI: F3 pressed - ", "Visible" if visible_state else "Hidden")

func _process(_delta: float) -> void:
	if not visible_state:
		return

	if not panel:
		return
		
	var active_camera = get_viewport().get_camera_3d()
	if not active_camera:
		return
		
	var cam_pos = active_camera.global_position
	
	# Update camera marker
	if camera_marker:
		camera_marker.global_position = cam_pos
		
	# Calculate and update wave info
	var wave_height = 0.0
	var is_underwater = false
	
	if ocean_renderer and ocean_renderer.initialized:
		# Get exact wave height at camera X/Z
		wave_height = ocean_renderer.get_wave_height_3d(cam_pos)
		is_underwater = ocean_renderer.is_position_underwater(cam_pos)
		
		# Update wave marker
		if wave_marker:
			wave_marker.global_position = Vector3(cam_pos.x, wave_height, cam_pos.z)
	
	# Update debug label with detailed info
	if debug_label:
		var delta_h = cam_pos.y - wave_height
		var txt = "Camera Y: %.2f\n" % cam_pos.y
		txt += "Wave Y:   %.2f\n" % wave_height
		txt += "Delta:    %.2f m\n" % delta_h
		txt += "Status:   %s" % ("UNDERWATER" if is_underwater else "SURFACE")
		debug_label.text = txt
