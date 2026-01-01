# Tactical Map Terrain Visualization

## Overview

The tactical map now displays the terrain heightmap as a colored background layer, showing land masses, coastlines, and ocean depths.

## Features

### Terrain Display

The terrain is rendered with color-coded elevation:

- **Deep Water** (< -100m): Dark blue `RGB(0.05, 0.1, 0.3)`
- **Shallow Water** (-100m to -20m): Medium blue `RGB(0.1, 0.3, 0.5)`
- **Very Shallow Water** (-20m to 0m): Gradient to sandy color
- **Beach** (0m to +5m): Sandy `RGB(0.8, 0.75, 0.5)`
- **Low Land** (+5m to +30m): Green `RGB(0.3, 0.5, 0.2)`
- **High Land** (+30m to +60m): Brown `RGB(0.5, 0.4, 0.3)`
- **Mountains** (> +60m): Gray `RGB(0.6, 0.6, 0.6)`

### Controls

**Toggle Terrain:**
- Press `T` key
- Click "Toggle Terrain (T)" button

**Map Navigation:**
- **Mouse Wheel**: Zoom in/out
- **Middle Mouse Button + Drag**: Pan the map
- **Left Click**: Set waypoint

### Transparency

The terrain is rendered with 70% opacity (`alpha = 0.7`) so that submarine, contacts, and waypoints remain clearly visible on top.

## Technical Details

### Terrain Texture Generation

The terrain texture is generated from the heightmap during initialization:

1. Reads the heightmap from `TerrainRenderer`
2. Converts each height value to a color based on elevation
3. Creates a 256x256 RGBA texture
4. Stores as `ImageTexture` for efficient rendering

### Rendering

The terrain is drawn as the first layer in the map canvas:

```gdscript
# In _on_map_canvas_draw()
if show_terrain:
    _draw_terrain()  # Draw terrain first (background)

# Then draw other elements on top:
_draw_waypoint_and_course()
_draw_submarine_icon()
_draw_contacts()
```

### Coordinate Mapping

The terrain texture is mapped to world coordinates:

- Terrain world size: 2048m x 2048m (configurable)
- Texture resolution: 256x256 pixels
- Each pixel represents ~8m x 8m of terrain
- Scales and pans with the map view

## Usage Examples

### Toggle Terrain Programmatically

```gdscript
var tactical_map = get_node("TacticalMapView")
tactical_map.show_terrain = false  # Hide terrain
tactical_map.show_terrain = true   # Show terrain
```

### Check if Terrain is Available

```gdscript
var tactical_map = get_node("TacticalMapView")
if tactical_map.terrain_texture:
    print("Terrain visualization available")
else:
    print("Terrain not loaded")
```

### Regenerate Terrain Texture

If the terrain changes (e.g., different region selected):

```gdscript
var tactical_map = get_node("TacticalMapView")
tactical_map._generate_terrain_texture()
```

## Performance

- **Texture Generation**: One-time cost during initialization (~10-50ms)
- **Rendering**: Minimal overhead (single texture draw per frame)
- **Memory**: ~256KB for 256x256 RGBA texture
- **No impact on gameplay**: Terrain is pre-generated and cached

## Integration with Terrain System

The tactical map automatically:
1. Detects the `TerrainRenderer` node
2. Waits for terrain initialization
3. Generates the colored texture from the heightmap
4. Updates when terrain region changes

## Customization

### Change Color Palette

Edit the color definitions in `_generate_terrain_texture()`:

```gdscript
var deep_water = Color(0.05, 0.1, 0.3, 1.0)
var shallow_water = Color(0.1, 0.3, 0.5, 1.0)
# ... etc
```

### Adjust Transparency

Change the alpha value in `_draw_terrain()`:

```gdscript
map_canvas.draw_texture_rect(terrain_texture, rect, false, Color(1, 1, 1, 0.7))
#                                                                           ^^^ alpha
```

### Change Elevation Thresholds

Modify the height ranges in `_generate_terrain_texture()`:

```gdscript
if actual_height < sea_level - 100.0:
    # Deep water
elif actual_height < sea_level - 20.0:
    # Shallow water
# ... etc
```

## Testing

Run the test script to verify terrain visualization:

```bash
godot --headless --script test_tactical_map_terrain.gd
```

Or test in-game:
1. Launch the game
2. Press `1` to switch to Tactical Map view
3. Observe the terrain background
4. Press `T` to toggle terrain on/off
5. Use mouse wheel to zoom and see terrain detail

## Troubleshooting

**Terrain not visible:**
- Check that `show_terrain = true`
- Verify terrain renderer is initialized
- Ensure terrain texture was generated

**Terrain colors wrong:**
- Check heightmap loaded correctly
- Verify height range settings match terrain
- Check color palette definitions

**Terrain position offset:**
- Verify terrain size matches between renderer and tactical map
- Check coordinate conversion functions
- Ensure map center is correct

**Performance issues:**
- Reduce terrain resolution if needed
- Check texture size (256x256 is optimal)
- Disable terrain if not needed: `show_terrain = false`

## Future Enhancements

Possible improvements:
1. **Contour Lines**: Add elevation contour lines
2. **Grid Overlay**: Add coordinate grid
3. **Depth Labels**: Show depth values at key points
4. **Bathymetric Shading**: Enhanced underwater terrain visualization
5. **Dynamic LOD**: Different detail levels based on zoom
6. **Terrain Legend**: Show color-to-elevation mapping
7. **Navigation Hazards**: Highlight shallow areas dangerous for submarine
