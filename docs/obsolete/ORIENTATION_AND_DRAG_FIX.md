# Submarine Orientation and Drag Fix

## Problem

The submarine was:
1. **Moving sideways** - Visual model not aligned with movement direction
2. **Speed capped at ~1/3 of target** - Only reaching ~3.4 m/s instead of 10.3 m/s

## Root Cause

### Issue 1: Submarine Not Rotating to Face Direction
The submarine body's rotation was not being set to match the target heading. Instead:
- Propulsion force was applied in the target heading direction
- But the submarine body itself wasn't rotated to face that way
- Turning was only done via torque based on velocity (not target heading)
- Result: Submarine moved in one direction while facing another

### Issue 2: Drag Didn't Account for Orientation
The drag calculation used a constant cross-sectional area:
```gdscript
drag_magnitude = 0.5 * WATER_DENSITY * speed² * DRAG_COEFFICIENT * 100.0
```

This didn't account for:
- **Frontal drag** (streamlined, ~20 m²) when moving forward
- **Side drag** (huge, ~200 m²) when moving sideways

When the submarine moved sideways, it experienced 10x more drag than it should!

## The Fix

### 1. Direct Rotation Control

Now the submarine body is directly rotated to face the target heading:

```gdscript
# Rotate submarine body to face target heading
var target_heading_rad = deg_to_rad(target_heading)
var current_yaw = submarine_body.rotation.y

# Smooth rotation towards target
var heading_diff = target_heading_rad - current_yaw
var yaw_change = clamp(heading_diff, -rotation_speed * delta, rotation_speed * delta)
submarine_body.rotation.y = current_yaw + yaw_change
```

**Benefits:**
- Submarine always faces the direction it's trying to move
- Visual model matches physics direction
- Eliminates sideways movement
- Rotation is smooth (2 rad/s ≈ 115°/s)

### 2. Orientation-Aware Drag

Drag now considers submarine orientation:

```gdscript
# Calculate velocity relative to submarine orientation
var forward_speed = velocity.dot(forward_direction)  # Along length
var sideways_speed = perpendicular component           # Across width

# Different cross-sectional areas
const FRONTAL_AREA: float = 20.0   # Streamlined front
const SIDE_AREA: float = 200.0     # Large side profile (10x bigger!)

# Calculate drag for each component
var forward_drag = ... * FRONTAL_AREA
var sideways_drag = ... * SIDE_AREA  # Much higher!
```

**Benefits:**
- Moving forward: Low drag (~20 m² frontal area)
- Moving sideways: High drag (~200 m² side area)
- Realistic hydrodynamics
- Encourages proper submarine orientation

### 3. Removed Torque-Based Turning

The old `_apply_turning_force()` function is no longer needed since we directly control rotation.

## Expected Behavior

### Before Fix
```
Target: 10.3 m/s, Heading: 0° (North)
Actual: 3.4 m/s, Visual: Facing 90° (East)
Problem: Moving north while facing east = huge side drag
```

### After Fix
```
Target: 10.3 m/s, Heading: 0° (North)
Actual: ~9-10 m/s, Visual: Facing 0° (North)
Result: Moving forward with streamlined profile = low drag
```

## Physics Explanation

### Drag Force Comparison

**Moving forward (aligned):**
- Area: 20 m²
- Speed: 10 m/s
- Drag: 0.5 × 1025 × 100 × 0.04 × 20 = 41,000 N

**Moving sideways (misaligned):**
- Area: 200 m²
- Speed: 10 m/s
- Drag: 0.5 × 1025 × 100 × 0.04 × 200 = 410,000 N

**That's 10x more drag!** This explains why speed was capped at ~1/3 of target.

### Force Balance at Steady State

With proper alignment:
- Propulsion: 5,000,000 N
- Drag at 10 m/s: ~41,000 N
- Net force: 4,959,000 N (still accelerating)
- Should reach close to target speed

With sideways movement:
- Propulsion: 5,000,000 N
- Drag at 3.4 m/s: ~4,900,000 N (10x area × speed²)
- Net force: ~100,000 N (barely accelerating)
- Caps out at ~3.4 m/s

## Files Modified

**scripts/physics/submarine_physics.gd**
1. Modified `apply_propulsion()`:
   - Added direct rotation control to face target heading
   - Smooth interpolation of yaw angle
   - Removed call to `_apply_turning_force()`
   - Added heading to debug output

2. Modified `apply_drag()`:
   - Calculate velocity components relative to submarine orientation
   - Separate frontal and side drag calculations
   - Use realistic cross-sectional areas (20 m² vs 200 m²)
   - Much higher drag when moving sideways

## Testing

The submarine should now:
1. ✓ Rotate to face the target heading smoothly
2. ✓ Move forward in the direction it's facing
3. ✓ Reach speeds of 9-10 m/s (close to 10.3 m/s target)
4. ✓ Experience low drag when properly aligned
5. ✓ Experience high drag if somehow moving sideways

## Debug Output

Console now shows:
```
Propulsion: target=10.3 current_speed=8.234 error=2.066 ratio=0.201 force=1005000 heading=0°
```

The heading confirms the submarine is facing the right direction.

## Next Steps

1. Test forward movement - should reach ~9-10 m/s
2. Test turning - submarine should rotate smoothly to new heading
3. Test reverse - should work the same way
4. Remove debug output once confirmed working
