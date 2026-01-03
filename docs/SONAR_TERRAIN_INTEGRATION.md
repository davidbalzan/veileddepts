# Sonar-Terrain Integration Guide

## Overview

The terrain system provides a comprehensive interface for sonar integration, allowing the sonar system to query terrain geometry, calculate surface normals for realistic reflections, and perform beam-based terrain queries for active sonar simulation.

## Quick Start

### Basic Terrain Query

```gdscript
# Get reference to collision manager
var collision_manager = get_node("/root/Main/CollisionManager")

# Query terrain within sonar range
var submarine_pos = Vector3(0, -100, 0)
var sonar_range = 5000.0  # 5 km
var simplification = 1  # Medium detail

var terrain_data = collision_manager.get_terrain_geometry_for_sonar(
    submarine_pos,
    sonar_range,
    simplification
)

# Access results
var positions: PackedVector3Array = terrain_data["positions"]
var normals: PackedVector3Array = terrain_data["normals"]

print("Found ", positions.size(), " terrain points within range")
```

### Surface Normal Query

```gdscript
# Get surface normal at a specific position
var hit_position = Vector3(100, -50, 200)
var surface_normal = collision_manager.get_surface_normal_for_sonar(hit_position)

# Use normal for reflection calculation
var incident_direction = Vector3(0, 1, 0)
var reflected = incident_direction.reflect(surface_normal)
```

### Active Sonar Beam Query

```gdscript
# Query terrain within a sonar beam cone
var beam_origin = submarine_pos
var beam_direction = Vector3(0, 1, 0).rotated(Vector3.RIGHT, deg_to_rad(-30))
var beam_range = 3000.0  # 3 km
var beam_width = deg_to_rad(30)  # 30 degree cone

var beam_hits = collision_manager.query_terrain_for_sonar_beam(
    beam_origin,
    beam_direction,
    beam_range,
    beam_width
)

# Process hits
for hit in beam_hits:
    var pos: Vector3 = hit["position"]
    var normal: Vector3 = hit["normal"]
    var distance: float = hit["distance"]
    
    print("Hit at ", pos, " distance: ", distance, "m")
```

## API Reference

### get_terrain_geometry_for_sonar()

Returns simplified terrain geometry within sonar range.

**Signature**:
```gdscript
func get_terrain_geometry_for_sonar(
    origin: Vector3,
    max_range: float,
    simplification_level: int = 1
) -> Dictionary
```

**Parameters**:
- `origin` - Sonar origin position (typically submarine position)
- `max_range` - Maximum sonar range in meters
- `simplification_level` - Geometry detail level (0-3):
  - 0: Full detail (every pixel)
  - 1: Medium detail (every 2nd pixel) - **Recommended**
  - 2: Low detail (every 4th pixel)
  - 3: Very low detail (every 8th pixel)

**Returns**:
Dictionary with:
- `positions: PackedVector3Array` - Terrain point positions
- `normals: PackedVector3Array` - Surface normals (same count as positions)

**Performance**: O(chunks × resolution²) where resolution depends on simplification level

### get_surface_normal_for_sonar()

Returns surface normal at a specific world position.

**Signature**:
```gdscript
func get_surface_normal_for_sonar(world_pos: Vector3) -> Vector3
```

**Parameters**:
- `world_pos` - World position to query (3D)

**Returns**:
- Normalized surface normal vector
- Returns `Vector3.UP` if chunk not loaded

**Performance**: O(1) - Single heightmap lookup with finite differences

### query_terrain_for_sonar_beam()

Queries terrain within a directional sonar beam cone.

**Signature**:
```gdscript
func query_terrain_for_sonar_beam(
    origin: Vector3,
    direction: Vector3,
    max_range: float,
    beam_width: float = PI / 6.0
) -> Array[Dictionary]
```

**Parameters**:
- `origin` - Beam origin position
- `direction` - Beam direction (will be normalized)
- `max_range` - Maximum beam range in meters
- `beam_width` - Beam cone angle in radians (default: 30°)

**Returns**:
Array of dictionaries, each containing:
- `position: Vector3` - Hit position
- `normal: Vector3` - Surface normal at hit
- `distance: float` - Distance from origin

**Performance**: O(chunks × resolution²) with cone filtering

## Integration Patterns

### Passive Sonar

For passive sonar (listening only), you typically want to know what terrain is nearby that could affect sound propagation:

```gdscript
func update_passive_sonar():
    var terrain_data = collision_manager.get_terrain_geometry_for_sonar(
        submarine_position,
        passive_sonar_range,
        2  # Low detail is fine for passive
    )
    
    # Check if terrain blocks line of sight to contacts
    for contact in detected_contacts:
        if is_terrain_blocking(submarine_position, contact.position, terrain_data):
            contact.signal_strength *= 0.5  # Terrain attenuation
```

### Active Sonar Ping

For active sonar, you want to simulate a directional ping:

```gdscript
func send_active_ping(direction: Vector3):
    var beam_hits = collision_manager.query_terrain_for_sonar_beam(
        submarine_position,
        direction,
        active_sonar_range,
        sonar_beam_width
    )
    
    # Find closest terrain return
    var closest_hit = null
    var closest_distance = INF
    
    for hit in beam_hits:
        if hit["distance"] < closest_distance:
            closest_distance = hit["distance"]
            closest_hit = hit
    
    if closest_hit:
        # Display terrain return on sonar display
        display_sonar_return(closest_hit["position"], closest_distance)
```

### Terrain Avoidance

For collision avoidance, check terrain ahead of submarine:

```gdscript
func check_terrain_ahead():
    var forward = submarine_transform.basis.z
    var look_ahead_distance = 500.0  # 500m
    
    var terrain_ahead = collision_manager.query_terrain_for_sonar_beam(
        submarine_position,
        forward,
        look_ahead_distance,
        deg_to_rad(45)  # Wide cone for safety
    )
    
    if not terrain_ahead.is_empty():
        var closest = terrain_ahead[0]["distance"]
        if closest < 100.0:  # Less than 100m ahead
            emit_signal("terrain_warning", closest)
```

### Sonar Display Rendering

For rendering terrain on a sonar display:

```gdscript
func render_sonar_display():
    # Get terrain in all directions
    var terrain_data = collision_manager.get_terrain_geometry_for_sonar(
        submarine_position,
        display_range,
        1  # Medium detail for display
    )
    
    # Convert to polar coordinates for circular display
    for i in range(terrain_data["positions"].size()):
        var pos = terrain_data["positions"][i]
        var relative = pos - submarine_position
        
        var bearing = atan2(relative.x, relative.z)
        var distance = relative.length()
        
        # Draw on sonar display
        draw_sonar_contact(bearing, distance, 0.5)  # 0.5 = terrain intensity
```

## Performance Guidelines

### Update Frequency

- **Passive sonar**: Update every 5 seconds (low frequency)
- **Active sonar**: Update on ping (2-5 second intervals)
- **Terrain avoidance**: Update every 1 second (continuous)

### Simplification Levels

Choose simplification based on use case:

| Use Case | Recommended Level | Reason |
|----------|------------------|---------|
| Passive sonar | 2 (Low) | Rough terrain shape sufficient |
| Active sonar display | 1 (Medium) | Balance detail and performance |
| Terrain avoidance | 1 (Medium) | Need accurate nearby terrain |
| Sonar simulation | 0 (Full) | Accurate reflections needed |

### Range Limits

Recommended maximum ranges:

- **Passive sonar**: 10,000m (10 km)
- **Active sonar**: 5,000m (5 km)
- **Terrain avoidance**: 1,000m (1 km)

Larger ranges will query more chunks and return more data.

## Troubleshooting

### No Terrain Data Returned

**Problem**: `get_terrain_geometry_for_sonar()` returns empty arrays.

**Solutions**:
1. Check if chunks are loaded: `chunk_manager.get_loaded_chunks()`
2. Verify submarine is near loaded terrain
3. Increase `max_range` parameter
4. Check if `collision_manager` has valid `chunk_manager` reference

### Normals Point Wrong Direction

**Problem**: Surface normals seem inverted or incorrect.

**Solutions**:
1. Verify heightmap data is correct
2. Check that terrain is properly generated
3. Ensure chunk is in LOADED state
4. Verify world position is within loaded chunks

### Poor Performance

**Problem**: Sonar queries cause frame rate drops.

**Solutions**:
1. Increase `simplification_level` (try 2 or 3)
2. Reduce `max_range`
3. Reduce update frequency
4. Use beam queries instead of full geometry queries
5. Cache results and reuse for multiple frames

### Beam Query Returns Too Many/Few Points

**Problem**: Beam query returns unexpected number of points.

**Solutions**:
1. Adjust `beam_width` parameter
2. Check `direction` vector is normalized
3. Verify `max_range` is appropriate
4. Ensure terrain exists in beam direction

## Advanced Topics

### Custom Beam Patterns

You can implement custom beam patterns by filtering the results:

```gdscript
func custom_beam_query(origin: Vector3, direction: Vector3, range: float) -> Array:
    # Get all terrain in range
    var terrain = collision_manager.get_terrain_geometry_for_sonar(origin, range, 1)
    
    # Custom filtering logic
    var filtered = []
    for i in range(terrain["positions"].size()):
        var pos = terrain["positions"][i]
        var to_point = (pos - origin).normalized()
        
        # Custom beam pattern (e.g., elliptical)
        var dot_h = direction.dot(to_point)
        var dot_v = Vector3.UP.dot(to_point)
        
        if dot_h > 0.8 and abs(dot_v) < 0.3:  # Horizontal beam
            filtered.append({
                "position": pos,
                "normal": terrain["normals"][i],
                "distance": origin.distance_to(pos)
            })
    
    return filtered
```

### Acoustic Shadowing

Simulate acoustic shadows behind terrain:

```gdscript
func is_acoustically_shadowed(source: Vector3, target: Vector3) -> bool:
    var direction = (target - source).normalized()
    var distance = source.distance_to(target)
    
    # Raycast to check for terrain blocking
    var hit = collision_manager.raycast(source, direction, distance)
    
    return hit["hit"]  # True if terrain blocks path
```

### Multi-Path Propagation

Simulate sound bouncing off terrain:

```gdscript
func calculate_multipath(source: Vector3, target: Vector3) -> Array:
    var paths = []
    
    # Direct path
    if not is_acoustically_shadowed(source, target):
        paths.append({"type": "direct", "distance": source.distance_to(target)})
    
    # Get nearby terrain for reflections
    var terrain = collision_manager.get_terrain_geometry_for_sonar(source, 5000.0, 2)
    
    # Check for single-bounce paths
    for i in range(terrain["positions"].size()):
        var bounce_point = terrain["positions"][i]
        var normal = terrain["normals"][i]
        
        # Check if this creates a valid reflection path
        var to_bounce = (bounce_point - source).normalized()
        var from_bounce = (target - bounce_point).normalized()
        var reflected = to_bounce.reflect(normal)
        
        if reflected.dot(from_bounce) > 0.9:  # Close to reflection angle
            var path_distance = source.distance_to(bounce_point) + bounce_point.distance_to(target)
            paths.append({
                "type": "reflection",
                "distance": path_distance,
                "bounce_point": bounce_point
            })
    
    return paths
```

## See Also

- [Terrain System Documentation](TERRAIN_SYSTEM.md)
- [Collision Manager Integration](COLLISION_MANAGER_INTEGRATION.md)
- [Sonar System Documentation](../scripts/core/sonar_system.gd)
