extends TacticalMapView
class_name WholeMapView

## WholeMapView displays the entire World Elevation Map and allows for global teleportation.
## Triggered with F2.

var global_map_texture: Texture2D

func _ready() -> void:
	# Call parent _ready but we'll override some parameters
	super._ready()
	
	# Load the full world map
	global_map_texture = load("res://src_assets/World_elevation_map.png")
	if global_map_texture:
		print("WholeMapView: Loaded global map texture (%dx%d)" % [global_map_texture.get_width(), global_map_texture.get_height()])
	
	# Whole map defaults
	map_zoom = 1.0 # Use 1.0 zoom to see the full world map
	map_pan_offset = Vector2.ZERO
	
	print("WholeMapView: Initialized with Global Map")

## Override waypoint placement to implement global teleportation
func _handle_waypoint_placement(_screen_pos: Vector2) -> void:
	if not simulation_state or not map_canvas:
		return
	
	# Use local mouse position for accurate UV calculation
	var local_pos = map_canvas.get_local_mouse_position()
	var canvas_size = map_canvas.size
	
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		print("WholeMapView: Canvas size is invalid, skipping teleport")
		return
		
	var click_uv = Vector2(
		clamp(local_pos.x / canvas_size.x, 0.0, 1.0),
		clamp(local_pos.y / canvas_size.y, 0.0, 1.0)
	)
	
	print("WholeMapView: Global teleport requested to UV=%s (local_pos=%s)" % [click_uv, local_pos])
	
	# Call main system to teleport and shift mission area
	var main_node = get_parent()
	if main_node and main_node.has_method("teleport_and_shift"):
		main_node.teleport_and_shift(click_uv)
	else:
		push_error("WholeMapView: teleport_and_shift method not found on parent!")


## Simplified UI for whole map
func _create_ui_elements() -> void:
	super._create_ui_elements()
	
	# Add a "WORLD MAP" title
	var title_inner = Label.new()
	title_inner.name = "WorldMapTitle"
	title_inner.text = "WORLD MAP - CLICK TO SHIFT MISSION AREA AND TELEPORT"
	title_inner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_inner.add_theme_font_size_override("font_size", 24)
	title_inner.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	title_inner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_inner.position.y = 20
	add_child(title_inner)
	
	# Hide standard tactical UI
	for child in get_children():
		if child.name in ["ControlPanel", "SubmarineInfo", "RecenterButton", "TerrainToggle"]:
			child.visible = false
		if child is Label and child.name == "Instructions":
			child.text = "F2: Close | Left Click: Teleport to UV | Zoom/Pan disabled on World Map"

## Override rendering to show global map
func _on_map_canvas_draw() -> void:
	if not visible:
		return
	
	if not map_canvas:
		push_error("WholeMapView: map_canvas is null!")
		return
	
	var canvas_size = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		# Canvas not sized yet, try to force a size
		canvas_size = get_viewport().get_visible_rect().size
		if canvas_size.x <= 0 or canvas_size.y <= 0:
			push_warning("WholeMapView: Canvas size is zero, skipping draw")
			return
	
	var canvas_rect = Rect2(Vector2.ZERO, canvas_size)
	
	# Draw background ocean (dark blue)
	map_canvas.draw_rect(canvas_rect, Color(0.02, 0.05, 0.1, 1.0))
	
	# Draw the global map texture to fill the canvas
	if global_map_texture:
		map_canvas.draw_texture_rect(global_map_texture, canvas_rect, false, Color(1, 1, 1, 0.8))
	else:
		# Fallback if texture missing
		var font_size = 32
		var msg = "MISSING GLOBAL MAP TEXTURE\n(Check res://src_assets/World_elevation_map.png)"
		map_canvas.draw_string(ThemeDB.fallback_font, canvas_rect.get_center(), msg, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.RED)
	
	# Draw mission area indicator (the 2km region)
	_draw_mission_area_indicator()
	
	# Draw submarine icon in global space
	_draw_submarine_icon_global()

func _draw_mission_area_indicator() -> void:
	if not terrain_renderer:
		return
		
	# Get the UV region currently loaded
	var region = terrain_renderer.heightmap_region
	var canvas_size = map_canvas.size
	
	var indicator_rect = Rect2(
		region.position.x * canvas_size.x,
		region.position.y * canvas_size.y,
		region.size.x * canvas_size.x,
		region.size.y * canvas_size.y
	)
	
	map_canvas.draw_rect(indicator_rect, Color(0, 1, 1, 0.5), false, 2.0)
	map_canvas.draw_string(ThemeDB.fallback_font, indicator_rect.position + Vector2(5, -5), "MISSION AREA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CYAN)

func _draw_submarine_icon_global() -> void:
	if not terrain_renderer or not simulation_state:
		return
		
	var region = terrain_renderer.heightmap_region
	var sub_pos = simulation_state.submarine_position
	
	# Map sub position (-1024..1024) to UV offset within region
	# terrain_size is 2048
	var sub_uv_offset = Vector2(
		(sub_pos.x / 2048.0),
		(sub_pos.z / 2048.0)
	)
	
	var sub_global_uv = region.get_center() + sub_uv_offset
	var canvas_size = map_canvas.size
	var screen_pos = Vector2(
		sub_global_uv.x * canvas_size.x,
		sub_global_uv.y * canvas_size.y
	)
	
	# Draw circle for sub
	map_canvas.draw_circle(screen_pos, 5.0, Color.GREEN)
	map_canvas.draw_arc(screen_pos, 8.0, 0, TAU, 16, Color.GREEN, 1.0)

# Ensure map updates regularly when visible (to show moving sub or updated mission area)
func _process(_delta: float) -> void:
	if visible and map_canvas:
		map_canvas.queue_redraw()

# Handle visibility changes to ensure proper redraw
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible and map_canvas:
			# Force immediate redraw when becoming visible
			await get_tree().process_frame
			map_canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	# Simple mouse click for teleportation
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_waypoint_placement(mouse_event.position)
