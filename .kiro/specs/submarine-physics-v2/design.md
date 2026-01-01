# Design Document: Submarine Physics Engine v2

## Overview

The Submarine Physics Engine v2 is a complete rewrite of the submarine physics system, designed to provide realistic hydrodynamic simulation while maintaining numerical stability and performance. The engine replaces force-based corrections with direct velocity manipulation where appropriate, implements speed-dependent control surfaces (rudders and dive planes), and provides extensible drag modeling for future gameplay features.

### Key Design Principles

1. **Stability First**: Use direct velocity manipulation for anti-slip rather than fighting forces with counter-forces
2. **Physical Realism**: Control surfaces (rudders, dive planes) only work with water flow
3. **Coordinate System Consistency**: All calculations use the unified coordinate system (North=0°, East=90°)
4. **Extensibility**: Drag system supports dynamic appendages for future features
5. **Performance**: Cache expensive calculations, skip unnecessary work
6. **Numerical Safety**: Validate all vectors, handle edge cases gracefully

## Architecture

### Component Hierarchy

```
SubmarinePhysicsV2 (Node)
├── CoordinateSystem (static utility)
├── PropulsionSystem (component)
├── HydrodynamicDrag (component)
├── RudderSystem (component)
├── DivePlaneSystem (component)
├── BallastSystem (component)
├── BuoyancySystem (component)
├── AppendageDragRegistry (component)
└── PhysicsValidator (component)
```

### Data Flow

```
Input (SimulationState)
  ↓
SubmarinePhysicsV2.update_physics(delta)
  ↓
1. Cache forward direction
2. Calculate buoyancy forces
3. Calculate drag forces (base + appendage + surface)
4. Calculate propulsion forces
5. Calculate rudder torques
6. Calculate dive plane torques
7. Calculate ballast forces
8. Apply sideways velocity elimination
9. Apply velocity alignment
10. Clamp velocity
11. Enforce boundaries
  ↓
Output (RigidBody3D state updated)
```

## Components and Interfaces

### SubmarinePhysicsV2

Main physics controller that orchestrates all subsystems.

**Public Interface:**
```gdscript
class_name SubmarinePhysicsV2 extends Node

func initialize(body: RigidBody3D, ocean: OceanRenderer, state: SimulationState) -> void
func update_physics(delta: float) -> void
func get_submarine_state() -> Dictionary
func configure_submarine_class(config: Dictionary) -> void
func load_submarine_class(class_name: String) -> bool
func add_appendage_drag(name: String, multiplier: float) -> void
func remove_appendage_drag(name: String) -> void
func get_available_classes() -> Array[String]
```


### CoordinateSystem

Static utility for coordinate transformations and heading calculations.

**Public Interface:**
```gdscript
static func calculate_heading(forward_direction: Vector3) -> float
static func normalize_heading(heading: float) -> float
static func heading_error(current: float, target: float) -> float
static func forward_direction_from_transform(transform: Transform3D) -> Vector3
static func heading_to_vector2(heading: float) -> Vector2
```

**Implementation Notes:**
- Uses standard formula: `atan2(forward.x, -forward.z)`
- Normalizes all headings to [0, 360) range
- Calculates shortest path for heading errors (wraps at ±180°)

### PropulsionSystem

Manages thrust generation along the submarine's longitudinal axis.

**Public Interface:**
```gdscript
func calculate_propulsion_force(
    forward_dir: Vector3,
    current_velocity: Vector3,
    target_speed: float,
    target_heading: float,
    delta: float
) -> Vector3
```

**Parameters:**
- `max_thrust`: Maximum propulsion force in Newtons
- `kp_speed`: Proportional gain for speed control (default: 1.5)
- `alignment_threshold`: Heading alignment required for full thrust (default: 0.9)

**Algorithm:**
1. Calculate speed along submarine axis: `speed = velocity.dot(forward_dir)`
2. Calculate heading alignment: `alignment = velocity_dir.dot(forward_dir)`
3. Calculate speed error: `error = target_speed - speed`
4. Apply PID control: `force = kp * error * max_thrust / max_speed`
5. Reduce thrust during turns: `force *= alignment_multiplier`
6. Clamp to limits: `force = clamp(force, -0.5 * max_thrust, max_thrust)`
7. Return force vector: `forward_dir * force`


### HydrodynamicDrag

Calculates drag forces opposing motion through water.

**Public Interface:**
```gdscript
func calculate_drag_force(
    velocity: Vector3,
    forward_dir: Vector3,
    depth: float,
    appendage_registry: AppendageDragRegistry
) -> Vector3
```

**Parameters:**
- `base_forward_drag`: Base drag coefficient for forward motion
- `sideways_drag`: Drag coefficient for sideways motion (400x forward)
- `surface_drag_depth_threshold`: Depth below which surface drag applies (5m)
- `surface_drag_multiplier`: Drag increase at surface (1.5 = 50% increase)

**Algorithm:**
1. Decompose velocity into forward and sideways components
2. Calculate surface drag factor based on depth
3. Calculate appendage drag from registry
4. Forward drag: `(base + appendage + surface) * forward_speed^2`
5. Sideways drag: `sideways_coef * sideways_speed^2`
6. Combine into total drag vector opposing motion

### RudderSystem

Generates yaw torque for steering based on water flow.

**Public Interface:**
```gdscript
func calculate_steering_torque(
    current_heading: float,
    target_heading: float,
    forward_speed: float,
    angular_velocity: float
) -> float
```

**Parameters:**
- `torque_coefficient`: Base torque multiplier (2,000,000 N·m)
- `max_rudder_angle`: Maximum rudder deflection (30°)
- `max_turn_rate`: Maximum angular velocity (5°/s)
- `min_steering_speed`: Minimum speed for effective steering (0.5 m/s)
- `max_steering_speed`: Speed cap for steering effectiveness (8.0 m/s)

**Algorithm:**
1. Calculate heading error (shortest path)
2. Calculate rudder angle: `clamp(heading_error, -30°, +30°)`
3. Calculate water flow speed over rudder: `abs(forward_speed)` (simplified - assumes flow aligned with submarine axis)
4. Apply low-speed penalty: if flow speed < 0.5 m/s, effectiveness = 20%
5. Cap speed factor at 8.0 m/s (prevents unrealistic turning at high speeds)
6. Calculate hydrodynamic force on rudder: `flow_speed * rudder_angle` (simplified lift equation)
7. Convert to torque: `-force * lever_arm * torque_coef` (negative for Godot's left-hand rotation)
8. Apply turn rate limiting if exceeding max_turn_rate
9. Apply stability damping

**Simplified Physics Model:**
- Real rudders generate lift force proportional to: `0.5 * density * area * velocity^2 * lift_coefficient * angle`
- We simplify to: `velocity * angle * effectiveness_coefficient`
- This captures the key behavior: no flow = no steering, more flow = more steering
- The linear relationship is sufficient for gameplay while being computationally efficient


### DivePlaneSystem

Generates pitch torque for depth control based on water flow.

**Public Interface:**
```gdscript
func calculate_dive_plane_torque(
    current_depth: float,
    target_depth: float,
    vertical_velocity: float,
    forward_speed: float,
    current_pitch: float
) -> float
```

**Parameters:**
- `bow_plane_effectiveness`: Bow plane contribution (0.4 = 40%)
- `stern_plane_effectiveness`: Stern plane contribution (0.6 = 60%)
- `max_plane_angle`: Maximum plane deflection (15°)
- `min_effective_speed`: Minimum speed for plane effectiveness (1.0 m/s)
- `max_effective_speed`: Speed for full plane effectiveness (5.0 m/s)

**Algorithm:**
1. Calculate depth error: `target_depth - current_depth`
2. Calculate desired pitch angle: `clamp(depth_error / 150, -15°, +15°)`
3. Calculate water flow speed over planes: `abs(forward_speed)` (simplified - assumes flow aligned with submarine axis)
4. Calculate speed effectiveness factor:
   - Below 1 m/s: < 10% effectiveness (minimal flow over planes)
   - 1-5 m/s: linear scaling (increasing flow effectiveness)
   - Above 5 m/s: 100% effectiveness (full hydrodynamic force)
5. Calculate pitch error: `desired_pitch - current_pitch`
6. Calculate hydrodynamic force on planes: `plane_angle * flow_speed^2 * effectiveness` (simplified lift equation)
7. Convert to torque with lever arms: bow planes at front (40%), stern planes at back (60%)
8. Return total pitch torque

**Simplified Physics Model:**
- Real dive planes generate lift force proportional to: `0.5 * density * area * velocity^2 * lift_coefficient * angle`
- We simplify to: `angle * velocity^2 * effectiveness_coefficient`
- The quadratic relationship with velocity is more important for dive planes than rudders
- This captures: no flow = no pitch control, more flow = exponentially more control
- Efficient computation while maintaining realistic behavior

### BallastSystem

Controls buoyancy for depth changes, especially at low speeds.

**Public Interface:**
```gdscript
func calculate_ballast_force(
    current_depth: float,
    target_depth: float,
    vertical_velocity: float,
    delta: float
) -> float
```

**Parameters:**
- `max_ballast_force`: Maximum vertical force (50,000,000 N)
- `kp`: Proportional gain (0.3)
- `ki`: Integral gain (0.005)
- `kd`: Derivative gain (1.2)
- `dead_zone`: Depth tolerance (0.5 m)

**Algorithm:**
1. Calculate depth error: `target_depth - current_depth`
2. Apply dead zone: if |error| < 0.5m, set error = 0
3. Update integral term with windup protection
4. Calculate desired depth rate: `clamp(error * 0.1, -5, +5) m/s`
5. Calculate rate error: `desired_rate - vertical_velocity`
6. PID output: `kp * error + ki * integral + kd * rate_error`
7. Convert to ballast force: `clamp(pid_output / 30, -1, +1) * max_force`
8. Apply vertical damping: `-vertical_velocity * 80,000`
9. Return total vertical force


### BuoyancySystem

Simulates Archimedes' principle and wave interaction.

**Public Interface:**
```gdscript
func calculate_buoyancy_force(
    position: Vector3,
    velocity: Vector3,
    target_depth: float,
    ocean_renderer: OceanRenderer
) -> Vector3
```

**Parameters:**
- `water_density`: Seawater density (1025 kg/m³)
- `submarine_volume`: Displacement volume (8000 m³)
- `buoyancy_coefficient`: Neutral buoyancy factor (1.0)
- `wave_influence_depth`: Depth where wave influence fades (10 m)

**Algorithm:**
1. Get wave height at submarine position from ocean renderer
2. Calculate submersion ratio based on hull depth vs water surface
3. Calculate buoyancy: `water_density * volume * submersion * 9.81`
4. Calculate wave influence factor (fades with depth)
5. If at surface: apply spring force to follow waves
6. If at surface: apply wave-induced roll/pitch torques
7. If deep: apply vertical stabilization damping
8. Return total buoyancy force vector

### AppendageDragRegistry

Manages dynamic drag contributions from extended equipment.

**Public Interface:**
```gdscript
func add_appendage(name: String, drag_multiplier: float) -> void
func remove_appendage(name: String) -> void
func get_total_drag_multiplier() -> float
func clear_all() -> void
func has_appendage(name: String) -> bool
```

**Data Structure:**
```gdscript
var appendages: Dictionary = {}  # name -> drag_multiplier
var max_total_multiplier: float = 2.0  # Max 100% increase
```

**Algorithm:**
1. Store appendages in dictionary: `{name: multiplier}`
2. Calculate total: `sum(all multipliers)`
3. Clamp total to max_total_multiplier
4. Return clamped total for use in drag calculations


### PhysicsValidator

Ensures numerical stability and handles edge cases.

**Public Interface:**
```gdscript
func validate_vector(v: Vector3, name: String) -> bool
func validate_and_fix_submarine_state(body: RigidBody3D) -> bool
func clamp_velocity(body: RigidBody3D, max_speed: float) -> void
func enforce_boundaries(body: RigidBody3D, boundary: float) -> void
```

**Safety Checks:**
1. Check all vectors for `is_finite()` before use
2. Check vector length before normalizing (prevent division by zero)
3. Detect and reset NaN in submarine state
4. Clamp all force magnitudes to prevent extreme values
5. Log errors for debugging without spamming console

## Data Models

### SubmarineConfiguration

```gdscript
class SubmarineConfiguration:
    var class_name: String
    var mass: float  # tons
    var max_speed: float  # m/s
    var max_depth: float  # meters
    var propulsion_force_max: float  # Newtons
    var base_forward_drag: float
    var sideways_drag: float
    var rudder_effectiveness: float
    var dive_plane_effectiveness: float
    var ballast_force_max: float
    var submarine_volume: float  # m³
    var max_turn_rate: float  # degrees/second
```

### PhysicsState

```gdscript
class PhysicsState:
    var position: Vector3
    var velocity: Vector3
    var angular_velocity: Vector3
    var rotation: Vector3
    var depth: float
    var heading: float
    var speed: float
    var forward_speed: float
    var sideways_speed: float
    var vertical_speed: float
```

### ControlInputs

```gdscript
class ControlInputs:
    var target_speed: float
    var target_heading: float
    var target_depth: float
```


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Heading Calculation Consistency

*For any* submarine orientation (transform), calculating the heading using `atan2(forward.x, -forward.z)` and normalizing to [0, 360) should produce a value that correctly represents the submarine's direction in the unified coordinate system (North=0°, East=90°, South=180°, West=270°).

**Validates: Requirements 1.1, 1.4**

### Property 2: Steering Direction Correctness

*For any* current heading and target heading, when a positive heading error exists (need to turn right/clockwise), the steering torque should be negative (accounting for Godot's left-hand Y-axis rotation), and vice versa for negative heading errors.

**Validates: Requirements 1.3, 18.2**

### Property 3: Propulsion Alignment

*For any* submarine orientation and velocity, the propulsion force vector should be parallel to the forward direction vector (dot product with perpendicular direction ≈ 0), and speed error should be calculated only along the forward axis.

**Validates: Requirements 2.1, 2.2**

### Property 4: Thrust Reduction During Turns

*For any* heading misalignment greater than 30 degrees, the propulsion thrust should be reduced to at most 50% of the maximum thrust that would be applied when perfectly aligned.

**Validates: Requirements 2.4**

### Property 5: Drag Formula Correctness

*For any* velocity, depth, and appendage configuration, the forward drag force should equal `(base + appendage + surface) * forward_speed^2` and sideways drag should equal `sideways_coef * sideways_speed^2`.

**Validates: Requirements 3.1, 3.2**

### Property 6: Sideways Drag Dominance

*For any* submarine configuration, the sideways drag coefficient should be at least 400 times larger than the base forward drag coefficient.

**Validates: Requirements 3.3**


### Property 7: Rudder Torque Formula

*For any* heading error, water flow speed, and rudder parameters, the steering torque should equal `-speed_factor * rudder_angle * torque_coefficient` where rudder angle is clamped to ±30° and speed factor is capped at 8.0 m/s.

**Validates: Requirements 4.1, 4.6**

### Property 8: Low-Speed Steering Penalty

*For any* water flow speed below 0.5 m/s, the rudder effectiveness should be reduced to at most 20% of normal effectiveness, reflecting that submarines cannot steer effectively without water flow.

**Validates: Requirements 4.3, 18.4**

### Property 9: Turn Rate Limiting

*For any* submarine state, the angular velocity around the Y-axis should never exceed the configured maximum turn rate (5°/s for default class), with damping applied when the limit is exceeded.

**Validates: Requirements 5.1**

### Property 10: Sideways Velocity Elimination

*For any* submarine with sideways velocity exceeding 0.5 m/s, applying the anti-slip correction should reduce the sideways component by 80% while preserving the forward speed magnitude.

**Validates: Requirements 6.2, 6.3, 18.3**

### Property 11: Velocity Alignment Threshold

*For any* submarine velocity with alignment factor (dot product of velocity direction and forward direction) above 0.7, the velocity alignment correction should be skipped to avoid unnecessary corrections.

**Validates: Requirements 7.2**

### Property 12: Depth Control Dead Zone

*For any* depth error within ±0.5 meters of target depth, the ballast system control output should be zero to prevent oscillation around the target.

**Validates: Requirements 8.2**

### Property 13: Dive Plane Speed Dependency

*For any* water flow speed, the dive plane pitch torque should be proportional to the speed (approaching zero at low speeds), and should reach maximum effectiveness at speeds above 5 m/s with less than 10% effectiveness below 1 m/s.

**Validates: Requirements 8.7, 19.2, 19.3, 18.5**

### Property 14: Buoyancy Calculation

*For any* submarine position and wave height, the buoyancy force should equal `water_density * displaced_volume * submersion_ratio * 9.81`, where displaced volume is based on the submarine's volume and submersion ratio is calculated from hull depth relative to water surface.

**Validates: Requirements 9.1, 9.2**


### Property 15: Velocity Clamping

*For any* submarine velocity, after clamping is applied, the velocity magnitude should not exceed 110% of the configured maximum speed.

**Validates: Requirements 10.1**

### Property 16: Boundary Enforcement

*For any* submarine position, after boundary enforcement is applied, the position should be within ±974 meters from the origin on both X and Z axes, and velocity components pointing outward from boundaries should be zeroed.

**Validates: Requirements 11.1, 11.3**

### Property 17: NaN Detection and Recovery

*For any* submarine state containing NaN or infinite values in position, velocity, or angular velocity, the validation system should detect the invalid state and reset to safe default values.

**Validates: Requirements 16.1, 16.2**

### Property 18: Surface Drag Scaling

*For any* depth between 0 and 5 meters, the surface drag multiplier should scale linearly from 1.5 (50% increase) at the surface to 1.0 (no increase) at 5 meters depth, and should be 1.0 for all depths greater than 5 meters.

**Validates: Requirements 20.1, 20.2, 20.3**

### Property 19: Appendage Drag Summation

*For any* set of active appendages, the total appendage drag multiplier should equal the sum of individual appendage multipliers, clamped to a maximum of 2.0 (100% increase).

**Validates: Requirements 21.6, 21.10**

### Property 20: Dive Plane Torque Formula

*For any* plane angle, water flow speed, and dive plane parameters, the pitch torque should be proportional to `plane_angle * speed_factor^2 * effectiveness`, where effectiveness is split 40% bow planes and 60% stern planes.

**Validates: Requirements 19.1**

## Error Handling

### NaN and Infinite Value Detection

The system implements comprehensive NaN detection at multiple levels:

1. **Pre-Force Application**: All force vectors are checked with `is_finite()` before applying to RigidBody3D
2. **State Validation**: Submarine position, velocity, and angular velocity are validated each frame
3. **Safe Defaults**: When NaN is detected, the system resets to safe values (zero velocity, current position)
4. **Logging**: All NaN detections are logged as errors for debugging

### Division by Zero Prevention

1. **Vector Normalization**: Always check `length_squared() > epsilon` before normalizing
2. **Speed Calculations**: Use epsilon checks before dividing by speed
3. **Safe Defaults**: Return zero vectors when normalization would fail


### Boundary Conditions

1. **Map Boundaries**: Position clamped to ±974m, velocity zeroed when hitting boundaries
2. **Depth Limits**: Surface at Y=0 (when target < 1m), maximum depth enforced per submarine class
3. **Speed Limits**: Velocity clamped to 110% of max speed
4. **Angle Limits**: Rudder ±30°, dive planes ±15°, heading normalized to [0, 360)

### Numerical Stability

1. **Force Clamping**: All forces clamped to reasonable maximums
2. **Delta Time**: All time-dependent calculations use delta parameter
3. **Epsilon Comparisons**: Use small epsilon values for floating-point comparisons
4. **Gradual Changes**: Use lerp for smooth transitions (ballast force, velocity alignment)

## Testing Strategy

### Unit Testing

Unit tests will validate specific examples and edge cases:

1. **Coordinate System Tests**:
   - Test heading calculation for cardinal directions (N, E, S, W)
   - Test heading normalization for negative angles and angles > 360°
   - Test heading error calculation for wrap-around cases (350° to 10°)

2. **Drag Calculation Tests**:
   - Test drag with zero velocity (should be zero)
   - Test drag with pure forward motion (no sideways component)
   - Test drag with pure sideways motion (no forward component)
   - Test surface drag at various depths (0m, 2.5m, 5m, 10m)

3. **Appendage Registry Tests**:
   - Test adding and removing appendages
   - Test total drag calculation with multiple appendages
   - Test clamping at 100% maximum increase

4. **Boundary Tests**:
   - Test position clamping at each boundary
   - Test velocity zeroing when hitting boundaries
   - Test corner cases (hitting two boundaries simultaneously)

5. **NaN Recovery Tests**:
   - Inject NaN into position, velocity, angular velocity
   - Verify system detects and recovers
   - Verify error logging occurs

### Property-Based Testing

Property tests will validate universal properties across all inputs using a property-based testing library (GDScript doesn't have a standard PBT library, so we'll use a custom implementation or adapt from Python's Hypothesis patterns).

Each property test will:
- Run minimum 100 iterations with randomized inputs
- Generate valid submarine states, velocities, and configurations
- Verify the property holds for all generated inputs
- Tag tests with feature name and property number

**Test Configuration:**
```gdscript
# Example property test structure
func test_property_1_heading_calculation():
    # Feature: submarine-physics-v2, Property 1: Heading Calculation Consistency
    for i in range(100):
        var random_transform = generate_random_transform()
        var heading = CoordinateSystem.calculate_heading(random_transform)
        assert(heading >= 0.0 and heading < 360.0)
        # Verify heading matches expected direction...
```


**Property Test Generators:**

1. **Random Submarine State**: Generate valid position, velocity, rotation within operational limits
2. **Random Heading**: Generate angles in [0, 360) range
3. **Random Speed**: Generate speeds in [0, max_speed * 1.2] range
4. **Random Depth**: Generate depths in [-5, max_depth] range
5. **Random Appendage Set**: Generate random combinations of appendages
6. **Random Transform**: Generate valid 3D transforms with various orientations

**Property Test Coverage:**

- Property 1-2: Coordinate system (100 random transforms)
- Property 3-4: Propulsion (100 random velocities and headings)
- Property 5-6: Drag (100 random velocities and configurations)
- Property 7-9: Steering (100 random heading errors and speeds)
- Property 10-11: Velocity correction (100 random velocities)
- Property 12-13: Depth control (100 random depths and speeds)
- Property 14: Buoyancy (100 random positions and wave heights)
- Property 15-16: Clamping and boundaries (100 random positions and velocities)
- Property 17: NaN detection (inject NaN in various states)
- Property 18: Surface drag (100 random depths)
- Property 19: Appendage drag (100 random appendage combinations)
- Property 20: Dive planes (100 random speeds and plane angles)

### Integration Testing

Integration tests will validate end-to-end behavior:

1. **Straight Line Travel**: Set target heading, verify submarine travels straight without sideways drift
2. **Turn Execution**: Set new heading, verify submarine turns in correct direction and reaches target
3. **Depth Change**: Set new depth, verify submarine reaches target depth without oscillation
4. **Speed Change**: Set new speed, verify submarine reaches target speed within 5 seconds
5. **Surface Operations**: Verify wave interaction and surface drag when at shallow depth
6. **Boundary Behavior**: Drive submarine to boundary, verify it stops correctly
7. **Appendage Deployment**: Deploy towed array, verify speed reduction
8. **Low-Speed Maneuvers**: Verify limited steering and dive plane effectiveness at low speeds

### Performance Testing

1. **Frame Time**: Verify physics update completes within 1ms on target hardware
2. **Memory Allocation**: Verify no allocations during physics updates
3. **Cache Efficiency**: Verify forward direction is cached and reused within frame

## Implementation Notes

### Migration from V1

The new physics engine maintains API compatibility with the existing system:

1. **Same Initialization**: `initialize(body, ocean, state)` unchanged
2. **Same Update**: `update_physics(delta)` unchanged
3. **Same State Query**: `get_submarine_state()` returns same dictionary structure
4. **New Features**: Additional methods for appendage drag management

### Performance Optimizations

1. **Forward Direction Caching**: Calculated once per frame, reused by all systems
2. **Early Exits**: Skip expensive calculations when not needed (wave sampling when deep)
3. **Squared Length**: Use `length_squared()` instead of `length()` when possible
4. **Conditional Logging**: Only log warnings for severe issues

### Debug Mode

A debug flag enables verbose logging for development:

```gdscript
var debug_mode: bool = false

func _log_debug(message: String) -> void:
    if debug_mode:
        print(message)
```

This allows detailed physics telemetry during development without impacting production performance.

## Future Enhancements

### Advanced Water Flow Modeling

The current design uses simplified water flow calculations (submarine's forward speed) for control surface effectiveness. Future enhancements could include:

1. **Relative Flow Velocity**: Calculate actual water flow over each control surface accounting for:
   - Submarine's linear velocity
   - Submarine's angular velocity (creates different flow at bow vs stern)
   - Ocean currents (if implemented)
   - Propeller wash effects

2. **Control Surface Interaction**: Model how rudder deflection affects flow over stern planes and vice versa

3. **Stall Conditions**: Model control surface stall at extreme angles (>30° for rudders, >15° for planes)

4. **Dynamic Pressure Distribution**: Calculate pressure distribution along hull affecting control authority

**Current Simplification Rationale:**
- Uses submarine's forward speed as proxy for water flow velocity
- Assumes flow is aligned with submarine's longitudinal axis
- Sufficient for gameplay realism while maintaining performance
- Captures essential behavior: no motion = no control authority
- Can be enhanced later without changing the component architecture
