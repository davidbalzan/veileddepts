# Implementation Plan: Terrain Rendering Fix

## Overview

This implementation plan addresses critical terrain visibility issues and establishes a robust terrain data pipeline. The work is organized into phases: core fixes first, then enhancements, then future features.

## Tasks

- [x] 1. Fix Core Terrain Visibility Issues
  - [x] 1.1 Increase procedural detail contribution
    - Modify `scripts/rendering/procedural_detail_generator.gd`
    - Change `detail_scale` from 2.0 to 30.0 meters
    - Change detail contribution from 0.1 (10%) to 0.5 (50%)
    - Add `flat_terrain_threshold` parameter (0.05)
    - Add `flat_terrain_amplitude` parameter (35.0 meters)
    - _Requirements: 2.1, 2.2_

  - [x] 1.2 Fix procedural detail function signature
    - Update `generate_detail()` to accept 3 parameters: `base_heightmap`, `chunk_coord`, `chunk_size_meters`
    - Remove `submarine_distance` parameter (use world-space coordinates instead)
    - Ensure world-space noise coordinates for boundary consistency
    - _Requirements: 2.4, 6.1, 6.2_

  - [x] 1.3 Add flat terrain detection and enhancement
    - Add `is_flat_terrain(heightmap: Image) -> bool` function
    - Add `get_heightmap_stats(heightmap: Image) -> Dictionary` function
    - When terrain is flat (< 5% variation), apply aggressive enhancement
    - _Requirements: 1.2, 2.2_

  - [ ]* 1.4 Write property test for minimum height variation
    - **Property 1: Minimum Height Variation**
    - **Validates: Requirements 1.1**

  - [ ]* 1.5 Write property test for boundary consistency
    - **Property 5: Procedural Detail Boundary Consistency**
    - **Validates: Requirements 6.1, 6.2**

- [x] 2. Fix Height Scaling
  - [x] 2.1 Update ChunkRenderer height scaling
    - Modify `scripts/rendering/chunk_renderer.gd`
    - Change `min_elevation` default from -10994.0 to -200.0
    - Change `max_elevation` default from 8849.0 to 100.0
    - Add mission area configuration support
    - _Requirements: 3.1, 3.2, 3.4_

  - [x] 2.2 Update ChunkManager to use correct detail generator call
    - Fix `_apply_procedural_detail()` in `scripts/rendering/chunk_manager.gd`
    - Pass correct parameters to `generate_detail()`
    - Add heightmap statistics logging
    - _Requirements: 1.4, 2.4_

  - [ ]* 2.3 Write property test for height mapping
    - **Property 4: Mission Area Height Mapping**
    - **Validates: Requirements 3.2**

- [x] 3. Checkpoint - Verify Terrain Visibility
  - Ensure terrain is visible when ocean is hidden
  - Verify height variation is >= 10 meters per chunk
  - Check console logs for heightmap statistics
  - Ask user to verify visual appearance

- [ ] 4. Implement TiledElevationProvider
  - [ ] 4.1 Create TiledElevationProvider class
    - Create `scripts/rendering/tiled_elevation_provider.gd`
    - Implement tile index loading from JSON
    - Implement `extract_region()` with tile lookup
    - Implement `get_elevation()` for point queries
    - Implement fallback to source image when tiles unavailable
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ] 4.2 Implement multi-resolution LOD support
    - Add `extract_region_lod()` for zoom-based detail
    - Add `get_lod_for_zoom()` to select appropriate LOD
    - Support 4 LOD levels (full, 1/2, 1/4, 1/8 resolution)
    - _Requirements: 8.5_

  - [ ] 4.3 Implement LOD cache for fast map loading
    - Add `LODCache` class with world overview pre-loading
    - Add tile cache with LRU eviction
    - Pre-load tiles around spawn point at startup
    - _Requirements: 8.4_

  - [ ]* 4.4 Write property test for tile lookup performance
    - **Property 9: Tile Index O(1) Lookup**
    - **Validates: Requirements 8.4**

- [ ] 5. Create Tile Processing Tool
  - [ ] 5.1 Create heightmap tile processor script
    - Create `tools/heightmap_tile_processor.gd`
    - Split source image into tiles at multiple LOD levels
    - Generate `tile_index.json` with metadata
    - Support command-line execution
    - _Requirements: 8.1_

  - [ ] 5.2 Process world elevation map into tiles
    - Run tile processor on `src_assets/World_elevation_map.png`
    - Generate tiles in `assets/terrain/tiles/` directory
    - Verify tile index is correct
    - _Requirements: 8.1_

- [ ] 6. Integrate TiledElevationProvider
  - [ ] 6.1 Update ChunkManager to use TiledElevationProvider
    - Modify `scripts/rendering/chunk_manager.gd`
    - Replace ElevationDataProvider with TiledElevationProvider
    - Update `_generate_heightmap()` to use new provider
    - _Requirements: 9.1_

  - [ ] 6.2 Update tactical map to use TiledElevationProvider
    - Modify `scripts/views/tactical_map_view.gd`
    - Use `extract_region_lod()` for zoom-based detail
    - Implement progressive loading for smooth zooming
    - _Requirements: 9.2_

  - [ ]* 6.3 Write property test for unified data consistency
    - **Property 10: Unified Elevation Data Consistency**
    - **Validates: Requirements 9.2, 9.3**

- [ ] 7. Checkpoint - Verify Tiled Loading
  - Ensure tiles load correctly
  - Verify tactical map uses same data as terrain
  - Check LOD switching works on zoom
  - Ask user to verify performance

- [ ] 8. Implement Calibration System
  - [ ] 8.1 Add height calibration using reference points
    - Create `HeightCalibration` class
    - Scan heightmap for min/max pixel values
    - Map to Mariana Trench and Mount Everest
    - Store calibration data for runtime use
    - _Requirements: 7.4_

  - [ ] 8.2 Add visual sea level calibration UI
    - Add "Sea Level Offset" slider to F3 debug panel (-50m to +50m)
    - Add "Save Calibration" button
    - Integrate with SeaLevelManager
    - Save calibration to `user://terrain_calibration.cfg`
    - _Requirements: 4.1_

- [ ] 9. Improve Terrain Shader Visibility
  - [ ] 9.1 Reduce depth-based darkening
    - Modify `shaders/terrain_chunk.gdshader`
    - Change depth falloff from 0.002 to 0.0005 (4x slower)
    - Ensure terrain visible at mission area depths
    - _Requirements: 5.2, 5.3, 5.4_

  - [ ] 9.2 Add debug color mode
    - Add `debug_color_mode` uniform to shader
    - When enabled, render terrain with bright height-based colors
    - Add toggle in F3 debug panel
    - _Requirements: 4.4_

- [ ] 10. Implement Enhanced Biome Detection
  - [ ] 10.1 Extend BiomeType enum
    - Add underwater biomes: DEEP_OCEAN, CONTINENTAL_SHELF, REEF_ZONE
    - Add coastal biomes: SANDY_BEACH, PEBBLE_BEACH, ROCKY_SHORE, TIDAL_FLAT
    - Add land biomes: COASTAL_VEGETATION, DUNES, WETLAND
    - _Requirements: 5.1_

  - [ ] 10.2 Implement coastal biome detection algorithm
    - Create `detect_coastal_biome()` function
    - Use elevation, slope, and distance to water
    - Classify beaches, cliffs, and tidal zones
    - _Requirements: 5.1_

  - [ ] 10.3 Create BeachDetector class
    - Implement `detect_beaches()` to find beach regions
    - Classify beach types (sandy, pebble, rocky, mudflat)
    - Calculate beach width and slope
    - _Requirements: 5.1_

- [ ] 11. Checkpoint - Verify Biome Detection
  - Ensure beaches are correctly identified
  - Verify biome colors are appropriate
  - Check coastal transitions look natural
  - Ask user to verify coastal feel

- [ ] 12. Add Debug Console Commands
  - [ ] 12.1 Add terrain status command
    - Add `/terrain status` command to show chunk count, memory, height ranges
    - Add `/terrain reload` command to force reload all chunks
    - Add `/terrain debug` command to toggle debug visualization
    - _Requirements: 4.2_

- [ ] 13. Legacy Code Cleanup
  - [ ] 13.1 Remove deprecated ElevationDataProvider
    - Verify all consumers use TiledElevationProvider
    - Remove `scripts/rendering/elevation_data_provider.gd`
    - Update any remaining references
    - _Requirements: 10.1, 10.2_

  - [ ] 13.2 Remove duplicate height scaling logic
    - Audit codebase for duplicate height calculations
    - Consolidate to ChunkRenderer only
    - Remove redundant code
    - _Requirements: 10.4_

  - [ ] 13.3 Document removed code
    - Create list of removed files/functions
    - Update any affected documentation
    - _Requirements: 10.3_

- [ ] 14. Final Checkpoint
  - Run all property tests
  - Verify terrain is visible and has good height variation
  - Verify coastal areas look realistic
  - Verify tactical map uses correct data
  - Verify no legacy code remains
  - Ask user for final approval

## Notes

- Tasks marked with `*` are optional property-based tests
- Checkpoints (tasks 3, 7, 11, 14) require user verification
- Phase 1 (tasks 1-3) addresses immediate visibility issues
- Phase 2 (tasks 4-7) implements efficient tile loading
- Phase 3 (tasks 8-11) adds calibration and biome enhancements
- Phase 4 (tasks 12-14) cleanup and finalization
