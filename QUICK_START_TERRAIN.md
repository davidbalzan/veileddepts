# Quick Start: Terrain Features

## What's New

Your submarine simulator now has:
1. **Real-world terrain** from world elevation map (default: Mediterranean)
2. **Micro detail** to prevent flat surfaces
3. **Safe spawn system** - submarine always starts in water
4. **Tactical map terrain** - see the terrain on your map

## Quick Start

### Launch the Game

```bash
./run_game.sh
# or
godot scenes/main.tscn
```

### View Terrain on Tactical Map

1. Press `1` to switch to Tactical Map view
2. You'll see colored terrain:
   - **Blue**: Water (darker = deeper)
   - **Sandy**: Beach/coastline
   - **Green/Brown**: Land
   - **Gray**: Mountains
3. Press `T` to toggle terrain on/off
4. Use **mouse wheel** to zoom
5. **Middle mouse + drag** to pan

### Change Terrain Region

Edit `scenes/main.tscn` or use code:

```gdscript
# In editor: Select TerrainRenderer node
# Set heightmap_region to one of:

# Mediterranean (default)
Rect2(0.25, 0.3, 0.1, 0.1)

# North Atlantic
Rect2(0.2, 0.2, 0.15, 0.15)

# Caribbean
Rect2(0.15, 0.35, 0.1, 0.1)

# Pacific
Rect2(0.6, 0.3, 0.2, 0.2)
```

Or use predefined regions:

```gdscript
$TerrainRenderer.set_terrain_region(TerrainRegions.NORTH_ATLANTIC)
```

## Key Features

### 1. World Elevation Map
- Real-world geography
- Multiple regions available
- 2048m x 2048m terrain area

### 2. Micro Detail
- Adds 0.2-0.5m height variations
- Prevents flat surfaces
- Respects original terrain shape

### 3. Safe Spawn
- Submarine always starts in water
- Minimum 5m clearance above sea floor
- Automatic position finding

### 4. Tactical Map Terrain
- Color-coded elevation
- Toggle with `T` key
- Zoom and pan support

## Controls

### Tactical Map
- `1` - Switch to Tactical Map
- `T` - Toggle terrain
- `Mouse Wheel` - Zoom
- `Middle Mouse + Drag` - Pan
- `Left Click` - Set waypoint

### Submarine
- `W/S` or `↑/↓` - Speed
- `A/D` or `←/→` - Heading
- `Space` - Stop
- `Q/E` - Depth

### Views
- `1` - Tactical Map
- `2` - Periscope View
- `3` - External View

## Testing

### Test Terrain System
```bash
godot --headless --script test_terrain_spawn.gd
```

### Test Tactical Map
```bash
godot --headless --script test_tactical_map_terrain.gd
```

### Test Submarine Movement
```bash
godot --headless --script test_submarine_movement.gd
```

## Configuration

### Adjust Micro Detail

More detail:
```gdscript
$TerrainRenderer.micro_detail_scale = 3.0
$TerrainRenderer.micro_detail_frequency = 0.1
```

Less detail:
```gdscript
$TerrainRenderer.micro_detail_scale = 1.0
$TerrainRenderer.micro_detail_frequency = 0.03
```

Disable:
```gdscript
$TerrainRenderer.enable_micro_detail = false
```

### Change Terrain Colors

Edit `scripts/views/tactical_map_view.gd`:

```gdscript
# In _generate_terrain_texture()
var deep_water = Color(0.05, 0.1, 0.3, 1.0)
var shallow_water = Color(0.1, 0.3, 0.5, 1.0)
# ... etc
```

## Troubleshooting

**Submarine spawns on land:**
- Check terrain region has water
- Verify `use_external_heightmap = true`

**Terrain not visible on map:**
- Press `T` to toggle terrain on
- Check terrain renderer initialized

**Terrain too flat:**
- Enable micro detail
- Increase `micro_detail_scale`

**Performance issues:**
- Reduce `terrain_resolution`
- Disable micro detail if not needed

## Documentation

- `TERRAIN_SYSTEM.md` - Complete terrain documentation
- `TACTICAL_MAP_TERRAIN.md` - Tactical map features
- `QUICK_TERRAIN_REFERENCE.md` - Quick reference
- `TERRAIN_UPDATE_SUMMARY.md` - What changed
- `TACTICAL_MAP_UPDATE_SUMMARY.md` - Tactical map changes

## Examples

### Mediterranean Operations (Default)
- Navigate between Italian coast and North Africa
- Avoid shallow coastal waters
- Use deep channels for transit

### North Atlantic Patrol
- Open ocean operations
- Deep water throughout
- Continental shelf visible

### Caribbean Mission
- Island hopping
- Shallow water hazards
- Coastal navigation

## Tips

1. **Use the tactical map** to plan routes around terrain
2. **Zoom in** to see micro detail on the map
3. **Toggle terrain** if it's distracting
4. **Check depth** before navigating near coastlines
5. **Use waypoints** to navigate around obstacles

## Next Steps

1. Try different terrain regions
2. Experiment with micro detail settings
3. Practice navigation using the tactical map
4. Test submarine in different water depths
5. Explore the terrain visualization

Enjoy your submarine simulator with realistic terrain!
