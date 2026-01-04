extends CanvasLayer
class_name TacticalMapView

## TacticalMapView provides the 2D strategic interface for submarine command and control.
var simulation_state: Node = null
var terrain_renderer: Node = null

## Map display parameters
var map_center: Vector2 = Vector2(960, 540)  # Center of 1920x1080 screen
var map_scale: float = 0.1  # pixels per meter (1 meter = 0.1 pixels)
var map_zoom: float = 1.0  # Zoom multiplier
var map_pan_offset: Vector2 = Vector2.ZERO  # Pan offset in pixels

## Terrain visualization
var terrain_texture: ImageTexture = null
var terrain_image: Image = null
var show_terrain: bool = true
var terrain_world_size: float = 10000.0  # meters
var _terrain_generation_attempted: bool = false
var _last_generated_zoom: float = 1.0
var _last_generated_pos: Vector3 = Vector3.ZERO
var _zoom_settle_timer: float = 0.0
var _current_lod: int = 3  # Start with lowest detail
var _target_lod: int = 0  # Target LOD based on zoom
var _loading_higher_detail: bool = false  # Flag to prevent multiple async loads

## Help overlay
var help_overlay: Control = null
var show_help: bool = false

## UI element references
var map_canvas: Control  # Canvas for drawing submarine and contacts
var submarine_info_label: Label
var speed_slider: HSlider
var depth_slider: HSlider
var speed_value_label: Label
var depth_value_label: Label
var compass_indicator: Control  # North indicator

## Contact icon tracking
var contact_icons: Dictionary = {}  # contact_id -> visual data

## Input state
var is_panning: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO

## Constants
const SUBMARINE_ICON_SIZE: float = 20.0
const CONTACT_ICON_SIZE: float = 15.0
const BEARING_ARC_LENGTH: float = 50.0
const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 10.0  # Increased from 5.0


func _ready() -> void:
	# Create UI elements first so they are available immediately (even to subclasses)
	_create_ui_elements()

	# Get simulation state reference from parent if not already set
	if not simulation_state:
		var main_node = get_parent()
		if main_node:
			simulation_state = main_node.get_node_or_null("SimulationState")
			if not simulation_state:
				push_error("TacticalMapView: SimulationState not found")

			# Get terrain renderer reference
			terrain_renderer = main_node.get_node_or_null("TerrainRenderer")
			
			print("TacticalMapView: Found SimulationState: ", simulation_state != null)
			print("TacticalMapView: Found TerrainRenderer: ", terrain_renderer != null)

			if terrain_renderer:
				# Wait for terrain to fully initialize (non-blocking for subclasses after this point if they don't await)
				_initialize_terrain_deferred()
				
				# Connect to mission area changes to regenerate texture
				if terrain_renderer.has_signal("mission_area_changed"):
					terrain_renderer.mission_area_changed.connect(_on_mission_area_changed)

	# Connect to SeaLevelManager for dynamic sea level updates
	if SeaLevelManager:
		SeaLevelManager.sea_level_changed.connect(_on_sea_level_changed)
		print("TacticalMapView: Connected to SeaLevelManager")
	else:
		push_warning("TacticalMapView: SeaLevelManager not found")

	print("TacticalMapView: Initialized")


func _on_mission_area_changed(_new_region: Rect2) -> void:
	print("TacticalMapView: Mission area changed, resetting terrain texture...")
	terrain_texture = null
	_terrain_generation_attempted = false


## Handle sea level changes from SeaLevelManager
func _on_sea_level_changed(normalized: float, meters: float) -> void:
	print("TacticalMapView: Sea level changed to %.3f (%.0fm), regenerating map texture..." % [normalized, meters])
	# Regenerate tactical map with new sea level threshold
	if terrain_renderer and terrain_renderer.initialized:
		_generate_terrain_texture()
	else:
		# Mark for regeneration when terrain becomes available
		terrain_texture = null
		_terrain_generation_attempted = false


func _initialize_terrain_deferred() -> void:
	# Wait multiple frames to ensure terrain system is ready
	for i in range(5):
		await get_tree().process_frame

	# Check if terrain renderer is initialized
	if terrain_renderer and terrain_renderer.initialized:
		print("TacticalMapView: Terrain renderer ready, generating texture...")
		_generate_terrain_texture()
	elif terrain_renderer:
		push_warning(
			"TacticalMapView: Terrain renderer not initialized yet, will retry later"
		)


## Create all UI elements for the tactical map
func _create_ui_elements() -> void:
	# Create background to cover 3D world
	var background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.1, 0.15, 1.0)  # Dark blue-grey
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Create map canvas for drawing (full screen)
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	map_canvas.draw.connect(_on_map_canvas_draw)
	add_child(map_canvas)

	# Create submarine info label
	submarine_info_label = Label.new()
	submarine_info_label.name = "SubmarineInfo"
	submarine_info_label.position = Vector2(20, 80)
	submarine_info_label.add_theme_font_size_override("font_size", 16)
	submarine_info_label.text = "Submarine Info"
	add_child(submarine_info_label)

	# Create control panel container
	var control_panel = VBoxContainer.new()
	control_panel.name = "ControlPanel"
	control_panel.position = Vector2(20, 200)
	control_panel.custom_minimum_size = Vector2(300, 200)
	add_child(control_panel)

	# Speed control
	var speed_label = Label.new()
	speed_label.text = "Speed (m/s): [Reverse ← | → Forward]"
	speed_label.add_theme_font_size_override("font_size", 14)
	control_panel.add_child(speed_label)

	speed_slider = HSlider.new()
	speed_slider.name = "SpeedSlider"
	speed_slider.min_value = -SimulationState.MAX_SPEED * 0.5  # Reverse at half speed
	speed_slider.max_value = SimulationState.MAX_SPEED
	speed_slider.step = 0.1
	speed_slider.value = 0.0
	speed_slider.custom_minimum_size = Vector2(250, 30)
	speed_slider.value_changed.connect(_on_speed_changed)
	control_panel.add_child(speed_slider)

	speed_value_label = Label.new()
	speed_value_label.name = "SpeedValue"
	speed_value_label.text = "0.0 m/s"
	speed_value_label.add_theme_font_size_override("font_size", 14)
	control_panel.add_child(speed_value_label)

	# Add spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	control_panel.add_child(spacer1)

	# Depth control
	var depth_label = Label.new()
	depth_label.text = "Depth (m):"
	depth_label.add_theme_font_size_override("font_size", 14)
	control_panel.add_child(depth_label)

	depth_slider = HSlider.new()
	depth_slider.name = "DepthSlider"
	depth_slider.min_value = SimulationState.MIN_DEPTH
	depth_slider.max_value = SimulationState.MAX_DEPTH
	depth_slider.step = 1.0
	depth_slider.value = 0.0
	depth_slider.custom_minimum_size = Vector2(250, 30)
	depth_slider.value_changed.connect(_on_depth_changed)
	control_panel.add_child(depth_slider)

	depth_value_label = Label.new()
	depth_value_label.name = "DepthValue"
	depth_value_label.text = "0 m"
	depth_value_label.add_theme_font_size_override("font_size", 14)
	control_panel.add_child(depth_value_label)

	# Instructions label
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.position = Vector2(20, 450)
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.text = "F1: Help | T: Toggle Terrain | Left Click: Waypoint"
	add_child(instructions)

	# Terrain toggle button
	var terrain_toggle = Button.new()
	terrain_toggle.name = "TerrainToggle"
	terrain_toggle.position = Vector2(20, 600)
	terrain_toggle.text = "Toggle Terrain (T)"
	terrain_toggle.custom_minimum_size = Vector2(200, 40)
	terrain_toggle.pressed.connect(_on_terrain_toggle)
	add_child(terrain_toggle)

	# Recenter button
	var recenter_button = Button.new()
	recenter_button.name = "RecenterButton"
	recenter_button.position = Vector2(20, 650)
	recenter_button.text = "Center on Sub (C)"
	recenter_button.custom_minimum_size = Vector2(200, 40)
	recenter_button.pressed.connect(_on_recenter)
	add_child(recenter_button)

	# Create help overlay (initially hidden)
	_create_help_overlay()

	# Compass indicator (top right)
	compass_indicator = Control.new()
	compass_indicator.name = "CompassIndicator"
	compass_indicator.position = Vector2(1920 - 120, 20)
	compass_indicator.custom_minimum_size = Vector2(100, 100)
	compass_indicator.draw.connect(_draw_compass)
	add_child(compass_indicator)


## Draw compass indicator showing north
func _draw_compass() -> void:
	if not compass_indicator or not simulation_state:
		return

	var control = compass_indicator
	var size = 100.0
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = 40.0

	# Draw background circle
	control.draw_circle(center, radius + 3, Color(0, 0, 0, 0.5))
	control.draw_arc(center, radius + 3, 0, TAU, 32, Color(0.2, 0.8, 0.2, 0.8), 2.0)

	# Draw cardinal directions
	var directions = [
		{"angle": 0, "label": "N", "color": Color(1, 0, 0, 1)},  # North - Red
		{"angle": 90, "label": "E", "color": Color(0.5, 0.5, 0.5, 1)},  # East - Gray
		{"angle": 180, "label": "S", "color": Color(0.5, 0.5, 0.5, 1)},  # South - Gray
		{"angle": 270, "label": "W", "color": Color(0.5, 0.5, 0.5, 1)}  # West - Gray
	]

	var font = ThemeDB.fallback_font
	var font_size = 16

	for dir in directions:
		var angle_rad = deg_to_rad(dir["angle"])
		var dir_vec = Vector2(sin(angle_rad), -cos(angle_rad))  # -cos because -Z is North
		var tick_start = center + dir_vec * (radius - 8)
		var tick_end = center + dir_vec * (radius + 2)
		var label_pos = center + dir_vec * (radius + 15)

		# Draw tick mark
		var tick_width = 3.0 if dir["angle"] == 0 else 2.0
		control.draw_line(tick_start, tick_end, dir["color"], tick_width)

		# Draw label
		var text_size = font.get_string_size(
			dir["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
		)
		control.draw_string(
			font,
			label_pos - text_size / 2,
			dir["label"],
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			font_size,
			dir["color"]
		)

	# Draw submarine heading indicator (green arrow) - shows CURRENT heading
	var heading_rad = deg_to_rad(simulation_state.submarine_heading)
	var heading_vec = Vector2(sin(heading_rad), -cos(heading_rad))  # -cos because -Z is North
	var arrow_end = center + heading_vec * (radius - 5)

	# Draw arrow line
	control.draw_line(center, arrow_end, Color(0, 1, 0, 0.9), 3.0)

	# Draw arrowhead
	var arrow_size = 6.0
	var arrow_left = (
		arrow_end + Vector2(sin(heading_rad - 2.5), -cos(heading_rad - 2.5)) * arrow_size
	)
	var arrow_right = (
		arrow_end + Vector2(sin(heading_rad + 2.5), -cos(heading_rad + 2.5)) * arrow_size
	)
	control.draw_colored_polygon(
		PackedVector2Array([arrow_end, arrow_left, arrow_right]), Color(0, 1, 0, 0.9)
	)

	# Draw target heading marker (yellow tick) - shows where sub is TURNING to
	var target_heading_rad = deg_to_rad(simulation_state.target_heading)
	var target_vec = Vector2(sin(target_heading_rad), -cos(target_heading_rad))
	var target_tick_start = center + target_vec * (radius - 12)
	var target_tick_end = center + target_vec * (radius + 5)
	control.draw_line(target_tick_start, target_tick_end, Color(1, 1, 0, 0.9), 4.0)

	# Draw small triangle at target heading
	var target_marker_pos = center + target_vec * (radius + 8)
	var target_marker_size = 5.0
	var target_left = (
		target_marker_pos
		+ (
			Vector2(sin(target_heading_rad - 2.0), -cos(target_heading_rad - 2.0))
			* target_marker_size
		)
	)
	var target_right = (
		target_marker_pos
		+ (
			Vector2(sin(target_heading_rad + 2.0), -cos(target_heading_rad + 2.0))
			* target_marker_size
		)
	)
	control.draw_colored_polygon(
		PackedVector2Array([target_marker_pos, target_left, target_right]), Color(1, 1, 0, 0.9)
	)

	# Draw heading text below compass - show current and target heading
	var heading_text = (
		"HDG: %03d° → %03d°"
		% [int(simulation_state.submarine_heading), int(simulation_state.target_heading)]
	)
	var heading_text_size = font.get_string_size(heading_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	control.draw_string(
		font,
		Vector2(center.x - heading_text_size.x / 2, size - 5),
		heading_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		14,
		Color(0, 1, 0, 1)
	)


## Handle input events for waypoint placement and map control
func _input(event: InputEvent) -> void:
	# Only process input when this view is visible
	if not visible:
		return

	# Help overlay intercepts all input except F1 and ESC
	if show_help:
		if event is InputEventKey:
			var key_event = event as InputEventKey
			if key_event.pressed and not key_event.echo:
				if key_event.keycode == KEY_F1 or key_event.keycode == KEY_ESCAPE:
					_toggle_help()
		return  # Block all other input when help is shown

	# Keyboard shortcuts
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			# Toggle help with F1
			if key_event.keycode == KEY_F1:
				_toggle_help()
				return
			# Toggle terrain debug overlay with F2
			elif key_event.keycode == KEY_F2:
				_toggle_terrain_debug()
				return
			# Toggle terrain with T key
			elif key_event.keycode == KEY_T:
				_on_terrain_toggle()
				return
			# Recenter with C key
			elif key_event.keycode == KEY_C:
				_on_recenter()
				return
			# Zoom in with + or =
			elif key_event.keycode == KEY_PLUS or key_event.keycode == KEY_EQUAL:
				_handle_keyboard_zoom(1.2)
				return
			# Zoom out with -
			elif key_event.keycode == KEY_MINUS:
				_handle_keyboard_zoom(0.8)
				return

	# Waypoint placement with left click
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		# Left click for waypoint
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_waypoint_placement(mouse_event.position)

		# Middle mouse button for panning
		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				is_panning = true
				last_mouse_position = mouse_event.position
			else:
				is_panning = false

		# Right mouse button for panning (alternative)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				is_panning = true
				last_mouse_position = mouse_event.position
			else:
				is_panning = false

		# Mouse wheel for zoom
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(1.1, mouse_event.position)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(0.9, mouse_event.position)

	# Handle panning
	elif event is InputEventMouseMotion and is_panning:
		var mouse_motion = event as InputEventMouseMotion
		var delta = mouse_motion.position - last_mouse_position
		map_pan_offset += delta
		last_mouse_position = mouse_motion.position


## Handle waypoint placement at screen position
func _handle_waypoint_placement(screen_pos: Vector2) -> void:
	if not simulation_state:
		return

	# Convert screen position to world position
	var world_pos = screen_to_world(screen_pos)

	# Debug: Print waypoint info
	var sub_pos = simulation_state.submarine_position
	var delta = world_pos - sub_pos
	var heading_to_waypoint = rad_to_deg(atan2(delta.x, -delta.z))
	if heading_to_waypoint < 0:
		heading_to_waypoint += 360.0
	print(
		"Waypoint: screen=%s world=%s heading=%.0f°" % [screen_pos, world_pos, heading_to_waypoint]
	)

	# Update submarine command with new waypoint
	# Keep current speed and depth targets
	simulation_state.update_submarine_command(
		world_pos, simulation_state.target_speed, simulation_state.target_depth
	)

	print("TacticalMapView: Waypoint set to ", world_pos)


## Handle zoom input
func _handle_zoom(zoom_factor: float, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	var old_zoom = map_zoom
	map_zoom *= zoom_factor
	map_zoom = clamp(map_zoom, MIN_ZOOM, MAX_ZOOM)

	# If mouse position provided and zoom actually changed, adjust pan to zoom toward mouse
	if mouse_pos != Vector2.ZERO and abs(map_zoom - old_zoom) > 0.001 and simulation_state:
		# Get world position under mouse cursor before zoom change
		var temp_zoom = map_zoom
		map_zoom = old_zoom
		var world_under_mouse = screen_to_world(mouse_pos)

		# Now with new zoom, calculate where that world position appears
		map_zoom = temp_zoom
		var new_screen_pos = world_to_screen(world_under_mouse)

		# Adjust pan so the world position stays under the mouse
		map_pan_offset += (mouse_pos - new_screen_pos)


## Speed slider changed callback
func _on_speed_changed(value: float) -> void:
	if not simulation_state:
		return

	# Set speed directly without changing waypoint or heading
	simulation_state.set_target_speed(value)

	# Update display
	if value < 0:
		speed_value_label.text = "%.1f m/s (Reverse)" % value
	else:
		speed_value_label.text = "%.1f m/s" % value


## Depth slider changed callback
func _on_depth_changed(value: float) -> void:
	if not simulation_state:
		return

	# Set depth directly without changing waypoint or speed
	simulation_state.set_target_depth(value)

	# Update display
	depth_value_label.text = "%.0f m" % value


## Convert 3D world position to 2D screen position
func _handle_keyboard_zoom(factor: float) -> void:
	map_zoom *= factor
	map_zoom = clamp(map_zoom, 0.1, 10.0)
	print("TacticalMapView: Zoom changed to %.2f" % map_zoom)


## Convert 3D world position to 2D screen position
func world_to_screen(world_pos: Vector3) -> Vector2:
	if not simulation_state:
		return map_center
	
	# Get submarine position as reference point
	var sub_pos = simulation_state.submarine_position

	# Calculate relative position from submarine
	var relative_pos = Vector2(world_pos.x - sub_pos.x, world_pos.z - sub_pos.z)

	# Apply scale and zoom
	var screen_offset = relative_pos * map_scale * map_zoom

	# Apply to screen center with pan offset
	return map_center + screen_offset + map_pan_offset


## Convert 2D screen position to 3D world position
func screen_to_world(screen_pos: Vector2) -> Vector3:
	if not simulation_state:
		return Vector3.ZERO

	# Get submarine position as reference point
	var sub_pos = simulation_state.submarine_position

	# Calculate screen offset from center
	var screen_offset = screen_pos - map_center - map_pan_offset

	# Remove scale and zoom to get relative world position
	var relative_pos = screen_offset / (map_scale * map_zoom)

	# Add submarine position to get absolute world position
	return Vector3(sub_pos.x + relative_pos.x, 0, sub_pos.z + relative_pos.y)


## Update display every frame
func _process(_delta: float) -> void:
	if not visible or not simulation_state:
		return

	# Requirements 9.2: Progressive loading for smooth zooming
	# Trigger regeneration if zoom changes significantly or we move far enough
	if visible and terrain_texture and terrain_renderer:
		var zoom_changed = abs(map_zoom - _last_generated_zoom) / max(_last_generated_zoom, 0.01) > 0.15
		var pos_diff = simulation_state.submarine_position.distance_to(_last_generated_pos)
		var moved_far = pos_diff > 500.0 # Refresh every 500m
		
		if zoom_changed or moved_far:
			_zoom_settle_timer += _delta
			if _zoom_settle_timer > 0.3: # Settle for 300ms
				# Calculate target LOD for current zoom
				var elevation_provider = terrain_renderer.get_node_or_null("TiledElevationProvider")
				if elevation_provider and elevation_provider.has_method("get_lod_for_zoom"):
					# Calculate meters per pixel based on current zoom and world size
					var viewport_size = get_viewport().get_visible_rect().size
					var screen_width_meters = viewport_size.x / (map_scale * map_zoom)
					var meters_per_pixel = screen_width_meters / 512.0
					_target_lod = elevation_provider.get_lod_for_zoom(meters_per_pixel)
					
					# If we need higher detail and not already loading
					if _target_lod < _current_lod and not _loading_higher_detail:
						print("TacticalMapView: Progressive loading - upgrading from LOD %d to LOD %d (%.1f m/px)" % [_current_lod, _target_lod, meters_per_pixel])
						_loading_higher_detail = true
						_generate_terrain_texture_async()
					elif _target_lod != _current_lod:
						# Direct regeneration for zoom out or first load
						print("TacticalMapView: Resampling terrain (Zoom/Movement) - LOD %d (%.1f m/px)" % [_target_lod, meters_per_pixel])
						_generate_terrain_texture()
				else:
					# Fallback to direct regeneration
					print("TacticalMapView: Resampling terrain (Zoom/Movement)...")
					_generate_terrain_texture()
				_zoom_settle_timer = 0.0
		else:
			_zoom_settle_timer = 0.0
	
	# Try to generate terrain texture if we don't have one yet
	if not terrain_texture and terrain_renderer and not _terrain_generation_attempted:
		var is_init = terrain_renderer.get("initialized")
		if is_init == true:
			_generate_terrain_texture()

	# Update camera to follow submarine
	_update_camera_position()

	# Update submarine display
	_update_submarine_display()

	# Update control sliders to match simulation state (only if changed)
	if speed_slider and abs(speed_slider.value - simulation_state.target_speed) > 0.01:
		speed_slider.set_value_no_signal(simulation_state.target_speed)
		speed_value_label.text = "%.1f m/s" % simulation_state.target_speed

	if depth_slider and abs(depth_slider.value - simulation_state.target_depth) > 0.1:
		depth_slider.set_value_no_signal(simulation_state.target_depth)
		depth_value_label.text = "%.0f m" % simulation_state.target_depth

	# Queue redraw for map canvas and compass
	if map_canvas and visible:
		map_canvas.queue_redraw()
	if compass_indicator and visible:
		compass_indicator.queue_redraw()


## Update camera to follow submarine position
func _update_camera_position() -> void:
	# Camera position is now handled by pan offset
	# We don't need to move the camera anymore
	pass


## Update submarine icon position and info display
func _update_submarine_display() -> void:
	if not simulation_state:
		return

	# Update submarine info label (check if it exists first)
	if not submarine_info_label:
		return

	submarine_info_label.text = (
		"Position: (%.0f, %.0f, %.0f)\n"
		% [
			simulation_state.submarine_position.x,
			simulation_state.submarine_position.y,
			simulation_state.submarine_position.z
		]
	)
	submarine_info_label.text += (
		"Course: %.0f° (Target: %.0f°)\n"
		% [simulation_state.submarine_heading, simulation_state.target_heading]
	)
	submarine_info_label.text += (
		"Speed: %.1f m/s (Target: %.1f m/s)\n"
		% [simulation_state.submarine_speed, simulation_state.target_speed]
	)
	submarine_info_label.text += (
		"Depth: %.0f m (Target: %.0f m)"
		% [simulation_state.submarine_depth, simulation_state.target_depth]
	)


## Draw callback for map canvas
func _on_map_canvas_draw() -> void:
	if not visible or not simulation_state:
		return

	# Draw terrain background
	if show_terrain:
		_draw_terrain()

	# Draw grid (now overlaying the terrain)
	_draw_grid()

	# Draw waypoint (cyan circle) and course line (yellow dotted line)
	_draw_waypoint_and_course()

	# Draw submarine icon (triangle)
	_draw_submarine_icon()

	# Draw contact icons and bearing arcs
	_draw_contacts()

	# Draw scale indicator (on top)
	_draw_scale_indicator()


## Generate terrain texture from heightmap
func _generate_terrain_texture() -> void:
	print("TacticalMapView: Starting terrain texture generation...")

	if not terrain_renderer:
		push_warning("TacticalMapView: Terrain renderer not available")
		return

	if not terrain_renderer.initialized:
		push_warning("TacticalMapView: Terrain renderer not initialized yet")
		return

	# Requirements 9.2: Use TiledElevationProvider for unified elevation data
	var elevation_provider = terrain_renderer.get_node_or_null("TiledElevationProvider")
	if not elevation_provider:
		# Fallback to old provider name for compatibility
		elevation_provider = terrain_renderer.get_node_or_null("ElevationDataProvider")
	if not elevation_provider:
		push_warning("TacticalMapView: No elevation provider available")
		return

	# Check if elevation provider is initialized
	if not elevation_provider.has_method("get_elevation"):
		push_warning("TacticalMapView: Elevation provider not ready")
		return

	print("TacticalMapView: Found elevation provider, generating preview...")

	# Calculate world size needed to cover screen + wide margin to reduce jitter
	var viewport_size = get_viewport().get_visible_rect().size
	var required_world_w = viewport_size.x / (map_scale * map_zoom)
	var required_world_h = viewport_size.y / (map_scale * map_zoom)
	
	terrain_world_size = max(required_world_w, required_world_h) * 1.8 # 80% margin
	_last_generated_zoom = map_zoom
	_last_generated_pos = simulation_state.submarine_position
	
	var start_time = Time.get_ticks_msec()

	# Requirements 9.2: Use extract_region_lod() for zoom-based detail
	var elevation_image: Image = null
	var world_bounds = Rect2(
		simulation_state.submarine_position.x - terrain_world_size/2.0,
		simulation_state.submarine_position.z - terrain_world_size/2.0,
		terrain_world_size,
		terrain_world_size
	)
	
	# Calculate meters per pixel for LOD selection (based on screen width)
	var screen_width_meters = viewport_size.x / (map_scale * map_zoom)
	var meters_per_pixel = screen_width_meters / 512.0  # Using 512x512 output
	
	# Use LOD-based extraction if available (Requirements 8.5, 9.2)
	if elevation_provider.has_method("extract_region_lod") and elevation_provider.has_method("get_lod_for_zoom"):
		var lod_level = elevation_provider.get_lod_for_zoom(meters_per_pixel)
		print("TacticalMapView: Using LOD level %d (%.1f m/px)" % [lod_level, meters_per_pixel])
		elevation_image = elevation_provider.extract_region_lod(world_bounds, lod_level)
	elif elevation_provider.has_method("extract_region"):
		# Fallback to standard extraction
		elevation_image = elevation_provider.extract_region(world_bounds, 512)
	
	if not elevation_image:
		push_error("TacticalMapView: Failed to extract elevation region")
		_terrain_generation_attempted = true
		return

	# Get output resolution from the extracted image
	var preview_size = elevation_image.get_width()

	# Find local min/max for dynamic range
	var local_min = 10000.0
	var local_max = -10000.0
	for y in range(preview_size):
		for x in range(preview_size):
			var px = elevation_image.get_pixel(x, y)
			var elevation = lerp(-10994.0, 8849.0, px.r)
			local_min = min(local_min, elevation)
			local_max = max(local_max, elevation)
			
	print("TacticalMapView: Local elevation range for tactical map: [%.1f, %.1f]" % [local_min, local_max])

	# Get current sea level from manager
	var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0
	print("TacticalMapView: Using sea level: %.0fm for map colorization" % sea_level_meters)

	# Colorize on CPU with dynamic range for better contrast in deep water
	terrain_image = Image.create(preview_size, preview_size, false, Image.FORMAT_RGBA8)
	
	# Color palette
	var abyss_color = Color(0.00, 0.02, 0.10, 1.0)     # Deepest part of local area
	var shallow_blue = Color(0.20, 0.40, 0.80, 1.0)     # shallowest part of local area
	var beach = Color(0.80, 0.75, 0.55, 1.0)            # 0m
	var mount = Color(0.60, 0.60, 0.60, 1.0)            # high land

	for y in range(preview_size):
		for x in range(preview_size):
			var px = elevation_image.get_pixel(x, y)
			var elevation = lerp(-10994.0, 8849.0, px.r)
			
			# Normalize based on local range if in deep water, or use fixed scale if near surface
			var color: Color
			if local_max < -100.0:
				# Use a minimum variation range to avoid amplifying noise in very flat areas
				var min_variation = 300.0 # Standard ocean floor variation scale
				var range_val = max(min_variation, local_max - local_min)
				var t = clamp((elevation - local_min) / range_val, 0.0, 1.0)
				
				# Professional Bathymetric Palette (Deep Blues to Cyan)
				var abyss = Color(0.0, 0.02, 0.08, 1.0)
				var mid_deep = Color(0.01, 0.08, 0.25, 1.0)
				var shelf = Color(0.05, 0.25, 0.50, 1.0)
				
				if t < 0.5:
					color = abyss.lerp(mid_deep, t * 2.0)
				else:
					color = mid_deep.lerp(shelf, (t - 0.5) * 2.0)
			else:
				# Use standard scheme near coastline, adjusted for current sea level
				if elevation < sea_level_meters - 500.0:
					color = abyss_color
				elif elevation < sea_level_meters:
					var t = (elevation - (sea_level_meters - 500.0)) / 500.0
					color = abyss_color.lerp(shallow_blue, t)
				elif elevation < sea_level_meters + 100.0:
					var t = (elevation - sea_level_meters) / 100.0
					color = beach.lerp(Color.DARK_GREEN, t)
				else:
					color = mount
				
			terrain_image.set_pixel(x, y, color)

	# Upscale high quality
	terrain_image.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	terrain_texture = ImageTexture.create_from_image(terrain_image)

	var duration = Time.get_ticks_msec() - start_time
	print("TacticalMapView: Terrain texture generated in %d ms" % duration)
	_terrain_generation_attempted = true
	
	# Update current LOD based on what we just generated
	if elevation_provider.has_method("get_lod_for_zoom"):
		_current_lod = elevation_provider.get_lod_for_zoom(meters_per_pixel)
	else:
		_current_lod = 0  # Assume full detail if LOD not supported


## Generate terrain texture asynchronously for progressive loading
## Requirements 9.2: Implement progressive loading for smooth zooming
func _generate_terrain_texture_async() -> void:
	if not terrain_renderer or not simulation_state:
		_loading_higher_detail = false
		return
	
	var elevation_provider = terrain_renderer.get_node_or_null("TiledElevationProvider")
	if not elevation_provider:
		_loading_higher_detail = false
		return
	
	# Calculate world bounds
	var world_bounds = Rect2(
		simulation_state.submarine_position.x - terrain_world_size/2.0,
		simulation_state.submarine_position.z - terrain_world_size/2.0,
		terrain_world_size,
		terrain_world_size
	)
	
	# Use the target LOD directly (don't recalculate, as it causes infinite loops)
	var lod_level = _target_lod
	
	print("TacticalMapView: Async loading terrain at LOD %d (target)..." % lod_level)
	
	# Extract elevation data at target LOD
	var elevation_image: Image = null
	if elevation_provider.has_method("extract_region_lod"):
		elevation_image = elevation_provider.extract_region_lod(world_bounds, lod_level)
	elif elevation_provider.has_method("extract_region"):
		elevation_image = elevation_provider.extract_region(world_bounds, 512)
	
	if not elevation_image:
		print("TacticalMapView: Failed to load higher detail terrain")
		_loading_higher_detail = false
		return
	
	# Process the image (same as synchronous version)
	var preview_size = elevation_image.get_width()
	
	# Find local min/max
	var local_min = 10000.0
	var local_max = -10000.0
	for y in range(preview_size):
		for x in range(preview_size):
			var px = elevation_image.get_pixel(x, y)
			var elevation = lerp(-10994.0, 8849.0, px.r)
			local_min = min(local_min, elevation)
			local_max = max(local_max, elevation)
	
	# Get sea level
	var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0
	
	# Colorize
	var new_terrain_image = Image.create(preview_size, preview_size, false, Image.FORMAT_RGBA8)
	
	var abyss_color = Color(0.00, 0.02, 0.10, 1.0)
	var shallow_blue = Color(0.20, 0.40, 0.80, 1.0)
	var beach = Color(0.80, 0.75, 0.55, 1.0)
	var mount = Color(0.60, 0.60, 0.60, 1.0)
	
	for y in range(preview_size):
		for x in range(preview_size):
			var px = elevation_image.get_pixel(x, y)
			var elevation = lerp(-10994.0, 8849.0, px.r)
			
			var color: Color
			if local_max < -100.0:
				var min_variation = 300.0
				var range_val = max(min_variation, local_max - local_min)
				var t = clamp((elevation - local_min) / range_val, 0.0, 1.0)
				
				var abyss = Color(0.0, 0.02, 0.08, 1.0)
				var mid_deep = Color(0.01, 0.08, 0.25, 1.0)
				var shelf = Color(0.05, 0.25, 0.50, 1.0)
				
				if t < 0.5:
					color = abyss.lerp(mid_deep, t * 2.0)
				else:
					color = mid_deep.lerp(shelf, (t - 0.5) * 2.0)
			else:
				if elevation < sea_level_meters - 500.0:
					color = abyss_color
				elif elevation < sea_level_meters:
					var t = (elevation - (sea_level_meters - 500.0)) / 500.0
					color = abyss_color.lerp(shallow_blue, t)
				elif elevation < sea_level_meters + 100.0:
					var t = (elevation - sea_level_meters) / 100.0
					color = beach.lerp(Color.DARK_GREEN, t)
				else:
					color = mount
			
			new_terrain_image.set_pixel(x, y, color)
	
	# Upscale
	new_terrain_image.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	
	# Update texture
	terrain_image = new_terrain_image
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	_current_lod = lod_level
	_loading_higher_detail = false
	
	# Update tracking variables to prevent immediate regeneration
	_last_generated_zoom = map_zoom
	_last_generated_pos = simulation_state.submarine_position
	
	print("TacticalMapView: Async terrain load complete at LOD %d" % lod_level)


## Draw terrain as background
func _draw_terrain() -> void:
	if not terrain_texture:
		# Draw a simple fallback background instead of warning every frame
		if not simulation_state:
			return

		# Draw a simple blue ocean background as fallback
		var canvas_size = map_canvas.size
		if canvas_size.x > 0 and canvas_size.y > 0:
			map_canvas.draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.1, 0.2, 0.4, 0.5))
		return

	if not simulation_state:
		return

	# The terrain texture is now centered on the submarine
	# Draw it using the world size it was generated with
	var half_size = terrain_world_size / 2.0

	# Calculate terrain corners in world space (relative to submarine)
	var world_top_left = Vector3(-half_size, 0, -half_size)
	var world_bottom_right = Vector3(half_size, 0, half_size)

	# Convert to screen space
	var screen_top_left = world_to_screen(simulation_state.submarine_position + world_top_left)
	var screen_bottom_right = world_to_screen(
		simulation_state.submarine_position + world_bottom_right
	)

	# Calculate size in screen space
	var screen_size = screen_bottom_right - screen_top_left

	# Draw the terrain texture
	var rect = Rect2(screen_top_left, screen_size)
	map_canvas.draw_texture_rect(terrain_texture, rect, false, Color(1, 1, 1, 1.0))


## Toggle terrain visibility
func _on_terrain_toggle() -> void:
	show_terrain = !show_terrain
	print("TacticalMapView: Terrain visibility: ", show_terrain)


## Create help overlay with all keyboard shortcuts
func _create_help_overlay() -> void:
	help_overlay = Control.new()
	help_overlay.name = "HelpOverlay"
	help_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_overlay.visible = false
	help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input when visible
	add_child(help_overlay)

	# Semi-transparent background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_overlay.add_child(background)

	# Help content container
	var content = VBoxContainer.new()
	content.name = "Content"
	content.position = Vector2(200, 100)
	content.custom_minimum_size = Vector2(1520, 880)
	help_overlay.add_child(content)

	# Title
	var title = Label.new()
	title.text = "TACTICAL MAP - KEYBOARD SHORTCUTS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	content.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	content.add_child(spacer1)

	# Create sections
	var sections = [
		{
			"title": "VIEW CONTROLS",
			"shortcuts":
			[
				["1", "Switch to Tactical Map View"],
				["2", "Switch to Periscope View"],
				["3", "Switch to External View"],
				["F1", "Toggle this Help Screen"],
				["F2", "Toggle Terrain Debug Overlay"],
				["T", "Toggle Terrain Visibility"]
			]
		},
		{
			"title": "MAP NAVIGATION",
			"shortcuts":
			[
				["Mouse Wheel / [ + ] [ - ]", "Zoom In/Out (0.1x to 10x)"],
				["Middle Mouse + Drag", "Pan the Map"],
				["Right Mouse + Drag", "Pan the Map (Alternative)"],
				["C", "Recenter Map on Submarine"],
				["Left Click", "Set Waypoint for Submarine"]
			]
		},
		{
			"title": "SUBMARINE SPEED CONTROL",
			"shortcuts":
			[
				["W or ↑", "Increase Speed (Forward)"],
				["S or ↓", "Decrease Speed (Reverse)"],
				["Space", "Emergency Stop (Set Speed to 0)"],
				["Speed Slider", "Direct Speed Control (-7.5 to 15 m/s)"]
			]
		},
		{
			"title": "SUBMARINE HEADING CONTROL",
			"shortcuts":
			[
				["A or ←", "Turn Left (Port)"],
				["D or →", "Turn Right (Starboard)"],
				["Left Click Map", "Set Course to Waypoint"]
			]
		},
		{
			"title": "SUBMARINE DEPTH CONTROL",
			"shortcuts":
			[
				["Q", "Decrease Depth (Go Shallower)"],
				["E", "Increase Depth (Go Deeper)"],
				["Depth Slider", "Direct Depth Control (-300 to 0 meters)"]
			]
		},
		{
			"title": "MAP DISPLAY",
			"shortcuts":
			[
				["Blue Colors", "Water (Darker = Deeper)"],
				["Sandy Color", "Beach/Coastline"],
				["Green/Brown", "Land Elevation"],
				["Gray", "Mountains"],
				["Green Triangle", "Your Submarine"],
				["Cyan Circle", "Active Waypoint"],
				["Yellow Line", "Course to Waypoint"],
				["Red/Orange Circles", "Detected Contacts"]
			]
		}
	]

	# Add each section
	for section in sections:
		# Section title
		var section_title = Label.new()
		section_title.text = section["title"]
		section_title.add_theme_font_size_override("font_size", 20)
		section_title.add_theme_color_override("font_color", Color(0, 0.8, 1, 1))
		content.add_child(section_title)

		# Section spacer
		var section_spacer = Control.new()
		section_spacer.custom_minimum_size = Vector2(0, 10)
		content.add_child(section_spacer)

		# Shortcuts in this section
		for shortcut in section["shortcuts"]:
			var shortcut_container = HBoxContainer.new()
			shortcut_container.custom_minimum_size = Vector2(0, 25)
			content.add_child(shortcut_container)

			# Key label
			var key_label = Label.new()
			key_label.text = shortcut[0]
			key_label.custom_minimum_size = Vector2(300, 0)
			key_label.add_theme_font_size_override("font_size", 16)
			key_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
			shortcut_container.add_child(key_label)

			# Description label
			var desc_label = Label.new()
			desc_label.text = shortcut[1]
			desc_label.add_theme_font_size_override("font_size", 16)
			desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
			shortcut_container.add_child(desc_label)

		# Section spacer
		var section_spacer2 = Control.new()
		section_spacer2.custom_minimum_size = Vector2(0, 20)
		content.add_child(section_spacer2)

	# Footer
	var footer = Label.new()
	footer.text = "Press F1 or ESC to close this help screen"
	footer.add_theme_font_size_override("font_size", 18)
	footer.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	content.add_child(footer)


## Toggle help overlay
func _toggle_help() -> void:
	show_help = !show_help
	if help_overlay:
		help_overlay.visible = show_help
	print("TacticalMapView: Help overlay: ", show_help)


## Toggle terrain debug overlay
func _toggle_terrain_debug() -> void:
	if not terrain_renderer:
		push_warning("TacticalMapView: Terrain renderer not available")
		print("TacticalMapView: Cannot toggle debug overlay - terrain renderer not found")
		return

	if not terrain_renderer.initialized:
		push_warning("TacticalMapView: Terrain renderer not initialized yet")
		print("TacticalMapView: Cannot toggle debug overlay - terrain not initialized")
		return

	print("TacticalMapView: Toggling terrain debug overlay...")
	terrain_renderer.toggle_debug_overlay()


## Recenter map on submarine
func _on_recenter() -> void:
	map_pan_offset = Vector2.ZERO
	map_zoom = 1.0
	print("TacticalMapView: Recentered on submarine")


## Draw waypoint and course line
func _draw_waypoint_and_course() -> void:
	if not simulation_state:
		return

	var waypoint = simulation_state.target_waypoint

	# Only draw if waypoint is set (not at origin)
	if waypoint.length() > 0.1:
		var submarine_screen_pos = world_to_screen(simulation_state.submarine_position)
		var waypoint_screen_pos = world_to_screen(waypoint)

		# Draw course line (yellow dotted line)
		var line_segments = 20
		var distance = submarine_screen_pos.distance_to(waypoint_screen_pos)
		var dash_length = 10.0
		var gap_length = 5.0
		var total_dash = dash_length + gap_length

		for i in range(line_segments):
			var t_start = float(i) / line_segments
			var t_end = float(i + 1) / line_segments
			var segment_start = submarine_screen_pos.lerp(waypoint_screen_pos, t_start)
			var segment_end = submarine_screen_pos.lerp(waypoint_screen_pos, t_end)

			# Only draw if this segment is in a "dash" part (not gap)
			var segment_distance = t_start * distance
			var dash_position = fmod(segment_distance, total_dash)
			if dash_position < dash_length:
				map_canvas.draw_line(segment_start, segment_end, Color.YELLOW, 2.0)

		# Draw waypoint (cyan circle)
		map_canvas.draw_circle(waypoint_screen_pos, 8.0, Color.CYAN)
		map_canvas.draw_arc(waypoint_screen_pos, 10.0, 0, TAU, 32, Color.CYAN, 2.0)


## Draw submarine icon as a triangle pointing in heading direction
func _draw_submarine_icon() -> void:
	var screen_pos = world_to_screen(simulation_state.submarine_position)
	# Use current submarine_heading to show where sub is actually facing
	var heading_rad = deg_to_rad(simulation_state.submarine_heading)

	# Calculate triangle points for 2D map
	# On screen: Y increases downward, so North (0°) should point up (negative Y)
	# heading=0° → point up, heading=90° → point right, heading=180° → point down
	var size = SUBMARINE_ICON_SIZE / 2

	# Forward point of triangle
	var forward = Vector2(sin(heading_rad), -cos(heading_rad)) * size

	# Left and right base points (perpendicular to forward)
	var perpendicular = Vector2(cos(heading_rad), sin(heading_rad))
	var left = -perpendicular * size * 0.5
	var right = perpendicular * size * 0.5

	var points = PackedVector2Array(
		[screen_pos + forward, screen_pos - forward + left, screen_pos - forward + right]  # Tip of triangle (forward)  # Left base  # Right base
	)

	map_canvas.draw_colored_polygon(points, Color.GREEN)


## Draw contact icons and bearing arcs
func _draw_contacts() -> void:
	var detected_contacts = simulation_state.get_detected_contacts(
		simulation_state.submarine_position
	)
	var submarine_screen_pos = world_to_screen(simulation_state.submarine_position)

	for contact in detected_contacts:
		var contact_screen_pos = world_to_screen(contact.position)

		# Draw bearing line from submarine to contact
		map_canvas.draw_line(submarine_screen_pos, contact_screen_pos, Color.YELLOW, 1.0)

		# Draw contact icon (circle)
		var color = Color.RED if contact.type == Contact.ContactType.AIRCRAFT else Color.ORANGE
		if contact.identified:
			color = Color.CYAN

		map_canvas.draw_circle(contact_screen_pos, CONTACT_ICON_SIZE / 2, color)

		# Draw bearing arc
		var bearing_rad = deg_to_rad(contact.get_bearing())
		var arc_start = bearing_rad - deg_to_rad(15)
		var arc_end = bearing_rad + deg_to_rad(15)

		# Draw arc as line segments
		var arc_points = PackedVector2Array()
		var segments = 10
		for i in range(segments + 1):
			var angle = lerp(arc_start, arc_end, float(i) / segments)
			var point = submarine_screen_pos + Vector2(sin(angle), -cos(angle)) * BEARING_ARC_LENGTH
			arc_points.append(point)

		for i in range(segments):
			map_canvas.draw_line(arc_points[i], arc_points[i + 1], Color.YELLOW, 2.0)


## Draw coordinate grid
func _draw_grid() -> void:
	if not map_canvas:
		return

	var canvas_size = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	# Dynamic grid spacing: Ensure lines are at least 40px apart on screen
	var grid_spacing_world = 100.0 # meters
	while grid_spacing_world * map_scale * map_zoom < 40.0:
		grid_spacing_world *= 2.0
		if grid_spacing_world > 50000.0: break # Safety exit
	
	var grid_spacing_screen = grid_spacing_world * map_scale * map_zoom

	# Don't draw grid if lines would be too close together (redundant now but safe)
	if grid_spacing_screen < 10:
		return

	# Get world bounds visible on screen
	var screen_center = canvas_size / 2
	var world_center = screen_to_world(screen_center)
	var world_half_width = canvas_size.x / (2 * map_scale * map_zoom)
	var world_half_height = canvas_size.y / (2 * map_scale * map_zoom)

	# Calculate grid line positions
	var grid_color = Color(0.3, 0.3, 0.3, 0.5)  # Dark gray, semi-transparent
	var major_grid_color = Color(0.4, 0.4, 0.4, 0.7)  # Slightly brighter for major lines

	# Vertical grid lines (X coordinates)
	var start_x = (
		floor((world_center.x - world_half_width) / grid_spacing_world) * grid_spacing_world
	)
	var end_x = ceil((world_center.x + world_half_width) / grid_spacing_world) * grid_spacing_world

	var x = start_x
	while x <= end_x:
		var screen_x = world_to_screen(Vector3(x, 0, 0)).x
		if screen_x >= 0 and screen_x <= canvas_size.x:
			# Major grid lines every 500m
			var is_major = int(x) % 500 == 0
			var color = major_grid_color if is_major else grid_color
			var width = 2.0 if is_major else 1.0
			map_canvas.draw_line(
				Vector2(screen_x, 0), Vector2(screen_x, canvas_size.y), color, width
			)
		x += grid_spacing_world

	# Horizontal grid lines (Z coordinates)
	var start_z = (
		floor((world_center.z - world_half_height) / grid_spacing_world) * grid_spacing_world
	)
	var end_z = ceil((world_center.z + world_half_height) / grid_spacing_world) * grid_spacing_world

	var z = start_z
	while z <= end_z:
		var screen_y = world_to_screen(Vector3(0, 0, z)).y
		if screen_y >= 0 and screen_y <= canvas_size.y:
			# Major grid lines every 500m
			var is_major = int(z) % 500 == 0
			var color = major_grid_color if is_major else grid_color
			var width = 2.0 if is_major else 1.0
			map_canvas.draw_line(
				Vector2(0, screen_y), Vector2(canvas_size.x, screen_y), color, width
			)
		z += grid_spacing_world


## Draw scale indicator
func _draw_scale_indicator() -> void:
	if not map_canvas:
		return

	var canvas_size = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return

	# Position scale in bottom-right corner
	var scale_pos = Vector2(canvas_size.x - 200, canvas_size.y - 60)
	var scale_width = 150.0
	var scale_height = 40.0

	# Draw background
	var bg_rect = Rect2(scale_pos, Vector2(scale_width, scale_height))
	map_canvas.draw_rect(bg_rect, Color(0, 0, 0, 0.7))
	map_canvas.draw_rect(bg_rect, Color(0.5, 0.5, 0.5, 0.8), false, 2.0)

	# Calculate scale bar length in world units
	var scale_bar_screen_length = 100.0  # pixels
	var scale_bar_world_length = scale_bar_screen_length / (map_scale * map_zoom)

	# Round to nice numbers
	var nice_lengths = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]
	var best_length = nice_lengths[0]
	for length in nice_lengths:
		if length <= scale_bar_world_length:
			best_length = length
		else:
			break

	# Recalculate screen length for the nice world length
	var actual_screen_length = best_length * map_scale * map_zoom

	# Draw scale bar
	var bar_start = scale_pos + Vector2(10, scale_height - 20)
	var bar_end = bar_start + Vector2(actual_screen_length, 0)

	# Draw the bar
	map_canvas.draw_line(bar_start, bar_end, Color.WHITE, 3.0)
	map_canvas.draw_line(bar_start, bar_start + Vector2(0, -5), Color.WHITE, 2.0)
	map_canvas.draw_line(bar_end, bar_end + Vector2(0, -5), Color.WHITE, 2.0)

	# Draw scale text
	var scale_text = (
		"%d m" % best_length if best_length < 1000 else "%.1f km" % (best_length / 1000.0)
	)
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text_size = font.get_string_size(scale_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = bar_start + Vector2(actual_screen_length / 2 - text_size.x / 2, -8)
	map_canvas.draw_string(
		font, text_pos, scale_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE
	)

	# Draw zoom level
	var zoom_text = "Zoom: %.1fx" % map_zoom
	var zoom_pos = scale_pos + Vector2(10, 15)
	map_canvas.draw_string(
		font, zoom_pos, zoom_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8, 1.0)
	)
