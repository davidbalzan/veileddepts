# Terrain System Documentation

## Overview

The terrain system now uses the world elevation map by default and includes micro-detail generation to prevent flat surfaces at submarine scale.

## Features

### 1. World Elevation Map Integration

The terrain system automatically loads real-world elevation data from `src_assets/World_elevation_map.png`.

**Default Configuration:**
- **Region**: Mediterranean area (UV coordinates: 0.25, 0.3, 0.1, 0.1)
- **Terrain Size**: 2048m x 2048m
- **Height Range**: -200m to +100m
- **Resolution**: 256x256 vertices

**Available Regions** (examples):
```gdscript
# Mediterranean (default)
Rect2(0.25, 0.3, 0.1, 0.1)

# North Atlantic
Rect2(0.2, 0.2, 0.15, 0.15)

# Pacific
Rect2(0.6, 0.3, 0.2, 0.2)

# Caribbean
Rect2(0.15, 0.35, 0.1, 0.1)
```

### 2. Micro Detail System

To prevent large flat planes at submarine scale, the terrain system adds procedural micro-detail using noise.

**Configuration:**
- **Enable Micro Detail**: `true` (default)
- **Detail Scale**: 2.0 meters (height variation)
- **Detail Frequency**: 0.05 (controls detail density)

The micro detail:
- Adds subtle height variations (typically 0.1-0.5 meters)
- Respects the original heightmap shape
- Prevents completely flat surfaces
- Maintains realistic terrain appearance

**Example variation**: Over an 8-meter distance, you'll see ~0.2-0.5 meters of height variation.

### 3. Safe Spawn System

The terrain system includes automatic safe spawn positioning to ensure the submarine starts in water.

**Features:**
- Automatically finds underwater positions
- Ensures clearance above sea floor (default: 5m minimum)
- Searches in spiral pattern if preferred position is invalid
- Validates depth below sea level

**Usage:**
```gdscript
# Find a safe spawn position
var safe_pos = terrain_renderer.find_safe_spawn_position(
    Vector3.ZERO,  # Preferred position
    1000.0,        # Search radius
    -50.0          # Minimum depth below sea level
)

# Check if a position is underwater
var is_safe = terrain_renderer.is_position_underwater(position, 5.0)
```

## Configuration in Editor

The terrain can be configured in `scenes/main.tscn` by selecting the `TerrainRenderer` node:

### Terrain Settings
- `terrain_size`: Size in meters (default: 2048x2048)
- `terrain_resolution`: Heightmap resolution (default: 256)
- `max_height`: Maximum terrain height (default: 100m)
- `min_height`: Minimum terrain height (default: -200m)
- `sea_level`: Water surface level (default: 0m)

### Micro Detail Settings
- `enable_micro_detail`: Enable/disable micro detail (default: true)
- `micro_detail_scale`: Height variation in meters (default: 2.0)
- `micro_detail_frequency`: Detail density (default: 0.05)

### External Heightmap Settings
- `use_external_heightmap`: Use world elevation map (default: true)
- `external_heightmap_path`: Path to heightmap (default: "res://src_assets/World_elevation_map.png")
- `heightmap_region`: Region to use (default: Mediterranean)

## Changing Terrain Region

### Using Predefined Regions

The `TerrainRegions` utility class provides easy access to predefined world regions:

```gdscript
# Get terrain renderer
var terrain = get_node("TerrainRenderer")

# Use a predefined region
terrain.set_terrain_region(TerrainRegions.NORTH_ATLANTIC)
terrain.set_terrain_region(TerrainRegions.CARIBBEAN)
terrain.set_terrain_region(TerrainRegions.PACIFIC)

# Get region by name
var region = TerrainRegions.get_region_by_name("mediterranean")
terrain.set_terrain_region(region)

# Use a random region
terrain.set_terrain_region(TerrainRegions.get_random_region())
```

### Available Predefined Regions

- `MEDITERRANEAN` - Mediterranean Sea (default)
- `NORTH_ATLANTIC` - North Atlantic Ocean
- `PACIFIC` - Pacific Ocean
- `CARIBBEAN` - Caribbean Sea
- `NORWEGIAN_SEA` - Norwegian Sea with fjords
- `SOUTH_CHINA_SEA` - South China Sea
- `ARCTIC` - Arctic Ocean
- `INDIAN_OCEAN` - Indian Ocean
- `BALTIC_SEA` - Baltic Sea
- `PERSIAN_GULF` - Persian Gulf

### Custom Regions

To use a custom region at runtime:

```gdscript
# Get terrain renderer
var terrain = get_node("TerrainRenderer")

# Set custom region (UV coordinates 0-1)
# Format: Rect2(x, y, width, height)
terrain.set_terrain_region(Rect2(0.2, 0.2, 0.15, 0.15))
```

Or in the editor, modify the `heightmap_region` property.

## Performance Notes

- **LOD System**: Terrain uses 4 LOD levels for optimal performance
- **Collision**: HeightMapShape3D provides efficient collision detection
- **Micro Detail**: Adds minimal overhead (computed during heightmap generation)

## Testing

Run the terrain test script to verify configuration:

```bash
godot --headless --script test_terrain_spawn.gd
```

This will verify:
- Terrain loads correctly with world elevation map
- Micro detail is working
- Submarine spawns safely in water
- Safe spawn position finder works correctly

## Technical Details

### Micro Detail Implementation

The micro detail system:
1. Loads the base heightmap from the world elevation map
2. Generates a separate noise layer with higher frequency
3. Blends the noise with the base heightmap (scaled to 2m variation)
4. Preserves the original terrain shape while adding fine detail

### Spawn Position Algorithm

The safe spawn finder:
1. Checks if preferred position is underwater and safe
2. If not, searches in a spiral pattern outward
3. Tests 8 directions per ring, up to 16 rings
4. Returns first valid position found
5. Falls back to default depth if no position found

### Height Sampling

The terrain uses bilinear interpolation for smooth height queries:
- Samples 4 nearest heightmap pixels
- Interpolates between them based on position
- Provides smooth transitions between vertices
