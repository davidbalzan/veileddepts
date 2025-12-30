extends CanvasLayer
class_name TacticalMapView

## TacticalMapView provides the 2D strategic interface for submarine command and control.
## Displays submarine position, course, speed, depth, and all detected contacts.
## Handles waypoint placement, speed/depth control, and coordinate conversion.

## Reference to simulation state
var simulation_state: SimulationState

## Map display parameters
var map_center: Vector2 = Vector2(960, 540)  # Center of 1920x1080 screen
var map_scale: float = 0.1  # pixels per meter (1 meter = 0.1 pixels)
var map_zoom: float = 1.0  # Zoom multiplier
var map_pan_offset: Vector2 = Vector2.ZERO  # Pan offset in pixels

## UI element references
var map_canvas: Control  # Canvas for drawing submarine and contacts
var submarine_info_label: Label
var speed_slider: HSlider
var depth_slider: HSlider
var speed_value_label: Label
var depth_value_label: Label

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
const MAX_ZOOM: float = 5.0


func _ready() -> void:
	# Get simulation state reference from parent if not already set
	if not simulation_state:
		var main_node = get_parent()
		if main_node:
			simulation_state = main_node.get_node_or_null("SimulationState")
			if not simulation_state:
				push_error("TacticalMapView: SimulationState not found")
	
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
	speed_label.text = "Speed (m/s):"
	speed_label.add_theme_font_size_override("font_size", 14)
	control_panel.add_child(speed_label)
	
	speed_slider = HSlider.new()
	speed_slider.name = "SpeedSlider"
	speed_slider.min_value = 0.0
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
	instructions.text = "Left Click: Set Waypoint\nMouse Wheel: Zoom\nMiddle Mouse Drag: Pan"
	add_child(instructions)


## Handle input events for waypoint placement and map control
func _input(event: InputEvent) -> void:
	# Only process input when this view is visible
	if not visible:
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
	
	# Update submarine command with new speed
	simulation_state.update_submarine_command(
		simulation_state.target_waypoint,
		value,
		simulation_state.target_depth
	)
	
	# Update display
	speed_value_label.text = "%.1f m/s" % value


## Depth slider changed callback
func _on_depth_changed(value: float) -> void:
	if not simulation_state:
		return
	
	# Update submarine command with new depth
	simulation_state.update_submarine_command(
		simulation_state.target_waypoint,
		simulation_state.target_speed,
		value
	)
	
	# Update display
	depth_value_label.text = "%.0f m" % value


## Convert 3D world position to 2D screen position
func world_to_screen(world_pos: Vector3) -> Vector2:
	# Project 3D position to 2D (ignore Y coordinate)
	var map_pos = Vector2(world_pos.x, world_pos.z)
	
	# Apply scale and zoom
	var screen_pos = map_pos * map_scale * map_zoom
	
	# Apply pan offset and center on screen
	screen_pos += map_center + map_pan_offset
	
	return screen_pos


## Convert 2D screen position to 3D world position
func screen_to_world(screen_pos: Vector2) -> Vector3:
	# Remove pan offset and center
	var map_pos = screen_pos - map_center - map_pan_offset
	
	# Remove scale and zoom
	map_pos /= (map_scale * map_zoom)
	
	# Convert to 3D (Y = 0 for surface level)
	return Vector3(map_pos.x, 0, map_pos.y)


## Update display every frame
func _process(_delta: float) -> void:
	if not visible or not simulation_state:
		return
	
	# Update submarine display
	_update_submarine_display()
	
	# Update control sliders to match simulation state (only if changed)
	if speed_slider and abs(speed_slider.value - simulation_state.target_speed) > 0.01:
		speed_slider.set_value_no_signal(simulation_state.target_speed)
		speed_value_label.text = "%.1f m/s" % simulation_state.target_speed
	
	if depth_slider and abs(depth_slider.value - simulation_state.target_depth) > 0.1:
		depth_slider.set_value_no_signal(simulation_state.target_depth)
		depth_value_label.text = "%.0f m" % simulation_state.target_depth
	
	# Queue redraw for map canvas only if needed
	if map_canvas and visible:
		map_canvas.queue_redraw()


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
	submarine_info_label.text += "Course: %.0f°\n" % simulation_state.submarine_heading
	submarine_info_label.text += "Speed: %.1f m/s\n" % simulation_state.submarine_speed
	submarine_info_label.text += "Depth: %.0f m" % simulation_state.submarine_depth


## Draw callback for map canvas
func _on_map_canvas_draw() -> void:
	if not visible or not simulation_state:
		return
	
	# Draw submarine icon (triangle)
	_draw_submarine_icon()
	
	# Draw contact icons and bearing arcs
	_draw_contacts()


## Draw submarine icon as a triangle pointing in heading direction
func _draw_submarine_icon() -> void:
	var screen_pos = world_to_screen(simulation_state.submarine_position)
	var heading_rad = deg_to_rad(simulation_state.submarine_heading)
	
	# Calculate triangle points
	var size = SUBMARINE_ICON_SIZE / 2
	var forward = Vector2(sin(heading_rad), -cos(heading_rad)) * size
	var left = Vector2(-cos(heading_rad), -sin(heading_rad)) * size * 0.5
	var right = Vector2(cos(heading_rad), sin(heading_rad)) * size * 0.5
	
	var points = PackedVector2Array([
		screen_pos + forward,
		screen_pos - forward + left,
		screen_pos - forward + right
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
