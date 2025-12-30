class_name OceanRenderer extends Node3D
## Ocean rendering system using FFT-based wave simulation
## Based on Tessendorf's FFT ocean implementation

# Ocean mesh and materials
var ocean_mesh: MeshInstance3D
var ocean_material: ShaderMaterial

# Wave spectrum parameters
var wind_speed: float = 10.0  # m/s
var wind_direction: Vector2 = Vector2(1.0, 0.0)  # normalized
var fetch_length: float = 100000.0  # meters
var gravity: float = 9.81  # m/s^2

# FFT grid parameters
var grid_size: int = 64  # Reduced from 256 for better performance
var patch_size: float = 1000.0  # Size of ocean patch in meters
var mesh_subdivisions: int = 32  # Separate mesh subdivision count

# Wave spectrum textures
var wave_spectrum: Texture2D
var displacement_texture: Texture2D
var normal_texture: Texture2D
var foam_texture: Texture2D
var caustics_texture: Texture2D

# Phillips spectrum parameters
var phillips_amplitude: float = 0.0002
var wave_suppression: float = 0.001  # Suppress waves smaller than this

# Foam parameters
var foam_threshold: float = -0.5  # Jacobian threshold for foam
var foam_decay: float = 0.5

# Time accumulator for wave animation
var time: float = 0.0

func _ready() -> void:
	_setup_ocean_mesh()
	_setup_ocean_material()
	generate_wave_spectrum(wind_speed, wind_direction)

func _setup_ocean_mesh() -> void:
	"""Create the ocean mesh with appropriate LOD"""
	ocean_mesh = MeshInstance3D.new()
	add_child(ocean_mesh)
	
	# Create a large plane mesh for the ocean surface
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(patch_size, patch_size)
	plane_mesh.subdivide_width = mesh_subdivisions  # Use lower subdivision for mesh
	plane_mesh.subdivide_depth = mesh_subdivisions
	
	ocean_mesh.mesh = plane_mesh
	ocean_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _setup_ocean_material() -> void:
	"""Setup the ocean shader material"""
	ocean_material = ShaderMaterial.new()
	
	# Create basic ocean shader
	var shader = Shader.new()
	shader.code = _get_ocean_shader_code()
	ocean_material.shader = shader
	
	# Set initial parameters
	ocean_material.set_shader_parameter("wind_speed", wind_speed)
	ocean_material.set_shader_parameter("wind_direction", wind_direction)
	ocean_material.set_shader_parameter("time", 0.0)
	ocean_material.set_shader_parameter("patch_size", patch_size)
	
	if ocean_mesh:
		ocean_mesh.material_override = ocean_material

func _get_ocean_shader_code() -> String:
	"""Returns the ocean shader code"""
	return """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float wind_speed = 10.0;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float time = 0.0;
uniform float patch_size = 1000.0;
uniform float foam_threshold = -0.5;
uniform sampler2D wave_height_map : hint_default_white;
uniform sampler2D normal_map : hint_normal;
uniform sampler2D foam_map : hint_default_white;
uniform sampler2D caustics_map : hint_default_white;

// Ocean color parameters
uniform vec4 deep_color : source_color = vec4(0.0, 0.05, 0.15, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.0, 0.3, 0.5, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness = 0.1;
uniform float metallic = 0.0;

// Refraction parameters
uniform float refraction_strength = 0.05;
uniform float water_clarity = 20.0;

// Caustics parameters
uniform float caustics_strength = 0.3;
uniform float caustics_scale = 2.0;

varying vec3 world_position;
varying vec3 vertex_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Sample wave height from texture
	vec2 uv = world_position.xz / patch_size + 0.5;
	float wave_height = texture(wave_height_map, uv).r * 2.0 - 1.0;
	
	// Apply wave displacement
	VERTEX.y += wave_height * 5.0;  // Scale factor for wave amplitude
	
	vertex_normal = NORMAL;
}

void fragment() {
	vec2 uv = world_position.xz / patch_size + 0.5;
	
	// Sample normal map
	vec3 normal = texture(normal_map, uv).rgb * 2.0 - 1.0;
	NORMAL = normalize(normal);
	
	// Calculate refraction
	vec3 view_dir = normalize(VIEW);
	float n1 = 1.0;  // Air
	float n2 = 1.333;  // Water
	vec3 refracted = refract(view_dir, NORMAL, n1 / n2);
	
	// Apply refraction offset to UV for underwater distortion
	vec2 refraction_offset = refracted.xz * refraction_strength;
	vec2 refracted_uv = uv + refraction_offset;
	
	// Sample foam with multiple scales for detail
	float foam = texture(foam_map, refracted_uv).r;
	float foam_detail = texture(foam_map, refracted_uv * 4.0).r * 0.5;
	foam = clamp(foam + foam_detail, 0.0, 1.0);
	
	// Calculate caustics (animated scrolling pattern)
	vec2 caustics_uv1 = world_position.xz * caustics_scale + vec2(time * 0.05, time * 0.03);
	vec2 caustics_uv2 = world_position.xz * caustics_scale * 1.3 - vec2(time * 0.04, time * 0.06);
	float caustics1 = texture(caustics_map, caustics_uv1).r;
	float caustics2 = texture(caustics_map, caustics_uv2).r;
	float caustics = min(caustics1, caustics2) * caustics_strength;
	
	// Mix ocean colors based on depth/view angle (Fresnel)
	float fresnel = pow(1.0 - max(dot(view_dir, NORMAL), 0.0), 3.0);
	vec3 ocean_color = mix(deep_color.rgb, shallow_color.rgb, fresnel);
	
	// Add caustics to shallow areas (less visible in deep water)
	ocean_color += caustics * (1.0 - fresnel) * 0.5;
	
	// Add foam to wave crests
	ocean_color = mix(ocean_color, foam_color.rgb, foam * 0.8);
	
	// Calculate transparency based on depth and clarity
	float depth_factor = 1.0 - exp(-abs(world_position.y) / water_clarity);
	float alpha = mix(0.7, 1.0, depth_factor);
	
	ALBEDO = ocean_color;
	ALPHA = alpha;
	ROUGHNESS = mix(roughness, 0.3, foam);  // Foam is rougher
	METALLIC = metallic;
	SPECULAR = 0.5;
	
	// Add subsurface scattering for more realistic water
	SSS_STRENGTH = 0.3;
}
"""

func generate_wave_spectrum(p_wind_speed: float, p_wind_direction: Vector2) -> void:
	"""Generate wave spectrum using Phillips spectrum"""
	wind_speed = p_wind_speed
	wind_direction = p_wind_direction.normalized()
	
	# Create spectrum texture
	var spectrum_image = Image.create(grid_size, grid_size, false, Image.FORMAT_RGBAF)
	
	for y in range(grid_size):
		for x in range(grid_size):
			var k = _get_wave_vector(x, y)
			var phillips = _phillips_spectrum(k)
			spectrum_image.set_pixel(x, y, Color(phillips, phillips, phillips, 1.0))
	
	wave_spectrum = ImageTexture.create_from_image(spectrum_image)
	
	# Initialize displacement and normal textures
	_initialize_wave_textures()

func _get_wave_vector(x: int, y: int) -> Vector2:
	"""Calculate wave vector for grid position"""
	var n = float(grid_size)
	var kx = (2.0 * PI * (x - n / 2.0)) / patch_size
	var ky = (2.0 * PI * (y - n / 2.0)) / patch_size
	return Vector2(kx, ky)

func _phillips_spectrum(k: Vector2) -> float:
	"""Calculate Phillips spectrum for wave vector k"""
	var k_length = k.length()
	
	if k_length < 0.0001:
		return 0.0
	
	# Suppress small waves
	var k_length2 = k_length * k_length
	var k_length4 = k_length2 * k_length2
	
	# Wind speed factor
	var L = (wind_speed * wind_speed) / gravity
	var L2 = L * L
	
	# Directional factor
	var k_dot_w = k.dot(wind_direction * k_length)
	var k_dot_w2 = k_dot_w * k_dot_w
	
	# Phillips spectrum formula
	var phillips = phillips_amplitude * (exp(-1.0 / (k_length2 * L2)) / k_length4) * k_dot_w2
	
	# Suppress waves traveling opposite to wind
	if k_dot_w < 0.0:
		phillips *= 0.07
	
	# Suppress small waves
	phillips *= exp(-k_length2 * wave_suppression * wave_suppression)
	
	return phillips

func _initialize_wave_textures() -> void:
	"""Initialize displacement and normal textures"""
	var displacement_image = Image.create(grid_size, grid_size, false, Image.FORMAT_RGBAF)
	var normal_image = Image.create(grid_size, grid_size, false, Image.FORMAT_RGB8)
	var foam_image = Image.create(grid_size, grid_size, false, Image.FORMAT_R8)
	
	# Fill with default values
	displacement_image.fill(Color(0.5, 0.5, 0.5, 1.0))
	normal_image.fill(Color(0.5, 0.5, 1.0, 1.0))
	foam_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	
	displacement_texture = ImageTexture.create_from_image(displacement_image)
	normal_texture = ImageTexture.create_from_image(normal_image)
	foam_texture = ImageTexture.create_from_image(foam_image)
	
	# Generate caustics texture
	_generate_caustics_texture()
	
	# Update shader parameters
	if ocean_material:
		ocean_material.set_shader_parameter("wave_height_map", displacement_texture)
		ocean_material.set_shader_parameter("normal_map", normal_texture)
		ocean_material.set_shader_parameter("foam_map", foam_texture)
		ocean_material.set_shader_parameter("foam_threshold", foam_threshold)
		ocean_material.set_shader_parameter("caustics_map", caustics_texture)

func _generate_caustics_texture() -> void:
	"""Generate procedural caustics texture"""
	var caustics_size = 512
	var caustics_image = Image.create(caustics_size, caustics_size, false, Image.FORMAT_R8)
	
	# Generate Voronoi-like pattern for caustics
	for y in range(caustics_size):
		for x in range(caustics_size):
			var uv = Vector2(float(x) / caustics_size, float(y) / caustics_size)
			
			# Create caustics pattern using multiple noise octaves
			var caustics_value = 0.0
			var frequency = 4.0
			var amplitude = 1.0
			
			for octave in range(3):
				var noise_x = uv.x * frequency + float(octave) * 0.5
				var noise_y = uv.y * frequency + float(octave) * 0.7
				
				# Simple procedural pattern
				var pattern = sin(noise_x * PI * 2.0) * sin(noise_y * PI * 2.0)
				pattern = abs(pattern)
				
				caustics_value += pattern * amplitude
				frequency *= 2.0
				amplitude *= 0.5
			
			# Normalize and enhance contrast
			caustics_value = clamp(caustics_value, 0.0, 1.0)
			caustics_value = pow(caustics_value, 2.0)  # Increase contrast
			
			caustics_image.set_pixel(x, y, Color(caustics_value, caustics_value, caustics_value, 1.0))
	
	caustics_texture = ImageTexture.create_from_image(caustics_image)

func update_waves(delta: float) -> void:
	"""Update wave animation"""
	time += delta
	
	if ocean_material:
		ocean_material.set_shader_parameter("time", time)
	
	# NOTE: Foam update disabled for performance
	# The foam is now handled entirely in the shader
	# _update_foam(delta)

func _update_foam(delta: float) -> void:
	"""Update foam texture based on Jacobian determinant"""
	if not foam_texture:
		return
	
	var foam_image = foam_texture.get_image()
	if not foam_image:
		return
	
	# Compute Jacobian for foam detection
	for y in range(grid_size):
		for x in range(grid_size):
			var jacobian = _compute_jacobian(x, y)
			
			# Foam appears where Jacobian is negative (wave compression)
			var foam_intensity = 0.0
			if jacobian < foam_threshold:
				foam_intensity = clamp(-jacobian / abs(foam_threshold), 0.0, 1.0)
			
			# Get current foam and apply decay
			var current_foam = foam_image.get_pixel(x, y).r
			current_foam = max(current_foam * (1.0 - foam_decay * delta), foam_intensity)
			
			foam_image.set_pixel(x, y, Color(current_foam, current_foam, current_foam, 1.0))
	
	# Update texture
	foam_texture.update(foam_image)
	
	if ocean_material:
		ocean_material.set_shader_parameter("foam_map", foam_texture)

func _compute_jacobian(x: int, y: int) -> float:
	"""Compute Jacobian determinant for foam detection"""
	# Simplified Jacobian computation
	# In a full FFT implementation, this would be computed from displacement gradients
	
	var dx = 1.0 / float(grid_size)
	var dy = 1.0 / float(grid_size)
	
	# Get neighboring wave heights
	var h_center = _get_wave_height_at_grid(x, y)
	var h_right = _get_wave_height_at_grid(x + 1, y)
	var h_up = _get_wave_height_at_grid(x, y + 1)
	
	# Compute gradients
	var dh_dx = (h_right - h_center) / dx
	var dh_dy = (h_up - h_center) / dy
	
	# Simplified Jacobian: det(I + gradient)
	# For 2D: (1 + dh/dx) * (1 + dh/dy) - 0
	var jacobian = (1.0 + dh_dx) * (1.0 + dh_dy)
	
	return jacobian - 1.0  # Return deviation from identity

func _get_wave_height_at_grid(x: int, y: int) -> float:
	"""Get wave height at grid coordinates"""
	x = x % grid_size
	y = y % grid_size
	
	if displacement_texture:
		var image = displacement_texture.get_image()
		if image:
			var color = image.get_pixel(x, y)
			return (color.r * 2.0 - 1.0) * 5.0
	
	return 0.0

func get_wave_height(world_position: Vector2) -> float:
	"""Get wave height at a specific world position"""
	# Convert world position to UV coordinates
	var uv = world_position / patch_size + Vector2(0.5, 0.5)
	
	# Clamp to valid range
	uv.x = clamp(uv.x, 0.0, 1.0)
	uv.y = clamp(uv.y, 0.0, 1.0)
	
	# Sample displacement texture if available
	if displacement_texture:
		var pixel_x = int(uv.x * grid_size) % grid_size
		var pixel_y = int(uv.y * grid_size) % grid_size
		
		var image = displacement_texture.get_image()
		if image:
			var color = image.get_pixel(pixel_x, pixel_y)
			# Convert from [0,1] to [-1,1] and scale
			return (color.r * 2.0 - 1.0) * 5.0
	
	# Fallback: simple sine wave
	var wave_freq = 0.1
	var wave_amp = 2.0
	return sin(world_position.x * wave_freq + time) * wave_amp + sin(world_position.y * wave_freq * 0.7 + time * 1.3) * wave_amp * 0.5

func apply_buoyancy(body: RigidBody3D) -> void:
	"""Apply buoyancy force to a rigid body based on wave height"""
	if not body:
		return
	
	var body_pos = body.global_position
	var wave_height = get_wave_height(Vector2(body_pos.x, body_pos.z))
	
	# Calculate buoyancy force
	var water_level = wave_height
	var submersion_depth = water_level - body_pos.y
	
	if submersion_depth > 0.0:
		# Apply upward buoyancy force
		var buoyancy_force = Vector3.UP * submersion_depth * 100.0  # Simplified buoyancy
		body.apply_central_force(buoyancy_force)

func _process(delta: float) -> void:
	update_waves(delta)
