extends Node
class_name InputSystem
## Processes player input and routes to appropriate handlers
##
## Routes input events to appropriate view handlers based on current view.
## Implements view toggle shortcuts (Tab, 1, 2, 3) as per requirements 15.1, 15.2, 15.3.
## Handles keyboard input for speed/depth adjustments, mouse input for waypoint placement,
## and mouse input for periscope/camera controls.

var view_manager: ViewManager
var current_view: Node
var simulation_state: SimulationState

## View references for input routing
var tactical_map_view: TacticalMapView
var periscope_view: PeriscopeView
var external_view: ExternalView

## Input customization system
var custom_bindings: Dictionary = {}
var config_file_path: String = "user://input_config.cfg"
var input_remapping_ui: Control = null
var is_remapping_ui_visible: bool = false

## Default input bindings (fallback)
var default_bindings: Dictionary = {
	"view_cycle": [KEY_TAB],
	"view_tactical": [KEY_1],
	"view_periscope": [KEY_2],
	"view_external": [KEY_3],
	"view_whole_map": [KEY_4],
	"speed_increase": [KEY_W, KEY_UP],
	"speed_decrease": [KEY_S, KEY_DOWN],
	"turn_left": [KEY_A, KEY_LEFT],
	"turn_right": [KEY_D, KEY_RIGHT],
	"depth_decrease": [KEY_Q],  # Go shallower
	"depth_increase": [KEY_E],  # Go deeper
	"emergency_stop": [KEY_SPACE],
	"show_input_config": [KEY_F4],  # Show input configuration UI
	"toggle_terrain_debug": [KEY_F5]  # Toggle terrain debug overlay
}

## Speed and heading control parameters
const SPEED_INCREMENT: float = 1.0  # m/s per key press
const HEADING_INCREMENT: float = 5.0  # degrees per key press
const DEPTH_INCREMENT: float = 5.0  # meters per key press


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

	# Get references to view nodes for input routing
	var main_node = get_parent()
	tactical_map_view = main_node.get_node_or_null("TacticalMapView")
	periscope_view = main_node.get_node_or_null("PeriscopeView")
	external_view = main_node.get_node_or_null("ExternalView")

	if not tactical_map_view:
		push_warning("InputSystem: TacticalMapView not found")
	if not periscope_view:
		push_warning("InputSystem: PeriscopeView not found")
	if not external_view:
		push_warning("InputSystem: ExternalView not found")

	# Load custom input bindings
	load_custom_bindings()

	# Create input remapping UI
	_create_input_remapping_ui()


func _input(event: InputEvent) -> void:
	"""Process input events and route to appropriate handlers."""

	# Handle global view switching first (always available)
	if _handle_view_switching(event):
		return  # View switching handled, don't process other input

	# Handle global submarine controls (available in all views)
	if _handle_global_submarine_controls(event):
		return  # Global controls handled

	# Route input to current view handler
	if view_manager:
		match view_manager.current_view:
			ViewManager.ViewType.TACTICAL_MAP:
				handle_tactical_input(event)
			ViewManager.ViewType.PERISCOPE:
				handle_periscope_input(event)
			ViewManager.ViewType.EXTERNAL:
				handle_external_input(event)
			ViewManager.ViewType.WHOLE_MAP:
				# Whole map uses same input as tactical map
				handle_tactical_input(event)


## Handle view switching input (Tab, 1, 2, 3)
## Requirements 15.1, 15.2, 15.3: View toggle shortcuts
func _handle_view_switching(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false

	var key_event = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false

	# Check for input configuration UI toggle first
	if _is_key_bound_to_action(key_event.keycode, "show_input_config"):
		_toggle_input_remapping_ui()
		return true

	# Handle view toggle shortcuts using custom bindings
	if _is_key_bound_to_action(key_event.keycode, "view_cycle"):
		handle_view_toggle_cycle()
		return true
	elif _is_key_bound_to_action(key_event.keycode, "view_tactical"):
		handle_view_toggle(ViewManager.ViewType.TACTICAL_MAP)
		return true
	elif _is_key_bound_to_action(key_event.keycode, "view_periscope"):
		handle_view_toggle(ViewManager.ViewType.PERISCOPE)
		return true
	elif _is_key_bound_to_action(key_event.keycode, "view_external"):
		handle_view_toggle(ViewManager.ViewType.EXTERNAL)
		return true
	elif _is_key_bound_to_action(key_event.keycode, "view_whole_map"):
		handle_view_toggle(ViewManager.ViewType.WHOLE_MAP)
		return true

	return false


## Handle global submarine controls (available in all views)
## Requirements 15.1: Keyboard input for speed and depth adjustments
func _handle_global_submarine_controls(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false

	var key_event = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false

	# Use custom bindings for submarine controls
	if _is_key_bound_to_action(key_event.keycode, "speed_increase"):
		_increase_speed()
		return true
	elif _is_key_bound_to_action(key_event.keycode, "speed_decrease"):
		_decrease_speed()
		return true
	elif _is_key_bound_to_action(key_event.keycode, "turn_left"):
		_turn_left()
		return true
	elif _is_key_bound_to_action(key_event.keycode, "turn_right"):
		_turn_right()
		return true
	elif _is_key_bound_to_action(key_event.keycode, "depth_decrease"):
		_decrease_depth()  # Go shallower
		return true
	elif _is_key_bound_to_action(key_event.keycode, "depth_increase"):
		_increase_depth()  # Go deeper
		return true
	elif _is_key_bound_to_action(key_event.keycode, "emergency_stop"):
		_emergency_stop()
		return true
	elif _is_key_bound_to_action(key_event.keycode, "toggle_terrain_debug"):
		_toggle_terrain_debug()
		return true

	return false


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


## Increase submarine depth (go deeper)
func _increase_depth() -> void:
	if not simulation_state:
		return

	var new_depth = simulation_state.target_depth + DEPTH_INCREMENT
	new_depth = clamp(new_depth, SimulationState.MIN_DEPTH, SimulationState.MAX_DEPTH)
	simulation_state.set_target_depth(new_depth)
	print("Depth increased to %.0f m" % new_depth)


## Decrease submarine depth (go shallower)
func _decrease_depth() -> void:
	if not simulation_state:
		return

	var new_depth = simulation_state.target_depth - DEPTH_INCREMENT
	new_depth = clamp(new_depth, SimulationState.MIN_DEPTH, SimulationState.MAX_DEPTH)
	simulation_state.set_target_depth(new_depth)
	print("Depth decreased to %.0f m" % new_depth)


## Emergency stop - set speed to zero
func _emergency_stop() -> void:
	if not simulation_state:
		return

	simulation_state.set_target_speed(0.0)
	print("Emergency stop - speed set to 0 m/s")


## Toggle terrain debug overlay
func _toggle_terrain_debug() -> void:
	var main = get_parent()
	var terrain_renderer = main.get_node_or_null("TerrainRenderer")
	if terrain_renderer and terrain_renderer.has_method("toggle_debug_overlay"):
		terrain_renderer.toggle_debug_overlay()
	else:
		print("InputSystem: TerrainRenderer or toggle_debug_overlay not found")


## Handle view toggle input
func handle_view_toggle(view_type: ViewManager.ViewType) -> void:
	"""Handle view toggle input."""
	if view_manager:
		# If already in the target view, toggle back to Tactical Map (only for Whole Map for now)
		if view_manager.current_view == view_type and view_type == ViewManager.ViewType.WHOLE_MAP:
			print("InputSystem: Toggling back to Tactical Map from Whole Map")
			view_manager.switch_to_view(ViewManager.ViewType.TACTICAL_MAP)
			return

		print("InputSystem: Switching to view %d" % view_type)
		view_manager.switch_to_view(view_type)


## Handle view toggle cycle (Tab key)
func handle_view_toggle_cycle() -> void:
	"""Cycle through views in order: Tactical -> Periscope -> External -> Tactical."""
	if not view_manager:
		return

	var next_view: ViewManager.ViewType
	match view_manager.current_view:
		ViewManager.ViewType.TACTICAL_MAP:
			next_view = ViewManager.ViewType.PERISCOPE
		ViewManager.ViewType.PERISCOPE:
			next_view = ViewManager.ViewType.EXTERNAL
		ViewManager.ViewType.EXTERNAL:
			next_view = ViewManager.ViewType.TACTICAL_MAP
		ViewManager.ViewType.WHOLE_MAP:
			next_view = ViewManager.ViewType.TACTICAL_MAP
		_:
			next_view = ViewManager.ViewType.TACTICAL_MAP

	view_manager.switch_to_view(next_view)


## Handle input specific to tactical map view
## Requirements 15.2: Mouse input for waypoint placement
func handle_tactical_input(event: InputEvent) -> void:
	"""Handle input specific to tactical map view."""
	if not tactical_map_view:
		return

	# Tactical map view handles its own input internally
	# This function is here for consistency and future expansion
	# The tactical map view processes mouse clicks for waypoint placement
	# and other tactical map specific controls
	pass


## Handle input specific to periscope view
## Requirements 15.3: Mouse input for periscope rotation and zoom
func handle_periscope_input(event: InputEvent) -> void:
	"""Handle input specific to periscope view."""
	if not periscope_view:
		return

	# Periscope view handles its own input internally
	# This function is here for consistency and future expansion
	# The periscope view processes mouse movement for rotation
	# and mouse wheel for zoom
	pass


## Handle input specific to external view
func handle_external_input(event: InputEvent) -> void:
	"""Handle input specific to external view."""
	if not external_view:
		return

	# External view handles its own input internally
	# This function is here for consistency and future expansion
	# The external view processes mouse input for camera orbit controls
	pass


## Check if a key is bound to a specific action
func _is_key_bound_to_action(keycode: int, action: String) -> bool:
	var bindings = custom_bindings.get(action, default_bindings.get(action, []))
	return keycode in bindings


## Load custom input bindings from config file
## Requirement 15.4: Save/load custom bindings to config file
func load_custom_bindings() -> void:
	var config = ConfigFile.new()
	var err = config.load(config_file_path)

	if err != OK:
		print("InputSystem: No custom bindings found, using defaults")
		custom_bindings = default_bindings.duplicate()
		return

	# Load custom bindings from config file
	custom_bindings = {}
	for action in default_bindings.keys():
		var saved_bindings = config.get_value("input", action, default_bindings[action])
		custom_bindings[action] = saved_bindings

	print("InputSystem: Custom bindings loaded from ", config_file_path)


## Save custom input bindings to config file
## Requirement 15.4: Save/load custom bindings to config file
func save_custom_bindings() -> void:
	var config = ConfigFile.new()

	# Save all custom bindings
	for action in custom_bindings.keys():
		config.set_value("input", action, custom_bindings[action])

	var err = config.save(config_file_path)
	if err == OK:
		print("InputSystem: Custom bindings saved to ", config_file_path)
	else:
		push_error("InputSystem: Failed to save custom bindings: " + str(err))


## Set custom binding for an action
## Requirement 15.4: Custom input binding functionality
func set_custom_binding(action: String, keycodes: Array) -> void:
	if action in default_bindings:
		custom_bindings[action] = keycodes
		save_custom_bindings()
		print("InputSystem: Set custom binding for ", action, ": ", keycodes)
	else:
		push_error("InputSystem: Unknown action: " + action)


## Reset bindings to defaults
func reset_to_defaults() -> void:
	custom_bindings = default_bindings.duplicate()
	save_custom_bindings()
	if input_remapping_ui:
		_refresh_input_remapping_ui()
	print("InputSystem: Reset all bindings to defaults")


## Create input remapping UI
## Requirement 15.4: Add input remapping UI
func _create_input_remapping_ui() -> void:
	# Create main UI container
	input_remapping_ui = Control.new()
	input_remapping_ui.name = "InputRemappingUI"
	input_remapping_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_remapping_ui.visible = false
	input_remapping_ui.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input when visible
	add_child(input_remapping_ui)

	# Semi-transparent background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_remapping_ui.add_child(background)

	# Main panel
	var panel = Panel.new()
	panel.name = "MainPanel"
	panel.position = Vector2(300, 150)
	panel.size = Vector2(1320, 780)
	input_remapping_ui.add_child(panel)

	# Title
	var title = Label.new()
	title.text = "INPUT CONFIGURATION"
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	panel.add_child(title)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Click on a key binding to change it. Press the new key to assign it."
	instructions.position = Vector2(20, 70)
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	panel.add_child(instructions)

	# Scroll container for bindings
	var scroll = ScrollContainer.new()
	scroll.name = "BindingsScroll"
	scroll.position = Vector2(20, 110)
	scroll.size = Vector2(1280, 580)
	panel.add_child(scroll)

	# VBox for binding entries
	var vbox = VBoxContainer.new()
	vbox.name = "BindingsContainer"
	scroll.add_child(vbox)

	# Create binding entries
	_create_binding_entries(vbox)

	# Button container
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(20, 710)
	button_container.custom_minimum_size = Vector2(1280, 50)
	panel.add_child(button_container)

	# Reset to defaults button
	var reset_button = Button.new()
	reset_button.text = "Reset to Defaults"
	reset_button.custom_minimum_size = Vector2(200, 40)
	reset_button.pressed.connect(reset_to_defaults)
	button_container.add_child(reset_button)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(spacer)

	# Close button
	var close_button = Button.new()
	close_button.text = "Close (F4)"
	close_button.custom_minimum_size = Vector2(150, 40)
	close_button.pressed.connect(_toggle_input_remapping_ui)
	button_container.add_child(close_button)


## Create binding entries in the UI
func _create_binding_entries(container: VBoxContainer) -> void:
	var action_descriptions = {
		"view_cycle": "Cycle Views",
		"view_tactical": "Tactical Map View",
		"view_periscope": "Periscope View",
		"view_external": "External View",
		"speed_increase": "Increase Speed",
		"speed_decrease": "Decrease Speed",
		"turn_left": "Turn Left",
		"turn_right": "Turn Right",
		"depth_decrease": "Decrease Depth (Shallower)",
		"depth_increase": "Increase Depth (Deeper)",
		"emergency_stop": "Emergency Stop",
		"show_input_config": "Show Input Configuration",
		"toggle_terrain_debug": "Toggle Terrain Debug"
	}

	for action in default_bindings.keys():
		var entry_container = HBoxContainer.new()
		entry_container.name = action + "_container"
		entry_container.custom_minimum_size = Vector2(0, 40)
		container.add_child(entry_container)

		# Action description
		var desc_label = Label.new()
		desc_label.text = action_descriptions.get(action, action)
		desc_label.custom_minimum_size = Vector2(300, 0)
		desc_label.add_theme_font_size_override("font_size", 16)
		entry_container.add_child(desc_label)

		# Current binding display/button
		var binding_button = Button.new()
		binding_button.name = action + "_button"
		binding_button.custom_minimum_size = Vector2(400, 35)
		binding_button.pressed.connect(_start_key_remapping.bind(action))
		entry_container.add_child(binding_button)

		# Update button text
		_update_binding_button_text(action)


## Update binding button text to show current keys
func _update_binding_button_text(action: String) -> void:
	var button = input_remapping_ui.get_node(
		"MainPanel/BindingsScroll/BindingsContainer/" + action + "_container/" + action + "_button"
	)
	if not button:
		return

	var bindings = custom_bindings.get(action, default_bindings.get(action, []))
	var key_names = []
	for keycode in bindings:
		key_names.append(OS.get_keycode_string(keycode))

	button.text = " + ".join(key_names) if key_names.size() > 0 else "None"


## Start key remapping for an action
var remapping_action: String = ""
var remapping_button: Button = null


func _start_key_remapping(action: String) -> void:
	remapping_action = action
	remapping_button = input_remapping_ui.get_node(
		"MainPanel/BindingsScroll/BindingsContainer/" + action + "_container/" + action + "_button"
	)

	if remapping_button:
		remapping_button.text = "Press new key..."
		remapping_button.add_theme_color_override("font_color", Color.YELLOW)


## Handle key remapping input
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_remapping_ui_visible or remapping_action == "":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event = event as InputEventKey

		# Cancel remapping with Escape
		if key_event.keycode == KEY_ESCAPE:
			_cancel_key_remapping()
			return

		# Set new binding
		set_custom_binding(remapping_action, [key_event.keycode])
		_update_binding_button_text(remapping_action)

		# Reset remapping state
		if remapping_button:
			remapping_button.remove_theme_color_override("font_color")
		remapping_action = ""
		remapping_button = null

		get_viewport().set_input_as_handled()


## Cancel key remapping
func _cancel_key_remapping() -> void:
	if remapping_button:
		_update_binding_button_text(remapping_action)
		remapping_button.remove_theme_color_override("font_color")
	remapping_action = ""
	remapping_button = null


## Toggle input remapping UI visibility
func _toggle_input_remapping_ui() -> void:
	if not input_remapping_ui:
		return

	is_remapping_ui_visible = not is_remapping_ui_visible
	input_remapping_ui.visible = is_remapping_ui_visible

	if is_remapping_ui_visible:
		_refresh_input_remapping_ui()
		print("InputSystem: Input configuration UI opened")
	else:
		_cancel_key_remapping()  # Cancel any ongoing remapping
		print("InputSystem: Input configuration UI closed")


## Refresh the input remapping UI
func _refresh_input_remapping_ui() -> void:
	if not input_remapping_ui:
		return

	for action in default_bindings.keys():
		_update_binding_button_text(action)
