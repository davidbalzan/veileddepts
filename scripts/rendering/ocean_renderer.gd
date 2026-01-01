class_name OceanRenderer extends Node3D
## Ocean rendering system using tessarakkt.oceanfft addon

var ocean: Ocean3D
var quad_tree: QuadTree3D
var camera: Camera3D
var initialized: bool = false

@export_group("Wave Settings")
@export var wind_speed: float = 30.0
@export var wind_direction_degrees: float = 0.0
@export_range(0.0, 2.5, 0.1) var choppiness: float = 1.5
@export var time_scale: float = 1.0

@export_group("FFT Settings")
@export_enum("64", "128", "256", "512") var fft_resolution_index: int = 1
@export var horizontal_dimension: int = 512

@export_group("LOD Settings")
@export var lod_level: int = 6
@export var quad_size: float = 16384.0
@export var mesh_vertex_resolution: int = 128

@export_group("Ocean Level")
@export var sea_level: float = 0.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("_setup_ocean")

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
		0: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_64x64
		1: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_128x128
		2: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_256x256
		3: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_512x512
	
	ocean.horizontal_dimension = horizontal_dimension
	ocean.wind_speed = wind_speed
	ocean.wind_direction_degrees = wind_direction_degrees
	ocean.choppiness = choppiness
	ocean.time_scale = time_scale
	ocean.simulation_frameskip = 0
	
	ocean.initialize_simulation()
	await get_tree().process_frame
	
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
	initialized = true
	print("OceanRenderer: Initialized")

func _process(delta: float) -> void:
	if initialized and ocean and ocean.initialized:
		ocean.simulate(delta)

func get_wave_height_3d(world_pos: Vector3) -> float:
	if not initialized or not ocean or not camera or not ocean.initialized:
		return sea_level
	var displacement = ocean.get_wave_height(camera, world_pos)
	return sea_level + displacement

func is_position_underwater(world_pos: Vector3, buffer: float = 0.5) -> bool:
	if not initialized:
		return world_pos.y < sea_level
	var wave_height = get_wave_height_3d(world_pos)
	return world_pos.y < (wave_height - buffer)
