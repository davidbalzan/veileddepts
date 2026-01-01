# Submarine Movement Fixes - Summary

## The Core Problem

The submarine wasn't moving when you adjusted the speed slider. Two main issues:

1. **Confusion between current and target heading**: The physics system was using `submarine_heading` which represents the CURRENT heading (calculated from velocity), not where the player wants to go.

2. **Speed included vertical movement**: When diving/surfacing, that vertical velocity was being reported as horizontal speed.

## The Solution

### 1. Separated Current State from Target Commands

**Before:**
- `submarine_heading` was used for both current state AND target direction
- Confusing and caused the submarine to not move properly

**After:**
- `submarine_heading` = current heading (where sub is actually pointing based on velocity)
- `target_heading` = where player wants to go (set by controls)
- Physics uses `target_heading` to apply propulsion

### 2. Fixed Speed Calculation

**Before:**
```gdscript
var speed = vel.length()  // Includes vertical (Y) component
```

**After:**
```gdscript
var horizontal_velocity = Vector2(vel.x, vel.z)
var speed = horizontal_velocity.length()  // Only horizontal movement
```

### 3. Added Direct Control Methods

New methods in `SimulationState`:
- `set_target_speed(speed)` - Set speed without changing heading
- `set_target_heading(heading)` - Set heading without waypoint
- `set_target_depth(depth)` - Set depth independently

### 4. Added Reverse Capability

- Speed slider now ranges from -5.15 to 10.3 m/s
- Negative values = reverse at half max speed
- Physics handles negative target speed correctly

## How It Works Now

1. **Player moves speed slider** → Calls `set_target_speed(5.0)`
2. **Target speed is set** → `simulation_state.target_speed = 5.0`
3. **Physics reads target** → Uses `target_heading` for direction
4. **Propulsion applied** → Force applied in `target_heading` direction
5. **Submarine moves** → Velocity builds up over time
6. **State updated** → Current heading calculated from actual velocity

## Quick Test

```gdscript
# In game or test script:
simulation_state.set_target_heading(0.0)  # Point North
simulation_state.set_target_speed(5.0)    # Move forward at 5 m/s

# Submarine will now accelerate forward!
```

## Files Changed

1. `scripts/core/simulation_state.gd` - Added target_heading, new setter methods
2. `scripts/physics/submarine_physics.gd` - Use target_heading, fix speed calc
3. `scripts/views/tactical_map_view.gd` - Update sliders to use new methods

## What You'll See

In the Tactical Map view:
```
Position: (0, 0, 0)
Course: 2° (Target: 0°)          ← Current heading converging to target
Speed: 4.8 m/s (Target: 5.0 m/s) ← Speed building up to target
Depth: 0 m (Target: 0 m)
```

The submarine will:
- ✓ Move when you adjust the speed slider
- ✓ Move in the direction of target_heading
- ✓ Support reverse (negative speed)
- ✓ Show accurate horizontal speed (not affected by diving)
- ✓ Display current vs target values for all controls
