# /relocate Command Demonstration

## Overview
The `/relocate` command allows developers to instantly teleport the submarine to any coordinates in the game world. This is useful for testing, debugging, and quickly navigating to different areas of the map.

## Command Syntax
```
/relocate <x> <y> <z>
```

Where:
- `x`: X coordinate (east-west position in meters)
- `y`: Y coordinate (vertical position in meters, negative is below surface)
- `z`: Z coordinate (north-south position in meters)

## Usage Examples

### Example 1: Move to Origin
```
/relocate 0 0 0
```
Moves the submarine to the world origin at the surface.

### Example 2: Move to Deep Location
```
/relocate 1000 -200 2000
```
Moves the submarine to coordinates (1000, -200, 2000), which is 200 meters below the surface.

### Example 3: Move with Decimal Precision
```
/relocate 123.45 -67.89 234.56
```
Supports decimal coordinates for precise positioning.

### Example 4: Move to Negative Coordinates
```
/relocate -1000 -100 -3000
```
Supports negative coordinates in all axes.

## What Happens When You Relocate

1. **Position Update**: The submarine's position is immediately updated to the specified coordinates
2. **Depth Update**: The submarine's depth is automatically calculated from the Y coordinate
3. **Logging**: The relocation is logged to the console with old and new positions
4. **Terrain Streaming**: Terrain chunks around the new position are automatically loaded
5. **Streaming Log**: A log entry confirms that terrain streaming was triggered

## Console Output Example

When you execute `/relocate 1000 -50 2000`, you'll see output similar to:

```
> /relocate 1000 -50 2000
[INFO] [console] Relocate command: (1000, -50, 2000)
[INFO] [submarine] Submarine relocated from (0.0, 0.0, 0.0) to (1000.0, -50.0, 2000.0)
[INFO] [streaming] Triggering terrain streaming update for new position
```

## Error Handling

### Invalid Coordinates
```
> /relocate abc 200 300
[ERROR] [console] Invalid X coordinate: abc
```

### Too Few Arguments
```
> /relocate 100 200
[ERROR] [console] Too few arguments for /relocate
Usage: /relocate <x> <y> <z>
```

### Too Many Arguments
```
> /relocate 100 200 300 400
[ERROR] [console] Too many arguments for /relocate
Usage: /relocate <x> <y> <z>
```

## Testing the Command

### Method 1: Using the Dev Console
1. Press `~` (tilde) to open the developer console
2. Type `/relocate 1000 -50 2000`
3. Press Enter
4. Observe the submarine's new position in the game

### Method 2: Using the Manual Test Script
1. Add `test_relocate_manual.gd` to your main scene
2. Run the game
3. Press F6 to test basic relocation
4. Press F7 to check current position
5. Press F8 to test far relocation

## Tips and Best Practices

1. **Check Current Position First**: Use `/relocate 0 0 0` to return to origin if you get lost
2. **Use Round Numbers**: For quick testing, use round numbers like 1000, 2000, etc.
3. **Watch the Logs**: Keep the console open to see relocation and streaming events
4. **Test Terrain Loading**: Relocate to far locations to test terrain streaming system
5. **Combine with Debug Mode**: Use `/debug on` before relocating to see terrain chunks loading

## Integration with Other Commands

The `/relocate` command works well with other console commands:

```bash
# Enable debug mode to see terrain chunks
/debug on

# Relocate to a new area
/relocate 5000 -100 -3000

# Check terrain loading in the debug overlay
# (Terrain chunks will load around the new position)

# Filter logs to see only streaming events
/filter category streaming
```

## Common Use Cases

### 1. Testing Terrain Streaming
```
/relocate 10000 -50 10000
```
Relocate to a far location to test terrain chunk loading/unloading.

### 2. Testing Deep Diving
```
/relocate 0 -300 0
```
Relocate to a deep location to test deep-water rendering and physics.

### 3. Testing Surface Operations
```
/relocate 0 0 0
```
Relocate to the surface to test periscope view and surface rendering.

### 4. Quick Navigation
```
/relocate 2000 -100 -1500
```
Quickly navigate to a specific area of interest for testing.

## Limitations

- No bounds checking (can relocate outside the world map)
- No collision detection (can relocate inside terrain)
- Instant teleportation (no animation or transition)
- Physics state is not reset (velocity, heading remain unchanged)

## Future Enhancements

Planned improvements for the `/relocate` command:
- Add bounds checking to prevent invalid locations
- Add collision detection to find safe spawn points
- Add named location presets (e.g., `/relocate home`)
- Add transition animation for smoother relocation
- Add command history for quick re-execution

## Related Commands

- `/help` - Show all available commands
- `/debug on/off` - Toggle debug overlays
- `/filter category streaming` - Show only streaming logs
- `/clear` - Clear the console log
