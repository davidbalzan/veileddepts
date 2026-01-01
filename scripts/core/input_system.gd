extends Node
class_name InputSystem
## Processes player input and routes to appropriate handlers

var view_manager: ViewManager
var current_view: Node
var simulation_state: SimulationState

## Speed and heading control parameters
const SPEED_INCREMENT: float = 1.0  # m/s per key press
const HEADING_INCREMENT: float = 5.0  # degrees per key press

func _ready() -> void:
	print("InputSystem: Initialized")
	
	# Get reference to ViewManager
	view_manager = get_parent().get_node("ViewManager")
	if not view_manager:
		push_error("InputSystem: ViewManager not found")
	
	# Get reference to SimulationState
	simulation_state = get_parent().get_node("SimulationState")
	if not simulation_state:
		push_error("InputSystem: SimulationState not found")

func _input(event: InputEvent) -> void:
	"""Process input events and route to appropriate handlers."""
	# View switching
	if event.is_action_pressed("view_tactical"):
		handle_view_toggle(ViewManager.ViewType.TACTICAL_MAP)
	elif event.is_action_pressed("view_periscope"):
		handle_view_toggle(ViewManager.ViewType.PERISCOPE)
	elif event.is_action_pressed("view_external"):
		handle_view_toggle(ViewManager.ViewType.EXTERNAL)
	elif event.is_action_pressed("view_toggle_cycle"):
		_cycle_view()
	
	# Speed controls (W/S or Up/Down arrows)
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W):
		_increase_speed()
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S):
		_decrease_speed()
	
	# Heading controls (A/D or Left/Right arrows)
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A):
		_turn_left()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D):
		_turn_right()
	
	# Emergency stop (Space)
	elif event.is_action_pressed("ui_select") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		_emergency_stop()


## Increase submarine speed
func _increase_speed() -> void:
	if not simulation_state:
		return
	
	var new_speed = simulation_state.target_speed + SPEED_INCREMENT
	new_speed = clamp(new_speed, -SimulationState.MAX_SPEED * 0.5, SimulationState.MAX_SPEED)
	simulation_state.set_target_speed(new_speed)
	print("Speed increased to %.1f m/s" % new_speed)


## Decrease submarine speed
func _decrease_speed() -> void:
	if not simulation_state:
		return
	
	var new_speed = simulation_state.target_speed - SPEED_INCREMENT
	new_speed = clamp(new_speed, -SimulationState.MAX_SPEED * 0.5, SimulationState.MAX_SPEED)
	simulation_state.set_target_speed(new_speed)
	print("Speed decreased to %.1f m/s" % new_speed)


## Turn submarine left (port)
func _turn_left() -> void:
	if not simulation_state:
		return
	
	var new_heading = simulation_state.target_heading - HEADING_INCREMENT
	while new_heading < 0:
		new_heading += 360.0
	simulation_state.set_target_heading(new_heading)
	print("Heading turned to %.0f°" % new_heading)


## Turn submarine right (starboard)
func _turn_right() -> void:
	if not simulation_state:
		return
	
	var new_heading = simulation_state.target_heading + HEADING_INCREMENT
	while new_heading >= 360:
		new_heading -= 360.0
	simulation_state.set_target_heading(new_heading)
	print("Heading turned to %.0f°" % new_heading)


## Emergency stop - set speed to zero
func _emergency_stop() -> void:
	if not simulation_state:
		return
	
	simulation_state.set_target_speed(0.0)
	print("Emergency stop - speed set to 0 m/s")

func handle_view_toggle(view_type: ViewManager.ViewType) -> void:
	"""Handle view toggle input."""
	if view_manager:
		print("InputSystem: Switching to view %d" % view_type)
		view_manager.switch_to_view(view_type)

func _cycle_view() -> void:
	"""Cycle through views in order."""
	if not view_manager:
		return
	
	var next_view = (view_manager.current_view + 1) % 3
	view_manager.switch_to_view(next_view)

func handle_tactical_input(_event: InputEvent) -> void:
	"""Handle input specific to tactical map view."""
	# Implementation will be added in Task 4
	pass

func handle_periscope_input(_event: InputEvent) -> void:
	"""Handle input specific to periscope view."""
	# Implementation will be added in Task 8
	pass

func handle_external_input(_event: InputEvent) -> void:
	"""Handle input specific to external view."""
	# Implementation will be added in Task 9
	pass
