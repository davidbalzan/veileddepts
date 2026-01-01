# Submarine Control Guide

## Speed Control

The speed slider in the Tactical Map view now supports both forward and reverse movement:

```
[Reverse ← | → Forward]
-5.15 m/s ←──●──→ 10.3 m/s
           (0.0)
```

### Speed Ranges
- **Forward**: 0.0 to 10.3 m/s (0 to 20 knots)
- **Reverse**: -5.15 to 0.0 m/s (-10 to 0 knots)
- **Stop**: 0.0 m/s

### How It Works
1. **Setting Speed**: Move the slider left (reverse) or right (forward)
2. **Direction**: Submarine moves along its current heading
   - Positive speed = forward in heading direction
   - Negative speed = backward (reverse) in heading direction
3. **Setting Heading**: Click on the tactical map to set a waypoint
   - Submarine will turn to face the waypoint
   - Then move at the set speed toward/away from it

## Depth Control

The depth slider controls how deep the submarine dives:

```
Surface (0m) ←──●──→ Max Depth (400m)
```

### Depth Ranges
- **Surface**: 0 m
- **Periscope Depth**: 10-20 m
- **Operating Depth**: 0-400 m
- **Max Depth**: 400 m

## Control Methods

### Method 1: Direct Speed/Depth Control (New)
```gdscript
# Set speed without changing heading or waypoint
simulation_state.set_target_speed(5.0)  # Forward at 5 m/s
simulation_state.set_target_speed(-3.0)  # Reverse at 3 m/s

# Set heading independently
simulation_state.set_target_heading(45.0)  # Northeast

# Set depth independently
simulation_state.set_target_depth(50.0)  # Dive to 50m
```

### Method 2: Waypoint Command (Original)
```gdscript
# Set waypoint, speed, and depth together
simulation_state.update_submarine_command(
    Vector3(100, 0, 100),  # Waypoint position
    7.5,                    # Speed (m/s)
    50.0                    # Depth (m)
)
# This also updates heading to point toward waypoint
```

## UI Display

The submarine info panel now shows both current and target values:

```
Position: (0, -50, 100)
Course: 45°
Speed: 4.8 m/s (Target: 5.0 m/s)
Depth: 48 m (Target: 50 m)
```

This helps you see:
- Where you are vs where you're going
- How fast you're moving vs target speed
- Current depth vs target depth

## Tips

1. **Starting Movement**: 
   - First set a heading (click waypoint or use set_target_heading)
   - Then adjust speed slider to move

2. **Quick Stop**: 
   - Move speed slider to center (0.0 m/s)
   - Submarine will coast to a stop

3. **Reversing**: 
   - Move speed slider to left (negative)
   - Submarine backs up along its heading
   - Useful for tight maneuvering

4. **Diving While Moving**: 
   - Set speed first
   - Then adjust depth slider
   - Submarine will dive/surface while maintaining speed

5. **Emergency Surface**: 
   - Set depth to 0 m
   - Submarine will rise to surface
   - Speed is maintained during surfacing
