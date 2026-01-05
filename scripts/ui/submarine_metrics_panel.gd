extends PanelContainer
class_name SubmarineMetricsPanel

## Submarine Metrics Panel
## Displays comprehensive submarine telemetry with visual gauges and indicators
## Draggable panel that can be positioned anywhere on screen

signal panel_moved(new_position: Vector2)

# References
var simulation_state: SimulationState
var submarine_body: RigidBody3D

# UI Elements - Labels
var speed_value: Label
var heading_value: Label
var target_heading_value: Label
var depth_value: Label
var target_depth_value: Label
var pitch_value: Label
var ascent_rate_value: Label
var dive_plane_angle_value: Label

# UI Elements - Gauges (Control nodes for custom drawing)
var speed_gauge: Control
var depth_gauge: Control
var pitch_indicator: Control
var heading_compass: Control
var _ascent_arrow_label: Label  # Direct reference to ascent arrow

# Panel state
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Cached values for smoothing
var _last_ascent_rate: float = 0.0
var _ascent_rate_history: Array[float] = []
const ASCENT_RATE_HISTORY_SIZE: int = 10

# Fonts
var title_font: Font
var label_font: Font
var value_font: Font


func _ready() -> void:
	# Setup panel appearance
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.2, 0.95)
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
	
	custom_minimum_size = Vector2(850, 150)
	
	# Ensure panel is visible
	visible = true
	show()
	
	# Setup dragging
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Build UI
	_build_ui()
	
	print("SubmarineMetricsPanel: _ready() called, visible=", visible, " size=", size)
	
	# Find references
	call_deferred("_find_references")


func _find_references() -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		simulation_state = main.get_node_or_null("SimulationState")
		submarine_body = main.get_node_or_null("SubmarineModel")
	
	if not simulation_state:
		push_warning("SubmarineMetricsPanel: SimulationState not found")
	if not submarine_body:
		push_warning("SubmarineMetricsPanel: SubmarineModel not found")
	
	print("SubmarineMetricsPanel: References found - sim_state=", simulation_state != null, " sub_body=", submarine_body != null)


func _build_ui() -> void:
	# Main container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Title bar with drag handle
	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)
	
	var drag_icon = Label.new()
	drag_icon.text = "☰"
	drag_icon.add_theme_font_size_override("font_size", 20)
	drag_icon.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	title_bar.add_child(drag_icon)
	
	var title = Label.new()
	title.text = "  SUBMARINE TELEMETRY"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	# Main content - horizontal layout
	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	vbox.add_child(content)
	
	# Left section - Text metrics
	var left_panel = VBoxContainer.new()
	left_panel.add_theme_constant_override("separation", 4)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(left_panel)
	
	_add_metric_row(left_panel, "Speed:", "0.0 m/s", "speed")
	_add_metric_row(left_panel, "Heading:", "000°", "heading")
	_add_metric_row(left_panel, "Target Hdg:", "000°", "target_heading")
	_add_metric_row(left_panel, "Depth:", "0.0 m", "depth")
	_add_metric_row(left_panel, "Target Depth:", "0.0 m", "target_depth")
	
	# Middle section - More metrics
	var middle_panel = VBoxContainer.new()
	middle_panel.add_theme_constant_override("separation", 4)
	middle_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(middle_panel)
	
	_add_metric_row(middle_panel, "Pitch:", "0.0°", "pitch")
	_add_metric_row(middle_panel, "Ascent Rate:", "0.0 m/s", "ascent_rate")
	_add_metric_row(middle_panel, "Dive Planes:", "0.0°", "dive_plane")
	
	# Add vertical arrow indicator for ascent/descent
	var ascent_arrow = Label.new()
	ascent_arrow.name = "AscentArrow"
	ascent_arrow.text = "--"
	ascent_arrow.add_theme_font_size_override("font_size", 28)
	ascent_arrow.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	ascent_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ascent_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ascent_arrow.custom_minimum_size = Vector2(60, 40)
	middle_panel.add_child(ascent_arrow)
	# Store reference directly instead of using unique_name
	_ascent_arrow_label = ascent_arrow
	print("SubmarineMetricsPanel: Ascent arrow created and added to middle_panel")
	
	# Right section - Control buttons and gauges
	var right_section = VBoxContainer.new()
	right_section.add_theme_constant_override("separation", 10)
	content.add_child(right_section)
	
	# Control buttons row
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	right_section.add_child(button_row)
	
	var level_button = Button.new()
	level_button.text = "LEVEL SUB"
	level_button.custom_minimum_size = Vector2(100, 32)
	level_button.pressed.connect(_on_level_sub_pressed)
	button_row.add_child(level_button)
	
	var surface_button = Button.new()
	surface_button.text = "SURFACE"
	surface_button.custom_minimum_size = Vector2(100, 32)
	surface_button.pressed.connect(_on_emergency_surface_pressed)
	button_row.add_child(surface_button)
	
	var trim_button = Button.new()
	trim_button.text = "RESET TRIM"
	trim_button.custom_minimum_size = Vector2(100, 32)
	trim_button.pressed.connect(_on_reset_trim_pressed)
	button_row.add_child(trim_button)
	
	# Gauge panel
	var gauge_panel = HBoxContainer.new()
	gauge_panel.add_theme_constant_override("separation", 15)
	right_section.add_child(gauge_panel)
	
	# Speed gauge
	var speed_container = VBoxContainer.new()
	gauge_panel.add_child(speed_container)
	var speed_label = Label.new()
	speed_label.text = "SPEED"
	speed_label.add_theme_font_size_override("font_size", 11)
	speed_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_container.add_child(speed_label)
	speed_gauge = Control.new()
	speed_gauge.custom_minimum_size = Vector2(110, 110)
	speed_gauge.draw.connect(_draw_speed_gauge)
	speed_container.add_child(speed_gauge)
	
	# Pitch indicator (attitude)
	var pitch_container = VBoxContainer.new()
	gauge_panel.add_child(pitch_container)
	var pitch_label = Label.new()
	pitch_label.text = "ATTITUDE"
	pitch_label.add_theme_font_size_override("font_size", 11)
	pitch_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	pitch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch_container.add_child(pitch_label)
	pitch_indicator = Control.new()
	pitch_indicator.custom_minimum_size = Vector2(110, 110)
	pitch_indicator.draw.connect(_draw_pitch_indicator)
	pitch_container.add_child(pitch_indicator)
	
	# Depth gauge
	var depth_container = VBoxContainer.new()
	gauge_panel.add_child(depth_container)
	var depth_label = Label.new()
	depth_label.text = "DEPTH"
	depth_label.add_theme_font_size_override("font_size", 11)
	depth_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_container.add_child(depth_label)
	depth_gauge = Control.new()
	depth_gauge.custom_minimum_size = Vector2(110, 110)
	depth_gauge.draw.connect(_draw_depth_gauge)
	depth_container.add_child(depth_gauge)


func _add_metric_row(parent: VBoxContainer, label_text: String, value_text: String, id: String) -> void:
	var row = HBoxContainer.new()
	parent.add_child(row)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	
	# Store reference
	match id:
		"speed": speed_value = value
		"heading": heading_value = value
		"target_heading": target_heading_value = value
		"depth": depth_value = value
		"target_depth": target_depth_value = value
		"pitch": pitch_value = value
		"ascent_rate": ascent_rate_value = value
		"dive_plane": dive_plane_angle_value = value


func _process(_delta: float) -> void:
	if not visible:
		return
	
	_update_metrics()
	
	# Queue redraw for gauges
	if speed_gauge:
		speed_gauge.queue_redraw()
	if depth_gauge:
		depth_gauge.queue_redraw()
	if pitch_indicator:
		pitch_indicator.queue_redraw()


func _update_metrics() -> void:
	if not simulation_state or not submarine_body:
		return
	
	# Speed
	var speed = simulation_state.submarine_speed
	if speed_value:
		speed_value.text = "%.1f m/s" % speed
		# Color code by speed
		if speed > 8.0:
			speed_value.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red - fast
		elif speed > 5.0:
			speed_value.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))  # Yellow
		else:
			speed_value.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green - slow
	
	# Heading
	if heading_value:
		heading_value.text = "%03d°" % int(simulation_state.submarine_heading)
	
	if target_heading_value:
		target_heading_value.text = "%03d°" % int(simulation_state.target_heading)
	
	# Depth
	var depth = simulation_state.submarine_depth
	if depth_value:
		depth_value.text = "%.1f m" % depth
		# Color code by depth
		if depth < 0:
			depth_value.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red - surfaced
		elif depth < 10:
			depth_value.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))  # Yellow - shallow
		else:
			depth_value.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))  # Blue - deep
	
	if target_depth_value:
		target_depth_value.text = "%.1f m" % simulation_state.target_depth
	
	# Pitch angle
	var pitch_rad = submarine_body.rotation.x
	var pitch_deg = rad_to_deg(pitch_rad)
	if pitch_value:
		pitch_value.text = "%+.1f°" % pitch_deg
		# Color code by pitch
		if abs(pitch_deg) > 15:
			pitch_value.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red - steep
		elif abs(pitch_deg) > 5:
			pitch_value.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))  # Yellow
		else:
			pitch_value.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green - level
	
	# Ascent rate (smoothed)
	var current_pos_y = submarine_body.global_position.y
	var velocity_y = submarine_body.linear_velocity.y
	_ascent_rate_history.append(velocity_y)
	if _ascent_rate_history.size() > ASCENT_RATE_HISTORY_SIZE:
		_ascent_rate_history.pop_front()
	
	var avg_rate = 0.0
	for rate in _ascent_rate_history:
		avg_rate += rate
	avg_rate /= _ascent_rate_history.size()
	
	if ascent_rate_value:
		ascent_rate_value.text = "%+.2f m/s" % avg_rate
		# Color code by rate
		if avg_rate > 0.5:
			ascent_rate_value.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green - ascending
		elif avg_rate < -0.5:
			ascent_rate_value.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red - descending
		else:
			ascent_rate_value.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))  # Yellow - stable
	
	# Update ascent arrow visual indicator
	if _ascent_arrow_label:
		if avg_rate > 0.2:
			_ascent_arrow_label.text = "↑↑"  # Double up arrow
			_ascent_arrow_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		elif avg_rate > 0.05:
			_ascent_arrow_label.text = "↑"  # Single up arrow
			_ascent_arrow_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		elif avg_rate < -0.2:
			_ascent_arrow_label.text = "↓↓"  # Double down arrow
			_ascent_arrow_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		elif avg_rate < -0.05:
			_ascent_arrow_label.text = "↓"  # Single down arrow
			_ascent_arrow_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
		else:
			_ascent_arrow_label.text = "--"  # Stable
			_ascent_arrow_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	# Dive plane angle - get actual commanded angle from physics
	# The dive plane system in submarine_physics_v2 calculates the real angle
	# We need to extract it from the torque or calculate it the same way
	var dive_plane_angle = 0.0
	if submarine_body and submarine_body.has_method("get_dive_plane_angle"):
		dive_plane_angle = submarine_body.get_dive_plane_angle()
	else:
		# Fallback: calculate similar to dive plane system but with rolloff
		var depth_error = simulation_state.target_depth - depth
		var vertical_velocity = submarine_body.linear_velocity.y if submarine_body else 0.0
		var predicted_depth = depth + (vertical_velocity * 3.0)
		var predicted_error = simulation_state.target_depth - predicted_depth
		var blended_error = (predicted_error * 0.7) + (depth_error * 0.3)
		dive_plane_angle = clamp(-blended_error / 75.0, -15, 15)
		
		# Apply pitch limit rolloff (same as dive_plane_system.gd)
		var current_pitch_deg = rad_to_deg(submarine_body.rotation.x) if submarine_body else 0.0
		var abs_pitch = abs(current_pitch_deg)
		if abs_pitch > 15.0:
			var rolloff_progress = (abs_pitch - 15.0) / 10.0  # 15-25° range
			var authority_factor = 1.0 - clamp(rolloff_progress, 0.0, 1.0)
			dive_plane_angle *= authority_factor
	
	if dive_plane_angle_value:
		dive_plane_angle_value.text = "%+.1f°" % dive_plane_angle


func _draw_speed_gauge() -> void:
	if not speed_gauge or not simulation_state:
		return
	
	var gauge_size = speed_gauge.size
	var center = gauge_size / 2
	var radius = min(gauge_size.x, gauge_size.y) / 2 - 10
	
	# Background circle
	speed_gauge.draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.3, 0.4, 0.5), 3.0)
	
	# Speed arc (0-10 m/s range)
	var speed = simulation_state.submarine_speed
	var max_speed = 10.3
	var speed_ratio = clamp(speed / max_speed, 0.0, 1.0)
	var arc_angle = speed_ratio * TAU * 0.75  # 270 degrees
	
	# Color gradient based on speed
	var color = Color.GREEN.lerp(Color.RED, speed_ratio)
	speed_gauge.draw_arc(center, radius, -PI/2, -PI/2 + arc_angle, 32, color, 5.0)
	
	# Center text
	var text = "%.1f" % speed
	var font = ThemeDB.fallback_font
	var font_size = 24
func _draw_depth_gauge() -> void:
	if not depth_gauge or not simulation_state:
		return
	
	var gauge_size = depth_gauge.size
	var center = gauge_size / 2
	var radius = min(gauge_size.x, gauge_size.y) / 2 - 10
	
	# Background circle
	depth_gauge.draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.3, 0.4, 0.5), 3.0)
	
	# Depth arc (0-400m range, inverted so clockwise = deeper)
	var depth = simulation_state.submarine_depth
	var max_depth = 400.0
	var depth_ratio = clamp(depth / max_depth, 0.0, 1.0)
	var arc_angle = depth_ratio * TAU * 0.75  # 270 degrees
	
	# Color gradient based on depth
	var color = Color(0.5, 0.8, 1.0).lerp(Color(0.2, 0.2, 0.8), depth_ratio)
	depth_gauge.draw_arc(center, radius, -PI/2, -PI/2 + arc_angle, 32, color, 5.0)
	
	# Target depth indicator
	var target_ratio = clamp(simulation_state.target_depth / max_depth, 0.0, 1.0)
	var target_angle = -PI/2 + target_ratio * TAU * 0.75
	var indicator_start = center + Vector2(cos(target_angle), sin(target_angle)) * (radius - 10)
	var indicator_end = center + Vector2(cos(target_angle), sin(target_angle)) * (radius + 5)
	depth_gauge.draw_line(indicator_start, indicator_end, Color.YELLOW, 3.0)
	
	# Center text
	var text = "%.0f" % depth
	var font = ThemeDB.fallback_font
	var font_size = 24
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	depth_gauge.draw_string(font, center - text_size / 2, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)


func _draw_pitch_indicator() -> void:
	"""Draw attitude indicator showing pitch and roll"""
	if not pitch_indicator or not submarine_body:
		return
	
	var gauge_size = pitch_indicator.size
	var center = gauge_size / 2
	var radius = min(gauge_size.x, gauge_size.y) / 2 - 10
	
	# Get pitch and roll angles
	var pitch_rad = submarine_body.rotation.x
	var roll_rad = submarine_body.rotation.z
	var pitch_deg = rad_to_deg(pitch_rad)
	
	# Outer circle
	pitch_indicator.draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.3, 0.4, 0.5), 3.0)
	
	# Horizon line (rotated by roll)
	# Pitch offset: move horizon up/down based on pitch (clamped to visible range)
	var pitch_offset = clamp(pitch_deg * 1.5, -radius * 0.8, radius * 0.8)
	var horizon_length = radius * 1.8
	var horizon_start = center + Vector2(-horizon_length/2, pitch_offset).rotated(roll_rad)
	var horizon_end = center + Vector2(horizon_length/2, pitch_offset).rotated(roll_rad)
	
	# Sky (blue) above horizon
	var sky_color = Color(0.3, 0.5, 0.8, 0.3)
	if pitch_offset < radius:
		pitch_indicator.draw_circle(center, radius - 3, sky_color)
	
	# Ground (brown) below horizon - draw simplified rectangle
	var ground_color = Color(0.4, 0.3, 0.2, 0.3)
	if pitch_offset > -radius:
		var ground_rect = Rect2(center.x - radius, center.y + pitch_offset, radius * 2, radius * 2)
		pitch_indicator.draw_rect(ground_rect, ground_color)
	
	# Draw horizon line (thick yellow/white)
	pitch_indicator.draw_line(horizon_start, horizon_end, Color(1.0, 1.0, 0.8), 4.0)
	
	# Center reference mark (aircraft/submarine symbol)
	var wing_size = 15.0
	var center_mark_color = Color(1.0, 0.8, 0.0)
	pitch_indicator.draw_line(center + Vector2(-wing_size, 0), center + Vector2(-5, 0), center_mark_color, 3.0)
	pitch_indicator.draw_line(center + Vector2(5, 0), center + Vector2(wing_size, 0), center_mark_color, 3.0)
	pitch_indicator.draw_circle(center, 3, center_mark_color)
	
	# Pitch scale marks (every 10 degrees)
	for pitch_mark in [-30, -20, -10, 10, 20, 30]:
		var mark_offset = pitch_mark * 1.5
		var mark_y = center.y + pitch_offset - mark_offset
		if abs(mark_y - center.y) < radius:
			var mark_length = 10.0 if abs(pitch_mark) % 20 == 0 else 6.0
			var mark_start = Vector2(center.x - mark_length, mark_y)
			var mark_end = Vector2(center.x + mark_length, mark_y)
			mark_start = center + (mark_start - center).rotated(roll_rad)
			mark_end = center + (mark_end - center).rotated(roll_rad)
			pitch_indicator.draw_line(mark_start, mark_end, Color(0.8, 0.8, 0.8, 0.7), 2.0)
	
	# Display text for pitch
	var font = ThemeDB.fallback_font
	var font_size = 16
	var pitch_text = "%+.0f°" % pitch_deg
	var text_pos = center + Vector2(-18, -radius + 18)
	pitch_indicator.draw_string(font, text_pos, pitch_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 
		Color(1.0, 0.8, 0.0) if abs(pitch_deg) > 15 else Color(0.8, 1.0, 0.8))


## Handle dragging
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_dragging = true
				drag_offset = mb.position
			else:
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = global_position + event.relative
		# Keep panel on screen
		var viewport_size = get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0, viewport_size.x - size.x)
		new_pos.y = clamp(new_pos.y, 0, viewport_size.y - size.y)
		global_position = new_pos
		panel_moved.emit(new_pos)


## Control button handlers
func _on_level_sub_pressed() -> void:
	print("Level Sub: Leveling submarine pitch and roll")
	if submarine_body:
		# Get physics system
		var main = get_tree().root.get_node_or_null("Main")
		if main:
			var physics = main.get_node_or_null("SubmarinePhysicsV2")
			if physics and physics.has_method("level_submarine"):
				physics.level_submarine()
			else:
				# Manually apply leveling forces
				var current_angular_vel = submarine_body.angular_velocity
				# Dampen all rotational motion
				submarine_body.angular_velocity = current_angular_vel * 0.5
				print("Applied manual leveling - dampened angular velocity")


func _on_emergency_surface_pressed() -> void:
	print("Emergency Surface: Setting target depth to 0m")
	if simulation_state:
		simulation_state.set_target_depth(0.0)
		# Also reduce speed to prevent overshooting
		var current_speed = simulation_state.target_speed
		if abs(current_speed) > 2.0:
			simulation_state.set_target_speed(2.0 if current_speed > 0 else -2.0)
		print("Target depth set to 0m, speed reduced for controlled surfacing")


func _on_reset_trim_pressed() -> void:
	print("Reset Trim: Resetting ballast system PID")
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var physics = main.get_node_or_null("SubmarinePhysicsV2")
		if physics and physics.has_method("reset_ballast_trim"):
			physics.reset_ballast_trim()
			print("Ballast trim reset complete")
