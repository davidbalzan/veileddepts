class_name SeabedDepthHUD extends CanvasLayer
## Simple HUD showing seabed depth below submarine
##
## Displays the distance from submarine to the seafloor below.
## Requires terrain_renderer and submarine references to be set.

var _depth_label: Label
var _terrain_renderer: Node = null
var _submarine: Node3D = null

func _ready() -> void:
	layer = 100  # Ensure HUD is on top

	# Create depth label
	_depth_label = Label.new()
	_depth_label.name = "SeabedDepthLabel"
	_depth_label.text = "Seabed: ---m"

	# Position at bottom center of screen
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_depth_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_depth_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_depth_label.position = Vector2(-100, -60)
	_depth_label.size = Vector2(200, 50)

	# Style the label
	_depth_label.add_theme_font_size_override("font_size", 18)
	_depth_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_depth_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_depth_label.add_theme_constant_override("shadow_offset_x", 2)
	_depth_label.add_theme_constant_override("shadow_offset_y", 2)

	add_child(_depth_label)

	# Find terrain renderer and submarine from Main
	call_deferred("_find_references")


func _find_references() -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		_terrain_renderer = main.get_node_or_null("TerrainRenderer")
		_submarine = main.get_node_or_null("SubmarineModel")

	if not _terrain_renderer:
		push_warning("SeabedDepthHUD: TerrainRenderer not found")
	if not _submarine:
		push_warning("SeabedDepthHUD: Submarine not found")


func _process(_delta: float) -> void:
	if not visible:
		return

	_update_depth_display()


func _update_depth_display() -> void:
	if not _terrain_renderer or not _submarine:
		_depth_label.text = "Seabed: ---m"
		return

	if not _terrain_renderer.has_method("get_height_at"):
		_depth_label.text = "Seabed: N/A"
		return

	var sub_pos = _submarine.global_position
	var seabed_height = _terrain_renderer.get_height_at(Vector2(sub_pos.x, sub_pos.z))

	# Debug: Print values to understand what's happening
	if Engine.get_frames_drawn() % 60 == 0:  # Print once per second
		print("SeabedDepthHUD: Sub Y=%.1f, Seabed=%.1f" % [sub_pos.y, seabed_height])

	# Calculate distance from submarine to seabed
	var depth_to_seabed = sub_pos.y - seabed_height

	# Format display
	if depth_to_seabed > 0:
		_depth_label.text = "Seabed: %.0fm below" % depth_to_seabed
		# Color based on proximity
		if depth_to_seabed < 20:
			_depth_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red - danger
		elif depth_to_seabed < 50:
			_depth_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))  # Yellow - caution
		else:
			_depth_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))  # Blue - safe
	else:
		_depth_label.text = "COLLISION!"
		_depth_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
