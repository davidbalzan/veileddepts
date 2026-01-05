# Enhanced Sky & Weather System

## Overview
Your Godot 4.x project now has a complete realistic sky and weather system featuring:

- **Procedural Sky** with Rayleigh/Mie scattering for realistic atmospheric effects
- **Dynamic Day-Night Cycle** with beautiful sunrise/sunset transitions
- **Procedural Cloud Layers** with animated noise-based rendering
- **Full Weather System** (Clear, Cloudy, Overcast, Rain, Storm)
- **Performance Optimized** for 60+ FPS on mid-range hardware

## Features

### 1. Realistic Procedural Sky (`atmosphere_renderer.gd`)

**Key Features:**
- Deep blue skies with proper atmospheric scattering
- Realistic sunrise/sunset golden hour effects (5-7am, 5-7pm)
- Purple/orange sunset colors with smooth transitions
- Night sky with stars
- Dynamic sun positioning and lighting
- Enhanced shadow quality with 4 cascades

**Configurable Parameters:**
- `time_of_day`: Current time (0-24 hours) - default 14:00
- `cycle_speed`: Day-night speed (0.1 = 24 minutes per day)
- `rayleigh_coefficient`: Blue sky intensity (2.5 default)
- `mie_coefficient`: Atmospheric haze (0.005 default)
- `sun_curve`: Sun sharpness (0.15 default)

**Controls:**
```gdscript
# Get atmosphere renderer
var atmosphere = get_node("/root/Main/AtmosphereRenderer")

# Set time of day
atmosphere.set_time_of_day(18.0)  # 6 PM sunset

# Change cycle speed
atmosphere.set_cycle_speed(0.2)  # Faster cycle

# Pause/resume cycle
atmosphere.pause_cycle()
atmosphere.resume_cycle(0.1)

# Get sun info
var elevation = atmosphere.get_sun_elevation()
var direction = atmosphere.get_sun_direction()
var is_day = atmosphere.is_sun_visible()
```

### 2. Cloud Layer System (`cloud_layer.gd` + `cloud_layer.gdshader`)

**Features:**
- Two-layer parallax clouds for depth
- Procedural noise-based rendering (FastNoiseLite)
- Animated wind movement
- Weather-responsive coverage
- Semi-transparent blending with sky

**Cloud Layers:**
- Layer 1: 2000m altitude, 50% coverage, faster movement
- Layer 2: 2500m altitude, 40% coverage, slower (parallax)

**Controls:**
```gdscript
# Access cloud layers
var cloud1 = get_node("/root/Main/AtmosphereRenderer/CloudLayer1")
var cloud2 = get_node("/root/Main/AtmosphereRenderer/CloudLayer2")

# Adjust coverage
cloud1.set_weather_coverage(0.8)  # More clouds

# Change speed
cloud1.set_cloud_speed(0.05)  # Faster

# Set wind direction
cloud1.set_wind_direction(Vector2(1.0, 0.5))  # Northeast wind
```

### 3. Weather System (`weather_system.gd`)

**Weather Types:**
1. **Clear** - Blue sky, 20% clouds, full sun
2. **Cloudy** - 60% clouds, slightly dimmed sun
3. **Overcast** - 90% clouds, minimal fog, reduced lighting
4. **Rain** - Full clouds, light fog, rain particles, 30% sun
5. **Storm** - Heavy rain, fog, lightning flashes, dark

**Features:**
- Smooth 10-second weather transitions
- Integrated rain particle systems (2000-4000 particles)
- Automatic lightning during storms (3-10s intervals)
- Fog system integration
- Optional auto-transitions with configurable duration

**Usage:**
```gdscript
# Get weather system
var weather = get_node("/root/Main/WeatherSystem")

# Change weather manually
weather.set_weather_by_name("Rain")
weather.current_weather = WeatherSystem.Weather.STORM

# Enable automatic weather changes
weather.enable_auto_transition(true)
weather.min_weather_duration = 120.0  # 2 min minimum
weather.max_weather_duration = 300.0  # 5 min maximum

# Set weather probabilities
weather.clear_probability = 0.4
weather.rain_probability = 0.2

# Get current weather
var current = weather.get_current_weather_name()

# Listen to weather changes
weather.weather_changed.connect(_on_weather_changed)
weather.precipitation_started.connect(_on_rain_started)
```

### 4. Wetness Shader (`wetness.gdshader`)

**Features:**
- Surface darkening when wet
- Dynamic puddle formation in low areas
- Increased reflectivity (reduced roughness)
- Puddle reflections with noise variation

**Usage:**
Apply to terrain materials during rain:
```gdscript
# In terrain renderer or weather system
var terrain_material = terrain.material_override

# Gradually increase wetness during rain
var tween = create_tween()
tween.tween_method(
	func(value): terrain_material.set_shader_parameter("wetness", value),
	0.0, 1.0, 5.0  # 0 to 1 over 5 seconds
)
```

## Scene Integration

The main scene (`scenes/main.tscn`) now includes:

```
Main/
├── AtmosphereRenderer (WorldEnvironment)
│   ├── CloudLayer1 (MeshInstance3D at 2000m)
│   └── CloudLayer2 (MeshInstance3D at 2500m)
├── WeatherSystem (Node)
└── DirectionalLight3D (Sun)
```

## Quick Start Examples

### Example 1: Time-lapse Day-Night
```gdscript
func demo_time_lapse():
	var atmosphere = get_node("/root/Main/AtmosphereRenderer")
	atmosphere.set_cycle_speed(2.0)  # Very fast (12 min per day)
	atmosphere.set_time_of_day(5.0)  # Start at dawn
```

### Example 2: Storm Sequence
```gdscript
func demo_storm():
	var weather = get_node("/root/Main/WeatherSystem")
	
	# Clear -> Cloudy -> Storm sequence
	weather.set_weather_by_name("Clear")
	await get_tree().create_timer(15.0).timeout
	
	weather.set_weather_by_name("Cloudy")
	await get_tree().create_timer(15.0).timeout
	
	weather.set_weather_by_name("Storm")
```

### Example 3: Golden Hour Photography Mode
```gdscript
func golden_hour_mode():
	var atmosphere = get_node("/root/Main/AtmosphereRenderer")
	atmosphere.pause_cycle()  # Stop time
	atmosphere.set_time_of_day(6.0)  # Sunrise golden hour
	# or atmosphere.set_time_of_day(18.0)  # Sunset
```

### Example 4: Dynamic Weather Based on Gameplay
```gdscript
func on_player_enters_storm_zone():
	var weather = get_node("/root/Main/WeatherSystem")
	weather.current_weather = WeatherSystem.Weather.STORM
	
	# Restore after leaving
	await player_left_storm_zone
	weather.current_weather = WeatherSystem.Weather.CLEAR
```

## Performance Tips

1. **Cloud Optimization:**
   - Reduce cloud mesh size if FPS drops: `cloud.layer_scale = 8000.0`
   - Lower noise texture resolution: `noise_tex.width = 256`
   - Disable one cloud layer on low-end hardware

2. **Particle Optimization:**
   - Reduce rain particle count: `rain_particles.amount = 1000`
   - Use local coordinates: `rain_particles.local_coords = true`
   - Enable view frustum culling

3. **Shader Performance:**
   - Disable SSR on potato PCs: `environment.ssr_enabled = false`
   - Reduce SDFGI cascades: `environment.sdfgi_cascades = 2`
   - Lower shadow quality: `sun.directional_shadow_mode = SHADOW_PARALLEL_2_SPLITS`

4. **Mobile/Low-End:**
   ```gdscript
   # Disable advanced features
   environment.sdfgi_enabled = false
   environment.ssao_enabled = false
   environment.ssr_enabled = false
   sky.radiance_size = Sky.RADIANCE_SIZE_128
   ```

## Customization Guide

### Change Sky Colors
Edit [atmosphere_renderer.gd](../scripts/rendering/atmosphere_renderer.gd#L180):
```gdscript
var day_sky_top = Color(0.1, 0.3, 0.9)  # Deeper blue
var sunset_sky_horizon = Color(1.0, 0.3, 0.1)  # More red
```

### Adjust Cloud Appearance
Edit [cloud_layer.gdshader](../shaders/cloud_layer.gdshader):
```glsl
uniform vec3 cloud_color = vec3(1.0, 0.95, 0.9);  // Warmer clouds
uniform float density = 1.5;  // Thicker clouds
```

### Modify Weather Transitions
Edit [weather_system.gd](../scripts/rendering/weather_system.gd#L165):
```gdscript
params["fog_density"] = 0.01  # Heavier fog in storms
params["sun_modifier"] = 0.1  # Darker storms
```

### Add Lightning Sound Effects
In [weather_system.gd](../scripts/rendering/weather_system.gd#L253):
```gdscript
func _trigger_lightning():
	# Flash effect...
	
	# Add thunder sound
	var audio = AudioStreamPlayer.new()
	add_child(audio)
	audio.stream = preload("res://assets/audio/thunder.ogg")
	audio.play()
```

## Testing Commands (Dev Console)

Add these to your dev console for testing:

```gdscript
# Time control
set_time 12.0
set_time_speed 1.0
pause_time
resume_time

# Weather control
set_weather Clear
set_weather Storm
auto_weather on
auto_weather off

# Cloud control
set_clouds 0.8
cloud_speed 0.05
```

## Known Limitations

1. **No volumetric clouds** - Uses flat quads with shader. For true 3D volumetric clouds, consider paid addons like "Volumetric Clouds Pro"
2. **Rain doesn't interact with geometry** - Particles pass through objects. Add collision layers for realistic puddles
3. **No wind on foliage** - Requires additional WindZone implementation
4. **Lightning is ambient only** - No directional light bolts. Enhance with OmniLight3D at random positions

## Advanced: Custom Weather Types

Create your own weather by extending `weather_system.gd`:

```gdscript
# Add to Weather enum
enum Weather {
	# ... existing ...
	FOG,
	SANDSTORM,
	SNOW
}

# Add parameters in _get_weather_params()
"Fog":
	params["fog_density"] = 0.02
	params["fog_color"] = Color(0.8, 0.8, 0.85)
	params["sun_modifier"] = 0.4
```

## Troubleshooting

**Clouds not visible:**
- Check cloud layer positions: `cloud.position.y = 2000`
- Verify shader is loaded: `cloud.material_override != null`
- Increase camera far plane: `camera.far = 16000`

**Rain particles not showing:**
- Check WeatherSystem is child of Main
- Verify particles are emitting: `rain_particles.emitting`
- Increase visibility AABB

**Performance issues:**
- Profile with Godot profiler (Debug → Profile)
- Disable SDFGI: `environment.sdfgi_enabled = false`
- Reduce particle counts
- Lower shadow quality

**Day-night cycle too fast/slow:**
- Adjust `cycle_speed` (0.1 = 24 minutes per day)
- Use `set_time_of_day()` to jump to specific times

## Credits & Resources

- Sky system inspired by Sebastian Lague's atmospheric scattering
- Cloud shader adapted from GDQuest tutorials
- Weather patterns based on community asset packs
- Performance optimization from Godot documentation

**Useful Resources:**
- [Godot Sky Shader Tutorial](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html)
- [ProceduralSkyMaterial Docs](https://docs.godotengine.org/en/stable/classes/class_proceduralskymaterial.html)
- [GPUParticles3D Best Practices](https://docs.godotengine.org/en/stable/tutorials/3d/particles/index.html)

## What's Next?

Consider adding:
- **Sun shafts** (god rays) using Environment volumetric fog
- **Stars/moon** at night with PanoramaSky overlay
- **Weather audio** (wind, rain sounds)
- **Seasonal variations** (autumn colors, winter snow)
- **Cloud shadows** on terrain using Decal nodes
- **Dynamic fog zones** for specific regions

Enjoy your AAA-quality sky and weather system! 🌤️⛈️🌙
