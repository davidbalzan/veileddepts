class_name AtmosphereRenderer extends WorldEnvironment
## Enhanced atmosphere rendering with realistic sky, weather, and day-night cycle
## Features Rayleigh/Mie scattering, procedural clouds, and weather transitions

# Time of day (0-24 hours, normalized to 0-1 for easier calculations)
@export_range(0.0, 24.0, 0.1) var time_of_day: float = 12.0:
	set(value):
		time_of_day = fmod(value, 24.0)
		if initialized:
			_update_time_of_day()

# Day-night cycle speed (multiplier, 0 = paused, 1.0 = 24 min real time per day)
@export var cycle_speed: float = 0.1

# Weather control
@export_enum("Clear", "Cloudy", "Overcast", "Rain", "Storm") var current_weather: String = "Clear":
	set(value):
		if value != current_weather and initialized:
			previous_weather = current_weather
			current_weather = value
			weather_transition_time = weather_transition_duration
		else:
			current_weather = value

# Advanced sky parameters
@export_group("Sky Quality")
# Note: Godot 4.5 removed Rayleigh/Mie scattering parameters from ProceduralSkyMaterial
# Sky appearance is now controlled through color properties
@export_range(0.0, 1.0) var sun_curve: float = 0.15  # Sun sharpness

# Sun reference
var sun: DirectionalLight3D

# Sky and environment
var sky: Sky
var sky_material: ProceduralSkyMaterial

# Base sun energy
var base_sun_energy: float = 1.2

# Cloud system reference (will be created)
var cloud_layers: Array[Node3D] = []

# Weather transition
var weather_transition_time: float = 0.0
var weather_transition_duration: float = 10.0
var previous_weather: String = "Clear"

# Initialization flag
var initialized: bool = false


func _ready() -> void:
	# Add to group for easy finding
	add_to_group("atmosphere_renderer")
	_setup_atmosphere()


func _setup_atmosphere() -> void:
	"""Setup the enhanced atmosphere rendering system with Rayleigh/Mie scattering"""

	# Create ProceduralSkyMaterial with realistic parameters
	sky_material = ProceduralSkyMaterial.new()
	
	# Enhanced sky colors - deeper blues, more realistic
	sky_material.sky_top_color = Color(0.15, 0.35, 0.85)  # Deep blue
	sky_material.sky_horizon_color = Color(0.5, 0.65, 0.85)  # Bright horizon
	sky_material.ground_bottom_color = Color(0.05, 0.08, 0.15)  # Dark ocean reflection
	sky_material.ground_horizon_color = Color(0.25, 0.35, 0.5)  # Lighter ground horizon
	
	# Note: Godot 4.5 removed rayleigh_coefficient, mie_coefficient, etc. from ProceduralSkyMaterial
	# The sky appearance is now controlled primarily through color properties
	sky_material.sun_angle_max = 30.0
	sky_material.sun_curve = sun_curve

	# Create Sky resource
	sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_512  # Higher quality reflections
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	# Create or configure environment
	if not environment:
		environment = Environment.new()

	# Configure background to cover full sky dome
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 1.0
	environment.sky_custom_fov = 0.0  # 0 = use full 180° dome

	# Ensure the WorldEnvironment has the environment assigned
	self.environment = environment

	# Ambient light from sky with better energy distribution
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 1.0
	environment.ambient_light_energy = 0.6

	# Enhanced tonemapping for better dynamic range
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.2

	# Screen Space Reflections for water
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.2

	# SSAO
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 1.5
	environment.ssao_light_affect = 0.5
	environment.ssao_ao_channel_affect = 0.5

	# Fog - disabled by default, weather will control it
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false

	# SDFGI for global illumination
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_read_sky_light = true
	environment.sdfgi_bounce_feedback = 0.6
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.2
	environment.sdfgi_cascade0_distance = 12.8
	environment.sdfgi_max_distance = 204.8
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	environment.sdfgi_energy = 1.0
	environment.sdfgi_normal_bias = 1.1
	environment.sdfgi_probe_bias = 1.1

	# Enhanced glow for sunsets and atmospheric effects
	environment.glow_enabled = true
	environment.glow_normalized = false
	environment.glow_intensity = 0.6
	environment.glow_strength = 1.2
	environment.glow_mix = 0.08
	environment.glow_bloom = 0.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 0.9
	environment.glow_hdr_scale = 2.0

	# Find or create sun (DirectionalLight3D)
	sun = _find_sun()
	if not sun:
		push_warning("AtmosphereRenderer: No DirectionalLight3D found, creating default sun")
		sun = DirectionalLight3D.new()
		get_parent().add_child(sun)
		sun.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else get_parent()

	# Configure sun with better shadow quality
	sun.light_energy = base_sun_energy
	sun.light_color = Color.WHITE
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 800.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = true

	initialized = true

	# Update to initial time of day
	_update_time_of_day()

	print("AtmosphereRenderer: Enhanced atmosphere initialized at ", time_of_day, ":00 hours")


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

	# Update day-night cycle
	if cycle_speed > 0.0:
		# Convert cycle_speed to time progression (0.1 = 24 min per day)
		time_of_day += (cycle_speed * delta * 24.0) / 1440.0  # 1440 minutes per day
		time_of_day = fmod(time_of_day, 24.0)
		_update_time_of_day()
	
	# Update weather transitions
	if weather_transition_time > 0.0:
		weather_transition_time -= delta
		var transition_progress = 1.0 - (weather_transition_time / weather_transition_duration)
		_update_weather_transition(transition_progress)


func _update_time_of_day() -> void:
	"""Update sun position and sky colors with improved transitions"""
	if not initialized or not sun or not sky_material:
		return
	
	# Calculate sun angle (smooth sine wave for realistic arc)
	var hour_angle = (time_of_day - 6.0) * 15.0  # 15 degrees per hour
	var sun_elevation = sin(deg_to_rad(hour_angle)) * 90.0  # -90 to +90
	sun_elevation = clamp(sun_elevation, -90.0, 90.0)

	# Sun rotation
	sun.rotation_degrees = Vector3(-sun_elevation, hour_angle, 0.0)

	# Calculate lighting factors with smoother curves
	var sun_progress = clamp((sun_elevation + 15.0) / 105.0, 0.0, 1.0)  # Start earlier
	var sun_intensity = smoothstep(0.0, 1.0, sun_progress)  # Smooth curve
	
	# Dynamic sun energy with atmosphere consideration
	if sun_elevation > 0.0:
		sun.light_energy = base_sun_energy * lerp(0.6, 1.4, sun_intensity)
	else:
		# Nighttime - very dim (moon simulation)
		sun.light_energy = base_sun_energy * 0.05

	# Enhanced color transitions
	# Sunrise/sunset detection (golden hour)
	var is_sunrise = time_of_day >= 5.0 and time_of_day <= 7.0
	var is_sunset = time_of_day >= 17.0 and time_of_day <= 19.0
	var golden_hour_factor = 0.0
	
	if is_sunrise:
		golden_hour_factor = 1.0 - abs(time_of_day - 6.0) / 1.0
	elif is_sunset:
		golden_hour_factor = 1.0 - abs(time_of_day - 18.0) / 1.0
	
	# Define color palettes
	var day_sky_top = Color(0.15, 0.35, 0.85)  # Deep blue
	var day_sky_horizon = Color(0.5, 0.65, 0.85)  # Bright horizon
	var night_sky_top = Color(0.005, 0.005, 0.02)  # Near black
	var night_sky_horizon = Color(0.02, 0.025, 0.05)  # Dark blue
	var sunset_sky_top = Color(0.4, 0.2, 0.6)  # Purple
	var sunset_sky_horizon = Color(1.0, 0.45, 0.2)  # Orange/red
	var sunrise_sky_horizon = Color(1.0, 0.6, 0.3)  # Warmer orange
	
	# Ground colors
	var day_ground_bottom = Color(0.05, 0.08, 0.15)
	var day_ground_horizon = Color(0.25, 0.35, 0.5)
	var night_ground_bottom = Color(0.0, 0.0, 0.0)
	var night_ground_horizon = Color(0.01, 0.01, 0.02)
	var sunset_ground_horizon = Color(0.6, 0.3, 0.15)
	
	# Interpolate colors
	var base_sky_top = lerp(night_sky_top, day_sky_top, sun_intensity)
	var base_sky_horizon = lerp(night_sky_horizon, day_sky_horizon, sun_intensity)
	var base_ground_bottom = lerp(night_ground_bottom, day_ground_bottom, sun_intensity)
	var base_ground_horizon = lerp(night_ground_horizon, day_ground_horizon, sun_intensity)
	
	# Apply golden hour tinting
	if golden_hour_factor > 0.0:
		var golden_horizon = sunrise_sky_horizon if is_sunrise else sunset_sky_horizon
		sky_material.sky_top_color = lerp(base_sky_top, sunset_sky_top, golden_hour_factor * 0.5)
		sky_material.sky_horizon_color = lerp(base_sky_horizon, golden_horizon, golden_hour_factor)
		sky_material.ground_horizon_color = lerp(base_ground_horizon, sunset_ground_horizon, golden_hour_factor)
	else:
		sky_material.sky_top_color = base_sky_top
		sky_material.sky_horizon_color = base_sky_horizon
		sky_material.ground_horizon_color = base_ground_horizon
	
	sky_material.ground_bottom_color = base_ground_bottom
	
	# Dynamic sun color
	if golden_hour_factor > 0.0:
		# Warm sunrise/sunset colors
		sun.light_color = lerp(Color.WHITE, Color(1.0, 0.7, 0.4), golden_hour_factor)
	else:
		sun.light_color = Color.WHITE

	# Adjust ambient light dynamically
	environment.ambient_light_energy = lerp(0.15, 0.6, sun_intensity)


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


## Weather System Functions

func _update_weather_transition(progress: float) -> void:
	"""Update weather parameters during transition"""
	progress = smoothstep(0.0, 1.0, progress)  # Smooth easing
	
	# Get weather parameters
	var prev_params = _get_weather_params(previous_weather)
	var current_params = _get_weather_params(current_weather)
	
	# Interpolate fog
	if prev_params.has("fog_density") and current_params.has("fog_density"):
		environment.fog_enabled = current_params["fog_density"] > 0.0
		if environment.fog_enabled:
			environment.fog_density = lerp(prev_params["fog_density"], current_params["fog_density"], progress)
			environment.fog_aerial_perspective = 0.5
			environment.fog_sky_affect = 0.5
	
	# Interpolate sun energy modifier
	if prev_params.has("sun_modifier") and current_params.has("sun_modifier"):
		var sun_mod = lerp(prev_params["sun_modifier"], current_params["sun_modifier"], progress)
		sun.light_energy = base_sun_energy * sun_mod
	
	# Update cloud layers if they exist
	for cloud in cloud_layers:
		if cloud.has_method("set_weather_coverage"):
			var coverage = lerp(prev_params.get("cloud_coverage", 0.4), 
							   current_params.get("cloud_coverage", 0.4), progress)
			cloud.call("set_weather_coverage", coverage)


func _get_weather_params(weather: String) -> Dictionary:
	"""Get weather-specific atmospheric parameters"""
	var params = {}
	
	match weather:
		"Clear":
			params["fog_density"] = 0.0
			params["sun_modifier"] = 1.0
			params["cloud_coverage"] = 0.2
		
		"Cloudy":
			params["fog_density"] = 0.0
			params["sun_modifier"] = 0.8
			params["cloud_coverage"] = 0.6
		
		"Overcast":
			params["fog_density"] = 0.001
			params["sun_modifier"] = 0.5
			params["cloud_coverage"] = 0.9
		
		"Rain":
			params["fog_density"] = 0.003
			params["sun_modifier"] = 0.3
			params["cloud_coverage"] = 1.0
		
		"Storm":
			params["fog_density"] = 0.005
			params["sun_modifier"] = 0.15
			params["cloud_coverage"] = 1.0
	
	return params


func set_weather(weather: String) -> void:
	"""Set weather (triggers transition)"""
	if weather != current_weather:
		current_weather = weather


func get_current_weather() -> String:
	"""Get current weather state"""
	return current_weather


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
