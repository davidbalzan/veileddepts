extends CanvasLayer
class_name TacticalMapView

## TacticalMapView provides the 2D strategic interface for submarine command and control.
## Displays submarine position, course, speed, depth, and all detected contacts.
## Handles waypoint placement, speed/depth control, and coordinate conversion.

## Reference to simulation state
var simulation_state: SimulationState

## Reference to terrain renderer
var terrain_renderer: Node = null

## Map display parameters
var map_center: Vector2 = Vector2(960, 540)  # Center of 1920x1080 screen
var map_scale: float = 0.5  # pixels per meter (1 meter = 0.5 pixels) - increased from 0.1
var map_zoom: float = 1.0  # Zoom multiplier
var map_pan_offset: Vector2 = Vector2.ZERO  # Pan offset in pixels

## Terrain visualization
var terrain_texture: ImageTexture = null
var terrain_image: Image = null
var show_terrain: bool = true

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
	# Get simulation state reference from parent if not already set
	if not simulation_state:
		var main_node = get_parent()
		if main_node:
			simulation_state = main_node.get_node_or_null("SimulationState")
			if not simulation_state:
				push_error("TacticalMapView: SimulationState not found")
			
			# Get terrain renderer reference
			terrain_renderer = main_node.get_node_or_null("TerrainRenderer")
			if terrain_renderer:
				# Wait a frame for terrain to initialize
				await get_tree().process_frame
				_generate_terrain_texture()
	
	# Create UI elements
	_create_ui_elements()
	
	print("TacticalMapView: Initialized")


## Create all UI elements for the tactical map
func _create_ui_elements() -> void:
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
		{"angle": 0, "label": "N", "color": Color(1, 0, 0, 1)},      # North - Red
		{"angle": 90, "label": "E", "color": Color(0.5, 0.5, 0.5, 1)},  # East - Gray
		{"angle": 180, "label": "S", "color": Color(0.5, 0.5, 0.5, 1)}, # South - Gray
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
		var text_size = font.get_string_size(dir["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		control.draw_string(font, label_pos - text_size / 2, dir["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, dir["color"])
	
	# Draw submarine heading indicator (green arrow) - shows CURRENT heading
	var heading_rad = deg_to_rad(simulation_state.submarine_heading)
	var heading_vec = Vector2(sin(heading_rad), -cos(heading_rad))  # -cos because -Z is North
	var arrow_end = center + heading_vec * (radius - 5)
	
	# Draw arrow line
	control.draw_line(center, arrow_end, Color(0, 1, 0, 0.9), 3.0)
	
	# Draw arrowhead
	var arrow_size = 6.0
	var arrow_left = arrow_end + Vector2(sin(heading_rad - 2.5), -cos(heading_rad - 2.5)) * arrow_size
	var arrow_right = arrow_end + Vector2(sin(heading_rad + 2.5), -cos(heading_rad + 2.5)) * arrow_size
	control.draw_colored_polygon(PackedVector2Array([arrow_end, arrow_left, arrow_right]), Color(0, 1, 0, 0.9))
	
	# Draw heading text below compass - show current heading
	var heading_text = "%03d°" % int(simulation_state.submarine_heading)
	var heading_text_size = font.get_string_size(heading_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	control.draw_string(font, Vector2(center.x - heading_text_size.x / 2, size - 5), heading_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0, 1, 0, 1))


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
			# Toggle terrain with T key
			elif key_event.keycode == KEY_T:
				_on_terrain_toggle()
				return
			# Recenter with C key
			elif key_event.keycode == KEY_C:
				_on_recenter()
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
			_handle_zoom(1.1)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(0.9)
	
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
	print("Waypoint: screen=%s world=%s heading=%.0f°" % [screen_pos, world_pos, heading_to_waypoint])
	
	# Update submarine command with new waypoint
	# Keep current speed and depth targets
	simulation_state.update_submarine_command(
		world_pos,
		simulation_state.target_speed,
		simulation_state.target_depth
	)
	
	print("TacticalMapView: Waypoint set to ", world_pos)


## Handle zoom input
func _handle_zoom(zoom_factor: float) -> void:
	map_zoom *= zoom_factor
	map_zoom = clamp(map_zoom, MIN_ZOOM, MAX_ZOOM)


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
	
	# Update submarine info label
	submarine_info_label.text = "Position: (%.0f, %.0f, %.0f)\n" % [
		simulation_state.submarine_position.x,
		simulation_state.submarine_position.y,
		simulation_state.submarine_position.z
	]
	submarine_info_label.text += "Course: %.0f° (Target: %.0f°)\n" % [
		simulation_state.submarine_heading,
		simulation_state.target_heading
	]
	submarine_info_label.text += "Speed: %.1f m/s (Target: %.1f m/s)\n" % [
		simulation_state.submarine_speed,
		simulation_state.target_speed
	]
	submarine_info_label.text += "Depth: %.0f m (Target: %.0f m)" % [
		simulation_state.submarine_depth,
		simulation_state.target_depth
	]


## Draw callback for map canvas
func _on_map_canvas_draw() -> void:
	if not visible or not simulation_state:
		return
	
	# Draw terrain background first
	if show_terrain:
		_draw_terrain()
	
	# Draw waypoint (cyan circle) and course line (yellow dotted line)
	_draw_waypoint_and_course()
	
	# Draw submarine icon (triangle)
	_draw_submarine_icon()
	
	# Draw contact icons and bearing arcs
	_draw_contacts()


## Generate terrain texture from heightmap
func _generate_terrain_texture() -> void:
	if not terrain_renderer or not terrain_renderer.initialized:
		push_warning("TacticalMapView: Terrain renderer not available")
		return
	
	# Get heightmap from terrain renderer
	var heightmap = terrain_renderer.heightmap
	if not heightmap:
		push_warning("TacticalMapView: No heightmap available")
		return
	
	var width = heightmap.get_width()
	var height = heightmap.get_height()
	
	# Create colored terrain image
	terrain_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	var sea_level = terrain_renderer.sea_level
	var min_height = terrain_renderer.min_height
	var max_height = terrain_renderer.max_height
	
	# Color palette for terrain
	var deep_water = Color(0.05, 0.1, 0.3, 1.0)      # Dark blue
	var shallow_water = Color(0.1, 0.3, 0.5, 1.0)    # Medium blue
	var beach = Color(0.8, 0.75, 0.5, 1.0)           # Sandy
	var land_low = Color(0.3, 0.5, 0.2, 1.0)         # Green
	var land_high = Color(0.5, 0.4, 0.3, 1.0)        # Brown
	var mountain = Color(0.6, 0.6, 0.6, 1.0)         # Gray
	
	for y in range(height):
		for x in range(width):
			# Get normalized height (0-1)
			var height_normalized = heightmap.get_pixel(x, y).r
			
			# Convert to actual height
			var actual_height = height_normalized * (max_height - min_height) + min_height
			
			# Determine color based on height
			var color: Color
			
			if actual_height < sea_level - 100.0:
				# Deep water
				color = deep_water
			elif actual_height < sea_level - 20.0:
				# Shallow water
				var t = (actual_height - (sea_level - 100.0)) / 80.0
				color = deep_water.lerp(shallow_water, t)
			elif actual_height < sea_level:
				# Very shallow water
				var t = (actual_height - (sea_level - 20.0)) / 20.0
				color = shallow_water.lerp(beach, t)
			elif actual_height < sea_level + 5.0:
				# Beach
				var t = (actual_height - sea_level) / 5.0
				color = beach.lerp(land_low, t)
			elif actual_height < sea_level + 30.0:
				# Low land
				var t = (actual_height - (sea_level + 5.0)) / 25.0
				color = land_low.lerp(land_high, t)
			elif actual_height < sea_level + 60.0:
				# High land
				var t = (actual_height - (sea_level + 30.0)) / 30.0
				color = land_high.lerp(mountain, t)
			else:
				# Mountains
				color = mountain
			
			terrain_image.set_pixel(x, y, color)
	
	# Create texture from image
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	
	print("TacticalMapView: Terrain texture generated (", width, "x", height, ")")


## Draw terrain as background
func _draw_terrain() -> void:
	if not terrain_texture or not terrain_renderer or not simulation_state:
		return
	
	# Get terrain size in world coordinates
	var terrain_size = terrain_renderer.terrain_size
	var half_size_x = terrain_size.x / 2.0
	var half_size_y = terrain_size.y / 2.0
	
	# Calculate terrain corners in world space
	var world_top_left = Vector3(-half_size_x, 0, -half_size_y)
	var world_bottom_right = Vector3(half_size_x, 0, half_size_y)
	
	# Convert to screen space (these will be relative to submarine)
	var screen_top_left = world_to_screen(world_top_left)
	var screen_bottom_right = world_to_screen(world_bottom_right)
	
	# Calculate size in screen space
	var screen_size = screen_bottom_right - screen_top_left
	
	# Draw the terrain texture
	var rect = Rect2(screen_top_left, screen_size)
	map_canvas.draw_texture_rect(terrain_texture, rect, false, Color(1, 1, 1, 0.7))


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
			"shortcuts": [
				["1", "Switch to Tactical Map View"],
				["2", "Switch to Periscope View"],
				["3", "Switch to External View"],
				["F1", "Toggle this Help Screen"],
				["T", "Toggle Terrain Visibility"]
			]
		},
		{
			"title": "MAP NAVIGATION",
			"shortcuts": [
				["Mouse Wheel Up/Down", "Zoom In/Out (0.1x to 10x)"],
				["Middle Mouse + Drag", "Pan the Map"],
				["Right Mouse + Drag", "Pan the Map (Alternative)"],
				["C", "Recenter Map on Submarine"],
				["Left Click", "Set Waypoint for Submarine"]
			]
		},
		{
			"title": "SUBMARINE SPEED CONTROL",
			"shortcuts": [
				["W or ↑", "Increase Speed (Forward)"],
				["S or ↓", "Decrease Speed (Reverse)"],
				["Space", "Emergency Stop (Set Speed to 0)"],
				["Speed Slider", "Direct Speed Control (-7.5 to 15 m/s)"]
			]
		},
		{
			"title": "SUBMARINE HEADING CONTROL",
			"shortcuts": [
				["A or ←", "Turn Left (Port)"],
				["D or →", "Turn Right (Starboard)"],
				["Left Click Map", "Set Course to Waypoint"]
			]
		},
		{
			"title": "SUBMARINE DEPTH CONTROL",
			"shortcuts": [
				["Q", "Decrease Depth (Go Shallower)"],
				["E", "Increase Depth (Go Deeper)"],
				["Depth Slider", "Direct Depth Control (-300 to 0 meters)"]
			]
		},
		{
			"title": "MAP DISPLAY",
			"shortcuts": [
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
	
	var points = PackedVector2Array([
		screen_pos + forward,           # Tip of triangle (forward)
		screen_pos - forward + left,    # Left base
		screen_pos - forward + right    # Right base
	])
	
	map_canvas.draw_colored_polygon(points, Color.GREEN)


## Draw contact icons and bearing arcs
func _draw_contacts() -> void:
	var detected_contacts = simulation_state.get_detected_contacts(simulation_state.submarine_position)
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
