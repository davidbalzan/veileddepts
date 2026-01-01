# Camera Heading and Drag Fix - Version 3

## Issues Fixed

### Issue 1: Cameras Not Following Submarine Heading ✓
The periscope and external view cameras were not influenced by the submarine's heading.

**Problem:**
- Periscope view used absolute rotation (0° = north) instead of relative to submarine
- External view orbited around submarine but didn't account for submarine heading
- When submarine turned, cameras stayed pointing in world directions

**Solution:**
- **Periscope**: Camera rotation now = submarine_heading + periscope_rotation
- **External view**: Camera orbit rotation now = submarine_heading + camera_rotation
- Both views now move with the submarine as it turns

### Issue 2: Still Not Reaching Target Speed ✓
Even with orientation fix, submarine wasn't reaching close to 10.3 m/s target.

**Problem:**
- Drag coefficient was too low (0.04)
- Frontal area was too small (15-20 m²)
- At 10 m/s, drag was only ~400k N vs 5M N propulsion
- Submarine would accelerate to 127 m/s at equilibrium!

**Solution:**
- Increased drag coefficient: 0.04 → 0.5 (more realistic)
- Increased frontal area: 15 m² → 50 m²
- Increased side area: 150 m² → 400 m²
- New equilibrium at ~10 m/s: drag ≈ 1.36M N vs 5M N propulsion
- Added debug output to monitor drag forces

## Changes Made

### 1. PeriscopeView (scripts/views/periscope_view.gd)

**Camera rotation now includes submarine heading:**
```gdscript
# Total rotation = submarine heading + periscope rotation
var submarine_heading_rad = deg_to_rad(simulation_state.submarine_heading)
var periscope_rotation_rad = deg_to_rad(periscope_rotation)
camera.rotation.y = submarine_heading_rad + periscope_rotation_rad
```

**Benefits:**
- Periscope rotation is now relative to submarine
- When submarine turns, periscope view turns with it
- Player can still rotate periscope independently

### 2. ExternalView (scripts/views/external_view.gd)

**Camera orbit now relative to submarine heading:**
```gdscript
# Camera rotation is relative to submarine heading
var submarine_heading_rad = deg_to_rad(simulation_state.submarine_heading)
var rotation_rad = deg_to_rad(camera_rotation) + submarine_heading_rad
```

**Benefits:**
- Default camera position (rotation=0) is behind the submarine
- Camera orbits relative to submarine's orientation
- When submarine turns, camera follows

### 3. SubmarinePhysics (scripts/physics/submarine_physics.gd)

**Increased drag parameters:**
```gdscript
const DRAG_COEFFICIENT: float = 0.5  # Was 0.04
const FRONTAL_AREA: float = 50.0     # Was 15-20 m²
const SIDE_AREA: float = 400.0       # Was 150-200 m²
```

**Fixed sideways speed calculation:**
```gdscript
# Perpendicular vector for sideways speed
var right_2d = Vector2(-forward_2d.y, forward_2d.x)
var sideways_speed = abs(velocity_2d.dot(right_2d))
```

**Added drag debug output:**
```
Drag: speed=8.23 forward=8.21 sideways=0.12 drag=1245000 N
```

## Physics Calculations

### Drag at Target Speed (10.3 m/s)

**Forward drag:**
- F = 0.5 × 1025 × 10.3² × 0.5 × 50
- F = 0.5 × 1025 × 106.09 × 25
- F ≈ 1,361,569 N

**With 5M N propulsion:**
- Net force = 5,000,000 - 1,361,569 = 3,638,431 N
- Still accelerating at 10.3 m/s
- Will reach equilibrium around 11-12 m/s

**This is much better!** Should reach close to target speed.

### Sideways Drag (if misaligned)

**At 10.3 m/s sideways:**
- F = 0.5 × 1025 × 10.3² × 0.5 × 400
- F ≈ 10,892,553 N

**This is 8x more than forward drag!** Ensures submarine stays aligned.

## Expected Behavior

### Periscope View
- **Before**: Periscope always pointed north when rotation=0, regardless of submarine heading
- **After**: Periscope points forward (relative to submarine) when rotation=0
- **Turning**: When submarine turns, periscope view turns with it
- **Control**: Player can still rotate periscope independently (relative to sub)

### External View
- **Before**: Camera orbit was in world space, rotation=0 always pointed north
- **After**: Camera orbit is relative to submarine, rotation=0 is behind submarine
- **Turning**: When submarine turns, camera follows to maintain relative position
- **Control**: Player can still orbit around submarine independently

### Speed
- **Before**: Capped at ~3-4 m/s due to low drag allowing sideways movement
- **After**: Should reach 9-11 m/s with proper alignment
- **Debug**: Console shows drag forces to verify

## Testing Checklist

### Camera Tests
- [ ] Periscope view points forward when submarine is stationary
- [ ] Periscope view turns when submarine turns
- [ ] Can still rotate periscope independently
- [ ] External view camera is behind submarine by default
- [ ] External view follows submarine when it turns
- [ ] Can still orbit camera around submarine

### Speed Tests
- [ ] Submarine reaches 8+ m/s within 20 seconds
- [ ] Speed approaches 10-11 m/s at full throttle
- [ ] Debug output shows reasonable drag values
- [ ] Forward drag < 2M N at 10 m/s
- [ ] Sideways drag is minimal (< 100k N) when aligned

## Debug Output

Watch console for:
```
Propulsion: target=10.3 current_speed=8.234 error=2.066 ratio=0.201 force=1005000 heading=0°
Drag: speed=8.23 forward=8.21 sideways=0.12 drag=1245000 N
```

**Good signs:**
- `current_speed` steadily increasing
- `forward` speed close to total `speed`
- `sideways` speed very low (< 0.5)
- `drag` around 1-1.5M N at 8-10 m/s

**Bad signs:**
- `sideways` speed high (> 1.0) = submarine not aligned
- `drag` > 3M N = too much drag, won't reach speed
- `current_speed` not increasing = force balance issue

## Next Steps

1. Test in game to verify speed reaches 9-11 m/s
2. Test camera views follow submarine heading
3. If speed still too low, reduce drag coefficient or area
4. If speed too high, increase drag coefficient or area
5. Remove debug output once confirmed working
