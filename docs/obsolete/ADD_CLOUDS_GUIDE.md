# Adding Clouds to the Game

## What the Example Has

The godot4-oceanfft example includes:
- **Volumetric Fog** - Creates cloud-like atmosphere
- **Sky Panorama** - HDRI sky texture
- **Fog Effects** - Distance fog and atmospheric scattering
- **Lighting** - Proper sun/sky lighting

## Step 1: Copy Sky Texture

```bash
cp /tmp/godot4-oceanfft-devel/example/sky.exr assets/
cp /tmp/godot4-oceanfft-devel/example/sky.exr.import assets/
```

## Step 2: Update AtmosphereRenderer

Add volumetric fog to `scripts/rendering/atmosphere_renderer.gd`:

```gdscript
func _setup_environment() -> void:
	"""Setup the environment with sky, fog, and volumetric clouds"""
	
	var env = environment.environment
	if not env:
		env = Environment.new()
		environment.environment = env
	
	# Sky setup
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = PanoramaSkyMaterial.new()
	
	# Load sky texture if available
	var sky_texture = load("res://assets/sky.exr")
	if sky_texture:
		sky_material.panorama = sky_texture
	
	sky.sky_material = sky_material
	env.sky = sky
	
	# Ambient light from sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.25
	
	# Tonemap for better colors
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	
	# Distance fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.349, 0.608, 0.890, 1.0)  # Sky blue
	env.fog_light_energy = 0.75
	env.fog_density = 0.0001
	env.fog_sky_affect = 0.0
	
	# VOLUMETRIC FOG (CLOUDS!)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0075  # Cloud density
	env.volumetric_fog_albedo = Color(0.122, 0.333, 0.545, 1.0)  # Cloud color
	env.volumetric_fog_length = 1024.0  # How far clouds extend
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 1.0
	
	# Color adjustment
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.0
	env.adjustment_saturation = 1.0
```

## Step 3: Adjust Cloud Density

You can control cloud appearance with these parameters:

**More Clouds:**
```gdscript
env.volumetric_fog_density = 0.015  # Denser clouds
```

**Lighter Clouds:**
```gdscript
env.volumetric_fog_density = 0.005  # Lighter clouds
```

**Cloud Color:**
```gdscript
# White fluffy clouds
env.volumetric_fog_albedo = Color(0.9, 0.9, 0.95, 1.0)

# Stormy clouds
env.volumetric_fog_albedo = Color(0.3, 0.3, 0.35, 1.0)

# Sunset clouds
env.volumetric_fog_albedo = Color(0.8, 0.5, 0.3, 1.0)
```

## Step 4: Performance Considerations

Volumetric fog is GPU intensive. If performance is an issue:

**Lower Quality:**
```gdscript
env.volumetric_fog_detail_spread = 4.0  # Less detail
env.volumetric_fog_length = 512.0  # Shorter distance
```

**Disable for Underwater:**
```gdscript
func _process(delta: float) -> void:
	# Disable volumetric fog when underwater
	if submarine_depth < -5.0:
		env.volumetric_fog_enabled = false
	else:
		env.volumetric_fog_enabled = true
```

## Step 5: Add Sun Rays (God Rays)

For dramatic effect:

```gdscript
# In your DirectionalLight3D setup
directional_light.shadow_enabled = true
directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

# Volumetric fog will create god rays automatically when sun shines through
```

## Quick Implementation

Add this to your existing `atmosphere_renderer.gd`:

```gdscript
@export var enable_volumetric_clouds: bool = true
@export var cloud_density: float = 0.0075
@export var cloud_color: Color = Color(0.122, 0.333, 0.545, 1.0)

func _setup_volumetric_fog() -> void:
	"""Setup volumetric fog for cloud effects"""
	var env = environment.environment
	if not env or not enable_volumetric_clouds:
		return
	
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = cloud_density
	env.volumetric_fog_albedo = cloud_color
	env.volumetric_fog_length = 1024.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 1.0
	
	print("AtmosphereRenderer: Volumetric clouds enabled")
```

Then call it in `_ready()`:
```gdscript
func _ready() -> void:
	_setup_environment()
	_setup_volumetric_fog()  # Add this
	_setup_sun()
```

## Visual Result

With volumetric fog enabled, you'll see:
- ☁️ Clouds in the sky
- 🌅 Atmospheric depth
- ✨ God rays from the sun
- 🌫️ Distance haze
- 🎨 Better color grading

## Testing

1. Open in Godot Editor
2. Run the game
3. Switch to External View (press 3)
4. Look up at the sky
5. Adjust `cloud_density` in Inspector to taste

## Example Values

**Clear Day:**
```gdscript
cloud_density = 0.003
cloud_color = Color(0.9, 0.9, 0.95, 1.0)
```

**Overcast:**
```gdscript
cloud_density = 0.012
cloud_color = Color(0.5, 0.5, 0.55, 1.0)
```

**Stormy:**
```gdscript
cloud_density = 0.020
cloud_color = Color(0.3, 0.3, 0.35, 1.0)
fog_density = 0.0005  # More distance fog too
```

---

**Note**: Volumetric fog requires Forward+ renderer (which you're using) and a decent GPU.
