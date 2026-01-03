# Keyboard Controls

## View Switching

- **Tab**: Cycle through views (Tactical Map -> Periscope -> External -> Tactical Map)
- **1**: Tactical Map view
- **2**: Periscope view
- **3**: External view
- **4**: World Map view (press again to return to Tactical Map)

## Submarine Controls (Available in All Views)

### Speed Control

- **W** or **Up Arrow**: Increase speed by 1.0 m/s
- **S** or **Down Arrow**: Decrease speed by 1.0 m/s
- **Space**: Emergency stop (set speed to 0)

Speed range: -5.15 m/s (reverse) to 10.3 m/s (forward)

### Heading Control

- **A** or **Left Arrow**: Turn left (port) by 5°
- **D** or **Right Arrow**: Turn right (starboard) by 5°

Heading range: 0° to 360° (0° = North, 90° = East, 180° = South, 270° = West)

### Depth Control

- **Q**: Decrease depth (go shallower) by 5m
- **E**: Increase depth (go deeper) by 5m

Depth range: 0 to 400 m

## Debug and Settings

- **F3**: Toggle debug panel (performance stats, submarine info)
- **F4**: Open input configuration UI (rebind keys)
- **F5**: Toggle terrain debug overlay

## Tactical Map View (Screen 1)

- **Left Click**: Set waypoint
- **Mouse Wheel**: Zoom in/out
- **Middle Mouse Drag**: Pan map
- **Speed Slider**: Adjust speed (-5.15 to 10.3 m/s)
- **Depth Slider**: Adjust depth (0 to 400 m)

## Periscope View (Screen 2)

- **Right Mouse Drag**: Rotate periscope (horizontal and vertical)
- **Mouse Wheel**: Zoom in/out (15° to 90° FOV)

## External View (Screen 3)

- **Right Mouse Drag**: Orbit camera around submarine
- **Middle Mouse Drag** or **Shift + Right Mouse Drag**: Adjust camera tilt
- **Mouse Wheel**: Adjust camera distance (10m to 500m)
- **F**: Toggle free camera mode

### Free Camera Mode (External View)

- **W/A/S/D**: Move camera horizontally
- **Q**: Move camera down
- **E**: Move camera up

## World Map View (Screen 4)

- **Left Click**: Teleport submarine to clicked location (shifts mission area)
- **Right Click + Drag** or **Middle Click + Drag**: Pan map
- **Mouse Wheel**: Zoom in/out
- **+** or **=**: Zoom in
- **-**: Zoom out
- **C**: Recenter map (reset zoom and pan)

The world map shows elevation data. Hover to see elevation at cursor.
- Blue areas: Ocean (below sea level)
- Green/Brown areas: Land (above sea level)

## Input Customization

Press **F4** to open the input configuration UI where you can rebind any key.
- Click on a binding to start remapping
- Press the new key to assign it
- Press **Escape** to cancel remapping
- Click "Reset to Defaults" to restore default bindings

Custom bindings are saved to `user://input_config.cfg`.

## Tips

1. **Quick maneuvering**: Use keyboard for rapid speed/heading changes
2. **Precise control**: Use sliders in Tactical Map for exact values
3. **Emergency situations**: Press Space to stop immediately
4. **Smooth turns**: Hold A or D to continuously turn
5. **Speed increments**: Each press changes speed by 1 m/s
6. **Heading increments**: Each press changes heading by 5°
7. **Find land**: Use World Map (4) to zoom in near coastlines, then teleport there
8. **Debug issues**: Press F3 to see performance stats and submarine state

## Examples

### Quick Start
1. Press **W** 5 times to reach 5 m/s
2. Press **D** 18 times to turn to 90° (East)
3. Submarine will move east at 5 m/s

### Emergency Stop
1. Press **Space** to immediately set speed to 0
2. Submarine will coast to a stop

### Reverse Maneuver
1. Press **S** repeatedly to go into reverse
2. Press **A** or **D** to turn while reversing
3. Press **Space** to stop

### View Switching
1. Press **Tab** to cycle through views
2. Or press **1**, **2**, **3**, or **4** for specific views

### Navigate to Land
1. Press **4** to open World Map
2. Use **+** to zoom in near a coastline
3. **Left Click** to teleport there
4. Press **4** again to return to Tactical Map
5. Press **3** for External view to see terrain
