class_name CloudLayer extends MeshInstance3D
## Procedural cloud layer with animated noise
## Provides realistic clouds that blend with the sky

@export var layer_height: float = 2000.0
@export var layer_scale: float = 10000.0
@export_range(0.0, 1.0) var coverage: float = 0.5
@export_range(0.0, 1.0) var speed: float = 0.02

var cloud_material: ShaderMaterial
var time_offset: float = 0.0


func _ready() -> void:
	_setup_cloud_layer()


func _setup_cloud_layer() -> void:
	"""Initialize the cloud layer mesh and material"""
	
	# Create a large quad mesh for the cloud layer
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(layer_scale, layer_scale)
	mesh = quad_mesh
	
	# Position high in the sky
	position = Vector3(0, layer_height, 0)
	rotation_degrees = Vector3(-90, 0, 0)  # Face down
	
	# Create shader material
	var shader = load("res://shaders/cloud_layer.gdshader")
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = shader
	
	# Generate or load noise textures
	_setup_noise_textures()
	
	# Set initial parameters
	cloud_material.set_shader_parameter("coverage", coverage)
	cloud_material.set_shader_parameter("speed", speed)
	cloud_material.set_shader_parameter("brightness", 1.2)
	cloud_material.set_shader_parameter("wind_direction", Vector2(1.0, 0.3))
	cloud_material.set_shader_parameter("density", 1.0)
	cloud_material.set_shader_parameter("softness", 0.2)
	
	# Apply material
	material_override = cloud_material
	
	# Rendering settings - critical for transparency
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	transparency = 1.0  # Enable transparency
	
	# Make sure it renders
	layers = 1  # Render on main layer
	
	print("CloudLayer: Initialized at height ", layer_height)


func _setup_noise_textures() -> void:
	"""Generate procedural noise textures for clouds"""
	
	# Create main cloud noise
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true
	
	# Create detail noise
	var detail_noise = FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	detail_noise.frequency = 0.08
	detail_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	detail_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	
	var detail_tex = NoiseTexture2D.new()
	detail_tex.noise = detail_noise
	detail_tex.width = 256
	detail_tex.height = 256
	detail_tex.seamless = true
	
	# Set textures
	cloud_material.set_shader_parameter("noise_texture", noise_tex)
	cloud_material.set_shader_parameter("detail_noise", detail_tex)


func set_weather_coverage(new_coverage: float) -> void:
	"""Update cloud coverage for weather changes"""
	coverage = new_coverage
	if cloud_material:
		cloud_material.set_shader_parameter("coverage", coverage)


func set_cloud_speed(new_speed: float) -> void:
	"""Update cloud animation speed"""
	speed = new_speed
	if cloud_material:
		cloud_material.set_shader_parameter("speed", speed)


func set_wind_direction(direction: Vector2) -> void:
	"""Update wind direction for cloud movement"""
	if cloud_material:
		cloud_material.set_shader_parameter("wind_direction", direction)
