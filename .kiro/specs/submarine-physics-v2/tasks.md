# Implementation Plan: Submarine Physics Engine v2

## Overview

This plan implements a realistic submarine physics engine with speed-dependent control surfaces, extensible drag modeling, and numerical stability guarantees. The implementation follows a component-based architecture with clear separation of concerns.

## Tasks

- [x] 1. Create coordinate system utility module
  - Create `scripts/physics/coordinate_system.gd` with static utility functions
  - Implement `calculate_heading(forward_dir: Vector3) -> float` using `atan2(x, -z)`
  - Implement `normalize_heading(heading: float) -> float` to [0, 360) range
  - Implement `heading_error(current: float, target: float) -> float` with shortest path
  - Implement `forward_direction_from_transform(transform: Transform3D) -> Vector3`
  - Implement `heading_to_vector2(heading: float) -> Vector2` for UI display
  - _Requirements: 1.1, 1.4_

- [x]* 1.1 Write property test for coordinate system
  - **Property 1: Heading Calculation Consistency**
  - **Validates: Requirements 1.1, 1.4**
  - Generate 100 random submarine transforms
  - Verify heading is in [0, 360) range
  - Verify heading matches expected direction for cardinal points
  - Verify heading normalization works for negative and >360 angles

- [x] 2. Create appendage drag registry
  - Create `scripts/physics/appendage_drag_registry.gd`
  - Implement `add_appendage(name: String, multiplier: float) -> void`
  - Implement `remove_appendage(name: String) -> void`
  - Implement `get_total_drag_multiplier() -> float` with clamping to 2.0
  - Implement `clear_all() -> void` and `has_appendage(name: String) -> bool`
  - _Requirements: 21.6, 21.7, 21.8, 21.9, 21.10_

- [ ]* 2.1 Write property test for appendage drag summation
  - **Property 19: Appendage Drag Summation**
  - **Validates: Requirements 21.6, 21.10**
  - Generate 100 random appendage combinations
  - Verify total equals sum of individual multipliers
  - Verify total is clamped to maximum of 2.0

- [x] 3. Create hydrodynamic drag component
  - Create `scripts/physics/hydrodynamic_drag.gd`
  - Implement forward/sideways velocity decomposition
  - Implement surface drag calculation based on depth (linear scale 0-5m)
  - Implement drag formula: `(base + appendage + surface) * speed^2`
  - Ensure sideways drag coefficient is 400x forward drag
  - Add early exit for speeds < 0.01 m/s
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 20.1, 20.2, 20.3_


- [ ]* 3.1 Write property tests for drag calculations
  - **Property 5: Drag Formula Correctness**
  - **Property 6: Sideways Drag Dominance**
  - **Property 18: Surface Drag Scaling**
  - **Validates: Requirements 3.1, 3.2, 3.3, 20.1, 20.2, 20.3**
  - Generate 100 random velocities, depths, and appendage configs
  - Verify forward drag formula is correct
  - Verify sideways drag formula is correct
  - Verify sideways coefficient >= 400x forward coefficient
  - Verify surface drag scales linearly from 0-5m depth

- [x] 4. Create propulsion system component
  - Create `scripts/physics/propulsion_system.gd`
  - Implement PID speed control along forward axis only
  - Implement alignment factor calculation (velocity dot forward direction)
  - Implement thrust reduction when misaligned > 30° (reduce to 50%)
  - Clamp thrust to [-0.5 * max, 1.0 * max]
  - Skip feedforward compensation when alignment < 0.9
  - Return force vector along forward direction
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ]* 4.1 Write property tests for propulsion
  - **Property 3: Propulsion Alignment**
  - **Property 4: Thrust Reduction During Turns**
  - **Validates: Requirements 2.1, 2.2, 2.4**
  - Generate 100 random velocities and headings
  - Verify propulsion force is parallel to forward direction
  - Verify speed error calculated along forward axis only
  - Verify thrust reduced to <=50% when misaligned >30°

- [x] 5. Create rudder system component
  - Create `scripts/physics/rudder_system.gd`
  - Implement heading error calculation (shortest path)
  - Calculate rudder angle proportional to error, clamp to ±30°
  - Calculate water flow speed from forward velocity
  - Apply low-speed penalty: <0.5 m/s = 20% effectiveness
  - Cap speed factor at 8.0 m/s
  - Calculate torque: `-speed_factor * rudder_angle * torque_coef`
  - Implement turn rate limiting (5°/s default)
  - Apply stability damping
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4_

- [ ]* 5.1 Write property tests for rudder system
  - **Property 2: Steering Direction Correctness**
  - **Property 7: Rudder Torque Formula**
  - **Property 8: Low-Speed Steering Penalty**
  - **Property 9: Turn Rate Limiting**
  - **Validates: Requirements 1.3, 4.1, 4.3, 4.6, 5.1, 18.2, 18.4**
  - Generate 100 random heading errors and speeds
  - Verify positive error → negative torque (right turn)
  - Verify torque formula is correct
  - Verify effectiveness <=20% when speed <0.5 m/s
  - Verify angular velocity never exceeds max turn rate

- [x] 6. Create dive plane system component
  - Create `scripts/physics/dive_plane_system.gd`
  - Calculate desired pitch angle from depth error
  - Calculate water flow speed effectiveness (0-10% below 1 m/s, 100% above 5 m/s)
  - Clamp plane angles to ±15°
  - Calculate pitch torque: `angle * speed^2 * effectiveness`
  - Split torque: 40% bow planes, 60% stern planes
  - Return total pitch torque
  - _Requirements: 8.5, 8.7, 8.8, 8.9, 8.10, 8.11, 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 19.7, 19.8_

- [ ]* 6.1 Write property tests for dive planes
  - **Property 13: Dive Plane Speed Dependency**
  - **Property 20: Dive Plane Torque Formula**
  - **Validates: Requirements 8.7, 19.1, 19.2, 19.3, 18.5**
  - Generate 100 random speeds and plane angles
  - Verify torque proportional to speed (near zero at low speeds)
  - Verify <10% effectiveness below 1 m/s
  - Verify 100% effectiveness above 5 m/s
  - Verify torque formula is correct
  - Verify 40/60 split between bow and stern planes


- [x] 7. Create ballast system component
  - Create `scripts/physics/ballast_system.gd`
  - Implement PID depth control (Kp=0.3, Ki=0.005, Kd=1.2)
  - Implement dead zone of ±0.5m around target depth
  - Reset integral term when in dead zone
  - Calculate desired depth rate and rate error
  - Convert PID output to ballast force
  - Apply vertical damping: `-vertical_velocity * 80000`
  - Smooth ballast force changes with lerp
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.6_

- [ ]* 7.1 Write property test for depth control dead zone
  - **Property 12: Depth Control Dead Zone**
  - **Validates: Requirements 8.2**
  - Generate 100 random depth errors
  - Verify control output is zero when |error| < 0.5m
  - Verify control output is non-zero when |error| >= 0.5m

- [x] 8. Create buoyancy system component
  - Create `scripts/physics/buoyancy_system.gd`
  - Calculate wave height from ocean renderer
  - Calculate submersion ratio based on hull depth vs water surface
  - Calculate buoyancy: `density * volume * submersion * 9.81`
  - Calculate wave influence factor (fades with depth >10m)
  - Apply spring force to follow waves at surface
  - Apply wave-induced roll/pitch torques at surface
  - Apply vertical stabilization when deep
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

- [ ]* 8.1 Write property test for buoyancy calculation
  - **Property 14: Buoyancy Calculation**
  - **Validates: Requirements 9.1, 9.2**
  - Generate 100 random positions and wave heights
  - Verify buoyancy formula is correct
  - Verify submersion ratio calculation is correct

- [x] 9. Create physics validator component
  - Create `scripts/physics/physics_validator.gd`
  - Implement `validate_vector(v: Vector3, name: String) -> bool`
  - Implement `validate_and_fix_submarine_state(body: RigidBody3D) -> bool`
  - Implement `clamp_velocity(body: RigidBody3D, max_speed: float) -> void`
  - Implement `enforce_boundaries(body: RigidBody3D, boundary: float) -> void`
  - Check all vectors with `is_finite()` before use
  - Check vector length before normalizing
  - Reset NaN states to safe defaults
  - Log errors without spamming console
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 11.1, 11.2, 11.3, 11.4, 11.5, 16.1, 16.2, 16.3, 16.4, 16.5_

- [ ]* 9.1 Write property tests for validation
  - **Property 15: Velocity Clamping**
  - **Property 16: Boundary Enforcement**
  - **Property 17: NaN Detection and Recovery**
  - **Validates: Requirements 10.1, 11.1, 11.3, 16.1, 16.2**
  - Generate 100 random velocities and positions
  - Verify velocity clamped to 110% of max speed
  - Verify position clamped to ±974m boundaries
  - Verify outward velocity zeroed at boundaries
  - Inject NaN values and verify detection and recovery

- [x] 10. Create main SubmarinePhysicsV2 class
  - Create `scripts/physics/submarine_physics_v2.gd`
  - Implement initialization with body, ocean, state references
  - Implement forward direction caching (once per frame)
  - Instantiate all component systems
  - Implement `update_physics(delta)` with correct order
  - Implement `get_submarine_state()` returning position, velocity, depth, heading, speed
  - Implement submarine class configuration system
  - Implement appendage drag management methods
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 17.1, 17.2, 17.3, 17.4, 17.5_


- [x] 11. Implement physics update order
  - In `update_physics(delta)`, call systems in order:
    1. Validate submarine state (detect NaN)
    2. Cache forward direction
    3. Calculate and apply buoyancy forces
    4. Calculate and apply drag forces
    5. Calculate and apply propulsion forces
    6. Calculate and apply rudder torques
    7. Calculate and apply dive plane torques
    8. Calculate and apply ballast forces
    9. Apply sideways velocity elimination
    10. Apply velocity alignment
    11. Clamp velocity
    12. Enforce boundaries
  - _Requirements: 12.1_

- [x] 12. Implement sideways velocity elimination
  - Calculate sideways velocity component perpendicular to forward direction
  - If |sideways_velocity| > 0.5 m/s, apply direct velocity correction
  - Reduce sideways component by 80% per frame
  - Preserve forward speed magnitude
  - Directly modify `submarine_body.linear_velocity`
  - Log only when sideways velocity > 3.0 m/s
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

- [ ]* 12.1 Write property test for sideways elimination
  - **Property 10: Sideways Velocity Elimination**
  - **Validates: Requirements 6.2, 6.3, 18.3**
  - Generate 100 random velocities with sideways components
  - Verify correction applied when |sideways| > 0.5 m/s
  - Verify sideways reduced by 80%
  - Verify forward speed preserved

- [x] 13. Implement velocity alignment (done)
  - Calculate alignment factor: `velocity_dir.dot(forward_dir)`
  - Skip if alignment > 0.7 or speed < 1.0 m/s
  - Skip if speed > max_speed * 1.05
  - Calculate desired horizontal velocity aligned with heading
  - Apply gradual correction with 10% lerp rate
  - Preserve vertical velocity component
  - Log only when alignment < 0.3
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

- [ ]* 13.1 Write property test for velocity alignment
  - **Property 11: Velocity Alignment Threshold**
  - **Validates: Requirements 7.2**
  - Generate 100 random velocities
  - Verify correction skipped when alignment > 0.7
  - Verify correction applied when alignment <= 0.7

- [x] 14. Implement submarine class presets
  - Define configurations for Los Angeles, Ohio, Virginia, Seawolf, Default classes
  - Include: mass, max_speed, max_depth, propulsion_force, drag coefficients, rudder/dive plane effectiveness
  - Implement `configure_submarine_class(config: Dictionary)`
  - Implement `load_submarine_class(class_name: String) -> bool`
  - Implement `get_available_classes() -> Array[String]`
  - Update all component parameters when class is loaded
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

- [x] 15. Implement debug mode and logging
  - Add `debug_mode: bool` flag (default false)
  - Implement `_log_debug(message: String)` that checks flag
  - Use minimal logging in production (only severe issues)
  - Log sideways velocity only when > 3.0 m/s
  - Log velocity alignment only when < 0.3
  - Log low-speed steering only when heading error > 10°
  - Log velocity clamping only when > 120% of max speed
  - Log boundary hits when they occur
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

- [x] 16. Checkpoint - Ensure all component tests pass
  - Run all unit tests and property tests
  - Verify no compilation errors
  - Verify all components integrate correctly
  - Ask user if questions arise


- [ ] 17. Create integration test scene
  - Create `tests/integration/test_submarine_physics_v2.gd`
  - Test straight line travel (no sideways drift)
  - Test turn execution (correct direction, reaches target)
  - Test depth changes (reaches target without oscillation)
  - Test speed changes (reaches target within 5 seconds)
  - Test surface operations (wave interaction, surface drag)
  - Test boundary behavior (stops at boundaries)
  - Test appendage deployment (speed reduction)
  - Test low-speed maneuvers (limited steering/dive planes)
  - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6, 18.7, 18.8, 18.9, 18.10_

- [ ]* 17.1 Write integration tests
  - Test straight line travel without sideways drift
  - Test turning in correct direction
  - Test depth control without oscillation
  - Test speed control convergence
  - Test low-speed steering limitation
  - Test low-speed dive plane limitation

- [ ] 18. Update main.gd to use SubmarinePhysicsV2
  - Replace SubmarinePhysics with SubmarinePhysicsV2
  - Verify initialization parameters are compatible
  - Verify update_physics call is compatible
  - Verify get_submarine_state is compatible
  - Test in game to ensure no regressions
  - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5_

- [ ] 19. Performance validation
  - Measure physics update time on target hardware
  - Verify < 1ms per frame
  - Verify no memory allocations during updates
  - Verify forward direction caching works
  - Profile and optimize if needed
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5_

- [ ] 20. Final checkpoint - Complete system validation
  - Run full test suite (unit + property + integration)
  - Test all submarine classes
  - Test appendage drag system
  - Test surface drag penalties
  - Verify coordinate system consistency
  - Verify no NaN issues under stress testing
  - Ask user for final approval

## Notes

- Tasks marked with `*` are optional test tasks that can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end behavior
- Checkpoints ensure incremental validation
