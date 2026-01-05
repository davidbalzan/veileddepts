extends Node
## Sky and Weather Testing Helper
## Attach to Main scene or use as AutoLoad for quick testing

# References (auto-found on ready)
var atmosphere: AtmosphereRenderer
var weather: WeatherSystem
var cloud1: CloudLayer
var cloud2: CloudLayer

# Testing state
var demo_active: bool = false
var demo_index: int = 0


func _ready() -> void:
	# Find system references
	atmosphere = _find_node_by_group("atmosphere_renderer")
	weather = _find_node_by_group("weather_system")
	
	if atmosphere:
		cloud1 = atmosphere.get_node_or_null("CloudLayer1")
		cloud2 = atmosphere.get_node_or_null("CloudLayer2")
		print("✓ Sky/Weather systems found")
	else:
		push_error("Sky/Weather helper: Systems not found!")
	
	print("\n=== Sky & Weather Test Helper ===")
	print("Press F6 to cycle through demos")
	print("Press F7 to toggle auto-weather")
	print("Press F8 to cycle time of day")
	print("Press F9 to cycle weather manually")
	print("================================\n")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F6:
				_next_demo()
			KEY_F7:
				_toggle_auto_weather()
			KEY_F8:
				_cycle_time()
			KEY_F9:
				_cycle_weather()


func _find_node_by_group(group_name: String) -> Node:
	var nodes = get_tree().get_nodes_in_group(group_name)
	return nodes[0] if nodes.size() > 0 else null


## Demo Functions

func _next_demo() -> void:
	if not atmosphere or not weather:
		return
	
	demo_index = (demo_index + 1) % 5
	
	match demo_index:
		0:
			print("\n🌅 Demo 1: Sunrise Time-lapse")
			demo_sunrise_timelapse()
		1:
			print("\n⛈️ Demo 2: Storm Sequence")
			demo_storm_sequence()
		2:
			print("\n🌄 Demo 3: Golden Hour")
			demo_golden_hour()
		3:
			print("\n🌤️ Demo 4: Weather Cycle")
			demo_weather_cycle()
		4:
			print("\n🌙 Demo 5: Day-Night Cycle")
			demo_full_cycle()


func demo_sunrise_timelapse() -> void:
	"""Fast sunrise from night to day"""
	atmosphere.set_time_of_day(4.0)  # Pre-dawn
	atmosphere.set_cycle_speed(1.0)  # Fast
	weather.set_weather_by_name("Clear")
	print("  - Starting at 4:00 AM")
	print("  - Fast cycle enabled")


func demo_storm_sequence() -> void:
	"""Clear -> Cloudy -> Storm progression"""
	atmosphere.set_cycle_speed(0.0)
	atmosphere.set_time_of_day(14.0)
	weather.set_weather_by_name("Clear")
	print("  - 15s Clear weather")
	
	await get_tree().create_timer(15.0).timeout
	weather.set_weather_by_name("Cloudy")
	print("  - 15s Cloudy weather")
	
	await get_tree().create_timer(15.0).timeout
	weather.set_weather_by_name("Storm")
	print("  - ⚡ Storm begins!")


func demo_golden_hour() -> void:
	"""Perfect sunset lighting"""
	atmosphere.pause_cycle()
	atmosphere.set_time_of_day(18.0)  # 6 PM sunset
	weather.set_weather_by_name("Clear")
	
	if cloud1:
		cloud1.set_weather_coverage(0.3)
	if cloud2:
		cloud2.set_weather_coverage(0.2)
	
	print("  - Time frozen at 18:00")
	print("  - Ideal for screenshots")


func demo_weather_cycle() -> void:
	"""Cycle through all weather types"""
	atmosphere.set_cycle_speed(0.05)
	atmosphere.set_time_of_day(12.0)
	
	var weathers = ["Clear", "Cloudy", "Overcast", "Rain", "Storm"]
	print("  - Cycling through all weather types...")
	
	for i in weathers.size():
		weather.set_weather_by_name(weathers[i])
		print("  - ", weathers[i])
		await get_tree().create_timer(12.0).timeout


func demo_full_cycle() -> void:
	"""Complete 24-hour cycle at medium speed"""
	atmosphere.set_time_of_day(0.0)  # Midnight
	atmosphere.set_cycle_speed(0.5)  # 48 min per day
	weather.set_weather_by_name("Clear")
	print("  - Full 24-hour cycle starting")
	print("  - Watch sunrise at ~6:00")
	print("  - Watch sunset at ~18:00")


## Manual Controls

func _toggle_auto_weather() -> void:
	if not weather:
		return
	
	weather.auto_transition = !weather.auto_transition
	if weather.auto_transition:
		print("🔄 Auto-weather: ENABLED")
	else:
		print("⏸️ Auto-weather: DISABLED")


func _cycle_time() -> void:
	if not atmosphere:
		return
	
	var current = atmosphere.time_of_day
	var next_time = fmod(current + 3.0, 24.0)  # +3 hours
	atmosphere.set_time_of_day(next_time)
	print("⏰ Time: ", int(next_time), ":00")


func _cycle_weather() -> void:
	if not weather:
		return
	
	var weathers = ["Clear", "Cloudy", "Overcast", "Rain", "Storm"]
	var current_idx = weathers.find(weather.get_current_weather_name())
	var next_idx = (current_idx + 1) % weathers.size()
	
	weather.set_weather_by_name(weathers[next_idx])
	print("🌦️ Weather: ", weathers[next_idx])


## Quick Access Functions (call from console or other scripts)

func set_time(hour: float) -> void:
	"""Set time of day (0-24)"""
	if atmosphere:
		atmosphere.set_time_of_day(hour)
		print("Time set to ", hour, ":00")


func set_weather(weather_name: String) -> void:
	"""Set weather by name"""
	if weather:
		weather.set_weather_by_name(weather_name)
		print("Weather set to ", weather_name)


func set_time_speed(speed: float) -> void:
	"""Set day-night cycle speed"""
	if atmosphere:
		atmosphere.set_cycle_speed(speed)
		print("Cycle speed: ", speed)


func pause_time() -> void:
	"""Pause day-night cycle"""
	if atmosphere:
		atmosphere.pause_cycle()
		print("Time paused")


func resume_time() -> void:
	"""Resume day-night cycle"""
	if atmosphere:
		atmosphere.resume_cycle()
		print("Time resumed")


func auto_weather(enable: bool) -> void:
	"""Enable/disable automatic weather transitions"""
	if weather:
		weather.enable_auto_transition(enable)
		print("Auto-weather: ", "ON" if enable else "OFF")


func set_clouds(coverage: float) -> void:
	"""Set cloud coverage (0-1)"""
	if cloud1:
		cloud1.set_weather_coverage(coverage)
	if cloud2:
		cloud2.set_weather_coverage(coverage * 0.8)
	print("Cloud coverage: ", coverage)


func cloud_speed(speed: float) -> void:
	"""Set cloud animation speed"""
	if cloud1:
		cloud1.set_cloud_speed(speed)
	if cloud2:
		cloud2.set_cloud_speed(speed * 0.75)
	print("Cloud speed: ", speed)


## Info Display

func print_current_status() -> void:
	"""Print current sky/weather state"""
	if not atmosphere or not weather:
		return
	
	print("\n=== Current Status ===")
	print("Time: ", atmosphere.time_of_day, ":00")
	print("Sun elevation: ", atmosphere.get_sun_elevation(), "°")
	print("Weather: ", weather.get_current_weather_name())
	print("Auto-weather: ", weather.auto_transition)
	print("Cycle speed: ", atmosphere.cycle_speed)
	print("=====================\n")
