# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Veiled Depths is a tactical submarine simulator built with Godot 4.5+ using GDScript. It features realistic submarine physics, FFT-based ocean simulation with buoyancy, and multiple camera views.

## Commands

**Run the game:**
```bash
godot --path . scenes/main.tscn
```

**Open in Godot Editor (compiles shaders, registers addon classes):**
```bash
godot project.godot
```

**Run tests:** Open project in Godot Editor, go to Gut panel at bottom, click "Run All". Tests are in `tests/unit/` and `tests/property/`.

**Run specific test file via CLI:**
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_submarine_physics.gd
```

## Architecture

### State Management
`SimulationState` (scripts/core/simulation_state.gd) is the single source of truth for all game state (submarine position, velocity, contacts, waypoints). All views query this rather than maintaining their own state.

### Core Systems (scripts/core/)
- `main.gd` - Entry point, initializes all systems
- `view_manager.gd` - Switches between tactical map, periscope, and external views
- `input_system.gd` - Routes all input to appropriate handlers
- `sonar_system.gd` - Contact detection and tracking
- `fog_of_war_system.gd` - Visibility system for contacts

### Physics (scripts/physics/)
- `submarine_physics.gd` - Submarine dynamics: propulsion along longitudinal axis, forward/sideways drag, wave buoyancy, steering torque with angular damping, depth control

### Views (scripts/views/)
Each view is independent and queries SimulationState:
- `tactical_map_view.gd` - 2D top-down map with waypoints, sliders, compass
- `periscope_view.gd` - First-person view with lens effects
- `external_view.gd` - Third-person orbit camera with free-cam mode
- `whole_map_view.gd` - Full map overview

### Rendering (scripts/rendering/)
- `ocean_renderer.gd` - FFT-based ocean surface (uses tessarakkt.oceanfft addon)
- `terrain_renderer.gd` - Heightmap terrain with LOD and collision
- `atmosphere_renderer.gd` - Day-night cycle, underwater effects
- `sealife_renderer.gd` - Ambient marine life

### AI (scripts/ai/)
- `ai_system.gd` - Manages AI agents
- `ai_agent.gd` - Individual AI behavior and navigation

## Key Addons

- `addons/tessarakkt.oceanfft/` - FFT ocean wave simulation with buoyancy
- `addons/gut/` - GUT testing framework for GDScript

## Coordinate System

-Z = North. Heading 0 = North, 90 = East, 180 = South, 270 = West.

## Testing

Tests use GUT framework (BDD-style). Test files are prefixed with `test_` and have `.gd` suffix. Configuration in `.gutconfig.json`.

## Documentation

- `docs/CURRENT_STATUS.md` - Development status and known issues
- `docs/KEYBOARD_CONTROLS.md` - Complete control reference
- `docs/archive/` - Completed feature documentation
- `docs/obsolete/` - Outdated approaches (historical reference)
