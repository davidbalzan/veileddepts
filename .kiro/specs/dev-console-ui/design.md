# Design Document

## Overview

The Developer Console UI system provides a command-line interface for controlling debug features, viewing system logs, and managing the game's view states. The design separates debug visualization from the console itself, allowing developers to view diagnostics without the console being open. The system integrates with existing terrain streaming, view management, and input systems to provide comprehensive development tools.

## Architecture

The system consists of five main components:

1. **DevConsole**: The main console UI with command input and log display
2. **CommandParser**: Interprets and executes console commands
3. **LogRouter**: Centralizes logging from all game systems and routes to console
4. **DebugPanelManager**: Controls visibility and state of debug overlays
5. **ViewInputHandler**: Enhanced input system for view switching and camera controls

### Component Interaction

```
┌─────────────────┐
│   DevConsole    │◄──────── User Input (~, commands)
└────────┬────────┘
         │
         ├──────► CommandParser ──────► Game Systems
         │                              (SimulationState,
         │                               TerrainRenderer,
         │                               DebugPanelManager)
         │
         ▼
    LogRouter ◄──────────────────────── All Game Systems
         │                              (terrain, streaming,
         │                               physics, etc.)
         │
         ▼
    Console Log Display


┌──────────────────────┐
│ DebugPanelManager    │
└──────────┬───────────┘
           │
           ├──────► TerrainDebugOverlay
           ├──────► PerformanceMonitor
           └──────► Other Debug Panels
```

## Components and Interfaces

### 1. DevConsole (CanvasLayer)

The main console UI component that handles display and user interaction.

**Properties:**
- `is_visible: bool` - Console visibility state
- `command_history: Array[String]` - Last 50 commands
- `history_index: int` - Current position in history navigation
- `log_buffer: Array[LogEntry]` - Circular buffer of log entries (max 1000)
- `current_command: String` - Text in the command input field
- `auto_scroll: bool` - Whether to auto-scroll to latest logs

**Methods:**
- `toggle_visibility()` - Show/hide the console
- `execute_command(command: String)` - Parse and run a command
- `add_log(message: String, level: LogLevel, category: String)` - Add entry to log
- `navigate_history(direction: int)` - Move through command history
- `auto_complete()` - Attempt to complete partial command
- `clear_logs()` - Empty the log buffer
- `save_history()` - Persist command history to file
- `load_history()` - Restore command history from file

**UI Structure:**
```
┌─────────────────────────────────────────┐
│ Dev Console [Filter: All] [Debug: ON]  │ ← Header with status
├─────────────────────────────────────────┤
│                                         │
│  [LOG AREA - Scrollable]                │
│  > [INFO] Terrain chunk loaded (0,0)   │
│  > [WARN] High memory usage: 450MB     │
│  > [DEBUG] Submarine relocated to...   │
│                                         │
├─────────────────────────────────────────┤
│ > /debug on_                            │ ← Command input
└─────────────────────────────────────────┘
```

### 2. CommandParser

Parses and executes console commands.

**Command Format:**
- Commands start with `/`
- Arguments separated by spaces
- String arguments can be quoted: `/save "my preset"`

**Supported Commands:**

| Command | Arguments | Description |
|---------|-----------|-------------|
| `/help` | [command] | Show all commands or help for specific command |
| `/debug` | on\|off\|terrain\|performance | Control debug panels |
| `/clear` | - | Clear console log |
| `/relocate` | x y z | Move submarine to coordinates |
| `/log` | debug\|info\|warning\|error | Set minimum log level |
| `/filter` | warnings\|errors on\|off | Toggle message type filtering |
| `/filter` | category <name\|all> | Filter by log category |
| `/filter` | reset | Clear all filters |
| `/save` | <name> | Save console preset |
| `/load` | <name> | Load console preset |
| `/history` | - | Display command history |

**Methods:**
- `parse(command: String) -> CommandResult` - Parse command string
- `execute(parsed_command: ParsedCommand) -> String` - Execute command and return result
- `get_suggestions(partial: String) -> Array[String]` - Get command suggestions for auto-complete
- `validate_args(command: String, args: Array) -> bool` - Check if arguments are valid

**Error Handling:**
- Unknown commands suggest similar valid commands (Levenshtein distance)
- Missing arguments show command usage
- Invalid arguments show expected format

### 3. LogRouter

Centralizes logging from all game systems.

**LogEntry Structure:**
```gdscript
class LogEntry:
    var timestamp: float
    var level: LogLevel  # DEBUG, INFO, WARNING, ERROR
    var category: String  # "terrain", "streaming", "physics", etc.
    var message: String
    var color: Color  # Based on level
```

**Log Levels:**
- `DEBUG` (gray): Detailed diagnostic information
- `INFO` (white): General informational messages
- `WARNING` (yellow): Warning messages
- `ERROR` (red): Error messages

**Log Categories:**
- `terrain`: Terrain loading, chunk management
- `streaming`: Map streaming events
- `physics`: Submarine physics, collisions
- `input`: Input handling, view switching
- `system`: General system messages

**Methods:**
- `log(message: String, level: LogLevel, category: String)` - Add log entry
- `set_min_level(level: LogLevel)` - Filter by minimum severity
- `set_category_filter(category: String)` - Show only specific category
- `clear_filters()` - Reset all filters
- `get_filtered_logs() -> Array[LogEntry]` - Get logs matching current filters

**Integration Points:**
- TerrainRenderer: Log chunk loading/unloading
- StreamingManager: Log streaming events
- SimulationState: Log submarine state changes
- ViewManager: Log view switches
- All systems: Route print() and push_error() calls

### 4. DebugPanelManager

Controls visibility and state of debug overlays.

**Properties:**
- `debug_enabled: bool` - Master debug toggle
- `active_panels: Dictionary` - Panel name -> visibility state
- `panel_references: Dictionary` - Panel name -> Node reference

**Managed Panels:**
- `terrain`: TerrainDebugOverlay (existing)
- `performance`: PerformanceMonitor (existing)
- `physics`: Submarine physics debug info
- `sonar`: Sonar system visualization

**Methods:**
- `enable_all()` - Show all debug panels
- `disable_all()` - Hide all debug panels
- `toggle_panel(name: String)` - Toggle specific panel
- `is_panel_visible(name: String) -> bool` - Check panel state
- `register_panel(name: String, node: Node)` - Add new debug panel

**Z-Order:**
- Debug panels: Layer 5 (below console)
- Dev console: Layer 10 (above everything)
- Game UI: Layer 1-4

### 5. ViewInputHandler

Enhanced input handling for view switching and camera controls.

**Key Bindings:**

| Key | Action | View Restriction |
|-----|--------|------------------|
| `~` | Toggle dev console | All views |
| `Esc` | Close overlays (console, help) | All views |
| `1` | Switch to tactical map | All views |
| `2` | Switch to periscope | All views |
| `3` | Switch to external (default) | All views |
| `F4` | Switch to whole map | All views |
| `M` | Toggle tactical map | All views |
| `+` / `=` | Zoom in | External view only |
| `-` / `_` | Zoom out | External view only |
| `Mouse Wheel` | Zoom in/out | External view only |

**External View Camera:**
- Default distance: 100 meters
- Min distance: 20 meters
- Max distance: 500 meters
- Zoom step: 10 meters per key press
- Zoom maintains orbit angle and look-at target

**Input Priority:**
1. Dev console (when visible) - captures all input
2. Help overlay (when visible) - captures all input except F1/Esc
3. View switching keys - always processed
4. Game-specific input - processed when no overlays active

**Methods:**
- `handle_input(event: InputEvent) -> bool` - Process input, return true if consumed
- `is_console_active() -> bool` - Check if console should capture input
- `zoom_camera(delta: float)` - Adjust external camera distance
- `switch_view(view: ViewType)` - Change active view

## Data Models

### ConsolePreset

Saved console configuration that can be loaded later.

```gdscript
class ConsolePreset:
    var name: String
    var min_log_level: LogLevel
    var category_filter: String
    var hide_warnings: bool
    var hide_errors: bool
    var window_height: float
```

### CommandResult

Result of command execution.

```gdscript
class CommandResult:
    var success: bool
    var message: String
    var data: Variant  # Optional command-specific data
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Console Toggle Consistency
*For any* console state (visible or hidden), toggling the console should flip the visibility state exactly once.
**Validates: Requirements 1.1**

### Property 2: Input Routing Based on Console State
*For any* input event, if the console is visible, game input handlers should not receive the event; if the console is hidden, game input handlers should receive the event normally.
**Validates: Requirements 1.3, 1.4**

### Property 3: Command Execution Produces Output
*For any* valid command, executing it should add at least one entry to the console log.
**Validates: Requirements 1.5, 1.6**

### Property 4: Log Auto-Scroll Behavior
*For any* sequence of log additions, if auto-scroll is enabled, the scroll position should always be at the bottom after each addition.
**Validates: Requirements 1.7**

### Property 5: Log Buffer Size Limit
*For any* number of log entries added, the log buffer should never exceed 1000 entries, with oldest entries removed first.
**Validates: Requirements 1.8**

### Property 6: Invalid Command Error Handling
*For any* invalid command string, executing it should produce an error message in the console log.
**Validates: Requirements 2.4**

### Property 7: Relocate Command Updates Position
*For any* valid coordinates (x, y, z), executing `/relocate x y z` should set the submarine position to those coordinates and log the action.
**Validates: Requirements 2.6**

### Property 8: Command History Navigation
*For any* sequence of executed commands, navigating up through history should retrieve commands in reverse chronological order.
**Validates: Requirements 2.7**

### Property 9: Command Auto-Completion
*For any* partial command that uniquely matches a valid command, pressing Tab should complete it to the full command.
**Validates: Requirements 2.8**

### Property 10: Terrain Events Logged
*For any* terrain chunk load event, the console should receive a log entry with the chunk coordinates.
**Validates: Requirements 3.1**

### Property 11: Submarine Relocation Logged
*For any* submarine position change via relocation, the console should log the new position.
**Validates: Requirements 3.2**

### Property 12: Streaming Events Logged
*For any* map streaming event, the console should log the streaming status and affected regions.
**Validates: Requirements 3.3**

### Property 13: Error/Warning Routing
*For any* error or warning generated by game systems, it should appear in the console with the appropriate severity indicator.
**Validates: Requirements 3.4**

### Property 14: Log Level Filtering
*For any* log level setting, only messages at or above that level should be visible in the console.
**Validates: Requirements 3.5**

### Property 15: Log Color Coding
*For any* log entry, its display color should match its severity level (debug=gray, info=white, warning=yellow, error=red).
**Validates: Requirements 3.6**

### Property 16: View Toggle with M Key
*For any* current view state, pressing M should toggle between tactical map and the previous view.
**Validates: Requirements 4.2**

### Property 17: Escape Key Priority
*For any* open overlay (console or help), pressing Escape should close the overlay before affecting game state.
**Validates: Requirements 4.7**

### Property 18: External View Zoom Changes Distance
*For any* zoom input (+, -, or mouse wheel) in external view, the camera distance should change in the appropriate direction.
**Validates: Requirements 5.1, 5.2, 5.6**

### Property 19: Zoom Preserves Orbit Angle
*For any* zoom operation, the camera's orbit angle and look-at target should remain unchanged.
**Validates: Requirements 5.3**

### Property 20: Debug Panel Visibility Matches Debug Mode
*For any* debug mode state (enabled or disabled), debug panels should be visible if and only if debug mode is enabled.
**Validates: Requirements 6.1, 6.2**

### Property 21: Console and Debug Panel Independence
*For any* console visibility state, if debug mode is enabled, debug panels should remain visible regardless of console state.
**Validates: Requirements 6.3**

### Property 22: Debug Panel Input Pass-Through
*For any* mouse input over debug panels, the input should pass through to the game layer below.
**Validates: Requirements 6.5**

### Property 23: Filter Status Display
*For any* active filter configuration, the console header should display the current filter status.
**Validates: Requirements 7.6**

## Error Handling

### Console Errors
- **Invalid command syntax**: Display error with command usage
- **Missing required arguments**: Show expected argument format
- **Invalid argument values**: Explain valid value range/format
- **Command execution failure**: Log error and maintain console state

### Log System Errors
- **Log buffer overflow**: Automatically remove oldest entries
- **Invalid log level**: Default to INFO level
- **Missing category**: Use "system" as default category
- **Circular logging**: Prevent LogRouter from logging its own errors

### Input Handling Errors
- **Conflicting key bindings**: Console and overlays take priority
- **Invalid view switch**: Log warning and maintain current view
- **Zoom out of bounds**: Clamp to min/max distance

### Persistence Errors
- **History file not found**: Start with empty history
- **Corrupted preset file**: Log error and use defaults
- **Save file write failure**: Display error in console

## Testing Strategy

### Unit Tests

Unit tests verify specific examples and edge cases:

1. **Console Visibility**: Test toggle behavior with specific states
2. **Command Parsing**: Test parsing of specific command strings
3. **Log Buffer Management**: Test buffer at exactly 1000 entries
4. **Command History**: Test history with specific command sequences
5. **Filter Logic**: Test specific filter combinations
6. **Preset Serialization**: Test saving/loading specific presets
7. **Key Binding Resolution**: Test specific key combinations
8. **Zoom Boundary Conditions**: Test zoom at min/max distances

### Property-Based Tests

Property tests verify universal properties across all inputs using the Gut testing framework with custom property test helpers:

1. **Property 1-23**: Each correctness property should be implemented as a property-based test
2. **Test Configuration**: Minimum 100 iterations per property test
3. **Test Tagging**: Each test tagged with feature name and property number
4. **Random Generation**: Generate random console states, commands, log entries, view states, and zoom values
5. **Invariant Checking**: Verify properties hold across all generated inputs

**Example Property Test Structure:**
```gdscript
# Feature: dev-console-ui, Property 1: Console Toggle Consistency
func test_console_toggle_consistency():
    for i in range(100):
        var initial_state = randi() % 2 == 0  # Random bool
        console.visible = initial_state
        console.toggle_visibility()
        assert_ne(console.visible, initial_state, "Toggle should flip state")
```

### Integration Tests

1. **Console-LogRouter Integration**: Verify logs from game systems appear in console
2. **Console-DebugPanelManager Integration**: Verify /debug commands control panels
3. **Console-SimulationState Integration**: Verify /relocate command moves submarine
4. **ViewInputHandler-ViewManager Integration**: Verify view switching works correctly
5. **Console-Persistence Integration**: Verify history and presets save/load correctly

### Manual Testing Checklist

1. Open console with ~, verify it appears
2. Type /help, verify command list displays
3. Type /debug on, verify debug panels appear
4. Type /relocate 1000 500 -200, verify submarine moves and logs appear
5. Press M to toggle tactical map, verify view switches
6. In external view, press +/- to zoom, verify camera distance changes
7. Add 1000+ log entries, verify buffer limits to 1000
8. Type /filter warnings off, verify warnings disappear
9. Close and reopen game, verify command history persists
10. Press Escape with console open, verify console closes

## Performance Considerations

### Log Buffer Management
- Circular buffer with fixed size (1000 entries)
- O(1) insertion and removal
- Lazy rendering: only render visible log lines

### Command History
- Limited to 50 most recent commands
- Stored in memory during session
- Persisted to disk on game close (async write)

### Debug Panel Rendering
- Panels only update when visible
- Update frequency: 10 Hz (every 0.1 seconds)
- Use dirty flags to avoid unnecessary redraws

### Input Processing
- Console input processed first (early return)
- View switching processed before game input
- Zoom calculations cached per frame

## Implementation Notes

### Godot-Specific Considerations

1. **CanvasLayer for Console**: Use layer 10 to ensure console appears above all game UI
2. **RichTextLabel for Logs**: Supports BBCode for color-coding and formatting
3. **LineEdit for Command Input**: Built-in text editing with history support
4. **Input.is_action_pressed()**: Use for continuous zoom input
5. **Input.is_action_just_pressed()**: Use for toggle actions
6. **ConfigFile**: Use for saving/loading presets and history

### Integration with Existing Systems

1. **TerrainRenderer**: Add LogRouter.log() calls in chunk loading methods
2. **StreamingManager**: Add LogRouter.log() calls in streaming events
3. **SimulationState**: Add LogRouter.log() calls in submarine state changes
4. **ViewManager**: Add LogRouter.log() calls in view switches
5. **InputSystem**: Integrate ViewInputHandler for enhanced key bindings

### File Locations

- Console UI: `scripts/ui/dev_console.gd`
- Command Parser: `scripts/ui/command_parser.gd`
- Log Router: `scripts/core/log_router.gd`
- Debug Panel Manager: `scripts/debug/debug_panel_manager.gd`
- View Input Handler: `scripts/core/view_input_handler.gd`
- History File: `user://console_history.txt`
- Presets: `user://console_presets/<name>.cfg`

## Future Enhancements

1. **Command Aliases**: Allow users to create custom command shortcuts
2. **Scripting Support**: Execute GDScript snippets from console
3. **Remote Console**: Connect to console over network for debugging
4. **Log Export**: Export console logs to file
5. **Console Themes**: Customizable colors and fonts
6. **Command Macros**: Record and replay command sequences
7. **Performance Profiling**: Built-in profiler accessible from console
8. **Variable Inspection**: Inspect and modify game variables from console
