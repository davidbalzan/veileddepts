# Propulsion Force Fix - Version 2

## Problem

After fixing the heading issue, the submarine still only reached 0.3 m/s when target was 10.3 m/s (full speed). This indicated a severe force imbalance.

## Root Cause Analysis

### Force Calculations

**Original propulsion force**: 500,000 N
**Submarine mass**: 8,000,000 kg (8000 tons)
**Maximum acceleration**: 500,000 / 8,000,000 = 0.0625 m/s²

At this acceleration:
- Time to reach 10.3 m/s = 10.3 / 0.0625 = 164.8 seconds (almost 3 minutes!)
- This assumes NO drag or other opposing forces

**Drag force at 0.3 m/s**:
- F_drag = 0.5 × 1025 × 0.3² × 0.04 × 100 ≈ 185 N
- This is tiny, so drag wasn't the problem

**Linear damping**:
- RigidBody3D had `linear_damp = 0.1`
- This applies a damping force proportional to velocity
- At low speeds, this can significantly slow acceleration
- Damping force ≈ velocity × damping × mass
- At 0.3 m/s: ~240,000 N opposing force!

## The Fix

### 1. Increased Propulsion Force (10x)

```gdscript
const PROPULSION_FORCE_MAX: float = 5000000.0  # Was 500,000
```

**New acceleration**: 5,000,000 / 8,000,000 = 0.625 m/s²
- Time to reach 10.3 m/s ≈ 16.5 seconds (much more reasonable)

### 2. Reduced Linear Damping (10x)

```gdscript
submarine_body.linear_damp = 0.01  # Was 0.1
```

**Why this matters**:
- Linear damping in Godot applies: `force = -velocity * linear_damp * mass`
- At 0.1 damping and 8M kg mass, even small velocities create huge opposing forces
- Reduced to 0.01 since water drag is already handled by our physics system
- At 0.3 m/s with new damping: ~24,000 N (10x less opposition)

### 3. Added Debug Output

Added temporary debug logging to monitor propulsion:
- Target speed
- Current speed in heading direction
- Speed error
- Propulsion ratio
- Applied force

This helps verify the fix is working.

## Expected Behavior Now

With the new values:
- **Net acceleration** at start: ~0.6 m/s² (accounting for damping)
- **Time to full speed**: ~17-20 seconds (realistic for a submarine)
- **Steady-state speed**: Should reach close to 10.3 m/s target

## Files Modified

1. **scripts/physics/submarine_physics.gd**
   - Increased `PROPULSION_FORCE_MAX` from 500,000 to 5,000,000 N
   - Added debug output to monitor propulsion

2. **scripts/core/main.gd**
   - Reduced `linear_damp` from 0.1 to 0.01
   - Water drag is handled by physics system, not RigidBody3D damping

## Testing

The submarine should now:
1. ✓ Accelerate noticeably when speed slider is moved
2. ✓ Reach speeds of 5+ m/s within 10 seconds
3. ✓ Eventually reach close to target speed (10.3 m/s)
4. ✓ Show debug output in console with force values

## Why This Happened

The original values were likely:
1. **Too conservative** - trying to be "realistic" but not accounting for the mass
2. **Double-damping** - both RigidBody3D damping AND physics drag
3. **Not tested** at full speed with the actual mass values

## Next Steps

Once confirmed working:
1. Remove debug output from `apply_propulsion()`
2. Fine-tune acceleration curve if needed
3. Test reverse movement
4. Test at different depths
