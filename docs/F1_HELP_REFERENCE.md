# F1 Help Screen Reference

## Overview

The F1 help screen provides a comprehensive guide to all keyboard shortcuts and controls available in the Tactical Submarine Simulator. This document describes the help system and all available controls.

## Accessing Help

- **F1**: Toggle help screen (available in all views)
- **ESC**: Close help screen

## View Controls

| Key | Action | Description |
|-----|--------|-------------|
| **1** | Switch to Tactical Map View | Top-down strategic view with map |
| **2** | Switch to Periscope View | First-person periscope view |
| **3** | Switch to External View | Third-person camera view |
| **Tab** | Cycle Views | Cycle through all available views |
| **F1** | Toggle Help Screen | Show/hide this help overlay |
| **F2** | Toggle Terrain Debug Overlay | Show/hide terrain streaming debug info |
| **T** | Toggle Terrain Visibility | Show/hide terrain on tactical map |

## Map Navigation (Tactical Map View)

| Control | Action | Description |
|---------|--------|-------------|
| **Mouse Wheel Up** | Zoom In | Zoom range: 0.1x to 10x |
| **Mouse Wheel Down** | Zoom Out | Zoom range: 0.1x to 10x |
| **Middle Mouse + Drag** | Pan Map | Move the map view |
| **Right Mouse + Drag** | Pan Map (Alt) | Alternative pan control |
| **C** | Recenter | Center map on submarine |
| **Left Click** | Set Waypoint | Set course waypoint for submarine |

## Submarine Speed Control

| Key | Action | Range |
|-----|--------|-------|
| **W** or **↑** | Increase Speed | -7.5 to 15 m/s |
| **S** or **↓** | Decrease Speed | -7.5 to 15 m/s |
| **Space** | Emergency Stop | Set speed to 0 m/s |
| **Speed Slider** | Direct Control | Precise speed adjustment |

## Submarine Heading Control

| Key | Action | Description |
|-----|--------|-------------|
| **A** or **←** | Turn Left (Port) | Rotate submarine counter-clockwise |
| **D** or **→** | Turn Right (Starboard) | Rotate submarine clockwise |
| **Left Click Map** | Set Course | Submarine turns toward waypoint |

## Submarine Depth Control

| Key | Action | Range |
|-----|--------|-------|
| **Q** | Decrease Depth (Shallower) | -300 to 0 meters |
| **E** | Increase Depth (Deeper) | -300 to 0 meters |
| **Depth Slider** | Direct Control | Precise depth adjustment |

## Map Display Legend

### Water Depths
- **Dark Blue**: Deep water (> 100m depth)
- **Medium Blue**: Shallow water (20-100m depth)
- **Light Blue**: Very shallow water (< 20m depth)

### Land Features
- **Sandy Color**: Beach/Coastline
- **Green**: Low elevation land
- **Brown**: Higher elevation land
- **Gray**: Mountains

### Tactical Symbols
- **Green Triangle**: Your submarine (points in heading direction)
- **Cyan Circle**: Active waypoint
- **Yellow Line**: Course line to waypoint
- **Red/Orange Circles**: Detected contacts (enemy/neutral)

## Periscope View Controls

| Control | Action | Description |
|---------|--------|-------------|
| **Mouse Move** | Look Around | Rotate periscope view |
| **Mouse Wheel** | Zoom | Adjust periscope magnification |
| **Right Click + Drag** | Pitch Control | Adjust vertical angle |

## External View Controls

| Control | Action | Description |
|---------|--------|-------------|
| **Mouse Move** | Rotate Camera | Orbit around submarine |
| **Mouse Wheel** | Zoom In/Out | Adjust camera distance |
| **Shift + Mouse** | Tilt Camera | Adjust camera pitch |
| **F** | Toggle Free Camera | Switch between orbit and free camera |

## Terrain Debug Overlay (F2)

When enabled, the terrain debug overlay shows:

- **Loaded Chunks**: Visual boundaries of loaded terrain chunks
- **Chunk Coordinates**: Grid coordinates for each chunk
- **LOD Levels**: Color-coded level of detail for each chunk
- **Memory Usage**: Current terrain system memory consumption
- **Performance Metrics**: Frame time and chunk loading statistics
- **Streaming Status**: Active chunk loading/unloading operations

### Debug Overlay Colors
- **Green**: LOD 0 (Highest detail)
- **Yellow**: LOD 1 (High detail)
- **Orange**: LOD 2 (Medium detail)
- **Red**: LOD 3 (Low detail)

## Coordinate System

The simulator uses a standard navigation coordinate system:

- **North**: 0° (heading)
- **East**: 90° (heading)
- **South**: 180° (heading)
- **West**: 270° (heading)

### World Coordinates
- **+X**: East
- **-X**: West
- **+Y**: Up (above sea level)
- **-Y**: Down (depth below sea level)
- **+Z**: South
- **-Z**: North

## Tips and Best Practices

### Navigation
1. Use the tactical map for strategic planning
2. Set waypoints by clicking on the map
3. Monitor your depth to avoid terrain collision
4. Use the compass to maintain course

### Speed Management
1. Higher speeds reduce maneuverability
2. Emergency stop (Space) for quick deceleration
3. Negative speeds allow reverse movement
4. Optimal cruise speed: 5-10 m/s

### Depth Control
1. Stay below periscope depth (-10m) to avoid detection
2. Monitor terrain depth to avoid grounding
3. Deeper depths provide better concealment
4. Shallow depths allow periscope use

### Terrain System
1. Press T to toggle terrain visibility on tactical map
2. Press F2 to see terrain streaming debug info
3. Terrain loads dynamically as you move
4. LOD system maintains performance at all distances

## Troubleshooting

### Map Not Showing Terrain
- Press **T** to ensure terrain visibility is enabled
- Check that terrain renderer is initialized (F2 debug overlay)
- Terrain generates dynamically - may take a moment to load

### Debug Overlay Not Visible
- Ensure F2 was pressed to enable it
- Check that terrain renderer has debug overlay enabled
- Debug overlay only shows when terrain system is active

### Performance Issues
- Press F2 to check memory usage and frame time
- Reduce LOD distance if performance is poor
- Check chunk loading statistics in debug overlay

## Additional Resources

- **Keyboard Controls**: See `docs/KEYBOARD_CONTROLS.md`
- **Submarine Controls**: See `docs/SUBMARINE_CONTROLS.md`
- **Terrain System**: See `docs/TERRAIN_SYSTEM.md`
- **Debug Overlay**: See `docs/DEBUG_OVERLAY_USAGE.md`

---

**Note**: This help screen is context-sensitive and shows controls relevant to the current view. Some controls may only be available in specific views.
