# LogRouter Integration Demo

## Overview
This document demonstrates the LogRouter integration with game systems, showing how events are logged to the developer console.

## Integrated Systems

### 1. TerrainRenderer
**Category**: `terrain`

Logs terrain initialization and configuration:
```
[INFO][terrain] TerrainRenderer initializing
[INFO][terrain] TerrainRenderer initialized: chunk_size=512.0m, load_distance=1024.0m, lod_levels=4
```

### 2. StreamingManager
**Category**: `terrain`

Logs chunk loading/unloading and streaming events:
```
[DEBUG][terrain] Chunk loaded at (0, 0)
[DEBUG][terrain] Chunk loaded at (1, 0)
[DEBUG][terrain] Chunk loaded (async) at (2, 0) in 1.2ms
[DEBUG][terrain] Chunk unloaded at (-1, -1)
[WARNING][terrain] Reducing LOD levels to improve performance
[WARNING][terrain] Emergency unloading distant chunks
```

### 3. SimulationState
**Category**: `submarine`

Logs submarine commands and state changes:
```
[INFO][submarine] Submarine command updated: waypoint=(100.0, -50.0, 200.0), speed=5.0m/s, depth=50.0m
[DEBUG][submarine] Submarine position: (120.0, -55.0, 220.0), depth: 55.0m, heading: 45.0°, speed: 5.0m/s
[DEBUG][submarine] Submarine depth changed: 0.0m -> 55.0m
```

### 4. ViewManager
**Category**: `view`

Logs view switches and transition times:
```
[INFO][view] Switching view: TACTICAL_MAP -> PERISCOPE
[DEBUG][view] View switch completed: PERISCOPE (0.5ms)
[INFO][view] Switching view: PERISCOPE -> EXTERNAL
[DEBUG][view] View switch completed: EXTERNAL (0.3ms)
[WARNING][view] View transition exceeded 100ms requirement: 125.0ms
```

## Log Levels

### DEBUG (Gray)
- Detailed diagnostic information
- Chunk operations
- Position updates
- Transition times

### INFO (White)
- General informational messages
- System initialization
- Command updates
- View switches

### WARNING (Yellow)
- Performance issues
- LOD reductions
- Emergency unloads
- Slow transitions

### ERROR (Red)
- Critical errors
- System failures
- Invalid operations

## Filtering Examples

### Filter by Category
```gdscript
# Show only terrain logs
LogRouter.set_category_filter("terrain")

# Show only submarine logs
LogRouter.set_category_filter("submarine")

# Show all categories
LogRouter.set_category_filter("")
```

### Filter by Level
```gdscript
# Show only INFO and above (hide DEBUG)
LogRouter.set_min_level(LogRouter.LogLevel.INFO)

# Show only WARNING and ERROR
LogRouter.set_min_level(LogRouter.LogLevel.WARNING)

# Show all levels
LogRouter.set_min_level(LogRouter.LogLevel.DEBUG)
```

### Hide Specific Types
```gdscript
# Hide warnings
LogRouter.set_hide_warnings(true)

# Hide errors
LogRouter.set_hide_errors(true)

# Reset filters
LogRouter.clear_filters()
```

## Console Commands

Once the developer console is implemented, these commands will control logging:

```
/log debug          # Show all log levels
/log info           # Show INFO, WARNING, ERROR
/log warning        # Show WARNING, ERROR only
/log error          # Show ERROR only

/filter category terrain    # Show only terrain logs
/filter category submarine  # Show only submarine logs
/filter category view       # Show only view logs
/filter category all        # Show all categories

/filter warnings off        # Hide warnings
/filter errors off          # Hide errors
/filter reset              # Clear all filters
```

## Testing

Run the integration test to verify logging:
```bash
godot --headless --path . test_log_router_integration.tscn
```

Expected output:
- ✓ TerrainRenderer is logging to console (2 logs)
- ✓ SimulationState is logging to console (3 logs)
- ✓ ViewManager is logging to console (4 logs)

## Performance Considerations

### Log Frequency
- **Terrain**: Logs on chunk load/unload (infrequent)
- **Submarine**: Logs on significant changes only (>10m position, >5m depth)
- **View**: Logs on view switches (user-initiated)

### Buffer Management
- Circular buffer with 1000 entry limit
- Oldest entries automatically removed
- O(1) insertion and removal

### Filtering
- Logs filtered before display
- No performance impact from hidden logs
- Efficient category and level checks

## Integration with Developer Console

When the developer console is opened with `~`:
1. All logs appear in scrollable display
2. Color-coded by severity level
3. Filterable by category and level
4. Auto-scrolls to show latest entries
5. Searchable and exportable

## Example Session

```
> /log debug
Log level set to DEBUG

[INFO][terrain] TerrainRenderer initialized: chunk_size=512.0m, load_distance=1024.0m, lod_levels=4
[DEBUG][terrain] Chunk loaded at (0, 0)
[DEBUG][terrain] Chunk loaded at (1, 0)

> /filter category submarine
Filter set to category: submarine

[INFO][submarine] Submarine command updated: waypoint=(100.0, -50.0, 200.0), speed=5.0m/s, depth=50.0m
[DEBUG][submarine] Submarine position: (120.0, -55.0, 220.0), depth: 55.0m, heading: 45.0°, speed: 5.0m/s

> /filter reset
All filters cleared

[INFO][view] Switching view: TACTICAL_MAP -> EXTERNAL
[DEBUG][view] View switch completed: EXTERNAL (0.5ms)
```

## Benefits

1. **Centralized Logging**: All game systems log to one place
2. **Easy Debugging**: Filter by category to focus on specific systems
3. **Performance Monitoring**: Track chunk loading, view transitions, etc.
4. **State Tracking**: Monitor submarine position, depth, heading changes
5. **Event History**: Circular buffer maintains recent event history

## Next Steps

With logging integration complete, the next task is to implement the remaining console commands and features:
- Command history (Up/Down arrows)
- Auto-completion (Tab key)
- Console persistence (save/load history)
- View controls integration
- External camera zoom controls
