# S-Curve Depth Control System

## Overview
The submarine now uses a sophisticated S-curve profile for depth changes, providing smooth and realistic ascent/descent behavior.

## Control Phases

### Phase 1: Smooth Start (Acceleration)
- **Distance**: First 30% of total depth change (max 50m)
- **Behavior**: Gradually builds pitch angle using cubic easing
- **Plane Angle**: Starts at 0°, smoothly increases to target pitch (12°)
- **Purpose**: Prevents jarring motion at dive start

### Phase 2: Active Dive (Cruise)
- **Distance**: Middle 30% of depth change
- **Behavior**: Maintains steady pitch angle
- **Plane Angle**: Constant at 12° (nose down for descent, nose up for ascent)
- **Purpose**: Efficient depth change at consistent rate

### Phase 3: Approach (Deceleration)
- **Distance**: Last 40% of depth change (max 75m)
- **Behavior**: Gradually reduces pitch back toward level
- **Plane Angle**: Decreases from 12° to 0°
- **Purpose**: Prepares for smooth arrival at target depth

### Phase 4: Final Entry (Counter-Pitch)
- **Distance**: Last 20m before target
- **Behavior**: Applies counter-pitch to arrest vertical velocity
- **Plane Angle**: Pitches opposite to motion (5° opposite direction)
- **Purpose**: Smooth settling at target depth without overshoot

## Special Features

### Surfacing (Target Depth = 0m)
1. **Initial Descent**: When deeper than 25m, target 25m first
2. **Final Approach**: Once at 25m, use gentle 3° pitch for final surface approach
3. **Safety**: Prevents rapid broaching and maintains control near surface

### Predictive Control
- Looks ahead 3 seconds based on current velocity
- Detects potential overshoot and applies early corrections
- Adjusts phase transitions based on predicted position

### Dynamic Phase Sizing
- Phase distances scale with total depth change
- Small depth changes (<50m): Tighter control zones
- Large depth changes (>200m): Extended cruise phase for efficiency

## Control Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Target Pitch (Cruise) | 12° | Pitch angle during active dive phase |
| Target Pitch (Surface Approach) | 3° | Gentle pitch for final surface approach |
| Counter-Pitch Strength | 5° | Maximum counter-pitch during Phase 4 |
| Acceleration Zone | 30% / 50m max | Distance for pitch ramp-up |
| Deceleration Zone | 40% / 75m max | Distance for pitch ramp-down |
| Counter-Pitch Zone | 20m | Distance for final entry correction |
| Surface Approach Depth | 25m | Intermediate target when surfacing |

## Benefits

1. **Smooth Operation**: No abrupt pitch changes
2. **Overshoot Prevention**: Predictive control and counter-pitch
3. **Safe Surfacing**: Two-stage approach prevents broaching
4. **Natural Feel**: Mimics real submarine diving procedures
5. **Efficient**: Maintains good vertical velocity during cruise phase

## Technical Implementation

Located in: [dive_plane_system.gd](../scripts/physics/dive_plane_system.gd)

The S-curve is achieved through:
- Distance-based phase detection
- Cubic easing for smooth transitions (Phase 1)
- Linear interpolation for deceleration (Phase 3)
- Velocity-based counter-pitch (Phase 4)
- Special surfacing logic with intermediate waypoint

## Testing

To test the S-curve behavior:
1. Set a target depth significantly different from current (e.g., 200m change)
2. Observe pitch angle changes during the dive
3. Watch for smooth acceleration, steady cruise, and gentle arrival
4. Try surfacing from 100m+ depth to see two-stage approach
