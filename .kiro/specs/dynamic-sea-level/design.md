# Design Document: Dynamic Sea Level Control

## Overview

This feature enables real-time adjustment of sea level in the tactical submarine simulator, allowing users to explore various scenarios such as climate change impacts, ice age conditions, or hypothetical flooding scenarios. The system provides a unified sea level control that affects all rendering, collision, physics, and visualization systems consistently.

The design introduces a central `SeaLevelManager` that coordinates sea level changes across all affected systems. When the user adjusts the sea level slider in the Whole Map View (Screen 4), the manager propagates the change to:

- **3D Terrain Rendering**: Updates shader parameters for underwater darkening effects
- **Biome Detection**: Reclassifies terrain based on new water/land boundaries
- **Ocean Surface**: Adjusts the physical water surface position
- **Collision Detection**: Updates underwater boundaries and safe navigation zones
- **2D Visualizations**: Regenerates map textures with new color thresholds
- **Submarine Physics**: Adapts depth readings and buoyancy calculations

The system uses a normalized elevation model (0.0 to 1.0) that maps to real-world elevations from the Mariana Trench (-10,994m) to Mount Everest (+8,849m). The default sea level of 0.554 normalized corresponds to 0m elevation in the real world.

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    WholeMapView (UI)                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Sea Level Slider (0.0 - 1.0)                        │  │
│  │  Display: Normalized + Metric (meters)               │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │ set_sea_level(normalized_value)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              SeaLevelManager (Singleton)                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  • Current sea level (normalized 0-1)                │  │
│  │  • Current sea level (meters)                        │  │
│  │  • Signal: sea_level_changed(normalized, meters)     │  │
│  │  • Methods: set_sea_level(), get_sea_level()         │  │
│  │  • Methods: reset_to_default()                       │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │ Broadcasts to all systems
         ┌───────────────┼───────────────┬─────────────────┐
         ▼               ▼               ▼                 ▼
┌─────────────┐  ┌──────────────┐  ┌──────────┐  ┌──────────────┐
│  Terrain    │  │    Biome     │  │  Ocean   │  │  Collision   │
│  Renderer   │  │   Detector   │  │ Renderer │  │   Manager    │
└─────────────┘  └──────────────┘  └──────────┘  └──────────────┘
         │               │               │                 │
         └───────────────┴───────────────┴─────────────────┘
                         │
                         ▼
         ┌───────────────────────────────────┐
         │  2D Visualization Systems         │
         │  • WholeMapView                   │
         │  • TacticalMapView                │
         └───────────────────────────────────┘
```

### Data Flow

1. **User Input**: User adjusts slider in WholeMapView debug panel
2. **Validation**: SeaLevelManager validates and stores the new value
3. **Signal Broadcast**: `sea_level_changed` signal emitted with both normalized and metric values
4. **System Updates**: All connected systems receive signal and update their state:
   - TerrainRenderer updates shader parameters for all loaded chunks
   - BiomeDetector recalculates biome classifications
   - OceanRenderer adjusts water surface Y position
   - CollisionManager updates underwater boundary checks
   - Visualization systems regenerate map textures
5. **Visual Feedback**: UI displays updated elevation info and visual indicators

## Components and Interfaces

### SeaLevelManager (New Singleton)

**Purpose**: Central authority for sea level state and change propagation.

**Location**: `scripts/core/sea_level_manager.gd`

**Properties**:
```gdscript
var current_sea_level_normalized: float = 0.554  # Default (0m elevation)
var current_sea_level_meters: float = 0.0
const DEFAULT_SEA_LEVEL: float = 0.554
const MARIANA_TRENCH_DEPTH: float = -10994.0
const MOUNT_EVEREST_HEIGHT: float = 8849.0
```

**Signals**:
```gdscript
signal sea_level_changed(normalized_value: float, meters_value: float)
```

**Methods**:
```gdscript
func set_sea_level(normalized: float) -> void
func get_sea_level_normalized() -> float
func get_sea_level_meters() -> float
func reset_to_default() -> void
func normalized_to_meters(normalized: float) -> float
func meters_to_normalized(meters: float) -> float
```

**Implementation Notes**:
- Autoload singleton registered in project settings
- Validates input range (0.0 to 1.0)
- Converts between normalized and metric values
- Emits signal only when value actually changes
- Thread-safe for potential async updates

### TerrainRenderer Updates

**Modified Methods**:
```gdscript
func _on_sea_level_changed(normalized: float, meters: float) -> void:
    # Update all loaded chunks with new sea level
    if _chunk_manager:
        for chunk_coord in _chunk_manager.get_loaded_chunks():
            var chunk = _chunk_manager.get_chunk(chunk_coord)
            if chunk and chunk.material:
                chunk.material.set_shader_parameter("sea_level", meters)
```

**Integration**:
- Connect to `SeaLevelManager.sea_level_changed` signal in `_ready()`
- Update shader parameter for all loaded chunks
- New chunks automatically receive current sea level from manager

### ChunkRenderer Updates

**Modified Methods**:
```gdscript
func create_chunk_material(biome_map: Image, bump_map: Image) -> ShaderMaterial:
    var material = ShaderMaterial.new()
    material.shader = terrain_shader
    # ... existing texture setup ...
    
    # Get current sea level from manager
    var sea_level = SeaLevelManager.get_sea_level_meters()
    material.set_shader_parameter("sea_level", sea_level)
    
    return material
```

**Integration**:
- Query SeaLevelManager when creating new chunk materials
- Ensures new chunks use current sea level

### BiomeDetector Updates

**Modified Methods**:
```gdscript
func detect_biomes(heightmap: Image, sea_level_override: float = NAN) -> Image:
    var effective_sea_level: float
    if not is_nan(sea_level_override):
        effective_sea_level = sea_level_override
    else:
        # Get current sea level from manager (in meters)
        effective_sea_level = SeaLevelManager.get_sea_level_meters()
    
    # Convert meters to normalized for heightmap comparison
    var sea_level_normalized = SeaLevelManager.meters_to_normalized(effective_sea_level)
    
    # ... existing biome detection logic using sea_level_normalized ...
```

**Integration**:
- Query SeaLevelManager for current sea level when detecting biomes
- Convert between meters and normalized as needed
- Maintain backward compatibility with sea_level_override parameter

### OceanRenderer Updates

**Modified Properties**:
```gdscript
@export_group("Ocean Level")
@export var sea_level_offset: float = 0.0  # Offset from manager's sea level
```

**Modified Methods**:
```gdscript
func _on_sea_level_changed(normalized: float, meters: float) -> void:
    # Update ocean surface position
    global_position.y = meters + sea_level_offset
    
    # Update quad_tree position if it exists
    if quad_tree:
        quad_tree.global_position.y = meters + sea_level_offset

func get_wave_height_3d(world_pos: Vector3) -> float:
    if not initialized or not ocean or not ocean.initialized:
        return SeaLevelManager.get_sea_level_meters()
    
    var active_camera = get_viewport().get_camera_3d()
    if not active_camera:
        return SeaLevelManager.get_sea_level_meters()
    
    var displacement = ocean.get_wave_height(active_camera, world_pos, 3, 2)
    return SeaLevelManager.get_sea_level_meters() + displacement
```

**Integration**:
- Connect to `SeaLevelManager.sea_level_changed` signal in `_ready()`
- Update Y position of ocean surface and quad tree
- Use manager's sea level in wave height calculations

### CollisionManager Updates

**Modified Methods**:
```gdscript
func is_underwater_safe(world_pos: Vector3, clearance: float) -> bool:
    # Get current sea level from manager
    var sea_level = SeaLevelManager.get_sea_level_meters()
    
    # Check if below sea level
    if world_pos.y >= sea_level:
        return false
    
    # Get terrain height at this position
    var terrain_height: float = get_height_at(Vector2(world_pos.x, world_pos.z))
    
    # Check if we have sufficient clearance above terrain
    var height_above_terrain: float = world_pos.y - terrain_height
    
    return height_above_terrain >= clearance
```

**Integration**:
- Query SeaLevelManager for current sea level in underwater checks
- Update safe spawn position calculations
- Adjust collision boundary checks

### WholeMapView Updates

**Modified Properties**:
```gdscript
# Remove local sea_level_threshold, use SeaLevelManager instead
```

**Modified Methods**:
```gdscript
func _on_sea_level_changed(value: float) -> void:
    # Update the manager (which will trigger updates everywhere)
    SeaLevelManager.set_sea_level(value)
    
    # Update UI display
    var elevation_meters = SeaLevelManager.get_sea_level_meters()
    if _debug_panel:
        var value_label = _debug_panel.find_child("SeaLevelValue", true, false)
        if value_label:
            value_label.text = "%.3f (%.0fm elevation, Default: 0.554)" % [value, elevation_meters]
    
    # Regenerate map with new sea level
    if global_map_image:
        _create_optimized_map()
        if map_canvas:
            map_canvas.queue_redraw()
        if map_zoom > 1.5:
            _generate_detail_texture()

func _create_optimized_map() -> void:
    if not global_map_image: return
    
    # Get current sea level from manager
    var sea_level_threshold = SeaLevelManager.get_sea_level_normalized()
    
    # ... existing map generation logic using sea_level_threshold ...
```

**Integration**:
- Connect slider to SeaLevelManager.set_sea_level()
- Query manager for current values when regenerating maps
- Display both normalized and metric values in UI

### TacticalMapView Updates

**Modified Methods**:
```gdscript
func _on_sea_level_changed(normalized: float, meters: float) -> void:
    # Regenerate tactical map with new sea level threshold
    if terrain_renderer and terrain_renderer.heightmap_region:
        _regenerate_map_texture()

func _regenerate_map_texture() -> void:
    # Get current sea level from manager
    var sea_level_threshold = SeaLevelManager.get_sea_level_normalized()
    
    # ... existing map generation logic using sea_level_threshold ...
```

**Integration**:
- Connect to `SeaLevelManager.sea_level_changed` signal
- Regenerate map texture when sea level changes
- Use manager's normalized value for color thresholding

## Data Models

### Elevation Scaling Model

The system uses a consistent elevation model across all components:

```gdscript
# Constants (defined in SeaLevelManager)
const MARIANA_TRENCH_DEPTH: float = -10994.0  # Lowest point on Earth
const MOUNT_EVEREST_HEIGHT: float = 8849.0    # Highest point on Earth
const DEFAULT_SEA_LEVEL: float = 0.554        # Normalized value for 0m elevation

# Conversion functions
func normalized_to_meters(normalized: float) -> float:
    return lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, normalized)

func meters_to_normalized(meters: float) -> float:
    return inverse_lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, meters)
```

**Normalized Range (0.0 - 1.0)**:
- 0.0 = Mariana Trench (-10,994m)
- 0.554 = Sea Level (0m) - Default
- 1.0 = Mount Everest (+8,849m)

**Metric Range (-10,994m to +8,849m)**:
- Used for 3D world positions (Y coordinate)
- Used for physics calculations
- Used for display to user

### Sea Level State

```gdscript
class SeaLevelState:
    var normalized: float  # 0.0 to 1.0
    var meters: float      # -10994.0 to +8849.0
    var is_default: bool   # true if at 0.554 (0m)
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Sea level consistency across systems

*For any* sea level value set through the manager, all systems (terrain shader, biome detector, ocean renderer, collision manager, and visualization systems) should report and use the same sea level value.

**Validates: Requirements 1.2, 2.1, 3.1, 4.1, 5.1, 6.3**

### Property 2: Elevation conversion round-trip

*For any* valid normalized elevation value (0.0 to 1.0), converting to meters and back to normalized should produce an equivalent value (within floating-point precision).

**Validates: Requirements 1.3**

### Property 3: Shader parameter propagation

*For any* loaded terrain chunk, when sea level changes, the chunk's material should have its sea_level shader parameter updated to match the manager's current value.

**Validates: Requirements 2.1, 2.4**

### Property 4: Biome reclassification on sea level change

*For any* terrain heightmap, when sea level changes, biome classifications should be recalculated such that elevations below the new sea level are classified as underwater biomes and elevations above are classified as land biomes.

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 5: Ocean surface position matches sea level

*For any* sea level value, the ocean renderer's Y position should equal the sea level in meters (plus any configured offset).

**Validates: Requirements 4.1, 4.4**

### Property 6: Underwater boundary consistency

*For any* world position, the collision manager's underwater check should return true if and only if the position's Y coordinate is below the current sea level (with appropriate clearance).

**Validates: Requirements 5.1, 5.2**

### Property 7: Map visualization threshold consistency

*For any* sea level value, both the Whole Map View and Tactical Map View should use the same normalized threshold for determining water vs land colors.

**Validates: Requirements 6.1, 6.2, 6.3**

### Property 8: UI display accuracy

*For any* sea level value, the UI should display both the normalized value (0.0-1.0) and the corresponding metric value in meters, and these values should be consistent with the manager's conversion functions.

**Validates: Requirements 1.3, 10.1**

### Property 9: Reset to default

*For any* current sea level value, calling reset_to_default() should set the sea level to 0.554 normalized (0m elevation).

**Validates: Requirements 8.2**

### Property 10: View persistence

*For any* sea level value, switching between views (External, Periscope, Tactical, Whole Map) should maintain the same sea level value.

**Validates: Requirements 8.3, 8.4**

## Error Handling

### Input Validation

**Invalid Slider Values**:
- Clamp input to valid range (0.0 to 1.0)
- Log warning if out-of-range value attempted
- Display error message in UI if extreme values cause issues

**Null Reference Checks**:
- Verify SeaLevelManager exists before querying
- Provide fallback to default sea level (0.554) if manager unavailable
- Log errors if critical systems fail to connect to manager

### System Update Failures

**Chunk Update Failures**:
- Continue updating other chunks if one fails
- Log error with chunk coordinates
- Retry on next sea level change

**Biome Reclassification Failures**:
- Use previous biome map if reclassification fails
- Log error with heightmap details
- Queue for retry on next update

**Ocean Renderer Failures**:
- Maintain previous ocean position if update fails
- Log error and continue simulation
- Attempt recovery on next frame

### Performance Safeguards

**Update Throttling**:
- Debounce rapid slider changes (100ms minimum between updates)
- Queue updates if system is busy
- Skip intermediate values if slider moved quickly

**Memory Management**:
- Limit number of chunks updated per frame
- Spread biome reclassification across multiple frames if needed
- Monitor memory usage during map regeneration

### Recovery Strategies

**Graceful Degradation**:
- If shader update fails, continue with previous sea level
- If biome detection fails, use default biome map
- If ocean update fails, maintain previous position

**User Notification**:
- Display warning in debug panel if updates are slow
- Show progress indicator during large updates
- Provide "Cancel" option for long-running operations

## Testing Strategy

### Unit Tests

**SeaLevelManager Tests**:
- Test elevation conversion functions (normalized ↔ meters)
- Test signal emission on value changes
- Test reset to default functionality
- Test input validation and clamping
- Test thread safety of get/set operations

**Integration Tests**:
- Test terrain shader parameter updates
- Test biome reclassification triggers
- Test ocean position updates
- Test collision boundary updates
- Test map texture regeneration

### Property-Based Tests

**Configuration**: Each property test runs 100 iterations with randomized inputs.

**Property 1 Test**: Sea level consistency
```gdscript
# Feature: dynamic-sea-level, Property 1: Sea level consistency across systems
# Generate random sea level value
# Set via manager
# Query all systems
# Assert all return same value
```

**Property 2 Test**: Elevation conversion round-trip
```gdscript
# Feature: dynamic-sea-level, Property 2: Elevation conversion round-trip
# Generate random normalized value (0.0-1.0)
# Convert to meters
# Convert back to normalized
# Assert values are equivalent (within epsilon)
```

**Property 3 Test**: Shader parameter propagation
```gdscript
# Feature: dynamic-sea-level, Property 3: Shader parameter propagation
# Generate random sea level
# Create random terrain chunks
# Set sea level via manager
# Assert all chunk materials have correct sea_level parameter
```

**Property 4 Test**: Biome reclassification
```gdscript
# Feature: dynamic-sea-level, Property 4: Biome reclassification on sea level change
# Generate random heightmap
# Generate random sea level
# Detect biomes
# Assert elevations below sea level are underwater biomes
# Assert elevations above sea level are land biomes
```

**Property 5 Test**: Ocean surface position
```gdscript
# Feature: dynamic-sea-level, Property 5: Ocean surface position matches sea level
# Generate random sea level
# Set via manager
# Assert ocean renderer Y position equals sea level in meters
```

**Property 6 Test**: Underwater boundary consistency
```gdscript
# Feature: dynamic-sea-level, Property 6: Underwater boundary consistency
# Generate random world position
# Generate random sea level
# Query collision manager
# Assert underwater check matches (position.y < sea_level)
```

**Property 7 Test**: Map visualization threshold
```gdscript
# Feature: dynamic-sea-level, Property 7: Map visualization threshold consistency
# Generate random sea level
# Set via manager
# Query WholeMapView threshold
# Query TacticalMapView threshold
# Assert both use same normalized value
```

**Property 8 Test**: UI display accuracy
```gdscript
# Feature: dynamic-sea-level, Property 8: UI display accuracy
# Generate random sea level
# Set via manager
# Query UI display values
# Assert normalized and metric values match manager's conversions
```

**Property 9 Test**: Reset to default
```gdscript
# Feature: dynamic-sea-level, Property 9: Reset to default
# Generate random sea level
# Set via manager
# Call reset_to_default()
# Assert sea level is 0.554 normalized (0m)
```

**Property 10 Test**: View persistence
```gdscript
# Feature: dynamic-sea-level, Property 10: View persistence
# Generate random sea level
# Set via manager
# Switch between random views
# Assert sea level remains constant
```

### Manual Testing Scenarios

**Scenario 1: Basic Slider Interaction**
1. Open Whole Map View (F4)
2. Open debug panel (F3)
3. Move sea level slider
4. Verify map colors update in real-time
5. Verify elevation display updates

**Scenario 2: 3D World Consistency**
1. Set sea level to high value (e.g., 0.7 = ~3000m)
2. Switch to External View (F1)
3. Verify terrain underwater darkening
4. Verify ocean surface at correct height
5. Verify submarine depth readings adjusted

**Scenario 3: Extreme Values**
1. Set sea level to minimum (0.0 = -10,994m)
2. Verify all land is above water
3. Set sea level to maximum (1.0 = +8,849m)
4. Verify all terrain is underwater
5. Verify no crashes or visual artifacts

**Scenario 4: Performance**
1. Set sea level to mid-range value
2. Monitor frame rate
3. Rapidly adjust slider
4. Verify updates complete within 100ms
5. Verify no frame drops or stuttering

**Scenario 5: Reset Functionality**
1. Set sea level to arbitrary value
2. Click "Reset to Default" button
3. Verify sea level returns to 0.554 (0m)
4. Verify all systems update correctly

### Performance Benchmarks

**Target Metrics**:
- Shader parameter update: < 10ms for all loaded chunks
- Biome reclassification: < 50ms per chunk
- Map texture regeneration: < 100ms for Whole Map View
- Ocean position update: < 1ms
- Total update time: < 100ms for typical scenario (10 loaded chunks)

**Stress Test**:
- 50 loaded chunks
- Rapid slider changes (10 per second)
- Monitor memory usage
- Verify no memory leaks
- Verify frame rate remains > 30 FPS
