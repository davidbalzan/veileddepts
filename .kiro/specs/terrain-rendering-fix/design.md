# Design Document: Terrain Rendering Fix

## Overview

This design addresses critical terrain visibility issues in the submarine simulator. The current terrain system loads chunks but produces nearly flat meshes because:

1. **Procedural detail contribution is too low** (10% instead of 50%+)
2. **Height scaling uses full Earth range** (-11km to +9km) instead of mission area (-200m to +100m)
3. **Base heightmap has minimal variation** in the submarine's operating area
4. **Shader darkening is too aggressive** making terrain invisible at depth

The fix involves:
- Increasing procedural detail contribution to 50%+
- Using mission-area height scaling
- Implementing tiled heightmap loading for efficiency
- Unifying elevation data access across all systems
- Cleaning up legacy code

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Terrain System (Refactored)                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           TiledElevationProvider (NEW)                      │ │
│  │  - Pre-processed tile loading                              │ │
│  │  - Tile index for O(1) lookup                              │ │
│  │  - Multi-resolution support                                │ │
│  │  - Fallback to source image                                │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │           ProceduralDetailGenerator (MODIFIED)              │ │
│  │  - 50%+ detail contribution (was 10%)                      │ │
│  │  - World-space noise coordinates                           │ │
│  │  - Flat terrain detection and enhancement                  │ │
│  │  - 20-50m amplitude for flat areas                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              ChunkRenderer (MODIFIED)                       │ │
│  │  - Mission area height scaling (-200m to +100m)            │ │
│  │  - Improved shader with less depth darkening               │ │
│  │  - Debug color mode                                        │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              ChunkManager (MODIFIED)                        │ │
│  │  - Uses TiledElevationProvider                             │ │
│  │  - Heightmap statistics logging                            │ │
│  │  - Flat terrain detection                                  │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   Terrain Rendering    Tactical Map View      Sonar System
   (3D chunks)          (2D elevation)         (depth queries)
```

### Data Flow

1. **Initialization**:
   - TiledElevationProvider checks for pre-processed tiles
   - If tiles exist, load tile index for O(1) lookup
   - If no tiles, fall back to source image extraction
   - Calculate mission area height range

2. **Chunk Loading**:
   - ChunkManager requests elevation data from TiledElevationProvider
   - TiledElevationProvider returns heightmap at requested resolution
   - ChunkManager checks heightmap variation
   - If variation < 5%, apply aggressive procedural enhancement
   - ProceduralDetailGenerator adds 50%+ detail contribution
   - ChunkRenderer creates mesh with mission area height scaling

3. **Unified Access**:
   - Tactical map queries TiledElevationProvider for elevation
   - Sonar system queries TiledElevationProvider for depth
   - All systems get consistent data

## Components and Interfaces

### TiledElevationProvider

**Responsibility**: Provide elevation data efficiently using pre-processed tiles or source image fallback.

**Interface**:
```gdscript
class_name TiledElevationProvider extends Node

## Tile configuration
@export var tile_directory: String = "res://assets/terrain/tiles/"
@export var source_image_path: String = "res://src_assets/World_elevation_map.png"
@export var tile_size_pixels: int = 256
@export var tile_size_meters: float = 512.0

## Multi-resolution tile levels (for zoom-based detail)
## Level 0 = highest resolution, Level N = lowest resolution
@export var max_lod_levels: int = 4

## Initialize and load tile index
func initialize() -> bool

## Check if tiles are available
func has_tiles() -> bool

## Extract elevation data for a world region
## Returns Image with FORMAT_RF containing normalized elevation (0-1)
func extract_region(world_bounds: Rect2, resolution: int) -> Image

## Get elevation at a specific world position
func get_elevation(world_pos: Vector2) -> float

## Get elevation at multiple resolutions (for LOD)
func extract_region_lod(world_bounds: Rect2, lod_level: int) -> Image

## Get appropriate LOD level based on zoom/scale
## zoom_scale: meters per pixel (lower = more zoomed in)
func get_lod_for_zoom(zoom_scale: float) -> int
```

### Multi-Resolution Map Display Support

The TiledElevationProvider supports zoom-based detail loading for 2D map displays (tactical map, minimap):

**LOD Levels for Maps**:
- **LOD 0** (highest): Full source resolution, used when zoomed in close
- **LOD 1**: 1/2 resolution, used for medium zoom
- **LOD 2**: 1/4 resolution, used for overview zoom
- **LOD 3** (lowest): 1/8 resolution, used for world map view

**Zoom-to-LOD Mapping**:
```gdscript
## Get appropriate LOD level based on meters per pixel
func get_lod_for_zoom(meters_per_pixel: float) -> int:
    # Higher meters_per_pixel = more zoomed out = lower detail needed
    if meters_per_pixel < 10.0:
        return 0  # Very zoomed in, full detail
    elif meters_per_pixel < 50.0:
        return 1  # Medium zoom
    elif meters_per_pixel < 200.0:
        return 2  # Overview
    else:
        return 3  # World map
```

**Tactical Map Integration**:
```gdscript
## In TacticalMapView
func _update_terrain_display() -> void:
    var view_bounds = _get_visible_world_bounds()
    var meters_per_pixel = view_bounds.size.x / get_viewport_rect().size.x
    var lod = elevation_provider.get_lod_for_zoom(meters_per_pixel)
    
    # Request terrain at appropriate detail level
    var terrain_image = elevation_provider.extract_region_lod(view_bounds, lod)
    _render_terrain_to_texture(terrain_image)
```

**Tile Storage Structure**:
```
assets/terrain/tiles/
├── lod0/           # Full resolution tiles (256x256 pixels = 512m)
│   ├── tile_0_0.png
│   ├── tile_0_1.png
│   └── ...
├── lod1/           # Half resolution (128x128 pixels = 512m)
│   ├── tile_0_0.png
│   └── ...
├── lod2/           # Quarter resolution (64x64 pixels = 512m)
│   └── ...
├── lod3/           # Eighth resolution (32x32 pixels = 512m)
│   └── ...
└── tile_index.json # Metadata for all tiles
```

### Internal LOD Cache for Fast Map Loading

To avoid slow map loading, the system maintains an internal cache of pre-computed LOD levels:

**LOD Cache Structure**:
```gdscript
class LODCache:
    ## Pre-computed world overview images at different resolutions
    var world_overview: Dictionary = {}  # lod_level -> Image
    
    ## Tile cache with LRU eviction
    var tile_cache: Dictionary = {}  # "lod_x_y" -> Image
    var cache_order: Array[String] = []  # LRU order
    var max_cached_tiles: int = 64
    
    ## Pre-load world overview at startup
    func preload_world_overview() -> void:
        for lod in range(4):
            world_overview[lod] = _generate_world_overview(lod)
    
    ## Get cached tile or load from disk
    func get_tile(lod: int, x: int, y: int) -> Image:
        var key = "%d_%d_%d" % [lod, x, y]
        if tile_cache.has(key):
            _touch_cache(key)
            return tile_cache[key]
        
        var tile = _load_tile_from_disk(lod, x, y)
        _add_to_cache(key, tile)
        return tile
```

**Startup Pre-loading**:
```gdscript
## In TiledElevationProvider._ready()
func _ready() -> void:
    # Pre-load low-resolution world overview for instant map display
    _lod_cache.preload_world_overview()
    
    # Pre-load tiles around spawn point
    var spawn_coord = Vector2i(0, 0)  # Or from game config
    _preload_tiles_around(spawn_coord, 2)  # 2 tile radius
```

**Progressive Loading for Maps**:
```gdscript
## In TacticalMapView
func _update_terrain_display() -> void:
    var view_bounds = _get_visible_world_bounds()
    var meters_per_pixel = view_bounds.size.x / get_viewport_rect().size.x
    var target_lod = elevation_provider.get_lod_for_zoom(meters_per_pixel)
    
    # First: Show cached low-res immediately (no loading delay)
    if _current_lod > target_lod:
        var cached_image = elevation_provider.get_cached_overview(target_lod + 1)
        if cached_image:
            _render_terrain_to_texture(cached_image)
    
    # Then: Load higher detail in background
    _request_terrain_async(view_bounds, target_lod, _on_terrain_loaded)

func _on_terrain_loaded(terrain_image: Image, lod: int) -> void:
    # Update display with higher detail when ready
    _render_terrain_to_texture(terrain_image)
    _current_lod = lod
```

**Memory Budget**:
- World overview cache: ~4MB (4 LOD levels × 1MB each)
- Tile cache: ~64MB (64 tiles × 1MB each)
- Total: ~68MB dedicated to map caching

## Additional Recommended Improvements

### 1. Terrain Streaming Priority Queue

Currently chunks load in arbitrary order. A priority queue would improve perceived performance:

```gdscript
class ChunkLoadPriority:
    var chunk_coord: Vector2i
    var priority: float  # Lower = higher priority
    
    static func calculate_priority(chunk_coord: Vector2i, submarine_pos: Vector3, view_dir: Vector3) -> float:
        var chunk_center = chunk_to_world(chunk_coord)
        var distance = submarine_pos.distance_to(chunk_center)
        var direction_to_chunk = (chunk_center - submarine_pos).normalized()
        var in_view_bonus = view_dir.dot(Vector3(direction_to_chunk.x, 0, direction_to_chunk.z))
        
        # Prioritize: close chunks, chunks in view direction
        return distance - (in_view_bonus * 100.0)
```

### 2. Terrain Occlusion Culling

Don't render chunks that are completely behind terrain:

```gdscript
func is_chunk_occluded(chunk: TerrainChunk, camera_pos: Vector3) -> bool:
    # Simple horizon check - if chunk is below camera's horizon line
    var chunk_max_height = chunk.get_max_height()
    var distance = camera_pos.distance_to(chunk.get_center())
    var horizon_drop = (distance * distance) / (2.0 * EARTH_RADIUS)  # Simplified
    
    return chunk_max_height < (camera_pos.y - horizon_drop - MARGIN)
```

### 3. Async Tile Processing

Move tile loading off the main thread:

```gdscript
var _tile_load_thread: Thread
var _tile_load_queue: Array[TileLoadRequest] = []
var _tile_load_mutex: Mutex

func _process(_delta: float) -> void:
    # Check for completed tile loads
    _mutex.lock()
    while _completed_tiles.size() > 0:
        var tile = _completed_tiles.pop_front()
        _on_tile_loaded(tile)
    _mutex.unlock()

func _tile_load_thread_func() -> void:
    while _running:
        _mutex.lock()
        if _tile_load_queue.size() > 0:
            var request = _tile_load_queue.pop_front()
            _mutex.unlock()
            var tile = _load_tile_sync(request)
            _mutex.lock()
            _completed_tiles.append(tile)
        _mutex.unlock()
        OS.delay_msec(1)  # Prevent busy-waiting
```

### 4. Terrain Normal Map Generation

Pre-compute normal maps for better lighting without geometry cost:

```gdscript
func generate_normal_map(heightmap: Image) -> Image:
    var normal_map = Image.create(heightmap.get_width(), heightmap.get_height(), false, Image.FORMAT_RGB8)
    
    for y in range(heightmap.get_height()):
        for x in range(heightmap.get_width()):
            var normal = _calculate_normal(heightmap, x, y)
            # Encode normal to RGB (0-1 range)
            var color = Color(
                (normal.x + 1.0) * 0.5,
                (normal.y + 1.0) * 0.5,
                (normal.z + 1.0) * 0.5
            )
            normal_map.set_pixel(x, y, color)
    
    return normal_map
```

### 5. Terrain Collision LOD

Use lower-resolution collision for distant chunks:

```gdscript
func update_collision_lod(chunk: TerrainChunk, distance: float) -> void:
    var collision_lod = 0
    if distance > 500.0:
        collision_lod = 1  # Half resolution collision
    elif distance > 1000.0:
        collision_lod = 2  # Quarter resolution collision
    
    if collision_lod != chunk.current_collision_lod:
        _regenerate_collision(chunk, collision_lod)
```

### 6. Debug Visualization Improvements

Add more debug tools for terrain development:

```gdscript
## Debug overlay options
@export var show_chunk_boundaries: bool = false
@export var show_height_gradient: bool = false  # Color by height
@export var show_slope_gradient: bool = false   # Color by slope
@export var show_lod_levels: bool = false       # Color by LOD
@export var show_memory_usage: bool = false     # Per-chunk memory

func _draw_debug_overlay() -> void:
    if show_height_gradient:
        _apply_height_debug_shader()
    if show_chunk_boundaries:
        _draw_chunk_wireframes()
    # etc.
```

These improvements are optional but would significantly enhance the terrain system's performance and debuggability.

## Biome and Coastal System

### Enhanced Biome Detection

The current BiomeDetector classifies terrain into basic types. We'll enhance it for realistic coastal environments:

**Biome Types (Extended)**:
```gdscript
enum BiomeType {
    # Underwater
    DEEP_OCEAN,         # > 200m depth, dark blue, soft sediment
    CONTINENTAL_SHELF,  # 50-200m depth, medium blue, mixed sediment
    SHALLOW_WATER,      # 10-50m depth, light blue, sandy
    REEF_ZONE,          # 0-30m depth, near coast, rocky/coral
    
    # Coastal
    SANDY_BEACH,        # 0-5m elevation, gentle slope, sand texture
    PEBBLE_BEACH,       # 0-5m elevation, moderate slope, pebbles
    ROCKY_SHORE,        # 0-10m elevation, steep slope, rocks
    CLIFF,              # > 10m elevation, very steep, rock face
    TIDAL_FLAT,         # 0-2m elevation, very flat, mud/sand
    
    # Land (for context)
    COASTAL_VEGETATION, # 5-20m elevation, gentle slope, grass/shrubs
    DUNES,              # 5-15m elevation, sandy, undulating
    WETLAND,            # 0-5m elevation, flat, marsh texture
}
```

**Coastal Detection Algorithm**:
```gdscript
func detect_coastal_biome(elevation: float, slope: float, distance_to_water: float) -> BiomeType:
    # Underwater biomes
    if elevation < -200.0:
        return BiomeType.DEEP_OCEAN
    elif elevation < -50.0:
        return BiomeType.CONTINENTAL_SHELF
    elif elevation < -10.0:
        return BiomeType.SHALLOW_WATER
    elif elevation < 0.0:
        return BiomeType.REEF_ZONE if slope > 0.3 else BiomeType.SHALLOW_WATER
    
    # Coastal biomes (0-10m elevation)
    elif elevation < 10.0:
        if slope < 0.1:  # Very flat
            if elevation < 2.0:
                return BiomeType.TIDAL_FLAT
            else:
                return BiomeType.SANDY_BEACH
        elif slope < 0.3:  # Gentle slope
            return BiomeType.PEBBLE_BEACH
        elif slope < 0.6:  # Moderate slope
            return BiomeType.ROCKY_SHORE
        else:  # Steep
            return BiomeType.CLIFF
    
    # Above coastal zone
    else:
        if slope < 0.2 and distance_to_water < 100.0:
            return BiomeType.DUNES if _is_sandy_area() else BiomeType.COASTAL_VEGETATION
        return BiomeType.COASTAL_VEGETATION
```

### Coastal Texture System

**Texture Layers**:
```gdscript
class CoastalTextureSet:
    var sand_diffuse: Texture2D
    var sand_normal: Texture2D
    var pebble_diffuse: Texture2D
    var pebble_normal: Texture2D
    var rock_diffuse: Texture2D
    var rock_normal: Texture2D
    var mud_diffuse: Texture2D
    var mud_normal: Texture2D
    var grass_diffuse: Texture2D
    var grass_normal: Texture2D
    
    # Underwater textures
    var seafloor_sand: Texture2D
    var seafloor_mud: Texture2D
    var seafloor_rock: Texture2D
    var coral: Texture2D
```

**Texture Blending Shader**:
```glsl
// In terrain_coastal.gdshader
uniform sampler2D biome_map;
uniform sampler2D sand_texture;
uniform sampler2D pebble_texture;
uniform sampler2D rock_texture;
uniform sampler2D grass_texture;

void fragment() {
    vec4 biome = texture(biome_map, UV);
    
    // Blend textures based on biome weights
    vec3 sand = texture(sand_texture, UV * 10.0).rgb;
    vec3 pebble = texture(pebble_texture, UV * 8.0).rgb;
    vec3 rock = texture(rock_texture, UV * 5.0).rgb;
    vec3 grass = texture(grass_texture, UV * 12.0).rgb;
    
    // biome.r = sand weight, biome.g = rock weight, biome.b = grass weight
    vec3 final_color = sand * biome.r + rock * biome.g + grass * biome.b;
    
    // Add pebble transition between sand and rock
    float pebble_weight = min(biome.r, biome.g) * 2.0;
    final_color = mix(final_color, pebble, pebble_weight);
    
    ALBEDO = final_color;
}
```

### Beach Detection and Rendering

**Beach Identification**:
```gdscript
class BeachDetector:
    ## Minimum beach width in meters
    @export var min_beach_width: float = 10.0
    
    ## Maximum slope for beach classification
    @export var max_beach_slope: float = 0.15  # ~8.5 degrees
    
    ## Elevation range for beaches
    @export var beach_min_elevation: float = -2.0  # Below sea level (tidal)
    @export var beach_max_elevation: float = 5.0   # Above sea level
    
    func detect_beaches(heightmap: Image, sea_level: float) -> Array[BeachRegion]:
        var beaches: Array[BeachRegion] = []
        
        # Find coastline (sea level crossing)
        var coastline = _find_coastline(heightmap, sea_level)
        
        # For each coastline segment, check if it's a beach
        for segment in coastline:
            var slope = _calculate_average_slope(heightmap, segment)
            var width = _calculate_beach_width(heightmap, segment, sea_level)
            
            if slope < max_beach_slope and width > min_beach_width:
                var beach = BeachRegion.new()
                beach.coastline = segment
                beach.width = width
                beach.slope = slope
                beach.type = _classify_beach_type(slope, width)
                beaches.append(beach)
        
        return beaches

class BeachRegion:
    var coastline: PackedVector2Array  # Coastline points
    var width: float                    # Beach width in meters
    var slope: float                    # Average slope
    var type: BeachType                 # Sandy, pebble, etc.
    
enum BeachType:
    SANDY_GENTLE,    # Wide, flat sandy beach
    SANDY_STEEP,     # Narrow sandy beach
    PEBBLE,          # Pebble/shingle beach
    ROCKY,           # Rocky shoreline
    MUDFLAT          # Tidal mudflat
```

### Future Building Support

**Building Placement System** (for future implementation):

```gdscript
class BuildingPlacementManager:
    ## Supported building types
    enum BuildingType {
        LIGHTHOUSE,
        DOCK,
        PIER,
        HARBOR,
        COASTAL_HOUSE,
        WAREHOUSE,
        NAVAL_BASE,
        OIL_PLATFORM,
    }
    
    ## Building placement rules
    var placement_rules: Dictionary = {
        BuildingType.LIGHTHOUSE: {
            "min_elevation": 5.0,
            "max_elevation": 50.0,
            "min_slope": 0.0,
            "max_slope": 0.3,
            "near_water": true,
            "water_distance_max": 100.0,
        },
        BuildingType.DOCK: {
            "min_elevation": -5.0,
            "max_elevation": 2.0,
            "min_slope": 0.0,
            "max_slope": 0.1,
            "near_water": true,
            "water_distance_max": 10.0,
        },
        # ... more rules
    }
    
    ## Find valid placement locations for a building type
    func find_valid_placements(building_type: BuildingType, search_area: Rect2) -> Array[Vector3]:
        var rules = placement_rules[building_type]
        var valid_locations: Array[Vector3] = []
        
        # Sample terrain in search area
        for pos in _sample_grid(search_area, 10.0):  # 10m grid
            var elevation = elevation_provider.get_elevation(Vector2(pos.x, pos.z))
            var slope = _get_slope_at(pos)
            var water_dist = _distance_to_water(pos)
            
            if _matches_rules(elevation, slope, water_dist, rules):
                valid_locations.append(Vector3(pos.x, elevation, pos.z))
        
        return valid_locations
    
    ## Place a building at a location
    func place_building(building_type: BuildingType, position: Vector3) -> BuildingInstance:
        var building = BuildingInstance.new()
        building.type = building_type
        building.position = position
        building.rotation = _calculate_optimal_rotation(position)
        
        # Flatten terrain under building
        _flatten_terrain_for_building(building)
        
        return building
```

**Building Data Structure**:
```gdscript
class BuildingInstance:
    var type: BuildingType
    var position: Vector3
    var rotation: float  # Y-axis rotation
    var scale: Vector3 = Vector3.ONE
    var model_path: String
    var collision_shape: Shape3D
    var is_destructible: bool = false
    var radar_signature: float = 0.0  # For sonar/radar detection
```

### Realistic Coastal Feel Checklist

To achieve a realistic coastal feel, the following elements should be implemented:

1. **Visual Elements**:
   - [ ] Sandy beach texture with wave-washed appearance
   - [ ] Pebble/shingle texture for steeper beaches
   - [ ] Rocky shore with barnacles and seaweed
   - [ ] Cliff faces with erosion patterns
   - [ ] Tidal zone with wet/dry appearance
   - [ ] Foam line at water's edge

2. **Terrain Features**:
   - [ ] Gentle beach slopes (< 10 degrees)
   - [ ] Dune formations behind beaches
   - [ ] Rocky outcrops and tide pools
   - [ ] Cliff erosion patterns
   - [ ] River mouths and estuaries

3. **Dynamic Elements** (future):
   - [ ] Tidal water level changes
   - [ ] Wave foam on beaches
   - [ ] Seabirds near coast
   - [ ] Boats and ships near harbors

4. **Audio** (future):
   - [ ] Wave sounds on beaches
   - [ ] Seabird calls
   - [ ] Harbor sounds near docks

### ProceduralDetailGenerator (Modified)

**Changes**:
- Increase detail_scale from 2.0 to 30.0 meters
- Add flat_terrain_threshold parameter
- Add aggressive_enhancement mode for flat terrain
- Ensure world-space noise coordinates

**Modified Interface**:
```gdscript
class_name ProceduralDetailGenerator extends Node

## Detail configuration (MODIFIED VALUES)
@export var detail_scale: float = 30.0  # Was 2.0, now 30m base amplitude
@export var detail_frequency: float = 0.02  # Lower frequency for larger features
@export var detail_octaves: int = 4  # More octaves for natural variation
@export var detail_contribution: float = 0.5  # 50% contribution (was 0.1)

## Flat terrain enhancement
@export var flat_terrain_threshold: float = 0.05  # 5% variation threshold
@export var flat_terrain_amplitude: float = 35.0  # 20-50m range, use 35m

## Generate detail heightmap for a chunk
## MODIFIED: Now properly uses world-space coordinates
func generate_detail(
    base_heightmap: Image,
    chunk_coord: Vector2i,
    chunk_size_meters: float
) -> Image

## Check if heightmap is flat (needs enhancement)
func is_flat_terrain(heightmap: Image) -> bool

## Get heightmap statistics
func get_heightmap_stats(heightmap: Image) -> Dictionary
```

### ChunkRenderer (Modified)

**Changes**:
- Use mission area height range instead of Earth range
- Reduce depth-based darkening in shader
- Add debug color mode

**Modified Interface**:
```gdscript
class_name ChunkRenderer extends Node

## Height scaling (MODIFIED - mission area instead of Earth range)
@export var min_elevation: float = -200.0  # Mission area minimum
@export var max_elevation: float = 100.0   # Mission area maximum

## Debug mode
@export var debug_color_mode: bool = false

## Create terrain mesh with proper height scaling
func create_chunk_mesh(
    heightmap: Image,
    biome_map: Image,
    chunk_coord: Vector2i,
    lod_level: int,
    neighbor_lods: Dictionary = {}
) -> ArrayMesh
```

### ChunkManager (Modified)

**Changes**:
- Use TiledElevationProvider instead of ElevationDataProvider
- Log heightmap statistics
- Detect flat terrain and apply enhancement

**Modified Interface**:
```gdscript
class_name ChunkManager extends Node

## Load chunk with flat terrain detection
func load_chunk(chunk_coord: Vector2i) -> TerrainChunk

## Get heightmap statistics for debugging
func get_chunk_stats(chunk_coord: Vector2i) -> Dictionary
```

## Data Models

### TileIndex

```gdscript
## Tile index for O(1) lookup
class TileIndex:
    var tiles: Dictionary = {}  # Vector2i -> TileInfo
    var tile_size_meters: float
    var tile_size_pixels: int
    var min_coord: Vector2i
    var max_coord: Vector2i
    
    func get_tile_for_world_pos(world_pos: Vector2) -> TileInfo
    func get_tiles_for_region(world_bounds: Rect2) -> Array[TileInfo]
```

### TileInfo

```gdscript
class TileInfo:
    var coord: Vector2i
    var file_path: String
    var world_bounds: Rect2
    var resolution: int
    var has_lod_variants: bool
```

### HeightmapStats

```gdscript
class HeightmapStats:
    var min_value: float
    var max_value: float
    var range: float
    var mean: float
    var is_flat: bool  # range < flat_terrain_threshold
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Minimum Height Variation

*For any* rendered terrain chunk, the mesh AABB Y-range (max_y - min_y) should be at least 10 meters.

**Validates: Requirements 1.1**

### Property 2: Flat Terrain Enhancement

*For any* base heightmap with less than 5% variation (range < 0.05), after procedural enhancement the output heightmap should have at least 20 meters of height variation.

**Validates: Requirements 1.2, 2.2**

### Property 3: Procedural Detail Contribution

*For any* heightmap with procedural detail applied, the detail contribution should be at least 50% of the total height range. Mathematically: `detail_range / total_range >= 0.5`

**Validates: Requirements 2.1**

### Property 4: Mission Area Height Mapping

*For any* normalized heightmap value in range [0, 1], the converted world height should be within the mission area range [min_elevation, max_elevation]. Specifically: `world_height = lerp(min_elevation, max_elevation, normalized_value)`

**Validates: Requirements 3.2**

### Property 5: Procedural Detail Boundary Consistency

*For any* two adjacent chunks sharing an edge, the procedural detail values at corresponding edge pixels should be identical (within floating-point tolerance).

**Validates: Requirements 6.1, 6.2, 6.4**

### Property 6: Resolution Preservation

*For any* elevation data extraction request, the output resolution should be at least the requested resolution (no downsampling below request).

**Validates: Requirements 7.1**

### Property 7: Pixel Value Preservation

*For any* pixel in the source elevation map, when extracted at full resolution, the output value should match the source value within floating-point tolerance.

**Validates: Requirements 7.4**

### Property 8: Bilinear Interpolation Smoothness

*For any* position between source pixels, the interpolated value should be between the values of the surrounding pixels (no extrapolation artifacts).

**Validates: Requirements 7.2**

### Property 9: Tile Index O(1) Lookup

*For any* world position, the tile lookup should complete in constant time regardless of the number of tiles.

**Validates: Requirements 8.4**

### Property 10: Unified Elevation Data Consistency

*For any* world position, elevation queries from terrain rendering, tactical map, and sonar should return identical values.

**Validates: Requirements 9.2, 9.3**

## Error Handling

### Missing Tile Files

**Scenario**: Pre-processed tile files are missing or corrupted.

**Handling**:
1. Log warning with missing tile path
2. Fall back to source image extraction
3. Continue normal operation
4. Mark tile as unavailable to prevent repeated attempts

### Source Image Missing

**Scenario**: Both tiles and source image are unavailable.

**Handling**:
1. Log error
2. Generate fully procedural terrain
3. Use aggressive procedural detail to create interesting terrain
4. Continue operation with procedural fallback

### Flat Terrain Detection

**Scenario**: Base heightmap has insufficient variation.

**Handling**:
1. Calculate heightmap statistics (min, max, range)
2. If range < 5% (0.05), flag as flat terrain
3. Apply aggressive procedural enhancement (35m amplitude)
4. Log that enhancement was applied

### Memory Pressure

**Scenario**: Too many tiles loaded in memory.

**Handling**:
1. Use LRU cache for tiles
2. Unload distant tiles first
3. Keep minimum tiles for current view
4. Log memory usage for debugging

## Testing Strategy

### Unit Tests

**Height Scaling**:
- Test normalized value 0.0 maps to min_elevation
- Test normalized value 1.0 maps to max_elevation
- Test normalized value 0.5 maps to midpoint
- Test values outside [0,1] are clamped

**Heightmap Statistics**:
- Test min/max calculation on known heightmap
- Test flat terrain detection threshold
- Test range calculation

**Tile Index**:
- Test world position to tile coordinate conversion
- Test tile lookup for various positions
- Test boundary conditions

### Property-Based Tests

All properties listed in the Correctness Properties section should be implemented as property-based tests using GdUnit4 with random input generation.

**Test Configuration**:
- Minimum 100 iterations per property test
- Use random heightmaps, chunk coordinates, and world positions
- Tag format: **Feature: terrain-rendering-fix, Property N: [property text]**

**Property Test Examples**:

```gdscript
# Property 1: Minimum Height Variation
func test_minimum_height_variation():
    for i in range(100):
        var chunk = generate_random_chunk()
        var mesh = chunk_renderer.create_chunk_mesh(chunk.heightmap, ...)
        var aabb = mesh.get_aabb()
        assert_gte(aabb.size.y, 10.0, "Chunk should have >= 10m height variation")

# Property 5: Boundary Consistency
func test_boundary_consistency():
    for i in range(100):
        var coord1 = Vector2i(randi() % 100, randi() % 100)
        var coord2 = Vector2i(coord1.x + 1, coord1.y)  # Adjacent chunk
        var detail1 = generator.generate_detail(base, coord1, 512.0)
        var detail2 = generator.generate_detail(base, coord2, 512.0)
        # Compare right edge of chunk1 with left edge of chunk2
        for y in range(detail1.get_height()):
            var val1 = detail1.get_pixel(detail1.get_width() - 1, y).r
            var val2 = detail2.get_pixel(0, y).r
            assert_almost_eq(val1, val2, 0.001, "Edge values should match")
```

### Integration Tests

**End-to-End Terrain Loading**:
- Load terrain around submarine spawn
- Verify chunks have visible height variation
- Verify no seams at chunk boundaries
- Verify collision matches visual terrain

**Unified Data Access**:
- Query elevation from terrain system
- Query same position from tactical map
- Query same position from sonar
- Verify all return identical values

### Visual Tests

**Terrain Visibility**:
- Hide ocean via debug UI
- Verify terrain is visible against neutral background
- Capture screenshots for regression testing

**Debug Color Mode**:
- Enable debug color mode
- Verify terrain renders with bright colors
- Verify height variation is visible

## Calibration System

### Height Calibration Using Known Reference Points

To ensure accurate terrain heights, the system will use known geographic reference points to calibrate the heightmap:

**Reference Points**:
1. **Mariana Trench** (-10,994m) - Darkest pixel in source map
2. **Mount Everest** (+8,849m) - Brightest pixel in source map
3. **Sea Level** (0m) - Calibrated visually or from known coastal locations

**Calibration Process**:
1. Scan source heightmap for min/max pixel values
2. Map min pixel → Mariana Trench depth
3. Map max pixel → Everest height
4. Calculate linear interpolation factor
5. Store calibration data for runtime use

**Calibration Data Structure**:
```gdscript
class HeightCalibration:
    var min_pixel_value: float  # Darkest pixel (0-1)
    var max_pixel_value: float  # Brightest pixel (0-1)
    var min_elevation: float = -10994.0  # Mariana Trench
    var max_elevation: float = 8849.0    # Mount Everest
    var sea_level_pixel: float  # Pixel value that corresponds to sea level
    var sea_level_meters: float = 0.0
    
    func pixel_to_elevation(pixel_value: float) -> float:
        var normalized = (pixel_value - min_pixel_value) / (max_pixel_value - min_pixel_value)
        return lerp(min_elevation, max_elevation, normalized)
    
    func elevation_to_pixel(elevation: float) -> float:
        var normalized = (elevation - min_elevation) / (max_elevation - min_elevation)
        return lerp(min_pixel_value, max_pixel_value, normalized)
```

### Visual Sea Level Calibration

Since sea level may not be exactly at pixel value 0.5, we need a visual calibration tool:

**Sea Level Calibration UI**:
1. Add slider in Ocean Debug UI (F3 panel) for "Sea Level Offset"
2. Range: -50m to +50m adjustment
3. Real-time preview: water surface moves up/down
4. When terrain and water align at coastlines, save calibration

**Calibration Workflow**:
1. Navigate submarine to a known coastal area
2. Open F3 debug panel
3. Adjust "Sea Level Offset" slider until water meets terrain at shoreline
4. Click "Save Calibration" to persist the offset
5. Offset is applied to all sea level calculations

**Implementation**:
```gdscript
## In OceanDebugUI
@export var sea_level_offset: float = 0.0

func _on_sea_level_offset_changed(value: float) -> void:
    sea_level_offset = value
    # Update SeaLevelManager with new offset
    if SeaLevelManager:
        SeaLevelManager.set_calibration_offset(value)
    # Update terrain shader sea_level parameter
    _update_terrain_sea_level()

func _save_calibration() -> void:
    var config = ConfigFile.new()
    config.set_value("calibration", "sea_level_offset", sea_level_offset)
    config.save("user://terrain_calibration.cfg")
```

**SeaLevelManager Integration**:
```gdscript
## In SeaLevelManager (autoload)
var calibration_offset: float = 0.0

func _ready() -> void:
    _load_calibration()

func _load_calibration() -> void:
    var config = ConfigFile.new()
    if config.load("user://terrain_calibration.cfg") == OK:
        calibration_offset = config.get_value("calibration", "sea_level_offset", 0.0)

func get_sea_level_meters() -> float:
    return base_sea_level + calibration_offset + dynamic_offset

func set_calibration_offset(offset: float) -> void:
    calibration_offset = offset
```

## Legacy Code Cleanup

### Files to Remove/Modify

After implementation, the following legacy code should be cleaned up:

1. **ElevationDataProvider** (`scripts/rendering/elevation_data_provider.gd`)
   - Replace with TiledElevationProvider
   - Remove after all consumers migrated

2. **Duplicate height scaling logic**
   - Consolidate to ChunkRenderer only
   - Remove from any other locations

3. **Old procedural generation**
   - Remove any procedural terrain code not using ProceduralDetailGenerator
   - Ensure single code path

### Migration Steps

1. Create TiledElevationProvider
2. Update ChunkManager to use TiledElevationProvider
3. Update tactical map to use TiledElevationProvider
4. Update sonar to use TiledElevationProvider
5. Verify all systems work with new provider
6. Remove ElevationDataProvider
7. Remove any other legacy code
