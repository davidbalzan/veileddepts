# Design Document

## Overview

This design document outlines improvements to the visual fidelity of the tactical submarine simulator. The improvements focus on seven key areas: foam/bubble system realism, periscope model stability, chromatic aberration refinement, periscope HUD information display, water transition effects, orbit camera underwater effects, and orbit camera zoom controls.

The design leverages Godot's GPUParticles3D system for foam effects, shader-based post-processing for lens effects, and camera environment switching for underwater rendering.

## Architecture

### System Components

1. **SubmarineWake System** (scripts/rendering/submarine_wake.gd)
   - Manages all foam and bubble particle emitters
   - Controls particle lifetimes and fade curves
   - Handles trail persistence and dissipation

2. **PeriscopeView System** (scripts/views/periscope_view.gd)
   - Manages periscope camera positioning and smoothing
   - Applies lens shader effects
   - Handles HUD overlay rendering
   - Controls water transition effects

3. **Periscope Lens Shader** (shaders/periscope_lens.gdshader)
   - Applies barrel distortion
   - Implements chromatic aberration with radial gradient
   - Renders vignette effect

4. **ExternalView System** (scripts/views/external_view.gd)
   - Manages orbit camera positioning
   - Handles zoom controls
   - Applies underwater environment effects

5. **Water Transition Effect System** (new component)
   - Manages water droplet particles on lens
   - Controls water sheet animation
   - Handles surface crossing detection

## Components and Interfaces

### 1. Foam System Improvements

**Modified Component:** `SubmarineWake`

**Changes:**
- Reduce bubble particle lifetime from current values to maximum 3 seconds
- Implement alpha curve for trail fade-out over time
- Reduce particle scale for more detailed foam appearance
- Add scale curve to simulate bubble growth and dissipation

**Interface:**
```gdscript
class SubmarineWake extends Node3D:
    # Configuration
    @export var bubble_max_lifetime: float = 3.0
    @export var trail_fade_curve: Curve
    @export var particle_scale_multiplier: float = 0.5
    
    # Methods
    func _configure_bubble_lifetime() -> void
    func _apply_trail_fade_curve() -> void
    func _adjust_particle_scales() -> void
```

### 2. Periscope Model Stability

**Modified Component:** `PeriscopeView`

**Changes:**
- Increase camera smoothing factor for position interpolation
- Implement separate smoothing for submarine model visibility
- Add frame-rate independent interpolation
- Use physics interpolation for submarine body reference

**Interface:**
```gdscript
class PeriscopeView extends Node3D:
    # Smoothing parameters
    const CAMERA_POSITION_SMOOTHING: float = 0.15
    const CAMERA_ROTATION_SMOOTHING: float = 0.15
    const MODEL_VISIBILITY_SMOOTHING: float = 0.2
    
    # Smoothed state
    var smooth_position: Vector3
    var smooth_rotation: Vector3
    var smooth_model_offset: Vector3
    
    # Methods
    func _apply_camera_smoothing(delta: float) -> void
    func _smooth_submarine_model_visibility(delta: float) -> void
```

### 3. Chromatic Aberration Refinement

**Modified Component:** `periscope_lens.gdshader`

**Changes:**
- Implement radial distance-based aberration strength
- Reduce aberration at center (0.0 at exact center)
- Increase aberration toward edges (full strength at radius 1.0)
- Use smooth interpolation curve for natural falloff

**Interface:**
```glsl
// Shader uniforms
uniform float chromatic_aberration_max : hint_range(0.0, 0.05) = 0.015;
uniform float chromatic_aberration_center_radius : hint_range(0.0, 0.5) = 0.2;

// Functions
float calculate_radial_aberration(vec2 uv, float max_aberration, float center_radius);
vec3 apply_chromatic_aberration_radial(vec2 uv, sampler2D tex);
```

### 4. Periscope HUD Information

**Modified Component:** `PeriscopeView`

**New Component:** `PeriscopeHUD` (Control node)

**Changes:**
- Add telemetry display panel
- Show speed, depth, heading in real-time
- Use naval-style typography and layout
- Position HUD elements for minimal obstruction

**Interface:**
```gdscript
class PeriscopeHUD extends Control:
    # Display elements
    var speed_label: Label
    var depth_label: Label
    var heading_label: Label
    var telemetry_panel: PanelContainer
    
    # Data sources
    var simulation_state: SimulationState
    
    # Methods
    func update_telemetry() -> void
    func format_speed(speed_mps: float) -> String  # Returns "XX.X kts"
    func format_depth(depth_m: float) -> String    # Returns "XXX m"
    func format_heading(heading_deg: float) -> String  # Returns "XXX°"
    
    # Styling
    func _apply_naval_styling() -> void
```

### 5. Water Transition Effects

**New Component:** `WaterTransitionEffect`

**Implementation:**
- Particle system for water droplets on lens
- Shader-based water sheet effect
- Surface crossing detection using ocean wave height
- Droplet evaporation over time

**Interface:**
```gdscript
class WaterTransitionEffect extends Node3D:
    # Components
    var droplet_particles: GPUParticles3D
    var water_sheet_overlay: ColorRect
    var water_sheet_shader: ShaderMaterial
    
    # State
    var is_submerged: bool = false
    var transition_time: float = 0.0
    var active_droplets: Array[Droplet]
    
    # Configuration
    @export var droplet_count: int = 20
    @export var droplet_lifetime: float = 5.0
    @export var sheet_duration: float = 1.5
    @export var evaporation_rate: float = 0.2
    
    # Methods
    func detect_surface_crossing() -> bool
    func trigger_emergence_effect() -> void
    func trigger_submersion_effect() -> void
    func update_droplets(delta: float) -> void
    func animate_water_sheet(delta: float) -> void
```

**Droplet Data Structure:**
```gdscript
class Droplet:
    var position: Vector2  # Screen space position
    var size: float
    var lifetime_remaining: float
    var velocity: Vector2  # For sliding down lens
```

### 6. Orbit Camera Underwater Effects

**Modified Component:** `ExternalView`

**Changes:**
- Add underwater environment detection
- Apply depth-based fog and color grading
- Implement smooth transition at water surface
- Add caustics or god rays for shallow depths

**Interface:**
```gdscript
class ExternalView extends Node3D:
    # Underwater rendering
    var underwater_environment: Environment
    var is_underwater: bool = false
    var underwater_transition_progress: float = 0.0
    
    # Configuration
    @export var underwater_fog_density: float = 0.08
    @export var underwater_color: Color = Color(0.1, 0.3, 0.4)
    @export var depth_attenuation_factor: float = 0.02
    @export var transition_speed: float = 2.0
    
    # Methods
    func detect_camera_underwater() -> bool
    func apply_underwater_environment() -> void
    func update_depth_effects(depth: float) -> void
    func transition_underwater_effects(delta: float) -> void
```

### 7. Orbit Camera Zoom Control

**Modified Component:** `ExternalView`

**Changes:**
- Add keyboard input handling for +/- keys
- Implement smooth zoom interpolation
- Maintain existing mouse wheel zoom functionality
- Add zoom speed configuration

**Interface:**
```gdscript
class ExternalView extends Node3D:
    # Zoom configuration
    @export var keyboard_zoom_speed: float = 10.0  # meters per second
    @export var zoom_smoothing: float = 0.1
    
    # State
    var target_distance: float
    var current_distance: float
    
    # Methods
    func handle_keyboard_zoom_input(delta: float) -> void
    func smooth_zoom_to_target(delta: float) -> void
```

## Data Models

### Foam Particle Configuration

```gdscript
class FoamParticleConfig:
    var lifetime: float = 2.5
    var scale_min: float = 0.02
    var scale_max: float = 0.06
    var alpha_curve: Curve
    var scale_curve: Curve
    var emission_rate: float = 50.0
```

### Water Droplet

```gdscript
class WaterDroplet:
    var screen_position: Vector2
    var size: float
    var opacity: float
    var slide_velocity: Vector2
    var lifetime: float
    var evaporation_rate: float
```

### Underwater Environment Config

```gdscript
class UnderwaterEnvironmentConfig:
    var fog_color: Color = Color(0.1, 0.3, 0.4)
    var fog_density_base: float = 0.05
    var fog_density_per_meter: float = 0.001
    var ambient_light_color: Color = Color(0.2, 0.4, 0.5)
    var ambient_light_energy: float = 0.3
    var visibility_range_base: float = 100.0
    var visibility_range_per_meter: float = -2.0
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Bubble Lifetime Constraint

*For any* bubble particle generated by the foam system, its lifetime shall not exceed 3 seconds from creation to removal.

**Validates: Requirements 1.1**

### Property 2: Trail Fade Monotonicity

*For any* trail particle over its lifetime, the opacity value shall monotonically decrease from initial value to zero.

**Validates: Requirements 1.2**

### Property 3: Particle Scale Reduction

*For any* foam particle configuration, the maximum particle scale after adjustment shall be less than or equal to 50% of the original maximum scale.

**Validates: Requirements 1.3**

### Property 4: Camera Position Smoothing

*For any* two consecutive frames in periscope view, the camera position change shall be smoothly interpolated with no discontinuous jumps greater than 0.1 meters.

**Validates: Requirements 2.1, 2.2**

### Property 5: Chromatic Aberration Radial Gradient

*For any* pixel in the periscope view, the chromatic aberration strength shall increase monotonically with distance from the screen center, with zero aberration at the exact center.

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 6: HUD Telemetry Update Rate

*For any* frame in periscope view, the HUD telemetry data (speed, depth, heading) shall reflect simulation state values that are no more than one frame old.

**Validates: Requirements 4.1, 4.2, 4.3, 4.4**

### Property 7: Water Transition Timing

*For any* surface crossing event (emergence or submersion), the water transition effect shall complete within 2 seconds of the crossing.

**Validates: Requirements 5.5**

### Property 8: Droplet Evaporation

*For any* water droplet on the lens, its opacity shall decrease over time until it reaches zero and is removed from the simulation.

**Validates: Requirements 5.3**

### Property 9: Underwater Effect Depth Correlation

*For any* orbit camera position underwater, the fog density and visibility range shall correlate with depth such that deeper positions have higher fog density and lower visibility.

**Validates: Requirements 6.2, 6.5**

### Property 10: Zoom Distance Bounds

*For any* zoom input (keyboard or mouse wheel), the resulting camera distance shall remain within the configured minimum and maximum distance bounds.

**Validates: Requirements 7.4, 7.5**

### Property 11: Zoom Smoothing Continuity

*For any* zoom operation, the camera distance shall change smoothly without discontinuous jumps, maintaining velocity continuity.

**Validates: Requirements 7.3, 7.6**

## Error Handling

### Foam System Errors

1. **Missing Ocean Renderer**
   - Fallback: Use fixed sea level (y=0) for surface detection
   - Log warning and continue with reduced functionality

2. **Particle System Initialization Failure**
   - Fallback: Disable foam effects for that emitter
   - Log error and continue without visual effects

### Periscope View Errors

1. **Shader Compilation Failure**
   - Fallback: Disable lens effects, use raw camera view
   - Log error and notify user

2. **HUD Element Creation Failure**
   - Fallback: Continue without HUD, core functionality intact
   - Log error

3. **Water Transition Effect Failure**
   - Fallback: Instant transition without effects
   - Log warning

### Orbit Camera Errors

1. **Environment Creation Failure**
   - Fallback: Use default world environment
   - Log warning

2. **Underwater Detection Failure**
   - Fallback: Assume surface mode
   - Log warning and continue

## Testing Strategy

### Unit Tests

Unit tests will verify specific examples and edge cases:

1. **Foam System Tests**
   - Test bubble lifetime clamping at boundary values (0s, 3s, 5s)
   - Test particle scale reduction calculation
   - Test alpha curve application

2. **Periscope View Tests**
   - Test camera smoothing with various delta values
   - Test HUD formatting functions (speed, depth, heading)
   - Test surface crossing detection at boundary conditions

3. **Shader Tests**
   - Test chromatic aberration calculation at center (should be 0)
   - Test chromatic aberration at edges (should be maximum)
   - Test radial distance calculation

4. **Orbit Camera Tests**
   - Test zoom distance clamping
   - Test underwater detection at surface boundary
   - Test keyboard input handling

### Property-Based Tests

Property-based tests will verify universal properties across all inputs using Gut's property testing capabilities:

**Configuration:** Each property test shall run a minimum of 100 iterations with randomized inputs.

**Test 1: Bubble Lifetime Property**
- **Property 1: Bubble Lifetime Constraint**
- **Validates: Requirements 1.1**
- Generate random bubble configurations
- Verify lifetime ≤ 3.0 seconds for all configurations

**Test 2: Trail Fade Monotonicity Property**
- **Property 2: Trail Fade Monotonicity**
- **Validates: Requirements 1.2**
- Generate random time samples across particle lifetime
- Verify opacity(t1) ≥ opacity(t2) for all t1 < t2

**Test 3: Particle Scale Property**
- **Property 3: Particle Scale Reduction**
- **Validates: Requirements 1.3**
- Generate random original scale values
- Verify adjusted_scale ≤ 0.5 * original_scale

**Test 4: Camera Smoothing Property**
- **Property 4: Camera Position Smoothing**
- **Validates: Requirements 2.1, 2.2**
- Generate random camera positions and targets
- Verify position changes are smooth (no jumps > 0.1m)

**Test 5: Chromatic Aberration Radial Property**
- **Property 5: Chromatic Aberration Radial Gradient**
- **Validates: Requirements 3.1, 3.2, 3.3**
- Generate random screen positions
- Verify aberration(center) = 0 and aberration increases with radius

**Test 6: HUD Update Property**
- **Property 6: HUD Telemetry Update Rate**
- **Validates: Requirements 4.1, 4.2, 4.3, 4.4**
- Generate random simulation states
- Verify HUD displays match simulation state within one frame

**Test 7: Water Transition Timing Property**
- **Property 7: Water Transition Timing**
- **Validates: Requirements 5.5**
- Generate random surface crossing events
- Verify transition completes within 2 seconds

**Test 8: Droplet Evaporation Property**
- **Property 8: Droplet Evaporation**
- **Validates: Requirements 5.3**
- Generate random droplets with various lifetimes
- Verify opacity decreases monotonically to zero

**Test 9: Underwater Depth Correlation Property**
- **Property 9: Underwater Effect Depth Correlation**
- **Validates: Requirements 6.2, 6.5**
- Generate random underwater depths
- Verify fog_density(d1) < fog_density(d2) for d1 < d2

**Test 10: Zoom Bounds Property**
- **Property 10: Zoom Distance Bounds**
- **Validates: Requirements 7.4, 7.5**
- Generate random zoom inputs
- Verify MIN_DISTANCE ≤ result_distance ≤ MAX_DISTANCE

**Test 11: Zoom Smoothing Property**
- **Property 11: Zoom Smoothing Continuity**
- **Validates: Requirements 7.3, 7.6**
- Generate random zoom sequences
- Verify distance changes are continuous (no velocity discontinuities)

### Integration Tests

1. Test foam system with submarine movement at various speeds
2. Test periscope view with submarine at various depths
3. Test water transition effects during surface crossing
4. Test orbit camera underwater effects at various depths
5. Test zoom controls with all input methods

### Manual Testing

1. Visual inspection of foam realism and trail fade
2. Periscope model stability during submarine maneuvers
3. Chromatic aberration appearance at center vs edges
4. HUD readability and accuracy
5. Water transition effect realism
6. Orbit camera underwater appearance
7. Zoom control responsiveness
