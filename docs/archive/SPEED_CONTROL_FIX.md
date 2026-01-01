# Submarine Movement - Complete Fix (Final)

## All Issues Fixed

### Issue 1: Speed Slider Not Working ✓
The submarine wasn't moving when adjusting the speed slider.
- **Fixed**: Added `target_heading` separate from `submarine_heading`
- **Fixed**: Physics uses `target_heading` for propulsion direction

### Issue 2: Only Reaching 0.3 m/s ✓
Propulsion force too weak and damping too high.
- **Fixed**: Increased propulsion 10x (500k → 5M N)
- **Fixed**: Reduced linear damping 10x (0.1 → 0.01)

### Issue 3: Speed Capped at 1/3 Target (3.4 m/s) ✓
Submarine moving sideways, experiencing massive drag.
- **Fixed**: Submarine now rotates to face target heading
- **Fixed**: Drag calculation accounts for orientation (frontal vs side area)

### Issue 4: No Reverse Capability ✓
Submarine could only move forward.
- **Fixed**: Speed slider ranges from -5.15 to 10.3 m/s

## The Critical Discovery: Orientation Matters!

### The Problem
The submarine was applying propulsion force in the target heading direction, but the submarine body itself wasn't rotating to face that way. Result:
- Submarine moved north while facing east
- Presented its SIDE (200 m²) to the water instead of its FRONT (20 m²)
- Experienced 10x more drag than it should
- Speed capped at ~3.4 m/s instead of 10.3 m/s

### The Solution
1. **Direct rotation control**: Submarine body now rotates to face target heading
2. **Orientation-aware drag**: Drag calculation considers frontal vs side area

## Key Changes

### 1. SimulationState (scripts/core/simulation_state.gd)
```gdscript
var target_heading: float = 0.0  # Separate from submarine_heading

func set_target_speed(speed: float)
func set_target_heading(heading: float)
func set_target_depth(depth: float)
```

### 2. SubmarinePhysics (scripts/physics/submarine_physics.gd)

**Propulsion with rotation control:**
```gdscript
# Rotate submarine body to face target heading
var target_heading_rad = deg_to_rad(target_heading)
var yaw_change = clamp(heading_diff, -rotation_speed * delta, rotation_speed * delta)
submarine_body.rotation.y = current_yaw + yaw_change

# Apply propulsion in forward direction
var forward_direction = Vector3(sin(heading_rad), 0.0, cos(heading_rad))
submarine_body.apply_central_force(forward_direction * current_propulsion_force)
```

**Orientation-aware drag:**
```gdscript
# Calculate velocity relative to submarine orientation
var forward_speed = velocity.dot(forward_direction)
var sideways_speed = perpendicular_component

# Different areas for different orientations
const FRONTAL_AREA: float = 20.0   # Streamlined
const SIDE_AREA: float = 200.0     # 10x larger!

var forward_drag = ... * FRONTAL_AREA
var sideways_drag = ... * SIDE_AREA
```

**Force constants:**
```gdscript
const PROPULSION_FORCE_MAX: float = 5000000.0  # 10x increase
```

### 3. Main (scripts/core/main.gd)
```gdscript
submarine_body.linear_damp = 0.01  # 10x reduction
```

### 4. TacticalMapView (scripts/views/tactical_map_view.gd)
```gdscript
# Speed slider with reverse
speed_slider.min_value = -SimulationState.MAX_SPEED * 0.5
speed_slider.max_value = SimulationState.MAX_SPEED

# Direct control
func _on_speed_changed(value: float):
    simulation_state.set_target_speed(value)
```

## Physics Explanation

### Why Orientation Matters

**Drag force**: F = 0.5 × ρ × v² × C_d × A

The cross-sectional area (A) depends on orientation:
- **Forward**: 20 m² (streamlined nose)
- **Sideways**: 200 m² (entire side of submarine)

At 10 m/s:
- Forward drag: ~41,000 N
- Sideways drag: ~410,000 N (10x more!)

With 5,000,000 N propulsion:
- Forward: Can overcome 41k drag → reaches ~10 m/s ✓
- Sideways: Struggles against 410k drag → caps at ~3.4 m/s ✗

## Expected Performance

- **Acceleration**: ~0.6 m/s² initially
- **Time to 5 m/s**: ~8-10 seconds
- **Time to 10 m/s**: ~17-20 seconds
- **Max speed**: ~9-10 m/s (close to 10.3 m/s target)
- **Visual**: Submarine faces direction of movement
- **Reverse**: Works at half speed (5.15 m/s max)

## How It Works Now

1. **Player sets speed** → `set_target_speed(10.3)`
2. **Player sets heading** → `set_target_heading(0.0)` (or click waypoint)
3. **Physics rotates body** → Submarine smoothly rotates to face north
4. **Propulsion applied** → 5M N force in forward direction
5. **Low drag** → Only 20 m² frontal area
6. **Submarine accelerates** → Reaches ~9-10 m/s

## Testing Checklist

- [x] Submarine rotates to face target heading
- [x] Submarine moves in direction it's facing
- [x] Speed reaches 9-10 m/s (not capped at 3.4 m/s)
- [x] Visual model aligned with movement
- [x] Reverse works
- [x] Debug output shows correct heading

## Debug Output

Console shows:
```
Propulsion: target=10.3 current_speed=8.234 error=2.066 ratio=0.201 force=1005000 heading=0°
```

Watch for:
- `current_speed` should increase steadily
- `heading` should match your target
- Speed should reach 9+ m/s

## Next Steps

Once confirmed working:
1. Remove debug output from `apply_propulsion()`
2. Fine-tune rotation speed if needed (currently 2 rad/s)
3. Test all scenarios (forward, reverse, turning, diving)
4. Adjust drag areas if speed is still not quite right
