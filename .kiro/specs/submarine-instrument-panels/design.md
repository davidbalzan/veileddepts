# Design Document

## Overview

The submarine instrument panel system provides a modular, extensible UI framework for displaying submarine systems data and accepting operator input. The architecture separates concerns between panel management, data integration, widget rendering, and user interaction. Each panel is a self-contained component that can be independently developed, tested, and deployed.

The system integrates with existing submarine physics, terrain streaming, and waypoint navigation systems to provide real-time operational displays. A centralized panel manager handles lifecycle, layout, and data routing while individual panels focus on their specific domain logic.

## Architecture

### High-Level Structure

```
┌─────────────────────────────────────────────────────────┐
│                    Panel Manager                         │
│  - Panel Registry                                        │
│  - Layout Management                                     │
│  - Data Router                                           │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼────────┐  ┌──────▼──────────┐
│  Panel Base    │  │  Widget System  │
│  - Lifecycle   │  │  - Gauge        │
│  - Data Bind   │  │  - Graph        │
│  - Events      │  │  - Indicator    │
└───────┬────────┘  │  - Button       │
        │           │  - Display      │
        │           └─────────────────┘
        │
┌───────┴────────────────────────────────────────┐
│                                                 │
│  Specialized Panels:                            │
│  - SonarPanel                                   │
│  - FireControlPanel                             │
│  - NavigationPanel                              │
│  - CommandPanel                                 │
│  - SensorPanel                                  │
└─────────────────────────────────────────────────┘
```

### Component Responsibilities

**PanelManager**
- Maintains registry of available panel types
- Handles panel instantiation and destruction
- Manages layout configurations and user preferences
- Routes data updates to active panels
- Coordinates panel visibility and z-ordering

**PanelBase**
- Abstract base class for all panels
- Provides lifecycle hooks (initialize, activate, deactivate, cleanup)
- Implements data binding infrastructure
- Handles common input events
- Manages child widgets

**WidgetSystem**
- Provides reusable UI components
- Handles widget rendering and updates
- Manages widget themes and styling
- Processes widget input events

**DataRouter**
- Subscribes to submarine system events
- Caches frequently accessed data
- Distributes updates to interested panels
- Handles data validation and error cases

## Components and Interfaces

### PanelManager

```gdscript
class_name PanelManager extends Node

# Panel registry
var _panel_types: Dictionary = {}  # String -> PanelType
var _active_panels: Dictionary = {}  # String -> Panel instance
var _layouts: Dictionary = {}  # String -> Layout config

# Data routing
var _data_router: DataRouter
var _update_queue: Array = []

func register_panel_type(panel_id: String, panel_script: Script) -> void
func create_panel(panel_id: String, config: Dictionary = {}) -> Panel
func destroy_panel(panel_id: String) -> void
func set_layout(layout_name: String) -> void
func save_layout(layout_name: String) -> void
func get_panel(panel_id: String) -> Panel
```

### PanelBase

```gdscript
class_name PanelBase extends Control

# Panel metadata
var panel_id: String
var panel_title: String
var is_active: bool = false
var update_frequency: float = 30.0  # Hz

# Data binding
var _data_bindings: Dictionary = {}  # String -> Callable
var _cached_data: Dictionary = {}

# Lifecycle
func _initialize(config: Dictionary) -> void
func _activate() -> void
func _deactivate() -> void
func _cleanup() -> void

# Data binding
func bind_data(key: String, callback: Callable) -> void
func unbind_data(key: String) -> void
func get_data(key: String) -> Variant

# Update
func _update_panel(delta: float) -> void
```

### Widget System

```gdscript
# Base widget
class_name Widget extends Control

var widget_id: String
var data_key: String
var theme_override: Dictionary = {}

func set_value(value: Variant) -> void
func get_value() -> Variant
func apply_theme(theme: Dictionary) -> void

# Specialized widgets
class_name GaugeWidget extends Widget
var min_value: float
var max_value: float
var current_value: float
var warning_threshold: float
var danger_threshold: float

class_name GraphWidget extends Widget
var history_size: int = 100
var data_points: Array = []
var y_min: float
var y_max: float

class_name IndicatorWidget extends Widget
var state: String  # "normal", "warning", "danger", "offline"
var label: String

class_name DisplayWidget extends Widget
var format_string: String
var unit: String
```

### DataRouter

```gdscript
class_name DataRouter extends Node

# Data sources
var submarine_physics: SubmarinePhysicsV2
var terrain_system: StreamingManager
var waypoint_system: WaypointNavigationSystem

# Subscribers
var _subscribers: Dictionary = {}  # String -> Array[Callable]

# Cache
var _data_cache: Dictionary = {}
var _cache_timestamps: Dictionary = {}
var _cache_ttl: float = 0.1  # seconds

func subscribe(data_key: String, callback: Callable) -> void
func unsubscribe(data_key: String, callback: Callable) -> void
func get_data(data_key: String) -> Variant
func _update_cache() -> void
func _notify_subscribers(data_key: String, value: Variant) -> void
```

## Data Models

### Panel Configuration

```gdscript
class_name PanelConfig extends Resource

@export var panel_id: String
@export var panel_type: String
@export var position: Vector2
@export var size: Vector2
@export var visible: bool = true
@export var update_frequency: float = 30.0
@export var custom_properties: Dictionary = {}
```

### Layout Configuration

```gdscript
class_name LayoutConfig extends Resource

@export var layout_name: String
@export var panels: Array[PanelConfig] = []
@export var screen_resolution: Vector2
```

### Sonar Data Model

```gdscript
class_name SonarData extends RefCounted

var scan_range: float  # meters
var scan_angle: float  # degrees (sector width)
var scan_resolution: int  # number of rays
var terrain_returns: Array[SonarReturn] = []
var contact_returns: Array[ContactReturn] = []
var timestamp: float

class SonarReturn:
    var bearing: float  # degrees
    var range: float  # meters
    var intensity: float  # 0.0 to 1.0
    var elevation: float  # meters (terrain height)

class ContactReturn:
    var bearing: float
    var range: float
    var contact_type: String  # "surface", "submarine", "unknown"
    var confidence: float  # 0.0 to 1.0
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Panel Registration Uniqueness

*For any* panel type registration, if a panel with the same ID already exists in the registry, the registration should either fail or replace the existing registration, never resulting in duplicate panel IDs.

**Validates: Requirements 1.1, 1.2**

### Property 2: Data Binding Consistency

*For any* data binding on a panel, when the bound data source updates, the panel should receive the update notification within one frame, ensuring UI consistency with system state.

**Validates: Requirements 9.4**

### Property 3: Panel Lifecycle Ordering

*For any* panel instance, the lifecycle methods should always execute in the correct order: initialize → activate → (update cycles) → deactivate → cleanup, with no state transitions skipped or repeated incorrectly.

**Validates: Requirements 1.3**

### Property 4: Sonar Range Accuracy

*For any* sonar scan, all terrain returns should have ranges less than or equal to the configured sonar range, and no terrain within range should be omitted from the scan results.

**Validates: Requirements 2.1, 11.6**

### Property 5: Sonar Bearing Accuracy

*For any* sonar return, the bearing value should be within the configured scan sector and normalized to 0-360 degrees, with proper handling of the 0/360 degree boundary.

**Validates: Requirements 2.3, 2.7**

### Property 6: Widget Value Bounds

*For any* gauge widget with defined min/max values, the displayed value should always be clamped to the valid range, preventing visual artifacts from out-of-bounds data.

**Validates: Requirements 8.3**

### Property 7: Update Frequency Compliance

*For any* panel with a configured update frequency, the actual update rate should not exceed the configured frequency by more than 10%, preventing excessive CPU usage.

**Validates: Requirements 10.1, 10.2**

### Property 8: Layout Persistence

*For any* user-customized layout, saving and then loading the layout should restore all panel positions, sizes, and visibility states exactly as they were before saving.

**Validates: Requirements 7.5**

### Property 9: Data Cache Freshness

*For any* cached data value, if the cache TTL has expired, the next data request should fetch fresh data from the source rather than returning stale cached data.

**Validates: Requirements 9.5**

### Property 10: Sensor Warning Thresholds

*For any* sensor widget with warning thresholds, when the sensor value crosses a threshold boundary, the widget should immediately update its visual state to reflect the new warning level.

**Validates: Requirements 6.7**

### Property 11: Sonar Terrain Integration

*For any* submarine position and sonar configuration, the sonar panel should query terrain data for all chunks within sonar range and convert elevation data to sonar returns with intensity proportional to terrain proximity.

**Validates: Requirements 11.1, 11.2, 11.3**

### Property 12: Panel Visibility Performance

*For any* hidden panel, the panel should not execute update cycles or render operations, conserving CPU and GPU resources.

**Validates: Requirements 10.6**

### Property 13: Navigation Waypoint Accuracy

*For any* active waypoint, the navigation panel should display bearing and distance that match the calculated values from the waypoint system within 0.1 degree and 1 meter tolerance.

**Validates: Requirements 4.3**

### Property 14: Fire Control Safety

*For any* weapon arming attempt, if safety conditions are not met (as defined by the fire control system), the weapon should remain in safe state and the panel should display the safety violation.

**Validates: Requirements 3.5**

### Property 15: Command Panel Status Consistency

*For any* submarine operational state change, the command panel should reflect the new state within one update cycle, ensuring operators have accurate situational awareness.

**Validates: Requirements 5.1, 5.4**

## Error Handling

### Panel Lifecycle Errors

- **Panel Registration Failure**: Log error and continue with existing panels
- **Panel Instantiation Failure**: Log error, notify user, fall back to default layout
- **Panel Activation Failure**: Deactivate panel, log error, mark panel as unavailable

### Data Integration Errors

- **Missing Data Source**: Display "NO DATA" indicator, log warning
- **Invalid Data Format**: Use last known good value, log error
- **Data Source Timeout**: Display "TIMEOUT" indicator, attempt reconnection
- **Cache Corruption**: Clear cache, fetch fresh data, log error

### Rendering Errors

- **Widget Rendering Failure**: Display error placeholder, log error, continue rendering other widgets
- **Theme Loading Failure**: Fall back to default theme, log warning
- **Layout Loading Failure**: Fall back to default layout, log error

### Sonar System Errors

- **Terrain Query Failure**: Display last known terrain data, log warning
- **Invalid Sonar Configuration**: Clamp to valid ranges, log warning
- **Sonar Processing Timeout**: Skip frame, log warning if persistent

### User Input Errors

- **Invalid Panel Configuration**: Validate and clamp to safe values, log warning
- **Layout Save Failure**: Notify user, log error, retain current layout
- **Keyboard Shortcut Conflict**: Use first registered handler, log warning

## Testing Strategy

### Unit Testing

**Panel System Tests**
- Test panel registration with valid and invalid configurations
- Test panel lifecycle state transitions
- Test data binding setup and teardown
- Test layout save/load with various configurations
- Test panel visibility toggling

**Widget Tests**
- Test gauge widget value clamping and threshold detection
- Test graph widget data point management and rendering
- Test indicator widget state transitions
- Test display widget formatting with various data types
- Test widget theme application

**Data Router Tests**
- Test subscription and unsubscription
- Test cache expiration and refresh
- Test data validation and error handling
- Test subscriber notification ordering

**Sonar System Tests**
- Test sonar range calculations
- Test bearing normalization and sector filtering
- Test terrain data conversion to sonar returns
- Test contact detection and tracking

### Property-Based Testing

All property tests should run with minimum 100 iterations and be tagged with their corresponding property number.

**Property Test 1: Panel Registration Uniqueness**
- Generate random panel registrations
- Verify no duplicate IDs in registry
- **Tag**: Feature: submarine-instrument-panels, Property 1

**Property Test 2: Data Binding Consistency**
- Generate random data updates
- Verify all bound panels receive updates
- **Tag**: Feature: submarine-instrument-panels, Property 2

**Property Test 3: Panel Lifecycle Ordering**
- Generate random panel lifecycle operations
- Verify correct state transition ordering
- **Tag**: Feature: submarine-instrument-panels, Property 3

**Property Test 4: Sonar Range Accuracy**
- Generate random sonar configurations and submarine positions
- Verify all returns within configured range
- **Tag**: Feature: submarine-instrument-panels, Property 4

**Property Test 5: Sonar Bearing Accuracy**
- Generate random sonar scans
- Verify bearing normalization and sector constraints
- **Tag**: Feature: submarine-instrument-panels, Property 5

**Property Test 6: Widget Value Bounds**
- Generate random gauge values including out-of-bounds
- Verify clamping to min/max
- **Tag**: Feature: submarine-instrument-panels, Property 6

**Property Test 7: Update Frequency Compliance**
- Generate random panel configurations
- Measure actual update rates
- Verify compliance with configured frequency
- **Tag**: Feature: submarine-instrument-panels, Property 7

**Property Test 8: Layout Persistence**
- Generate random layout configurations
- Save and load, verify exact restoration
- **Tag**: Feature: submarine-instrument-panels, Property 8

**Property Test 9: Data Cache Freshness**
- Generate random data requests with varying timing
- Verify cache expiration behavior
- **Tag**: Feature: submarine-instrument-panels, Property 9

**Property Test 10: Sensor Warning Thresholds**
- Generate random sensor values crossing thresholds
- Verify immediate visual state updates
- **Tag**: Feature: submarine-instrument-panels, Property 10

**Property Test 11: Sonar Terrain Integration**
- Generate random submarine positions
- Verify terrain queries and sonar return generation
- **Tag**: Feature: submarine-instrument-panels, Property 11

**Property Test 12: Panel Visibility Performance**
- Toggle panel visibility randomly
- Verify hidden panels skip updates
- **Tag**: Feature: submarine-instrument-panels, Property 12

**Property Test 13: Navigation Waypoint Accuracy**
- Generate random waypoints and submarine positions
- Verify bearing/distance calculations
- **Tag**: Feature: submarine-instrument-panels, Property 13

**Property Test 14: Fire Control Safety**
- Generate random weapon arming attempts with various safety states
- Verify safety enforcement
- **Tag**: Feature: submarine-instrument-panels, Property 14

**Property Test 15: Command Panel Status Consistency**
- Generate random submarine state changes
- Verify panel reflects changes within one cycle
- **Tag**: Feature: submarine-instrument-panels, Property 15

### Integration Testing

- Test panel system integration with submarine physics
- Test sonar panel integration with terrain streaming system
- Test navigation panel integration with waypoint system
- Test data router integration with all data sources
- Test layout persistence across game sessions
- Test performance with all panels active simultaneously

### Manual Testing

- Visual verification of panel rendering quality
- Usability testing of panel layouts
- Performance testing with various panel combinations
- Accessibility testing (contrast, readability, tooltips)
- Sonar display accuracy verification against known terrain
