---
inclusion: fileMatch
fileMatchPattern: "**/*.gd"
---

# Unified Coordinate System

This project uses a consistent coordinate system for all navigation and heading calculations.

## World Coordinates (Godot 3D)

- **+X** = East (right when facing North)
- **-X** = West (left when facing North)
- **+Y** = Up (above sea level)
- **-Y** = Down (below sea level / depth)
- **+Z** = South (behind when facing North)
- **-Z** = North (forward when facing North)

## Navigation Headings

Headings are measured in degrees from North, clockwise:
- **0°** = North (-Z direction)
- **90°** = East (+X direction)
- **180°** = South (+Z direction)
- **270°** = West (-X direction)

## Standard Heading Calculation

Always use this formula to calculate heading from a direction vector:

```gdscript
# From a 3D direction vector:
var heading_deg = rad_to_deg(atan2(direction.x, -direction.z))

# Normalize to 0-360 range:
while heading_deg < 0:
    heading_deg += 360.0
while heading_deg >= 360:
    heading_deg -= 360.0
```

## 2D Screen Vectors for Compass/Map Display

When drawing on screen where Y increases downward:

```gdscript
# Convert heading to 2D screen vector (for compass arrows, icons, etc.)
var heading_rad = deg_to_rad(heading_deg)
var screen_vec = Vector2(sin(heading_rad), -cos(heading_rad))
# Result: North (0°) points up, East (90°) points right
```

## Godot Y-Axis Rotation

In Godot, `rotation.y` follows the left-hand rule:
- **Positive rotation.y** = Counter-clockwise when viewed from above (turns LEFT)
- **Negative rotation.y** = Clockwise when viewed from above (turns RIGHT)

This is OPPOSITE to navigation convention where increasing heading = turning right.

When applying steering torque:
```gdscript
# heading_error > 0 means we need to turn RIGHT (clockwise)
# But positive Y torque turns LEFT, so we NEGATE:
var steering_torque = -heading_error * torque_coefficient
```

## Key Files Using This System

- `scripts/physics/submarine_physics.gd` - Heading calculation and steering
- `scripts/core/simulation_state.gd` - Waypoint heading calculation
- `scripts/core/contact.gd` - Bearing calculations
- `scripts/views/tactical_map_view.gd` - Compass and submarine icon
- `scripts/views/periscope_view.gd` - Bearing arc display
