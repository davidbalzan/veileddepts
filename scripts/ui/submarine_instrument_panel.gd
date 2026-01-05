# DEPRECATED: This file is replaced by submarine_metrics_panel.gd
# Marked for deletion
extends PanelContainer
class_name SubmarineInstrumentPanel

## Submarine Instrument Panel
## Displays real-time submarine metrics with gauges and visual indicators
## Draggable panel that can be positioned anywhere on screen

var simulation_state: SimulationState
var submarine_body: RigidBody3D

# UI elements
var _drag_handle: Panel
var _metrics_grid: GridContainer
var _speed_gauge: TextureProgressBar
var _depth_gauge: TextureProgressBar
var _pitch_indicator: Control
var _heading_compass: Control

# Drag state
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# Labels for numeric displays
var _speed_label: Label
var _target_speed_label: Label
var _depth_label: Label
var _target_depth_label: Label
var _pitch_label: Label
var _heading_label: Label
var _target_heading_label: Label
var _ascent_rate_label: Label
var _dive_plane_label: Label

# Previous depth for ascent rate calculation
var _previous_depth: float = 0.0
var _ascent_rate_samples: Array[float] = []
const ASCENT_RATE_SAMPLES: int = 10


func _ready() -> void:
	# Set panel properties
	custom_minimum_size = Vector2(800, 200)
	
	# Create panel background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.7, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)
	
	# Main container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	
	# Drag handle
	_drag_handle = Panel.new()
	_drag_handle.custom_minimum_size = Vector2(0, 30)
	var handle_style = StyleBoxFlat.new()
	handle_style.bg_color = Color(0.2, 0.3, 0.4, 1.0)
	_drag_handle.add_theme_stylebox_override("panel", handle_style)
	vbox.add_child(_drag_handle)
	
	var handle_label = Label.new()
	handle_label.text = "SUBMARINE INSTRUMENTS (Drag to move • I to toggle)"
	handle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handle_label.add_theme_font_size_override("font_size", 14)
	handle_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	handle_label.position = Vector2(10, 7)
	_drag_handle.add_child(handle_label)
	
	# Content container with margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(margin)
	
	# Grid for metrics
	_metrics_grid = GridContainer.new()
	_metrics_grid.columns = 4
	_metrics_grid.add_theme_constant_override("h_separation", 20)
	_metrics_grid.add_theme_constant_override("v_separation", 10)
	margin.add_child(_metrics_grid)
	
	# Create metric displays
	_create_speed_section()
	_create_depth_section()
	_create_attitude_section()
	_create_heading_section()
	
	# Position at bottom center initially
	call_deferred("_position_panel")


func _position_panel() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	position = Vector2(
		(viewport_size.x - size.x) / 2,
		viewport_size.y - size.y - 20
	)


func _create_speed_section() -> void:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(180, 0)
	
	var title = Label.new()
	title.text = "SPEED"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	container.add_child(title)
	
	_speed_label = Label.new()
	_speed_label.text = "0.0 m/s"
	_speed_label.add_theme_font_size_override("font_size", 24)
	_speed_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	container.add_child(_speed_label)
	
	_target_speed_label = Label.new()
	_target_speed_label.text = "Target: 0.0 m/s"
	_target_speed_label.add_theme_font_size_override("font_size", 12)
	_target_speed_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(_target_speed_label)
	
	_metrics_grid.add_child(container)


func _create_depth_section() -> void:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(180, 0)
	
	var title = Label.new()
	title.text = "DEPTH"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	container.add_child(title)
	
	_depth_label = Label.new()
	_depth_label.text = "0.0 m"
	_depth_label.add_theme_font_size_override("font_size", 24)
	_depth_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	container.add_child(_depth_label)
	
	_target_depth_label = Label.new()
	_target_depth_label.text = "Target: 0.0 m"
	_target_depth_label.add_theme_font_size_override("font_size", 12)
	_target_depth_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(_target_depth_label)
	
	_ascent_rate_label = Label.new()
	_ascent_rate_label.text = "Rate: 0.0 m/s"
	_ascent_rate_label.add_theme_font_size_override("font_size", 12)
	_ascent_rate_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	container.add_child(_ascent_rate_label)
	
	_metrics_grid.add_child(container)


func _create_attitude_section() -> void:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(180, 0)
	
	var title = Label.new()
	title.text = "ATTITUDE"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	container.add_child(title)
	
	_pitch_label = Label.new()
	_pitch_label.text = "Pitch: 0.0°"
	_pitch_label.add_theme_font_size_override("font_size", 18)
	_pitch_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	container.add_child(_pitch_label)
	
	_dive_plane_label = Label.new()
	_dive_plane_label.text = "Planes: 0.0°"
	_dive_plane_label.add_theme_font_size_override("font_size", 12)
	_dive_plane_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(_dive_plane_label)
	
	# Visual pitch indicator
	_pitch_indicator = Control.new()
	_pitch_indicator.custom_minimum_size = Vector2(150, 40)
	_pitch_indicator.draw.connect(_draw_pitch_indicator)
	container.add_child(_pitch_indicator)
	
	_metrics_grid.add_child(container)


func _create_heading_section() -> void:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(180, 0)
	
	var title = Label.new()
	title.text = "HEADING"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	container.add_child(title)
	
	_heading_label = Label.new()
	_heading_label.text = "000°"
	_heading_label.add_theme_font_size_override("font_size", 24)
	_heading_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	container.add_child(_heading_label)
	
	_target_heading_label = Label.new()
	_target_heading_label.text = "Target: 000°"
	_target_heading_label.add_theme_font_size_override("font_size", 12)
	_target_heading_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(_target_heading_label)
	
	# Visual compass
	_heading_compass = Control.new()
	_heading_compass.custom_minimum_size = Vector2(150, 40)
	_heading_compass.draw.connect(_draw_heading_compass)
	container.add_child(_heading_compass)
	
	_metrics_grid.add_child(container)


func _draw_pitch_indicator() -> void:
	if not _pitch_indicator or not submarine_body:
		return
	
	var size = _pitch_indicator.size
	var center = Vector2(size.x / 2, size.y / 2)
	var pitch_rad = submarine_body.rotation.x
	var pitch_deg = rad_to_deg(pitch_rad)
	
	# Background
	_pitch_indicator.draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.1, 0.5))
	
	# Horizon line
	var horizon_y = center.y - pitch_deg * 0.5  # Scale for visibility
	horizon_y = clamp(horizon_y, 0, size.y)
	_pitch_indicator.draw_line(Vector2(0, horizon_y), Vector2(size.x, horizon_y), Color(0.3, 0.8, 1.0), 2.0)
	
	# Center reference
	_pitch_indicator.draw_line(Vector2(0, center.y), Vector2(size.x, center.y), Color(0.5, 0.5, 0.5, 0.5), 1.0)
	
	# Submarine icon
	var sub_points = PackedVector2Array([
		center + Vector2(-15, 0),
		center + Vector2(-5, -5),
		center + Vector2(15, 0),
		center + Vector2(-5, 5)
	])
	_pitch_indicator.draw_colored_polygon(sub_points, Color(1.0, 1.0, 0.5))


func _draw_heading_compass() -> void:
	if not _heading_compass or not simulation_state:
		return
	
	var size = _heading_compass.size
	var center = Vector2(size.x / 2, size.y / 2)
	var radius = min(size.x, size.y) / 2 - 5
	
	# Background circle
	_heading_compass.draw_circle(center, radius, Color(0.1, 0.1, 0.1, 0.5))
	_heading_compass.draw_arc(center, radius, 0, TAU, 32, Color(0.3, 0.5, 0.7), 2.0)
	
	# Current heading arrow
	var heading_rad = deg_to_rad(simulation_state.submarine_heading)
	var arrow_end = center + Vector2(sin(heading_rad), -cos(heading_rad)) * radius * 0.8
	_heading_compass.draw_line(center, arrow_end, Color(0.9, 1.0, 0.9), 3.0)
	
	# Target heading arrow
	var target_rad = deg_to_rad(simulation_state.target_heading)
	var target_end = center + Vector2(sin(target_rad), -cos(target_rad)) * radius * 0.6
	_heading_compass.draw_line(center, target_end, Color(1.0, 0.8, 0.3), 2.0, true)
	
	# North indicator
	_heading_compass.draw_line(center + Vector2(0, -radius), center + Vector2(0, -radius + 8), Color(1.0, 0.3, 0.3), 2.0)


func _process(delta: float) -> void:
	if not visible:
		return
	
	_update_displays(delta)
	
	# Queue redraws for visual indicators
	if _pitch_indicator:
		_pitch_indicator.queue_redraw()
	if _heading_compass:
		_heading_compass.queue_redraw()


func _update_displays(delta: float) -> void:
	if not simulation_state or not submarine_body:
		return
	
	# Speed
	var speed = simulation_state.submarine_velocity.length()
	_speed_label.text = "%.1f m/s" % speed
	_target_speed_label.text = "Target: %.1f m/s" % simulation_state.target_speed
	
	# Color code speed (green = on target, yellow = adjusting)
	var speed_diff = abs(speed - simulation_state.target_speed)
	if speed_diff < 0.5:
		_speed_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		_speed_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	
	# Depth
	var depth = simulation_state.submarine_depth
	_depth_label.text = "%.1f m" % depth
	_target_depth_label.text = "Target: %.1f m" % simulation_state.target_depth
	
	# Color code depth
	var depth_diff = abs(depth - simulation_state.target_depth)
	if depth_diff < 1.0:
		_depth_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	elif depth < 10.0:
		_depth_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red near surface
	else:
		_depth_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	
	# Ascent rate
	var ascent_rate = (_previous_depth - depth) / delta
	_ascent_rate_samples.append(ascent_rate)
	if _ascent_rate_samples.size() > ASCENT_RATE_SAMPLES:
		_ascent_rate_samples.pop_front()
	
	var avg_ascent_rate = 0.0
	for rate in _ascent_rate_samples:
		avg_ascent_rate += rate
	avg_ascent_rate /= _ascent_rate_samples.size()
	
	_ascent_rate_label.text = "Rate: %.2f m/s" % avg_ascent_rate
	if avg_ascent_rate > 0.1:
		_ascent_rate_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green ascending
	elif avg_ascent_rate < -0.1:
		_ascent_rate_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))  # Blue descending
	else:
		_ascent_rate_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	
	_previous_depth = depth
	
	# Pitch
	var pitch_deg = rad_to_deg(submarine_body.rotation.x)
	_pitch_label.text = "Pitch: %.1f°" % pitch_deg
	
	# Color code pitch (green = level, yellow/red = angled)
	if abs(pitch_deg) < 2.0:
		_pitch_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	elif abs(pitch_deg) < 10.0:
		_pitch_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	else:
		_pitch_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	
	# Dive planes (approximate from pitch and depth error)
	var depth_error = simulation_state.target_depth - depth
	var desired_pitch = -depth_error / 150.0  # Simplified calculation
	var plane_angle = clamp(desired_pitch, -15.0, 15.0)
	_dive_plane_label.text = "Planes: %.1f°" % plane_angle
	
	# Heading
	_heading_label.text = "%03d°" % int(simulation_state.submarine_heading)
	_target_heading_label.text = "Target: %03d°" % int(simulation_state.target_heading)
	
	# Color code heading
	var heading_diff = abs(simulation_state.submarine_heading - simulation_state.target_heading)
	if heading_diff > 180:
		heading_diff = 360 - heading_diff
	if heading_diff < 5.0:
		_heading_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		_heading_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Check if click is on drag handle
				var local_pos = _drag_handle.get_local_mouse_position()
				if Rect2(Vector2.ZERO, _drag_handle.size).has_point(local_pos):
					_is_dragging = true
					_drag_offset = get_global_mouse_position() - global_position
			else:
				_is_dragging = false
	
	elif event is InputEventMouseMotion and _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset


func initialize(p_simulation_state: SimulationState, p_submarine_body: RigidBody3D) -> void:
	simulation_state = p_simulation_state
	submarine_body = p_submarine_body
	print("SubmarineInstrumentPanel: Initialized")
