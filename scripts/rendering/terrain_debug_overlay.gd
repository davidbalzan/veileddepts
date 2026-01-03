class_name TerrainDebugOverlay extends CanvasLayer
## Debug visualization overlay for the terrain streaming system
##
## Displays:
## - Loaded chunks with boundaries
## - Chunk coordinates as labels
## - LOD levels with color coding
## - Memory usage bar
## - Performance metrics display
##
## Requirements: 13.2, 13.3, 13.5

## Configuration
@export var enabled: bool = false
@export var show_chunk_boundaries: bool = true
@export var show_chunk_labels: bool = true
@export var show_lod_colors: bool = true
@export var show_memory_bar: bool = true
@export var show_performance_metrics: bool = true
@export var update_interval: float = 0.1  # Update display every 100ms

## References to terrain system components
var streaming_manager: StreamingManager = null
var chunk_manager: ChunkManager = null
var performance_monitor: PerformanceMonitor = null
var camera: Camera3D = null

## UI elements
var _container: Control = null
var _memory_bar: ProgressBar = null
var _memory_label: Label = null
var _metrics_panel: PanelContainer = null
var _metrics_label: Label = null
var _chunk_labels_container: Control = null

## 3D visualization
var _chunk_boundary_meshes: Dictionary = {}  # Vector2i -> MeshInstance3D
var _immediate_geometry: ImmediateMesh = null
var _boundary_material: StandardMaterial3D = null

## Update timing
var _time_since_update: float = 0.0

## LOD color scheme
const LOD_COLORS: Array[Color] = [
	Color(0.0, 1.0, 0.0, 0.3),  # LOD 0 - Green (highest detail)
	Color(0.5, 1.0, 0.0, 0.3),  # LOD 1 - Yellow-green
	Color(1.0, 1.0, 0.0, 0.3),  # LOD 2 - Yellow
	Color(1.0, 0.5, 0.0, 0.3),  # LOD 3 - Orange (lowest detail)
]


func _ready() -> void:
	# Set layer to render on top
	layer = 100

	# Create UI container
	_create_ui()

	# Create 3D visualization materials
	_create_3d_materials()

	# Find terrain system components
	_find_terrain_components()

	# Initially hide if not enabled
	visible = enabled


func _process(delta: float) -> void:
	if not enabled or not visible:
		return

	_time_since_update += delta

	if _time_since_update >= update_interval:
		_update_display()
		_time_since_update = 0.0


## Toggle debug overlay visibility
func toggle() -> void:
	enabled = not enabled
	visible = enabled

	if enabled:
		_update_display()
	else:
		_clear_3d_visualization()


## Set whether to show chunk boundaries
func set_show_chunk_boundaries(show: bool) -> void:
	show_chunk_boundaries = show
	if enabled:
		_update_display()


## Set whether to show chunk labels
func set_show_chunk_labels(show: bool) -> void:
	show_chunk_labels = show
	if _chunk_labels_container:
		_chunk_labels_container.visible = show


## Set whether to show LOD colors
func set_show_lod_colors(show: bool) -> void:
	show_lod_colors = show
	if enabled:
		_update_display()


## Set whether to show memory bar
func set_show_memory_bar(show: bool) -> void:
	show_memory_bar = show
	if _memory_bar:
		_memory_bar.visible = show
	if _memory_label:
		_memory_label.visible = show


## Set whether to show performance metrics
func set_show_performance_metrics(show: bool) -> void:
	show_performance_metrics = show
	if _metrics_panel:
		_metrics_panel.visible = show


## Create UI elements
func _create_ui() -> void:
	# Main container
	_container = Control.new()
	_container.name = "DebugContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

	# Memory usage bar (top right)
	var memory_container: VBoxContainer = VBoxContainer.new()
	memory_container.name = "MemoryContainer"
	memory_container.position = Vector2(10, 10)
	memory_container.custom_minimum_size = Vector2(300, 0)
	_container.add_child(memory_container)

	_memory_label = Label.new()
	_memory_label.name = "MemoryLabel"
	_memory_label.text = "Memory Usage: 0 / 0 MB"
	_memory_label.add_theme_color_override("font_color", Color.WHITE)
	_memory_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_memory_label.add_theme_constant_override("outline_size", 2)
	memory_container.add_child(_memory_label)

	_memory_bar = ProgressBar.new()
	_memory_bar.name = "MemoryBar"
	_memory_bar.custom_minimum_size = Vector2(300, 20)
	_memory_bar.max_value = 100.0
	_memory_bar.value = 0.0
	_memory_bar.show_percentage = false
	memory_container.add_child(_memory_bar)

	# Performance metrics panel (top left)
	_metrics_panel = PanelContainer.new()
	_metrics_panel.name = "MetricsPanel"
	_metrics_panel.position = Vector2(10, 60)
	_metrics_panel.custom_minimum_size = Vector2(300, 0)
	_container.add_child(_metrics_panel)

	var metrics_margin: MarginContainer = MarginContainer.new()
	metrics_margin.add_theme_constant_override("margin_left", 10)
	metrics_margin.add_theme_constant_override("margin_right", 10)
	metrics_margin.add_theme_constant_override("margin_top", 10)
	metrics_margin.add_theme_constant_override("margin_bottom", 10)
	_metrics_panel.add_child(metrics_margin)

	_metrics_label = Label.new()
	_metrics_label.name = "MetricsLabel"
	_metrics_label.text = "Performance Metrics"
	_metrics_label.add_theme_color_override("font_color", Color.WHITE)
	metrics_margin.add_child(_metrics_label)

	# Chunk labels container (for 2D labels at chunk positions)
	_chunk_labels_container = Control.new()
	_chunk_labels_container.name = "ChunkLabelsContainer"
	_chunk_labels_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chunk_labels_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_chunk_labels_container)


## Create materials for 3D visualization
func _create_3d_materials() -> void:
	_boundary_material = StandardMaterial3D.new()
	_boundary_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_boundary_material.albedo_color = Color(1.0, 1.0, 0.0, 0.8)
	_boundary_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_boundary_material.no_depth_test = true
	_boundary_material.disable_receive_shadows = true
	_boundary_material.cull_mode = BaseMaterial3D.CULL_DISABLED


## Find terrain system components in the scene tree
func _find_terrain_components() -> void:
	# Try to find components as siblings or in parent
	var parent: Node = get_parent()
	if parent:
		streaming_manager = parent.get_node_or_null("StreamingManager")
		chunk_manager = parent.get_node_or_null("ChunkManager")
		performance_monitor = parent.get_node_or_null("PerformanceMonitor")

	# Try to find camera
	camera = get_viewport().get_camera_3d()


## Update all display elements
func _update_display() -> void:
	if not enabled:
		return

	_update_memory_display()
	_update_performance_metrics()
	_update_chunk_visualization()


## Update memory usage display
func _update_memory_display() -> void:
	if not show_memory_bar or not chunk_manager:
		return

	var current_mb: float = chunk_manager.get_memory_usage_mb()
	var max_mb: int = chunk_manager.max_cache_memory_mb
	var percentage: float = (current_mb / float(max_mb)) * 100.0

	if _memory_label:
		_memory_label.text = (
			"Memory Usage: %.1f / %d MB (%.1f%%)" % [current_mb, max_mb, percentage]
		)

	if _memory_bar:
		_memory_bar.value = percentage

		# Color code the bar based on usage
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if percentage < 70.0:
			style.bg_color = Color(0.0, 0.8, 0.0, 0.8)  # Green
		elif percentage < 90.0:
			style.bg_color = Color(0.8, 0.8, 0.0, 0.8)  # Yellow
		else:
			style.bg_color = Color(0.8, 0.0, 0.0, 0.8)  # Red

		_memory_bar.add_theme_stylebox_override("fill", style)


## Update performance metrics display
func _update_performance_metrics() -> void:
	if not show_performance_metrics or not performance_monitor:
		return

	var metrics: Dictionary = performance_monitor.get_performance_metrics()

	var text: String = "Performance Metrics\n"
	text += "─────────────────────\n"
	text += "FPS: %.1f\n" % metrics.get("current_fps", 0.0)
	text += "Frame Time: %.2f ms\n" % metrics.get("average_frame_time_ms", 0.0)
	text += "Terrain Time: %.2f ms\n" % metrics.get("average_terrain_time_ms", 0.0)
	text += "Terrain Budget: %.1f%%\n" % metrics.get("terrain_budget_usage_percent", 0.0)

	var state: int = metrics.get("performance_state", 0)
	var state_text: String = "NORMAL"
	if state == 1:
		state_text = "LOD_REDUCED"
	elif state == 2:
		state_text = "EMERGENCY_UNLOAD"
	text += "State: %s\n" % state_text

	if chunk_manager:
		text += "\nChunk Info\n"
		text += "─────────────────────\n"
		text += "Loaded Chunks: %d\n" % chunk_manager.get_chunk_count()

	if streaming_manager:
		text += "Load Progress: %.1f%%\n" % (streaming_manager.get_loading_progress() * 100.0)

	if _metrics_label:
		_metrics_label.text = text


## Update chunk visualization (boundaries, labels, LOD colors)
func _update_chunk_visualization() -> void:
	if not chunk_manager or not camera:
		return

	# Clear old labels
	for child in _chunk_labels_container.get_children():
		child.queue_free()

	# Get loaded chunks
	var loaded_chunks: Array[Vector2i] = chunk_manager.get_loaded_chunks()

	# Update visualization for each chunk
	for chunk_coord in loaded_chunks:
		var chunk: TerrainChunk = chunk_manager.get_chunk(chunk_coord)
		if not chunk:
			continue

		# Draw chunk boundary
		if show_chunk_boundaries:
			_draw_chunk_boundary(chunk)

		# Draw chunk label
		if show_chunk_labels:
			_draw_chunk_label(chunk)

		# Apply LOD color overlay
		if show_lod_colors:
			_apply_lod_color(chunk)

	# Remove boundaries for unloaded chunks
	var coords_to_remove: Array[Vector2i] = []
	for coord in _chunk_boundary_meshes.keys():
		if not loaded_chunks.has(coord):
			coords_to_remove.append(coord)

	for coord in coords_to_remove:
		var mesh_instance = _chunk_boundary_meshes[coord]
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
		_chunk_boundary_meshes.erase(coord)


## Draw boundary lines for a chunk
func _draw_chunk_boundary(chunk: TerrainChunk) -> void:
	# Check if we already have a boundary mesh for this chunk
	if _chunk_boundary_meshes.has(chunk.chunk_coord):
		return

	# Create a new mesh instance for the boundary
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "ChunkBoundary_%s" % chunk.chunk_coord

	# Create immediate mesh for drawing lines
	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	mesh_instance.material_override = _boundary_material

	# Get chunk bounds
	var bounds: Rect2 = chunk.world_bounds
	var min_x: float = bounds.position.x
	var min_z: float = bounds.position.y
	var max_x: float = bounds.position.x + bounds.size.x
	var max_z: float = bounds.position.y + bounds.size.y

	# Sample height at corners (approximate)
	var height: float = 0.0
	if chunk.base_heightmap:
		# Use a height slightly above the terrain
		height = 10.0

	# Draw boundary lines
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Bottom edge
	immediate_mesh.surface_add_vertex(Vector3(min_x, height, min_z))
	immediate_mesh.surface_add_vertex(Vector3(max_x, height, min_z))

	# Right edge
	immediate_mesh.surface_add_vertex(Vector3(max_x, height, min_z))
	immediate_mesh.surface_add_vertex(Vector3(max_x, height, max_z))

	# Top edge
	immediate_mesh.surface_add_vertex(Vector3(max_x, height, max_z))
	immediate_mesh.surface_add_vertex(Vector3(min_x, height, max_z))

	# Left edge
	immediate_mesh.surface_add_vertex(Vector3(min_x, height, max_z))
	immediate_mesh.surface_add_vertex(Vector3(min_x, height, min_z))

	immediate_mesh.surface_end()

	# Add to scene
	chunk.add_child(mesh_instance)
	_chunk_boundary_meshes[chunk.chunk_coord] = mesh_instance


## Draw label for a chunk showing coordinates and LOD
func _draw_chunk_label(chunk: TerrainChunk) -> void:
	if not camera:
		return

	# Get chunk center in world space
	var chunk_center: Vector3 = chunk_manager.chunk_to_world(chunk.chunk_coord)

	# Project to screen space
	var screen_pos: Vector2 = camera.unproject_position(chunk_center)

	# Check if on screen
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if (
		screen_pos.x < 0
		or screen_pos.x > viewport_size.x
		or screen_pos.y < 0
		or screen_pos.y > viewport_size.y
	):
		return

	# Create label
	var label: Label = Label.new()
	label.text = "Chunk %s\nLOD: %d" % [chunk.chunk_coord, chunk.current_lod]
	label.position = screen_pos - Vector2(30, 20)  # Center the label
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_chunk_labels_container.add_child(label)


## Apply LOD color overlay to chunk mesh
func _apply_lod_color(chunk: TerrainChunk) -> void:
	if not chunk.mesh_instance or not chunk.material:
		return

	# Get LOD color
	var lod_index: int = clampi(chunk.current_lod, 0, LOD_COLORS.size() - 1)
	var lod_color: Color = LOD_COLORS[lod_index]

	# Apply as a modulation (this is a simple approach)
	# In a real implementation, you might want to modify the shader
	# or add a separate overlay mesh
	# chunk.mesh_instance.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Reset modulation - Node3D doesn't support modulate
	
	# Note: For proper LOD color visualization, you would need to modify
	# the terrain shader to accept a debug color uniform


## Clear all 3D visualization elements
func _clear_3d_visualization() -> void:
	# Remove all boundary meshes
	for mesh_instance in _chunk_boundary_meshes.values():
		if mesh_instance:
			mesh_instance.queue_free()
	_chunk_boundary_meshes.clear()

	# Clear chunk labels
	for child in _chunk_labels_container.get_children():
		child.queue_free()


## Clean up on exit
func _exit_tree() -> void:
	_clear_3d_visualization()
