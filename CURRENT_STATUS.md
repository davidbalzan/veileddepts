# Tactical Submarine Simulator - Current Status

## What's Working ✅

### Core Systems
1. **Speed Control**: Submarine reaches full 10.3 m/s
2. **Coordinate System**: Consistent -Z = North across all systems
3. **View Switching**: Can switch between tactical map (1), periscope (2), and external (3)
4. **Waypoint System**: Click to set waypoints, calculates correct heading
5. **Camera Following**: All cameras track submarine position
6. **Model Visibility**: Submarine model visible from all views
7. **Physics Integration**: Visual model IS the physics body (no desync)

### Physics
- **Propulsion**: Pushes along submarine's longitudinal axis
- **Drag**: Forward and sideways drag implemented
- **Buoyancy**: Wave-based buoyancy forces
- **Axis Locking**: Pitch and roll locked (yaw only)

### Views
- **Tactical Map**: 2D top-down with submarine icon, waypoints, compass
- **Periscope**: First-person view from mast with camera smoothing
- **External**: Third-person view positioned in front of submarine

## Current Issues ❌

### 1. Steering/Turning
**Status**: Inconsistent behavior
- Sometimes turns too fast (spins)
- Sometimes doesn't turn at all (slides sideways)
- Difficult to find stable torque/damping balance

**Current Settings**:
- Torque multiplier: 5000
- Max torque: 1 trillion N⋅m
- Angular damping: 0.5
- Mass: 8 million kg

### 2. Lateral Movement
**Problem**: Submarine slides sideways instead of turning first
**Cause**: Body rotation not keeping up with velocity direction
**Attempted Fix**: High sideways drag (100x forward drag)

## Key Files

### Physics
- `scripts/physics/submarine_physics.gd` - Propulsion, drag, steering torque
- `scripts/core/main.gd` - Submarine body initialization
- `scenes/main.tscn` - SubmarineModel RigidBody3D properties

### Views
- `scripts/views/tactical_map_view.gd` - 2D map with camera following
- `scripts/views/periscope_view.gd` - First-person with smoothing
- `scripts/views/external_view.gd` - Third-person camera

### State
- `scripts/core/simulation_state.gd` - Submarine state, waypoint handling
- `scripts/core/view_manager.gd` - View switching

## Physics Parameters to Tune

### For Faster Turning
- Increase torque multiplier (currently 5000)
- Decrease angular damping (currently 0.5)
- Risk: Oscillation and spinning

### For Stable Turning
- Decrease torque multiplier
- Increase angular damping
- Risk: Slow turning, lateral sliding

### Sweet Spot (Unknown)
Need to find balance where:
- Submarine turns at 3-10°/second
- No oscillation or spinning
- Minimal lateral sliding
- Body rotation matches velocity direction

## Next Steps

1. **Add visual debug**: Draw velocity vector vs body direction on map
2. **Measure turn rate**: Log actual degrees/second achieved
3. **Test different combinations**: Systematically try torque/damping pairs
4. **Consider PID controller**: Add integral/derivative terms for better control
5. **Alternative: Direct rotation**: Set rotation directly (arcade style) if physics approach fails

## User Controls

### Tactical Map (View 1)
- Left click: Set waypoint
- Mouse wheel: Zoom
- W/S: Speed up/down
- Q/E: Depth up/down
- Tab/1/2/3: Switch views

### Periscope (View 2)
- Right mouse drag: Rotate periscope
- Mouse wheel: Zoom

### External (View 3)
- Camera positioned in front of submarine
- Follows submarine movement

## Performance
- Speed: 10.3 m/s achieved ✅
- Frame rate: Should be 60+ FPS
- Physics: 60 Hz fixed timestep
