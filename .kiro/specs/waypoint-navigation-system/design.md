# Design Document: Waypoint Navigation System

## Overview

The Waypoint Navigation System provides comprehensive route planning and automated navigation capabilities for the tactical submarine simulator. Players can plot multi-segment routes with configurable stance and speed parameters, visualize their planned path on the tactical map, and engage auto-navigation to follow the route automatically. The system integrates with the existing View Manager to enable seamless switching between different game screens (Tactical Map, Periscope, Helm, Sonar).

This design leverages the existing coordinate system, simulation state, and tactical map infrastructure while adding new components for waypoint management, route execution, and view switching.

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Main Scene                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              ViewManager                              │   │
│  │  - Manages active view                                │   │
│  │  - Handles view switching (F1-F4)                     │   │
│  │  - Preserves view state                               │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                    │
│         ┌────────────────┼────────────────┬─────────────┐   │
│         │                │                │             │   │
│    ┌────▼────┐     ┌────▼────┐     ┌────▼────┐   ┌────▼────┐
│    │Tactical │     │Periscope│     │  Helm   │   │  Sonar  │
│    │   Map   │     │  View   │     │  View   │   │  View   │
│    └────┬────┘     └─────────┘     └─────────┘   └─────────┘
│         │                                                     │
│    ┌────▼──────────────────────────────────────────────┐    │
│    │         WaypointSystem                             │    │
│    │  - Waypoint creation/deletion                      │    │
│    │  - Route segment configuration                     │    │
│    │  - Route visualization                             │    │
│    │  - Auto-navigation execution                       │    │
│    │  - Collision detection                             │    │
│    └────┬──────────────────────────────────────────────┘    │
│         │                                                     │
│    ┌────▼──────────────────────────────────────────────┐    │
│    │         SimulationState                            │    │
│    │  - Submarine state                                 │    │
│    │  - Target commands                                 │    │
│    └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Integration Points

1. **TacticalMapView**: Hosts the waypoint UI and visualization
2. **SimulationState**: Stores current submarine state and target commands
3. **CoordinateSystem**: Provides heading and distance calculations
4. **TerrainRenderer**: Provides elevation data for collision detection

## Components and Interfaces

### 1. ViewManager

Manages the active game view and handles view switching.

**Interface**:
```gdscript
class_name ViewManager extends Node

# Available views
enum GameView {
	TACTICAL_MAP,
	PERISCOPE,
	HELM,
	SONAR
}

# Current active view
var current_view: GameView = GameView.TACTICAL_MAP

# View node references
var tactical_map_view: TacticalMapView
var periscope_view: Node  # Placeholder for future implementation
var helm_view: Node       # Placeholder for future implementation
var sonar_view: Node      # Placeholder for future implementation

# Switch to a specific view
func switch_to_view(view: GameView) -> void

# Get the current view name as string
func get_current_view_name() -> String

# Handle view hotkey input
func handle_view_hotkey(keycode: int) -> bool
```

**Responsibilities**:
- Maintain references to all game view nodes
- Show/hide views based on active selection
- Preserve view state when switching
- Handle F1-F4 hotkeys for view switching
- Display current view name in UI

### 2. Waypoint

Represents a single navigation waypoint with geographic coordinates.

**Interface**:
```gdscript
class_name Waypoint extends RefCounted

# Unique identifier
var id: int = 0

# Sequential number in route (1-based)
var number: int = 0

# Geographic position (world coordinates)
var position: Vector3 = Vector3.ZERO

# Depth at this waypoint (meters below surface)
var depth: float = 0.0

# Optional waypoint name
var name: String = ""

# Constructor
func _init(p_position: Vector3, p_depth: float = 0.0, p_name: String = "")

# Calculate distance to another waypoint
func distance_to(other: Waypoint) -> float

# Calculate bearing to another waypoint
func bearing_to(other: Waypoint) -> float

# Serialize to dictionary
func to_dict() -> Dictionary

# Deserialize from dictionary
static func from_dict(data: Dictionary) -> Waypoint
```

### 3. RouteSegment

Represents the path between two consecutive waypoints with operational parameters.

**Interface**:
```gdscript
class_name RouteSegment extends RefCounted

# Segment endpoints
var start_waypoint: Waypoint
var end_waypoint: Waypoint

# Operational stance for this segment
enum Stance {
	SILENT,    # Max 5 knots, minimal noise
	STANDARD,  # Max 15 knots, normal operations
	FLANK,     # Max 25 knots, high speed
	EMERGENCY  # Max 35 knots, maximum speed
}
var stance: Stance = Stance.STANDARD

# Speed as percentage of stance maximum (0-100)
var speed_percent: float = 50.0

# Calculated segment properties
var distance: float = 0.0  # meters
var estimated_time: float = 0.0  # seconds

# Collision warning level
enum CollisionWarning {
	NONE,     # No collision detected
	CAUTION,  # Within 50m of terrain
	DANGER    # Intersects terrain
}
var collision_warning: CollisionWarning = CollisionWarning.NONE

# Constructor
func _init(p_start: Waypoint, p_end: Waypoint)

# Get maximum speed for current stance (m/s)
func get_max_speed() -> float

# Get actual target speed (m/s)
func get_target_speed() -> float

# Calculate segment metrics
func calculate_metrics() -> void

# Get segment color for visualization
func get_color() -> Color

# Serialize to dictionary
func to_dict() -> Dictionary

# Deserialize from dictionary
static func from_dict(data: Dictionary, waypoints: Array[Waypoint]) -> RouteSegment
```

### 4. WaypointSystem

Core system managing waypoints, routes, and auto-navigation.

**Interface**:
```gdscript
class_name WaypointSystem extends Node

# Route data
var waypoints: Array[Waypoint] = []
var segments: Array[RouteSegment] = []
var next_waypoint_id: int = 1

# Auto-navigation state
var auto_navigation_active: bool = false
var current_segment_index: int = -1
var waypoint_reached_threshold: float = 100.0  # meters

# References
var simulation_state: SimulationState
var terrain_renderer: Node

# Waypoint management
func add_waypoint(position: Vector3, depth: float = 0.0) -> Waypoint
func remove_waypoint(waypoint_id: int) -> bool
func move_waypoint(waypoint_id: int, new_position: Vector3) -> bool
func get_waypoint(waypoint_id: int) -> Waypoint
func clear_route() -> void

# Segment configuration
func configure_segment(segment_index: int, stance: RouteSegment.Stance, speed_percent: float) -> bool
func get_segment(segment_index: int) -> RouteSegment

# Route metrics
func get_total_distance() -> float
func get_total_estimated_time() -> float
func get_distance_to_waypoint(waypoint_index: int) -> float
func get_bearing_to_waypoint(waypoint_index: int) -> float

# Auto-navigation
func start_auto_navigation() -> bool
func stop_auto_navigation() -> void
func pause_auto_navigation() -> void
func resume_auto_navigation() -> void
func update_auto_navigation(delta: float) -> void

# Collision detection
func check_segment_collision(segment: RouteSegment) -> RouteSegment.CollisionWarning
func update_collision_warnings() -> void

# Import/Export
func export_route(filepath: String) -> bool
func import_route(filepath: String) -> bool

# Serialization
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void
```

**Responsibilities**:
- Manage waypoint creation, deletion, and modification
- Maintain route segments with operational parameters
- Execute auto-navigation logic
- Calculate route metrics (distance, time, bearing)
- Detect terrain collisions along route
- Handle route import/export

### 5. WaypointUI

UI component for waypoint interaction on the tactical map.

**Interface**:
```gdscript
class_name WaypointUI extends Control

# References
var waypoint_system: WaypointSystem
var tactical_map_view: TacticalMapView

# UI state
var selected_waypoint_id: int = -1
var selected_segment_index: int = -1
var hovered_waypoint_id: int = -1

# Configuration panel
var config_panel: Panel
var stance_option_button: OptionButton
var speed_slider: HSlider
var speed_label: Label

# Route info panel
var route_info_panel: Panel
var total_distance_label: Label
var total_time_label: Label

# Auto-navigation controls
var auto_nav_button: Button
var auto_nav_status_label: Label

# Waypoint interaction
func handle_waypoint_click(screen_pos: Vector2) -> void
func handle_waypoint_drag(waypoint_id: int, screen_pos: Vector2) -> void
func handle_waypoint_context_menu(waypoint_id: int) -> void

# Segment interaction
func handle_segment_click(segment_index: int) -> void
func show_segment_config_panel(segment_index: int) -> void
func hide_segment_config_panel() -> void

# UI updates
func update_route_info() -> void
func update_auto_nav_status() -> void
func update_waypoint_markers() -> void
```

### 6. WaypointRenderer

Rendering component for visualizing waypoints and routes on the tactical map.

**Interface**:
```gdscript
class_name WaypointRenderer extends Node

# References
var waypoint_system: WaypointSystem
var tactical_map_view: TacticalMapView

# Visual constants
const WAYPOINT_RADIUS: float = 8.0
const WAYPOINT_HOVER_RADIUS: float = 12.0
const ACTIVE_WAYPOINT_RADIUS: float = 10.0
const SEGMENT_LINE_WIDTH: float = 3.0
const ACTIVE_SEGMENT_LINE_WIDTH: float = 5.0

# Render waypoints
func draw_waypoints(canvas: Control) -> void

# Render route segments
func draw_segments(canvas: Control) -> void

# Render waypoint numbers
func draw_waypoint_numbers(canvas: Control) -> void

# Render collision warnings
func draw_collision_warnings(canvas: Control) -> void

# Render route metrics
func draw_route_metrics(canvas: Control) -> void

# Helper: Convert world position to screen position
func world_to_screen(world_pos: Vector3) -> Vector2

# Helper: Get segment color based on stance and warnings
func get_segment_color(segment: RouteSegment) -> Color
```

## Data Models

### Waypoint Data Structure

```gdscript
{
	"id": 1,
	"number": 1,
	"position": Vector3(100, 0, -200),
	"depth": -50.0,
	"name": "Checkpoint Alpha"
}
```

### RouteSegment Data Structure

```gdscript
{
	"start_waypoint_id": 1,
	"end_waypoint_id": 2,
	"stance": RouteSegment.Stance.STANDARD,
	"speed_percent": 75.0,
	"distance": 500.0,
	"estimated_time": 25.0,
	"collision_warning": RouteSegment.CollisionWarning.NONE
}
```

### Route File Format (JSON)

```json
{
	"version": "1.0",
	"metadata": {
		"name": "Northern Patrol Route",
		"description": "Standard patrol pattern for northern sector",
		"created": "2026-01-03T12:00:00Z",
		"author": "Commander Smith"
	},
	"waypoints": [
		{
			"id": 1,
			"number": 1,
			"position": [100.0, 0.0, -200.0],
			"depth": -50.0,
			"name": "Checkpoint Alpha"
		},
		{
			"id": 2,
			"number": 2,
			"position": [300.0, 0.0, -400.0],
			"depth": -75.0,
			"name": "Checkpoint Bravo"
		}
	],
	"segments": [
		{
			"start_waypoint_id": 1,
			"end_waypoint_id": 2,
			"stance": "STANDARD",
			"speed_percent": 75.0
		}
	]
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Waypoint Uniqueness

*For any* waypoint system state, all waypoint IDs should be unique and no two waypoints should have the same ID.

**Validates: Requirements 1.2**

### Property 2: Sequential Waypoint Numbering

*For any* route with N waypoints, the waypoint numbers should be sequential from 1 to N without gaps.

**Validates: Requirements 1.2, 1.4**

### Property 3: Segment Endpoint Validity

*For any* route segment, both the start and end waypoints must exist in the waypoint list.

**Validates: Requirements 2.1**

### Property 4: Stance Speed Limits

*For any* route segment with stance S and speed percentage P, the calculated target speed should not exceed the maximum speed for stance S.

**Validates: Requirements 2.4, 2.5, 2.6, 2.7**

### Property 5: Route Segment Continuity

*For any* route with N waypoints, there should be exactly N-1 segments, and segment i should connect waypoint i to waypoint i+1.

**Validates: Requirements 3.1**

### Property 6: Waypoint Reached Detection

*For any* submarine position P and target waypoint W, if the distance between P and W is less than the threshold (100m), the waypoint should be marked as reached.

**Validates: Requirements 4.2**

### Property 7: Auto-Navigation Progression

*For any* active auto-navigation state, when a waypoint is reached and there are more waypoints ahead, the current segment index should increment by 1.

**Validates: Requirements 4.2, 4.3**

### Property 8: View State Preservation

*For any* view V, switching away from V and then back to V should restore V to its previous state (same zoom, pan, selections).

**Validates: Requirements 5.4**

### Property 9: Hotkey View Mapping

*For any* hotkey H in {F1, F2, F3, F4}, pressing H should switch to the corresponding view {Tactical_Map, Periscope, Helm, Sonar}.

**Validates: Requirements 6.1, 6.2, 6.3, 6.4**

### Property 10: Route Import/Export Round Trip

*For any* valid route R, exporting R to a file and then importing that file should produce an equivalent route R' where all waypoints and segments match.

**Validates: Requirements 7.1, 7.2, 7.3, 7.5**

### Property 11: Distance Calculation Consistency

*For any* two waypoints W1 and W2, the distance from W1 to W2 should equal the distance from W2 to W1.

**Validates: Requirements 8.1, 8.6**

### Property 12: Bearing Calculation Range

*For any* two distinct waypoints W1 and W2, the bearing from W1 to W2 should be in the range [0, 360) degrees.

**Validates: Requirements 8.2**

### Property 13: Route Modification Consistency

*For any* route with active auto-navigation, adding or removing waypoints ahead of the current position should update the route metrics without affecting the current segment.

**Validates: Requirements 9.1, 9.2, 9.4**

### Property 14: Collision Warning Persistence

*For any* route segment S with a collision warning, the warning should persist until the segment geometry changes (waypoint moved) or the terrain data changes.

**Validates: Requirements 10.1, 10.6**

## Error Handling

### Waypoint System Errors

1. **Invalid Waypoint Position**: If a waypoint position is outside map boundaries, clamp to boundaries and log warning
2. **Duplicate Waypoint ID**: If attempting to add a waypoint with existing ID, generate new unique ID
3. **Missing Waypoint Reference**: If a segment references a non-existent waypoint, remove the segment and log error
4. **Invalid Segment Configuration**: If stance or speed values are out of range, clamp to valid range and log warning

### Auto-Navigation Errors

1. **No Waypoints**: If auto-navigation is started with empty route, display error message and refuse to start
2. **Obstacle Detected**: If collision is detected during auto-navigation, pause navigation and alert player
3. **Waypoint Unreachable**: If submarine cannot reach waypoint after 5 minutes, alert player and suggest manual control
4. **Navigation Timeout**: If auto-navigation is active for more than 2 hours, alert player and suggest review

### View Manager Errors

1. **View Not Implemented**: If switching to unimplemented view, display placeholder screen with "Coming Soon" message
2. **View Initialization Failed**: If view fails to initialize, log error and fall back to Tactical Map view
3. **Invalid Hotkey**: If unrecognized hotkey is pressed, ignore and log debug message

### Import/Export Errors

1. **File Not Found**: Display error message "Route file not found"
2. **Invalid JSON**: Display error message "Route file is corrupted or invalid"
3. **Version Mismatch**: If route file version is incompatible, attempt to migrate or display error
4. **Missing Required Fields**: If route file is missing required fields, display error with details

## Testing Strategy

### Unit Tests

Unit tests verify specific examples, edge cases, and error conditions for individual components.

**Waypoint Tests**:
- Test waypoint creation with valid coordinates
- Test waypoint distance calculation between known points
- Test waypoint bearing calculation for cardinal directions
- Test waypoint serialization/deserialization

**RouteSegment Tests**:
- Test segment creation with valid waypoints
- Test stance speed limit calculations for each stance
- Test segment color mapping for each stance
- Test collision warning levels

**WaypointSystem Tests**:
- Test adding waypoints updates waypoint list
- Test removing waypoints renumbers subsequent waypoints
- Test clearing route removes all waypoints and segments
- Test auto-navigation starts only with valid route

**ViewManager Tests**:
- Test view switching changes active view
- Test hotkey mapping for each F-key
- Test view state preservation on switch
- Test fallback to placeholder for unimplemented views

### Property-Based Tests

Property-based tests verify universal properties across all inputs using randomization (minimum 100 iterations per test).

**Property Test 1: Waypoint Uniqueness**
- Generate random waypoint system with N waypoints
- Verify all waypoint IDs are unique
- **Feature: waypoint-navigation-system, Property 1: Waypoint Uniqueness**

**Property Test 2: Sequential Waypoint Numbering**
- Generate random route with N waypoints
- Verify waypoint numbers are 1, 2, 3, ..., N
- **Feature: waypoint-navigation-system, Property 2: Sequential Waypoint Numbering**

**Property Test 3: Segment Endpoint Validity**
- Generate random route with waypoints and segments
- Verify all segment endpoints exist in waypoint list
- **Feature: waypoint-navigation-system, Property 3: Segment Endpoint Validity**

**Property Test 4: Stance Speed Limits**
- Generate random segments with all stance types
- Verify target speed never exceeds stance maximum
- **Feature: waypoint-navigation-system, Property 4: Stance Speed Limits**

**Property Test 5: Route Segment Continuity**
- Generate random route with N waypoints
- Verify exactly N-1 segments exist
- Verify segment i connects waypoint i to waypoint i+1
- **Feature: waypoint-navigation-system, Property 5: Route Segment Continuity**

**Property Test 6: Waypoint Reached Detection**
- Generate random submarine positions and waypoints
- Verify waypoint marked as reached when distance < threshold
- **Feature: waypoint-navigation-system, Property 6: Waypoint Reached Detection**

**Property Test 7: Auto-Navigation Progression**
- Generate random routes and simulate waypoint reaching
- Verify segment index increments correctly
- **Feature: waypoint-navigation-system, Property 7: Auto-Navigation Progression**

**Property Test 8: View State Preservation**
- Generate random view states (zoom, pan, selections)
- Switch away and back
- Verify state is restored
- **Feature: waypoint-navigation-system, Property 8: View State Preservation**

**Property Test 9: Hotkey View Mapping**
- Test all hotkeys F1-F4
- Verify correct view is activated
- **Feature: waypoint-navigation-system, Property 9: Hotkey View Mapping**

**Property Test 10: Route Import/Export Round Trip**
- Generate random routes
- Export to JSON and import back
- Verify routes are equivalent
- **Feature: waypoint-navigation-system, Property 10: Route Import/Export Round Trip**

**Property Test 11: Distance Calculation Consistency**
- Generate random waypoint pairs
- Verify distance(W1, W2) == distance(W2, W1)
- **Feature: waypoint-navigation-system, Property 11: Distance Calculation Consistency**

**Property Test 12: Bearing Calculation Range**
- Generate random waypoint pairs
- Verify bearing is in [0, 360) range
- **Feature: waypoint-navigation-system, Property 12: Bearing Calculation Range**

**Property Test 13: Route Modification Consistency**
- Generate random routes with active navigation
- Add/remove waypoints ahead of current position
- Verify current segment unchanged
- **Feature: waypoint-navigation-system, Property 13: Route Modification Consistency**

**Property Test 14: Collision Warning Persistence**
- Generate random segments with collision warnings
- Verify warnings persist until geometry changes
- **Feature: waypoint-navigation-system, Property 14: Collision Warning Persistence**

### Integration Tests

- Test waypoint system integration with tactical map view
- Test auto-navigation integration with submarine physics
- Test view manager integration with all game views
- Test collision detection integration with terrain renderer
- Test route import/export with file system

### Manual Testing Scenarios

1. **Route Planning**: Create a multi-waypoint route, configure segments, verify visualization
2. **Auto-Navigation**: Start auto-navigation, verify submarine follows route, reaches waypoints
3. **View Switching**: Switch between all views using hotkeys, verify state preservation
4. **Route Modification**: Modify route during active navigation, verify updates
5. **Collision Warnings**: Create route through terrain, verify warnings appear
6. **Import/Export**: Save route, load in new session, verify route restored
