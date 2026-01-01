# Force Diagnosis - Finding the Speed Limiter

## Problem

Submarine consistently maxes out at 3.6 m/s instead of reaching 10.3 m/s target, despite:
- 5,000,000 N propulsion force
- Proper alignment (low sideways drag)
- Reasonable drag coefficient

This indicates a force equilibrium at 3.6 m/s that we haven't identified.

## Force Analysis at 3.6 m/s

### Expected Forces

**Propulsion (should be high):**
- Speed error = 10.3 - 3.6 = 6.7 m/s
- Propulsion ratio = 6.7 / 10.3 = 0.65
- Force ≈ 0.65 × 5,000,000 = **3,250,000 N forward**

**Drag (forward, aligned):**
- F = 0.5 × 1025 × 3.6² × 0.5 × 50
- F = 0.5 × 1025 × 12.96 × 25
- F ≈ **166,410 N backward**

**Linear damping (RigidBody3D):**
- F = velocity × linear_damp × mass
- F = 3.6 × 0.01 × 8,000,000
- F ≈ **288,000 N backward**

**Total expected:**
- Forward: 3,250,000 N
- Backward: 166,410 + 288,000 = 454,410 N
- Net: 2,795,590 N forward
- **Should still be accelerating!**

### Missing Force

There's approximately **2.8M N** of opposing force we haven't accounted for!

## Suspects

### 1. Depth Control System (MOST LIKELY)

The depth control applies:
```gdscript
const BALLAST_FORCE_MAX: float = 50000000.0  // 50 MILLION Newtons!
```

Even with PID control limiting this, if there's any depth error or the submarine is pitching, this could create massive forces.

Also applies:
```gdscript
var damping_force = -vertical_velocity * 80000.0
```

If the submarine has any vertical velocity component, this creates 80k N per m/s.

### 2. Buoyancy System

Applies spring forces at surface:
```gdscript
var spring_constant = 80000.0 * wave_influence
var damping = 60000.0 * wave_influence
```

If wave_influence is high and there's surface error, could create large forces.

### 3. Wave Motion

Applies torques for pitch/roll which could indirectly affect horizontal movement through coupling.

## Diagnostic Approach

### Test 1: Disable Depth Control

**Change made:**
```gdscript
func update_physics(delta: float) -> void:
    apply_buoyancy(delta)
    apply_drag(delta)
    apply_propulsion(delta)
    // apply_depth_control(delta)  // DISABLED
```

**Expected result:**
- If speed increases significantly → depth control is the culprit
- If speed stays at 3.6 m/s → problem is elsewhere

### Test 2: Force Logging

**Added comprehensive logging:**
```gdscript
print("Forces: speed=%.2f buoy=%.0f drag=%.0f prop=%.0f")
```

This shows the actual force contribution from each system.

## Next Steps

1. **Run the game** with depth control disabled
2. **Check console output** for force values
3. **Observe speed** - does it reach 8-10 m/s now?

### If Speed Improves:
- Depth control is the problem
- Need to reduce BALLAST_FORCE_MAX or improve PID tuning
- May need to separate horizontal and vertical physics better

### If Speed Stays Low:
- Check buoyancy force values in console
- May need to disable buoyancy spring forces
- Could be an issue with how forces are being applied

## Hypothesis

I suspect the depth control system is applying large vertical forces that, due to the submarine's pitch or the way Godot's physics works, are creating horizontal drag. The 50M N ballast force is 10x larger than propulsion!

Alternatively, the vertical damping (80k N per m/s) might be affecting horizontal movement if there's any coupling in the physics engine.

## Files Modified

**scripts/physics/submarine_physics.gd:**
- Temporarily disabled `apply_depth_control(delta)`
- Added force logging in `update_physics()`

## Testing Instructions

1. Launch the game
2. Switch to Tactical Map view
3. Set speed slider to maximum (10.3 m/s)
4. Keep depth at 0 (surface)
5. Watch console output for force values
6. Observe if speed reaches above 5 m/s

Console should show:
```
Forces: speed=X.XX buoy=XXXXX drag=XXXXX prop=XXXXXXX
Propulsion: target=10.3 current_speed=X.XXX ...
Drag: speed=X.XX forward=X.XX sideways=X.XX drag=XXXXX N
```

Look for:
- Is propulsion force staying high (> 3M N)?
- Is drag force reasonable (< 500k N at 3.6 m/s)?
- Is buoyancy force creating horizontal forces?
- Does speed increase past 3.6 m/s?
