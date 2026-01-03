# Implementation Plan: Developer Console UI

## Overview

This implementation plan breaks down the developer console and UI refinement into discrete coding tasks. The approach prioritizes core console functionality first, then integrates logging, adds command features, and finally implements view enhancements and persistence.

## Tasks

- [x] ✅ 1. Create LogRouter system for centralized logging
  - Create `scripts/core/log_router.gd` as autoload singleton
  - Implement LogEntry class with timestamp, level, category, message, color
  - Implement log level filtering (DEBUG, INFO, WARNING, ERROR)
  - Implement category filtering
  - Add circular buffer with 1000 entry limit
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
  - **Status: COMPLETE** - All 14 unit tests passing

- [ ]* 1.1 Write property test for log buffer size limit
  - **Property 5: Log Buffer Size Limit**
  - **Validates: Requirements 1.8**

- [ ]* 1.2 Write property test for log level filtering
  - **Property 14: Log Level Filtering**
  - **Validates: Requirements 3.5**

- [ ]* 1.3 Write property test for log color coding
  - **Property 15: Log Color Coding**
  - **Validates: Requirements 3.6**

- [x] 2. Create DevConsole UI component
  - Create `scripts/ui/dev_console.gd` extending CanvasLayer (layer 10)
  - Add semi-transparent background panel with MOUSE_FILTER_STOP
  - Add RichTextLabel for scrollable log display with BBCode support
  - Add LineEdit for command input at bottom
  - Implement toggle_visibility() method
  - Add tilde (~) key binding to toggle console
  - Implement auto-scroll to bottom when new logs added
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.7_

- [ ]* 2.1 Write property test for console toggle consistency
  - **Property 1: Console Toggle Consistency**
  - **Validates: Requirements 1.1**

- [ ]* 2.2 Write property test for input routing based on console state
  - **Property 2: Input Routing Based on Console State**
  - **Validates: Requirements 1.3, 1.4**

- [ ]* 2.3 Write property test for log auto-scroll behavior
  - **Property 4: Log Auto-Scroll Behavior**
  - **Validates: Requirements 1.7**

- [x] 3. Integrate LogRouter with DevConsole
  - Connect LogRouter signals to DevConsole log display
  - Implement color-coded log rendering in RichTextLabel
  - Add filter status display in console header
  - Test log messages appear in console with correct colors
  - _Requirements: 3.4, 3.6, 7.6_

- [ ]* 3.1 Write property test for filter status display
  - **Property 23: Filter Status Display**
  - **Validates: Requirements 7.6**

- [x] 4. Create CommandParser system
  - Create `scripts/ui/command_parser.gd` class
  - Implement parse() method to extract command and arguments
  - Implement command validation with error messages
  - Add command suggestion system using Levenshtein distance
  - Implement execute() method that routes to appropriate handlers
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ]* 4.1 Write property test for command execution produces output
  - **Property 3: Command Execution Produces Output**
  - **Validates: Requirements 1.5, 1.6**

- [ ]* 4.2 Write property test for invalid command error handling
  - **Property 6: Invalid Command Error Handling**
  - **Validates: Requirements 2.4**

- [x] 5. Implement core console commands
  - Implement /help command with command list display
  - Implement /clear command to empty log buffer
  - Implement /debug on/off command
  - Implement /log <level> command for log level filtering
  - Implement /filter commands (warnings, errors, category, reset)
  - Add command execution to DevConsole LineEdit on Enter key
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 3.5, 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 6. Checkpoint - Test console and logging
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Create DebugPanelManager system
  - Create `scripts/debug/debug_panel_manager.gd` as autoload singleton
  - Implement enable_all() and disable_all() methods
  - Implement toggle_panel(name) for individual panel control
  - Register existing debug panels (TerrainDebugOverlay, PerformanceMonitor, etc.)
  - Set debug panels to layer 5 (below console)
  - Ensure debug panels use MOUSE_FILTER_IGNORE for backgrounds
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

- [ ]* 7.1 Write property test for debug panel visibility matches debug mode
  - **Property 20: Debug Panel Visibility Matches Debug Mode**
  - **Validates: Requirements 6.1, 6.2**

- [ ]* 7.2 Write property test for console and debug panel independence
  - **Property 21: Console and Debug Panel Independence**
  - **Validates: Requirements 6.3**

- [ ]* 7.3 Write property test for debug panel input pass-through
  - **Property 22: Debug Panel Input Pass-Through**
  - **Validates: Requirements 6.5**

- [x] 8. Integrate DebugPanelManager with console commands
  - Connect /debug on/off commands to DebugPanelManager
  - Implement /debug terrain command to toggle terrain overlay
  - Implement /debug performance command to toggle performance monitor
  - Update console header to show debug mode status
  - _Requirements: 2.1, 6.6, 6.7_

- [x] 9. Implement /relocate command
  - Add /relocate <x> <y> <z> command to CommandParser
  - Integrate with SimulationState to move submarine
  - Log submarine position change to console
  - Log any triggered terrain streaming events
  - _Requirements: 2.6, 3.2, 3.3_

- [ ]* 9.1 Write property test for relocate command updates position
  - **Property 7: Relocate Command Updates Position**
  - **Validates: Requirements 2.6**

- [ ]* 9.2 Write property test for submarine relocation logged
  - **Property 11: Submarine Relocation Logged**
  - **Validates: Requirements 3.2**

- [x] 10. Add LogRouter integration to existing systems
  - Add LogRouter.log() calls to TerrainRenderer chunk loading/unloading
  - Add LogRouter.log() calls to StreamingManager streaming events
  - Add LogRouter.log() calls to SimulationState submarine state changes
  - Add LogRouter.log() calls to ViewManager view switches
  - Test that all events appear in console with correct categories
  - _Requirements: 3.1, 3.2, 3.3_

- [ ]* 10.1 Write property test for terrain events logged
  - **Property 10: Terrain Events Logged**
  - **Validates: Requirements 3.1**

- [ ]* 10.2 Write property test for streaming events logged
  - **Property 12: Streaming Events Logged**
  - **Validates: Requirements 3.3**

- [ ]* 10.3 Write property test for error/warning routing
  - **Property 13: Error/Warning Routing**
  - **Validates: Requirements 3.4**

- [-] 11. Checkpoint - Test logging integration
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Implement command history system
  - Add command_history array (max 50 commands) to DevConsole
  - Implement Up/Down arrow key navigation through history
  - Add history_index tracking for navigation
  - Store executed commands in history
  - _Requirements: 2.7, 8.5_

- [ ]* 12.1 Write property test for command history navigation
  - **Property 8: Command History Navigation**
  - **Validates: Requirements 2.7**

- [ ] 13. Implement command auto-completion
  - Add Tab key handler to DevConsole
  - Implement get_suggestions() in CommandParser
  - Complete partial commands when unique match found
  - Show suggestions when multiple matches exist
  - _Requirements: 2.8_

- [ ]* 13.1 Write property test for command auto-completion
  - **Property 9: Command Auto-Completion**
  - **Validates: Requirements 2.8**

- [ ] 14. Create ViewInputHandler for enhanced key bindings
  - Create `scripts/core/view_input_handler.gd` class
  - Implement input priority system (console > overlays > views > game)
  - Add F4 key binding for whole map view
  - Add M key binding to toggle tactical map
  - Update 1/2/3 key bindings for view switching
  - Add Escape key handler to close overlays first
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.7_

- [ ]* 14.1 Write property test for view toggle with M key
  - **Property 16: View Toggle with M Key**
  - **Validates: Requirements 4.2**

- [ ]* 14.2 Write property test for escape key priority
  - **Property 17: Escape Key Priority**
  - **Validates: Requirements 4.7**

- [ ] 15. Implement external view camera zoom controls
  - Add zoom_distance property to ExternalView (default 100m, min 20m, max 500m)
  - Implement zoom_camera(delta) method
  - Add +/= key binding to zoom in (decrease distance by 10m)
  - Add -/_ key binding to zoom out (increase distance by 10m)
  - Add mouse wheel zoom support
  - Ensure zoom maintains orbit angle and look-at target
  - Clamp zoom to min/max boundaries
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [ ]* 15.1 Write property test for external view zoom changes distance
  - **Property 18: External View Zoom Changes Distance**
  - **Validates: Requirements 5.1, 5.2, 5.6**

- [ ]* 15.2 Write property test for zoom preserves orbit angle
  - **Property 19: Zoom Preserves Orbit Angle**
  - **Validates: Requirements 5.3**

- [ ] 16. Set external view as default startup view
  - Update ViewManager to start with ViewType.EXTERNAL instead of TACTICAL_MAP
  - Update main.tscn to have ExternalView visible by default
  - Test that game starts in external view
  - _Requirements: 4.6_

- [ ] 17. Fix tactical map click-through issue
  - Update TacticalMapView UI controls to use MOUSE_FILTER_STOP
  - Ensure speed_slider and depth_slider consume mouse events
  - Verify clicks on sliders don't pass through to map waypoint placement
  - Test that map only receives clicks when not over UI controls
  - _Requirements: 1.3, 6.5_

- [ ] 18. Checkpoint - Test view controls and input handling
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 19. Implement console persistence system
  - Create save_history() method to write last 50 commands to user://console_history.txt
  - Create load_history() method to restore commands on startup
  - Call save_history() when game closes
  - Call load_history() in DevConsole._ready()
  - _Requirements: 8.1, 8.2_

- [ ] 20. Implement console preset system
  - Create ConsolePreset class with configuration fields
  - Implement /save <name> command to save preset to user://console_presets/<name>.cfg
  - Implement /load <name> command to restore preset
  - Implement /history command to display command history
  - Use ConfigFile for preset serialization
  - _Requirements: 8.3, 8.4, 8.5_

- [x] 21. Add DevConsole and systems to main scene
  - Add LogRouter as autoload in project.godot
  - Add DebugPanelManager as autoload in project.godot
  - Add DevConsole node to main.tscn as CanvasLayer (layer 10)
  - Add ViewInputHandler to main.tscn
  - Wire up all references and signals
  - _Requirements: All_

- [ ] 22. Final integration testing and polish
  - Test all console commands work correctly
  - Test all view switching keys work correctly
  - Test external view zoom controls work correctly
  - Test log filtering and display work correctly
  - Test debug panel visibility toggles work correctly
  - Test command history and auto-completion work correctly
  - Test console persistence across game restarts
  - Verify click-through issue is fixed
  - _Requirements: All_

- [ ]* 22.1 Write integration test for console-LogRouter integration
  - Test that logs from game systems appear in console

- [ ]* 22.2 Write integration test for console-DebugPanelManager integration
  - Test that /debug commands control panel visibility

- [ ]* 22.3 Write integration test for console-SimulationState integration
  - Test that /relocate command moves submarine

- [ ]* 22.4 Write integration test for ViewInputHandler-ViewManager integration
  - Test that view switching keys work correctly

- [ ] 23. Final checkpoint - Complete system verification
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Integration tests verify component interactions
- The click-through fix (task 17) addresses the reported issue with tactical map sliders
