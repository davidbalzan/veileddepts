class_name OceanRenderer extends Node3D
## Ocean rendering system wrapper for tessarakkt.oceanfft addon
## Provides FFT-based ocean simulation with waves, foam, caustics, and buoyancy

# Ocean3D resource (the FFT simulation)
var ocean: Ocean3D

# QuadTree3D for LOD mesh rendering
var quad_tree: QuadTree3D

# OceanEnvironment for managing the simulation
var ocean_environment: Node  # OceanEnvironment type

# Camera reference for wave height queries
var camera: Camera3D

# Ocean parameters
@export_group("Wave Settings")
@export var wind_speed: float = 15.00:
	set(value):
		wind_speed = value
		if ocean:
			ocean.wind_speed = value

@export var wind_direction_degrees: float = 0.0:
	set(value):
		wind_direction_degrees = value
		if ocean:
			ocean.wind_direction_degrees = value

@export_range(0.0, 5.0, 0.1) var choppiness: float = 1.50:
	set(value):
		choppiness = value
		if ocean:
			ocean.choppiness = value

@export var time_scale: float = 1.0:
	set(value):
		time_scale = value
		if ocean:
			ocean.time_scale = value

@export_group("Foam Settings")
@export_range(0.0, 2.0, 0.05) var foam_jacobian_limit: float = 0.62:
	set(value):
		foam_jacobian_limit = value
		_update_foam_params()

@export_range(0.0, 2.0, 0.05) var foam_coverage: float = 0.26:
	set(value):
		foam_coverage = value
		_update_foam_params()

@export_range(0.0, 5.0, 0.1) var foam_mix_strength: float = 1.86:
	set(value):
		foam_mix_strength = value
		_update_foam_params()

@export_range(0.0, 3.0, 0.1) var foam_diffuse_strength: float = 1.55:
	set(value):
		foam_diffuse_strength = value
		_update_foam_params()

@export_group("Specular Settings")
@export_range(0.0, 2.0, 0.05) var specular_strength: float = 0.10:
	set(value):
		specular_strength = value
		_update_specular_params()

@export_range(0.0, 1.0, 0.05) var pbr_specular_strength: float = 0.49:
	set(value):
		pbr_specular_strength = value
		_update_specular_params()

@export_range(0.0, 0.5, 0.01) var pbr_specular_offset: float = 0.05:
	set(value):
		pbr_specular_offset = value
		_update_specular_params()

@export_group("FFT Settings")
# FFT resolution (must be power of 2)
@export_enum("64", "128", "256", "512") var fft_resolution_index: int = 2

# Horizontal dimension of ocean patch
@export var horizontal_dimension: int = 512

@export_group("LOD Settings")
# QuadTree LOD settings
@export var lod_level: int = 5
@export var quad_size: float = 8192.0

# Initialization flag
var initialized: bool = false

func _update_foam_params() -> void:
	if ocean and ocean.material:
		ocean.material.set_shader_parameter("foam_jacobian_limit", foam_jacobian_limit)
		ocean.material.set_shader_parameter("foam_coverage", foam_coverage)
		ocean.material.set_shader_parameter("foam_mix_strength", foam_mix_strength)
		ocean.material.set_shader_parameter("foam_diffuse_strength", foam_diffuse_strength)

func _update_specular_params() -> void:
	if ocean and ocean.material:
		ocean.material.set_shader_parameter("specular_strength", specular_strength)
		ocean.material.set_shader_parameter("pbr_specular_strength", pbr_specular_strength)
		ocean.material.set_shader_parameter("pbr_specular_offset", pbr_specular_offset)

func _ready() -> void:
	_setup_ocean()

func _setup_ocean() -> void:
	"""Setup the ocean using the tessarakkt.oceanfft addon"""
	
	# Check if we have a rendering device (not available in headless mode)
	var rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_warning("OceanRenderer: No RenderingDevice available (headless mode?). Using fallback.")
		initialized = true
		return
	
	# Get or create camera reference
	camera = get_viewport().get_camera_3d()
	if not camera:
		push_warning("OceanRenderer: No camera found in viewport, creating default camera")
		camera = Camera3D.new()
		camera.position = Vector3(0, 50, 100)
		camera.far = 16000.0
		add_child(camera)
		camera.make_current()
	
	# Create Ocean3D resource
	ocean = Ocean3D.new()
	ocean.wind_speed = wind_speed
	ocean.wind_direction_degrees = wind_direction_degrees
	ocean.choppiness = choppiness
	ocean.time_scale = time_scale
	ocean.horizontal_dimension = horizontal_dimension
	
	# Set FFT resolution based on index
	match fft_resolution_index:
		0: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_64x64
		1: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_128x128
		2: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_256x256
		3: ocean.fft_resolution = Ocean3D.FFTResolution.FFT_512x512
	
	# Configure visual settings BEFORE initialization (material is preloaded)
	if ocean.material:
		# Apply specular settings
		ocean.material.set_shader_parameter("specular_strength", specular_strength)
		ocean.material.set_shader_parameter("pbr_specular_strength", pbr_specular_strength)
		ocean.material.set_shader_parameter("pbr_specular_offset", pbr_specular_offset)
		
		# Apply foam settings
		ocean.material.set_shader_parameter("foam_jacobian_limit", foam_jacobian_limit)
		ocean.material.set_shader_parameter("foam_coverage", foam_coverage)
		ocean.material.set_shader_parameter("foam_mix_strength", foam_mix_strength)
		ocean.material.set_shader_parameter("foam_diffuse_strength", foam_diffuse_strength)
	
	# Apply choppiness
	ocean.choppiness = choppiness
	
	# Initialize the ocean simulation
	ocean.initialize_simulation()
	
	# Create QuadTree3D for LOD mesh rendering
	quad_tree = QuadTree3D.new()
	quad_tree.lod_level = lod_level
	quad_tree.quad_size = quad_size
	quad_tree.material = ocean.material
	quad_tree.mesh_vertex_resolution = 128
	
	# Configure LOD ranges based on quad size
	var ranges: Array[float] = []
	var current_range = quad_size / 16.0
	for i in range(lod_level + 1):
		ranges.append(current_range)
		current_range *= 2.0
	quad_tree.ranges = ranges
	
	add_child(quad_tree)
	
	initialized = true
	print("OceanRenderer: Initialized with FFT resolution ", ocean.fft_resolution, ", choppiness ", ocean.choppiness)

func _process(delta: float) -> void:
	if not initialized or not ocean:
		return
	
	# Wait for Ocean3D to finish async initialization on render thread
	if not ocean.initialized:
		return
	
	# Update ocean simulation
	ocean.simulate(delta)

func get_wave_height(world_pos: Vector2) -> float:
	"""Get wave height at a specific world position (XZ plane)"""
	if not initialized or not ocean or not camera or not ocean.initialized:
		return 0.0
	
	var pos_3d = Vector3(world_pos.x, 0.0, world_pos.y)
	return ocean.get_wave_height(camera, pos_3d)

func get_wave_height_3d(world_pos: Vector3) -> float:
	"""Get wave height at a specific 3D world position"""
	if not initialized or not ocean or not camera or not ocean.initialized:
		return 0.0
	
	return ocean.get_wave_height(camera, world_pos)

func apply_buoyancy(body: RigidBody3D) -> void:
	"""Apply buoyancy force to a rigid body based on wave height"""
	if not body or not initialized:
		return
	
	var body_pos = body.global_position
	var wave_height = get_wave_height_3d(body_pos)
	
	# Calculate submersion depth
	var water_level = wave_height
	var submersion_depth = water_level - body_pos.y
	
	if submersion_depth > 0.0:
		# Apply upward buoyancy force proportional to submersion
		var buoyancy_force = Vector3.UP * submersion_depth * 100.0 * body.mass
		body.apply_central_force(buoyancy_force)
		
		# Apply drag when underwater
		var drag = -body.linear_velocity * 0.5 * submersion_depth
		body.apply_central_force(drag)

func set_wind(speed: float, direction_degrees: float) -> void:
	"""Set wind parameters for wave generation"""
	wind_speed = speed
	wind_direction_degrees = direction_degrees

func get_wind_direction() -> Vector2:
	"""Get normalized wind direction vector"""
	var rad = deg_to_rad(wind_direction_degrees)
	return Vector2(cos(rad), sin(rad))

func get_ocean_material() -> ShaderMaterial:
	"""Get the ocean shader material for customization"""
	if ocean:
		return ocean.material
	return null

func get_waves_texture(cascade: int = 0) -> Texture2DRD:
	"""Get the wave displacement texture for a specific cascade"""
	if ocean and initialized:
		return ocean.get_waves_texture(cascade)
	return null
