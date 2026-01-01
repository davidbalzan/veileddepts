extends Node
class_name ViewManager
## Manages switching between tactical map, periscope, and external views
##
## Coordinates view transitions and maintains simulation consistency.
## Ensures view transitions complete within 100ms as per requirements.

enum ViewType { TACTICAL_MAP, PERISCOPE, EXTERNAL, WHOLE_MAP }

## Current active view
var current_view: ViewType = ViewType.TACTICAL_MAP

## Camera references - set by main scene
var tactical_map_camera: Camera2D
var periscope_camera: Camera3D
var external_camera: Camera3D

## View container references for UI visibility control
var tactical_map_view: CanvasLayer
var periscope_view: Node3D
var external_view: Node3D
var whole_map_view: CanvasLayer

## Reference to simulation state for camera positioning
var simulation_state: SimulationState

## Transition start time for performance monitoring
var _transition_start_time: int = 0


func _ready() -> void:
	print("ViewManager: Initialized")
	
	# Find camera references from scene tree
	_find_camera_references()
	
	# Ensure all cameras start in correct state
	_deactivate_all_views()
	
	# Start with tactical map view active
	_activate_view(ViewType.TACTICAL_MAP)


## Find and cache camera references from the scene tree
func _find_camera_references() -> void:
	# Get references from parent (Main node)
	var main_node = get_parent()
	
	# Find tactical map camera
	var tactical_map_node = main_node.get_node_or_null("TacticalMapView")
	if tactical_map_node:
		tactical_map_view = tactical_map_node
		tactical_map_camera = tactical_map_node.get_node_or_null("Camera2D")
		if not tactical_map_camera:
			push_error("ViewManager: Tactical map Camera2D not found")
	else:
		push_error("ViewManager: TacticalMapView node not found")
	
	# Find periscope camera
	var periscope_node = main_node.get_node_or_null("PeriscopeView")
	if periscope_node:
		periscope_view = periscope_node
		periscope_camera = periscope_node.get_node_or_null("Camera3D")
		if not periscope_camera:
			push_error("ViewManager: Periscope Camera3D not found")
	else:
		push_error("ViewManager: PeriscopeView node not found")
	
	# Find external camera
	var external_node = main_node.get_node_or_null("ExternalView")
	if external_node:
		external_view = external_node
		external_camera = external_node.get_node_or_null("Camera3D")
		if not external_camera:
			push_error("ViewManager: External Camera3D not found")
	else:
		push_error("ViewManager: ExternalView node not found")
	
	# Find whole map view
	var whole_map_node = main_node.get_node_or_null("WholeMapView")
	if whole_map_node:
		whole_map_view = whole_map_node
	else:
		push_error("ViewManager: WholeMapView node not found")
	
	# Find simulation state
	simulation_state = main_node.get_node_or_null("SimulationState")
	if not simulation_state:
		push_error("ViewManager: SimulationState not found")


## Switch to the specified view type
## Ensures transition completes within 100ms (requirement 3.5)
func switch_to_view(view: ViewType) -> void:
	# Start transition timing
	_transition_start_time = Time.get_ticks_msec()
	
	# Validate view type - WHOLE_MAP is the highest valid enum (3)
	if int(view) < 0 or int(view) > ViewType.WHOLE_MAP:
		push_error("ViewManager: Invalid view type %d (max is %d)" % [view, ViewType.WHOLE_MAP])
		return
	
	# Don't switch if already in target view
	if current_view == view:
		return
	
	# Deactivate ALL views first to ensure clean state
	_deactivate_all_views()
	
	# Activate target view
	_activate_view(view)
	
	# Update current view
	current_view = view
	
	# Log transition time
	var transition_time = Time.get_ticks_msec() - _transition_start_time
	print("ViewManager: Switched to %s in %d ms" % [_view_type_to_string(view), transition_time])
	
	# Warn if transition exceeded 100ms requirement
	if transition_time > 100:
		push_warning("ViewManager: View transition took %d ms (exceeds 100ms requirement)" % transition_time)


## Deactivate all views to ensure clean state
func _deactivate_all_views() -> void:
	# Deactivate tactical map
	if tactical_map_camera:
		tactical_map_camera.enabled = false
	if tactical_map_view:
		tactical_map_view.visible = false
	
	# Deactivate periscope
	if periscope_camera:
		periscope_camera.current = false
		periscope_camera.set_current(false)  # Explicitly call set_current
	if periscope_view:
		periscope_view.visible = false
	
	# Deactivate external
	if external_camera:
		external_camera.current = false
		external_camera.set_current(false)  # Explicitly call set_current
	if external_view:
		external_view.visible = false
	
	# Deactivate whole map
	if whole_map_view:
		whole_map_view.visible = false


## Activate the specified view
func _activate_view(view: ViewType) -> void:
	match view:
		ViewType.TACTICAL_MAP:
			if tactical_map_camera:
				tactical_map_camera.enabled = true
			if tactical_map_view:
				tactical_map_view.visible = true
		
		ViewType.PERISCOPE:
			if periscope_camera:
				periscope_camera.current = true
			if periscope_view:
				periscope_view.visible = true
			# Update camera position to submarine mast
			_update_periscope_camera_position()
		
		ViewType.EXTERNAL:
			if external_camera:
				external_camera.current = true
			if external_view:
				external_view.visible = true
			# Update camera position for orbit around submarine
			_update_external_camera_position()
		
		ViewType.WHOLE_MAP:
			if whole_map_view:
				whole_map_view.visible = true


## Update periscope camera position to submarine mast position
## Requirement 5.1: Camera should be at submarine mast position
func _update_periscope_camera_position() -> void:
	if not periscope_camera or not simulation_state:
		return
	
	# Mast height above submarine center (10 meters)
	const MAST_HEIGHT: float = 10.0
	
	# Position camera at submarine position + mast height
	var mast_position = simulation_state.submarine_position
	mast_position.y += MAST_HEIGHT
	
	periscope_camera.global_position = mast_position
	
	# Set rotation based on submarine heading
	# Heading is in degrees where 0 is north (+Z), 90 is east (+X)
	var heading_rad = deg_to_rad(simulation_state.submarine_heading)
	periscope_camera.rotation.y = heading_rad


## Update external camera position for orbit around submarine
## Requirement 4.1: Third-person perspective around submarine
func _update_external_camera_position() -> void:
	if not external_camera or not simulation_state:
		return
	
	# Default orbit parameters
	const DEFAULT_DISTANCE: float = 100.0  # meters from submarine
	const DEFAULT_TILT: float = 30.0  # degrees above horizon
	const DEFAULT_ROTATION: float = 0.0  # degrees around submarine
	
	# Calculate camera position in orbit around submarine
	var submarine_pos = simulation_state.submarine_position
	
	# Convert tilt and rotation to radians
	var tilt_rad = deg_to_rad(DEFAULT_TILT)
	var rotation_rad = deg_to_rad(DEFAULT_ROTATION)
	
	# Calculate offset from submarine
	var horizontal_distance = DEFAULT_DISTANCE * cos(tilt_rad)
	var vertical_offset = DEFAULT_DISTANCE * sin(tilt_rad)
	
	var offset = Vector3(
		horizontal_distance * sin(rotation_rad),
		vertical_offset,
		horizontal_distance * cos(rotation_rad)
	)
	
	# Set camera position
	external_camera.global_position = submarine_pos + offset
	
	# Look at submarine
	external_camera.look_at(submarine_pos, Vector3.UP)


## Get the currently active camera
## Returns the camera node for the current view, or null if not found
func get_active_camera() -> Node:
	match current_view:
		ViewType.TACTICAL_MAP:
			return tactical_map_camera
		ViewType.PERISCOPE:
			return periscope_camera
		ViewType.EXTERNAL:
			return external_camera
	return null


## Convert ViewType enum to string for logging
func _view_type_to_string(view: ViewType) -> String:
	match view:
		ViewType.TACTICAL_MAP:
			return "TACTICAL_MAP"
		ViewType.PERISCOPE:
			return "PERISCOPE"
		ViewType.EXTERNAL:
			return "EXTERNAL"
		ViewType.WHOLE_MAP:
			return "WHOLE_MAP"
	return "UNKNOWN"


## Process function to update camera positions each frame
func _process(_delta: float) -> void:
	# Update camera positions based on current view
	match current_view:
		ViewType.PERISCOPE:
			_update_periscope_camera_position()
		ViewType.EXTERNAL:
			_update_external_camera_position()
