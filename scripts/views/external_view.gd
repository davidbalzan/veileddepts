extends Node3D
class_name ExternalView
## External view providing third-person tactical observation with fog-of-war
##
## Implements orbit camera controls with tilt, rotation, and distance adjustment.
## Supports free camera mode for independent camera movement.
## Integrates with fog-of-war system to show only identified contacts.
## Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8

## Camera reference
var camera: Camera3D

## Reference to simulation state for submarine position
var simulation_state: SimulationState

## Reference to fog of war system for contact visibility
var fog_of_war: FogOfWarSystem

## Camera control parameters
var camera_distance: float = 100.0  # Distance from submarine in meters
var camera_tilt: float = 30.0  # Vertical angle in degrees (-89 to 89)
var camera_rotation: float = 0.0  # Horizontal rotation in degrees (0-360)
var free_camera_mode: bool = false  # Whether camera moves independently

## Free camera position (used when free_camera_mode is true)
var free_camera_position: Vector3 = Vector3.ZERO

## Camera parameter limits
const MIN_DISTANCE: float = 10.0  # Minimum distance from submarine
const MAX_DISTANCE: float = 500.0  # Maximum distance from submarine
const MIN_TILT: float = -89.0  # Maximum downward tilt
const MAX_TILT: float = 89.0  # Maximum upward tilt

## Input sensitivity
const TILT_SENSITIVITY: float = 0.3  # degrees per pixel
const ROTATION_SENSITIVITY: float = 0.3  # degrees per pixel
const DISTANCE_SENSITIVITY: float = 5.0  # meters per scroll unit
const FREE_CAMERA_SPEED: float = 50.0  # meters per second

## Input state
var is_rotating: bool = false
var is_tilting: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Find camera in scene tree
	camera = get_node_or_null("Camera3D")
	if not camera:
		push_error("ExternalView: Camera3D not found")
		return
	
	# Find simulation state from parent (Main node)
	var main_node = get_parent()
	simulation_state = main_node.get_node_or_null("SimulationState")
	if not simulation_state:
		push_error("ExternalView: SimulationState not found")
	
	# Find fog of war system
	fog_of_war = main_node.get_node_or_null("FogOfWarSystem")
	if not fog_of_war:
		push_warning("ExternalView: FogOfWarSystem not found, all contacts will be visible")
	
	# Initialize camera position
	update_camera_position()
	
	print("ExternalView: Initialized")


## Update camera position based on orbit parameters or free camera mode
## Requirement 4.1: Third-person perspective around submarine
## Requirement 4.3: Orbit around submarine position
## Requirement 4.5: Free camera mode for independent movement
func update_camera_position() -> void:
	if not camera or not simulation_state:
		return
	
	if free_camera_mode:
		# In free camera mode, use stored free camera position
		camera.global_position = free_camera_position
		
		# Look at submarine for reference (optional - could look at any direction)
		var submarine_pos = simulation_state.submarine_position
		if camera.global_position.distance_to(submarine_pos) > 0.1:
			camera.look_at(submarine_pos, Vector3.UP)
	else:
		# In orbit mode, calculate position around submarine
		var submarine_pos = simulation_state.submarine_position
		
		# Convert tilt and rotation to radians
		var tilt_rad = deg_to_rad(camera_tilt)
		var rotation_rad = deg_to_rad(camera_rotation)
		
		# Calculate offset from submarine
		# Horizontal distance is affected by tilt (more tilt = less horizontal distance)
		var horizontal_distance = camera_distance * cos(tilt_rad)
		var vertical_offset = camera_distance * sin(tilt_rad)
		
		# Calculate position in orbit
		var offset = Vector3(
			horizontal_distance * sin(rotation_rad),
			vertical_offset,
			horizontal_distance * cos(rotation_rad)
		)
		
		# Set camera position
		camera.global_position = submarine_pos + offset
		
		# Look at submarine
		camera.look_at(submarine_pos, Vector3.UP)


## Handle tilt input for vertical camera angle adjustment
## Requirement 4.2: Adjust vertical viewing angle within operational limits
## @param delta_tilt: Change in tilt angle in degrees
func handle_tilt_input(delta_tilt: float) -> void:
	# Update tilt
	camera_tilt += delta_tilt
	
	# Clamp to operational limits
	camera_tilt = clamp(camera_tilt, MIN_TILT, MAX_TILT)
	
	# Update camera position
	update_camera_position()


## Handle rotation input for horizontal camera rotation
## Requirement 4.3: Orbit around submarine position
## @param delta_rotation: Change in rotation angle in degrees
func handle_rotation_input(delta_rotation: float) -> void:
	# Update rotation
	camera_rotation += delta_rotation
	
	# Normalize to 0-360 range
	while camera_rotation < 0:
		camera_rotation += 360.0
	while camera_rotation >= 360:
		camera_rotation -= 360.0
	
	# Update camera position
	update_camera_position()


## Handle distance input for camera zoom
## Requirement 4.4: Adjust camera distance within operational limits
## @param delta_distance: Change in distance in meters
func handle_distance_input(delta_distance: float) -> void:
	# Update distance
	camera_distance += delta_distance
	
	# Clamp to operational limits
	camera_distance = clamp(camera_distance, MIN_DISTANCE, MAX_DISTANCE)
	
	# Update camera position
	update_camera_position()


## Toggle free camera mode
## Requirement 4.5: Allow camera to move independently from submarine
func toggle_free_camera() -> void:
	free_camera_mode = not free_camera_mode
	
	if free_camera_mode:
		# Store current camera position as free camera starting position
		if camera:
			free_camera_position = camera.global_position
		print("ExternalView: Free camera mode enabled")
	else:
		print("ExternalView: Free camera mode disabled (orbit mode)")
	
	# Update camera position
	update_camera_position()


## Move free camera in a direction
## Only works when free_camera_mode is enabled
## @param direction: Movement direction in camera space
## @param delta: Time delta for frame-rate independent movement
func move_free_camera(direction: Vector3, delta: float) -> void:
	if not free_camera_mode or not camera:
		return
	
	# Transform direction from camera space to world space
	var world_direction = camera.global_transform.basis * direction
	
	# Move camera
	free_camera_position += world_direction * FREE_CAMERA_SPEED * delta
	
	# Update camera position
	camera.global_position = free_camera_position


## Process function called each frame
func _process(delta: float) -> void:
	# Update camera position to track submarine (or maintain free camera position)
	update_camera_position()
	
	# Handle free camera movement with WASD keys
	if free_camera_mode and visible:
		var movement = Vector3.ZERO
		
		if Input.is_key_pressed(KEY_W):
			movement.z -= 1.0
		if Input.is_key_pressed(KEY_S):
			movement.z += 1.0
		if Input.is_key_pressed(KEY_A):
			movement.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			movement.x += 1.0
		if Input.is_key_pressed(KEY_Q):
			movement.y -= 1.0
		if Input.is_key_pressed(KEY_E):
			movement.y += 1.0
		
		if movement.length() > 0:
			movement = movement.normalized()
			move_free_camera(movement, delta)


## Handle input events for camera control
func _input(event: InputEvent) -> void:
	# Only process input when this view is visible
	if not visible:
		return
	
	# Handle mouse motion for rotation and tilt
	if event is InputEventMouseMotion:
		var mouse_motion = event as InputEventMouseMotion
		
		# Right mouse button for rotation
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var delta_rotation = mouse_motion.relative.x * ROTATION_SENSITIVITY
			handle_rotation_input(delta_rotation)
		
		# Middle mouse button for tilt (pitch up/down)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var delta_tilt = -mouse_motion.relative.y * TILT_SENSITIVITY
			handle_tilt_input(delta_tilt)
		
		# Shift + Right mouse button for tilt (alternative)
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var delta_tilt = -mouse_motion.relative.y * TILT_SENSITIVITY
			handle_tilt_input(delta_tilt)
	
	# Handle mouse wheel for distance
	elif event is InputEventMouseButton:
		var mouse_button = event as InputEventMouseButton
		if mouse_button.pressed:
			if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
				# Zoom in (decrease distance)
				handle_distance_input(-DISTANCE_SENSITIVITY)
			elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Zoom out (increase distance)
				handle_distance_input(DISTANCE_SENSITIVITY)
	
	# Handle F key for free camera toggle
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F:
				toggle_free_camera()


## Get contacts that should be rendered based on fog of war
## Requirement 4.7, 4.8: Only render contacts that are detected AND identified
func get_visible_contacts() -> Array[Contact]:
	if not simulation_state:
		return []
	
	# If no fog of war system, show all detected contacts
	if not fog_of_war:
		return simulation_state.get_detected_contacts(simulation_state.submarine_position)
	
	# Use fog of war system to filter contacts
	var all_contacts = simulation_state.contacts
	var visible_contacts: Array[Contact] = []
	
	for contact in all_contacts:
		if fog_of_war.is_contact_visible(contact):
			visible_contacts.append(contact)
	
	return visible_contacts
