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

## Debug visualization
var show_debug_vectors: bool = false
var thrust_arrow: Node3D = null
var velocity_arrow: Node3D = null
var target_arrow: Node3D = null


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

	# Create debug arrow nodes
	_create_debug_arrows()

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

		# Get submarine body rotation directly
		var main_node = get_parent()
		var submarine_body = main_node.get_node_or_null("SubmarineModel")
		var submarine_body_yaw = submarine_body.rotation.y if submarine_body else 0.0

		# Convert tilt and rotation to radians
		var tilt_rad = deg_to_rad(camera_tilt)
		# Camera rotation is relative to submarine body rotation
		# rotation=0 means behind submarine, rotation=180 means in front
		var rotation_rad = deg_to_rad(camera_rotation + 180.0) + submarine_body_yaw

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

		# Safety check: Ensure camera and target are not at same position
		var look_direction = submarine_pos - camera.global_position
		if look_direction.length_squared() > 0.01:
			# Additional safety: Check if look direction is colinear with up vector
			var up_dot = abs(look_direction.normalized().dot(Vector3.UP))
			if up_dot < 0.99:  # Not nearly vertical
				camera.look_at(submarine_pos, Vector3.UP)
			else:
				# Use alternative up vector when nearly vertical
				var alt_up = Vector3.RIGHT if abs(look_direction.x) < 0.5 else Vector3.FORWARD
				camera.look_at(submarine_pos, alt_up)


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

	# Update debug vectors if enabled
	if show_debug_vectors:
		_update_debug_vectors()

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

	# Handle F key for free camera toggle and F3 for debug vectors
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F:
				toggle_free_camera()
			elif key_event.keycode == KEY_F3:
				# Toggle debug vector visualization
				show_debug_vectors = not show_debug_vectors
				if thrust_arrow:
					thrust_arrow.visible = show_debug_vectors
				if velocity_arrow:
					velocity_arrow.visible = show_debug_vectors
				if target_arrow:
					target_arrow.visible = show_debug_vectors
				var sub_forward_arrow = get_node_or_null("SubForwardArrow")
				if sub_forward_arrow:
					sub_forward_arrow.visible = show_debug_vectors
				print(
					"ExternalView: Debug vectors ", "enabled" if show_debug_vectors else "disabled"
				)
			elif key_event.keycode == KEY_P:
				# Toggle pause
				get_tree().paused = not get_tree().paused
				print("Game ", "PAUSED" if get_tree().paused else "RESUMED")


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


## Create debug arrow nodes using CSG shapes
func _create_debug_arrows() -> void:
	# Create thrust arrow (RED)
	thrust_arrow = _create_arrow_node("ThrustArrow", Color.RED)
	add_child(thrust_arrow)
	thrust_arrow.visible = false

	# Create velocity arrow (BLUE)
	velocity_arrow = _create_arrow_node("VelocityArrow", Color.BLUE)
	add_child(velocity_arrow)
	velocity_arrow.visible = false

	# Create target arrow (YELLOW)
	target_arrow = _create_arrow_node("TargetArrow", Color.YELLOW)
	add_child(target_arrow)
	target_arrow.visible = false

	# Create submarine forward indicator (GREEN) - shows model's actual forward
	var sub_forward_arrow = _create_arrow_node("SubForwardArrow", Color.GREEN)
	add_child(sub_forward_arrow)
	sub_forward_arrow.visible = false
	sub_forward_arrow.set_meta("is_sub_forward", true)


## Create a single arrow node using CSG
func _create_arrow_node(arrow_name: String, color: Color) -> Node3D:
	var arrow_root = Node3D.new()
	arrow_root.name = arrow_name
	arrow_root.top_level = true  # Use world coordinates

	# Create arrow shaft (cylinder)
	var shaft = CSGCylinder3D.new()
	shaft.name = "Shaft"
	shaft.radius = 0.3
	shaft.height = 20.0
	shaft.material = StandardMaterial3D.new()
	shaft.material.albedo_color = color
	shaft.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_root.add_child(shaft)

	# Create arrowhead (cone)
	var head = CSGCylinder3D.new()
	head.name = "Head"
	head.radius = 0.8
	head.height = 3.0
	head.cone = true
	head.material = StandardMaterial3D.new()
	head.material.albedo_color = color
	head.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.position = Vector3(0, 11.5, 0)  # At the end of shaft
	arrow_root.add_child(head)

	return arrow_root


## Update debug vector visualization using CSG arrows
func _update_debug_vectors() -> void:
	if not simulation_state:
		return

	# Get submarine body reference
	var main_node = get_parent()
	var submarine_body = main_node.get_node_or_null("SubmarineModel")
	if not submarine_body:
		return

	var sub_pos = submarine_body.global_position
	var velocity = submarine_body.linear_velocity

	# Get submarine's forward direction from transform basis (matches physics)
	var thrust_direction = -submarine_body.global_transform.basis.z

	# Get submarine's ACTUAL forward direction from its transform basis
	var model_forward = -submarine_body.global_transform.basis.z  # Should be same as thrust_direction

	# Get target heading direction
	var target_heading_rad = deg_to_rad(simulation_state.target_heading)
	var target_direction = Vector3(sin(target_heading_rad), 0.0, -cos(target_heading_rad))

	# Update thrust arrow (RED) - calculated from rotation.y
	if thrust_arrow:
		_position_arrow(thrust_arrow, sub_pos, thrust_direction, 20.0)

	# Update submarine forward arrow (GREEN) - actual model forward from transform
	var sub_forward_arrow = get_node_or_null("SubForwardArrow")
	if sub_forward_arrow:
		_position_arrow(sub_forward_arrow, sub_pos, model_forward, 15.0)
		sub_forward_arrow.visible = show_debug_vectors

	# Update velocity arrow (BLUE)
	if velocity_arrow and velocity.length() > 0.1:
		var vel_direction = velocity.normalized()
		_position_arrow(velocity_arrow, sub_pos, vel_direction, velocity.length() * 5.0)
		velocity_arrow.visible = show_debug_vectors
	elif velocity_arrow:
		velocity_arrow.visible = false

	# Update target arrow (YELLOW)
	if target_arrow:
		_position_arrow(target_arrow, sub_pos, target_direction, 25.0)


## Position and orient an arrow to point in a direction
func _position_arrow(arrow: Node3D, start_pos: Vector3, direction: Vector3, length: float) -> void:
	# Position at start
	arrow.global_position = start_pos

	# Reset rotation first
	arrow.global_rotation = Vector3.ZERO

	# Orient to point in direction
	# Arrows point along +Y axis by default, so we need to rotate to align with direction
	if direction.length() > 0.001:
		var normalized_dir = direction.normalized()
		var target_pos = start_pos + normalized_dir

		# Avoid "Target and up vectors are colinear" error where look_at fails
		var up_dot = abs(normalized_dir.dot(Vector3.UP))
		var up_vector = Vector3.UP if up_dot < 0.99 else Vector3.RIGHT
		
		# Point the arrow in the direction
		arrow.look_at(target_pos, up_vector)
		# Rotate 90° around local X axis to align arrow (which points up) with forward direction
		arrow.rotate_object_local(Vector3.RIGHT, -PI / 2)

	# Scale arrow to desired length
	var shaft = arrow.get_node_or_null("Shaft")
	if shaft:
		shaft.height = length
