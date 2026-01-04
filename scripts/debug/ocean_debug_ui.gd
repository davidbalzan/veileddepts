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
var wave_stats_label: Label

# Wave measurement
var wave_sample_points: Array[Vector3] = []
var wave_height_min: float = 0.0
var wave_height_max: float = 0.0
var wave_height_avg: float = 0.0
var significant_wave_height: float = 0.0  # Hs - average of highest 1/3 of waves


func _ready() -> void:
	# Ensure this CanvasLayer is on top of other UI
	layer = 128
	# Process input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_deferred_setup")
	
	# Register with DebugPanelManager
	DebugPanelManager.register_panel("ocean", self)


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
	mat.albedo_color = Color(1, 0, 0)  # Red
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
	mat2.albedo_color = Color(0, 0, 1)  # Blue
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
	panel.custom_minimum_size = Vector2(300, 400)  # Increased height
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

	# Visibility Toggles
	_add_section_label(vbox, "Visibility")
	_add_checkbox(vbox, "Show Ocean", true, _on_ocean_visibility_changed)
	_add_checkbox(vbox, "Show Atmosphere", true, _on_atmosphere_visibility_changed)

	vbox.add_child(HSeparator.new())

	# Wave Settings
	_add_section_label(vbox, "Wave Settings")

	var init_wave_scale = 512
	var init_amplitude = 1.0
	if ocean_renderer and ocean_renderer.horizontal_dimension:
		init_wave_scale = ocean_renderer.horizontal_dimension
	if ocean_renderer and ocean_renderer.ocean:
		init_amplitude = ocean_renderer.ocean.amplitude_scale_max

	_add_slider(vbox, "Wave Height", 0.05, 2.0, init_amplitude, _on_wave_height_changed)
	_add_slider(vbox, "Wave Length", 64.0, 2048.0, float(init_wave_scale), _on_wave_scale_changed)
	_add_slider(vbox, "Wind Speed", 1.0, 100.0, init_wind_speed, _on_wind_speed_changed)
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
	_add_checkbox(vbox, "Debug Terrain Colors", false, _on_terrain_debug_colors_changed)

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

	# Wave statistics section
	vbox.add_child(HSeparator.new())
	_add_section_label(vbox, "Wave Statistics (meters)")
	wave_stats_label = Label.new()
	wave_stats_label.name = "WaveStatsLabel"
	wave_stats_label.text = "Measuring..."
	vbox.add_child(wave_stats_label)


func _add_section_label(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	parent.add_child(label)


func _add_checkbox(
	parent: Control,
	label_text: String,
	default_val: bool,
	callback: Callable
) -> CheckBox:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)

	var checkbox = CheckBox.new()
	checkbox.text = label_text
	checkbox.button_pressed = default_val
	checkbox.toggled.connect(callback)
	hbox.add_child(checkbox)

	return checkbox


func _add_slider(
	parent: Control,
	label_text: String,
	min_val: float,
	max_val: float,
	default_val: float,
	callback: Callable
) -> HSlider:
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

	slider.value_changed.connect(
		func(val):
			value_label.text = "%.2f" % val
			callback.call(val)
	)
	return slider


func _on_wave_height_changed(value: float) -> void:
	if ocean_renderer and ocean_renderer.ocean:
		ocean_renderer.ocean.amplitude_scale_max = value
		# Also update amplitude_scale_min proportionally
		ocean_renderer.ocean.amplitude_scale_min = value * 0.25


func _on_wave_scale_changed(value: float) -> void:
	if ocean_renderer:
		ocean_renderer.horizontal_dimension = int(value)
		# Need to reinitialize ocean simulation for this to take effect
		if ocean_renderer.ocean:
			ocean_renderer.ocean.horizontal_dimension = int(value)


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


func _on_ocean_visibility_changed(is_visible: bool) -> void:
	if ocean_renderer:
		ocean_renderer.visible = is_visible
		# Also hide the quad_tree directly (the actual rendering mesh)
		if ocean_renderer.quad_tree:
			ocean_renderer.quad_tree.visible = is_visible

	# Hide all sea-related elements
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var sealife = main.get_node_or_null("SealifeRenderer")
		if sealife:
			sealife.visible = is_visible

		var wake = main.get_node_or_null("SubmarineWake")
		if wake:
			wake.visible = is_visible

		# Hide underwater particles if they exist
		var particles = main.get_node_or_null("UnderwaterParticles")
		if particles:
			particles.visible = is_visible

	# Change background to show terrain clearly when ocean is hidden
	if atmosphere_renderer and atmosphere_renderer.environment:
		if is_visible:
			# Restore sky background
			atmosphere_renderer.environment.background_mode = Environment.BG_SKY
		else:
			# Use solid color background to see terrain clearly
			atmosphere_renderer.environment.background_mode = Environment.BG_COLOR
			atmosphere_renderer.environment.background_color = Color(0.15, 0.15, 0.15)  # Neutral gray

	print("OceanDebugUI: Ocean/sea visibility set to ", is_visible)


func _on_atmosphere_visibility_changed(is_visible: bool) -> void:
	if atmosphere_renderer:
		# WorldEnvironment doesn't have a visible property
		# Instead, we enable/disable the environment itself
		if is_visible:
			# Restore the environment if we stored one
			if atmosphere_renderer.has_meta("_stored_environment"):
				atmosphere_renderer.environment = atmosphere_renderer.get_meta("_stored_environment")
				atmosphere_renderer.remove_meta("_stored_environment")
		else:
			# Store and disable the environment
			if atmosphere_renderer.environment:
				atmosphere_renderer.set_meta("_stored_environment", atmosphere_renderer.environment)
				atmosphere_renderer.environment = null
		
		print("OceanDebugUI: Atmosphere visibility set to ", is_visible)


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


func _on_terrain_debug_colors_changed(enabled: bool) -> void:
	if terrain_renderer:
		# Find the ChunkManager in the terrain renderer
		var chunk_manager = terrain_renderer.get_node_or_null("ChunkManager")
		if chunk_manager and chunk_manager.has_method("set_debug_color_mode"):
			chunk_manager.set_debug_color_mode(enabled)
			print("OceanDebugUI: Terrain debug colors ", "enabled" if enabled else "disabled")


func _print_values() -> void:
	if ocean_renderer:
		print("=== Ocean Settings ===")
		if ocean_renderer.ocean:
			print("amplitude_scale_max = %.2f" % ocean_renderer.ocean.amplitude_scale_max)
		print("horizontal_dimension = ", ocean_renderer.horizontal_dimension)
		print("wind_speed = ", ocean_renderer.wind_speed)
		print("wind_direction_degrees = ", ocean_renderer.wind_direction_degrees)
		print("choppiness = ", ocean_renderer.choppiness)
		print("time_scale = ", ocean_renderer.time_scale)
		print("")
		print("=== Wave Statistics ===")
		print("wave_height_min = %.2f m" % wave_height_min)
		print("wave_height_max = %.2f m" % wave_height_max)
		print("peak_to_trough = %.2f m" % (wave_height_max - wave_height_min))
		print("significant_wave_height = %.2f m" % significant_wave_height)
		print("sea_state = %s" % _get_sea_state(significant_wave_height))
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

		# Measure wave statistics (every 10 frames to reduce overhead)
		if Engine.get_process_frames() % 10 == 0:
			_measure_wave_statistics(cam_pos)

	# Update debug label with detailed info
	if debug_label:
		var delta_h = cam_pos.y - wave_height
		var txt = "Camera Y: %.2f\n" % cam_pos.y
		txt += "Wave Y:   %.2f\n" % wave_height
		txt += "Delta:    %.2f m\n" % delta_h
		txt += "Status:   %s" % ("UNDERWATER" if is_underwater else "SURFACE")
		debug_label.text = txt

	# Update wave stats label
	if wave_stats_label:
		var sea_state = _get_sea_state(significant_wave_height)
		var txt = "Min: %.1fm  Max: %.1fm\n" % [wave_height_min, wave_height_max]
		txt += "Peak-to-Trough: %.1fm\n" % (wave_height_max - wave_height_min)
		txt += "Sig. Wave Ht (Hs): %.1fm\n" % significant_wave_height
		txt += "Sea State: %s" % sea_state
		wave_stats_label.text = txt


func _measure_wave_statistics(center_pos: Vector3) -> void:
	if not ocean_renderer or not ocean_renderer.initialized:
		return

	# Sample a grid of points around the camera
	var sample_radius = 100.0  # meters
	var sample_count = 8  # points per axis
	var heights: Array[float] = []

	for i in range(sample_count):
		for j in range(sample_count):
			var offset_x = (float(i) / (sample_count - 1) - 0.5) * 2.0 * sample_radius
			var offset_z = (float(j) / (sample_count - 1) - 0.5) * 2.0 * sample_radius
			var sample_pos = Vector3(center_pos.x + offset_x, 0, center_pos.z + offset_z)
			var h = ocean_renderer.get_wave_height_3d(sample_pos)
			heights.append(h)

	if heights.is_empty():
		return

	# Calculate statistics
	heights.sort()
	wave_height_min = heights[0]
	wave_height_max = heights[heights.size() - 1]

	var sum = 0.0
	for h in heights:
		sum += h
	wave_height_avg = sum / heights.size()

	# Significant wave height (Hs) = average of highest 1/3 of waves
	# This is a standard oceanographic measure
	var top_third_start = int(heights.size() * 2.0 / 3.0)
	var top_third_sum = 0.0
	var top_third_count = 0
	for i in range(top_third_start, heights.size()):
		top_third_sum += heights[i] - wave_height_avg  # Height above mean
		top_third_count += 1

	if top_third_count > 0:
		# Hs is typically measured as 4x the standard deviation,
		# but simplified here as average amplitude of top 1/3
		significant_wave_height = (wave_height_max - wave_height_min) * 0.5


func _get_sea_state(hs: float) -> String:
	# Douglas Sea Scale / World Meteorological Organization sea state codes
	# Based on significant wave height (Hs)
	if hs < 0.1:
		return "0 - Calm (glassy)"
	elif hs < 0.5:
		return "1 - Calm (rippled)"
	elif hs < 1.25:
		return "2 - Smooth"
	elif hs < 2.5:
		return "3 - Slight"
	elif hs < 4.0:
		return "4 - Moderate"
	elif hs < 6.0:
		return "5 - Rough"
	elif hs < 9.0:
		return "6 - Very Rough"
	elif hs < 14.0:
		return "7 - High"
	else:
		return "8 - Very High"
