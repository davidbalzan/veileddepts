# Terrain Debug Overlay Usage Guide

## Overview
The Terrain Debug Overlay provides real-time visualization of the terrain streaming system's internal state, including chunk loading, LOD levels, memory usage, and performance metrics.

## Quick Start

### Adding to Your Scene

```gdscript
# In your main terrain scene script
extends Node3D

var debug_overlay: TerrainDebugOverlay = null

func _ready():
	# Create debug overlay
	debug_overlay = TerrainDebugOverlay.new()
	add_child(debug_overlay)
	
	# Initially disabled
	debug_overlay.enabled = false

func _input(event):
	# Toggle with F3 key
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_overlay.toggle()
```

### Configuration

```gdscript
# Enable specific features
debug_overlay.show_chunk_boundaries = true
debug_overlay.show_chunk_labels = true
debug_overlay.show_lod_colors = true
debug_overlay.show_memory_bar = true
debug_overlay.show_performance_metrics = true

# Adjust update frequency (in seconds)
debug_overlay.update_interval = 0.1  # Update every 100ms
```

## Features

### 1. Chunk Boundaries
- **What it shows**: Yellow wireframe boxes around each loaded chunk
- **Use case**: Verify chunks are loading in the correct positions
- **Toggle**: `debug_overlay.set_show_chunk_boundaries(true/false)`

### 2. Chunk Labels
- **What it shows**: Chunk coordinates and current LOD level
- **Use case**: Identify specific chunks and their detail levels
- **Toggle**: `debug_overlay.set_show_chunk_labels(true/false)`

### 3. LOD Color Coding
- **What it shows**: Color-coded visualization of LOD levels
  - Green: LOD 0 (highest detail)
  - Yellow-green: LOD 1
  - Yellow: LOD 2
  - Orange: LOD 3 (lowest detail)
- **Use case**: Visualize LOD transitions and verify distance-based LOD
- **Toggle**: `debug_overlay.set_show_lod_colors(true/false)`

### 4. Memory Usage Bar
- **What it shows**: Current memory usage vs. maximum cache size
- **Color coding**:
  - Green: < 70% (healthy)
  - Yellow: 70-90% (warning)
  - Red: > 90% (critical)
- **Use case**: Monitor memory consumption and detect leaks
- **Toggle**: `debug_overlay.set_show_memory_bar(true/false)`

### 5. Performance Metrics
- **What it shows**:
  - Current FPS
  - Frame time (ms)
  - Terrain operation time (ms)
  - Terrain budget usage (%)
  - Performance state
  - Loaded chunk count
  - Load progress
- **Use case**: Identify performance bottlenecks
- **Toggle**: `debug_overlay.set_show_performance_metrics(true/false)`

## Common Use Cases

### Debugging Chunk Loading Issues
```gdscript
# Enable chunk boundaries and labels
debug_overlay.show_chunk_boundaries = true
debug_overlay.show_chunk_labels = true

# Move submarine and watch chunks load/unload
# Verify chunks load within load_distance
# Verify chunks unload beyond unload_distance
```

### Optimizing LOD Transitions
```gdscript
# Enable LOD colors
debug_overlay.show_lod_colors = true

# Move submarine at different speeds
# Verify smooth LOD transitions
# Check for LOD popping artifacts
```

### Monitoring Memory Usage
```gdscript
# Enable memory bar
debug_overlay.show_memory_bar = true

# Navigate around the world
# Watch memory usage grow and shrink
# Verify LRU eviction works correctly
```

### Profiling Performance
```gdscript
# Enable performance metrics
debug_overlay.show_performance_metrics = true

# Monitor FPS and frame time
# Check terrain budget usage
# Verify adaptive performance kicks in when needed
```

## Integration with Existing Systems

### With StreamingManager
The debug overlay automatically finds and connects to the StreamingManager:
```gdscript
# No manual connection needed
# Debug overlay will find StreamingManager in parent node
```

### With ChunkManager
```gdscript
# Debug overlay automatically finds ChunkManager
# Displays loaded chunks and memory usage
```

### With PerformanceMonitor
```gdscript
# Debug overlay automatically finds PerformanceMonitor
# Displays real-time performance metrics
```

## Keyboard Shortcuts (Recommended)

Add these to your input map for easy debugging:

```gdscript
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F3:
				# Toggle entire overlay
				debug_overlay.toggle()
			KEY_F4:
				# Toggle chunk boundaries only
				debug_overlay.set_show_chunk_boundaries(
					not debug_overlay.show_chunk_boundaries
				)
			KEY_F5:
				# Toggle performance metrics only
				debug_overlay.set_show_performance_metrics(
					not debug_overlay.show_performance_metrics
				)
```

## Performance Impact

The debug overlay is designed to have minimal performance impact:
- Updates only at specified interval (default 100ms)
- Chunk boundary meshes are cached
- Labels only created for visible chunks
- Typical overhead: < 1ms per update

For maximum performance during gameplay, disable the overlay:
```gdscript
debug_overlay.enabled = false
```

## Troubleshooting

### Overlay not visible
- Check that `enabled = true`
- Verify overlay is added to scene tree
- Check that layer is set correctly (default: 100)

### Chunk boundaries not showing
- Verify chunks are actually loaded
- Check camera is positioned to see chunks
- Ensure `show_chunk_boundaries = true`

### Performance metrics not updating
- Verify PerformanceMonitor exists in scene
- Check update_interval is not too high
- Ensure `show_performance_metrics = true`

### Labels not appearing
- Check camera exists and is active
- Verify chunks are on screen
- Ensure `show_chunk_labels = true`

## Example: Complete Debug Setup

```gdscript
extends Node3D

var terrain_system: Node3D
var debug_overlay: TerrainDebugOverlay

func _ready():
	# Setup terrain system
	terrain_system = Node3D.new()
	add_child(terrain_system)
	
	# Add terrain components
	var chunk_manager = ChunkManager.new()
	var streaming_manager = StreamingManager.new()
	var performance_monitor = PerformanceMonitor.new()
	
	terrain_system.add_child(chunk_manager)
	terrain_system.add_child(streaming_manager)
	terrain_system.add_child(performance_monitor)
	
	# Add debug overlay
	debug_overlay = TerrainDebugOverlay.new()
	terrain_system.add_child(debug_overlay)
	
	# Configure debug overlay
	debug_overlay.enabled = true
	debug_overlay.show_chunk_boundaries = true
	debug_overlay.show_chunk_labels = true
	debug_overlay.show_memory_bar = true
	debug_overlay.show_performance_metrics = true
	debug_overlay.update_interval = 0.1

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_overlay.toggle()
```

## Best Practices

1. **Enable during development**: Keep overlay enabled while developing
2. **Disable for release**: Set `enabled = false` in production builds
3. **Use selective features**: Enable only the features you need
4. **Adjust update interval**: Increase interval if overlay impacts performance
5. **Monitor memory**: Watch memory bar to catch leaks early
6. **Profile regularly**: Check performance metrics frequently

## Advanced Usage

### Custom Styling
```gdscript
# Access UI elements directly for custom styling
var memory_bar = debug_overlay._memory_bar
memory_bar.custom_minimum_size = Vector2(400, 30)

var metrics_label = debug_overlay._metrics_label
metrics_label.add_theme_font_size_override("font_size", 16)
```

### Programmatic Control
```gdscript
# Update display manually
debug_overlay._update_display()

# Clear 3D visualization
debug_overlay._clear_3d_visualization()

# Access internal state
var boundary_meshes = debug_overlay._chunk_boundary_meshes
print("Boundary meshes: ", boundary_meshes.size())
```

## See Also
- [Terrain System Documentation](TERRAIN_SYSTEM.md)
- [Performance Monitoring Guide](PERFORMANCE_MONITORING.md)
- [Chunk Management Guide](CHUNK_MANAGEMENT.md)
