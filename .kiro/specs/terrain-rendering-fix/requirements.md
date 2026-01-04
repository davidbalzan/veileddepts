# Requirements Document

## Introduction

This specification addresses critical issues with the terrain rendering system that prevent terrain from being visible during gameplay. The current system loads terrain chunks but produces nearly flat meshes due to insufficient height variation. This fix will ensure terrain is visually prominent, has meaningful height variation for submarine gameplay, and provides clear visual feedback for navigation.

Additionally, this specification addresses heightmap data management to preserve the full resolution of the source elevation map, enable efficient chunk-based loading, and provide a unified data source for all map displays (terrain rendering, tactical map, sonar).

## Glossary

- **Terrain_System**: The complete terrain management system including chunk loading, LOD, and rendering
- **Chunk**: A square section of terrain that can be loaded/unloaded independently
- **Heightmap**: A grayscale image where pixel values represent elevation
- **Procedural_Detail**: Additional geometric detail generated algorithmically to enhance flat terrain
- **Height_Scale**: The multiplier applied to convert normalized heightmap values to world-space meters
- **Mission_Area**: A localized region with appropriate depth range for submarine gameplay (typically -200m to +100m)
- **Detail_Contribution**: The percentage of procedural detail added to base heightmap values
- **Tiled_Heightmap**: A pre-processed heightmap split into indexed tiles for efficient chunk loading
- **Source_Elevation_Map**: The original high-resolution world elevation image (World_elevation_map.png)
- **Tile_Index**: A metadata file mapping world coordinates to tile files for fast lookup

## Requirements

### Requirement 1: Visible Terrain Height Variation

**User Story:** As a player, I want to see meaningful terrain height variation, so that I can navigate using visual landmarks and avoid collisions.

#### Acceptance Criteria

1. WHEN terrain chunks are rendered THEN the Terrain_System SHALL produce meshes with minimum 10 meters of height variation within each chunk
2. WHEN the base heightmap has less than 5% variation THEN the Terrain_System SHALL apply procedural enhancement to ensure visible terrain features
3. WHEN viewing terrain from the submarine THEN the Terrain_System SHALL render terrain that is clearly distinguishable from a flat plane
4. THE Terrain_System SHALL log heightmap statistics (min, max, range) for each loaded chunk for debugging

### Requirement 2: Aggressive Procedural Detail Enhancement

**User Story:** As a player, I want terrain to have natural-looking features even in flat areas, so that the underwater environment feels realistic.

#### Acceptance Criteria

1. WHEN procedural detail is applied THEN the detail contribution SHALL be at least 50% of the total height range (not 10%)
2. WHEN the base terrain is flat THEN the Procedural_Detail generator SHALL create hills, ridges, and valleys with amplitude of 20-50 meters
3. WHEN generating procedural detail THEN the Terrain_System SHALL use multiple noise octaves for natural-looking variation
4. THE Procedural_Detail generator SHALL accept chunk coordinates and chunk size to ensure seamless boundaries

### Requirement 3: Mission Area Height Scaling

**User Story:** As a developer, I want terrain height to be scaled appropriately for submarine gameplay, so that depths are meaningful and navigation is challenging.

#### Acceptance Criteria

1. THE Terrain_System SHALL use a configurable mission area depth range (default: -200m to +100m) instead of full Earth range
2. WHEN converting heightmap values to world height THEN the Terrain_System SHALL map the full 0-1 range to the mission area range
3. WHEN the mission area range is changed THEN the Terrain_System SHALL regenerate affected chunks
4. THE Terrain_System SHALL expose min_elevation and max_elevation as configurable parameters

### Requirement 4: Terrain Visibility Debugging

**User Story:** As a developer, I want to verify terrain is rendering correctly, so that I can diagnose and fix visibility issues.

#### Acceptance Criteria

1. WHEN the ocean is hidden via debug UI THEN the Terrain_System SHALL remain visible against a neutral background
2. THE Terrain_System SHALL provide console commands to query terrain status (chunk count, memory usage, height ranges)
3. WHEN a chunk is loaded THEN the Terrain_System SHALL log the mesh AABB (bounding box) including Y range
4. THE Terrain_System SHALL support a debug mode that renders terrain with bright, distinguishable colors

### Requirement 5: Terrain Material Visibility

**User Story:** As a player, I want terrain to be clearly visible underwater, so that I can see the seabed and navigate safely.

#### Acceptance Criteria

1. WHEN rendering underwater terrain THEN the Terrain_System SHALL use colors that contrast with the water
2. THE terrain shader SHALL apply minimal depth-based darkening within the mission area depth range
3. WHEN terrain is at shallow depths (0-50m) THEN the Terrain_System SHALL render with bright, visible colors
4. WHEN terrain is at medium depths (50-150m) THEN the Terrain_System SHALL render with moderately visible colors

### Requirement 6: Seamless Procedural Detail Boundaries

**User Story:** As a player, I want terrain to look continuous across chunk boundaries, so that the world feels seamless.

#### Acceptance Criteria

1. WHEN procedural detail is generated THEN it SHALL use world-space coordinates for noise sampling
2. WHEN two chunks share an edge THEN their procedural detail SHALL match exactly at the boundary
3. THE Procedural_Detail generator SHALL use the same noise seed and parameters for all chunks
4. WHEN chunk coordinates are used as noise input THEN they SHALL be converted to world-space positions first

### Requirement 7: Heightmap Resolution Preservation

**User Story:** As a developer, I want to preserve the full resolution of the source elevation map, so that terrain detail is not lost during loading.

#### Acceptance Criteria

1. WHEN loading elevation data THEN the Terrain_System SHALL NOT downsample the source image below the chunk's required resolution
2. WHEN the source elevation map has higher resolution than needed THEN the Terrain_System SHALL use bilinear interpolation to sample at full precision
3. THE Terrain_System SHALL log the source resolution and the extracted resolution for each chunk
4. WHEN extracting a region THEN the Terrain_System SHALL preserve the original pixel values without quantization loss

### Requirement 8: Tiled Heightmap Format

**User Story:** As a developer, I want the heightmap pre-processed into indexed tiles, so that chunks can be loaded quickly without reading the entire source image.

#### Acceptance Criteria

1. THE Terrain_System SHALL support a tiled heightmap format where each tile corresponds to a chunk region
2. WHEN initializing THEN the Terrain_System SHALL check for pre-processed tiles and use them if available
3. WHEN tiles are not available THEN the Terrain_System SHALL fall back to extracting from the source image
4. THE Tile_Index SHALL map world coordinate ranges to tile file paths for O(1) lookup
5. WHEN zooming or requesting higher detail THEN the Terrain_System SHALL load higher-resolution tiles if available

### Requirement 9: Unified Elevation Data Source

**User Story:** As a developer, I want all map displays to use the same elevation data source, so that terrain is consistent across rendering, tactical map, and sonar.

#### Acceptance Criteria

1. THE Terrain_System SHALL provide a single ElevationDataProvider interface for all consumers
2. WHEN the tactical map queries elevation THEN it SHALL use the same data as terrain rendering
3. WHEN the sonar system queries depth THEN it SHALL use the same data as terrain rendering
4. THE ElevationDataProvider SHALL support queries at different resolutions for different use cases

### Requirement 10: Legacy Code Cleanup

**User Story:** As a developer, I want legacy terrain code removed, so that the codebase is maintainable and there are no conflicting implementations.

#### Acceptance Criteria

1. WHEN this specification is complete THEN all deprecated terrain loading code SHALL be removed
2. THE Terrain_System SHALL have a single, clear code path for elevation data loading
3. WHEN legacy code is identified THEN it SHALL be documented and scheduled for removal
4. THE final implementation SHALL NOT contain duplicate or redundant terrain generation logic

