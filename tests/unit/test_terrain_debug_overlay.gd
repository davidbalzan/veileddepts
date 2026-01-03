extends GutTest
## Unit tests for TerrainDebugOverlay
##
## Tests debug visualization functionality including:
## - Enabling/disabling debug mode
## - Displaying chunk boundaries
## - Showing performance metrics
## - Memory usage visualization

const TerrainDebugOverlay = preload("res://scripts/rendering/terrain_debug_overlay.gd")

var debug_overlay = null
var chunk_manager: ChunkManager = null
var streaming_manager: StreamingManager = null
var performance_monitor: PerformanceMonitor = null


func before_each() -> void:
	# Create test scene structure
	var root: Node = Node.new()
	add_child_autofree(root)

	# Create mock chunk renderer
	var chunk_renderer = MockChunkRenderer.new()
	chunk_renderer.name = "ChunkRenderer"
	root.add_child(chunk_renderer)

	# Create chunk manager
	chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	chunk_manager.chunk_size = 512.0
	chunk_manager.max_cache_memory_mb = 100
	root.add_child(chunk_manager)

	# Create streaming manager
	streaming_manager = StreamingManager.new()
	streaming_manager.chunk_size = 512.0
	root.add_child(streaming_manager)

	# Create performance monitor
	performance_monitor = PerformanceMonitor.new()
	root.add_child(performance_monitor)

	# Create camera
	var camera = Camera3D.new()
	root.add_child(camera)
	camera.make_current()

	# Create debug overlay
	debug_overlay = TerrainDebugOverlay.new()
	root.add_child(debug_overlay)

	# Wait for ready
	await wait_frames(2)


class MockChunkRenderer:
	extends ChunkRenderer
	
	func _ready():
		# Disable normal initialization
		pass
		
	func create_chunk_mesh(_heightmap, _biome_map, _chunk_coord, _lod_level, _neighbor_lods = {}) -> ArrayMesh:
		var mesh = ArrayMesh.new()
		var vertices = PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.RIGHT])
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
		
	func create_chunk_material(_biome_map, _param2):
		return ShaderMaterial.new()
		
	func update_chunk_lod(_chunk, _lod): 
		pass


func after_each() -> void:
	debug_overlay = null
	chunk_manager = null
	streaming_manager = null
	performance_monitor = null


## Test that debug mode can be enabled/disabled
func test_debug_mode_toggle() -> void:
	# Initially disabled
	assert_false(debug_overlay.enabled, "Debug overlay should start disabled")
	assert_false(debug_overlay.visible, "Debug overlay should not be visible when disabled")

	# Enable
	debug_overlay.toggle()
	assert_true(debug_overlay.enabled, "Debug overlay should be enabled after toggle")
	assert_true(debug_overlay.visible, "Debug overlay should be visible when enabled")

	# Disable
	debug_overlay.toggle()
	assert_false(debug_overlay.enabled, "Debug overlay should be disabled after second toggle")
	assert_false(debug_overlay.visible, "Debug overlay should not be visible when disabled")


## Test that chunk boundaries can be toggled
func test_chunk_boundaries_toggle() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true

	# Initially enabled
	assert_true(debug_overlay.show_chunk_boundaries, "Chunk boundaries should be shown by default")

	# Disable
	debug_overlay.set_show_chunk_boundaries(false)
	assert_false(debug_overlay.show_chunk_boundaries, "Chunk boundaries should be disabled")

	# Enable
	debug_overlay.set_show_chunk_boundaries(true)
	assert_true(debug_overlay.show_chunk_boundaries, "Chunk boundaries should be enabled")


## Test that chunk labels can be toggled
func test_chunk_labels_toggle() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true

	# Initially enabled
	assert_true(debug_overlay.show_chunk_labels, "Chunk labels should be shown by default")

	# Disable
	debug_overlay.set_show_chunk_labels(false)
	assert_false(debug_overlay.show_chunk_labels, "Chunk labels should be disabled")

	# Enable
	debug_overlay.set_show_chunk_labels(true)
	assert_true(debug_overlay.show_chunk_labels, "Chunk labels should be enabled")


## Test that LOD colors can be toggled
func test_lod_colors_toggle() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true

	# Initially enabled
	assert_true(debug_overlay.show_lod_colors, "LOD colors should be shown by default")

	# Disable
	debug_overlay.set_show_lod_colors(false)
	assert_false(debug_overlay.show_lod_colors, "LOD colors should be disabled")

	# Enable
	debug_overlay.set_show_lod_colors(true)
	assert_true(debug_overlay.show_lod_colors, "LOD colors should be enabled")


## Test that memory bar can be toggled
func test_memory_bar_toggle() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true

	# Initially enabled
	assert_true(debug_overlay.show_memory_bar, "Memory bar should be shown by default")

	# Disable
	debug_overlay.set_show_memory_bar(false)
	assert_false(debug_overlay.show_memory_bar, "Memory bar should be disabled")

	# Enable
	debug_overlay.set_show_memory_bar(true)
	assert_true(debug_overlay.show_memory_bar, "Memory bar should be enabled")


## Test that performance metrics can be toggled
func test_performance_metrics_toggle() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true

	# Initially enabled
	assert_true(
		debug_overlay.show_performance_metrics, "Performance metrics should be shown by default"
	)

	# Disable
	debug_overlay.set_show_performance_metrics(false)
	assert_false(debug_overlay.show_performance_metrics, "Performance metrics should be disabled")

	# Enable
	debug_overlay.set_show_performance_metrics(true)
	assert_true(debug_overlay.show_performance_metrics, "Performance metrics should be enabled")


## Test that UI elements are created
func test_ui_elements_created() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true

	await wait_frames(2)

	# Check that UI container exists
	var container: Control = debug_overlay.get_node_or_null("DebugContainer")
	assert_not_null(container, "Debug container should be created")

	# Check that memory bar exists
	var memory_container: Node = container.get_node_or_null("MemoryContainer")
	assert_not_null(memory_container, "Memory container should be created")

	# Check that metrics panel exists
	var metrics_panel: Node = container.get_node_or_null("MetricsPanel")
	assert_not_null(metrics_panel, "Metrics panel should be created")

	# Check that chunk labels container exists
	var labels_container: Node = container.get_node_or_null("ChunkLabelsContainer")
	assert_not_null(labels_container, "Chunk labels container should be created")


## Test that memory usage is displayed correctly
func test_memory_usage_display() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true
	debug_overlay.show_memory_bar = true

	# Find terrain components
	debug_overlay.chunk_manager = chunk_manager

	await wait_frames(2)

	# Trigger update
	debug_overlay._update_memory_display()

	# Check that memory label is updated
	var memory_label: Label = debug_overlay._memory_label
	assert_not_null(memory_label, "Memory label should exist")
	assert_true(
		memory_label.text.contains("Memory Usage"), "Memory label should contain usage text"
	)

	# Check that memory bar is updated
	var memory_bar: ProgressBar = debug_overlay._memory_bar
	assert_not_null(memory_bar, "Memory bar should exist")
	assert_gte(memory_bar.value, 0.0, "Memory bar value should be >= 0")
	assert_lte(memory_bar.value, 100.0, "Memory bar value should be <= 100")


## Test that performance metrics are displayed
func test_performance_metrics_display() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true
	debug_overlay.show_performance_metrics = true

	# Find terrain components
	debug_overlay.performance_monitor = performance_monitor
	debug_overlay.chunk_manager = chunk_manager
	debug_overlay.streaming_manager = streaming_manager

	await wait_frames(2)

	# Trigger update
	debug_overlay._update_performance_metrics()

	# Check that metrics label is updated
	var metrics_label: Label = debug_overlay._metrics_label
	assert_not_null(metrics_label, "Metrics label should exist")
	assert_true(metrics_label.text.contains("Performance Metrics"), "Metrics should contain header")
	assert_true(metrics_label.text.contains("FPS"), "Metrics should contain FPS")
	assert_true(metrics_label.text.contains("Frame Time"), "Metrics should contain frame time")


## Test that chunk boundaries are drawn for loaded chunks
func test_chunk_boundaries_drawn() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true
	debug_overlay.show_chunk_boundaries = true

	# Find terrain components
	debug_overlay.chunk_manager = chunk_manager

	# Load a test chunk
	var chunk_coord: Vector2i = Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)

	await wait_frames(2)

	# Trigger visualization update
	debug_overlay._update_chunk_visualization()

	await wait_frames(2)

	# Check that boundary mesh was created
	assert_true(
		debug_overlay._chunk_boundary_meshes.has(chunk_coord),
		"Boundary mesh should be created for loaded chunk"
	)

	var boundary_mesh: MeshInstance3D = debug_overlay._chunk_boundary_meshes[chunk_coord]
	assert_not_null(boundary_mesh, "Boundary mesh instance should exist")


## Test that boundaries are removed when chunks are unloaded
func test_chunk_boundaries_removed_on_unload() -> void:
	# Enable debug overlay
	debug_overlay.enabled = true
	debug_overlay.visible = true
	debug_overlay.show_chunk_boundaries = true

	# Find terrain components
	debug_overlay.chunk_manager = chunk_manager

	# Load a test chunk
	var chunk_coord: Vector2i = Vector2i(0, 0)
	chunk_manager.load_chunk(chunk_coord)

	await wait_frames(2)

	# Trigger visualization update
	debug_overlay._update_chunk_visualization()

	await wait_frames(2)

	# Verify boundary exists
	assert_true(
		debug_overlay._chunk_boundary_meshes.has(chunk_coord),
		"Boundary mesh should exist for loaded chunk"
	)

	# Unload chunk
	chunk_manager.unload_chunk(chunk_coord)

	await wait_frames(2)

	# Trigger visualization update
	debug_overlay._update_chunk_visualization()

	await wait_frames(2)

	# Verify boundary is removed
	assert_false(
		debug_overlay._chunk_boundary_meshes.has(chunk_coord),
		"Boundary mesh should be removed for unloaded chunk"
	)


## Test that update interval is respected
func test_update_interval() -> void:
	# Enable debug overlay with short update interval
	debug_overlay.enabled = true
	debug_overlay.visible = true
	debug_overlay.update_interval = 0.1

	# Find terrain components
	debug_overlay.chunk_manager = chunk_manager
	debug_overlay.performance_monitor = performance_monitor

	# Reset time
	debug_overlay._time_since_update = 0.0

	# Process for less than update interval
	debug_overlay._process(0.05)

	# Should not have updated yet
	assert_almost_eq(
		debug_overlay._time_since_update, 0.05, 0.01, "Time should accumulate without updating"
	)

	# Process to exceed update interval
	debug_overlay._process(0.06)

	# Should have updated and reset
	assert_almost_eq(debug_overlay._time_since_update, 0.0, 0.01, "Time should reset after update")
