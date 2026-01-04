class_name OceanRenderer extends Node3D
## Ocean rendering system using tessarakkt.oceanfft addon

var ocean: Ocean3D
var quad_tree: QuadTree3D
var camera: Camera3D
var initialized: bool = false

@export_group("Wave Settings")
@export var wind_speed: float = 5.0  # Lower wind = smaller waves (~0.20m)
@export var wind_direction_degrees: float = 0.0
@export_range(0.0, 2.5, 0.1) var choppiness: float = 1.5
@export var time_scale: float = 1.0

@export_group("FFT Settings")
@export_enum("64", "128", "256", "512") var fft_resolution_index: int = 1
@export var horizontal_dimension: int = 512

@export_group("LOD Settings")
@export var lod_level: int = 6
@export var quad_size: float = 4096.0  # Reduced from 16384 to avoid occluding distant coastlines
@export var mesh_vertex_resolution: int = 128

@export_group("Ocean Level")
@export var sea_level_offset: float = 0.0  # Offset from manager's sea level


func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("_setup_ocean")
		# Connect to SeaLevelManager signal
		if SeaLevelManager:
			SeaLevelManager.sea_level_changed.connect(_on_sea_level_changed)
			# Initialize with current sea level
			var current_sea_level = SeaLevelManager.get_sea_level_meters()
			global_position.y = current_sea_level + sea_level_offset


func _setup_ocean() -> void:
	var rd = RenderingServer.get_rendering_device()
	if rd == null:
		return

	camera = get_viewport().get_camera_3d()
	if not camera:
		camera = Camera3D.new()
		camera.position = Vector3(0, 50, 100)
		camera.far = 16000.0
		add_child(camera)
		camera.make_current()

	ocean = Ocean3D.new()

	match fft_resolution_index:
		0:
			ocean.fft_resolution = Ocean3D.FFTResolution.FFT_64x64
		1:
			ocean.fft_resolution = Ocean3D.FFTResolution.FFT_128x128
		2:
			ocean.fft_resolution = Ocean3D.FFTResolution.FFT_256x256
		3:
			ocean.fft_resolution = Ocean3D.FFTResolution.FFT_512x512

	ocean.horizontal_dimension = horizontal_dimension
	ocean.wind_speed = wind_speed
	ocean.wind_direction_degrees = wind_direction_degrees
	ocean.choppiness = choppiness
	ocean.time_scale = time_scale
	ocean.simulation_frameskip = 0

	ocean.initialize_simulation()
	await get_tree().process_frame
	
	# Set default wave amplitude to 0.2 for calmer seas
	ocean.amplitude_scale_max = 0.2
	ocean.amplitude_scale_min = 0.05  # 25% of max for distant waves

	quad_tree = QuadTree3D.new()
	quad_tree.lod_level = lod_level
	quad_tree.quad_size = quad_size
	quad_tree.mesh_vertex_resolution = mesh_vertex_resolution
	quad_tree.material = ocean.material

	var ranges: Array[float] = []
	var current_range = quad_size / 8.0
	for i in range(lod_level + 1):
		ranges.append(current_range)
		current_range *= 2.5
	quad_tree.ranges = ranges

	add_child(quad_tree)
	
	# Update quad_tree position to match current sea level
	if SeaLevelManager:
		var current_sea_level = SeaLevelManager.get_sea_level_meters()
		quad_tree.global_position.y = current_sea_level + sea_level_offset
	
	initialized = true
	print("OceanRenderer: Initialized")


func _on_sea_level_changed(_normalized: float, meters: float) -> void:
	# Update ocean surface position
	global_position.y = meters + sea_level_offset
	
	# Update quad_tree position if it exists
	if quad_tree and is_instance_valid(quad_tree):
		quad_tree.global_position.y = meters + sea_level_offset


func _exit_tree() -> void:
	# Clean up GPU resources to prevent RID leaks
	if ocean and is_instance_valid(ocean):
		ocean.cleanup()
	initialized = false


func _process(delta: float) -> void:
	if initialized and ocean and ocean.initialized:
		ocean.simulate(delta)


func get_wave_height_3d(world_pos: Vector3) -> float:
	if not initialized or not ocean or not ocean.initialized:
		# Return current sea level from manager if available
		if SeaLevelManager:
			return SeaLevelManager.get_sea_level_meters()
		return 0.0
	
	# Use the current active camera, not the stored one (which may be stale after view switches)
	var active_camera = get_viewport().get_camera_3d()
	if not active_camera:
		if SeaLevelManager:
			return SeaLevelManager.get_sea_level_meters()
		return 0.0
	
	# Use all 3 cascades to match the visual shader (CASCADE_COUNT = 3)
	var displacement = ocean.get_wave_height(active_camera, world_pos, 3, 2)
	
	# Get current sea level from manager
	var current_sea_level = 0.0
	if SeaLevelManager:
		current_sea_level = SeaLevelManager.get_sea_level_meters()
	
	return current_sea_level + displacement


func is_position_underwater(world_pos: Vector3, buffer: float = 0.5) -> bool:
	if not initialized:
		# Use manager's sea level if available
		var sea_level = 0.0
		if SeaLevelManager:
			sea_level = SeaLevelManager.get_sea_level_meters()
		return world_pos.y < sea_level
	
	var wave_height = get_wave_height_3d(world_pos)
	return world_pos.y < (wave_height - buffer)
