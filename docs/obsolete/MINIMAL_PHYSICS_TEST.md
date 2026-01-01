# Minimal Physics Test - Isolating the Problem

## Current State

Submarine still capping at 3.6 m/s even with depth control disabled.

## Changes Made - Stripping Down to Bare Minimum

### 1. Disabled Buoyancy
```gdscript
// apply_buoyancy(delta)  // DISABLED
```

### 2. Disabled Depth Control
```gdscript
// apply_depth_control(delta)  // DISABLED
```

### 3. Simplified Drag to Absolute Minimum
```gdscript
const DRAG_CONSTANT: float = 10000.0
var drag_magnitude = DRAG_CONSTANT * speed * speed
```

**At 3.6 m/s:** drag = 10,000 × 12.96 = **129,600 N**
**At 10 m/s:** drag = 10,000 × 100 = **1,000,000 N**

### 4. Disabled Gravity
```gdscript
submarine_body.gravity_scale = 0.0
```

## Current Physics State

**ONLY these forces are active:**
1. **Propulsion**: ~3,250,000 N forward (at 3.6 m/s with 10.3 m/s target)
2. **Drag**: ~130,000 N backward (at 3.6 m/s)
3. **Linear damping**: ~288,000 N backward (RigidBody3D built-in)

**Net force:** 3,250,000 - 130,000 - 288,000 = **2,832,000 N forward**

**Expected acceleration:** 2,832,000 / 8,000,000 = **0.354 m/s²**

The submarine should be accelerating rapidly!

## If Still Capped at 3.6 m/s

Then the problem MUST be one of:

### 1. Propulsion Force Not Being Applied Correctly
- Check if `apply_central_force()` is working
- Check if force direction is correct
- Check if force magnitude is actually what we think

### 2. RigidBody3D Linear Damping Higher Than Expected
- Current setting: 0.01
- At 3.6 m/s: creates 288,000 N
- But maybe Godot calculates it differently?

### 3. Hidden Force We Haven't Found
- Some Godot physics setting
- Collision with something
- Another system we haven't identified

### 4. Force Application Timing Issue
- Forces being applied then immediately cancelled
- Physics step order problem

## Debug Output to Watch

Console should show:
```
Drag SIMPLE: speed=3.60 drag=129600 N
Propulsion: target=10.3 current_speed=3.600 error=6.700 ratio=0.650 force=3250000 heading=0°
Forces: speed=3.60 buoy=0 drag=129600 prop=3250000
```

**Key things to verify:**
1. Is `prop` force actually 3.25M N?
2. Is `drag` force only ~130k N?
3. Is speed actually stuck at exactly 3.6 m/s or slowly increasing?

## Next Steps If Still Stuck

### Test 1: Disable Linear Damping Completely
```gdscript
submarine_body.linear_damp = 0.0
```

### Test 2: Disable Drag Completely
```gdscript
// apply_drag(delta)  // DISABLED
```

Then it's ONLY propulsion. Should accelerate to ridiculous speeds.

### Test 3: Check Propulsion Force Directly
Add to propulsion function:
```gdscript
print("PROPULSION FORCE VECTOR: ", forward_direction * current_propulsion_force)
print("VELOCITY BEFORE: ", submarine_body.linear_velocity)
submarine_body.apply_central_force(forward_direction * current_propulsion_force)
print("VELOCITY AFTER: ", submarine_body.linear_velocity)
```

### Test 4: Try Impulse Instead of Force
```gdscript
submarine_body.apply_central_impulse(forward_direction * current_propulsion_force * delta)
```

## Hypothesis

At this point, if it's still capped at 3.6 m/s with minimal physics, I suspect:
1. **Linear damping is calculated differently** than we think in Godot
2. **There's a max velocity setting** on the RigidBody3D we haven't seen
3. **The force isn't actually being applied** due to some Godot quirk

## Files Modified

1. **scripts/physics/submarine_physics.gd**
   - Disabled buoyancy
   - Disabled depth control
   - Simplified drag to k×v²
   - Added detailed logging

2. **scripts/core/main.gd**
   - Disabled gravity (gravity_scale = 0.0)

## Test Instructions

1. Launch game
2. Set speed to max
3. Watch console output
4. Note if speed goes above 3.6 m/s
5. Share console output showing force values
