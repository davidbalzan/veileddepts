# Requirements Document

## Introduction

This specification defines a developer console and improved debug UI separation for the tactical submarine simulator. The system provides a command-line interface for controlling debug features, viewing system logs, and managing view states with proper keyboard bindings.

## Glossary

- **Dev_Console**: A tilde (~) activated command-line interface for developer commands and log viewing
- **Debug_Panel**: Visual overlay showing system diagnostics and debug information
- **View_System**: The existing view manager that switches between tactical map, periscope, external, and whole map views
- **Log_System**: Centralized logging that routes messages to the dev console
- **Command_Parser**: Component that interprets and executes console commands

## Requirements

### Requirement 1: Developer Console

**User Story:** As a developer, I want a tilde (~) activated console with command-line interface, so that I can control debug features and view system logs without cluttering the game UI.

#### Acceptance Criteria

1. WHEN the user presses the tilde (~) key THEN the System SHALL toggle the developer console visibility
2. WHEN the console is visible THEN the System SHALL display a command input field at the bottom and a scrollable log area above it
3. WHEN the console is visible THEN the System SHALL capture keyboard input for the command line and prevent game input
4. WHEN the console is hidden THEN the System SHALL restore normal game input handling
5. WHEN the user types a command and presses Enter THEN the System SHALL parse and execute the command
6. WHEN a command is executed THEN the System SHALL display the command result in the console log
7. WHEN the console displays logs THEN the System SHALL auto-scroll to show the most recent entries
8. WHEN the console has many log entries THEN the System SHALL limit the buffer to prevent memory issues (e.g., 1000 lines)

### Requirement 2: Console Command System

**User Story:** As a developer, I want to execute commands like "/debug on/off" in the console, so that I can control debug features programmatically.

#### Acceptance Criteria

1. WHEN the user types "/debug on" THEN the System SHALL enable all debug panels and log "Debug mode enabled"
2. WHEN the user types "/debug off" THEN the System SHALL disable all debug panels and log "Debug mode disabled"
3. WHEN the user types "/help" THEN the System SHALL display a list of available commands
4. WHEN the user types an invalid command THEN the System SHALL display an error message with suggestions
5. WHEN the user types "/clear" THEN the System SHALL clear the console log history
6. WHEN the user types "/relocate <x> <y> <z>" THEN the System SHALL move the submarine to the specified coordinates and log the action
7. WHEN the user presses Up/Down arrow keys THEN the System SHALL navigate through command history
8. WHEN the user types a partial command and presses Tab THEN the System SHALL auto-complete the command if possible

### Requirement 3: Centralized Log Routing

**User Story:** As a developer, I want all system logs to appear in the dev console, so that I can monitor terrain loading, map streaming, and other events in one place.

#### Acceptance Criteria

1. WHEN terrain chunks are loaded THEN the System SHALL log the event to the console with chunk coordinates
2. WHEN the submarine is relocated THEN the System SHALL log the new position and any triggered map updates
3. WHEN map streaming events occur THEN the System SHALL log the streaming status and affected regions
4. WHEN errors or warnings occur THEN the System SHALL log them to the console with appropriate severity indicators
5. WHEN the user types "/log <level>" THEN the System SHALL filter console output to show only messages at or above the specified level (debug, info, warning, error)
6. WHEN logs are displayed THEN the System SHALL color-code them by severity (debug=gray, info=white, warning=yellow, error=red)

### Requirement 4: View Keybinding Improvements

**User Story:** As a player, I want improved keyboard bindings for views, so that I can quickly access different perspectives with intuitive keys.

#### Acceptance Criteria

1. WHEN the user presses F4 THEN the System SHALL switch to Screen 4 (whole map view)
2. WHEN the user presses M THEN the System SHALL toggle the tactical map view
3. WHEN the user presses 1 THEN the System SHALL switch to tactical map view
4. WHEN the user presses 2 THEN the System SHALL switch to periscope view
5. WHEN the user presses 3 THEN the System SHALL switch to external view (default)
6. WHEN Screen 3 (external view) is active THEN the System SHALL set it as the default view on startup
7. WHEN the user presses Escape THEN the System SHALL close any open overlays (console, help) before affecting game state

### Requirement 5: External View Camera Controls

**User Story:** As a player, I want to zoom in and out on the orbit camera in external view, so that I can adjust my viewing distance.

#### Acceptance Criteria

1. WHEN the user presses the Plus (+) key in external view THEN the System SHALL zoom the camera closer to the submarine
2. WHEN the user presses the Minus (-) key in external view THEN the System SHALL zoom the camera farther from the submarine
3. WHEN the camera zooms THEN the System SHALL maintain the current orbit angle and look-at target
4. WHEN the camera reaches minimum zoom distance THEN the System SHALL prevent further zoom-in
5. WHEN the camera reaches maximum zoom distance THEN the System SHALL prevent further zoom-out
6. WHEN the user scrolls the mouse wheel in external view THEN the System SHALL zoom the camera in/out as an alternative to +/- keys

### Requirement 6: Debug Panel Separation

**User Story:** As a developer, I want debug panels to be separate from the dev console, so that I can view diagnostics without the console being open.

#### Acceptance Criteria

1. WHEN debug mode is enabled THEN the System SHALL show debug panels as overlays on the active view
2. WHEN debug mode is disabled THEN the System SHALL hide all debug panels
3. WHEN the console is closed THEN the System SHALL keep debug panels visible if debug mode is enabled
4. WHEN the console is open THEN the System SHALL display it above debug panels in the z-order
5. WHEN debug panels are visible THEN the System SHALL allow mouse interaction to pass through to the game
6. WHEN the user types "/debug terrain" THEN the System SHALL toggle only the terrain debug overlay
7. WHEN the user types "/debug performance" THEN the System SHALL toggle only the performance monitor overlay

### Requirement 7: Console Log Filtering

**User Story:** As a developer, I want to filter console logs by category and severity, so that I can focus on relevant information.

#### Acceptance Criteria

1. WHEN the user types "/filter warnings off" THEN the System SHALL hide warning-level messages from the console
2. WHEN the user types "/filter errors off" THEN the System SHALL hide error-level messages from the console
3. WHEN the user types "/filter category terrain" THEN the System SHALL show only terrain-related messages
4. WHEN the user types "/filter category all" THEN the System SHALL show messages from all categories
5. WHEN the user types "/filter reset" THEN the System SHALL clear all filters and show all messages
6. WHEN filters are active THEN the System SHALL display the current filter status in the console header

### Requirement 8: Console Persistence

**User Story:** As a developer, I want the console to remember my command history and settings, so that I can quickly repeat common commands across sessions.

#### Acceptance Criteria

1. WHEN the game closes THEN the System SHALL save the last 50 console commands to a history file
2. WHEN the game starts THEN the System SHALL load the command history from the previous session
3. WHEN the user types "/save <name>" THEN the System SHALL save the current console state as a named preset
4. WHEN the user types "/load <name>" THEN the System SHALL restore a saved console preset
5. WHEN the user types "/history" THEN the System SHALL display the command history in the console
