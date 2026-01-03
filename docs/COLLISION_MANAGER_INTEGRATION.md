# CollisionManager Integration Guide

## Overview

The CollisionManager is a component of the Dynamic Terrain Streaming System that handles terrain collision geometry, height queries, underwater safety checks, and raycasting. This guide explains how to integrate it with existing systems.

## Basic Setup

### 1. Add CollisionManager to Scene

```gdscript
# In your main terrain system or scene
var collision_manager: CollisionManager

func _ready():
	# Create collision manager
	collision_manager = CollisionManager.new()
	add_child(collision_manager)
	
	# Set reference to chunk manager
	collision_manager.set_chunk_manager(chunk_manager)
```

### 2. Create Collision When Loading Chunks

The CollisionManager should be called when chunks are loaded. This can be done in the StreamingManager or ChunkManager:

```gdscript
# In StreamingManager or ChunkManager
func _on_chunk_loaded(chunk: TerrainChunk):
	# Create collision geometry for the chunk
	collision_manager.create_collision(chunk)
```

### 3. Remove Collision When Unloading Chunks

```gdscript
# In StreamingManager or ChunkManager
func _on_chunk_unloaded(chunk: TerrainChunk):
	# Remove collision geometry
	collision_manager.remove_collision(chunk)
```

## Integration Examples

### Submarine Ground Collision

Use height queries to prevent the submarine from going through terrain:

```gdscript
# In submarine physics update
func _physics_process(delta):
	var submarine_pos = global_position
	var terrain_height = collision_manager.get_height_at(
		Vector2(submarine_pos.x, submarine_pos.z)
	)
	
	# Add clearance (e.g., submarine hull radius)
	var min_safe_height = terrain_height + submarine_hull_radius
	
	# Prevent going below terrain
	if submarine_pos.y < min_safe_height:
		submarine_pos.y = min_safe_height
		# Apply collision response (bounce, stop, etc.)
		velocity.y = max(0, velocity.y)
```

### Spawn Point Validation

Use underwater safety checks to find valid spawn points:

```gdscript
func find_safe_spawn_point(search_area: Rect2, min_depth: float, clearance: float) -> Vector3:
	var attempts = 0
	var max_attempts = 100
	
	while attempts < max_attempts:
		# Random position in search area
		var x = randf_range(search_area.position.x, search_area.end.x)
		var z = randf_range(search_area.position.y, search_area.end.y)
		var y = -min_depth  # Start at desired depth
		
		var test_pos = Vector3(x, y, z)
		
		# Check if safe
		if collision_manager.is_underwater_safe(test_pos, clearance):
			return test_pos
		
		attempts += 1
	
	# Fallback to default spawn
	return Vector3(0, -100, 0)
```

### Sonar Terrain Detection

Use raycasting for sonar beam intersection with terrain:

```gdscript
func cast_sonar_beam(origin: Vector3, direction: Vector3, max_range: float) -> Dictionary:
	# Cast ray against terrain
	var result = collision_manager.raycast(origin, direction, max_range)
	
	if result["hit"]:
		# Calculate sonar return
		var distance = result["distance"]
		var normal = result["normal"]
		
		# Calculate reflection angle for sonar display
		var reflection_strength = abs(direction.dot(normal))
		
		return {
			"detected": true,
			"distance": distance,
			"position": result["position"],
			"strength": reflection_strength
		}
	
	return {"detected": false}
```

### Terrain Following

Use height queries for autonomous terrain following:

```gdscript
func maintain_altitude_above_terrain(target_altitude: float):
	var current_pos = global_position
	var terrain_height = collision_manager.get_height_at(
		Vector2(current_pos.x, current_pos.z)
	)
	
	var target_height = terrain_height + target_altitude
	var height_error = target_height - current_pos.y
	
	# Apply vertical control to maintain altitude
	var vertical_thrust = height_error * altitude_gain
	apply_force(Vector3(0, vertical_thrust, 0))
```

## Integration with StreamingManager

The recommended integration point is in the StreamingManager, which already handles chunk loading/unloading:

```gdscript
# In StreamingManager
var collision_manager: CollisionManager

func _ready():
	# ... existing setup ...
	
	# Create collision manager
	collision_manager = CollisionManager.new()
	add_child(collision_manager)
	collision_manager.set_chunk_manager(_chunk_manager)

func _process_load_queue():
	# ... existing load logic ...
	
	# After chunk is loaded
	if chunk.state == ChunkState.State.LOADED:
		# Create collision geometry
		collision_manager.create_collision(chunk)

func _process_unload_queue():
	# Before unloading chunk
	var chunk = _chunk_manager.get_chunk(chunk_coord)
	
	# Remove collision first
	collision_manager.remove_collision(chunk)
	
	# Then unload chunk
	_chunk_manager.unload_chunk(chunk_coord)
```

## Performance Considerations

### Collision Resolution

The CollisionManager automatically determines collision resolution based on heightmap size. For better performance:

- Use lower resolution heightmaps for distant chunks
- Collision resolution is independent of visual LOD
- Typical resolution: 65x65 (64 + 1) for good balance

### Height Query Optimization

Height queries are fast but can be optimized:

```gdscript
# Cache height queries if checking same position multiple times
var cached_height: float
var cached_position: Vector2
var cache_valid: bool = false

func get_terrain_height_cached(pos: Vector2) -> float:
	if cache_valid and pos.distance_to(cached_position) < 1.0:
		return cached_height
	
	cached_height = collision_manager.get_height_at(pos)
	cached_position = pos
	cache_valid = true
	return cached_height
```

### Raycast Optimization

For multiple raycasts (e.g., sonar array):

```gdscript
# Batch raycasts in a single frame
func cast_sonar_array(origin: Vector3, directions: Array[Vector3], max_range: float) -> Array:
	var results = []
	for direction in directions:
		var result = collision_manager.raycast(origin, direction, max_range)
		results.append(result)
	return results
```

## Debugging

### Visualize Collision Geometry

```gdscript
# Enable collision shape visibility in debug mode
func _ready():
	if OS.is_debug_build():
		get_tree().debug_collisions_hint = true
```

### Log Height Queries

```gdscript
# Add logging to track height queries
func debug_get_height_at(pos: Vector2) -> float:
	var height = collision_manager.get_height_at(pos)
	print("Height at (%0.1f, %0.1f): %0.2f m" % [pos.x, pos.y, height])
	return height
```

### Visualize Raycasts

```gdscript
# Draw debug lines for raycasts
func debug_raycast(origin: Vector3, direction: Vector3, max_distance: float):
	var result = collision_manager.raycast(origin, direction, max_distance)
	
	if result["hit"]:
		# Draw line to hit point
		DebugDraw.line(origin, result["position"], Color.GREEN)
		# Draw normal at hit point
		DebugDraw.line(
			result["position"],
			result["position"] + result["normal"] * 5.0,
			Color.BLUE
		)
	else:
		# Draw full ray
		DebugDraw.line(
			origin,
			origin + direction * max_distance,
			Color.RED
		)
```

## Common Issues

### Issue: Raycast Not Hitting Terrain

**Cause**: Collision geometry not created for chunk

**Solution**: Ensure `create_collision()` is called after chunk is loaded:
```gdscript
# Check if collision exists
if not chunk.static_body:
	collision_manager.create_collision(chunk)
```

### Issue: Height Query Returns 0.0

**Cause**: Querying position in unloaded chunk

**Solution**: Load chunk before querying, or handle fallback:
```gdscript
var height = collision_manager.get_height_at(pos)
if height == 0.0:
	# Either load the chunk or use a default value
	print("Warning: Querying unloaded chunk at ", pos)
```

### Issue: Submarine Falls Through Terrain

**Cause**: Collision not updated when chunk LOD changes

**Solution**: Recreate collision when LOD changes:
```gdscript
func _on_chunk_lod_changed(chunk: TerrainChunk):
	# Remove old collision
	collision_manager.remove_collision(chunk)
	# Create new collision with updated heightmap
	collision_manager.create_collision(chunk)
```

## API Reference

### CollisionManager Methods

#### `create_collision(chunk: TerrainChunk) -> void`
Creates collision geometry for a chunk.

#### `remove_collision(chunk: TerrainChunk) -> void`
Removes collision geometry from a chunk.

#### `get_height_at(world_pos: Vector2) -> float`
Queries terrain height at a world position.

#### `is_underwater_safe(world_pos: Vector3, clearance: float) -> bool`
Checks if a position is safe underwater with required clearance.

#### `raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary`
Casts a ray against terrain collision.

Returns:
```gdscript
{
	"hit": bool,           # True if ray hit terrain
	"position": Vector3,   # Hit position (if hit)
	"normal": Vector3,     # Surface normal at hit (if hit)
	"distance": float      # Distance to hit (if hit)
}
```

## Next Steps

1. Integrate CollisionManager with StreamingManager
2. Update submarine physics to use height queries
3. Implement sonar terrain detection using raycasts
4. Add spawn point validation using safety checks
5. Test collision at chunk boundaries
6. Optimize collision resolution for performance
