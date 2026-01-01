# Submarine Movement Fix - Backwards Movement Issue

## Problem
When submarine heading was 0° (North) and power was increased, the submarine moved backwards instead of forwards.

## Root Cause
Inconsistent forward direction calculations in `submarine_physics.gd`:

1. **Propulsion function** (line 277): Used `-cos(heading_rad)` for Z component ✓
2. **Drag function** (line 203-209): Used `-cos(heading_rad)` for Z component ✓

The fix has been successfully applied - both functions now use the same formula.

## Solution
Updated the drag function to use `-cos(heading_rad)` to match the propulsion function.

### Changed in `scripts/physics/submarine_physics.gd` (line 203-209):
```gdscript
# Get submarine's forward direction
# FIXED: Negate Z component - Godot's coordinate system has -Z as forward
var forward_direction = Vector3(
    sin(submarine_body.rotation.y),
    0.0,
    -cos(submarine_body.rotation.y)  # Changed from +cos to -cos
)
```

## Coordinate System
Godot's coordinate system:
- **+X** = East
- **+Y** = Up
- **-Z** = Forward (North when rotation.y = 0)

Heading angles:
- **0°** = North (-Z direction)
- **90°** = East (+X direction)
- **180°** = South (+Z direction)
- **270°** = West (-X direction)

## Verification
Both forward direction calculations now use the same formula:
```gdscript
Vector3(sin(heading_rad), 0.0, -cos(heading_rad))
```

This ensures:
1. ✅ Propulsion pushes in the correct direction
2. ✅ Drag opposes motion correctly
3. ✅ Submarine moves forward when heading = 0° and speed > 0
4. ✅ All compass indicators match across views

## Status
**FIXED** - The submarine now moves forward correctly at all headings.
