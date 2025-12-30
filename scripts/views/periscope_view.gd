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

## Lens effect shader material
var lens_shader_material: ShaderMaterial

## ColorRect for applying lens effects
var lens_effect_rect: ColorRect

## Periscope control parameters
var zoom_level: float = 60.0  # Field of view in degrees (15° to 90°)
var periscope_rotation: float = 0.0  # Rotation in degrees (0-360)

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
	
	# Initialize camera FOV
	camera.fov = zoom_level
	
	# Setup lens effect shader
	apply_lens_effects()
	
	# Setup underwater environment
	setup_underwater_environment()
	
	print("PeriscopeView: Initialized")


## Update camera position to track submarine mast
## Requirement 5.1: Render view from submarine mast position
func update_camera_position() -> void:
	if not camera or not simulation_state:
		return
	
	# Position camera at submarine position + mast height
	var mast_position = simulation_state.submarine_position
	mast_position.y += MAST_HEIGHT
	
	camera.global_position = mast_position
	
	# Apply rotation based on periscope rotation control
	# Rotation is in degrees where 0 is north (+Z), 90 is east (+X)
	var rotation_rad = deg_to_rad(periscope_rotation)
	camera.rotation.y = rotation_rad


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
	
	# Apply rotation to camera
	if camera:
		var rotation_rad = deg_to_rad(periscope_rotation)
		camera.rotation.y = rotation_rad


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
func is_underwater() -> bool:
	if not simulation_state:
		return false
	
	return simulation_state.submarine_depth > PERISCOPE_DEPTH


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
