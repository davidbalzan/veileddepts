# Requirements Document: Submarine Physics Engine v2

## Introduction

This document specifies the requirements for a realistic submarine physics engine that simulates hydrodynamic forces, propulsion, steering, and depth control. The system replaces the existing physics implementation with a more stable, physically accurate approach that eliminates sideways drift, provides speed-dependent steering, and maintains consistency with the unified coordinate system.

## Glossary

- **Submarine_Body**: The RigidBody3D representing the physical submarine with mass, velocity, and rotation
- **Propulsion_System**: The propeller and motor system that generates forward thrust along the submarine's longitudinal axis
- **Rudder_System**: The control surfaces that generate turning moments proportional to water flow speed
- **Ballast_System**: The depth control mechanism that adjusts buoyancy to change submarine depth
- **Dive_Planes**: Control surfaces (bow planes and stern planes) that generate pitch moments to control depth changes
- **Bow_Planes**: Forward control surfaces that generate pitch torque for depth control
- **Stern_Planes**: Aft control surfaces that generate pitch torque for depth control
- **Hydrodynamic_Drag**: Resistance forces opposing submarine motion through water, proportional to velocity squared
- **Base_Drag**: The inherent drag from the submarine hull shape
- **Appendage_Drag**: Additional drag from extended equipment (periscopes, masts, towed arrays, antennas)
- **Surface_Drag**: Increased drag when operating at or near the surface due to wave interaction
- **Towed_Array**: A sonar sensor cable deployed behind the submarine that increases drag significantly
- **Coordinate_System**: The unified navigation system where North=0°, East=90°, South=180°, West=270°
- **Forward_Direction**: The submarine's longitudinal axis pointing toward the bow (-Z in Godot coordinates)
- **Sideways_Velocity**: Velocity component perpendicular to the submarine's longitudinal axis
- **Water_Flow_Speed**: The relative velocity of water flowing past the submarine hull and control surfaces
- **Turning_Rate**: Angular velocity around the vertical axis (yaw rate) measured in degrees per second
- **Depth_Rate**: Vertical velocity measured in meters per second (positive = descending)
- **Alignment_Factor**: Dot product between velocity direction and forward direction (1.0 = perfect alignment)

## Requirements

### Requirement 1: Coordinate System Integration

**User Story:** As a developer, I want the physics engine to use the unified coordinate system consistently, so that all navigation calculations are synchronized and correct.

#### Acceptance Criteria

1. THE Submarine_Body SHALL use the standard heading calculation: `heading = atan2(forward.x, -forward.z)`
2. WHEN calculating Forward_Direction, THE system SHALL use `-submarine_body.global_transform.basis.z`
3. WHEN applying steering torque, THE system SHALL negate the torque to account for Godot's left-hand Y-axis rotation
4. THE system SHALL normalize all heading values to the range [0, 360) degrees
5. WHEN converting between 3D vectors and 2D navigation, THE system SHALL use X for East-West and Z for North-South

### Requirement 2: Propulsion Force Application

**User Story:** As a submarine commander, I want propulsion to push the submarine forward along its axis, so that thrust is always aligned with the submarine's orientation.

#### Acceptance Criteria

1. THE Propulsion_System SHALL apply force exclusively along the Forward_Direction vector
2. WHEN target speed is set, THE Propulsion_System SHALL calculate speed error along the Forward_Direction only
3. THE Propulsion_System SHALL use PID control with proportional gain between 1.0 and 2.0
4. WHEN the submarine is misaligned with target heading by more than 30 degrees, THE Propulsion_System SHALL reduce thrust to 50% of maximum
5. THE Propulsion_System SHALL clamp total thrust to the range [-0.5 * max_thrust, 1.0 * max_thrust]
6. THE Propulsion_System SHALL NOT apply feedforward compensation during turns (alignment < 0.9)

### Requirement 3: Hydrodynamic Drag Forces

**User Story:** As a physics simulation, I want drag forces to resist motion realistically, so that submarines slow down naturally and sideways motion is heavily penalized.

#### Acceptance Criteria

1. THE Hydrodynamic_Drag SHALL calculate forward drag as `(base_forward_drag + appendage_drag + surface_drag) * forward_speed^2`
2. THE Hydrodynamic_Drag SHALL calculate sideways drag as `sideways_drag_coef * sideways_speed^2`
3. THE sideways_drag_coef SHALL be at least 400 times larger than base_forward_drag
4. THE Hydrodynamic_Drag SHALL decompose velocity into forward and sideways components relative to Forward_Direction
5. THE Hydrodynamic_Drag SHALL apply drag forces separately along forward and sideways axes
6. WHEN speed is below 0.01 m/s, THE Hydrodynamic_Drag SHALL skip calculations to prevent numerical instability
7. THE system SHALL support dynamic modification of drag coefficients during runtime
8. THE system SHALL provide methods to add or remove Appendage_Drag contributions

### Requirement 20: Surface Drag Penalty

**User Story:** As a submarine commander, I want reduced speed when operating at the surface, so that the simulation reflects that modern submarines are optimized for submerged operations.

#### Acceptance Criteria

1. WHEN the submarine is at depth less than 5 meters, THE system SHALL apply Surface_Drag
2. THE Surface_Drag SHALL increase forward drag coefficient by 50% when fully surfaced
3. THE Surface_Drag SHALL scale linearly from 0% at 5 meters depth to 50% at surface
4. THE Surface_Drag SHALL account for wave interaction and hull form drag
5. THE system SHALL reduce maximum effective speed by approximately 20% when surfaced
6. WHEN the submarine submerges below 5 meters, THE Surface_Drag SHALL fade to zero

### Requirement 21: Appendage Drag System

**User Story:** As a game designer, I want to model drag from extended equipment, so that tactical decisions about sensor deployment have realistic consequences.

#### Acceptance Criteria

1. THE system SHALL maintain a registry of active appendages with individual drag contributions
2. WHEN a periscope is raised, THE system SHALL add periscope Appendage_Drag (5% increase)
3. WHEN a radar mast is raised, THE system SHALL add radar mast Appendage_Drag (3% increase)
4. WHEN a Towed_Array is deployed, THE system SHALL add towed array Appendage_Drag (25% increase)
5. WHEN an ESM mast is raised, THE system SHALL add ESM mast Appendage_Drag (2% increase)
6. THE system SHALL calculate total Appendage_Drag as the sum of all active appendage contributions
7. THE system SHALL allow appendages to be added or removed dynamically during gameplay
8. THE system SHALL provide a method `add_appendage_drag(name: String, drag_multiplier: float)`
9. THE system SHALL provide a method `remove_appendage_drag(name: String)`
10. THE system SHALL clamp total Appendage_Drag to prevent unrealistic values (max 100% increase)

### Requirement 4: Speed-Dependent Steering

**User Story:** As a submarine commander, I want steering effectiveness to depend on water flow speed, so that the submarine cannot turn when stationary and turns more effectively at higher speeds.

#### Acceptance Criteria

1. THE Rudder_System SHALL calculate steering torque as `torque = -speed_factor * rudder_angle * torque_coefficient`
2. THE Rudder_System SHALL use Water_Flow_Speed equal to the absolute value of forward velocity (simplified model)
3. WHEN Water_Flow_Speed is below 0.5 m/s, THE Rudder_System SHALL reduce effectiveness to 20% of normal
4. THE Rudder_System SHALL clamp rudder angle to the range [-30°, +30°]
5. THE Rudder_System SHALL calculate rudder angle proportional to heading error with maximum at ±30°
6. THE Rudder_System SHALL cap speed_factor at 8.0 m/s to prevent excessive turning at high speeds
7. THE Rudder_System SHALL model hydrodynamic force on rudder as proportional to water flow velocity and rudder deflection angle

### Requirement 5: Turn Rate Limiting

**User Story:** As a submarine commander, I want realistic turn rates, so that large submarines turn slowly and maneuvers feel authentic.

#### Acceptance Criteria

1. THE Rudder_System SHALL limit maximum Turning_Rate to 5 degrees per second for default submarine class
2. WHEN Turning_Rate exceeds the maximum, THE Rudder_System SHALL apply strong damping torque proportional to excess rotation
3. THE Rudder_System SHALL apply stability damping proportional to angular velocity even within normal turn rates
4. THE Rudder_System SHALL scale maximum Turning_Rate based on submarine class (faster for smaller submarines)
5. WHEN heading error is less than 5 degrees, THE Rudder_System SHALL reduce steering input to prevent oscillation

### Requirement 6: Sideways Motion Elimination

**User Story:** As a submarine commander, I want the submarine to move in the direction it's pointing, so that navigation is predictable and realistic.

#### Acceptance Criteria

1. THE system SHALL calculate Sideways_Velocity as the velocity component perpendicular to Forward_Direction
2. WHEN Sideways_Velocity exceeds 0.5 m/s, THE system SHALL apply direct velocity correction
3. THE system SHALL reduce Sideways_Velocity by 80% per frame while preserving forward speed
4. THE system SHALL NOT use force-based anti-slip (which creates instability)
5. THE system SHALL apply velocity correction by directly modifying `submarine_body.linear_velocity`
6. WHEN Sideways_Velocity is below 0.5 m/s, THE system SHALL skip correction to reduce computational overhead

### Requirement 7: Velocity Alignment

**User Story:** As a physics simulation, I want velocity direction to gradually align with submarine heading, so that major misalignments are corrected without fighting other systems.

#### Acceptance Criteria

1. THE system SHALL calculate Alignment_Factor as the dot product of velocity direction and Forward_Direction
2. WHEN Alignment_Factor is above 0.7, THE system SHALL skip alignment correction
3. WHEN Alignment_Factor is below 0.7, THE system SHALL apply gradual velocity direction correction
4. THE system SHALL use lerp with 10% correction rate per frame for velocity alignment
5. THE system SHALL preserve horizontal speed magnitude during alignment correction
6. THE system SHALL preserve vertical velocity component (Y-axis) during alignment correction

### Requirement 8: Depth Control System

**User Story:** As a submarine commander, I want smooth depth changes without oscillation, so that I can maintain precise depth control.

#### Acceptance Criteria

1. THE Ballast_System SHALL use PID control with Kp=0.3, Ki=0.005, Kd=1.2
2. THE Ballast_System SHALL implement a dead zone of 0.5 meters around target depth
3. WHEN depth error is within the dead zone, THE Ballast_System SHALL set control output to zero
4. THE Ballast_System SHALL apply vertical damping force proportional to vertical velocity
5. THE Dive_Planes SHALL apply pitch angle proportional to depth error (max ±5.7 degrees)
6. WHEN depth error is less than 1 meter, THE Dive_Planes SHALL level the submarine pitch to zero
7. THE Dive_Planes SHALL generate pitch torque proportional to Water_Flow_Speed (no effect when stationary)
8. THE Bow_Planes SHALL contribute 40% of total pitch control torque
9. THE Stern_Planes SHALL contribute 60% of total pitch control torque
10. WHEN diving, THE Dive_Planes SHALL pitch the submarine nose-down to assist descent
11. WHEN surfacing, THE Dive_Planes SHALL pitch the submarine nose-up to assist ascent

### Requirement 9: Buoyancy and Surface Behavior

**User Story:** As a submarine commander, I want realistic surface behavior with wave interaction, so that surfaced operations feel dynamic.

#### Acceptance Criteria

1. THE system SHALL calculate buoyancy force using Archimedes' principle based on displaced volume
2. THE system SHALL calculate submersion ratio based on hull depth relative to wave surface
3. WHEN the submarine is at the surface, THE system SHALL apply spring forces to follow wave height
4. WHEN the submarine is deeper than 10 meters, THE system SHALL disable wave influence
5. THE system SHALL apply wave-induced roll and pitch torques when at the surface
6. WHEN target depth is less than 1 meter, THE system SHALL allow surfacing to Y=0

### Requirement 10: Velocity Clamping

**User Story:** As a physics simulation, I want to prevent excessive speeds, so that submarines don't run off the map or exceed realistic limits.

#### Acceptance Criteria

1. THE system SHALL clamp velocity magnitude to 110% of maximum speed
2. WHEN velocity exceeds the clamp threshold, THE system SHALL normalize and scale velocity
3. THE system SHALL only log warnings when velocity exceeds 120% of maximum speed
4. THE system SHALL apply velocity clamping after all other physics calculations
5. THE system SHALL preserve velocity direction when clamping magnitude

### Requirement 11: Map Boundary Enforcement

**User Story:** As a game system, I want to prevent submarines from leaving the playable area, so that gameplay remains within the terrain bounds.

#### Acceptance Criteria

1. THE system SHALL enforce map boundaries at ±974 meters from origin (50m buffer from 1024m terrain edge)
2. WHEN the submarine reaches a boundary, THE system SHALL clamp position to the boundary
3. WHEN the submarine reaches a boundary, THE system SHALL zero velocity components pointing outward
4. THE system SHALL check both X and Z boundaries independently
5. THE system SHALL log warnings only when boundaries are actually hit

### Requirement 12: Physics Update Order

**User Story:** As a physics simulation, I want deterministic update order, so that physics calculations are stable and predictable.

#### Acceptance Criteria

1. THE system SHALL execute physics updates in this order: buoyancy, drag, propulsion, depth control, sideways elimination, velocity alignment, velocity clamping, boundary enforcement
2. THE system SHALL perform all calculations in a single physics frame
3. THE system SHALL use delta time for time-dependent calculations
4. THE system SHALL cache Forward_Direction once per frame to avoid redundant calculations
5. THE system SHALL validate all vectors for NaN before applying forces

### Requirement 13: Submarine Class Configurations

**User Story:** As a game designer, I want different submarine classes with distinct performance characteristics, so that gameplay variety is supported.

#### Acceptance Criteria

1. THE system SHALL support configurable parameters: mass, max_speed, max_depth, propulsion_force_max, base drag coefficients, rudder effectiveness, dive plane effectiveness
2. THE system SHALL provide presets for: Los Angeles Class, Ohio Class, Virginia Class, Seawolf Class, and Default
3. WHEN a submarine class is loaded, THE system SHALL update all physics parameters
4. THE system SHALL scale Turning_Rate limits based on submarine mass (lighter = faster turns)
5. THE system SHALL scale propulsion force based on submarine class specifications
6. THE system SHALL configure surface speed penalties per submarine class (some classes handle surface operations better)
7. THE system SHALL allow custom submarine configurations to be defined at runtime

### Requirement 14: Debug and Telemetry

**User Story:** As a developer, I want minimal debug output during normal operation, so that logs remain readable and performance is not impacted.

#### Acceptance Criteria

1. THE system SHALL only log warnings for severe issues (NaN detection, boundary hits, major speed violations)
2. THE system SHALL only log sideways velocity corrections when exceeding 3.0 m/s
3. THE system SHALL only log velocity alignment corrections when Alignment_Factor is below 0.3
4. THE system SHALL only log low-speed steering warnings when heading error exceeds 10 degrees
5. THE system SHALL provide a debug mode flag that enables verbose logging when needed

### Requirement 15: Performance Requirements

**User Story:** As a game system, I want physics calculations to be efficient, so that frame rates remain high.

#### Acceptance Criteria

1. THE system SHALL complete all physics calculations within 1 millisecond per frame on target hardware
2. THE system SHALL cache frequently used values (Forward_Direction) to avoid redundant calculations
3. THE system SHALL skip expensive calculations when conditions don't require them (wave sampling when deep)
4. THE system SHALL use squared length comparisons instead of length when possible
5. THE system SHALL avoid allocating new objects during physics updates

### Requirement 16: Numerical Stability

**User Story:** As a physics simulation, I want stable calculations that don't produce NaN or infinite values, so that the simulation never crashes or behaves erratically.

#### Acceptance Criteria

1. THE system SHALL check all vectors for `is_finite()` before applying forces
2. WHEN NaN is detected in submarine state, THE system SHALL reset to safe values and log an error
3. THE system SHALL check vector length before normalizing to prevent division by zero
4. THE system SHALL clamp all force magnitudes to prevent extreme values
5. THE system SHALL use safe defaults when calculations would produce undefined results

### Requirement 17: Integration with Existing Systems

**User Story:** As a developer, I want the new physics engine to integrate seamlessly with existing code, so that migration is smooth.

#### Acceptance Criteria

1. THE system SHALL maintain the same public interface as the existing SubmarinePhysics class
2. THE system SHALL accept the same initialization parameters: submarine_body, ocean_renderer, simulation_state
3. THE system SHALL provide the same `get_submarine_state()` method returning position, velocity, depth, heading, speed
4. THE system SHALL respond to the same control inputs: target_speed, target_heading, target_depth
5. THE system SHALL be a drop-in replacement requiring no changes to calling code

### Requirement 18: Testing and Validation

**User Story:** As a developer, I want to validate physics behavior, so that I can ensure the new engine works correctly.

#### Acceptance Criteria

1. THE system SHALL maintain constant depth when target depth is set and no other forces are applied
2. THE system SHALL turn in the correct direction (right for positive heading error, left for negative)
3. THE system SHALL not move sideways when traveling in a straight line
4. THE system SHALL require forward motion to turn effectively (no turning when stationary)
5. THE system SHALL require forward motion for dive planes to be effective (no pitch control when stationary)
6. THE system SHALL reach target speed within 5 seconds when no obstacles are present
7. THE system SHALL complete a 180-degree turn within 60 seconds at cruising speed
8. THE system SHALL reach target depth within 30 seconds when changing depth by 50 meters
9. THE system SHALL not exceed map boundaries under any normal operating conditions
10. THE system SHALL not produce NaN values under any combination of inputs

### Requirement 19: Dive Plane Physics

**User Story:** As a submarine commander, I want dive planes that respond to water flow, so that depth control feels realistic and speed-dependent.

#### Acceptance Criteria

1. THE Dive_Planes SHALL generate pitch torque proportional to plane angle and Water_Flow_Speed squared
2. THE Dive_Planes SHALL have maximum effectiveness at speeds above 5 m/s
3. WHEN Water_Flow_Speed is below 1 m/s, THE Dive_Planes SHALL have minimal effectiveness (less than 10%)
4. THE Dive_Planes SHALL clamp plane angles to the range [-15°, +15°]
5. THE Dive_Planes SHALL calculate plane angle based on depth error and desired Depth_Rate
6. THE Dive_Planes SHALL work in conjunction with Ballast_System for optimal depth control
7. WHEN the submarine is at high speed, THE Dive_Planes SHALL be the primary depth control mechanism
8. WHEN the submarine is at low speed, THE Ballast_System SHALL be the primary depth control mechanism
9. THE Dive_Planes SHALL model hydrodynamic lift force as proportional to water flow velocity squared and plane deflection angle
