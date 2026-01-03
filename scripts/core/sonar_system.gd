class_name SonarSystem extends Node

## SonarSystem handles detection and tracking of contacts using various sensor types.
## It implements passive sonar (bearing only), active sonar (bearing + range),
## and radar detection (bearing + range) with different update frequencies.

## Detection types
enum DetectionType { PASSIVE_SONAR, ACTIVE_SONAR, RADAR }  # Bearing only, 5s update  # Bearing + range, 2s update  # Bearing + range, 1s update

## Update intervals for each detection type (in seconds)
const PASSIVE_SONAR_UPDATE_INTERVAL: float = 5.0
const ACTIVE_SONAR_UPDATE_INTERVAL: float = 2.0
const RADAR_UPDATE_INTERVAL: float = 1.0

## Detection ranges for each sensor type (in meters)
@export var passive_sonar_range: float = 10000.0  # 10 km
@export var active_sonar_range: float = 5000.0  # 5 km
@export var radar_range: float = 20000.0  # 20 km

## Reference to simulation state for contact management
var simulation_state: SimulationState

## Timers for each detection type
var _passive_sonar_timer: float = 0.0
var _active_sonar_timer: float = 0.0
var _radar_timer: float = 0.0

## Active sonar enabled flag
var active_sonar_enabled: bool = false

## Radar enabled flag (for surface contacts)
var radar_enabled: bool = false

## Thermal layer depth (affects detection ranges)
var thermal_layer_depth: float = 100.0  # meters

## Thermal layer strength (0.0 to 1.0, affects range reduction)
var thermal_layer_strength: float = 0.5


## Initialize the sonar system
func _ready() -> void:
	# Find simulation state in the scene tree if not already injected
	if not simulation_state:
		simulation_state = get_node_or_null("/root/Main/SimulationState")
	if not simulation_state:
		push_warning("SonarSystem: SimulationState not found in scene tree")


## Process detection updates based on timers
func _process(delta: float) -> void:
	if not simulation_state:
		return

	# Update passive sonar
	_passive_sonar_timer += delta
	if _passive_sonar_timer >= PASSIVE_SONAR_UPDATE_INTERVAL:
		_passive_sonar_timer = 0.0
		_update_passive_sonar()

	# Update active sonar if enabled
	if active_sonar_enabled:
		_active_sonar_timer += delta
		if _active_sonar_timer >= ACTIVE_SONAR_UPDATE_INTERVAL:
			_active_sonar_timer = 0.0
			_update_active_sonar()

	# Update radar if enabled
	if radar_enabled:
		_radar_timer += delta
		if _radar_timer >= RADAR_UPDATE_INTERVAL:
			_radar_timer = 0.0
			_update_radar()


## Update passive sonar detections (bearing only)
func _update_passive_sonar() -> void:
	var submarine_pos = simulation_state.submarine_position
	var submarine_depth = simulation_state.submarine_depth

	for contact in simulation_state.contacts:
		# Skip if contact is not a submarine or surface ship
		if contact.type == Contact.ContactType.AIRCRAFT:
			continue

		# Calculate range to contact
		var distance = submarine_pos.distance_to(contact.position)

		# Apply thermal layer effects
		var effective_range = _apply_thermal_layer_effect(
			passive_sonar_range, submarine_depth, contact.position.y
		)

		# Check if within detection range
		if distance <= effective_range:
			# Passive sonar provides bearing only
			contact.update_bearing_and_range(submarine_pos)
			contact.detected = true
			# Note: Passive sonar doesn't automatically identify contacts
		else:
			# Out of range - mark as not detected
			contact.detected = false
			contact.identified = false


## Update active sonar detections (bearing + range)
func _update_active_sonar() -> void:
	var submarine_pos = simulation_state.submarine_position
	var submarine_depth = simulation_state.submarine_depth

	for contact in simulation_state.contacts:
		# Skip aircraft (active sonar doesn't detect aircraft)
		if contact.type == Contact.ContactType.AIRCRAFT:
			continue

		# Calculate range to contact
		var distance = submarine_pos.distance_to(contact.position)

		# Apply thermal layer effects
		var effective_range = _apply_thermal_layer_effect(
			active_sonar_range, submarine_depth, contact.position.y
		)

		# Check if within detection range
		if distance <= effective_range:
			# Active sonar provides bearing and range
			contact.update_bearing_and_range(submarine_pos)
			contact.detected = true
			# Active sonar can identify contacts with high confidence
			contact.identified = true
		else:
			# Out of range - mark as not detected
			contact.detected = false
			contact.identified = false


## Update radar detections (bearing + range, surface only)
func _update_radar() -> void:
	var submarine_pos = simulation_state.submarine_position
	var submarine_depth = simulation_state.submarine_depth

	# Radar only works when submarine is at periscope depth or shallower
	if submarine_depth > 10.0:
		return

	for contact in simulation_state.contacts:
		# Radar only detects surface ships and aircraft
		if contact.type == Contact.ContactType.SUBMARINE:
			continue

		# Calculate range to contact
		var distance = submarine_pos.distance_to(contact.position)

		# Check if within radar range
		if distance <= radar_range:
			# Radar provides bearing and range
			contact.update_bearing_and_range(submarine_pos)
			contact.detected = true
			# Radar can identify surface contacts
			if contact.type == Contact.ContactType.SURFACE_SHIP:
				contact.identified = true
		else:
			# Out of range - mark as not detected (only for radar contacts)
			if contact.type != Contact.ContactType.SUBMARINE:
				contact.detected = false
				contact.identified = false


## Apply thermal layer effects to detection range
## Returns the effective detection range after thermal layer reduction
func _apply_thermal_layer_effect(
	base_range: float, observer_depth: float, target_depth: float
) -> float:
	# Check if thermal layer is between observer and target
	var crosses_thermal_layer = false

	if observer_depth < thermal_layer_depth and target_depth > thermal_layer_depth:
		crosses_thermal_layer = true
	elif observer_depth > thermal_layer_depth and target_depth < thermal_layer_depth:
		crosses_thermal_layer = true

	# If thermal layer is crossed, reduce detection range
	if crosses_thermal_layer:
		# Reduce range by thermal layer strength (0.5 = 50% reduction)
		return base_range * (1.0 - thermal_layer_strength)

	return base_range


## Enable active sonar
func enable_active_sonar() -> void:
	active_sonar_enabled = true
	_active_sonar_timer = 0.0  # Trigger immediate update


## Disable active sonar
func disable_active_sonar() -> void:
	active_sonar_enabled = false


## Enable radar
func enable_radar() -> void:
	radar_enabled = true
	_radar_timer = 0.0  # Trigger immediate update


## Disable radar
func disable_radar() -> void:
	radar_enabled = false


## Set thermal layer parameters
func set_thermal_layer(depth: float, strength: float) -> void:
	thermal_layer_depth = clamp(depth, 0.0, 1000.0)
	thermal_layer_strength = clamp(strength, 0.0, 1.0)


## Get detection type for a contact
## Returns the most accurate detection type currently available
func get_detection_type(contact: Contact) -> DetectionType:
	if not contact.detected:
		return DetectionType.PASSIVE_SONAR  # Default

	# Check if radar detected this contact
	if radar_enabled and contact.type != Contact.ContactType.SUBMARINE:
		var submarine_depth = simulation_state.submarine_depth
		if submarine_depth <= 10.0:
			return DetectionType.RADAR

	# Check if active sonar detected this contact
	if active_sonar_enabled and contact.type != Contact.ContactType.AIRCRAFT:
		return DetectionType.ACTIVE_SONAR

	# Default to passive sonar
	return DetectionType.PASSIVE_SONAR


## Get update interval for a detection type
func get_update_interval(detection_type: DetectionType) -> float:
	match detection_type:
		DetectionType.PASSIVE_SONAR:
			return PASSIVE_SONAR_UPDATE_INTERVAL
		DetectionType.ACTIVE_SONAR:
			return ACTIVE_SONAR_UPDATE_INTERVAL
		DetectionType.RADAR:
			return RADAR_UPDATE_INTERVAL
		_:
			return PASSIVE_SONAR_UPDATE_INTERVAL


## Force immediate update of all sensors
func force_update() -> void:
	_update_passive_sonar()
	if active_sonar_enabled:
		_update_active_sonar()
	if radar_enabled:
		_update_radar()


## Get all contacts detected by any sensor
func get_detected_contacts() -> Array[Contact]:
	if not simulation_state:
		return []

	return simulation_state.get_detected_contacts(simulation_state.submarine_position)


## Check if a contact is within detection range of any sensor
func is_contact_in_range(contact: Contact) -> bool:
	if not simulation_state:
		return false

	var submarine_pos = simulation_state.submarine_position
	var submarine_depth = simulation_state.submarine_depth
	var distance = submarine_pos.distance_to(contact.position)

	# Check passive sonar range
	var passive_range = _apply_thermal_layer_effect(
		passive_sonar_range, submarine_depth, contact.position.y
	)
	if distance <= passive_range and contact.type != Contact.ContactType.AIRCRAFT:
		return true

	# Check active sonar range
	if active_sonar_enabled:
		var active_range = _apply_thermal_layer_effect(
			active_sonar_range, submarine_depth, contact.position.y
		)
		if distance <= active_range and contact.type != Contact.ContactType.AIRCRAFT:
			return true

	# Check radar range
	if radar_enabled and submarine_depth <= 10.0:
		if distance <= radar_range and contact.type != Contact.ContactType.SUBMARINE:
			return true

	return false
