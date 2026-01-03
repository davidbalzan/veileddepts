class_name SimulationState extends Node

## SimulationState maintains the authoritative game state for the submarine simulator.
## It serves as the single source of truth for submarine position, velocity, depth, heading,
## and all contact tracking. All views (tactical map, periscope, external) query this state.

## Submarine state variables
var submarine_position: Vector3 = Vector3.ZERO
var submarine_velocity: Vector3 = Vector3.ZERO
var submarine_depth: float = 0.0  # meters below surface
var submarine_heading: float = 0.0  # degrees (0-360, where 0 is north) - CURRENT heading
var submarine_speed: float = 0.0  # meters per second

## Target values for submarine commands
var target_waypoint: Vector3 = Vector3.ZERO
var target_depth: float = 0.0
var target_speed: float = 0.0
var target_heading: float = 0.0  # Target heading for propulsion

## Submarine operational limits
const MAX_SPEED: float = 10.3  # 20 knots in m/s
const MAX_DEPTH: float = 400.0  # meters
const MIN_DEPTH: float = 0.0  # surface

## Contact tracking
var contacts: Array[Contact] = []
var _next_contact_id: int = 1


## Called when the node enters the scene tree
func _ready() -> void:
	# Initialize submarine at surface, stationary
	submarine_position = Vector3.ZERO
	submarine_velocity = Vector3.ZERO
	submarine_depth = 0.0
	submarine_heading = 0.0
	submarine_speed = 0.0
	target_waypoint = Vector3.ZERO
	target_depth = 0.0
	target_speed = 0.0
	target_heading = 0.0  # North by default


## Update submarine command with new waypoint, speed, and depth
## This is called from the tactical map when the player issues commands
func update_submarine_command(waypoint: Vector3, speed: float, depth: float) -> void:
	# Set target waypoint
	target_waypoint = waypoint

	# Clamp speed to operational limits (allow negative for reverse)
	target_speed = clamp(speed, -MAX_SPEED * 0.5, MAX_SPEED)  # Reverse at half speed

	# Clamp depth to operational limits
	target_depth = clamp(depth, MIN_DEPTH, MAX_DEPTH)
	
	# Log submarine command to console
	if LogRouter:
		LogRouter.log(
			"Submarine command updated: waypoint=(%.1f, %.1f, %.1f), speed=%.1fm/s, depth=%.1fm" % [waypoint.x, waypoint.y, waypoint.z, target_speed, target_depth],
			LogRouter.LogLevel.INFO,
			"submarine"
		)

	# Update TARGET heading to point toward waypoint
	var delta = waypoint - submarine_position
	if delta.length() > 0.1:  # Only update if waypoint is not at current position
		# Calculate basic heading from position to waypoint
		# atan2(x, -z) gives angle where 0 is north (-Z), 90 is east (+X)
		var heading_rad = atan2(delta.x, -delta.z)
		var basic_heading = rad_to_deg(heading_rad)

		# Normalize to 0-360 range
		if basic_heading < 0:
			basic_heading += 360.0

		# Calculate lead-ahead for turning at current speed
		var distance_to_waypoint = delta.length()
		var current_speed_2d = Vector2(submarine_velocity.x, submarine_velocity.z).length()

		# Estimate turning radius based on current speed (simplified)
		var turning_radius = 50.0  # Base turning radius in meters
		if current_speed_2d > 1.0:
			turning_radius = current_speed_2d * 8.0  # Rough approximation

		# If we're close to the waypoint and moving fast, start turning early
		var lead_ahead_distance = min(turning_radius, distance_to_waypoint * 0.5)

		if distance_to_waypoint < lead_ahead_distance * 2.0 and current_speed_2d > 2.0:
			# We're approaching the waypoint - calculate lead-ahead heading
			var lead_ahead_point = waypoint + delta.normalized() * lead_ahead_distance
			var lead_delta = lead_ahead_point - submarine_position
			if lead_delta.length() > 0.1:
				var lead_heading_rad = atan2(lead_delta.x, -lead_delta.z)
				target_heading = rad_to_deg(lead_heading_rad)
				if target_heading < 0:
					target_heading += 360.0
			else:
				target_heading = basic_heading
		else:
			# Normal navigation - point directly at waypoint
			target_heading = basic_heading


## Set target speed directly without changing waypoint or heading
## Allows negative values for reverse (at half max speed)
func set_target_speed(speed: float) -> void:
	target_speed = clamp(speed, -MAX_SPEED * 0.5, MAX_SPEED)


## Set target heading directly without changing waypoint
func set_target_heading(heading: float) -> void:
	target_heading = heading
	# Normalize to 0-360 range
	while target_heading < 0:
		target_heading += 360.0
	while target_heading >= 360:
		target_heading -= 360.0


## Set target depth directly without changing waypoint or speed
func set_target_depth(depth: float) -> void:
	target_depth = clamp(depth, MIN_DEPTH, MAX_DEPTH)


## Add a new contact to the tracking system
## Returns the assigned contact ID
func add_contact(contact: Contact) -> int:
	# Assign unique ID if not already set
	if contact.id == 0:
		contact.id = _next_contact_id
		_next_contact_id += 1

	# Check for duplicate ID
	for existing_contact in contacts:
		if existing_contact.id == contact.id:
			push_warning("Contact with ID %d already exists, not adding duplicate" % contact.id)
			return -1

	# Add contact to tracking list
	contacts.append(contact)
	return contact.id


## Update an existing contact's position and detection status
## Returns true if contact was found and updated, false otherwise
func update_contact(
	contact_id: int, new_position: Vector3, is_detected: bool, is_identified: bool
) -> bool:
	for contact in contacts:
		if contact.id == contact_id:
			contact.position = new_position
			contact.detected = is_detected
			contact.identified = is_identified
			return true

	push_warning("Contact with ID %d not found for update" % contact_id)
	return false


## Get all contacts that are visible from the observer position
## A contact is visible if it is both detected AND identified
## This is used by the fog-of-war system
func get_visible_contacts(observer_position: Vector3) -> Array[Contact]:
	var visible: Array[Contact] = []

	for contact in contacts:
		# Contact must be both detected and identified to be visible
		if contact.detected and contact.identified:
			# Update bearing and range from observer position
			contact.update_bearing_and_range(observer_position)
			visible.append(contact)

	return visible


## Get all detected contacts (regardless of identification status)
## This is used by the tactical map to show all sensor contacts
func get_detected_contacts(observer_position: Vector3) -> Array[Contact]:
	var detected: Array[Contact] = []

	for contact in contacts:
		if contact.detected:
			# Update bearing and range from observer position
			contact.update_bearing_and_range(observer_position)
			detected.append(contact)

	return detected


## Remove a contact from tracking
## Returns true if contact was found and removed, false otherwise
func remove_contact(contact_id: int) -> bool:
	for i in range(contacts.size()):
		if contacts[i].id == contact_id:
			contacts.remove_at(i)
			return true

	return false


## Get contact by ID
## Returns the contact if found, null otherwise
func get_contact(contact_id: int) -> Contact:
	for contact in contacts:
		if contact.id == contact_id:
			return contact

	return null


## Clear all contacts from tracking
func clear_contacts() -> void:
	contacts.clear()


## Update submarine state based on physics calculations
## This is called by the submarine physics system each frame
func update_submarine_state(
	position: Vector3, velocity: Vector3, depth: float, heading: float, speed: float
) -> void:
	# Check for significant position changes (more than 10 meters)
	var position_changed = submarine_position.distance_to(position) > 10.0
	var old_depth = submarine_depth
	
	submarine_position = position
	submarine_velocity = velocity
	submarine_depth = clamp(depth, MIN_DEPTH, MAX_DEPTH)
	submarine_heading = heading
	submarine_speed = clamp(speed, 0.0, MAX_SPEED)

	# Normalize heading to 0-360 range
	while submarine_heading < 0:
		submarine_heading += 360.0
	while submarine_heading >= 360:
		submarine_heading -= 360.0
	
	# Log significant state changes to console
	if position_changed and LogRouter:
		LogRouter.log(
			"Submarine position: (%.1f, %.1f, %.1f), depth: %.1fm, heading: %.1f°, speed: %.1fm/s" % [position.x, position.y, position.z, submarine_depth, submarine_heading, submarine_speed],
			LogRouter.LogLevel.DEBUG,
			"submarine"
		)
	
	# Log depth changes
	if abs(submarine_depth - old_depth) > 5.0 and LogRouter:
		LogRouter.log(
			"Submarine depth changed: %.1fm -> %.1fm" % [old_depth, submarine_depth],
			LogRouter.LogLevel.DEBUG,
			"submarine"
		)


## Get the current submarine state as a dictionary
## Useful for debugging and state serialization
func get_submarine_state() -> Dictionary:
	return {
		"position": submarine_position,
		"velocity": submarine_velocity,
		"depth": submarine_depth,
		"heading": submarine_heading,
		"speed": submarine_speed,
		"target_waypoint": target_waypoint,
		"target_depth": target_depth,
		"target_speed": target_speed,
		"target_heading": target_heading
	}


## Physics process function called at fixed timestep (60 Hz)
## Updates submarine physics and synchronizes state
func _physics_process(_delta: float) -> void:
	# Physics updates will be handled by SubmarinePhysics system
	# This is called at fixed 60 Hz timestep for consistent physics
	pass
