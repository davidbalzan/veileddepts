class_name WeatherSystem extends Node
## Advanced weather system with rain, storms, fog, and transitions
## Integrates with AtmosphereRenderer for seamless weather changes

signal weather_changed(new_weather: String)
signal precipitation_started()
signal precipitation_stopped()

# Weather types
enum Weather {
	CLEAR,
	CLOUDY,
	OVERCAST,
	RAIN,
	STORM
}

# Current weather state
@export var current_weather: Weather = Weather.CLEAR:
	set(value):
		if value != current_weather:
			_change_weather(value)

# Weather transition settings
@export var auto_transition: bool = false
@export_range(30.0, 600.0) var min_weather_duration: float = 120.0  # 2 minutes
@export_range(60.0, 1200.0) var max_weather_duration: float = 300.0  # 5 minutes

# Weather probabilities (must sum to ~1.0)
@export_group("Weather Probabilities")
@export_range(0.0, 1.0) var clear_probability: float = 0.4
@export_range(0.0, 1.0) var cloudy_probability: float = 0.3
@export_range(0.0, 1.0) var overcast_probability: float = 0.15
@export_range(0.0, 1.0) var rain_probability: float = 0.1
@export_range(0.0, 1.0) var storm_probability: float = 0.05

# References
var atmosphere: AtmosphereRenderer
var rain_particles: GPUParticles3D
var storm_particles: GPUParticles3D
var lightning_timer: Timer

# State
var weather_timer: float = 0.0
var next_weather_change: float = 0.0
var is_transitioning: bool = false


func _ready() -> void:
	add_to_group("weather_system")
	
	# Find atmosphere renderer
	atmosphere = _find_atmosphere_renderer()
	if not atmosphere:
		push_error("WeatherSystem: No AtmosphereRenderer found!")
		return
	
	# Setup weather effects
	_setup_rain_system()
	_setup_storm_effects()
	
	# Initialize weather
	_apply_weather(current_weather)
	
	if auto_transition:
		next_weather_change = randf_range(min_weather_duration, max_weather_duration)
	
	print("WeatherSystem: Initialized")


func _find_atmosphere_renderer() -> AtmosphereRenderer:
	"""Find the AtmosphereRenderer in the scene"""
	var atmospheres = get_tree().get_nodes_in_group("atmosphere_renderer")
	if atmospheres.size() > 0:
		return atmospheres[0] as AtmosphereRenderer
	return null


func _process(delta: float) -> void:
	# Auto weather transitions
	if auto_transition:
		weather_timer += delta
		if weather_timer >= next_weather_change:
			weather_timer = 0.0
			next_weather_change = randf_range(min_weather_duration, max_weather_duration)
			_transition_to_random_weather()


func _change_weather(new_weather: Weather) -> void:
	"""Change to a new weather state"""
	var old_weather = current_weather
	current_weather = new_weather
	
	_apply_weather(new_weather)
	
	# Update atmosphere
	if atmosphere:
		atmosphere.set_weather(_weather_to_string(new_weather))
	
	weather_changed.emit(_weather_to_string(new_weather))
	print("Weather changed from ", _weather_to_string(old_weather), " to ", _weather_to_string(new_weather))


func _apply_weather(weather: Weather) -> void:
	"""Apply weather effects"""
	match weather:
		Weather.CLEAR:
			_stop_precipitation()
		
		Weather.CLOUDY:
			_stop_precipitation()
		
		Weather.OVERCAST:
			_stop_precipitation()
		
		Weather.RAIN:
			_start_rain()
		
		Weather.STORM:
			_start_storm()


func _setup_rain_system() -> void:
	"""Create rain particle system"""
	rain_particles = GPUParticles3D.new()
	add_child(rain_particles)
	
	# Configure particles
	rain_particles.amount = 2000
	rain_particles.lifetime = 2.0
	rain_particles.visibility_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 500, 1000))
	rain_particles.emitting = false
	
	# Process material
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(500, 1, 500)
	process_mat.direction = Vector3(0, -1, 0)
	process_mat.initial_velocity_min = 15.0
	process_mat.initial_velocity_max = 20.0
	process_mat.gravity = Vector3(0, -9.8, 0)
	process_mat.scale_min = 0.1
	process_mat.scale_max = 0.2
	rain_particles.process_material = process_mat
	
	# Draw pass mesh (small cylinder for rain drop)
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = 0.5
	rain_particles.draw_pass_1 = cylinder


func _setup_storm_effects() -> void:
	"""Create storm effects (heavier rain + lightning)"""
	storm_particles = GPUParticles3D.new()
	add_child(storm_particles)
	
	# Heavier rain
	storm_particles.amount = 4000
	storm_particles.lifetime = 1.5
	storm_particles.visibility_aabb = AABB(Vector3(-500, -50, -500), Vector3(1000, 500, 1000))
	storm_particles.emitting = false
	
	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(500, 1, 500)
	process_mat.direction = Vector3(0.2, -1, 0.1)  # Slight angle for wind
	process_mat.initial_velocity_min = 25.0
	process_mat.initial_velocity_max = 30.0
	process_mat.gravity = Vector3(2.0, -15.0, 1.0)
	process_mat.scale_min = 0.12
	process_mat.scale_max = 0.25
	storm_particles.process_material = process_mat
	
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.06
	cylinder.height = 0.8
	storm_particles.draw_pass_1 = cylinder
	
	# Lightning timer
	lightning_timer = Timer.new()
	add_child(lightning_timer)
	lightning_timer.wait_time = 5.0
	lightning_timer.one_shot = false
	lightning_timer.timeout.connect(_trigger_lightning)


func _start_rain() -> void:
	"""Start rain effects"""
	if rain_particles:
		rain_particles.emitting = true
	precipitation_started.emit()


func _start_storm() -> void:
	"""Start storm effects"""
	if storm_particles:
		storm_particles.emitting = true
	if lightning_timer:
		lightning_timer.start(randf_range(3.0, 8.0))
	precipitation_started.emit()


func _stop_precipitation() -> void:
	"""Stop all precipitation"""
	if rain_particles:
		rain_particles.emitting = false
	if storm_particles:
		storm_particles.emitting = false
	if lightning_timer:
		lightning_timer.stop()
	precipitation_stopped.emit()


func _trigger_lightning() -> void:
	"""Create lightning flash effect"""
	# Flash the ambient light briefly
	if atmosphere and atmosphere.environment:
		var original_energy = atmosphere.environment.ambient_light_energy
		atmosphere.environment.ambient_light_energy = original_energy * 2.5
		
		# Reset after short delay
		await get_tree().create_timer(0.1).timeout
		atmosphere.environment.ambient_light_energy = original_energy
	
	# Schedule next lightning
	lightning_timer.wait_time = randf_range(3.0, 10.0)


func _transition_to_random_weather() -> void:
	"""Transition to a random weather based on probabilities"""
	var rand = randf()
	var cumulative = 0.0
	
	cumulative += clear_probability
	if rand < cumulative:
		current_weather = Weather.CLEAR
		return
	
	cumulative += cloudy_probability
	if rand < cumulative:
		current_weather = Weather.CLOUDY
		return
	
	cumulative += overcast_probability
	if rand < cumulative:
		current_weather = Weather.OVERCAST
		return
	
	cumulative += rain_probability
	if rand < cumulative:
		current_weather = Weather.RAIN
		return
	
	current_weather = Weather.STORM


func _weather_to_string(weather: Weather) -> String:
	"""Convert weather enum to string"""
	match weather:
		Weather.CLEAR: return "Clear"
		Weather.CLOUDY: return "Cloudy"
		Weather.OVERCAST: return "Overcast"
		Weather.RAIN: return "Rain"
		Weather.STORM: return "Storm"
	return "Clear"


## Public API

func set_weather_by_name(weather_name: String) -> void:
	"""Set weather by string name"""
	match weather_name.to_lower():
		"clear": current_weather = Weather.CLEAR
		"cloudy": current_weather = Weather.CLOUDY
		"overcast": current_weather = Weather.OVERCAST
		"rain": current_weather = Weather.RAIN
		"storm": current_weather = Weather.STORM


func get_current_weather_name() -> String:
	"""Get current weather as string"""
	return _weather_to_string(current_weather)


func enable_auto_transition(enable: bool) -> void:
	"""Enable/disable automatic weather transitions"""
	auto_transition = enable
	if enable:
		weather_timer = 0.0
		next_weather_change = randf_range(min_weather_duration, max_weather_duration)
