# Submarine Physics System Analysis

## Overview

The submarine physics system in Veiled Depths is implemented as a modular component-based architecture. The main physics controller (`SubmarinePhysicsV2`) orchestrates multiple subsystems to simulate realistic submarine behavior.

## System Architecture

```
SubmarinePhysicsV2 (Main Controller)
├── BuoyancySystem         - Archimedes principle, wave interaction
├── BallastSystem          - PID depth control, vertical force
├── DivePlaneSystem        - Pitch torque from control surfaces
├── RudderSystem           - Yaw torque for steering
├── PropulsionSystem       - Forward thrust generation
├── HullLiftSystem         - Vertical lift from pitched hull
├── HydrodynamicDrag       - Velocity-dependent drag forces
├── AppendageDragRegistry  - Extensible drag from deployed equipment
├── PhysicsValidator       - NaN detection, velocity clamping
└── CoordinateSystem       - Heading calculations (static utility)
```

## Data Flow

```
SimulationState (target_speed, target_heading, target_depth)
        │
        ▼
    InputSystem ──────────────────┐
        │                         │
        ▼                         ▼
SubmarinePhysicsV2.update_physics(delta)
        │
        ├─► BuoyancySystem.calculate_buoyancy_force()
        ├─► HydrodynamicDrag.calculate_drag_force()
        ├─► PropulsionSystem.calculate_propulsion_force()
        ├─► RudderSystem.calculate_steering_torque()
        ├─► DivePlaneSystem.calculate_dive_plane_torque()
        ├─► BallastSystem.calculate_ballast_force()
        ├─► HullLiftSystem.calculate_hull_lift_with_damping()
        │
        ▼
    RigidBody3D.apply_central_force() / apply_torque()
```

---

## Component Details

### 1. DivePlaneSystem ([dive_plane_system.gd](../scripts/physics/dive_plane_system.gd))

**Purpose:** Generates pitch torque based on depth error and forward speed.

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `bow_plane_effectiveness` | 0.4 | Bow plane contribution (40%) |
| `stern_plane_effectiveness` | 0.6 | Stern plane contribution (60%) |
| `max_plane_angle` | 15.0° | Maximum plane deflection |
| `min_effective_speed` | 1.0 m/s | Minimum speed for effectiveness |
| `max_effective_speed` | 5.0 m/s | Speed for full effectiveness |
| `torque_coefficient` | 1500.0 | Base torque multiplier |
| `depth_to_pitch_ratio` | 75.0 | Depth error to pitch angle ratio |
| `max_torque_limit` | 10,000,000 Nm | Hard limit to prevent saturation |

**Speed Effectiveness Curve:**
- Below 1 m/s: 0-10% effectiveness (linear)
- 1-5 m/s: 10-100% effectiveness (linear)
- Above 5 m/s: 100% effectiveness

**Calculation:**
```
depth_error = target_depth - current_depth
desired_pitch = -depth_error / depth_to_pitch_ratio
pitch_error = desired_pitch - current_pitch
plane_angle = clamp(pitch_error, ±15°)
torque = plane_angle × speed² × torque_coefficient × speed_effectiveness
```

---

### 2. BallastSystem ([ballast_system.gd](../scripts/physics/ballast_system.gd))

**Purpose:** PID-controlled vertical force for depth changes, especially at low speeds.

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `max_ballast_force` | 50,000,000 N | Maximum vertical force |
| `kp` | 0.5 | Proportional gain |
| `ki` | 0.01 | Integral gain |
| `kd` | 1.5 | Derivative gain |
| `dead_zone` | 0.5 m | Depth tolerance |
| `vertical_damping_coefficient` | 80,000 | Damping force coefficient |
| `max_depth_rate` | 6.0 m/s | Maximum descent/ascent rate |

**Behavior:**
- Within ±0.5m of target: No ballast force applied
- Integral term resets in dead zone to prevent wind-up
- Output smoothed via lerp at 10% rate per frame

---

### 3. BuoyancySystem ([buoyancy_system.gd](../scripts/physics/buoyancy_system.gd))

**Purpose:** Archimedes' principle buoyancy and wave interaction.

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `water_density` | 1025 kg/m³ | Seawater density |
| `submarine_volume` | 8000 m³ | Displacement volume |
| `wave_influence_depth` | 10 m | Depth where waves fade |
| `wave_spring_coefficient` | 80,000 N/m | Spring force for wave following |
| `wave_damping_coefficient` | 25,000 N·s/m | Damping for wave following |
| `hull_height` | 8 m | Hull height for submersion calc |

**Wave Influence:**
- 0-2m depth: Full wave influence
- 2-10m depth: Linear fade
- >10m depth: No wave influence

**Wave Torques:**
- Pitch torque: Applied proportional to forward velocity
- Roll torque: **Disabled** (always 0) - roll axis locked

---

### 4. RudderSystem ([rudder_system.gd](../scripts/physics/rudder_system.gd))

**Purpose:** Yaw torque for heading control.

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `torque_coefficient` | 250,000 N·m | Base torque multiplier |
| `max_rudder_angle` | 30° | Maximum rudder deflection |
| `max_turn_rate` | 3°/s | Maximum angular velocity |
| `min_steering_speed` | 0.5 m/s | Minimum for effective steering |
| `low_speed_effectiveness` | 0.2 | 20% effectiveness below min speed |

**Calculation:**
```
heading_error = shortest_path(target_heading - current_heading)
rudder_angle = clamp(heading_error / 2, ±30°)
torque = -speed_factor × rudder_angle × coefficient × effectiveness
```

---

### 5. HullLiftSystem ([hull_lift_system.gd](../scripts/physics/hull_lift_system.gd))

**Purpose:** Vertical lift from pitched hull moving through water.

**Physics:** `Lift = 0.5 × ρ × v² × A × CL × sin(α)`

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `hull_reference_area` | 150 m² | Projected hull cross-section |
| `hull_lift_coefficient` | 1.2 | Lift coefficient |
| `min_speed_for_lift` | 1.0 m/s | Minimum speed threshold |

**Behavior:**
- Nose up + forward motion = upward lift
- Nose down + forward motion = downward force
- Below 1 m/s: No lift generated

---

### 6. Roll Stabilization (in [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd#L320-L332))

**Two-component system:**
1. **Righting Torque:** `-current_roll × 8,000,000` (pushes back to level)
2. **Damping Torque:** `-roll_angular_velocity × 6,000,000` (prevents oscillation)

---

### 7. Pitch Stabilization (in [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd#L334-L338))

**Manual damping:** `-pitch_angular_velocity × 300,000`

---

### 8. Surface Leveling (in [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd#L353-L360))

When depth < 0.5m:
- Force pitch to 0° with strength proportional to surface proximity
- Reduce pitch angular velocity by 80%

---

### 9. Low-Speed Pitch Assist (in [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd#L340-L351))

When forward speed < 2 m/s:
- Applies trim tank simulation
- Desired pitch based on depth error: `-depth_error × 0.01` (max ±8.5°)
- Torque scaled by low-speed factor

---

## Identified Issues & Root Causes

### Issue 1: Pitch Only Works After Two Turns

**Symptom:** Submarine won't pitch up when ascending until after performing two turns.

**Root Cause Analysis:**

The dive plane torque is calculated using `effective_speed_for_planes` which is derived from:
```gdscript
var effective_speed_for_planes = max(abs(forward_speed), velocity.length() * 0.7)
```

However, dive plane effectiveness has a **minimum speed threshold of 1 m/s** and requires speed² for torque generation. The issue occurs because:

1. **Initial state:** Submarine may be stationary or slow
2. **Turning changes velocity direction:** After turns, the velocity magnitude increases due to momentum from rudder action
3. **Speed dependency:** `torque = plane_angle × speed² × coefficient × effectiveness`
   - At 0.5 m/s: effectiveness = 5%, speed² = 0.25 → minimal torque
   - At 2 m/s: effectiveness = 33%, speed² = 4 → 26× more torque

**Location:** [dive_plane_system.gd#L109-L117](../scripts/physics/dive_plane_system.gd#L109-L117)

---

### Issue 2: Roll Appearing Near Surface

**Symptom:** Submarine develops unwanted roll when near the surface.

**Root Cause Analysis:**

Multiple factors contribute:

1. **Wave-induced forces** are applied at surface (wave_influence > 0) but wave torque on roll axis should be disabled:
   ```gdscript
   result.torque.z = 0.0  // Always zero - roll is locked
   ```
   However, the **buoyancy spring force** may still cause asymmetric forces.

2. **Surface leveling only affects pitch** ([submarine_physics_v2.gd#L353-L360](../scripts/physics/submarine_physics_v2.gd#L353-L360)):
   ```gdscript
   if depth < 0.5:
       var level_torque = -current_pitch * 3000000.0 * surface_level_strength
       // No roll correction here!
   ```

3. **Hull lift direction issue:** The hull lift is applied in world UP direction, which is correct, but any slight roll means the submarine's local axes are misaligned with world axes, potentially causing feedback loops.

**Location:** [buoyancy_system.gd#L192-L222](../scripts/physics/buoyancy_system.gd#L192-L222), [submarine_physics_v2.gd#L353-L360](../scripts/physics/submarine_physics_v2.gd#L353-L360)

---

### Issue 3: Submarine Not Reverting to Level After Maneuver

**Symptom:** After depth changes or turns, submarine maintains slight roll instead of returning to level.

**Root Cause Analysis:**

1. **Roll stabilization coefficients may be insufficient** for the submarine's mass:
   - Righting coefficient: 8,000,000
   - Damping coefficient: 6,000,000
   - Submarine mass: 8,000 tons = 8,000,000 kg
   
   The moment of inertia for a cylinder about longitudinal axis ≈ `0.5 × m × r²`
   For a submarine ~10m diameter: `0.5 × 8,000,000 × 25 = 100,000,000 kg·m²`
   
   The righting torque may not be strong enough relative to inertia.

2. **No roll correction in surface leveling code** - only pitch is corrected at surface.

3. **Velocity alignment only affects horizontal velocity** ([submarine_physics_v2.gd#L610-L655](../scripts/physics/submarine_physics_v2.gd#L610-L655)):
   ```gdscript
   // Preserves vertical velocity but doesn't correct roll
   var vertical_velocity = velocity.y
   ```

**Location:** [submarine_physics_v2.gd#L320-L332](../scripts/physics/submarine_physics_v2.gd#L320-L332)

---

## Tasks to Fix

### High Priority

- [x] **TASK-001:** Increase roll righting coefficient to overcome inertia
  - File: [submarine_physics_v2.gd#L322](../scripts/physics/submarine_physics_v2.gd#L322)
  - Current: `8,000,000`
  - Suggested: `20,000,000` or higher
  - Rationale: Moment of inertia ~100M kg·m² requires stronger righting moment
  - **COMPLETED:** Increased to 25M Nm

- [x] **TASK-002:** Add roll correction to surface leveling code
  - File: [submarine_physics_v2.gd#L353-L360](../scripts/physics/submarine_physics_v2.gd#L353-L360)
  - Add roll zeroing similar to pitch zeroing when at surface
  - **COMPLETED:** Already implemented at L517-526

- [x] **TASK-003:** Implement low-speed pitch assist at higher speeds or remove minimum speed threshold for dive planes
  - File: [dive_plane_system.gd#L14](../scripts/physics/dive_plane_system.gd#L14)
  - Current: `min_effective_speed = 1.0`
  - Option A: Reduce to 0.3 m/s
  - Option B: Increase low-speed pitch assist threshold from 2.0 to 3.0 m/s
  - **COMPLETED:** Reduced to 0.3 m/s

### Medium Priority

- [x] **TASK-004:** Review dive plane torque coefficient scaling
  - File: [dive_plane_system.gd#L17](../scripts/physics/dive_plane_system.gd#L17)
  - Current: `torque_coefficient = 1500.0`
  - This seems very low compared to rudder (250,000) - may need increase
  - **COMPLETED:** Increased to 3000

- [x] **TASK-005:** Add roll velocity damping at surface
  - File: [submarine_physics_v2.gd#L353-L360](../scripts/physics/submarine_physics_v2.gd#L353-L360)
  - Similar to pitch velocity reduction: `submarine_body.angular_velocity.z *= surface_level_strength * 0.8`
  - **COMPLETED:** Already implemented at L524-526

- [ ] **TASK-006:** Verify buoyancy spring force is applied symmetrically
  - File: [buoyancy_system.gd#L99-L105](../scripts/physics/buoyancy_system.gd#L99-L105)
  - Ensure wave spring force doesn't create asymmetric roll moments

### Low Priority

- [ ] **TASK-007:** Add debug visualization for roll/pitch torques
  - File: [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd)
  - Would help diagnose physics issues in real-time

- [ ] **TASK-008:** Consider adding explicit roll lock as RigidBody3D constraint
  - Alternative to fighting roll with torques
  - May provide more stable behavior

---

## Physics Constants Summary

| System | Mass/Force | Coefficient | Unit |
|--------|-----------|-------------|------|
| Submarine Mass | 8,000 tons | - | kg × 1000 |
| Max Propulsion | 50,000,000 | - | N |
| Max Ballast | 50,000,000 | - | N |
| Max Dive Plane Torque | 10,000,000 | - | N·m |
| Rudder Torque Coef | 250,000 | - | N·m |
| Dive Plane Torque Coef | 1,500 | - | N·m |
| Roll Righting | 8,000,000 | - | N·m |
| Roll Damping | 6,000,000 | - | N·m·s |
| Pitch Damping | 300,000 | - | N·m·s |

---

## Coordinate System

- **Forward:** -Z axis (Godot convention)
- **Up:** +Y axis
- **Right:** +X axis
- **Heading:** 0° = North (-Z), 90° = East (+X), 180° = South (+Z), 270° = West (-X)
- **Pitch:** Positive = nose up (rotation around X axis)
- **Roll:** Positive = right side down (rotation around Z axis)
- **Depth:** Positive = below sea surface

---

---

## Area of Operation Parameter Consistency

### Global World Parameters (Reference)

From [earth_scale.gd](../scripts/utils/earth_scale.gd):

| Parameter | Value | Description |
|-----------|-------|-------------|
| `EARTH_CIRCUMFERENCE_EQUATOR` | 40,075,000 m | Full map width |
| `EARTH_CIRCUMFERENCE_MERIDIAN` | 40,008,000 m | Pole to pole |
| `FULL_MAP_WIDTH_METERS` | 40,075,000 m | Map X extent |
| `FULL_MAP_HEIGHT_METERS` | 20,004,000 m | Map Y extent (half meridian) |

### Global Elevation Range

From [tiled_elevation_provider.gd](../scripts/rendering/tiled_elevation_provider.gd#L10-L11):

| Parameter | Value | Description |
|-----------|-------|-------------|
| `MARIANA_TRENCH_DEPTH` | -10,994 m | Lowest point on Earth |
| `MOUNT_EVEREST_HEIGHT` | +8,849 m | Highest point on Earth |
| **Total Range** | 19,843 m | Full elevation span |

### Mission Area Parameters

The mission area is a subset of the global map with constrained elevation for gameplay.

| Location | MIN_ELEVATION | MAX_ELEVATION | Range |
|----------|---------------|---------------|-------|
| [sea_level_manager.gd#L25-26](../scripts/core/sea_level_manager.gd#L25-L26) | -200.0 m | +100.0 m | 300 m |
| [chunk_renderer.gd#L23-24](../scripts/rendering/chunk_renderer.gd#L23-L24) | -200.0 m | +100.0 m | 300 m |
| [collision_manager.gd#L379-380](../scripts/rendering/collision_manager.gd#L379-L380) | -200.0 m | +100.0 m | 300 m |

**✅ Consistent:** All mission area elevation ranges match (-200m to +100m).

### Submarine Operational Limits

| Location | MIN_DEPTH | MAX_DEPTH | Notes |
|----------|-----------|-----------|-------|
| [simulation_state.gd#L23-24](../scripts/core/simulation_state.gd#L23-L24) | 0.0 m | 400.0 m | Authoritative constants |
| [submarine_physics_v2.gd#L36](../scripts/physics/submarine_physics_v2.gd#L36) | - | 400.0 m | Default class |
| [submarine_metrics_panel.gd#L393](../scripts/ui/submarine_metrics_panel.gd#L393) | - | 400.0 m | UI display |
| [submarine_tuning_panel.gd#L15](../scripts/debug/submarine_tuning_panel.gd#L15) | 100.0 m | 800.0 m | Tuning range (adjustable) |

### ⚠️ CRITICAL MISMATCH: Terrain vs Submarine Depth

| System | Minimum | Maximum |
|--------|---------|---------|
| **Mission Area Terrain** | -200 m | +100 m |
| **Submarine MAX_DEPTH** | 0 m | 400 m |

**RESOLUTION:** Using global map approach - no depth limits enforced at mission area level. The global elevation map (40,075 km × 20,004 km) covers the entire Earth with full depth range (Mariana Trench to Mount Everest). Terrain depth limits are not a concern when using dynamic streaming from the global map.

### Sea Level Normalization

From [sea_level_manager.gd](../scripts/core/sea_level_manager.gd):

```
Mission Area:
  MIN_ELEVATION = -200m
  MAX_ELEVATION = +100m
  
  normalized = 0.0 → -200m (sea floor)
  normalized = 0.667 → 0m (sea level) ← DEFAULT
  normalized = 1.0 → +100m (mountain top)
  
Global (World Map):
  MARIANA = -10,994m
  EVEREST = +8,849m
  
  normalized = 0.0 → -10,994m
  normalized = 0.554 → 0m (sea level)
  normalized = 1.0 → +8,849m
```

**⚠️ ISSUE:** The normalized sea level value (0.667 in mission area, 0.554 globally) is different between systems. This could cause visual inconsistencies between tactical map and world map.

---

## Pitch and Roll Calculation Analysis

### How Godot Stores Rotation

Godot's `RigidBody3D.rotation` uses **Euler angles** in **XYZ order** (pitch, yaw, roll):

| Property | Axis | Convention | Range |
|----------|------|------------|-------|
| `rotation.x` | X-axis | Pitch (nose up/down) | -π to π |
| `rotation.y` | Y-axis | Yaw (heading) | -π to π |
| `rotation.z` | Z-axis | Roll (bank left/right) | -π to π |

### Current Pitch Reading (Physics Model)

**Location:** [submarine_physics_v2.gd#L303](../scripts/physics/submarine_physics_v2.gd#L303)

```gdscript
var current_pitch = submarine_body.rotation.x
```

**⚠️ ISSUE: This reads the WORLD-ALIGNED Euler angle, NOT the local pitch!**

When the submarine is heading North (rotation.y = 0), this works correctly:
- `rotation.x` = pitch angle in world frame = local pitch

But when the submarine turns (e.g., heading East, rotation.y = -π/2):
- `rotation.x` in world frame ≠ local pitch
- Euler angles get "gimbal locked" or mixed between axes

### Current Roll Reading (Physics Model)

**Location:** [submarine_physics_v2.gd#L331](../scripts/physics/submarine_physics_v2.gd#L331)

```gdscript
var current_roll = submarine_body.rotation.z  // Roll angle in radians
```

**⚠️ SAME ISSUE: This reads WORLD-ALIGNED roll, not local roll!**

When heading changes, what appears as "roll" in world coordinates may actually be a combination of local pitch and roll.

### How Torques Are Applied (Correct)

The torque application DOES use local axes correctly:

**Pitch torque:** [submarine_physics_v2.gd#L324](../scripts/physics/submarine_physics_v2.gd#L324)
```gdscript
var local_pitch_axis = submarine_body.global_transform.basis.x
submarine_body.apply_torque(local_pitch_axis * dive_plane_torque)
```

**Roll torque:** [submarine_physics_v2.gd#L330](../scripts/physics/submarine_physics_v2.gd#L330)
```gdscript
var local_roll_axis = submarine_body.global_transform.basis.z
submarine_body.apply_torque(local_roll_axis * (roll_righting_torque + roll_damping_torque))
```

### The Mismatch Problem

| Operation | Frame Used | Correct? |
|-----------|------------|----------|
| Read pitch angle | World (Euler `rotation.x`) | ❌ Wrong at non-zero headings |
| Read roll angle | World (Euler `rotation.z`) | ❌ Wrong at non-zero headings |
| Apply pitch torque | Local (`basis.x`) | ✅ Correct |
| Apply roll torque | Local (`basis.z`) | ✅ Correct |

**This explains why pitch only works after turning!**

When heading is 0° (North):
- World X-axis = Local pitch axis ✅
- `rotation.x` correctly represents pitch

After turning to 90° (East):
- World X-axis is now perpendicular to local pitch axis
- `rotation.x` no longer represents actual pitch
- Dive plane torque is applied to correct axis, but error calculation uses wrong angle

### Correct Way to Calculate Local Pitch/Roll

To get **true local pitch and roll** regardless of heading, extract angles from the basis:

```gdscript
# Get submarine's local axes
var basis = submarine_body.global_transform.basis
var forward = -basis.z  # Local forward (-Z)
var up = basis.y        # Local up (Y)
var right = basis.x     # Local right (X)

# Local pitch: angle between forward and horizontal plane
var local_pitch = asin(clamp(-forward.y, -1.0, 1.0))

# Local roll: angle between local up and world up, projected onto forward axis
var world_up = Vector3.UP
var local_up_horizontal = (up - forward * up.dot(forward)).normalized()
var world_up_horizontal = (world_up - forward * world_up.dot(forward)).normalized()
var local_roll = acos(clamp(local_up_horizontal.dot(world_up_horizontal), -1.0, 1.0))
# Determine roll sign
if right.dot(world_up) > 0:
    local_roll = -local_roll
```

### 3D Model vs Physics Model

| Component | Rotation Source | Notes |
|-----------|-----------------|-------|
| SubmarineModel (RigidBody3D) | `rotation` property | Physics-driven, Euler angles |
| UI Instrument Panel | `submarine_body.rotation.x` | Reads from physics model |
| Metrics Panel | `submarine_body.rotation.x/z` | Reads from physics model |
| External View Camera | Follows `submarine_body` position/rotation | Orbit camera, doesn't read angles |

All systems read from the same `submarine_body` RigidBody3D, so they're consistent - but all have the same Euler angle problem.

---

## Depth Calculation Analysis

### Depth Coordinate System

**Convention:** Depth is **positive going DOWN** from sea surface.

| Value | Meaning |
|-------|---------|
| depth = 0 | At sea surface |
| depth = 50 | 50 meters below surface |
| depth = -5 | 5 meters ABOVE surface (should not happen) |

### Godot World Coordinates

Godot uses Y-up coordinate system:
- **Y increases going UP**
- **Sea surface is at Y = 0** (plus wave height)

Therefore: `depth = sea_level - position.y`

### Depth Calculation Locations

#### 1. Physics System (Authoritative)

**Location:** [submarine_physics_v2.gd#L224-L237](../scripts/physics/submarine_physics_v2.gd#L224-L237)

```gdscript
var sea_surface_y = 0.0
if ocean_renderer:
    sea_surface_y = ocean_renderer.get_wave_height_3d(position)
else:
    var ocean_node = get_tree().root.get_node_or_null("Main/OceanRenderer")
    if ocean_node:
        sea_surface_y = ocean_node.global_position.y

var depth = sea_surface_y - position.y  # Depth = how far below surface
depth = max(0.0, depth)  # Clamp to surface - can't fly above water!
```

#### 2. get_submarine_state() Method

**Location:** [submarine_physics_v2.gd#L461-L462](../scripts/physics/submarine_physics_v2.gd#L461-L462)

```gdscript
var sea_level_meters = SeaLevelManager.get_sea_level_meters() if SeaLevelManager else 0.0
var depth = sea_level_meters - pos.y  # Depth is positive going down from sea level
```

**⚠️ INCONSISTENCY:** Uses `SeaLevelManager.get_sea_level_meters()` instead of `ocean_renderer.get_wave_height_3d()`

#### 3. Depth Control Monitor (Debug)

**Location:** [depth_control_monitor.gd#L85](../scripts/debug/depth_control_monitor.gd#L85)

```gdscript
var depth = -submarine_body.global_position.y
```

**⚠️ BUG:** Assumes sea level is at Y=0, ignores SeaLevelManager and waves!

#### 4. Simulation State

**Location:** [simulation_state.gd#L8](../scripts/core/simulation_state.gd#L8)

```gdscript
var submarine_depth: float = 0.0  # meters below sea surface (0 = surface, + = deeper)
```

Updated via `update_submarine_state()` from physics system.

### Depth in Different Systems

| System | Depth Source | Sea Level Reference |
|--------|--------------|---------------------|
| SubmarinePhysicsV2 (update_physics) | `sea_surface_y - position.y` | `ocean_renderer.get_wave_height_3d()` |
| SubmarinePhysicsV2 (get_submarine_state) | `sea_level_meters - pos.y` | `SeaLevelManager.get_sea_level_meters()` |
| SimulationState | Received from physics | N/A (passthrough) |
| TacticalMapView | `simulation_state.submarine_depth` | Reads from SimulationState |
| WholeMapView | `simulation_state.submarine_depth` | Reads from SimulationState |
| DepthControlMonitor | `-submarine_body.global_position.y` | **HARDCODED Y=0** ❌ |
| BuoyancySystem | Parameter passed in | Caller provides |
| BallastSystem | Parameter passed in | Caller provides |

### Sea Level Manager

**Location:** [sea_level_manager.gd](../scripts/core/sea_level_manager.gd)

Manages global sea level with two representations:

| Property | Range | Description |
|----------|-------|-------------|
| `current_sea_level_normalized` | 0.0 - 1.0 | Normalized for elevation textures |
| `current_sea_level_meters` | -200 to +100 | Actual meters (mission area range) |

**Conversion:**
```gdscript
const MIN_ELEVATION: float = -200.0   # Mission area minimum
const MAX_ELEVATION: float = 100.0    # Mission area maximum

# Normalized to meters:
meters = MIN_ELEVATION + normalized * (MAX_ELEVATION - MIN_ELEVATION)

# Default: normalized = 0.667 → meters = 0m
```

### Ocean Renderer Wave Height

The ocean surface is not flat - it has waves. The `ocean_renderer.get_wave_height_3d(position)` method returns the actual water surface height at a given XZ position.

For accurate depth:
```gdscript
var wave_height = ocean_renderer.get_wave_height_3d(submarine_position)
var depth = wave_height - submarine_position.y
```

### Depth Consistency Issues

| Issue | Location | Problem |
|-------|----------|---------|
| **TASK-009** | [depth_control_monitor.gd#L85](../scripts/debug/depth_control_monitor.gd#L85) | Uses `-position.y` instead of proper sea level reference |
| **TASK-010** | [submarine_physics_v2.gd#L461](../scripts/physics/submarine_physics_v2.gd#L461) | Uses `SeaLevelManager` while `update_physics` uses `ocean_renderer` |

### Tactical Map Depth Display

**Location:** [tactical_map_view.gd](../scripts/views/tactical_map_view.gd)

The tactical map displays depth from `simulation_state.submarine_depth`, which is updated by the main loop:

```gdscript
# In main.gd _process():
simulation_state.update_submarine_state(position, velocity, depth, heading, speed)
```

The depth value comes from `submarine_physics.get_submarine_state().depth`.

### World Map (WholeMapView)

**Location:** [whole_map_view.gd](../scripts/views/whole_map_view.gd)

Uses terrain elevation from world elevation map texture. Sea level is controlled by `SeaLevelManager.get_sea_level_normalized()`.

Colors terrain based on:
- Above sea level → green/brown (land)
- Below sea level → blue shades (water depth)

---

## Additional Tasks (from this analysis)

### High Priority

- [ ] **TASK-009:** Fix DepthControlMonitor to use proper sea level reference
  - File: [depth_control_monitor.gd#L85](../scripts/debug/depth_control_monitor.gd#L85)
  - Current: `var depth = -submarine_body.global_position.y`
  - Should use: `SeaLevelManager.get_sea_level_meters() - position.y`

- [ ] **TASK-010:** Unify sea level reference in SubmarinePhysicsV2
  - File: [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd)
  - `update_physics()` uses `ocean_renderer.get_wave_height_3d()`
  - `get_submarine_state()` uses `SeaLevelManager.get_sea_level_meters()`
  - Should be consistent (prefer wave height for accuracy)

- [ ] **TASK-011:** Fix pitch/roll angle reading to use local frame
  - File: [submarine_physics_v2.gd#L303](../scripts/physics/submarine_physics_v2.gd#L303), [#L331](../scripts/physics/submarine_physics_v2.gd#L331)
  - Current: `submarine_body.rotation.x` and `rotation.z`
  - Should: Extract local angles from basis vectors (see code above)
  - **This is likely the ROOT CAUSE of pitch-only-after-turn bug!**

### Medium Priority

- [ ] **TASK-012:** Update UI panels to use local pitch/roll
  - Files: [submarine_instrument_panel.gd](../scripts/ui/submarine_instrument_panel.gd), [submarine_metrics_panel.gd](../scripts/ui/submarine_metrics_panel.gd)
  - Ensure displayed pitch/roll matches actual submarine orientation

### Parameter Consistency Tasks

- [ ] **TASK-013:** Unify sea level normalized value between mission area and world map
  - Mission area: 0.667 for sea level at 0m
  - World map: 0.554 for sea level at 0m  
  - Consider using absolute meters instead of normalized values for sea level
  - File: [sea_level_manager.gd](../scripts/core/sea_level_manager.gd)

---

## Complete Task Summary

### Critical (Blocking Issues)

| Task | Issue | Impact |
|------|-------|--------|
| **TASK-011** | Pitch/roll reads world-frame Euler angles, not local | **ROOT CAUSE** of pitch-after-turn bug |

### High Priority

| Task | Issue | Impact |
|------|-------|--------|
| **TASK-001** | Roll righting coefficient too low | Sub doesn't return to level |
| **TASK-002** | No roll correction at surface | Roll persists near surface |
| **TASK-003** | High min speed threshold for dive planes | Pitch ineffective at low speeds |
| **TASK-009** | DepthControlMonitor uses hardcoded Y=0 | Debug tool shows wrong depth |
| **TASK-010** | Inconsistent sea level reference in physics | Potential depth calculation errors |

### Medium Priority

| Task | Issue | Impact |
|------|-------|--------|
| **TASK-004** | Dive plane torque coefficient very low | May need tuning |
| **TASK-005** | No roll velocity damping at surface | Roll oscillation at surface |
| **TASK-006** | Verify buoyancy force symmetry | Potential asymmetric roll source |
| **TASK-012** | UI panels use world-frame angles | Displays may be incorrect |
| **TASK-013** | Different normalized sea level values | Visual inconsistency |

### Low Priority

| Task | Issue | Impact |
|------|-------|--------|
| **TASK-007** | No debug visualization for torques | Harder to diagnose issues |
| **TASK-008** | Consider RigidBody3D roll axis lock | Alternative solution |

---

## Related Files

- [submarine_physics_v2.gd](../scripts/physics/submarine_physics_v2.gd) - Main physics controller
- [dive_plane_system.gd](../scripts/physics/dive_plane_system.gd) - Pitch control
- [ballast_system.gd](../scripts/physics/ballast_system.gd) - Depth control via buoyancy
- [buoyancy_system.gd](../scripts/physics/buoyancy_system.gd) - Archimedes & waves
- [rudder_system.gd](../scripts/physics/rudder_system.gd) - Yaw control
- [hull_lift_system.gd](../scripts/physics/hull_lift_system.gd) - Pitch-induced lift
- [propulsion_system.gd](../scripts/physics/propulsion_system.gd) - Thrust generation
- [hydrodynamic_drag.gd](../scripts/physics/hydrodynamic_drag.gd) - Drag forces
- [physics_validator.gd](../scripts/physics/physics_validator.gd) - Stability checks
- [coordinate_system.gd](../scripts/physics/coordinate_system.gd) - Heading utilities
- [simulation_state.gd](../scripts/core/simulation_state.gd) - Game state
- [input_system.gd](../scripts/core/input_system.gd) - Player controls
- [sea_level_manager.gd](../scripts/core/sea_level_manager.gd) - Sea level authority
- [tactical_map_view.gd](../scripts/views/tactical_map_view.gd) - 2D tactical display
- [whole_map_view.gd](../scripts/views/whole_map_view.gd) - Global map display
- [depth_control_monitor.gd](../scripts/debug/depth_control_monitor.gd) - Debug depth monitor
