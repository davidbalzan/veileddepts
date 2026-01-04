extends TacticalMapView
class_name WholeMapView

## WholeMapView displays the entire World Elevation Map and allows for global teleportation.
## Uses tile-based loading to handle the massive 21600x10800 image.

var global_map_image: Image = null
var tile_cache: Dictionary = {}  # Vector2i -> ImageTexture
var tile_size: int = 2048  # Size of each tile
var max_cached_tiles: int = 16  # Maximum number of tiles to keep in memory
var _scaled_map_texture: ImageTexture = null  # Downscaled version for display
var icon_overlay: Control = null
var map_background: TextureRect = null

# Sea level control (removed local sea_level_threshold, now using SeaLevelManager)
var _sea_level_slider: HSlider = null
var _debug_panel: PanelContainer = null
var _debug_visible: bool = false
var _progress_bar: ProgressBar = null
var _progress_label: Label = null

# State for "resample on zoom" detail texture
var _detail_texture: ImageTexture = null
var _detail_uv_rect: Rect2 = Rect2()
var _last_resample_zoom: float = 1.0
var _last_resample_pan: Vector2 = Vector2.ZERO
var _resample_settle_timer: float = 0.0




func _ready() -> void:
	# Call parent _ready but we'll override some parameters
	super._ready()

	# WholeMapView doesn't need Camera2D, remove any inherited one
	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.queue_free()

	# Ensure map_canvas fills the entire viewport
	if map_canvas:
		map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		map_canvas.position = Vector2.ZERO
		map_canvas.size = get_viewport().get_visible_rect().size

	# Load the full world map as an Image (not a texture yet)
	var image_path = "res://src_assets/World_elevation_map.png"

	if ResourceLoader.exists(image_path):
		global_map_image = Image.load_from_file(image_path)
		if global_map_image:
			var size = Vector2i(global_map_image.get_width(), global_map_image.get_height())
			print("WholeMapView: Loaded world map image (%dx%d)" % [size.x, size.y])
			print(
				"WholeMapView: Using tile-based rendering with %dx%d tiles" % [tile_size, tile_size]
			)
		else:
			push_error("WholeMapView: Failed to load image from %s" % image_path)
	else:
		push_error("WholeMapView: World map file not found at %s" % image_path)

	# Whole map defaults
	map_zoom = 1.0
	map_pan_offset = Vector2.ZERO

	_create_background_node()
	_create_overlay_node()
	_create_debug_panel()
	
	# Connect to SeaLevelManager progress signal
	if SeaLevelManager:
		SeaLevelManager.update_progress.connect(_on_sea_level_update_progress)
	
	if global_map_image:
		_create_optimized_map()
		print("WholeMapView: Initialized with Global Map (CPU-Colorized)")
	else:
		print("WholeMapView: Initialized but Global Map image is NULL!")


func _create_optimized_map() -> void:
	if not global_map_image: return
	
	print("WholeMapView: Creating colorized overview map (Optimized Sampling)...")
	var target_width = 1024
	var source_w = global_map_image.get_width()
	var source_h = global_map_image.get_height()
	var scale_w = float(source_w) / target_width
	var target_height = int(source_h / scale_w)
	
	var color_image = Image.create(target_width, target_height, false, Image.FORMAT_RGBA8)
	
	# Get current sea level from manager
	var sea_level_threshold = SeaLevelManager.get_sea_level_normalized()
	
	# Sample directly from large image to avoid huge duplicates
	for y in range(target_height):
		var source_y = clampi(int(y * scale_w), 0, source_h - 1)
		for x in range(target_width):
			var source_x = clampi(int(x * scale_w), 0, source_w - 1)
			var val = global_map_image.get_pixel(source_x, source_y).r
			
			var color: Color
			if val <= sea_level_threshold:
				var norm = val / sea_level_threshold
				color = Color(0.0, 0.1 * norm, 0.2 + 0.3 * norm)
			else:
				var norm = (val - sea_level_threshold) / (1.0 - sea_level_threshold)
				color = Color(0.1 + 0.3 * norm, 0.4 - 0.1 * norm, 0.1)
				
			color_image.set_pixel(x, y, color)
	
	_scaled_map_texture = ImageTexture.create_from_image(color_image)
	print("WholeMapView: Colorized overview map created successfully (%dx%d)" % [target_width, target_height])


## Override waypoint placement to implement global teleportation
func _handle_waypoint_placement(_screen_pos: Vector2) -> void:
	if not simulation_state or not map_canvas:
		return

	# Use local mouse position for accurate UV calculation
	var local_pos = map_canvas.get_local_mouse_position()
	var click_uv = _screen_to_uv(local_pos)

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
	title_inner.add_theme_font_size_override("font_size", 28)
	title_inner.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	title_inner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_inner.position.y = 20
	add_child(title_inner)

	# Hide standard tactical UI
	for child in get_children():
		if child.name in ["ControlPanel", "SubmarineInfo", "RecenterButton", "TerrainToggle"]:
			child.visible = false
		if child is Label and child.name == "Instructions":
			child.text = "F2: Close | F3: Debug Panel | F4: All Debug | Left Click: Teleport | Right Click/Middle: Pan | Wheel: Zoom"

	# Add elevation info label
	var elev_label = Label.new()
	elev_label.name = "ElevationInfo"
	elev_label.position = Vector2(20, 120)
	elev_label.add_theme_font_size_override("font_size", 20)
	elev_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(elev_label)


func _create_background_node() -> void:
	# No longer using a separate node, we'll draw directly on canvas in _on_map_canvas_draw
	pass


func _create_overlay_node() -> void:
	if not map_canvas: return
	
	icon_overlay = Control.new()
	icon_overlay.name = "IconOverlay"
	icon_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(icon_overlay)
	icon_overlay.draw.connect(_on_icon_overlay_draw)


func _create_debug_panel() -> void:
	"""Create debug panel with sea level slider and debug info"""
	_debug_panel = PanelContainer.new()
	_debug_panel.name = "DebugPanel"
	
	# Position in top-right corner
	_debug_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug_panel.position = Vector2(-320, 60)
	_debug_panel.custom_minimum_size = Vector2(300, 0)
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_box.border_color = Color(0, 1, 1, 1)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(5)
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 10
	style_box.content_margin_bottom = 10
	_debug_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_debug_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "DEBUG CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	vbox.add_child(title)
	
	# Separator
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# Sea Level Control Section
	var sea_level_label = Label.new()
	sea_level_label.text = "Sea Level Threshold (Visualization Only)"
	sea_level_label.add_theme_font_size_override("font_size", 16)
	sea_level_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(sea_level_label)
	
	# Sea level value display
	var sea_level_value = Label.new()
	sea_level_value.name = "SeaLevelValue"
	var current_normalized = SeaLevelManager.get_sea_level_normalized()
	var current_meters = SeaLevelManager.get_sea_level_meters()
	sea_level_value.text = "%.3f (%.0fm elevation, Default: 0.561)" % [current_normalized, current_meters]
	sea_level_value.add_theme_font_size_override("font_size", 14)
	sea_level_value.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(sea_level_value)
	
	# Sea level slider - focused range around 0.561 default
	_sea_level_slider = HSlider.new()
	_sea_level_slider.name = "SeaLevelSlider"
	_sea_level_slider.min_value = 0.50
	_sea_level_slider.max_value = 0.60
	_sea_level_slider.step = 0.0001  # Fine control for coastline calibration
	_sea_level_slider.value = current_normalized
	_sea_level_slider.custom_minimum_size = Vector2(280, 20)
	_sea_level_slider.value_changed.connect(_on_sea_level_changed)
	vbox.add_child(_sea_level_slider)
	
	# Reset to Default button
	var reset_button = Button.new()
	reset_button.name = "ResetSeaLevelButton"
	reset_button.text = "Reset to Default (0m)"
	reset_button.custom_minimum_size = Vector2(280, 30)
	reset_button.pressed.connect(_on_reset_sea_level)
	vbox.add_child(reset_button)
	
	# Progress indicator (initially hidden)
	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.text = ""
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	_progress_label.visible = false
	vbox.add_child(_progress_label)
	
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.custom_minimum_size = Vector2(280, 20)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.visible = false
	vbox.add_child(_progress_bar)
	
	# Separator
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Debug Info Section
	var debug_info_label = Label.new()
	debug_info_label.text = "Map Information"
	debug_info_label.add_theme_font_size_override("font_size", 16)
	debug_info_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(debug_info_label)
	
	# Map size info
	var map_info = Label.new()
	map_info.name = "MapInfo"
	if global_map_image:
		map_info.text = "Size: %dx%d pixels\nZoom: %.2fx\nTiles Cached: 0/%d" % [
			global_map_image.get_width(),
			global_map_image.get_height(),
			map_zoom,
			max_cached_tiles
		]
	else:
		map_info.text = "Map: Not Loaded"
	map_info.add_theme_font_size_override("font_size", 13)
	map_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(map_info)
	
	# Separator
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Debug Panel Toggle Buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 5)
	vbox.add_child(button_container)
	
	# Toggle Performance Panel
	var perf_button = Button.new()
	perf_button.text = "Performance"
	perf_button.custom_minimum_size = Vector2(135, 30)
	perf_button.pressed.connect(_on_toggle_performance_panel)
	button_container.add_child(perf_button)
	
	# Toggle Terrain Debug
	var terrain_button = Button.new()
	terrain_button.text = "Terrain"
	terrain_button.custom_minimum_size = Vector2(135, 30)
	terrain_button.pressed.connect(_on_toggle_terrain_panel)
	button_container.add_child(terrain_button)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "F3: Toggle This Panel\nF4: Toggle All Debug"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(instructions)
	
	# Add to scene
	add_child(_debug_panel)
	_debug_panel.visible = _debug_visible
	
	print("WholeMapView: Debug panel created")


## Get or create a tile texture for a specific region
func _get_tile_texture(tile_coord: Vector2i) -> ImageTexture:
	# Check cache first
	if tile_cache.has(tile_coord):
		return tile_cache[tile_coord]

	# Enforce cache limit
	if tile_cache.size() >= max_cached_tiles:
		# Remove oldest tile (first key)
		var first_key = tile_cache.keys()[0]
		tile_cache.erase(first_key)

	# Extract tile from source image
	if not global_map_image:
		return null

	var img_size = Vector2i(global_map_image.get_width(), global_map_image.get_height())
	var tile_x = tile_coord.x * tile_size
	var tile_y = tile_coord.y * tile_size

	# Clamp to image bounds
	var actual_width = min(tile_size, img_size.x - tile_x)
	var actual_height = min(tile_size, img_size.y - tile_y)

	if actual_width <= 0 or actual_height <= 0:
		return null

	# Create a new image for this tile
	var tile_image = Image.create(actual_width, actual_height, false, global_map_image.get_format())

	# Copy pixels from source image
	tile_image.blit_rect(
		global_map_image, Rect2i(tile_x, tile_y, actual_width, actual_height), Vector2i.ZERO
	)

	# Create texture from tile
	var texture = ImageTexture.create_from_image(tile_image)

	# Cache it
	tile_cache[tile_coord] = texture

	return texture


func _on_map_canvas_draw() -> void:
	if not visible or not map_canvas:
		return

	# Draw base background texture
	if _scaled_map_texture:
		var canvas_size = map_canvas.size
		var img_aspect = float(global_map_image.get_width()) / global_map_image.get_height()
		var canvas_aspect = canvas_size.x / canvas_size.y

		var draw_rect: Rect2
		if img_aspect > canvas_aspect:
			var draw_width = canvas_size.x
			var draw_height = draw_width / img_aspect
			draw_rect = Rect2(0, (canvas_size.y - draw_height) / 2.0, draw_width, draw_height)
		else:
			var draw_height = canvas_size.y
			var draw_width = draw_height * img_aspect
			draw_rect = Rect2((canvas_size.x - draw_width) / 2.0, 0, draw_width, draw_height)

		# Apply zoom and pan
		var zoomed_rect = Rect2(
			(draw_rect.position + map_pan_offset) * map_zoom - (canvas_size * (map_zoom - 1.0) / 2.0),
			draw_rect.size * map_zoom
		)

		map_canvas.draw_texture_rect(_scaled_map_texture, zoomed_rect, false)
		
		# Draw detail texture overlay if available
		if _detail_texture:
			# Calculate screen rect for the detail texture relative to its stored UV rect
			var detail_top_left = _uv_to_screen(_detail_uv_rect.position)
			var detail_bottom_right = _uv_to_screen(_detail_uv_rect.position + _detail_uv_rect.size)
			var detail_screen_rect = Rect2(detail_top_left, detail_bottom_right - detail_top_left)
			
			map_canvas.draw_texture_rect(_detail_texture, detail_screen_rect, false)

	# Redraw overlay
	if icon_overlay:
		icon_overlay.queue_redraw()


func _on_icon_overlay_draw() -> void:
	# Draw mission area indicator (the 2km region)
	_draw_mission_area_indicator()

	# Draw submarine icon in global space
	_draw_submarine_icon_global()


func _draw_missing_image_warning(canvas_rect: Rect2) -> void:
	var font_size = 32
	var msg = "MISSING GLOBAL MAP IMAGE\n(Check res://src_assets/World_elevation_map.png)"
	map_canvas.draw_string(
		ThemeDB.fallback_font,
		canvas_rect.get_center(),
		msg,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		font_size,
		Color.RED
	)


func _generate_detail_texture() -> void:
	if not global_map_image or not visible:
		return
	
	print("WholeMapView: Generating detail texture for current view...")
	
	# Determine current visible UV rect
	var canvas_size = map_canvas.size
	var uv_top_left = _screen_to_uv(Vector2.ZERO)
	var uv_bottom_right = _screen_to_uv(canvas_size)
	
	# Add a margin (approx 40%) to allow for panning without immediate blanking
	var margin = (uv_bottom_right - uv_top_left) * 0.4
	uv_top_left -= margin
	uv_bottom_right += margin
	
	# Clamp to valid UV range
	uv_top_left.x = clamp(uv_top_left.x, 0.0, 1.0)
	uv_top_left.y = clamp(uv_top_left.y, 0.0, 1.0)
	uv_bottom_right.x = clamp(uv_bottom_right.x, 0.0, 1.0)
	uv_bottom_right.y = clamp(uv_bottom_right.y, 0.0, 1.0)
	
	var uv_rect = Rect2(uv_top_left, uv_bottom_right - uv_top_left)
	if uv_rect.size.x <= 0 or uv_rect.size.y <= 0:
		return
		
	_detail_uv_rect = uv_rect
	
	# Extraction resolution (higher than base, but manageable)
	var resolution = 512
	var source_w = global_map_image.get_width()
	var source_h = global_map_image.get_height()
	
	var detail_image = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	
	# Get current sea level from manager
	var sea_level_threshold = SeaLevelManager.get_sea_level_normalized()
	
	# Extract and colorize
	for y in range(resolution):
		var uv_y = uv_rect.position.y + (float(y) / (resolution - 1)) * uv_rect.size.y
		var source_y = clampi(int(uv_y * (source_h - 1)), 0, source_h - 1)
		
		for x in range(resolution):
			var uv_x = uv_rect.position.x + (float(x) / (resolution - 1)) * uv_rect.size.x
			var source_x = clampi(int(uv_x * (source_w - 1)), 0, source_w - 1)
			
			var val = global_map_image.get_pixel(source_x, source_y).r
			var color: Color
			if val <= sea_level_threshold:
				var norm = val / sea_level_threshold
				color = Color(0.0, 0.1 * norm, 0.2 + 0.3 * norm)
			else:
				var norm = (val - sea_level_threshold) / (1.0 - sea_level_threshold)
				color = Color(0.1 + 0.3 * norm, 0.4 - 0.1 * norm, 0.1)
				
			detail_image.set_pixel(x, y, color)
			
	_detail_texture = ImageTexture.create_from_image(detail_image)
	_last_resample_zoom = map_zoom
	_last_resample_pan = map_pan_offset
	
	print("WholeMapView: Detail texture generated for UV rect %s" % uv_rect)




## Convert screen position to global map UV
func _screen_to_uv(screen_pos: Vector2) -> Vector2:
	if not global_map_image: return Vector2.ZERO
	
	var canvas_size = map_canvas.size
	var img_aspect = float(global_map_image.get_width()) / global_map_image.get_height()
	var canvas_aspect = canvas_size.x / canvas_size.y
	
	var draw_rect: Rect2
	if img_aspect > canvas_aspect:
		var draw_width = canvas_size.x
		var draw_height = draw_width / img_aspect
		draw_rect = Rect2(0, (canvas_size.y - draw_height) / 2.0, draw_width, draw_height)
	else:
		var draw_height = canvas_size.y
		var draw_width = draw_height * img_aspect
		draw_rect = Rect2((canvas_size.x - draw_width) / 2.0, 0, draw_width, draw_height)
		
	# Revert zoom and pan
	var relative_pos = (screen_pos + (canvas_size * (map_zoom - 1.0) / 2.0)) / map_zoom - map_pan_offset - draw_rect.position
	
	return Vector2(
		clamp(relative_pos.x / draw_rect.size.x, 0.0, 1.0),
		clamp(relative_pos.y / draw_rect.size.y, 0.0, 1.0)
	)


func _draw_mission_area_indicator() -> void:
	if not terrain_renderer or not global_map_image:
		return

	# Calculate the draw rect (same logic as _draw_tiled_map)
	var canvas_size = map_canvas.size
	var img_aspect = float(global_map_image.get_width()) / global_map_image.get_height()
	var canvas_aspect = canvas_size.x / canvas_size.y

	var draw_rect: Rect2
	if img_aspect > canvas_aspect:
		var draw_width = canvas_size.x
		var draw_height = draw_width / img_aspect
		var y_offset = (canvas_size.y - draw_height) / 2.0
		draw_rect = Rect2(0, y_offset, draw_width, draw_height)
	else:
		var draw_height = canvas_size.y
		var draw_width = draw_height * img_aspect
		var x_offset = (canvas_size.x - draw_width) / 2.0
		draw_rect = Rect2(x_offset, 0, draw_width, draw_height)

	var region = terrain_renderer.heightmap_region

	# Convert region boundaries to screen space
	var top_left = _uv_to_screen(region.position)
	var bottom_right = _uv_to_screen(region.position + region.size)
	
	var indicator_rect = Rect2(top_left, bottom_right - top_left)

	icon_overlay.draw_rect(indicator_rect, Color(0, 1, 1, 0.5), false, 2.0)
	icon_overlay.draw_string(
		ThemeDB.fallback_font,
		indicator_rect.position + Vector2(5, -5),
		"MISSION AREA",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color.CYAN
	)


func _draw_submarine_icon_global() -> void:
	if not terrain_renderer or not simulation_state:
		return

	var region = terrain_renderer.heightmap_region
	var sub_pos = simulation_state.submarine_position

	# Map sub position (-1024..1024) to UV offset within region
	# terrain_size is 2048
	var sub_uv_offset = Vector2(sub_pos.x / 2048.0, sub_pos.z / 2048.0)

	var sub_global_uv = region.get_center() + sub_uv_offset
	var screen_pos = _uv_to_screen(sub_global_uv)

	# Draw circle for sub on icon_overlay
	icon_overlay.draw_circle(screen_pos, 5.0, Color.GREEN)
	icon_overlay.draw_arc(screen_pos, 8.0, 0, TAU, 16, Color.GREEN, 1.0)


# Ensure map updates regularly when visible (to show moving sub or updated mission area)
func _process(_delta: float) -> void:
	if visible and map_canvas:
		# Ensure canvas fills viewport (handle window resize)
		var viewport_size = get_viewport().get_visible_rect().size
		if viewport_size.x > 0 and viewport_size.y > 0:
			if map_canvas.size != viewport_size or map_canvas.position != Vector2.ZERO:
				print("WholeMapView: Resizing canvas to ", viewport_size)
				map_canvas.size = viewport_size
				map_canvas.position = Vector2.ZERO
				map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# Update elevation info
		_update_elevation_info()
		
		# Update debug panel info
		_update_debug_panel_info()
		
		# Better resampling logic for World Map Detail
		var zoom_changed = abs(map_zoom - _last_resample_zoom) / _last_resample_zoom > 0.1
		var pan_changed = map_pan_offset.distance_to(_last_resample_pan) > (100.0 / map_zoom)
		
		if zoom_changed or pan_changed:
			_resample_settle_timer = 0.4 # Default settle time
			_last_resample_zoom = map_zoom # Update immediately to stop further increments
			_last_resample_pan = map_pan_offset
		
		if _resample_settle_timer > 0:
			_resample_settle_timer -= _delta
			if _resample_settle_timer <= 0:
				_generate_detail_texture()

		map_canvas.queue_redraw()


func _update_elevation_info() -> void:
	var label = get_node_or_null("ElevationInfo")
	if not label or not global_map_image: return
	
	var mouse_pos = map_canvas.get_local_mouse_position()
	var uv = _screen_to_uv(mouse_pos)
	
	var px = int(uv.x * (global_map_image.get_width() - 1))
	var py = int(uv.y * (global_map_image.get_height() - 1))
	
	var val = global_map_image.get_pixel(px, py).r
	
	# Match Simulation Scaling
	var MARIANA = -10994.0
	var EVEREST = 8849.0
	var elevation = lerp(MARIANA, EVEREST, val)
	
	label.text = "Elevation: %.1f m" % elevation
	if elevation > 0:
		label.add_theme_color_override("font_color", Color.GREEN)
	else:
		label.add_theme_color_override("font_color", Color.CYAN)


func _update_debug_panel_info() -> void:
	"""Update debug panel information"""
	if not _debug_panel or not _debug_visible:
		return
	
	var map_info = _debug_panel.find_child("MapInfo", true, false)
	if map_info and global_map_image:
		var perf_stats = ""
		
		# Get performance stats from SeaLevelManager
		if SeaLevelManager:
			var stats = SeaLevelManager.get_performance_stats()
			perf_stats = "\nMemory: %.1fMB (Peak: %.1fMB)" % [
				stats.current_memory_mb,
				stats.peak_memory_mb
			]
			if stats.update_in_progress:
				perf_stats += "\nUpdate: IN PROGRESS"
			elif stats.last_update_duration_ms > 0:
				perf_stats += "\nLast Update: %.1fms" % stats.last_update_duration_ms
		
		map_info.text = "Size: %dx%d pixels\nZoom: %.2fx\nTiles Cached: %d/%d%s" % [
			global_map_image.get_width(),
			global_map_image.get_height(),
			map_zoom,
			tile_cache.size(),
			max_cached_tiles,
			perf_stats
		]


func _uv_to_screen(uv: Vector2) -> Vector2:
	if not global_map_image: return Vector2.ZERO
	
	var canvas_size = map_canvas.size
	var img_aspect = float(global_map_image.get_width()) / global_map_image.get_height()
	var canvas_aspect = canvas_size.x / canvas_size.y
	
	var draw_rect: Rect2
	if img_aspect > canvas_aspect:
		var draw_width = canvas_size.x
		var draw_height = draw_width / img_aspect
		draw_rect = Rect2(0, (canvas_size.y - draw_height) / 2.0, draw_width, draw_height)
	else:
		var draw_height = canvas_size.y
		var draw_width = draw_height * img_aspect
		draw_rect = Rect2((canvas_size.x - draw_width) / 2.0, 0, draw_width, draw_height)
		
	var local_pos = uv * draw_rect.size + draw_rect.position
	return (local_pos + map_pan_offset) * map_zoom - (canvas_size * (map_zoom - 1.0) / 2.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# F3 to toggle debug panel
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F3:
				_toggle_debug_panel()
				return
			elif key_event.keycode == KEY_F4:
				_toggle_all_debug_panels()
				return

	# Simple mouse click for teleportation
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		
		# Left click for teleport
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_waypoint_placement(mouse_event.position)
			
		# Right/Middle click for pan
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT or mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				is_panning = true
				last_mouse_position = mouse_event.position
			else:
				is_panning = false
				
		# Mouse wheel for zoom
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_handle_zoom(1.2, mouse_event.position)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_handle_zoom(0.8, mouse_event.position)

	# Keyboard shortcuts
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			# Zoom in with + or =
			if key_event.keycode == KEY_PLUS or key_event.keycode == KEY_EQUAL:
				_handle_zoom(1.2)
			# Zoom out with -
			elif key_event.keycode == KEY_MINUS:
				_handle_zoom(0.8)
			# Recenter with C
			elif key_event.keycode == KEY_C:
				map_pan_offset = Vector2.ZERO
				map_zoom = 1.0
				print("WholeMapView: Recentered")
	
	# Handle panning movement
	elif event is InputEventMouseMotion and is_panning:
		var mouse_motion = event as InputEventMouseMotion
		var delta = mouse_motion.position - last_mouse_position
		map_pan_offset += delta / map_zoom  # Adjust for zoom level
		last_mouse_position = mouse_motion.position


func _handle_zoom(zoom_factor: float, _mouse_pos: Vector2 = Vector2.ZERO) -> void:
	map_zoom *= zoom_factor
	map_zoom = clamp(map_zoom, 1.0, 100.0)


## Debug panel callbacks

func _toggle_debug_panel() -> void:
	"""Toggle the debug panel visibility"""
	_debug_visible = not _debug_visible
	if _debug_panel:
		_debug_panel.visible = _debug_visible
	print("WholeMapView: Debug panel toggled: ", _debug_visible)


func _toggle_all_debug_panels() -> void:
	"""Toggle all debug panels via DebugPanelManager"""
	if DebugPanelManager:
		if DebugPanelManager.is_debug_enabled():
			DebugPanelManager.disable_all()
		else:
			DebugPanelManager.enable_all()


func _on_toggle_performance_panel() -> void:
	"""Toggle the performance debug panel"""
	if DebugPanelManager:
		DebugPanelManager.toggle_panel("performance")


func _on_toggle_terrain_panel() -> void:
	"""Toggle the terrain debug panel"""
	if DebugPanelManager:
		DebugPanelManager.toggle_panel("terrain")


## Override parent to match signature but handle slider input
## This is called both from:
## 1. The UI slider (1 param) - we update SeaLevelManager
## 2. SeaLevelManager signal (2 params) - we regenerate the map
func _on_sea_level_changed(normalized: float, meters: float = NAN) -> void:
	# If meters is NAN, this came from the slider, so update the manager
	if is_nan(meters):
		SeaLevelManager.set_sea_level(normalized)
		# The manager will emit its signal, which will call this method again with both params
		return
	
	# If we get here, this came from SeaLevelManager's signal
	# Update UI display to show both normalized and metric values
	if _debug_panel:
		var value_label = _debug_panel.find_child("SeaLevelValue", true, false)
		if value_label:
			value_label.text = "%.3f (%.0fm elevation, Default: 0.561)" % [normalized, meters]
	
	# Regenerate the map with new sea level
	if global_map_image:
		_create_optimized_map()
		
		# Update the map_background texture if it exists
		if map_background:
			map_background.texture = _scaled_map_texture
		
		# Force redraw
		if map_canvas:
			map_canvas.queue_redraw()
		
		# Regenerate detail texture if zoomed in
		if map_zoom > 1.5:
			_generate_detail_texture()
	
	print("WholeMapView: Sea level threshold changed to %.3f (%.0fm elevation)" % [normalized, meters])


func _on_reset_sea_level() -> void:
	"""Called when Reset to Default button is pressed"""
	SeaLevelManager.reset_to_default()
	
	# Update slider to match
	if _sea_level_slider:
		_sea_level_slider.value = SeaLevelManager.get_sea_level_normalized()
	
	# Update UI display
	var elevation_meters = SeaLevelManager.get_sea_level_meters()
	if _debug_panel:
		var value_label = _debug_panel.find_child("SeaLevelValue", true, false)
		if value_label:
			value_label.text = "%.3f (%.0fm elevation, Default: 0.561)" % [SeaLevelManager.get_sea_level_normalized(), elevation_meters]
	
	# Regenerate the map with default sea level
	if global_map_image:
		_create_optimized_map()
		
		# Update the map_background texture if it exists
		if map_background:
			map_background.texture = _scaled_map_texture
		
		# Force redraw
		if map_canvas:
			map_canvas.queue_redraw()
		
		# Regenerate detail texture if zoomed in
		if map_zoom > 1.5:
			_generate_detail_texture()
	
	print("WholeMapView: Sea level reset to default (0.561 / 0m elevation)")


## Handle progress updates from SeaLevelManager
func _on_sea_level_update_progress(progress: float, operation: String) -> void:
	"""Update progress indicator during sea level changes"""
	if not _progress_bar or not _progress_label:
		return
	
	# Show progress indicator when update starts
	if progress <= 0.0:
		_progress_bar.visible = true
		_progress_label.visible = true
	
	# Update progress
	_progress_bar.value = progress
	_progress_label.text = operation
	
	# Hide progress indicator when complete
	if progress >= 1.0:
		# Keep visible for a moment to show completion
		await get_tree().create_timer(0.5).timeout
		if _progress_bar and _progress_label:
			_progress_bar.visible = false
			_progress_label.visible = false
