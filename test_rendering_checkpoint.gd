extends Node3D
## Visual verification script for Task 9: Rendering System Checkpoint
##
## This script creates a test scene to verify:
## 1. Chunks render with correct LOD based on distance
## 2. Biomes are detected and rendered correctly
## 3. No visible seams between chunks
## 4. Procedural detail is applied correctly
##
## Run in editor: Open this scene and press F6, or attach to a scene and run

# Test configuration
const CHUNK_SIZE: float = 512.0
const LOAD_DISTANCE: float = 2048.0
const TEST_DURATION_SECONDS: float = 30.0

# Components
var streaming_manager: StreamingManager = null
var chunk_manager: ChunkManager = null
var chunk_renderer: ChunkRenderer = null
var biome_detector: BiomeDetector = null
var procedural_detail: ProceduralDetailGenerator = null
var elevation_provider: ElevationDataProvider = null

# Camera for viewing
var camera: Camera3D = null
var camera_position: Vector3 = Vector3(256, 200, 256)
var camera_rotation: Vector2 = Vector2(-30, 0)  # pitch, yaw in degrees

# Test state
var test_time: float = 0.0
var camera_mode: int = 0  # 0=stationary, 1=moving, 2=rotating
var info_label: Label = null
var test_phase: int = 0  # 0=loading, 1=stationary, 2=moving, 3=complete

# Debug visualization
var show_chunk_boundaries: bool = true
var show_lod_colors: bool = true
var show_biome_info: bool = true


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("RENDERING SYSTEM VERIFICATION - TASK 9 CHECKPOINT")
	print("=".repeat(60))

	# Setup the scene
	_setup_environment()
	_setup_camera()
	_setup_streaming_system()
	_setup_ui()

	print("\nTest scene initialized. Controls:")
	print("  WASD - Move camera")
	print("  Mouse - Look around")
	print("  Q/E - Move up/down")
	print("  1 - Toggle chunk boundaries")
	print("  2 - Toggle LOD colors")
	print("  3 - Toggle biome info")
	print("  Space - Cycle camera modes")
	print("  ESC - Exit")
	print("\nStarting visual verification...")


func _setup_environment() -> void:
	"""Create basic environment for viewing terrain"""
	# Add directional light
	var light = DirectionalLight3D.new()
	light.name = "Sun"
	light.position = Vector3(0, 100, 0)
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)

	# Add environment
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	world_env.environment = environment
	add_child(world_env)

	print("Environment created")


func _setup_camera() -> void:
	"""Create and configure camera"""
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = camera_position
	camera.rotation_degrees = Vector3(camera_rotation.x, camera_rotation.y, 0)
	camera.fov = 75.0
	camera.far = 10000.0
	add_child(camera)

	print("Camera created at %s" % camera_position)


func _setup_streaming_system() -> void:
	"""Initialize the terrain streaming system"""
	# Create ElevationDataProvider
	elevation_provider = ElevationDataProvider.new()
	elevation_provider.name = "ElevationDataProvider"
	add_child(elevation_provider)
	elevation_provider.initialize()

	# Create ProceduralDetailGenerator
	procedural_detail = ProceduralDetailGenerator.new()
	procedural_detail.name = "ProceduralDetailGenerator"
	add_child(procedural_detail)

	# Create BiomeDetector
	biome_detector = BiomeDetector.new()
	biome_detector.name = "BiomeDetector"
	add_child(biome_detector)

	# Create ChunkRenderer
	chunk_renderer = ChunkRenderer.new()
	chunk_renderer.name = "ChunkRenderer"
	chunk_renderer.chunk_size = CHUNK_SIZE
	chunk_renderer.lod_levels = 4
	chunk_renderer.base_lod_distance = 200.0
	chunk_renderer.lod_distance_multiplier = 2.0
	add_child(chunk_renderer)

	# Create ChunkManager
	chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	chunk_manager.chunk_size = CHUNK_SIZE
	chunk_manager.max_cache_memory_mb = 256
	add_child(chunk_manager)

	# Create StreamingManager
	streaming_manager = StreamingManager.new()
	streaming_manager.name = "StreamingManager"
	streaming_manager.chunk_size = CHUNK_SIZE
	streaming_manager.load_distance = LOAD_DISTANCE
	streaming_manager.unload_distance = LOAD_DISTANCE * 1.5
	streaming_manager.max_chunks_per_frame = 2
	streaming_manager.max_load_time_ms = 5.0
	streaming_manager.set_async_loading(false)  # Synchronous for testing
	add_child(streaming_manager)

	print("Streaming system initialized")
	print("  Chunk size: %.0f m" % CHUNK_SIZE)
	print("  Load distance: %.0f m" % LOAD_DISTANCE)


func _setup_ui() -> void:
	"""Create UI overlay for test information"""
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	# Info panel
	var panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.size = Vector2(400, 300)
	canvas.add_child(panel)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(info_label)

	# Instructions
	var instructions = Label.new()
	instructions.text = """
Controls:
  WASD - Move camera
  Mouse - Look around
  Q/E - Move up/down
  1 - Toggle chunk boundaries
  2 - Toggle LOD colors
  3 - Toggle biome info
  Space - Cycle camera modes
  ESC - Exit
"""
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.position = Vector2(10, 320)
	canvas.add_child(instructions)

	print("UI created")


func _process(delta: float) -> void:
	test_time += delta

	# Handle input
	_handle_input(delta)

	# Update camera mode
	_update_camera_mode(delta)

	# Update streaming system
	streaming_manager.update(camera.global_position)

	# Update LOD for visible chunks
	_update_chunk_lods()

	# Render chunks if needed
	_render_chunks()

	# Update UI
	_update_ui()

	# Check test completion
	if test_time > TEST_DURATION_SECONDS:
		_complete_test()


func _handle_input(delta: float) -> void:
	"""Handle keyboard and mouse input"""
	var move_speed = 50.0 * delta
	var rotate_speed = 90.0 * delta

	# Camera movement
	if Input.is_key_pressed(KEY_W):
		camera.translate(Vector3(0, 0, -move_speed))
	if Input.is_key_pressed(KEY_S):
		camera.translate(Vector3(0, 0, move_speed))
	if Input.is_key_pressed(KEY_A):
		camera.translate(Vector3(-move_speed, 0, 0))
	if Input.is_key_pressed(KEY_D):
		camera.translate(Vector3(move_speed, 0, 0))
	if Input.is_key_pressed(KEY_Q):
		camera.translate(Vector3(0, -move_speed, 0))
	if Input.is_key_pressed(KEY_E):
		camera.translate(Vector3(0, move_speed, 0))

	# Camera rotation
	if Input.is_key_pressed(KEY_LEFT):
		camera.rotate_y(deg_to_rad(rotate_speed))
	if Input.is_key_pressed(KEY_RIGHT):
		camera.rotate_y(deg_to_rad(-rotate_speed))
	if Input.is_key_pressed(KEY_UP):
		camera.rotate_x(deg_to_rad(rotate_speed))
	if Input.is_key_pressed(KEY_DOWN):
		camera.rotate_x(deg_to_rad(-rotate_speed))

	# Toggle options
	if Input.is_key_pressed(KEY_1) and not Input.is_key_pressed(KEY_SHIFT):
		show_chunk_boundaries = not show_chunk_boundaries
		await get_tree().create_timer(0.2).timeout
	if Input.is_key_pressed(KEY_2):
		show_lod_colors = not show_lod_colors
		await get_tree().create_timer(0.2).timeout
	if Input.is_key_pressed(KEY_3):
		show_biome_info = not show_biome_info
		await get_tree().create_timer(0.2).timeout

	# Cycle camera mode
	if Input.is_key_pressed(KEY_SPACE):
		camera_mode = (camera_mode + 1) % 3
		await get_tree().create_timer(0.2).timeout

	# Exit
	if Input.is_key_pressed(KEY_ESCAPE):
		_complete_test()


func _update_camera_mode(delta: float) -> void:
	"""Update camera based on current mode"""
	match camera_mode:
		0:  # Stationary
			pass
		1:  # Moving forward
			camera.translate(Vector3(0, 0, -20.0 * delta))
		2:  # Rotating
			camera.rotate_y(deg_to_rad(30.0 * delta))


func _update_chunk_lods() -> void:
	"""Update LOD levels for all loaded chunks based on camera distance"""
	var loaded_chunks = streaming_manager.get_loaded_chunks()

	for chunk_coord in loaded_chunks:
		var chunk = chunk_manager.get_chunk(chunk_coord)
		if chunk and chunk.state == ChunkState.State.LOADED:
			var distance = camera.global_position.distance_to(chunk.global_position)
			chunk_renderer.update_chunk_lod(chunk, distance)


func _render_chunks() -> void:
	"""Ensure all loaded chunks have rendering components"""
	var loaded_chunks = streaming_manager.get_loaded_chunks()

	for chunk_coord in loaded_chunks:
		var chunk = chunk_manager.get_chunk(chunk_coord)
		if chunk and chunk.state == ChunkState.State.LOADED:
			_ensure_chunk_rendered(chunk)


func _ensure_chunk_rendered(chunk: TerrainChunk) -> void:
	"""Ensure a chunk has all rendering components"""
	# Skip if already rendered
	if chunk.mesh_instance != null and chunk.lod_meshes.size() > 0:
		return

	# Generate procedural detail
	var camera_distance = camera.global_position.distance_to(chunk.global_position)
	chunk.detail_heightmap = procedural_detail.generate_detail(
		chunk.base_heightmap, chunk.chunk_coord, camera_distance
	)

	# Detect biomes
	chunk.biome_map = biome_detector.detect_biomes(chunk.base_heightmap, 0.0)

	# Generate bump map
	chunk.bump_map = procedural_detail.generate_bump_map(
		chunk.detail_heightmap if chunk.detail_heightmap else chunk.base_heightmap,
		chunk.chunk_coord
	)

	# Create LOD meshes
	chunk.lod_meshes.clear()
	for lod in range(chunk_renderer.lod_levels):
		var mesh = chunk_renderer.create_chunk_mesh(
			chunk.detail_heightmap if chunk.detail_heightmap else chunk.base_heightmap,
			chunk.biome_map,
			chunk.chunk_coord,
			lod
		)
		chunk.lod_meshes.append(mesh)

	# Create material
	chunk.material = chunk_renderer.create_chunk_material(chunk.biome_map, chunk.bump_map)

	# Create mesh instance
	if not chunk.mesh_instance:
		chunk.mesh_instance = MeshInstance3D.new()
		chunk.mesh_instance.name = "Mesh"
		chunk.add_child(chunk.mesh_instance)

	# Set initial mesh and material
	chunk.mesh_instance.mesh = chunk.lod_meshes[0]
	chunk.mesh_instance.material_override = chunk.material

	# Stitch edges with neighbors
	var neighbors = _get_chunk_neighbors(chunk.chunk_coord)
	chunk_renderer.stitch_chunk_edges(chunk, neighbors)


func _get_chunk_neighbors(chunk_coord: Vector2i) -> Dictionary:
	"""Get neighboring chunks for edge stitching"""
	var neighbors = {}
	var directions = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]  # West  # East  # North  # South

	for direction in directions:
		var neighbor_coord = chunk_coord + direction
		if chunk_manager.is_chunk_loaded(neighbor_coord):
			neighbors[direction] = chunk_manager.get_chunk(neighbor_coord)

	return neighbors


func _update_ui() -> void:
	"""Update UI with current test information"""
	if not info_label:
		return

	var loaded_chunks = streaming_manager.get_loaded_chunks()
	var memory_usage = chunk_manager.get_memory_usage_mb()

	# Count chunks by LOD
	var lod_counts = [0, 0, 0, 0]
	for chunk_coord in loaded_chunks:
		var chunk = chunk_manager.get_chunk(chunk_coord)
		if chunk and chunk.current_lod < lod_counts.size():
			lod_counts[chunk.current_lod] += 1

	# Build info text
	var info_text = "RENDERING VERIFICATION - Task 9\n"
	info_text += "Time: %.1f / %.1f s\n" % [test_time, TEST_DURATION_SECONDS]
	info_text += "\n"
	info_text += "Camera: %s\n" % camera.global_position
	info_text += "Mode: %s\n" % ["Stationary", "Moving", "Rotating"][camera_mode]
	info_text += "\n"
	info_text += "Loaded Chunks: %d\n" % loaded_chunks.size()
	info_text += "Memory: %.1f MB\n" % memory_usage
	info_text += "\n"
	info_text += "LOD Distribution:\n"
	for i in range(lod_counts.size()):
		info_text += "  LOD %d: %d chunks\n" % [i, lod_counts[i]]
	info_text += "\n"
	info_text += "Debug Options:\n"
	info_text += "  Chunk Boundaries: %s\n" % ("ON" if show_chunk_boundaries else "OFF")
	info_text += "  LOD Colors: %s\n" % ("ON" if show_lod_colors else "OFF")
	info_text += "  Biome Info: %s\n" % ("ON" if show_biome_info else "OFF")

	info_label.text = info_text


func _complete_test() -> void:
	"""Complete the test and print results"""
	print("\n" + "=".repeat(60))
	print("RENDERING VERIFICATION COMPLETE")
	print("=".repeat(60))

	var loaded_chunks = streaming_manager.get_loaded_chunks()

	print("\nTest Results:")
	print("  Duration: %.1f seconds" % test_time)
	print("  Chunks rendered: %d" % loaded_chunks.size())
	print("  Memory used: %.1f MB" % chunk_manager.get_memory_usage_mb())

	# Check for rendering issues
	var issues = []

	# Check 1: Are chunks rendering?
	if loaded_chunks.size() == 0:
		issues.append("No chunks were rendered")
	else:
		print("  ✓ Chunks are rendering")

	# Check 2: Do chunks have LOD meshes?
	var chunks_with_lod = 0
	for chunk_coord in loaded_chunks:
		var chunk = chunk_manager.get_chunk(chunk_coord)
		if chunk and chunk.lod_meshes.size() > 0:
			chunks_with_lod += 1

	if chunks_with_lod == loaded_chunks.size():
		print("  ✓ All chunks have LOD meshes")
	else:
		issues.append("%d chunks missing LOD meshes" % (loaded_chunks.size() - chunks_with_lod))

	# Check 3: Do chunks have biome maps?
	var chunks_with_biomes = 0
	for chunk_coord in loaded_chunks:
		var chunk = chunk_manager.get_chunk(chunk_coord)
		if chunk and chunk.biome_map != null:
			chunks_with_biomes += 1

	if chunks_with_biomes == loaded_chunks.size():
		print("  ✓ All chunks have biome maps")
	else:
		issues.append("%d chunks missing biome maps" % (loaded_chunks.size() - chunks_with_biomes))

	# Check 4: Do chunks have materials?
	var chunks_with_materials = 0
	for chunk_coord in loaded_chunks:
		var chunk = chunk_manager.get_chunk(chunk_coord)
		if chunk and chunk.material != null:
			chunks_with_materials += 1

	if chunks_with_materials == loaded_chunks.size():
		print("  ✓ All chunks have materials")
	else:
		issues.append(
			"%d chunks missing materials" % (loaded_chunks.size() - chunks_with_materials)
		)

	# Print issues
	if issues.size() > 0:
		print("\n✗ Issues found:")
		for issue in issues:
			print("  - %s" % issue)
	else:
		print("\n✓ No rendering issues detected")

	print("\nManual Verification Checklist:")
	print("  [ ] Chunks render with correct LOD based on distance")
	print("  [ ] Biomes are detected and rendered with correct colors")
	print("  [ ] No visible seams between chunks")
	print("  [ ] Procedural detail is visible at close range")
	print("  [ ] LOD transitions are smooth")
	print("  [ ] Textures tile seamlessly across boundaries")

	print("\n" + "=".repeat(60))

	# Don't auto-exit, let user review
	print("\nPress ESC to exit or continue exploring...")
