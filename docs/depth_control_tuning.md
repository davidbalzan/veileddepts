# Submarine Depth Control Tuning Guide

## Problem Description

The submarine was experiencing oscillations when trying to maintain a target depth. When commanded to dive to 50m, it would:
1. Overshoot the target depth
2. Rise back above the target
3. Dive again, creating a continuous oscillation

This is a classic control system stability problem caused by improper PID tuning.

## Root Cause

The original PID controller had:
- Too high proportional gain (Kp = 0.8): Caused aggressive corrections
- Insufficient damping (Kd = 0.4): Not enough resistance to velocity changes
- Small dead zone (0.5m): Controller kept making corrections even when very close to target
- Derivative term based on error change: Less stable than velocity-based derivative

## Solution Implemented

### 1. Reduced Proportional Gain
```gdscript
const KP: float = 0.3  # Was 0.8 - reduced by 62%
```
Lower Kp means less aggressive corrections, reducing overshoot.

### 2. Increased Derivative Gain
```gdscript
const KD: float = 1.2  # Was 0.4 - increased by 200%
```
Higher Kd provides more damping, resisting rapid velocity changes.

### 3. Velocity-Based Derivative Term
```gdscript
var depth_rate = -submarine_body.linear_velocity.y
var desired_rate = clamp(effective_error * 0.1, -DEPTH_CHANGE_RATE, DEPTH_CHANGE_RATE)
var rate_error = desired_rate - depth_rate
```
Using actual velocity instead of error derivative provides better stability.

### 4. Larger Dead Zone
```gdscript
const DEAD_ZONE: float = 1.5  # Was 0.5m - tripled
```
Within 1.5m of target, the controller stops making corrections, preventing micro-oscillations.

### 5. Increased Vertical Damping
```gdscript
var damping_force = -vertical_velocity * 80000.0  # Was 50000.0
```
More damping force resists vertical motion, stabilizing depth changes.

### 6. Reduced Pitch Authority
```gdscript
var pitch_for_depth = clamp(depth_error / 150.0, -0.1, 0.1)  # Was /100.0, ±0.15
```
Less aggressive pitch changes reduce dynamic instability.

### 7. Active Leveling Near Target
```gdscript
if abs(depth_error) > DEAD_ZONE * 2.0:
    // Apply pitch for depth change
else:
    // Level out when near target
    var level_torque = -current_pitch * 40000.0
    submarine_body.apply_torque(Vector3(level_torque, 0, 0))
```
Automatically levels the submarine when approaching target depth.

## Testing

### Unit Tests (`tests/unit/test_submarine_depth_control.gd`)
- Tests depth control reaching target
- Verifies no excessive oscillation
- Checks buoyancy at surface
- Validates PID gains
- Tests depth control while moving
- Tests depth change response

### Property Tests (`tests/property/test_depth_control_stability.gd`)
- Long-duration stability tests (2 minutes)
- Measures overshoot, settling time, steady-state error
- Counts oscillations
- Tests depth changes mid-simulation

### Debug Monitor (`scripts/debug/depth_control_monitor.gd`)
- Real-time monitoring of depth control
- Displays current depth, target, error, velocity
- Counts oscillations automatically
- Exports data to CSV for analysis
- Press ESC to export data

## Expected Behavior

After tuning, the submarine should:

1. Approach target depth smoothly without excessive overshoot (< 10m)
2. Settle within 30-60 seconds for typical depth changes
3. Maintain depth with minimal oscillation (< 5 crossings)
4. Stay within ±2m of target depth in steady state
5. Level out automatically when near target

## Further Tuning

If oscillations persist:

1. Increase Kd (derivative gain) for more damping
2. Decrease Kp (proportional gain) for less aggressive response
3. Increase dead zone to 2.0m or more
4. Increase vertical damping force
5. Reduce pitch authority further

If response is too slow:

1. Increase Kp slightly (but watch for oscillations)
2. Decrease dead zone to 1.0m
3. Increase pitch authority slightly

## Control Theory Background

This is a critically damped PID controller design:

- Critically damped: Returns to target as quickly as possible without overshooting
- Damping ratio ζ ≈ 1.0: Optimal for submarine depth control

### PID Terms Explained

- P (Proportional): Correction proportional to error. Too high causes overshoot.
- I (Integral): Eliminates steady-state error. Too high causes windup and instability.
- D (Derivative): Resists rate of change. Provides damping. Too high causes noise sensitivity.

## Monitoring in Game

To monitor depth control behavior:

1. Add `DepthControlMonitor` node to main scene
2. Run the game
3. Command submarine to dive (e.g., 50m)
4. Watch the monitor display in top-left
5. Press ESC to export data to CSV
6. Analyze data in spreadsheet software

## CSV Data Analysis

The exported CSV contains:
- Time: Simulation time in seconds
- Depth: Current depth in meters
- Velocity: Vertical velocity in m/s
- Target: Target depth in meters
- Error: Depth error (target - current)

Plot depth vs time to visualize:
- Overshoot
- Settling time
- Oscillations
- Steady-state error
