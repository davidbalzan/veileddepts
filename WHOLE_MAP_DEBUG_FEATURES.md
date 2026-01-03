# Whole Map View Debug Features

## Overview

Added comprehensive debug controls and sea level adjustment to the Whole Map View (Screen 4).

## Features Added

### 1. Debug Control Panel

A collapsible debug panel in the top-right corner with:

- **Sea Level Threshold Slider**
  - Range: 0.0 to 1.0
  - Step: 0.001
  - Default: 0.554
  - Real-time map recoloring when adjusted
  - Shows current value and default reference

- **Map Information Display**
  - Map dimensions (21600x10800 pixels)
  - Current zoom level
  - Tile cache usage (current/max)

- **Debug Panel Toggle Buttons**
  - "Performance" - Toggles performance monitoring panel
  - "Terrain" - Toggles terrain debug overlay

### 2. Keyboard Shortcuts

- **F3** - Toggle debug panel visibility
- **F4** - Toggle all debug panels (via DebugPanelManager)
- **F2** - Close whole map view
- **Left Click** - Teleport submarine
- **Right/Middle Click** - Pan map
- **Mouse Wheel** - Zoom in/out
- **+/=** - Zoom in
- **-** - Zoom out
- **C** - Recenter view

### 3. Sea Level Control

The sea level slider dynamically adjusts the threshold that determines what is rendered as water vs land:

- **Lower values** (< 0.554): More area appears as land
- **Higher values** (> 0.554): More area appears as water
- **Real-time updates**: Map regenerates immediately when slider changes
- **Visual feedback**: Value display updates to show current threshold

### 4. Integration with Debug System

- Properly integrated with `DebugPanelManager` autoload
- Can toggle performance and terrain debug panels
- F4 enables/disables all registered debug panels system-wide
- Debug panel uses proper z-ordering (layer 5, below console at layer 10)

## Technical Implementation

### Files Modified

- `scripts/views/whole_map_view.gd`
  - Added debug panel creation (`_create_debug_panel()`)
  - Added sea level threshold as adjustable variable
  - Added keyboard input handling for F3/F4
  - Added callback functions for slider and buttons
  - Added debug panel info updates in `_process()`
  - Integrated with DebugPanelManager

### Key Components

1. **Debug Panel UI**
   - PanelContainer with styled background
   - VBoxContainer layout
   - HSlider for sea level control
   - Labels for information display
   - Buttons for panel toggles

2. **Sea Level System**
   - `sea_level_threshold` variable (0.0-1.0)
   - `_on_sea_level_changed()` callback
   - Regenerates both overview and detail textures
   - Updates value label in real-time

3. **Debug Panel Manager Integration**
   - `_toggle_all_debug_panels()` - F4 handler
   - `_on_toggle_performance_panel()` - Performance button
   - `_on_toggle_terrain_panel()` - Terrain button
   - Proper integration with existing debug system

## Usage

### Accessing the Debug Panel

1. Press **4** to switch to Whole Map View
2. Press **F3** to show/hide the debug panel
3. Use the slider to adjust sea level threshold
4. Click buttons to toggle other debug panels
5. Press **F4** to toggle all debug panels at once

### Adjusting Sea Level

1. Open debug panel (F3)
2. Drag the "Sea Level Threshold" slider
3. Watch the map recolor in real-time
4. Lower values show more land, higher values show more water
5. Default value is 0.554 (actual Earth sea level)

### Viewing Debug Information

The debug panel shows:
- Current map size
- Current zoom level
- Number of cached tiles
- Sea level threshold value

## Visual Design

- **Panel Style**: Dark semi-transparent background with cyan border
- **Colors**: 
  - Title: Cyan (#00FFFF)
  - Labels: White
  - Values: Light gray
  - Instructions: Dark gray
- **Position**: Top-right corner, offset from edge
- **Size**: 300px wide, auto height

## Benefits

1. **Real-time Sea Level Adjustment**: Experiment with different water levels
2. **Debug Access**: Quick access to performance and terrain debug panels
3. **Information Display**: See map stats and cache usage
4. **Keyboard Shortcuts**: Fast toggle without mouse
5. **Clean UI**: Collapsible panel that doesn't obstruct the map

## Future Enhancements

Potential additions:
- Save/load sea level presets
- Color scheme selection
- Biome visualization toggle
- Mission area size adjustment
- Coordinate display
- Distance measurement tool

## Testing

To test the features:

1. Run the game: `./run_game.sh`
2. Press **4** to switch to Whole Map View
3. Press **F3** to open debug panel
4. Adjust the sea level slider and observe map changes
5. Click "Performance" and "Terrain" buttons to toggle debug overlays
6. Press **F4** to toggle all debug panels
7. Verify keyboard shortcuts work correctly

## Notes

- The sea level threshold affects only the visual representation
- Actual terrain elevation data remains unchanged
- Debug panel is hidden by default
- All debug features are non-intrusive and can be toggled off
- Integration with existing DebugPanelManager ensures consistency
