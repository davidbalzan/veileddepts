extends Node3D
class_name PeriscopeView
## Periscope view providing first-person observation from submarine mast
##
## Implements realistic periscope controls including rotation and zoom.
## Applies lens effects and switches to underwater rendering when submerged.
## Requirements: 5.1, 5.2, 5.3, 5.4, 5.5

## Camera reference
var camera: Camera3D

## Reference to simulation state for submarine position
var simulation_state: SimulationState

## Reference to ocean renderer for wave height queries
var ocean_renderer: OceanRenderer

## Lens effect shader material
var lens_shader_material: ShaderMaterial

## ColorRect for applying lens effects
var lens_effect_rect: ColorRect

## Periscope control parameters
var zoom_level: float = 60.0  # Field of view in degrees (15° to 90°)
var periscope_rotation: float = 0.0  # Horizontal rotation in degrees (0-360)
var periscope_pitch: float = 0.0  # Vertical pitch in degrees (-90 to +90)

## Camera smoothing to reduce physics jitter
var smooth_position: Vector3 = Vector3.ZERO
var smooth_rotation: Vector3 = Vector3.ZERO
const CAMERA_SMOOTHING: float = 0.2  # Lower = smoother but more lag

## Zoom limits (FOV in degrees)
const MIN_FOV: float = 15.0  # Telephoto
const MAX_FOV: float = 90.0  # Wide angle

## Mast height above submarine center
const MAST_HEIGHT: float = 10.0

## Periscope depth threshold for underwater rendering
const PERISCOPE_DEPTH: float = 10.0

## Rotation sensitivity
const ROTATION_SENSITIVITY: float = 0.5  # degrees per pixel

## Zoom sensitivity
const ZOOM_SENSITIVITY: float = 5.0  # FOV change per scroll unit

## Underwater rendering state
var is_underwater_mode: bool = false

## Environment for underwater effects
var underwater_environment: Environment

## HUD elements
var hud_canvas: CanvasLayer
var bearing_label: Label
var bearing_arc: Control
var submarine_indicator: Control


func _ready() -> void:
	# Find camera in scene tree
	camera = get_node_or_null("Camera3D")
	if not camera:
		push_error("PeriscopeView: Camera3D not found")
		return
	
	# Find simulation state from parent (Main node)
	var main_node = get_parent()
	simulation_state = main_node.get_node_or_null("SimulationState")
	if not simulation_state:
		push_error("PeriscopeView: SimulationState not found")
	
	# Find ocean renderer in this view
	ocean_renderer = get_node_or_null("OceanRenderer")
	if not ocean_renderer:
		push_warning("PeriscopeView: OceanRenderer not found, underwater detection will use fixed depth")
	
	# Initialize camera FOV
	camera.fov = zoom_level
	
	# Setup lens effect shader
	apply_lens_effects()
	
	# Setup underwater environment
	setup_underwater_environment()
	
	# Setup HUD elements
	_setup_hud()
	
	print("PeriscopeView: Initialized")


## Update camera position to track submarine mast
## Requirement 5.1: Render view from submarine mast position
func update_camera_position() -> void:
	if not camera or not simulation_state:
		return
	
	# Get submarine body from main scene
	var main_node = get_parent()
	var submarine_body = main_node.get_node_or_null("SubmarineModel")
	
	if not submarine_body:
		return
	
	# Calculate target position at submarine position + mast height (in submarine's local space)
	var mast_offset = Vector3(0, MAST_HEIGHT, 0)
	var target_position = submarine_body.global_position + submarine_body.global_transform.basis * mast_offset
	
	# Calculate target rotation: submarine body's rotation + periscope controls
	var periscope_rotation_rad = deg_to_rad(periscope_rotation)
	var periscope_pitch_rad = deg_to_rad(periscope_pitch)
	var target_rotation = submarine_body.rotation
	target_rotation.y += periscope_rotation_rad
	target_rotation.x += periscope_pitch_rad
	
	# Smooth camera movement to reduce jitter
	smooth_position = smooth_position.lerp(target_position, CAMERA_SMOOTHING)
	smooth_rotation = smooth_rotation.lerp(target_rotation, CAMERA_SMOOTHING)
	
	# Apply smoothed values
	camera.global_position = smooth_position
	camera.rotation = smooth_rotation


## Handle rotation input for periscope rotation
## Requirement 5.2: Rotate periscope based on player input
## @param delta_rotation: Change in rotation in degrees
func handle_rotation_input(delta_rotation: float) -> void:
	# Update rotation
	periscope_rotation += delta_rotation
	
	# Normalize to 0-360 range
	while periscope_rotation < 0:
		periscope_rotation += 360.0
	while periscope_rotation >= 360:
		periscope_rotation -= 360.0
	
	# Apply rotation to camera (will be combined with submarine heading in update_camera_position)
	update_camera_position()


## Handle pitch input for vertical camera movement
## @param delta_pitch: Change in pitch in degrees
func handle_pitch_input(delta_pitch: float) -> void:
	# Update pitch
	periscope_pitch += delta_pitch
	
	# Clamp to -90 to +90 range
	periscope_pitch = clamp(periscope_pitch, -90.0, 90.0)
	
	# Apply pitch to camera (will be combined with submarine heading in update_camera_position)
	update_camera_position()


## Handle zoom input for FOV adjustment
## Requirement 5.3: Adjust field of view within operational limits (15° to 90°)
## @param delta_zoom: Change in zoom level (positive = zoom in, negative = zoom out)
func handle_zoom_input(delta_zoom: float) -> void:
	# Update zoom level (FOV)
	# Positive delta_zoom means zoom in (decrease FOV)
	# Negative delta_zoom means zoom out (increase FOV)
	zoom_level -= delta_zoom
	
	# Clamp to operational limits
	zoom_level = clamp(zoom_level, MIN_FOV, MAX_FOV)
	
	# Apply to camera
	if camera:
		camera.fov = zoom_level


## Check if submarine is below periscope depth
## Returns true if underwater rendering should be active
## Now checks actual wave height at camera position for accurate detection
func is_underwater() -> bool:
	if not camera:
		return false
	
	# Get camera position
	var cam_pos = camera.global_position
	
	# If we have ocean renderer, check actual wave height at camera position
	if ocean_renderer and ocean_renderer.initialized:
		var wave_height = ocean_renderer.get_wave_height_3d(cam_pos)
		# Camera is underwater if it's below the wave surface
		# Add small buffer (0.5m) to avoid flickering at the surface
		return cam_pos.y < (wave_height - 0.5)
	
	# Fallback: use fixed depth check if no ocean renderer
	if simulation_state:
		return simulation_state.submarine_depth > PERISCOPE_DEPTH
	
	return false


## Apply lens effect shader to periscope view
## Requirement 5.4: Apply lens effects including distortion, chromatic aberration, and vignette
func apply_lens_effects() -> void:
	# Find or create lens effect overlay
	var canvas_layer = get_node_or_null("LensEffectCanvas")
	
	if not canvas_layer:
		# Create CanvasLayer for overlay
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "LensEffectCanvas"
		canvas_layer.layer = 100  # Render on top
		add_child(canvas_layer)
		
		# Create ColorRect for full-screen shader
		lens_effect_rect = ColorRect.new()
		lens_effect_rect.name = "LensEffectOverlay"
		lens_effect_rect.anchor_right = 1.0
		lens_effect_rect.anchor_bottom = 1.0
		lens_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas_layer.add_child(lens_effect_rect)
	else:
		lens_effect_rect = canvas_layer.get_node("LensEffectOverlay")
	
	# Load and apply shader
	var shader = load("res://shaders/periscope_lens.gdshader")
	if shader:
		lens_shader_material = ShaderMaterial.new()
		lens_shader_material.shader = shader
		
		# Set shader parameters
		lens_shader_material.set_shader_parameter("distortion_strength", 0.15)
		lens_shader_material.set_shader_parameter("chromatic_aberration", 0.01)
		lens_shader_material.set_shader_parameter("vignette_strength", 0.4)
		lens_shader_material.set_shader_parameter("vignette_radius", 0.8)
		
		lens_effect_rect.material = lens_shader_material
		print("PeriscopeView: Lens effects applied")
	else:
		push_error("PeriscopeView: Failed to load periscope lens shader")


## Setup underwater environment for when submarine is submerged
## Requirement 5.5: Display underwater environment when below periscope depth
func setup_underwater_environment() -> void:
	# Create underwater environment
	underwater_environment = Environment.new()
	
	# Configure underwater fog
	underwater_environment.fog_enabled = true
	underwater_environment.fog_light_color = Color(0.1, 0.3, 0.4)  # Blue-green underwater color
	underwater_environment.fog_density = 0.05  # Dense fog for underwater
	underwater_environment.fog_aerial_perspective = 0.5
	
	# Configure ambient lighting for underwater
	underwater_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	underwater_environment.ambient_light_color = Color(0.2, 0.4, 0.5)  # Dim blue-green ambient
	underwater_environment.ambient_light_energy = 0.3  # Reduced light underwater
	
	# Adjust tonemap for darker underwater environment
	underwater_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	underwater_environment.tonemap_exposure = 0.7  # Darker exposure
	
	print("PeriscopeView: Underwater environment configured")


## Setup HUD elements for periscope view
func _setup_hud() -> void:
	# Create HUD canvas layer
	hud_canvas = CanvasLayer.new()
	hud_canvas.name = "PeriscopeHUD"
	hud_canvas.layer = 100  # Render on top
	add_child(hud_canvas)
	
	# Bearing indicator at top center
	bearing_label = Label.new()
	bearing_label.name = "BearingLabel"
	bearing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bearing_label.position = Vector2(960 - 100, 20)  # Center top
	bearing_label.custom_minimum_size = Vector2(200, 40)
	bearing_label.add_theme_font_size_override("font_size", 32)
	bearing_label.add_theme_color_override("font_color", Color(0, 1, 0, 0.9))  # Green
	bearing_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	bearing_label.add_theme_constant_override("outline_size", 4)
	hud_canvas.add_child(bearing_label)
	
	# Bearing arc (compass rose at top)
	bearing_arc = Control.new()
	bearing_arc.name = "BearingArc"
	bearing_arc.position = Vector2(960 - 200, 70)
	bearing_arc.custom_minimum_size = Vector2(400, 60)
	bearing_arc.draw.connect(_draw_bearing_arc)
	hud_canvas.add_child(bearing_arc)
	
	# Submarine orientation indicator (bottom right)
	submarine_indicator = Control.new()
	submarine_indicator.name = "SubmarineIndicator"
	submarine_indicator.position = Vector2(1920 - 180, 1080 - 180)
	submarine_indicator.custom_minimum_size = Vector2(160, 160)
	submarine_indicator.draw.connect(_draw_submarine_indicator)
	hud_canvas.add_child(submarine_indicator)
	
	print("PeriscopeView: HUD elements created")


## Draw bearing arc (compass rose)
func _draw_bearing_arc() -> void:
	if not simulation_state:
		return
	
	var control = bearing_arc
	var width = 400.0
	var height = 60.0
	var center_x = width / 2.0
	
	# Get submarine body rotation
	var main_node = get_parent()
	var submarine_body = main_node.get_node_or_null("SubmarineModel")
	var submarine_body_heading = rad_to_deg(submarine_body.rotation.y) if submarine_body else 0.0
	
	# Normalize to 0-360
	while submarine_body_heading < 0:
		submarine_body_heading += 360.0
	while submarine_body_heading >= 360:
		submarine_body_heading -= 360.0
	
	# Get absolute bearing (submarine body heading + periscope rotation)
	var absolute_bearing = submarine_body_heading + periscope_rotation
	while absolute_bearing < 0:
		absolute_bearing += 360.0
	while absolute_bearing >= 360:
		absolute_bearing -= 360.0
	
	# Draw compass marks
	var marks = [0, 45, 90, 135, 180, 225, 270, 315]  # Cardinal and intercardinal
	var labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	
	for i in range(marks.size()):
		var bearing = marks[i]
		var label = labels[i]
		
		# Calculate position relative to current bearing
		# FIXED: Invert the calculation - if we're looking at 281°, North (0°) is to our right
		var relative_bearing = absolute_bearing - bearing
		while relative_bearing < -180:
			relative_bearing += 360
		while relative_bearing > 180:
			relative_bearing -= 360
		
		# Only draw if within view range (-90 to +90 degrees)
		if abs(relative_bearing) <= 90:
			var x_pos = center_x + (relative_bearing / 90.0) * (width / 2.0)
			
			# Draw tick mark
			var tick_height = 20.0 if bearing % 90 == 0 else 10.0
			var color = Color(0, 1, 0, 0.8) if bearing % 90 == 0 else Color(0, 1, 0, 0.5)
			control.draw_line(Vector2(x_pos, height - tick_height), Vector2(x_pos, height), color, 2.0)
			
			# Draw label for cardinal directions
			if bearing % 90 == 0:
				var font = ThemeDB.fallback_font
				var font_size = 16
				var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
				control.draw_string(font, Vector2(x_pos - text_size.x / 2, height - tick_height - 5), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	
	# Draw center line (current bearing)
	control.draw_line(Vector2(center_x, 0), Vector2(center_x, height), Color(1, 0, 0, 0.9), 3.0)


## Draw submarine orientation indicator
func _draw_submarine_indicator() -> void:
	if not simulation_state:
		return
	
	var control = submarine_indicator
	var size = 160.0
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = 60.0
	
	# Draw background circle
	control.draw_circle(center, radius + 5, Color(0, 0, 0, 0.7))
	control.draw_arc(center, radius + 5, 0, TAU, 32, Color(0, 1, 0, 0.5), 2.0)
	
	# Draw submarine body (always pointing up = submarine's forward)
	var sub_length = 40.0
	var sub_width = 12.0
	var sub_points = PackedVector2Array([
		center + Vector2(0, -sub_length / 2),  # Bow
		center + Vector2(-sub_width / 2, sub_length / 2),  # Port stern
		center + Vector2(sub_width / 2, sub_length / 2)   # Starboard stern
	])
	control.draw_colored_polygon(sub_points, Color(0.5, 0.5, 0.5, 0.9))
	control.draw_polyline(sub_points + PackedVector2Array([sub_points[0]]), Color(0, 1, 0, 0.9), 2.0)
	
	# Draw periscope direction indicator (red line)
	# Periscope rotation: 0° = forward (up), 90° = right (east), etc.
	# In screen space: 0° = up, 90° = right
	var periscope_angle = deg_to_rad(periscope_rotation)  # Direct conversion, no negation
	var periscope_dir = Vector2(sin(periscope_angle), -cos(periscope_angle))  # -cos for up=0
	var periscope_end = center + periscope_dir * radius
	control.draw_line(center, periscope_end, Color(1, 0, 0, 0.9), 3.0)
	
	# Draw arrow at end of periscope line
	var arrow_size = 8.0
	var arrow_angle = periscope_angle
	var arrow_left = periscope_end + Vector2(sin(arrow_angle - 2.5), -cos(arrow_angle - 2.5)) * arrow_size
	var arrow_right = periscope_end + Vector2(sin(arrow_angle + 2.5), -cos(arrow_angle + 2.5)) * arrow_size
	control.draw_colored_polygon(PackedVector2Array([periscope_end, arrow_left, arrow_right]), Color(1, 0, 0, 0.9))
	
	# Draw cardinal directions
	var font = ThemeDB.fallback_font
	var font_size = 14
	control.draw_string(font, center + Vector2(-5, -radius - 15), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 1, 0, 0.7))
	control.draw_string(font, center + Vector2(radius + 10, 5), "E", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 1, 0, 0.7))
	control.draw_string(font, center + Vector2(-5, radius + 20), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 1, 0, 0.7))
	control.draw_string(font, center + Vector2(-radius - 15, 5), "W", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 1, 0, 0.7))
	
	# Draw periscope rotation angle text
	var angle_text = "Periscope: %03d°" % int(periscope_rotation)
	control.draw_string(font, Vector2(10, size - 10), angle_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 1, 0, 0.9))


## Update underwater rendering mode based on submarine depth
## Requirement 5.5: Switch to underwater fog and lighting when depth > 10m
func update_underwater_mode() -> void:
	var should_be_underwater = is_underwater()
	
	# Only update if state changed
	if should_be_underwater != is_underwater_mode:
		is_underwater_mode = should_be_underwater
		
		if is_underwater_mode:
			# Switch to underwater rendering
			if camera:
				camera.environment = underwater_environment
			print("PeriscopeView: Switched to underwater rendering mode")
		else:
			# Switch back to normal rendering
			if camera:
				camera.environment = null  # Use default world environment
			print("PeriscopeView: Switched to surface rendering mode")


## Process function called each frame
func _process(_delta: float) -> void:
	# Update camera position to track submarine
	update_camera_position()
	
	# Update underwater rendering mode based on depth
	update_underwater_mode()
	
	# Show/hide lens effects based on visibility
	_update_lens_effect_visibility()
	
	# Update HUD elements
	_update_hud()


## Update HUD visibility and content
func _update_hud() -> void:
	if not hud_canvas or not simulation_state:
		return
	
	# Show/hide HUD with view
	hud_canvas.visible = visible
	
	if not visible:
		return
	
	# Get submarine body rotation
	var main_node = get_parent()
	var submarine_body = main_node.get_node_or_null("SubmarineModel")
	var submarine_body_heading = rad_to_deg(submarine_body.rotation.y) if submarine_body else 0.0
	
	# Normalize to 0-360
	while submarine_body_heading < 0:
		submarine_body_heading += 360.0
	while submarine_body_heading >= 360:
		submarine_body_heading -= 360.0
	
	# Update bearing label (body heading + periscope rotation)
	var absolute_bearing = submarine_body_heading + periscope_rotation
	while absolute_bearing < 0:
		absolute_bearing += 360.0
	while absolute_bearing >= 360:
		absolute_bearing -= 360.0
	
	bearing_label.text = "%03d°" % int(absolute_bearing)
	
	# Queue redraw for dynamic elements
	if bearing_arc:
		bearing_arc.queue_redraw()
	if submarine_indicator:
		submarine_indicator.queue_redraw()


## Update lens effect visibility to match view visibility
func _update_lens_effect_visibility() -> void:
	var canvas_layer = get_node_or_null("LensEffectCanvas")
	if canvas_layer:
		canvas_layer.visible = visible


## Handle input events for periscope control
func _input(event: InputEvent) -> void:
	# Only process input when this view is visible
	if not visible:
		return
	
	# Handle mouse motion for rotation
	if event is InputEventMouseMotion:
		var mouse_motion = event as InputEventMouseMotion
		# Only rotate if right mouse button is held
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var delta_rotation = mouse_motion.relative.x * ROTATION_SENSITIVITY
			handle_rotation_input(delta_rotation)
	
	# Handle mouse wheel for zoom
	elif event is InputEventMouseButton:
		var mouse_button = event as InputEventMouseButton
		if mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				# Zoom in
				handle_zoom_input(ZOOM_SENSITIVITY)
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Zoom out
				handle_zoom_input(-ZOOM_SENSITIVITY)
