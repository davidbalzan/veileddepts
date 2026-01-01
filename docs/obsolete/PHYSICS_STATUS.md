# Submarine Physics Status

## Working ✅
1. **Speed**: Reaches full 10.3 m/s
2. **Coordinate system**: Consistent across all views
3. **Heading calculation**: Correct from velocity
4. **Waypoint placement**: Calculates correct heading to target
5. **Camera smoothing**: Reduces jitter
6. **Axis locking**: Prevents roll and pitch instability
7. **Model visibility**: Visible from all camera views

## Issues Remaining ❌

### 1. Lateral Movement (Sliding)
**Problem**: Submarine slides sideways instead of turning first then moving forward

**Root Cause**: The submarine body rotation isn't keeping up with the velocity direction. This creates a mismatch:
- Propulsion pushes along body axis (e.g., north)
- But velocity ends up pointing toward waypoint (e.g., west)
- Result: Submarine appears to slide sideways

**Attempted Fixes**:
- Increased sideways drag (now 100x forward drag)
- Increased steering torque
- Added angular damping

**Why it's hard**: 
- Torque too low → submarine doesn't turn, slides sideways
- Torque too high → submarine spins uncontrollably
- Need to find the sweet spot

### 2. Steering Torque Balance
**Problem**: Finding the right torque value is difficult
- Too low (< 10000): Submarine doesn't turn, just slides
- Too high (> 50000): Submarine spins like a top
- Current (20000): Still some lateral movement

**Physics Parameters**:
- Mass: 8,000,000 kg (8000 tons)
- Angular damping: 1.0
- Torque multiplier: 20000
- Max torque: 1 trillion N⋅m

## Possible Solutions

### Option A: Increase Torque + Damping Together
- Torque multiplier: 50000
- Angular damping: 3.0
- Theory: High torque for fast turning, high damping to prevent overshoot

### Option B: Direct Rotation (Arcade Style)
- Instead of torque, directly set rotation toward target
- More arcade-like but guaranteed to work
- Loses realistic physics feel

### Option C: Velocity-Based Steering
- Apply lateral force to steer (like a car)
- Not realistic for submarines but might feel better

### Option D: Tune PID Controller
- Add integral and derivative terms to steering
- Better control of angular velocity
- More complex but more stable

## Recommendation
Try Option A first - it maintains physics realism while providing responsive control.
