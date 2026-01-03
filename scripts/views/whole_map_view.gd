extends TacticalMapView
class_name WholeMapView

## WholeMapView displays the entire World Elevation Map and allows for global teleportation.
## Uses tile-based loading to handle the massive 21600x10800 image.

var global_map_image: Image = null
var tile_cache: Dictionary = {}  # Vector2i -> ImageTexture
var tile_size: int = 2048  # Size of each tile
var max_cached_tiles: int = 16  # Maximum number of tiles to keep in memory
var _scaled_map_texture: ImageTexture = null  # Downscaled version for display
var _colorizer_material: ShaderMaterial = null
var icon_overlay: Control = null

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
	var sea_level_threshold = 0.554
	
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
	if map_background:
		map_background.texture = _scaled_map_texture
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
			child.text = "F2: Close | Left Click: Teleport | Right Click/Middle: Pan | Wheel: Zoom"

	# Add elevation info label
	var elev_label = Label.new()
	elev_label.name = "ElevationInfo"
	elev_label.position = Vector2(20, 120)
	elev_label.add_theme_font_size_override("font_size", 18)
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
	var sea_level_threshold = 0.554
	
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
