extends Node
## Manages visibility and state of debug overlays
##
## Responsibilities:
## - Control master debug toggle for all panels
## - Manage individual panel visibility
## - Register and track debug panels
## - Ensure proper z-ordering (layer 5, below console at layer 10)
## - Ensure panels use MOUSE_FILTER_IGNORE for pass-through input
##
## Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7

## Master debug state
var debug_enabled: bool = false

## Registered panels: name -> Node reference
var _panel_references: Dictionary = {}

## Individual panel visibility states: name -> bool
var _active_panels: Dictionary = {}

## Signals
signal debug_mode_changed(enabled: bool)
signal panel_toggled(panel_name: String, visible: bool)


func _ready() -> void:
	# Debug panels start disabled by default
	debug_enabled = false


## Enable all registered debug panels
func enable_all() -> void:
	if debug_enabled:
		return
	
	debug_enabled = true
	debug_mode_changed.emit(true)
	
	# Show all registered panels
	for panel_name in _panel_references.keys():
		_set_panel_visible(panel_name, true)
	
	LogRouter.log("Debug mode enabled - all panels visible", LogRouter.LogLevel.INFO, "debug")


## Disable all registered debug panels
func disable_all() -> void:
	if not debug_enabled:
		return
	
	debug_enabled = false
	debug_mode_changed.emit(false)
	
	# Hide all registered panels
	for panel_name in _panel_references.keys():
		_set_panel_visible(panel_name, false)
	
	LogRouter.log("Debug mode disabled - all panels hidden", LogRouter.LogLevel.INFO, "debug")


## Toggle a specific debug panel by name
## Returns true if the panel was toggled, false if panel not found
func toggle_panel(panel_name: String) -> bool:
	if not _panel_references.has(panel_name):
		LogRouter.log(
			"Cannot toggle panel '%s' - not registered" % panel_name,
			LogRouter.LogLevel.WARNING,
			"debug"
		)
		return false
	
	var current_state: bool = _active_panels.get(panel_name, false)
	var new_state: bool = not current_state
	
	_set_panel_visible(panel_name, new_state)
	
	LogRouter.log(
		"Panel '%s' toggled: %s" % [panel_name, "visible" if new_state else "hidden"],
		LogRouter.LogLevel.INFO,
		"debug"
	)
	
	return true


## Check if a specific panel is currently visible
func is_panel_visible(panel_name: String) -> bool:
	return _active_panels.get(panel_name, false)


## Register a debug panel with the manager
## panel_name: Unique identifier for the panel
## node: The Node instance (should be CanvasLayer or Control)
func register_panel(panel_name: String, node: Node) -> void:
	if _panel_references.has(panel_name):
		LogRouter.log(
			"Panel '%s' already registered, replacing reference" % panel_name,
			LogRouter.LogLevel.WARNING,
			"debug"
		)
	
	_panel_references[panel_name] = node
	_active_panels[panel_name] = false
	
	# Configure panel properties
	_configure_panel(node)
	
	# Initially hide the panel
	_set_panel_visible(panel_name, false)
	
	LogRouter.log(
		"Debug panel '%s' registered" % panel_name,
		LogRouter.LogLevel.INFO,
		"debug"
	)


## Unregister a debug panel
func unregister_panel(panel_name: String) -> void:
	if not _panel_references.has(panel_name):
		return
	
	_panel_references.erase(panel_name)
	_active_panels.erase(panel_name)
	
	LogRouter.log(
		"Debug panel '%s' unregistered" % panel_name,
		LogRouter.LogLevel.INFO,
		"debug"
	)


## Get list of all registered panel names
func get_registered_panels() -> Array[String]:
	var panels: Array[String] = []
	for panel_name in _panel_references.keys():
		panels.append(panel_name)
	return panels


## Get the current debug mode state
func is_debug_enabled() -> bool:
	return debug_enabled


## Configure a panel with proper settings
func _configure_panel(node: Node) -> void:
	# Set layer to 5 (below console at layer 10)
	if node is CanvasLayer:
		node.layer = 5
	
	# Ensure mouse input passes through
	_set_mouse_filter_recursive(node, Control.MOUSE_FILTER_IGNORE)


## Recursively set mouse filter on all Control nodes
func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		# Only set MOUSE_FILTER_IGNORE on background/container elements
		# Don't override interactive elements like buttons
		if node is Panel or node is PanelContainer or node is MarginContainer:
			node.mouse_filter = filter
		elif node is VBoxContainer or node is HBoxContainer:
			node.mouse_filter = filter
	
	# Recurse to children
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


## Set panel visibility and update state
func _set_panel_visible(panel_name: String, visible: bool) -> void:
	var node: Node = _panel_references.get(panel_name)
	if not node:
		return
	
	# Update visibility
	if node is CanvasLayer or node is Control:
		node.visible = visible
	elif node.has_method("set_enabled"):
		# For custom debug panels with enable/disable methods
		node.set_enabled(visible)
	
	# Update state tracking
	_active_panels[panel_name] = visible
	
	# Emit signal
	panel_toggled.emit(panel_name, visible)


## Get debug panel node by name (for direct access if needed)
func get_panel(panel_name: String) -> Node:
	return _panel_references.get(panel_name)
