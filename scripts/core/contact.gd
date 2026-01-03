class_name Contact extends Resource

## Contact represents a detected entity (ship, aircraft, or submarine)
## displayed on sonar, radar, or ESM systems.

enum ContactType { SURFACE_SHIP, AIRCRAFT, SUBMARINE }

## Unique identifier for this contact
@export var id: int = 0

## Type of contact (surface ship, aircraft, or submarine)
@export var type: ContactType = ContactType.SURFACE_SHIP

## 3D position in world space
@export var position: Vector3 = Vector3.ZERO

## Velocity vector in m/s
@export var velocity: Vector3 = Vector3.ZERO

## Whether this contact has been detected by sensors
@export var detected: bool = false

## Whether this contact has been identified (type confirmed)
@export var identified: bool = false

## Cached bearing in degrees (0-360, where 0 is north)
var _cached_bearing: float = 0.0

## Cached range in meters
var _cached_range: float = 0.0

## Whether cached values are valid
var _cache_valid: bool = false


## Calculate bearing from observer position to this contact
## Returns bearing in degrees (0-360, where 0 is north, 90 is east)
func calculate_bearing(observer_position: Vector3) -> float:
	var delta = position - observer_position
	# Unified coordinate system: atan2(x, -z) where -Z is North, +X is East
	# This gives: North=0°, East=90°, South=180°, West=270°
	var bearing_rad = atan2(delta.x, -delta.z)
	var bearing_deg = rad_to_deg(bearing_rad)

	# Normalize to 0-360 range
	if bearing_deg < 0:
		bearing_deg += 360.0

	_cached_bearing = bearing_deg
	return bearing_deg


## Calculate range from observer position to this contact
## Returns range in meters
func calculate_range(observer_position: Vector3) -> float:
	var delta = position - observer_position
	var range_meters = delta.length()

	_cached_range = range_meters
	return range_meters


## Get the last calculated bearing (cached value)
## Call calculate_bearing first to update the cache
func get_bearing() -> float:
	return _cached_bearing


## Get the last calculated range (cached value)
## Call calculate_range first to update the cache
func get_range() -> float:
	return _cached_range


## Update both bearing and range from observer position
## This is more efficient than calling both methods separately
func update_bearing_and_range(observer_position: Vector3) -> void:
	var delta = position - observer_position

	# Calculate range
	_cached_range = delta.length()

	# Calculate bearing using unified coordinate system
	# atan2(x, -z) where -Z is North, +X is East
	var bearing_rad = atan2(delta.x, -delta.z)
	var bearing_deg = rad_to_deg(bearing_rad)

	# Normalize to 0-360 range
	if bearing_deg < 0:
		bearing_deg += 360.0

	_cached_bearing = bearing_deg
	_cache_valid = true


## Create a duplicate of this contact
func duplicate_contact() -> Contact:
	var new_contact = Contact.new()
	new_contact.id = id
	new_contact.type = type
	new_contact.position = position
	new_contact.velocity = velocity
	new_contact.detected = detected
	new_contact.identified = identified
	new_contact._cached_bearing = _cached_bearing
	new_contact._cached_range = _cached_range
	new_contact._cache_valid = _cache_valid
	return new_contact
