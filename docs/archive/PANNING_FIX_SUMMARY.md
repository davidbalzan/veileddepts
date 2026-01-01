# Panning Fix Summary

## Problem

The map panning was moving the entire canvas instead of properly panning the view. When dragging with middle or right mouse button, the whole UI would shift instead of the map content scrolling.

## Root Cause

The coordinate conversion functions (`world_to_screen` and `screen_to_world`) were using absolute world coordinates instead of relative coordinates from the submarine. This caused the entire canvas to shift when pan offset was applied, rather than just shifting the view of the world.

## Solution

Changed the coordinate system to be **submarine-relative**:

### Before (Absolute Coordinates)
```gdscript
# World position → Screen position
var screen_pos = world_pos * map_scale * map_zoom
screen_pos += map_center + map_pan_offset
```

This made the submarine move around the screen when panning.

### After (Relative Coordinates)
```gdscript
# Calculate position relative to submarine
var relative_pos = Vector2(world_pos.x - sub_pos.x, world_pos.z - sub_pos.z)

# Convert to screen space
var screen_offset = relative_pos * map_scale * map_zoom

# Apply to screen center with pan offset
return map_center + screen_offset + map_pan_offset
```

This keeps the submarine at the center and pans the world around it.

## Changes Made

### scripts/views/tactical_map_view.gd

**Modified Functions:**

1. **`world_to_screen()`**
   - Now calculates position relative to submarine
   - Submarine always appears at screen center + pan offset
   - Pan offset shifts the view, not the submarine

2. **`screen_to_world()`**
   - Converts screen position back to world coordinates
   - Accounts for submarine position as reference
   - Properly handles pan offset

3. **`_update_camera_position()`**
   - Simplified to do nothing (camera not needed)
   - Panning is now handled by coordinate conversion

4. **`_draw_terrain()`**
   - Added simulation_state check
   - Uses updated coordinate conversion

## How It Works Now

### Default View (No Panning)
- Submarine is always at screen center (960, 540)
- World coordinates are converted relative to submarine
- Terrain and contacts are positioned relative to submarine

### With Panning
- Pan offset shifts the entire view
- Submarine moves on screen by pan offset amount
- All world elements move together
- Dragging feels natural - like moving a camera

### Example
```
Submarine at world (0, 0, 0)
Pan offset (100, 50)

Submarine screen position: (960, 540) + (100, 50) = (1060, 590)
Point 200m east: (1060 + 100, 590) = (1160, 590)
Point 200m north: (1060, 590 - 100) = (1060, 490)
```

## Test Results

All tests passing ✅

```
✓ Submarine is at screen center (no pan)
✓ North point is above center (correct orientation)
✓ Pan offset applied correctly
✓ Terrain moves with pan offset
✓ Screen to world conversion correct
✓ Round trip conversion accurate (0.0m error)
```

## Benefits

1. **Natural Panning**: Dragging feels like moving a camera
2. **Submarine Centered**: Submarine stays at center by default
3. **Consistent Movement**: All elements pan together
4. **Accurate Conversion**: Round-trip conversion has zero error
5. **Smooth Experience**: No canvas jumping or shifting

## User Experience

### Before Fix
- Dragging would shift the entire UI
- Submarine would jump around
- Terrain and icons would separate
- Confusing and disorienting

### After Fix
- Dragging smoothly pans the view
- Submarine stays centered (or moves with pan)
- All elements move together
- Natural map exploration

## Usage

### Pan the Map
1. Click and hold middle or right mouse button
2. Drag to pan the view
3. Release to stop panning
4. Submarine moves on screen, world pans around it

### Recenter
1. Press `C` key or click "Center on Sub" button
2. Pan offset resets to zero
3. Submarine returns to screen center
4. Zoom resets to 1.0x

### Zoom While Panned
1. Pan to desired location
2. Use mouse wheel to zoom
3. Zoom centers on current view
4. Pan offset is preserved

## Technical Details

### Coordinate System

**World Space:**
- Origin at (0, 0, 0)
- X: East (+) / West (-)
- Z: South (+) / North (-)
- Y: Up (+) / Down (-) [ignored in 2D map]

**Screen Space:**
- Origin at top-left (0, 0)
- X: Right (+) / Left (-)
- Y: Down (+) / Up (-)
- Center at (960, 540) for 1920x1080

**Submarine-Relative:**
- Submarine is reference point
- All positions calculated relative to submarine
- Submarine appears at screen center + pan offset

### Conversion Formula

**World to Screen:**
```gdscript
relative = world_pos - submarine_pos
screen = center + (relative * scale * zoom) + pan_offset
```

**Screen to World:**
```gdscript
screen_offset = screen - center - pan_offset
relative = screen_offset / (scale * zoom)
world = submarine_pos + relative
```

## Compatibility

- Works with all zoom levels (0.1x to 10.0x)
- Compatible with terrain visualization
- Works with waypoint placement
- Contact icons pan correctly
- Course lines pan correctly

## Performance

- No performance impact
- Same number of calculations
- No additional memory usage
- Smooth at all zoom levels

## Future Enhancements

Possible improvements:
1. **Momentum Panning**: Continue panning after release
2. **Pan Limits**: Prevent panning too far from submarine
3. **Minimap**: Show panned area on minimap
4. **Pan Animation**: Smooth transition when recentering
5. **Touch Support**: Two-finger pan for touch screens

## Testing

Run the panning test:
```bash
godot --headless --script test_panning.gd
```

Or test in-game:
1. Launch game
2. Press `1` for Tactical Map
3. Right-click and drag to pan
4. Verify smooth panning
5. Press `C` to recenter
6. Try zooming while panned

## Documentation

- `TACTICAL_MAP_ENHANCEMENTS.md` - Map enhancements overview
- `TACTICAL_MAP_TERRAIN.md` - Terrain visualization
- `PANNING_FIX_SUMMARY.md` - This document
