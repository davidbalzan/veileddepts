# Developer Console Commands - Demonstration Guide

## Overview
This guide demonstrates all implemented console commands and their functionality.

## Opening the Console
Press the **~** (tilde/backtick) key to toggle the console visibility.

## Available Commands

### 1. /help - Show Command List
```
/help
```
Shows all available commands with their usage and descriptions.

```
/help log
```
Shows detailed help for a specific command.

**Example Output:**
```
Available commands:
  /help [command]
    Show all commands or help for specific command
  /debug <on|off|terrain|performance>
    Control debug panels
  /clear
    Clear console log
  ...
```

### 2. /clear - Clear Console
```
/clear
```
Clears all log entries from the console display and log buffer.

**Example Output:**
```
Console cleared
```

### 3. /log - Set Log Level
```
/log debug
/log info
/log warning
/log error
```
Sets the minimum log level to display. Only messages at or above this level will be shown.

**Example:**
```
> /log warning
Log level set to WARNING
```
After this, only WARNING and ERROR messages will be displayed.

### 4. /filter - Filter Log Messages

#### Hide/Show Warnings
```
/filter warnings off
/filter warnings on
```
Toggles visibility of warning messages.

**Example:**
```
> /filter warnings off
Warnings filter disabled
```

#### Hide/Show Errors
```
/filter errors off
/filter errors on
```
Toggles visibility of error messages.

**Example:**
```
> /filter errors off
Errors filter disabled
```

#### Filter by Category
```
/filter category terrain
/filter category physics
/filter category system
/filter category all
```
Shows only messages from a specific category, or all categories.

**Example:**
```
> /filter category terrain
Category filter set to 'terrain'
```

#### Reset All Filters
```
/filter reset
```
Clears all active filters and shows all messages.

**Example:**
```
> /filter reset
All filters cleared
```

### 5. /history - Show Command History
```
/history
```
Displays the command history in reverse chronological order.

**Example Output:**
```
Command history:
  3. /filter reset
  2. /log warning
  1. /help
```

### 6. /debug - Control Debug Panels (Placeholder)
```
/debug on
/debug off
/debug terrain
/debug performance
```
Controls debug panel visibility. Currently returns success but actual panel control will be implemented in Task 7.

**Example:**
```
> /debug on
Debug command: on
```

### 7. /relocate - Move Submarine (Placeholder)
```
/relocate <x> <y> <z>
```
Moves the submarine to specified coordinates. Currently validates coordinates but actual movement will be implemented in Task 9.

**Example:**
```
> /relocate 1000 -200 500
Relocate command: (1000, -200, 500)
```

## Command History Navigation

### Up/Down Arrow Keys
- **Up Arrow**: Navigate backward through command history
- **Down Arrow**: Navigate forward through command history

Press Up to recall previous commands, edit them, and press Enter to execute.

## Error Handling

### Invalid Command
```
> /invalidcmd
Unknown command: /invalidcmd
Did you mean: /clear, /filter
```

### Missing Arguments
```
> /log
Too few arguments for /log
Usage: /log <debug|info|warning|error>
```

### Invalid Arguments
```
> /log invalid
Invalid log level: invalid
Valid levels: debug, info, warning, error
```

## Log Color Coding

Messages are color-coded by severity:
- **DEBUG**: Gray - Detailed diagnostic information
- **INFO**: White - General informational messages
- **WARNING**: Yellow - Warning messages
- **ERROR**: Red - Error messages

## Filter Status Display

The console header shows the current filter status:
```
Dev Console [Filter: All] [Debug: OFF]
Dev Console [Filter: Level: WARNING] [Debug: OFF]
Dev Console [Filter: Category: terrain, Warnings: OFF] [Debug: OFF]
```

## Practical Examples

### Example 1: Debugging Terrain Loading
```
> /filter category terrain
> /log debug
```
Now you'll only see DEBUG and higher messages from the terrain system.

### Example 2: Focusing on Errors
```
> /log error
> /filter warnings off
```
Now you'll only see ERROR messages, with warnings hidden.

### Example 3: Clean Slate
```
> /clear
> /filter reset
> /log debug
```
Clears the console and resets all filters to show everything.

## Tips

1. **Use /help** frequently to remember command syntax
2. **Use Up Arrow** to quickly repeat or modify previous commands
3. **Use /clear** when the console gets cluttered
4. **Use /filter category** to focus on specific systems
5. **Use /history** to see what commands you've run

## Testing the Console

To test the console functionality:

1. Run the game
2. Press ~ to open console
3. Try each command listed above
4. Verify that:
   - Commands execute without errors
   - Log level filtering works
   - Category filtering works
   - Warning/error filtering works
   - Command history works with Up/Down arrows
   - Invalid commands show helpful error messages

## Next Steps

After Task 7 (DebugPanelManager):
- `/debug on/off` will actually control debug panels
- `/debug terrain` will toggle terrain overlay
- `/debug performance` will toggle performance monitor

After Task 9 (Relocate Integration):
- `/relocate` will actually move the submarine
- Terrain streaming events will be logged

After Task 10 (LogRouter Integration):
- All game systems will log to console
- Terrain chunk loading will be visible
- Submarine state changes will be logged
- View switches will be logged
