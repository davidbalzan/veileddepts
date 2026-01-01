# Design Document: Dynamic Terrain Streaming System

## Overview

The Dynamic Terrain Streaming System provides efficient, scalable terrain rendering for a tactical submarine simulator. The system dynamically loads and unloads terrain chunks based on the submarine's position, uses real-world elevation data from a world heightmap, enhances visual quality with procedural detail, and automatically detects and renders coastal biomes.

The design emphasizes:
- **Memory efficiency**: Only load terrain data near the submarine
- **Visual quality**: Seamless transitions, realistic detail at all scales
- **Performance**: Maintain 60 FPS through LOD and adaptive detail
- **Accuracy**: Real-world elevation scaling using known reference points
- **Flexibility**: Support both real-world data and procedural generation

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Terrain System                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Streaming Manager                          │ │
│  │  - Chunk loading/unloading                             │ │
│  │  - Priority queue                                       │ │
│  │  - Memory management                                    │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Chunk Manager                              │ │
│  │  - Chunk grid coordinate system                        │ │
│  │  - Chunk cache (LRU)                                   │ │
│  │  - Chunk state tracking                                │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Elevation Data Provider                       │ │
│  │  - World elevation map interface                       │ │
│  │  - Vertical scaling (Mariana/Everest)                  │ │
│  │  - Region extraction                                    │ │
│  │  - Fallback procedural generation                      │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Procedural Detail Generator                   │ │
│  │  - Multi-octave noise                                  │ │
│  │  - Slope-aware detail                                  │ │
│  │  - Distance-based amplitude                            │ │
│  │  - Bump map generation                                 │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Biome Detector                             │ │
│  │  - Coastal region detection                            │ │
│  │  - Slope analysis                                      │ │
│  │  - Beach/cliff classification                          │ │
│  │  - Texture assignment                                  │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Chunk Renderer                             │ │
│  │  - LOD mesh generation                                 │ │
│  │  - Material management                                 │ │
│  │  - Seamless stitching                                  │ │
│  │  - T-junction elimination                              │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Collision Manager                             │ │
│  │  - HeightMapShape3D per chunk                          │ │
│  │  - Height queries                                      │ │
│  │  - Boundary handling                                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   Submarine           Sonar System         Debug Visualizer
```

### Data Flow

1. **Initialization**:
   - Load world elevation map metadata (dimensions, format)
   - Scan for min/max values (Mariana Trench, Mount Everest)
   - Calculate vertical scale factor
   - Initialize chunk grid around submarine spawn

2. **Runtime Loop**:
   - Monitor submarine position
   - Determine visible/needed chunks
   - Prioritize chunk loading by distance
   - Load chunks asynchronously (background thread)
   - Generate procedural detail based on proximity
   - Apply LOD based on distance
   - Unload distant chunks when memory limit reached

3. **Chunk Loading**:
   - Calculate chunk world bounds
   - Extract elevation data from world map
   - Apply vertical scaling
   - Generate procedural detail
   - Detect biomes
   - Create LOD meshes
   - Generate collision geometry
   - Stitch edges with neighbors

## Components and Interfaces

### StreamingManager

**Responsibility**: Orchestrate chunk loading/unloading based on submarine position and memory constraints.

**Interface**:
```gdscript
class_name StreamingManager extends Node

## Configuration
@export var chunk_size: float = 512.0  # meters
@export var load_distance: float = 2048.0  # meters
@export var unload_distance: float = 3072.0  # meters
@export var max_chunks_per_frame: int = 1
@export var max_load_time_ms: float = 2.0

## Update streaming based on submarine position
func update(submarine_position: Vector3) -> void

## Force load a specific chunk
func load_chunk(chunk_coord: Vector2i) -> void

## Force unload a specific chunk
func unload_chunk(chunk_coord: Vector2i) -> void

## Get loading progress (0.0 to 1.0)
func get_loading_progress() -> float

## Get list of currently loaded chunks
func get_loaded_chunks() -> Array[Vector2i]
```

**Algorithm**:
1. Calculate chunk coordinates for submarine position
2. Determine all chunks within load_distance
3. Add missing chunks to load queue, prioritized by distance
4. Remove chunks beyond unload_distance from loaded set
5. Process load queue (max N chunks per frame, max T milliseconds)
6. If memory limit reached, unload furthest chunks first

### ChunkManager

**Responsibility**: Manage chunk lifecycle, coordinate system, and caching.

**Interface**:
```gdscript
class_name ChunkManager extends Node

## Chunk cache configuration
@export var max_cache_memory_mb: int = 512

## Convert world position to chunk coordinates
func world_to_chunk(world_pos: Vector3) -> Vector2i

## Convert chunk coordinates to world position (center)
func chunk_to_world(chunk_coord: Vector2i) -> Vector3

## Get chunk at coordinates (load if needed)
func get_chunk(chunk_coord: Vector2i) -> TerrainChunk

## Check if chunk is loaded
func is_chunk_loaded(chunk_coord: Vector2i) -> bool

## Unload chunk and free memory
func unload_chunk(chunk_coord: Vector2i) -> void

## Get current memory usage
func get_memory_usage_mb() -> float

## Get chunk state (unloaded, loading, loaded)
func get_chunk_state(chunk_coord: Vector2i) -> ChunkState
```

**Chunk Coordinate System**:
- Origin (0, 0) at world origin
- Positive X = East, Positive Z = North
- Chunk (x, z) covers world region [x*size, (x+1)*size] × [z*size, (z+1)*size]
- Supports negative coordinates for regions west/south of origin
- Consistent rounding: `floor(world_pos / chunk_size)`

### ElevationDataProvider

**Responsibility**: Provide elevation data from world map or procedural generation.

**Interface**:
```gdscript
class_name ElevationDataProvider extends Node

## World elevation map configuration
@export var elevation_map_path: String = "res://src_assets/World_elevation_map.png"
@export var map_width_meters: float = 40075000.0  # Earth circumference
@export var map_height_meters: float = 20037500.0  # Half circumference

## Initialize and scan for reference points
func initialize() -> bool

## Get elevation at world position (meters)
func get_elevation(world_pos: Vector2) -> float

## Extract elevation data for a region
func extract_region(world_bounds: Rect2, resolution: int) -> Image

## Get vertical scale factor
func get_vertical_scale() -> float

## Get reference elevations
func get_mariana_depth() -> float  # Should return -10994.0
func get_everest_height() -> float  # Should return 8849.0
```

**Vertical Scaling Algorithm**:
1. Scan entire world elevation map for min/max pixel values
2. Map min pixel value to Mariana Trench depth (-10,994m)
3. Map max pixel value to Mount Everest height (+8,849m)
4. For any pixel value p: `elevation = lerp(mariana_depth, everest_height, p)`
5. Store scale factor for debugging: `scale = (everest - mariana) / (max_pixel - min_pixel)`

### ProceduralDetailGenerator

**Responsibility**: Generate fine-scale terrain detail that follows base elevation.

**Interface**:
```gdscript
class_name ProceduralDetailGenerator extends Node

## Detail configuration
@export var detail_scale: float = 2.0  # meters
@export var detail_frequency: float = 0.05
@export var detail_octaves: int = 3
@export var distance_falloff: float = 100.0  # meters

## Generate detail heightmap for a chunk
func generate_detail(
	base_heightmap: Image,
	chunk_coord: Vector2i,
	submarine_distance: float
) -> Image

## Generate bump map for a chunk
func generate_bump_map(
	base_heightmap: Image,
	chunk_coord: Vector2i
) -> Image

## Calculate detail amplitude based on distance
func calculate_amplitude(distance: float) -> float
```

**Detail Generation Algorithm**:
1. Sample base heightmap to get slope and curvature
2. Generate multi-octave noise using chunk coordinates as seed
3. Modulate noise amplitude by:
   - Distance from submarine (closer = more detail)
   - Slope (steep = rocky detail, flat = sediment detail)
   - Curvature (convex = erosion, concave = deposition)
4. Add modulated noise to base heightmap
5. Generate normal map from detailed heightmap for bump mapping

### BiomeDetector

**Responsibility**: Classify terrain regions and assign appropriate textures.

**Interface**:
```gdscript
class_name BiomeDetector extends Node

## Biome classification thresholds
@export var beach_slope_threshold: float = 0.3  # radians
@export var cliff_slope_threshold: float = 0.6  # radians
@export var shallow_water_depth: float = 10.0  # meters

## Detect biomes in a heightmap
func detect_biomes(heightmap: Image, sea_level: float) -> Image

## Get biome at a specific position
func get_biome(elevation: float, slope: float, sea_level: float) -> BiomeType

## Get texture parameters for a biome
func get_biome_texture(biome: BiomeType) -> BiomeTextureParams
```

**Biome Types**:
- `DEEP_WATER`: Below sea level, depth > 50m
- `SHALLOW_WATER`: Below sea level, depth < 50m
- `BEACH`: Coastal, slope < 0.3 rad
- `CLIFF`: Coastal, slope > 0.6 rad
- `GRASS`: Above sea level, low elevation, gentle slope
- `ROCK`: Above sea level, steep slope or high elevation
- `SNOW`: Above sea level, very high elevation

**Detection Algorithm**:
1. For each pixel in heightmap:
   - Calculate elevation relative to sea level
   - Calculate slope from neighboring pixels
   - Classify based on elevation and slope thresholds
2. Apply smoothing filter to prevent biome noise
3. Generate biome map (one biome ID per pixel)

### ChunkRenderer

**Responsibility**: Generate and render terrain meshes with LOD and seamless stitching.

**Interface**:
```gdscript
class_name ChunkRenderer extends Node

## LOD configuration
@export var lod_levels: int = 4
@export var lod_distance_multiplier: float = 2.0
@export var base_lod_distance: float = 100.0

## Create terrain chunk mesh
func create_chunk_mesh(
	heightmap: Image,
	biome_map: Image,
	chunk_coord: Vector2i,
	lod_level: int
) -> ArrayMesh

## Update chunk LOD based on distance
func update_chunk_lod(chunk: TerrainChunk, distance: float) -> void

## Stitch chunk edges with neighbors
func stitch_chunk_edges(
	chunk: TerrainChunk,
	neighbors: Dictionary  # Vector2i -> TerrainChunk
) -> void

## Generate material for chunk
func create_chunk_material(biome_map: Image, bump_map: Image) -> ShaderMaterial
```

**LOD Strategy**:
- LOD 0 (highest): Full resolution (e.g., 128x128 vertices)
- LOD 1: Half resolution (64x64 vertices)
- LOD 2: Quarter resolution (32x32 vertices)
- LOD 3 (lowest): Eighth resolution (16x16 vertices)

**Seamless Stitching**:
1. **Edge Matching**: Ensure edge vertices have identical positions between chunks
2. **Normal Blending**: Average normals across chunk boundaries
3. **T-Junction Elimination**: When adjacent chunks have different LODs, add extra vertices to prevent cracks
4. **Procedural Consistency**: Use chunk coordinates as noise seed to ensure detail matches at boundaries
5. **Texture Tiling**: Use world-space UVs so textures tile seamlessly

### CollisionManager

**Responsibility**: Manage terrain collision geometry and height queries.

**Interface**:
```gdscript
class_name CollisionManager extends Node

## Create collision shape for chunk
func create_collision(chunk: TerrainChunk) -> void

## Remove collision shape for chunk
func remove_collision(chunk: TerrainChunk) -> void

## Query terrain height at world position
func get_height_at(world_pos: Vector2) -> float

## Check if position is underwater with clearance
func is_underwater_safe(world_pos: Vector3, clearance: float) -> bool

## Raycast against terrain
func raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary
```

**Collision Strategy**:
- Use HeightMapShape3D for each chunk
- Collision resolution matches visual LOD 1 (balance between accuracy and performance)
- Update collision when chunk LOD changes significantly
- Handle queries at chunk boundaries by checking both chunks

## Data Models

### TerrainChunk

```gdscript
class_name TerrainChunk extends Node3D

## Chunk identification
var chunk_coord: Vector2i
var world_bounds: Rect2

## Terrain data
var base_heightmap: Image
var detail_heightmap: Image
var biome_map: Image
var bump_map: Image

## Rendering
var mesh_instance: MeshInstance3D
var lod_meshes: Array[ArrayMesh]
var current_lod: int
var material: ShaderMaterial

## Collision
var static_body: StaticBody3D
var collision_shape: CollisionShape3D

## State
var state: ChunkState  # UNLOADED, LOADING, LOADED
var last_access_time: float
var memory_size_bytes: int

## Neighbors (for stitching)
var neighbors: Dictionary  # Vector2i -> TerrainChunk
```

### ChunkState

```gdscript
enum ChunkState {
	UNLOADED,   # Not in memory
	LOADING,    # Being loaded asynchronously
	LOADED,     # Fully loaded and rendered
	UNLOADING   # Being unloaded
}
```

### BiomeType

```gdscript
enum BiomeType {
	DEEP_WATER,
	SHALLOW_WATER,
	BEACH,
	CLIFF,
	GRASS,
	ROCK,
	SNOW
}
```

### BiomeTextureParams

```gdscript
class_name BiomeTextureParams extends Resource

var albedo_color: Color
var roughness: float
var metallic: float
var normal_strength: float
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Chunk Loading Proximity

*For any* submarine position and chunk configuration, when the submarine moves within the load threshold of an unloaded chunk, that chunk should be added to the load queue.

**Validates: Requirements 1.1**

### Property 2: Chunk Unloading Distance

*For any* loaded chunk and submarine position, when the submarine moves beyond the unload threshold from that chunk, the chunk should be unloaded and its memory freed.

**Validates: Requirements 1.3, 6.3**

### Property 3: Chunk Load Prioritization

*For any* set of chunks in the load queue, chunks should be ordered by distance to the submarine (closest first).

**Validates: Requirements 1.4**

### Property 4: Frame Time Budget

*For any* chunk loading operation, the main thread should not be blocked for more than 2 milliseconds.

**Validates: Requirements 1.5**

### Property 5: Edge Vertex Matching

*For any* two adjacent chunks, their shared edge vertices should have identical positions and heights.

**Validates: Requirements 1.2, 10.1**

### Property 6: Region Extraction Bounds

*For any* chunk, the elevation data extracted from the world map should correspond exactly to that chunk's world bounds.

**Validates: Requirements 2.2**

### Property 7: Procedural Detail Follows Base

*For any* terrain with procedural detail applied, the detail should preserve the general shape of the base elevation (no inversions of major features).

**Validates: Requirements 3.1**

### Property 8: Detail Amplitude Distance Falloff

*For any* two points at different distances from the submarine, the point closer to the submarine should have equal or greater procedural detail amplitude.

**Validates: Requirements 3.3**

### Property 9: Slope-Based Detail Characteristics

*For any* terrain region, steep slopes (>0.6 rad) should have rocky detail characteristics, and flat areas (<0.2 rad) should have sediment characteristics.

**Validates: Requirements 3.5, 3.6**

### Property 10: LOD Distance Relationship

*For any* chunk, its LOD level should be inversely related to its distance from the submarine (closer = higher LOD).

**Validates: Requirements 4.1, 4.2**

### Property 11: Independent Chunk LOD

*For any* set of visible chunks, each chunk's LOD level should be determined independently based on its own distance to the submarine.

**Validates: Requirements 4.5**

### Property 12: Adaptive Performance

*For any* frame where frame time exceeds the budget, the system should reduce LOD levels before unloading chunks.

**Validates: Requirements 4.3, 6.5**

### Property 13: Coastal Detection

*For any* terrain region where elevation crosses sea level, that region should be classified as coastal.

**Validates: Requirements 5.1**

### Property 14: Beach Classification

*For any* coastal region with slope less than 0.3 radians, it should be classified as a beach biome and rendered with sand-colored textures.

**Validates: Requirements 5.2, 5.4**

### Property 15: Cliff Classification

*For any* coastal region with slope greater than 0.6 radians, it should be classified as a cliff biome and rendered with rock-colored textures.

**Validates: Requirements 5.3, 5.5**

### Property 16: Shallow Water Coloring

*For any* water region within 10 meters of sea level near a beach, the water color should be lighter than deep water.

**Validates: Requirements 5.6**

### Property 17: Memory Limit Enforcement

*For any* chunk cache state, when the memory limit is reached, the furthest chunks should be unloaded first until memory usage is below the limit.

**Validates: Requirements 6.2**

### Property 18: Coordinate Conversion Round Trip

*For any* world position, converting to chunk coordinates and back to world position should yield a position within the same chunk.

**Validates: Requirements 7.2, 7.3**

### Property 19: Height Query Chunk Identification

*For any* world position, querying terrain height should correctly identify and sample from the chunk containing that position.

**Validates: Requirements 7.5**

### Property 20: Collision Geometry Lifecycle

*For any* chunk, when it is loaded it should have collision geometry, and when it is unloaded the collision geometry should be removed.

**Validates: Requirements 8.1, 8.2**

### Property 21: Height Query Accuracy

*For any* world position in a loaded chunk, the queried height should match the height from the chunk's heightmap within interpolation tolerance.

**Validates: Requirements 8.3**

### Property 22: Boundary Collision Continuity

*For any* position on a chunk boundary, collision detection should work correctly using data from the appropriate chunk(s).

**Validates: Requirements 8.4**

### Property 23: Sonar Normal Provision

*For any* sonar query to terrain, the system should return surface normals for that terrain position.

**Validates: Requirements 9.2**

### Property 24: Sonar Range Filtering

*For any* terrain beyond sonar range, the system should not provide terrain data to the sonar system.

**Validates: Requirements 9.4**

### Property 25: Normal Continuity Across Boundaries

*For any* chunk boundary, normal vectors should blend smoothly across the boundary (no discontinuities).

**Validates: Requirements 10.2**

### Property 26: T-Junction Elimination

*For any* pair of adjacent chunks with different LOD levels, there should be no visible cracks at the boundary.

**Validates: Requirements 10.3**

### Property 27: Procedural Detail Boundary Consistency

*For any* chunk boundary, procedural detail should be consistent across the boundary (same noise values at the same world positions).

**Validates: Requirements 10.4**

### Property 28: Texture Tiling Continuity

*For any* chunk boundary, textures should tile seamlessly without visible seams.

**Validates: Requirements 10.5**

### Property 29: Underwater Feature Preservation

*For any* underwater terrain feature (trench, ridge, seamount) at LOD level N, the feature should still be recognizable at LOD level N+1.

**Validates: Requirements 11.3**

### Property 30: Vertical Scale Interpolation

*For any* elevation value from the world map, the calculated real-world height should be a linear interpolation between Mariana Trench depth and Mount Everest height.

**Validates: Requirements 12.3, 12.5**

## Error Handling

### Missing Elevation Data

**Scenario**: World elevation map file is missing or corrupted.

**Handling**:
1. Log error with file path
2. Fall back to fully procedural terrain generation
3. Use Perlin/Simplex noise with appropriate frequency for realistic terrain
4. Continue normal operation with procedural data

### Memory Exhaustion

**Scenario**: Chunk cache reaches memory limit.

**Handling**:
1. Immediately stop loading new chunks
2. Unload furthest chunks using LRU policy
3. If still over limit, reduce LOD levels on remaining chunks
4. Log warning if unable to free sufficient memory
5. Resume normal operation once below threshold

### Chunk Loading Timeout

**Scenario**: Chunk takes too long to load (>5 seconds).

**Handling**:
1. Cancel the loading operation
2. Mark chunk as failed
3. Retry loading after 10 seconds
4. After 3 failed attempts, generate procedural chunk instead
5. Log error for debugging

### Invalid Chunk Coordinates

**Scenario**: Request for chunk at coordinates outside valid range.

**Handling**:
1. Clamp coordinates to valid range
2. Log warning with original and clamped coordinates
3. Proceed with clamped coordinates

### Collision Query Outside Loaded Chunks

**Scenario**: Height query for position not in any loaded chunk.

**Handling**:
1. Return estimated height based on nearest loaded chunk
2. Optionally trigger load of the needed chunk
3. Log warning if queries frequently miss loaded chunks

## Testing Strategy

### Unit Tests

**Chunk Coordinate Conversion**:
- Test world_to_chunk with positive coordinates
- Test world_to_chunk with negative coordinates
- Test world_to_chunk at exact chunk boundaries
- Test chunk_to_world round-trip accuracy

**Vertical Scaling**:
- Test that min pixel maps to Mariana depth
- Test that max pixel maps to Everest height
- Test interpolation at midpoint
- Test scale factor calculation

**Biome Detection**:
- Test beach detection with gentle slope
- Test cliff detection with steep slope
- Test deep water classification
- Test shallow water classification

**Memory Management**:
- Test LRU eviction when cache is full
- Test memory tracking accuracy
- Test that unloaded chunks free memory

### Property-Based Tests

All properties listed in the Correctness Properties section should be implemented as property-based tests. Each test should:
- Generate random valid inputs (submarine positions, chunk configurations, terrain data)
- Execute the system behavior
- Verify the property holds
- Run for minimum 100 iterations

**Test Configuration**:
- Minimum 100 iterations per property test
- Use fast-check or GDScript equivalent for property testing
- Tag each test with: **Feature: dynamic-terrain-streaming, Property N: [property text]**

### Integration Tests

**End-to-End Streaming**:
- Spawn submarine in test world
- Move submarine in a pattern that crosses multiple chunks
- Verify chunks load/unload correctly
- Verify no visual artifacts at boundaries
- Verify collision works throughout movement

**Performance Tests**:
- Load maximum number of chunks
- Measure frame time
- Verify stays within budget (16.67ms for 60 FPS)
- Measure memory usage
- Verify stays within limit

**Sonar Integration**:
- Query terrain from sonar system
- Verify correct normals returned
- Verify range filtering works
- Verify simplified geometry provided

### Visual Tests

**Seamless Boundaries**:
- Render scene with multiple chunks at different LODs
- Visually inspect for cracks or seams
- Capture screenshots for regression testing

**Biome Rendering**:
- Render scene with beaches, cliffs, and water
- Verify colors match expected biome textures
- Verify smooth transitions between biomes

**Procedural Detail**:
- Render terrain at close range
- Verify detail is visible and natural-looking
- Verify detail follows base terrain shape
