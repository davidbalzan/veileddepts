class_name AtmosphereRenderer extends WorldEnvironment
## Atmosphere rendering system for sky, clouds, and lighting
## Provides day-night cycle, god rays, and global illumination

# Time of day (0-24 hours)
@export_range(0.0, 24.0, 0.1) var time_of_day: float = 12.0:
	set(value):
		time_of_day = fmod(value, 24.0)
		if initialized:
			_update_time_of_day()

# Day-night cycle speed (hours per real second)
@export var cycle_speed: float = 0.0  # 0 = paused, 1.0 = 1 game hour per real second

# Sun reference
var sun: DirectionalLight3D

# Sky and environment
var sky: Sky
var sky_material: ProceduralSkyMaterial

# Base sun energy (used as multiplier for day-night cycle)
var base_sun_energy: float = 0.64

# Initialization flag
var initialized: bool = false

func _ready() -> void:
	# Add to group for easy finding
	add_to_group("atmosphere_renderer")
	_setup_atmosphere()

func _setup_atmosphere() -> void:
	"""Setup the atmosphere rendering system"""
	
	# Use ProceduralSkyMaterial for simple, reliable blue sky
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.2, 0.4, 0.8)  # Blue sky
	sky_material.sky_horizon_color = Color(0.6, 0.7, 0.9)  # Lighter at horizon
	sky_material.ground_bottom_color = Color(0.05, 0.1, 0.2)
	sky_material.ground_horizon_color = Color(0.3, 0.4, 0.5)
	sky_material.sun_angle_max = 30.0
	sky_material.sun_curve = 0.15
	
	# Create Sky resource
	sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	
	# Create environment if it doesn't exist
	if not environment:
		environment = Environment.new()
	
	# Configure background
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	
	# Ensure the WorldEnvironment has the environment assigned
	self.environment = environment
	
	# Configure ambient light from sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 1.0
	environment.ambient_light_energy = 0.50
	
	# Configure tonemapping
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.0
	
	# Enable Screen Space Reflections (SSR) for water reflections
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.2
	
	# Enable Screen Space Ambient Occlusion (SSAO)
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 2.0
	
	# Disable fog entirely for now - cleaner look
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	
	# Enable SDFGI (Signed Distance Field Global Illumination) with 4 cascades
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_read_sky_light = true
	environment.sdfgi_bounce_feedback = 0.5
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.2
	environment.sdfgi_cascade0_distance = 12.8
	environment.sdfgi_max_distance = 204.8
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	environment.sdfgi_energy = 1.0
	environment.sdfgi_normal_bias = 1.1
	environment.sdfgi_probe_bias = 1.1
	
	# Configure glow (subtle)
	environment.glow_enabled = true
	environment.glow_normalized = false
	environment.glow_intensity = 0.4
	environment.glow_strength = 1.0
	environment.glow_mix = 0.05
	environment.glow_bloom = 0.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 1.0
	environment.glow_hdr_scale = 2.0
	
	# Find or create sun (DirectionalLight3D)
	sun = _find_sun()
	if not sun:
		push_warning("AtmosphereRenderer: No DirectionalLight3D found, creating default sun")
		sun = DirectionalLight3D.new()
		get_parent().add_child(sun)
		sun.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else get_parent()
	
	# Configure sun
	sun.light_energy = base_sun_energy  # Default sun strength
	sun.light_color = Color.WHITE
	sun.shadow_enabled = true
	sun.shadow_bias = 0.1
	sun.shadow_normal_bias = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 500.0
	
	initialized = true
	
	# Update to initial time of day
	_update_time_of_day()
	
	print("AtmosphereRenderer: Initialized with time_of_day=", time_of_day)

func _find_sun() -> DirectionalLight3D:
	"""Find existing DirectionalLight3D in the scene"""
	# Check parent's children
	if get_parent():
		for child in get_parent().get_children():
			if child is DirectionalLight3D:
				return child
	
	# Check scene root
	var root = get_tree().root
	if root:
		for child in root.get_children():
			if child is DirectionalLight3D:
				return child
			# Check one level deeper
			for grandchild in child.get_children():
				if grandchild is DirectionalLight3D:
					return grandchild
	
	return null

func _process(delta: float) -> void:
	if not initialized:
		return
	
	# Update day-night cycle if enabled
	if cycle_speed > 0.0:
		time_of_day += cycle_speed * delta
		time_of_day = fmod(time_of_day, 24.0)
		_update_time_of_day()

func _update_time_of_day() -> void:
	"""Update sun position and sky colors based on time of day"""
	if not initialized or not sun or not sky_material:
		return
	
	# Calculate sun angle (0 = midnight, 12 = noon)
	# Sun rises at 6:00, sets at 18:00
	var hour_angle = (time_of_day - 6.0) * 15.0  # 15 degrees per hour
	var sun_elevation = sin(deg_to_rad(hour_angle)) * 90.0  # -90 to +90 degrees
	
	# Clamp sun elevation
	sun_elevation = clamp(sun_elevation, -90.0, 90.0)
	
	# Calculate sun rotation (east to west arc)
	var sun_rotation_y = hour_angle
	var sun_rotation_x = -sun_elevation
	
	# Apply rotation to sun
	sun.rotation_degrees = Vector3(sun_rotation_x, sun_rotation_y, 0.0)
	
	# Calculate lighting intensity based on sun elevation
	var sun_intensity = clamp((sun_elevation + 10.0) / 100.0, 0.0, 1.0)
	
	# Adjust sun energy based on time of day, using base_sun_energy as multiplier
	if sun_elevation > 0.0:
		# Daytime - scale from 0.5x to 1.5x the base energy
		sun.light_energy = base_sun_energy * lerp(0.5, 1.5, sun_intensity)
	else:
		# Nighttime - very dim
		sun.light_energy = base_sun_energy * 0.1
	
	# Calculate day progress for colors
	var day_progress = clamp((sun_elevation + 10.0) / 100.0, 0.0, 1.0)
	
	# Day colors
	var day_sky_top = Color(0.2, 0.4, 0.8)
	var day_sky_horizon = Color(0.6, 0.7, 0.9)
	var day_ground_bottom = Color(0.05, 0.1, 0.2)
	var day_ground_horizon = Color(0.3, 0.4, 0.5)
	
	# Night colors
	var night_sky_top = Color(0.01, 0.01, 0.05)
	var night_sky_horizon = Color(0.05, 0.05, 0.1)
	var night_ground_bottom = Color(0.0, 0.0, 0.0)
	var night_ground_horizon = Color(0.02, 0.02, 0.05)
	
	# Sunrise/sunset colors (when sun is near horizon)
	var sunset_factor = 0.0
	if sun_elevation > -10.0 and sun_elevation < 10.0:
		sunset_factor = 1.0 - abs(sun_elevation) / 10.0
	
	var sunset_sky_horizon = Color(1.0, 0.5, 0.3)
	var sunset_ground_horizon = Color(0.8, 0.4, 0.2)
	
	# Interpolate sky colors
	sky_material.sky_top_color = lerp(night_sky_top, day_sky_top, day_progress)
	sky_material.sky_horizon_color = lerp(
		lerp(night_sky_horizon, day_sky_horizon, day_progress),
		sunset_sky_horizon,
		sunset_factor
	)
	sky_material.ground_bottom_color = lerp(night_ground_bottom, day_ground_bottom, day_progress)
	sky_material.ground_horizon_color = lerp(
		lerp(night_ground_horizon, day_ground_horizon, day_progress),
		sunset_ground_horizon,
		sunset_factor
	)
	
	# Adjust sun color for sunrise/sunset
	if sunset_factor > 0.0:
		sun.light_color = lerp(Color.WHITE, Color(1.0, 0.7, 0.5), sunset_factor)
	else:
		sun.light_color = Color.WHITE
	
	# Adjust ambient light energy
	environment.ambient_light_energy = lerp(0.1, 0.5, day_progress)

func set_time_of_day(hour: float) -> void:
	"""Set the time of day (0-24 hours)"""
	time_of_day = fmod(hour, 24.0)
	_update_time_of_day()

func get_sun_elevation() -> float:
	"""Get current sun elevation in degrees (-90 to +90)"""
	var hour_angle = (time_of_day - 6.0) * 15.0
	return sin(deg_to_rad(hour_angle)) * 90.0

func is_sun_visible() -> bool:
	"""Check if sun is above horizon (for god rays)"""
	return get_sun_elevation() > 0.0

func set_cloud_coverage(_coverage: float) -> void:
	"""Placeholder for cloud coverage - requires sky shader addon for proper clouds"""
	# Note: Godot's built-in ProceduralSkyMaterial doesn't support clouds
	# For volumetric clouds, consider using:
	# - A custom sky shader with raymarched clouds
	# - The "Godot Sky Addon" or similar
	pass

func get_sun_direction() -> Vector3:
	"""Get normalized sun direction vector"""
	if sun:
		return -sun.global_transform.basis.z
	return Vector3.DOWN

func set_cycle_speed(speed: float) -> void:
	"""Set day-night cycle speed (hours per real second)"""
	cycle_speed = speed

func pause_cycle() -> void:
	"""Pause the day-night cycle"""
	cycle_speed = 0.0

func resume_cycle(speed: float = 1.0) -> void:
	"""Resume the day-night cycle at specified speed"""
	cycle_speed = speed
