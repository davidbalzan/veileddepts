# Implementation Plan: Dynamic Sea Level Control

## Overview

This implementation plan breaks down the dynamic sea level control feature into discrete coding tasks. The approach follows a bottom-up strategy: first implementing the core SeaLevelManager singleton, then integrating it with each affected system, and finally adding comprehensive testing.

## Tasks

- [x] 1. Create SeaLevelManager singleton
  - Create `scripts/core/sea_level_manager.gd` with core functionality
  - Implement elevation conversion functions (normalized ↔ meters)
  - Implement signal emission on value changes
  - Add input validation and clamping
  - Register as autoload singleton in project.godot
  - _Requirements: 1.2, 1.3, 8.2_

- [ ]* 1.1 Write property test for elevation conversion round-trip
  - **Property 2: Elevation conversion round-trip**
  - **Validates: Requirements 1.3**

- [ ]* 1.2 Write unit tests for SeaLevelManager
  - Test set_sea_level() with valid and invalid inputs
  - Test signal emission behavior
  - Test reset_to_default() functionality
  - _Requirements: 1.2, 8.2_

- [x] 2. Update TerrainRenderer for sea level integration
  - Add signal connection to SeaLevelManager in _ready()
  - Implement _on_sea_level_changed() callback
  - Update shader parameters for all loaded chunks
  - Ensure new chunks use current sea level from manager
  - _Requirements: 2.1, 2.4, 2.5_

- [ ]* 2.1 Write property test for shader parameter propagation
  - **Property 3: Shader parameter propagation**
  - **Validates: Requirements 2.1, 2.4**

- [ ]* 2.2 Write unit tests for TerrainRenderer sea level updates
  - Test signal connection
  - Test chunk shader parameter updates
  - Test handling of null/missing chunks
  - _Requirements: 2.1, 2.4_

- [x] 3. Update ChunkRenderer for sea level integration
  - Modify create_chunk_material() to query SeaLevelManager
  - Ensure new materials use current sea level
  - Update shader parameter initialization
  - _Requirements: 2.1, 2.4_

- [x]* 3.1 Write unit tests for ChunkRenderer material creation
  - Test material creation with various sea levels
  - Test shader parameter initialization
  - _Requirements: 2.1_

- [x] 4. Update BiomeDetector for dynamic sea level
  - Modify detect_biomes() to query SeaLevelManager when no override provided
  - Add conversion between meters and normalized values
  - Update get_biome() to use dynamic sea level
  - Maintain backward compatibility with sea_level_override parameter
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ]* 4.1 Write property test for biome reclassification
  - **Property 4: Biome reclassification on sea level change**
  - **Validates: Requirements 3.1, 3.2, 3.3**

- [ ]* 4.2 Write unit tests for BiomeDetector sea level integration
  - Test biome detection with various sea levels
  - Test underwater vs land biome classification
  - Test backward compatibility with override parameter
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 5. Update OceanRenderer for dynamic sea level
  - Add signal connection to SeaLevelManager in _ready()
  - Implement _on_sea_level_changed() callback
  - Update ocean surface Y position
  - Update quad_tree position
  - Modify get_wave_height_3d() to use manager's sea level
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ]* 5.1 Write property test for ocean surface position
  - **Property 5: Ocean surface position matches sea level**
  - **Validates: Requirements 4.1, 4.4**

- [ ]* 5.2 Write unit tests for OceanRenderer sea level updates
  - Test position updates
  - Test wave height calculations
  - _Requirements: 4.1, 4.3_

- [x] 6. Update CollisionManager for dynamic sea level
  - Modify is_underwater_safe() to query SeaLevelManager
  - Update safe spawn position calculations
  - Update collision boundary checks
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ]* 6.1 Write property test for underwater boundary consistency
  - **Property 6: Underwater boundary consistency**
  - **Validates: Requirements 5.1, 5.2**

- [ ]* 6.2 Write unit tests for CollisionManager sea level integration
  - Test underwater safety checks
  - Test spawn position calculations
  - _Requirements: 5.1, 5.2, 5.5_

- [x] 7. Update WholeMapView for SeaLevelManager integration
  - Remove local sea_level_threshold variable
  - Modify _on_sea_level_changed() to call SeaLevelManager.set_sea_level()
  - Update _create_optimized_map() to query manager for current value
  - Update _generate_detail_texture() to query manager for current value
  - Update UI display to show both normalized and metric values
  - Add "Reset to Default" button to debug panel
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 6.1, 6.4, 8.2, 10.1_

- [ ]* 7.1 Write property test for UI display accuracy
  - **Property 8: UI display accuracy**
  - **Validates: Requirements 1.3, 10.1**

- [ ]* 7.2 Write unit tests for WholeMapView sea level integration
  - Test slider interaction
  - Test map regeneration
  - Test UI display updates
  - Test reset button functionality
  - _Requirements: 1.1, 1.2, 1.5, 8.2_

- [x] 8. Update TacticalMapView for dynamic sea level
  - Add signal connection to SeaLevelManager in _ready()
  - Implement _on_sea_level_changed() callback
  - Update map texture regeneration to use manager's normalized value
  - _Requirements: 6.2, 6.3, 6.4_

- [ ]* 8.1 Write property test for map visualization threshold consistency
  - **Property 7: Map visualization threshold consistency**
  - **Validates: Requirements 6.1, 6.2, 6.3**

- [ ]* 8.2 Write unit tests for TacticalMapView sea level integration
  - Test map regeneration
  - Test threshold consistency
  - _Requirements: 6.2, 6.4_

- [x] 9. Checkpoint - Basic integration complete
  - Ensure all tests pass
  - Verify sea level changes propagate to all systems
  - Test in-game with slider adjustments
  - **Status: COMPLETE** - Parse errors fixed in WholeMapView, game runs successfully

- [x] 10. Add performance optimizations
  - Implement update throttling/debouncing (100ms minimum)
  - Add incremental chunk updates to avoid frame drops
  - Implement progress indicators for long operations
  - Add memory usage monitoring
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  - **Status: COMPLETE** - All performance optimizations implemented and tested (7/7 tests passed)

- [ ]* 10.1 Write unit tests for performance optimizations
  - Test throttling behavior
  - Test incremental updates
  - _Requirements: 7.1, 7.2_

- [x] 11. Add submarine physics adaptation
  - Update depth reading calculations to use SeaLevelManager
  - Update periscope depth calculations
  - Update surface breach prevention
  - Update sonar range calculations
  - Update buoyancy physics
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ]* 11.1 Write unit tests for submarine physics adaptation
  - Test depth reading adjustments
  - Test surface breach prevention
  - _Requirements: 9.1, 9.3_

- [ ] 12. Add visual feedback and indicators
  - Update elevation info label to show depth relative to current sea level
  - Add before/after elevation comparisons
  - Add visual indicator for newly flooded/exposed areas
  - Add sea level line indicator on Whole Map View
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ]* 12.1 Write unit tests for visual feedback
  - Test elevation display updates
  - Test indicator visibility
  - _Requirements: 10.1, 10.5_

- [ ] 13. Add error handling and recovery
  - Add null reference checks for SeaLevelManager
  - Implement graceful degradation for system update failures
  - Add user notifications for slow updates
  - Implement recovery strategies
  - _Requirements: 7.5_

- [ ]* 13.1 Write unit tests for error handling
  - Test null manager handling
  - Test system failure recovery
  - _Requirements: 7.5_

- [ ] 14. Integration testing and polish
  - [ ] 14.1 Test complete workflow from slider to all systems
    - _Requirements: 1.1, 1.2, 2.1, 3.1, 4.1, 5.1, 6.1_

  - [ ]* 14.2 Write property test for sea level consistency across systems
    - **Property 1: Sea level consistency across systems**
    - **Validates: Requirements 1.2, 2.1, 3.1, 4.1, 5.1, 6.3**

  - [ ]* 14.3 Write property test for reset to default
    - **Property 9: Reset to default**
    - **Validates: Requirements 8.2**

  - [ ]* 14.4 Write property test for view persistence
    - **Property 10: View persistence**
    - **Validates: Requirements 8.3, 8.4**

  - [ ] 14.5 Perform manual testing scenarios
    - Test basic slider interaction
    - Test 3D world consistency
    - Test extreme values (min/max)
    - Test performance with rapid changes
    - Test reset functionality
    - _Requirements: All_

  - [ ] 14.6 Run performance benchmarks
    - Measure shader update time
    - Measure biome reclassification time
    - Measure map regeneration time
    - Verify total update time < 100ms
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 15. Final checkpoint - Feature complete
  - Ensure all tests pass
  - Verify all requirements are met
  - Test all edge cases
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Checkpoints ensure incremental validation
- The implementation follows a bottom-up approach: core manager first, then system integrations, then polish
