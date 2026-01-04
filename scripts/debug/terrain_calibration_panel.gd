class_name TerrainCalibrationPanel extends CanvasLayer
## Debug UI panel for terrain height calibration
##
## Provides visual controls for:
## - Sea level offset adjustment (-50m to +50m)
## - Save/Load calibration
## - Display current calibration status
##
## Press F3 to toggle visibility (managed by DebugPanelManager)
##
## Requirements: 4.1

const CALIBRATION_FILE_PATH = "user://terrain_calibration.cfg"

var panel: PanelContainer
var visible_state: bool = false

# UI elements
var sea_level_slider: HSlider
var sea_level_value_label: Label
var calibration_status_label: Label
var save_button: Button
var load_button: Button
var reset_button: Button

# Current calibration
var current_calibration: HeightCalibration = null


func _ready() -> void:
	# Ensure this CanvasLayer is on layer 5 (below console at layer 10)
	layer = 5
	
	# Process input even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	print("TerrainCalibrationPanel: Starting setup...")
	
	# Try to load existing calibration
	_load_calibration()
	
	# Create UI
	_create_ui()
	
	# Register with DebugPanelManager
	DebugPanelManager.register_panel("terrain_calibration", self)
	
	# Initially hidden
	panel.visible = visible_state
	
	print("TerrainCalibrationPanel: Setup complete!")


func _create_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "TerrainCalibrationPanel"
	panel.custom_minimum_size = Vector2(350, 250)
	panel.position = Vector2(340, 20)  # Position next to ocean debug panel
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Header
	var title = Label.new()
	title.text = "TERRAIN CALIBRATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Calibration status
	calibration_status_label = Label.new()
	calibration_status_label.text = "Status: Not calibrated"
	calibration_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(calibration_status_label)
	
	vbox.add_child(HSeparator.new())
	
	# Sea level offset section
	_add_section_label(vbox, "Sea Level Offset")
	
	var offset_desc = Label.new()
	offset_desc.text = "Adjust sea level for visual calibration"
	offset_desc.add_theme_font_size_override("font_size", 10)
	offset_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(offset_desc)
	
	# Get current offset
	var current_offset = 0.0
	if current_calibration:
		current_offset = current_calibration.get_sea_level_offset()
	
	# Sea level offset slider
	var slider_container = HBoxContainer.new()
	vbox.add_child(slider_container)
	
	var slider_label = Label.new()
	slider_label.text = "Offset:"
	slider_label.custom_minimum_size.x = 60
	slider_container.add_child(slider_label)
	
	sea_level_slider = HSlider.new()
	sea_level_slider.min_value = -50.0
	sea_level_slider.max_value = 50.0
	sea_level_slider.step = 0.5
	sea_level_slider.value = current_offset
	sea_level_slider.custom_minimum_size.x = 180
	sea_level_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_container.add_child(sea_level_slider)
	
	sea_level_value_label = Label.new()
	sea_level_value_label.text = "%.1fm" % current_offset
	sea_level_value_label.custom_minimum_size.x = 50
	slider_container.add_child(sea_level_value_label)
	
	sea_level_slider.value_changed.connect(_on_sea_level_offset_changed)
	
	vbox.add_child(HSeparator.new())
	
	# Buttons section
	_add_section_label(vbox, "Actions")
	
	var button_container = VBoxContainer.new()
	vbox.add_child(button_container)
	
	# Save button
	save_button = Button.new()
	save_button.text = "Save Calibration"
	save_button.pressed.connect(_on_save_pressed)
	button_container.add_child(save_button)
	
	# Load button
	load_button = Button.new()
	load_button.text = "Load Calibration"
	load_button.pressed.connect(_on_load_pressed)
	button_container.add_child(load_button)
	
	# Reset button
	reset_button = Button.new()
	reset_button.text = "Reset to Default"
	reset_button.pressed.connect(_on_reset_pressed)
	button_container.add_child(reset_button)
	
	vbox.add_child(HSeparator.new())
	
	# Info section
	var info_label = Label.new()
	info_label.text = "Adjust offset until terrain appears at correct depth relative to sea level."
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	
	# Update status display
	_update_status_display()


func _add_section_label(parent: Control, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	parent.add_child(label)


func _on_sea_level_offset_changed(value: float) -> void:
	# Update value label
	sea_level_value_label.text = "%.1fm" % value
	
	# Create or update calibration
	if not current_calibration:
		current_calibration = HeightCalibration.new()
		current_calibration.is_calibrated = true
	
	# Set the offset
	current_calibration.set_sea_level_offset(value)
	
	# Apply to SeaLevelManager
	_apply_offset_to_sea_level_manager(value)
	
	# Update status
	_update_status_display()
	
	LogRouter.log(
		"Terrain calibration: Sea level offset set to %.1fm" % value,
		LogRouter.LogLevel.INFO,
		"terrain"
	)


func _apply_offset_to_sea_level_manager(offset_meters: float) -> void:
	"""Apply the offset to SeaLevelManager by adjusting the normalized sea level"""
	if not SeaLevelManager:
		push_warning("TerrainCalibrationPanel: SeaLevelManager not available")
		return
	
	# Convert offset to normalized adjustment
	# The offset shifts the entire elevation scale, so we need to adjust
	# the sea level position accordingly
	var current_meters = SeaLevelManager.get_sea_level_meters()
	var new_meters = current_meters + offset_meters
	
	# Convert back to normalized
	var new_normalized = SeaLevelManager.meters_to_normalized(new_meters)
	
	# Apply to manager
	SeaLevelManager.set_sea_level(new_normalized, true)  # force_immediate = true


func _on_save_pressed() -> void:
	if not current_calibration:
		LogRouter.log(
			"No calibration to save",
			LogRouter.LogLevel.WARNING,
			"terrain"
		)
		return
	
	var success = current_calibration.save_to_file(CALIBRATION_FILE_PATH)
	if success:
		LogRouter.log(
			"Terrain calibration saved to %s" % CALIBRATION_FILE_PATH,
			LogRouter.LogLevel.INFO,
			"terrain"
		)
		_update_status_display()
	else:
		LogRouter.log(
			"Failed to save terrain calibration",
			LogRouter.LogLevel.ERROR,
			"terrain"
		)


func _on_load_pressed() -> void:
	_load_calibration()


func _on_reset_pressed() -> void:
	# Reset to default (no offset)
	if current_calibration:
		current_calibration.set_sea_level_offset(0.0)
	
	# Reset slider
	sea_level_slider.value = 0.0
	sea_level_value_label.text = "0.0m"
	
	# Reset SeaLevelManager
	if SeaLevelManager:
		SeaLevelManager.reset_to_default()
	
	_update_status_display()
	
	LogRouter.log(
		"Terrain calibration reset to default",
		LogRouter.LogLevel.INFO,
		"terrain"
	)


func _load_calibration() -> void:
	var loaded = HeightCalibration.load_from_file(CALIBRATION_FILE_PATH)
	
	if loaded:
		current_calibration = loaded
		
		# Update UI
		var offset = current_calibration.get_sea_level_offset()
		sea_level_slider.value = offset
		sea_level_value_label.text = "%.1fm" % offset
		
		# Apply to SeaLevelManager
		_apply_offset_to_sea_level_manager(offset)
		
		LogRouter.log(
			"Terrain calibration loaded from %s" % CALIBRATION_FILE_PATH,
			LogRouter.LogLevel.INFO,
			"terrain"
		)
	else:
		# Create default calibration
		current_calibration = HeightCalibration.new()
		current_calibration.is_calibrated = false
		
		LogRouter.log(
			"No saved calibration found, using defaults",
			LogRouter.LogLevel.INFO,
			"terrain"
		)
	
	_update_status_display()


func _update_status_display() -> void:
	if not calibration_status_label:
		return
	
	if not current_calibration or not current_calibration.is_calibrated:
		calibration_status_label.text = "Status: Not calibrated\nUse default values"
	else:
		var offset = current_calibration.get_sea_level_offset()
		calibration_status_label.text = "Status: Calibrated\nOffset: %.1fm" % offset


## Set visibility (called by DebugPanelManager)
func set_enabled(enabled: bool) -> void:
	visible_state = enabled
	if panel:
		panel.visible = enabled


## Get current visibility state
func is_enabled() -> bool:
	return visible_state


## Get current calibration
func get_calibration() -> HeightCalibration:
	return current_calibration


## Set calibration (for external use)
func set_calibration(calibration: HeightCalibration) -> void:
	current_calibration = calibration
	
	if calibration and sea_level_slider:
		var offset = calibration.get_sea_level_offset()
		sea_level_slider.value = offset
		sea_level_value_label.text = "%.1fm" % offset
		_update_status_display()
