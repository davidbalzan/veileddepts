extends GutTest
## Unit tests for DebugPanelManager
##
## Tests the debug panel management system including:
## - Panel registration and unregistration
## - Enable/disable all panels
## - Toggle individual panels
## - Panel visibility state tracking
## - Layer configuration
## - Mouse filter configuration

var manager: Node
var test_panel: CanvasLayer


func before_each() -> void:
	# Get the autoload singleton
	manager = get_node("/root/DebugPanelManager")
	assert_not_null(manager, "DebugPanelManager autoload should exist")
	
	# Create a test panel
	test_panel = CanvasLayer.new()
	test_panel.name = "TestPanel"
	test_panel.layer = 100  # Start with high layer
	add_child_autofree(test_panel)


func after_each() -> void:
	# Clean up any registered panels
	if manager:
		for panel_name in manager.get_registered_panels():
			manager.unregister_panel(panel_name)


func test_register_panel_adds_to_registry() -> void:
	# Arrange & Act
	manager.register_panel("test", test_panel)
	
	# Assert
	var panels: Array = manager.get_registered_panels()
	assert_true(panels.has("test"), "Panel should be registered")
	assert_eq(manager.get_panel("test"), test_panel, "Should return correct panel reference")


func test_register_panel_sets_layer_to_5() -> void:
	# Arrange & Act
	manager.register_panel("test", test_panel)
	
	# Assert
	assert_eq(test_panel.layer, 5, "Panel layer should be set to 5")


func test_register_panel_starts_hidden() -> void:
	# Arrange & Act
	manager.register_panel("test", test_panel)
	
	# Assert
	assert_false(test_panel.visible, "Panel should start hidden")
	assert_false(manager.is_panel_visible("test"), "Manager should track panel as hidden")


func test_unregister_panel_removes_from_registry() -> void:
	# Arrange
	manager.register_panel("test", test_panel)
	
	# Act
	manager.unregister_panel("test")
	
	# Assert
	var panels: Array = manager.get_registered_panels()
	assert_false(panels.has("test"), "Panel should be unregistered")
	assert_null(manager.get_panel("test"), "Should return null for unregistered panel")


func test_enable_all_shows_all_panels() -> void:
	# Arrange
	var panel1: CanvasLayer = CanvasLayer.new()
	var panel2: CanvasLayer = CanvasLayer.new()
	add_child_autofree(panel1)
	add_child_autofree(panel2)
	
	manager.register_panel("panel1", panel1)
	manager.register_panel("panel2", panel2)
	
	# Act
	manager.enable_all()
	
	# Assert
	assert_true(manager.is_debug_enabled(), "Debug mode should be enabled")
	assert_true(panel1.visible, "Panel 1 should be visible")
	assert_true(panel2.visible, "Panel 2 should be visible")
	assert_true(manager.is_panel_visible("panel1"), "Manager should track panel1 as visible")
	assert_true(manager.is_panel_visible("panel2"), "Manager should track panel2 as visible")


func test_disable_all_hides_all_panels() -> void:
	# Arrange
	var panel1: CanvasLayer = CanvasLayer.new()
	var panel2: CanvasLayer = CanvasLayer.new()
	add_child_autofree(panel1)
	add_child_autofree(panel2)
	
	manager.register_panel("panel1", panel1)
	manager.register_panel("panel2", panel2)
	manager.enable_all()
	
	# Act
	manager.disable_all()
	
	# Assert
	assert_false(manager.is_debug_enabled(), "Debug mode should be disabled")
	assert_false(panel1.visible, "Panel 1 should be hidden")
	assert_false(panel2.visible, "Panel 2 should be hidden")
	assert_false(manager.is_panel_visible("panel1"), "Manager should track panel1 as hidden")
	assert_false(manager.is_panel_visible("panel2"), "Manager should track panel2 as hidden")


func test_toggle_panel_changes_visibility() -> void:
	# Arrange
	manager.register_panel("test", test_panel)
	assert_false(test_panel.visible, "Panel should start hidden")
	
	# Act - toggle on
	var result1: bool = manager.toggle_panel("test")
	
	# Assert
	assert_true(result1, "Toggle should return true for registered panel")
	assert_true(test_panel.visible, "Panel should be visible after toggle")
	assert_true(manager.is_panel_visible("test"), "Manager should track panel as visible")
	
	# Act - toggle off
	var result2: bool = manager.toggle_panel("test")
	
	# Assert
	assert_true(result2, "Toggle should return true for registered panel")
	assert_false(test_panel.visible, "Panel should be hidden after second toggle")
	assert_false(manager.is_panel_visible("test"), "Manager should track panel as hidden")


func test_toggle_nonexistent_panel_returns_false() -> void:
	# Act
	var result: bool = manager.toggle_panel("nonexistent")
	
	# Assert
	assert_false(result, "Toggle should return false for unregistered panel")


func test_enable_all_idempotent() -> void:
	# Arrange
	manager.register_panel("test", test_panel)
	manager.enable_all()
	
	# Act - enable again
	manager.enable_all()
	
	# Assert - should still be enabled with no errors
	assert_true(manager.is_debug_enabled(), "Debug mode should still be enabled")
	assert_true(test_panel.visible, "Panel should still be visible")


func test_disable_all_idempotent() -> void:
	# Arrange
	manager.register_panel("test", test_panel)
	
	# Act - disable when already disabled
	manager.disable_all()
	
	# Assert - should still be disabled with no errors
	assert_false(manager.is_debug_enabled(), "Debug mode should still be disabled")
	assert_false(test_panel.visible, "Panel should still be hidden")


func test_panel_with_control_children_gets_mouse_filter_ignore() -> void:
	# Arrange
	var panel_container: PanelContainer = PanelContainer.new()
	var vbox: VBoxContainer = VBoxContainer.new()
	test_panel.add_child(panel_container)
	panel_container.add_child(vbox)
	
	# Act
	manager.register_panel("test", test_panel)
	
	# Assert
	assert_eq(
		panel_container.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"PanelContainer should have MOUSE_FILTER_IGNORE"
	)
	assert_eq(
		vbox.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"VBoxContainer should have MOUSE_FILTER_IGNORE"
	)


func test_get_registered_panels_returns_all_panel_names() -> void:
	# Arrange
	var panel1: CanvasLayer = CanvasLayer.new()
	var panel2: CanvasLayer = CanvasLayer.new()
	var panel3: CanvasLayer = CanvasLayer.new()
	add_child_autofree(panel1)
	add_child_autofree(panel2)
	add_child_autofree(panel3)
	
	manager.register_panel("panel1", panel1)
	manager.register_panel("panel2", panel2)
	manager.register_panel("panel3", panel3)
	
	# Act
	var panels: Array = manager.get_registered_panels()
	
	# Assert
	assert_eq(panels.size(), 3, "Should return 3 panel names")
	assert_true(panels.has("panel1"), "Should include panel1")
	assert_true(panels.has("panel2"), "Should include panel2")
	assert_true(panels.has("panel3"), "Should include panel3")


func test_register_panel_replaces_existing_registration() -> void:
	# Arrange
	var panel1: CanvasLayer = CanvasLayer.new()
	var panel2: CanvasLayer = CanvasLayer.new()
	add_child_autofree(panel1)
	add_child_autofree(panel2)
	
	manager.register_panel("test", panel1)
	
	# Act
	manager.register_panel("test", panel2)
	
	# Assert
	assert_eq(manager.get_panel("test"), panel2, "Should return new panel reference")
	var panels: Array = manager.get_registered_panels()
	assert_eq(panels.size(), 1, "Should only have one panel registered")
