# Implementation Plan: Tactical Submarine Simulator

## Overview

This implementation plan breaks down the tactical submarine simulator into discrete, incremental tasks. The approach follows a bottom-up strategy: establish core systems first (simulation state, view management), then build rendering systems (ocean, terrain, atmosphere), add AI and interactions, and finally integrate everything with polish and testing.

Each task builds on previous work, ensuring no orphaned code. The plan emphasizes getting core functionality working early with property-based tests to catch bugs during development.

## Tasks

- [x] 1. Project Setup and Core Infrastructure
  - Create new Godot 4.6 project with Metal (Mac) and Vulkan (Ubuntu) renderers
  - Set up project structure: scenes/, scripts/, assets/, tests/
  - Install Gut testing framework for unit and property tests
  - Configure input mappings for view switching, submarine controls, camera controls
  - Create main scene with basic node hierarchy
  - _Requirements: 15.1, 15.2, 15.3, 16.1, 16.2_

- [x] 2. Simulation State and Submarine Model
  - [x] 2.1 Implement SimulationState class
    - Create SimulationState.gd with submarine state variables (position, velocity, depth, heading, speed)
    - Implement update methods for submarine commands (waypoint, speed, depth)
    - Add contact tracking with add_contact, update_contact, get_visible_contacts methods
    - _Requirements: 1.2, 1.3, 1.4, 11.1, 11.2, 11.3, 11.4_

  - [ ]* 2.2 Write property test for submarine control clamping
    - **Property 3: Submarine Control Input Clamping**
    - **Validates: Requirements 1.3, 1.4**

  - [x] 2.3 Implement Contact class
    - Create Contact.gd resource with id, type, position, velocity, detected, identified fields
    - Add bearing and range calculation methods
    - _Requirements: 2.1, 2.2, 2.3_

  - [ ]* 2.4 Write property test for waypoint course update
    - **Property 2: Waypoint Course Update**
    - **Validates: Requirements 1.2**

- [x] 3. View Manager and Camera System
  - [x] 3.1 Implement ViewManager class
    - Create ViewManager.gd with ViewType enum (TACTICAL_MAP, PERISCOPE, EXTERNAL)
    - Implement switch_to_view method with camera activation/deactivation
    - Add references to tactical_map_camera (Camera2D), periscope_camera (Camera3D), external_camera (Camera3D)
    - Ensure view transitions complete within 100ms
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ]* 3.2 Write property test for view toggle correctness
    - **Property 9: View Toggle Correctness**
    - **Validates: Requirements 3.1, 3.2, 3.3**

  - [ ]* 3.3 Write property test for view switch state preservation
    - **Property 10: View Switch State Preservation**
    - **Validates: Requirements 3.4**

  - [x] 3.4 Implement camera positioning for each view
    - Position tactical map camera for top-down orthographic view
    - Position periscope camera at submarine mast position
    - Position external camera with orbit controls around submarine
    - _Requirements: 4.1, 5.1_

- [x] 4. Tactical Map View
  - [x] 4.1 Create TacticalMapView UI
    - Create TacticalMapView.gd as CanvasLayer
    - Add submarine icon with position, course, speed, depth display
    - Add contact icons with bearing arcs
    - Implement waypoint placement on mouse click
    - Add speed and depth control sliders
    - _Requirements: 1.1, 1.5, 2.1, 2.2_

  - [ ]* 4.2 Write property test for tactical map display completeness
    - **Property 1: Tactical Map Display Completeness**
    - **Validates: Requirements 1.1**

  - [ ]* 4.3 Write property test for contact display completeness
    - **Property 4: Contact Display Completeness**
    - **Validates: Requirements 1.5**

  - [x] 4.4 Implement coordinate conversion
    - Convert 3D simulation positions to 2D map coordinates
    - Handle map zoom and pan
    - _Requirements: 1.1, 1.5_

- [x] 5. Checkpoint - Core Systems Functional
  - Verify simulation state updates correctly
  - Verify view switching works between all three views
  - Verify tactical map displays submarine and accepts commands
  - Ensure all tests pass, ask the user if questions arise

- [x] 6. Ocean Rendering System
  - [x] 6.1 Integrate godot4-oceanfft addon
    - Fork and add godot4-oceanfft to project
    - Create OceanRenderer.gd wrapper class
    - Configure FFT parameters: grid size, wave spectrum, wind speed/direction
    - _Requirements: 6.1_

  - [x] 6.2 Implement wave height queries
    - Add get_wave_height(position: Vector2) method
    - Implement wave spectrum generation from Phillips spectrum
    - _Requirements: 6.1, 6.3_

  - [x] 6.3 Add foam rendering
    - Compute Jacobian determinant for foam detection
    - Apply foam texture to wave crests
    - _Requirements: 6.2_

  - [x] 6.4 Add caustics and refraction
    - Implement caustics projection shader on sea floor
    - Add refraction shader for underwater viewing
    - _Requirements: 6.4, 6.5_

  - [ ]* 6.5 Write property test for wave-based buoyancy
    - **Property 19: Wave-Based Buoyancy**
    - **Validates: Requirements 6.3**

- [-] 7. Submarine Physics
  - [x] 7.1 Implement SubmarinePhysics class
    - Create SubmarinePhysics.gd with RigidBody3D reference
    - Implement apply_buoyancy using ocean wave heights
    - Implement apply_drag based on velocity squared
    - Implement apply_propulsion for target speed
    - Implement apply_depth_control for target depth
    - _Requirements: 11.1, 11.3, 11.4, 11.5_

  - [ ]* 7.2 Write property test for depth-based physics forces
    - **Property 28: Depth-Based Physics Forces**
    - **Validates: Requirements 11.1**

  - [ ]* 7.3 Write property test for hydrodynamic drag
    - **Property 30: Hydrodynamic Drag Application**
    - **Validates: Requirements 11.3**

  - [ ]* 7.4 Write property test for speed-dependent maneuverability
    - **Property 31: Speed-Dependent Maneuverability**
    - **Validates: Requirements 11.4**

  - [x] 7.5 Integrate submarine physics with simulation state
    - Update simulation state from physics calculations each frame
    - Apply commands from tactical map to physics system
    - _Requirements: 12.1, 12.2_

- [x] 8. Periscope View
  - [x] 8.1 Implement PeriscopeView class
    - Create PeriscopeView.gd with Camera3D reference
    - Implement update_camera_position to track submarine mast
    - Implement handle_rotation_input for periscope rotation
    - Implement handle_zoom_input for FOV adjustment (15° to 90°)
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 8.2 Add lens effect shaders
    - Create periscope shader with distortion, chromatic aberration, vignette
    - Apply shader to periscope camera viewport
    - _Requirements: 5.4_

  - [x] 8.3 Implement underwater rendering mode
    - Detect when submarine depth > periscope depth (10m)
    - Switch to underwater fog and lighting
    - _Requirements: 5.5_

  - [ ]* 8.4 Write property test for periscope camera positioning
    - **Property 16: Periscope Camera Positioning**
    - **Validates: Requirements 5.1**

  - [ ]* 8.5 Write property test for underwater rendering activation
    - **Property 18: Underwater Rendering Activation**
    - **Validates: Requirements 5.5**

- [x] 9. External View and Fog of War
  - [x] 9.1 Implement ExternalView class
    - Create ExternalView.gd with Camera3D reference
    - Implement orbit camera controls (tilt, rotation, distance)
    - Add free camera mode toggle
    - Clamp camera parameters: tilt [-89°, 89°], distance [10m, 500m]
    - _Requirements: 4.2, 4.3, 4.4, 4.5_

  - [ ]* 9.2 Write property test for camera input clamping
    - **Property 11: Camera Input Clamping**
    - **Validates: Requirements 4.2, 4.4, 5.3**

  - [ ]* 9.3 Write property test for external camera orbit behavior
    - **Property 12: External Camera Orbit Behavior**
    - **Validates: Requirements 4.3**

  - [x] 9.4 Implement FogOfWarSystem class
    - Create FogOfWarSystem.gd
    - Implement is_contact_visible method (returns true only if detected AND identified)
    - _Requirements: 4.7, 4.8_

  - [ ]* 9.5 Write property test for fog of war contact visibility
    - **Property 15: Fog of War Contact Visibility**
    - **Validates: Requirements 4.7, 4.8**

  - [x] 9.6 Integrate fog of war with external view rendering
    - Query fog of war system before rendering each contact
    - Always render terrain, ocean, atmosphere, sealife
    - _Requirements: 4.6, 4.7, 4.8_

- [x] 10. Checkpoint - All Views Functional
  - Verify periscope view tracks submarine and responds to input
  - Verify external view orbits submarine with fog of war
  - Verify submarine physics affects all views consistently
  - Ensure all tests pass, ask the user if questions arise

- [x] 11. Terrain System
  - [x] 11.1 Integrate Terrain3D addon
    - Add Terrain3D addon to project
    - Create TerrainRenderer.gd wrapper class
    - _Requirements: 7.1_

  - [x] 11.2 Generate procedural heightmap
    - Implement generate_heightmap using Perlin/Simplex noise
    - Configure terrain size and resolution
    - _Requirements: 7.1_

  - [x] 11.3 Implement LOD system
    - Configure Terrain3D LOD levels (4 levels)
    - Implement update_lod based on camera distance
    - _Requirements: 7.2_

  - [x] 11.4 Add collision detection
    - Generate collision geometry from heightmap
    - Implement get_height_at for collision queries
    - _Requirements: 7.3, 7.5_

  - [ ]* 11.5 Write property test for terrain collision prevention
    - **Property 20: Terrain Collision Prevention**
    - **Validates: Requirements 7.3**

  - [x] 11.6 Add parallax occlusion shader
    - Create terrain shader with parallax occlusion mapping
    - Apply to terrain material
    - _Requirements: 7.4_

- [x] 12. Atmosphere and Lighting
  - [x] 12.1 Implement AtmosphereRenderer class
    - Create AtmosphereRenderer.gd extending WorldEnvironment
    - Configure ProceduralSkyMaterial for sky and clouds
    - Add volumetric fog for clouds
    - _Requirements: 8.1_

  - [x] 12.2 Implement day-night cycle
    - Add time_of_day variable (0-24 hours)
    - Update sun position based on time
    - Adjust sky colors and lighting
    - _Requirements: 8.2_

  - [ ]* 12.3 Write property test for god ray visibility condition
    - **Property 22: God Ray Visibility Condition**
    - **Validates: Requirements 8.3**

  - [x] 12.4 Configure global illumination
    - Enable SDFGI with 4 cascades
    - Configure SSR for water reflections
    - _Requirements: 8.4, 8.5_

- [x] 13. Sealife System
  - [x] 13.1 Implement sealife rendering
    - Create fish school using MultiMeshInstance3D or GPUParticles3D
    - Add simple fish models (low-poly)
    - _Requirements: 9.1_

  - [x] 13.2 Implement sealife culling
    - Add distance-based culling
    - Add foam-based culling (cull in high-foam areas)
    - _Requirements: 9.2, 9.3_

  - [ ]* 13.3 Write property test for sealife culling rules
    - **Property 23: Sealife Culling Rules**
    - **Validates: Requirements 9.2, 9.3**

- [x] 14. AI System
  - [x] 14.1 Implement AIAgent class
    - Create AIAgent.gd with State enum (PATROL, SEARCH, ATTACK)
    - Add NavigationAgent3D for pathfinding
    - Implement state machine with transition logic
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 14.2 Implement patrol behavior
    - Add update_patrol method to follow waypoint routes
    - Implement detection scanning for submarine
    - _Requirements: 10.1_

  - [ ]* 14.3 Write property test for AI patrol route following
    - **Property 24: AI Patrol Route Following**
    - **Validates: Requirements 10.1**

  - [x] 14.4 Implement search behavior
    - Add update_search method to investigate last known position
    - Implement search timeout (60 seconds)
    - _Requirements: 10.2_

  - [ ]* 14.5 Write property test for AI detection state transition
    - **Property 25: AI Detection State Transition**
    - **Validates: Requirements 10.2**

  - [x] 14.6 Implement attack behavior
    - Add update_attack method with dipping sonar pattern
    - Implement attack range checking
    - _Requirements: 10.3_

  - [ ]* 14.7 Write property test for AI attack behavior activation
    - **Property 26: AI Attack Behavior Activation**
    - **Validates: Requirements 10.3**

  - [x] 14.8 Add AI visual effects
    - Add contrails using GPUParticles3D
    - Add shadows on ocean surface
    - _Requirements: 10.4_

  - [x] 14.9 Implement AISystem manager
    - Create AISystem.gd to manage multiple AI agents
    - Add spawn_air_patrol method
    - Integrate with simulation state for submarine detection
    - _Requirements: 10.5_

- [x] 15. Sonar and Detection Systems
  - [x] 15.1 Implement SonarSystem class
    - Create SonarSystem.gd
    - Implement passive sonar detection (bearing only, 5s update)
    - Implement active sonar detection (bearing + range, 2s update)
    - Implement radar detection (bearing + range, 1s update)
    - _Requirements: 2.1, 2.3, 2.4_

  - [ ]* 15.2 Write property test for sonar range detection display
    - **Property 5: Sonar Range Detection Display**
    - **Validates: Requirements 2.1**

  - [ ]* 15.3 Write property test for contact update frequency
    - **Property 8: Contact Update Frequency**
    - **Validates: Requirements 2.4**

  - [x] 15.4 Implement thermal layer effects
    - Add thermal layer simulation affecting detection ranges
    - _Requirements: 11.2_

  - [ ]* 15.5 Write property test for thermal layer detection effects
    - **Property 29: Thermal Layer Detection Effects**
    - **Validates: Requirements 11.2**

- [x] 16. Checkpoint - Simulation Complete
  - Verify AI patrols navigate and detect submarine
  - Verify sonar system detects and tracks contacts
  - Verify terrain collision prevents submarine penetration
  - Ensure all tests pass, ask the user if questions arise

- [ ] 17. Audio System
  - [ ] 17.1 Implement AudioSystem class
    - Create AudioSystem.gd
    - Add AudioStreamPlayer3D for sonar pings
    - Add AudioStreamPlayer3D for propeller sounds
    - Add AudioStreamPlayer for ambient sounds
    - _Requirements: 14.1, 14.2, 14.3_

  - [ ] 17.2 Implement audio triggering
    - Connect sonar detection events to play_sonar_ping
    - Update propeller sound based on submarine speed
    - Update ambient sound based on sea state
    - _Requirements: 14.1, 14.2, 14.3_

  - [ ]* 17.3 Write property test for sonar detection audio trigger
    - **Property 35: Sonar Detection Audio Trigger**
    - **Validates: Requirements 14.1**

  - [ ]* 17.4 Write property test for speed-proportional propeller audio
    - **Property 36: Speed-Proportional Propeller Audio**
    - **Validates: Requirements 14.2**

  - [ ] 17.5 Implement 3D audio spatialization
    - Configure AudioStreamPlayer3D attenuation and doppler
    - Update audio positions relative to active camera
    - _Requirements: 14.4_

- [ ] 18. Input System Integration
  - [ ] 18.1 Implement InputSystem class
    - Create InputSystem.gd
    - Route input events to appropriate view handlers
    - Implement view toggle shortcuts (Tab, 1, 2, 3)
    - _Requirements: 15.1, 15.2, 15.3_

  - [ ] 18.2 Implement input customization
    - Add input remapping UI
    - Save/load custom bindings to config file
    - _Requirements: 15.4_

  - [ ]* 18.3 Write property test for custom input binding functionality
    - **Property 42: Custom Input Binding Functionality**
    - **Validates: Requirements 15.4**

- [ ] 19. State Synchronization and Polish
  - [ ] 19.1 Implement bidirectional state synchronization
    - Ensure tactical map commands update 3D simulation
    - Ensure 3D physics updates tactical map display
    - Synchronize contact positions across all systems
    - _Requirements: 12.1, 12.2, 12.4_

  - [ ]* 19.2 Write property test for bidirectional state synchronization
    - **Property 33: Bidirectional State Synchronization**
    - **Validates: Requirements 12.1, 12.2**

  - [ ]* 19.3 Write property test for contact position consistency
    - **Property 34: Contact Position Consistency**
    - **Validates: Requirements 12.4**

  - [ ] 19.4 Add error handling
    - Implement error handlers for view switching, physics, AI, rendering
    - Add logging for debugging
    - _Requirements: All_

  - [ ] 19.5 Optimize performance
    - Implement frustum culling
    - Configure LOD for ocean, terrain, particles
    - Profile and optimize bottlenecks
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

- [ ] 20. Cross-Platform Testing and Export
  - [ ] 20.1 Test on Mac M3
    - Verify Metal renderer works correctly
    - Verify 90 FPS at 1080p
    - Test all features
    - _Requirements: 16.1, 13.1_

  - [ ] 20.2 Test on Ubuntu
    - Verify Vulkan renderer works correctly
    - Verify 60 FPS at 1080p
    - Test all features
    - _Requirements: 16.2, 13.2_

  - [ ]* 20.3 Write property test for cross-platform feature parity
    - **Property 43: Cross-Platform Feature Parity**
    - **Validates: Requirements 16.4**

  - [ ] 20.4 Configure platform-specific file paths
    - Implement platform detection
    - Use appropriate directories for config/save data
    - _Requirements: 16.5_

  - [ ]* 20.5 Write property test for platform-appropriate file paths
    - **Property 44: Platform-Appropriate File Paths**
    - **Validates: Requirements 16.5**

  - [ ] 20.6 Export standalone builds
    - Configure export presets for Mac and Ubuntu
    - Test exported builds on both platforms
    - _Requirements: 16.3_

- [ ] 21. Final Checkpoint and Documentation
  - Run full test suite (unit tests + property tests with 1000 iterations)
  - Verify all 44 correctness properties pass
  - Test complete gameplay loop: spawn submarine, encounter AI patrol, evade, observe from all views
  - Document known issues and future enhancements
  - Ensure all tests pass, ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- The implementation uses GDScript as specified in the design document
- Ocean rendering uses the godot4-oceanfft addon
- Terrain rendering uses the Terrain3D addon
- Testing uses the Gut framework for Godot
