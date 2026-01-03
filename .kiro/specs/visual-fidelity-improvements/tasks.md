# Implementation Plan: Visual Fidelity Improvements

## Overview

This implementation plan breaks down the visual fidelity improvements into discrete, manageable tasks. The plan follows a logical progression: foam system improvements, periscope enhancements, water effects, and camera improvements.

## Tasks

- [ ] 1. Improve foam and bubble system realism
  - [ ] 1.1 Reduce bubble particle lifetimes
    - Modify `SubmarineWake` to set maximum bubble lifetime to 3 seconds
    - Update bow wake, stern wake, and hull foam particle lifetimes
    - _Requirements: 1.1_
  
  - [ ]* 1.2 Write property test for bubble lifetime constraint
    - **Property 1: Bubble Lifetime Constraint**
    - **Validates: Requirements 1.1**
  
  - [ ] 1.3 Implement trail fade-out effect
    - Create alpha curve for wake trail particles
    - Apply curve to `wake_trail` particle material
    - Configure fade from 0.8 to 0.0 over particle lifetime
    - _Requirements: 1.2_
  
  - [ ]* 1.4 Write property test for trail fade monotonicity
    - **Property 2: Trail Fade Monotonicity**
    - **Validates: Requirements 1.2**
  
  - [ ] 1.5 Reduce particle sizes for more detail
    - Reduce `scale_min` and `scale_max` by 50% for all foam particles
    - Update quad mesh sizes proportionally
    - Test visual appearance at various distances
    - _Requirements: 1.3_
  
  - [ ]* 1.6 Write property test for particle scale reduction
    - **Property 3: Particle Scale Reduction**
    - **Validates: Requirements 1.3**
  
  - [ ] 1.7 Add scale curve for bubble growth/dissipation
    - Create scale curve: start at 0.5, peak at 1.0 (20% lifetime), end at 0.3
    - Apply to all bubble particle materials
    - _Requirements: 1.4_

- [ ] 2. Fix periscope model jittering
  - [ ] 2.1 Increase camera smoothing factor
    - Reduce `CAMERA_SMOOTHING` constant from 0.2 to 0.15
    - Test smoothness during submarine maneuvers
    - _Requirements: 2.1, 2.2_
  
  - [ ] 2.2 Implement frame-rate independent smoothing
    - Modify `update_camera_position()` to use delta time
    - Use exponential smoothing: `lerp(current, target, 1.0 - exp(-smoothing * delta))`
    - _Requirements: 2.3_
  
  - [ ]* 2.3 Write property test for camera smoothing
    - **Property 4: Camera Position Smoothing**
    - **Validates: Requirements 2.1, 2.2**
  
  - [ ]* 2.4 Write unit tests for smoothing edge cases
    - Test with very small delta values
    - Test with large position jumps
    - _Requirements: 2.1, 2.2_

- [ ] 3. Refine chromatic aberration effect
  - [ ] 3.1 Implement radial distance-based aberration
    - Modify `periscope_lens.gdshader` to calculate radial distance from center
    - Add `chromatic_aberration_center_radius` uniform (default 0.2)
    - Implement smooth interpolation from 0 at center to max at edges
    - _Requirements: 3.1, 3.2, 3.3_
  
  - [ ] 3.2 Update shader aberration calculation
    - Replace constant aberration with radial function
    - Use `smoothstep` for natural falloff curve
    - Reduce max aberration from 0.01 to 0.015
    - _Requirements: 3.1, 3.2_
  
  - [ ]* 3.3 Write property test for radial aberration gradient
    - **Property 5: Chromatic Aberration Radial Gradient**
    - **Validates: Requirements 3.1, 3.2, 3.3**
  
  - [ ] 3.4 Add configuration parameter for aberration intensity
    - Expose `chromatic_aberration_max` as shader parameter
    - Allow runtime adjustment via material
    - _Requirements: 3.4_

- [ ] 4. Add periscope HUD telemetry display
  - [ ] 4.1 Create PeriscopeHUD component
    - Create new `Control` node in `PeriscopeView`
    - Add `PanelContainer` for telemetry background
    - Position in lower-left corner for minimal obstruction
    - _Requirements: 4.1, 4.2, 4.3_
  
  - [ ] 4.2 Add speed display label
    - Create `Label` for speed display
    - Format as "XX.X kts" (convert m/s to knots: * 1.94384)
    - Update from `simulation_state.submarine_velocity`
    - _Requirements: 4.1_
  
  - [ ] 4.3 Add depth display label
    - Create `Label` for depth display
    - Format as "XXX m" (depth below surface)
    - Update from `simulation_state.submarine_depth`
    - _Requirements: 4.2_
  
  - [ ] 4.4 Add heading display label
    - Create `Label` for heading display
    - Format as "XXX°" (0-360 degrees)
    - Update from `simulation_state.submarine_heading`
    - _Requirements: 4.3_
  
  - [ ] 4.5 Implement real-time telemetry updates
    - Update HUD in `_process()` function
    - Ensure updates occur every frame
    - _Requirements: 4.4_
  
  - [ ]* 4.6 Write property test for HUD update rate
    - **Property 6: HUD Telemetry Update Rate**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**
  
  - [ ] 4.7 Apply naval-style typography and colors
    - Use monospace font for telemetry values
    - Apply green color (#00FF00) with black outline
    - Add semi-transparent dark background panel
    - _Requirements: 4.5_

- [ ] 5. Checkpoint - Test periscope improvements
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement water transition effects
  - [ ] 6.1 Create WaterTransitionEffect component
    - Create new `Node3D` class `WaterTransitionEffect`
    - Add to `PeriscopeView` scene
    - Initialize component references
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [ ] 6.2 Implement surface crossing detection
    - Use `ocean_renderer.get_wave_height_3d()` for accurate detection
    - Compare camera Y position with wave height
    - Add hysteresis to prevent flickering (0.1m threshold)
    - _Requirements: 5.4_
  
  - [ ] 6.3 Create water sheet overlay effect
    - Create `ColorRect` with custom shader for water sheet
    - Implement animated water flow down screen
    - Trigger on emergence from water
    - Duration: 1.5 seconds
    - _Requirements: 5.1_
  
  - [ ] 6.4 Create water droplet particle system
    - Create `GPUParticles3D` for lens droplets
    - Configure 20 droplets with 5-second lifetime
    - Position randomly on screen after emergence
    - _Requirements: 5.2_
  
  - [ ] 6.5 Implement droplet evaporation
    - Apply alpha curve to droplets: fade from 0.8 to 0.0
    - Add slight downward velocity for sliding effect
    - Remove droplets when opacity reaches 0
    - _Requirements: 5.3_
  
  - [ ]* 6.6 Write property test for transition timing
    - **Property 7: Water Transition Timing**
    - **Validates: Requirements 5.5**
  
  - [ ]* 6.7 Write property test for droplet evaporation
    - **Property 8: Droplet Evaporation**
    - **Validates: Requirements 5.3**
  
  - [ ] 6.8 Handle submersion effect
    - Trigger water covering lens when submerging
    - Quick fade to underwater view (0.5 seconds)
    - _Requirements: 5.4_

- [ ] 7. Add orbit camera underwater effects
  - [ ] 7.1 Implement underwater detection for orbit camera
    - Add `detect_camera_underwater()` method to `ExternalView`
    - Use `ocean_renderer.get_wave_height_3d()` at camera position
    - Add hysteresis for smooth transitions
    - _Requirements: 6.1, 6.3_
  
  - [ ] 7.2 Create underwater environment configuration
    - Create `Environment` resource for underwater rendering
    - Configure fog: color (0.1, 0.3, 0.4), density 0.08
    - Configure ambient light: color (0.2, 0.4, 0.5), energy 0.3
    - _Requirements: 6.1, 6.2_
  
  - [ ] 7.3 Implement depth-based fog adjustment
    - Calculate fog density based on camera depth
    - Formula: `base_density + depth * 0.001`
    - Update environment each frame
    - _Requirements: 6.2_
  
  - [ ] 7.4 Implement smooth underwater transition
    - Interpolate between surface and underwater environments
    - Transition duration: 0.5 seconds
    - Use `lerp` for smooth color and density changes
    - _Requirements: 6.3_
  
  - [ ] 7.5 Add visibility range reduction with depth
    - Reduce camera far plane based on depth
    - Formula: `100.0 - depth * 2.0` (clamped to minimum 20m)
    - _Requirements: 6.5_
  
  - [ ]* 7.6 Write property test for depth correlation
    - **Property 9: Underwater Effect Depth Correlation**
    - **Validates: Requirements 6.2, 6.5**
  
  - [ ]* 7.7 Write unit tests for underwater detection
    - Test at surface boundary (y = wave_height)
    - Test at various depths
    - Test hysteresis behavior
    - _Requirements: 6.1, 6.3_

- [ ] 8. Implement orbit camera zoom controls
  - [ ] 8.1 Add keyboard zoom input handling
    - Handle KEY_PLUS and KEY_KP_ADD for zoom in
    - Handle KEY_MINUS and KEY_KP_SUBTRACT for zoom out
    - Implement in `_input()` method of `ExternalView`
    - _Requirements: 7.1, 7.2_
  
  - [ ] 8.2 Implement smooth zoom interpolation
    - Add `target_distance` variable for desired zoom level
    - Interpolate `camera_distance` toward `target_distance`
    - Use smoothing factor 0.1 for gradual zoom
    - _Requirements: 7.3, 7.6_
  
  - [ ] 8.3 Configure keyboard zoom speed
    - Set zoom speed to 10 meters per second
    - Apply speed to distance change on key press
    - Make speed configurable via export variable
    - _Requirements: 7.1, 7.2_
  
  - [ ] 8.4 Maintain zoom distance bounds
    - Clamp target distance to MIN_DISTANCE (10m) and MAX_DISTANCE (500m)
    - Ensure bounds are respected for both keyboard and mouse wheel
    - _Requirements: 7.4, 7.5_
  
  - [ ]* 8.5 Write property test for zoom bounds
    - **Property 10: Zoom Distance Bounds**
    - **Validates: Requirements 7.4, 7.5**
  
  - [ ]* 8.6 Write property test for zoom smoothing
    - **Property 11: Zoom Smoothing Continuity**
    - **Validates: Requirements 7.3, 7.6**
  
  - [ ] 8.7 Preserve orbit angle during zoom
    - Ensure `camera_rotation` and `camera_tilt` remain unchanged
    - Only modify `camera_distance` during zoom
    - _Requirements: 7.6_

- [ ] 9. Final checkpoint - Integration testing
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
