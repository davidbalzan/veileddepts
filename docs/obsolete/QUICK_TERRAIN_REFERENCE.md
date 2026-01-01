# Quick Terrain Reference

## Common Tasks

### Change Terrain Region

**In Editor:**
1. Select `TerrainRenderer` node in scene tree
2. Find `heightmap_region` property
3. Set to desired region (e.g., `(0.2, 0.2, 0.15, 0.15)` for North Atlantic)

**In Code:**
```gdscript
# Use predefined region
$TerrainRenderer.set_terrain_region(TerrainRegions.PACIFIC)

# Or custom region
$TerrainRenderer.set_terrain_region(Rect2(0.5, 0.3, 0.1, 0.1))
```

### Adjust Micro Detail

**More Detail:**
```gdscript
$TerrainRenderer.micro_detail_scale = 3.0
$TerrainRenderer.micro_detail_frequency = 0.1
```

**Less Detail:**
```gdscript
$TerrainRenderer.micro_detail_scale = 1.0
$TerrainRenderer.micro_detail_frequency = 0.03
```

**Disable:**
```gdscript
$TerrainRenderer.enable_micro_detail = false
```

### Find Safe Spawn Position

```gdscript
var terrain = $TerrainRenderer
var safe_pos = terrain.find_safe_spawn_position(
    Vector3(0, 0, 0),  # Preferred position
    1000.0,            # Search radius
    -50.0              # Min depth below sea level
)
submarine.global_position = safe_pos
```

### Check if Position is Underwater

```gdscript
var terrain = $TerrainRenderer
if terrain.is_position_underwater(position, 5.0):
    print("Safe underwater position")
else:
    print("Position is on land or too close to sea floor")
```

### Get Terrain Height

```gdscript
var terrain = $TerrainRenderer

# From 2D position (XZ plane)
var height = terrain.get_height_at(Vector2(x, z))

# From 3D position
var height = terrain.get_height_at_3d(Vector3(x, y, z))
```

## Predefined Regions

```gdscript
TerrainRegions.MEDITERRANEAN      # Default
TerrainRegions.NORTH_ATLANTIC     # Open ocean
TerrainRegions.PACIFIC            # Large area
TerrainRegions.CARIBBEAN          # Islands
TerrainRegions.NORWEGIAN_SEA      # Fjords
TerrainRegions.SOUTH_CHINA_SEA    # Complex coast
TerrainRegions.ARCTIC             # Polar
TerrainRegions.INDIAN_OCEAN       # Tropical
TerrainRegions.BALTIC_SEA         # Enclosed
TerrainRegions.PERSIAN_GULF       # Shallow
```

## Default Settings

```gdscript
terrain_size = Vector2i(2048, 2048)
terrain_resolution = 256
max_height = 100.0
min_height = -200.0
sea_level = 0.0

enable_micro_detail = true
micro_detail_scale = 2.0
micro_detail_frequency = 0.05

use_external_heightmap = true
external_heightmap_path = "res://src_assets/World_elevation_map.png"
heightmap_region = Rect2(0.25, 0.3, 0.1, 0.1)  # Mediterranean
```

## Troubleshooting

**Submarine spawns on land:**
- Check that `use_external_heightmap = true`
- Verify `heightmap_region` has water in it
- Ensure terrain initializes before submarine spawn

**Terrain is too flat:**
- Enable micro detail: `enable_micro_detail = true`
- Increase detail scale: `micro_detail_scale = 3.0`
- Increase frequency: `micro_detail_frequency = 0.1`

**Terrain loads slowly:**
- Reduce `terrain_resolution` (e.g., 128 instead of 256)
- Reduce `lod_levels` (e.g., 3 instead of 4)
- Disable micro detail if not needed

**Wrong region displayed:**
- Check `heightmap_region` coordinates (0-1 range)
- Verify `external_heightmap_path` is correct
- Ensure `use_external_heightmap = true`

## Testing

```bash
# Test terrain and spawn system
godot --headless --script test_terrain_spawn.gd

# Test submarine movement with terrain
godot --headless --script test_submarine_movement.gd
```
