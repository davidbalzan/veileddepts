# Testing the S-Curve Depth Control

## Quick Test Scenarios

### Test 1: Standard Descent (150m)
**Setup:**
- Start at surface (0m depth)
- Set target depth to 150m
- Forward speed: 5 m/s

**Expected Behavior:**
1. **0-45m**: Pitch smoothly increases from 0° to ~12° (nose down)
2. **45-90m**: Steady pitch at 12°, efficient descent
3. **90-130m**: Pitch gradually reduces from 12° to 0°
4. **130-150m**: Slight nose-up counter-pitch (~5°) to arrest descent
5. **At 150m**: Level, stable, minimal oscillation

**Watch For:**
- Smooth pitch transitions (no jerks)
- No overshoot beyond 153m
- Settling time < 15 seconds

---

### Test 2: Standard Ascent (100m to surface)
**Setup:**
- Start at 100m depth
- Set target depth to 0m (surface)
- Forward speed: 5 m/s

**Expected Behavior:**
1. **100-75m**: Pitch smoothly increases to ~12° (nose up), targeting 25m
2. **75-40m**: Steady pitch at 12°
3. **40-25m**: Pitch reduces, arriving level at 25m waypoint
4. **25-15m**: Gentle pitch ~3° for final approach (reduced from 12°)
5. **15-5m**: Counter-pitch nose down ~2-3° to slow ascent
6. **At surface**: Level, no broaching

**Watch For:**
- Two-stage behavior (100m→25m, then 25m→0m)
- Reduced pitch during final approach
- Smooth surface arrival without breach
- Zero pitch at surface

---

### Test 3: Small Depth Change (50m)
**Setup:**
- Start at 100m depth
- Set target depth to 150m
- Forward speed: 5 m/s

**Expected Behavior:**
1. **100-115m**: Smooth pitch ramp to ~10°
2. **115-135m**: Steady cruise
3. **135-145m**: Deceleration
4. **145-150m**: Counter-pitch
5. **At 150m**: Stable arrival

**Watch For:**
- Phases scale appropriately for shorter distance
- Still smooth and controlled
- No overshoot

---

### Test 4: Emergency Deep Dive (300m)
**Setup:**
- Start at 50m depth
- Set target depth to 350m
- Forward speed: 8 m/s

**Expected Behavior:**
1. **50-125m**: Extended acceleration phase
2. **125-275m**: Long steady cruise at 12° pitch
3. **275-330m**: Extended deceleration
4. **330-350m**: Counter-pitch arrest
5. **At 350m**: Stable

**Watch For:**
- Phases scale up for longer distance
- Extended cruise phase is efficient
- Still smooth transitions at both ends

---

### Test 5: Low Speed Maneuvering
**Setup:**
- Start at 75m depth
- Set target depth to 100m
- Forward speed: 1 m/s (very slow)

**Expected Behavior:**
- S-curve still applies but slower response
- Dive planes less effective at low speed
- May take longer to achieve target
- Still follows phase pattern

**Watch For:**
- System still attempts S-curve
- No jerky movements despite low speed
- Eventually reaches target

---

## Debug Information

### Viewing S-Curve in Action

Enable debug mode in [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd#L467):
```gdscript
if debug_mode and Engine.get_process_frames() % 120 == 0:
    print("[PITCH DEBUG] ...")
```

This prints every 2 seconds:
- Current pitch angle
- Dive plane torque
- Ascent/descent rate
- Current depth

### Manual Testing Checklist

- [ ] Smooth acceleration (no jerks)
- [ ] Steady cruise phase visible
- [ ] Early deceleration observed
- [ ] Counter-pitch arrests motion
- [ ] No significant overshoot (< 5m)
- [ ] Stable at target depth
- [ ] Surface approach uses two stages
- [ ] No breaching at surface
- [ ] Works at various speeds

---

## Tuning Parameters

If behavior needs adjustment, modify these in [dive_plane_system.gd](../scripts/physics/dive_plane_system.gd):

### Target Pitch Angle (Line ~98)
```gdscript
var target_pitch_magnitude = 12.0  # Degrees during cruise
```
- **Increase** (e.g., 15°): Faster depth changes, more aggressive
- **Decrease** (e.g., 8°): Slower depth changes, more gentle

### Surface Approach Pitch (Line ~102)
```gdscript
target_pitch_magnitude = 3.0  # Very shallow angle
```
- **Increase** (e.g., 5°): Faster surface approach
- **Decrease** (e.g., 2°): More gentle surface approach

### Phase Distances (Line ~93-94)
```gdscript
var acceleration_distance = min(50.0, total_distance * 0.3)
var deceleration_distance = min(75.0, total_distance * 0.4)
```
- **Increase percentages**: Longer smooth phases, slower response
- **Decrease percentages**: Shorter smooth phases, quicker transitions

### Counter-Pitch Zone (Line ~109)
```gdscript
if remaining_distance < 20.0:
```
- **Increase** (e.g., 30.0): Earlier counter-pitch, more damping
- **Decrease** (e.g., 15.0): Later counter-pitch, less damping

### Counter-Pitch Strength (Line ~115)
```gdscript
var counter_angle = -sign(depth_error) * 5.0 * counter_pitch_strength * velocity_factor
```
- **Increase** (e.g., 7.0): Stronger arrest, less overshoot
- **Decrease** (e.g., 3.0): Gentler arrest, may have slight overshoot

---

## Common Issues & Solutions

### Issue: Overshoot still occurring
**Cause**: Counter-pitch too weak or starting too late
**Solution**: 
- Increase counter-pitch zone from 20m to 30m
- Increase counter-pitch strength from 5.0 to 7.0

### Issue: Takes too long to change depth
**Cause**: Target pitch too conservative
**Solution**:
- Increase `target_pitch_magnitude` from 12° to 15°
- Decrease deceleration distance percentage

### Issue: Oscillation at target depth
**Cause**: Counter-pitch too strong or phase transitions too abrupt
**Solution**:
- Decrease counter-pitch strength
- Increase transition zone sizes

### Issue: Breaching at surface
**Cause**: Final approach too aggressive
**Solution**:
- Decrease `target_pitch_magnitude` in surface approach block
- Increase surface approach phase distances

### Issue: Not smooth enough
**Cause**: Phase transitions too short
**Solution**:
- Increase acceleration and deceleration percentages
- Check that cubic easing is working (Phase 1)

---

## Unit Test Template

Create test in `tests/unit/test_s_curve_depth.gd`:

```gdscript
extends GutTest

func test_descent_phases():
    var dive_plane = DivePlaneSystem.new()
    
    # Test Phase 1: Acceleration
    var torque_0m = dive_plane.calculate_dive_plane_torque(
        0.0, 150.0, 0.0, 5.0, 0.0, 0.0
    )
    var torque_20m = dive_plane.calculate_dive_plane_torque(
        20.0, 150.0, 2.0, 5.0, 5.0, 0.0
    )
    assert_true(abs(torque_20m) > abs(torque_0m), 
        "Torque should increase during acceleration phase")
    
    # Test Phase 2: Cruise
    var torque_70m = dive_plane.calculate_dive_plane_torque(
        70.0, 150.0, 3.0, 5.0, 12.0, 0.0
    )
    # Should maintain steady pitch
    
    # Test Phase 4: Counter-pitch
    var torque_145m = dive_plane.calculate_dive_plane_torque(
        145.0, 150.0, 2.5, 5.0, 2.0, 0.0
    )
    # Should apply counter-pitch (opposite sign to depth error)
```

---

## Performance Monitoring

Watch these metrics during testing:

| Metric | Target | Excellent | Acceptable | Poor |
|--------|--------|-----------|------------|------|
| Overshoot | < 2m | < 3m | < 5m | > 5m |
| Settling Time | < 10s | < 15s | < 20s | > 20s |
| Pitch Smoothness | 0 jerks | 0-1 jerks | 1-2 jerks | > 2 jerks |
| Max Pitch | 12° | 13° | 15° | > 15° |
| Surface Breach | None | None | Small | Large |
| Cruise Stability | ±0.5° | ±1° | ±2° | > 2° |

---

## Integration Testing

Test with full simulation:
1. Launch game: `./run_game.sh`
2. Set waypoint with depth 150m
3. Observe submarine behavior
4. Try multiple depth changes
5. Test surfacing from various depths
6. Check debug overlay (F1) for real-time data

---

## Success Criteria

The S-curve depth control is working correctly when:
- ✓ Depth changes feel smooth and natural
- ✓ No jarring pitch changes
- ✓ Minimal or no overshoot
- ✓ Quick settling at target depth
- ✓ Surfacing is safe and controlled
- ✓ Works consistently across various scenarios
- ✓ Players report improved submarine handling
