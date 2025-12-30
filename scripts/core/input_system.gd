extends Node
class_name InputSystem
## Processes player input and routes to appropriate handlers

var view_manager: ViewManager
var current_view: Node

func _ready() -> void:
	print("InputSystem: Initialized")
	
	# Get reference to ViewManager
	view_manager = get_parent().get_node("ViewManager")
	if not view_manager:
		push_error("InputSystem: ViewManager not found")

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
