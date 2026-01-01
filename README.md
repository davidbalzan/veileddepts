# Veiled Depths - Tactical Submarine Simulator

A realistic submarine simulation built in Godot 4, featuring tactical navigation, sonar systems, and underwater physics.

## Features

- **Realistic Physics**: Submarine movement with proper buoyancy, drag, and propulsion
- **Multiple Views**: Tactical map, periscope, and external camera views
- **Sonar System**: Passive/active sonar with contact detection and tracking
- **AI Patrols**: Enemy vessels with patrol routes and detection systems
- **Terrain System**: Real-world elevation data with underwater collision detection
- **Ocean Simulation**: Wave-based ocean surface with FFT rendering

## Quick Start

1. Open the project in Godot 4.2+
2. Run the main scene (`scenes/main.tscn`)
3. Use the tactical map (View 1) to navigate
4. Set waypoints by clicking on the map
5. Control speed with W/S keys
6. Switch views with Tab or number keys (1/2/3)

## Controls

### Tactical Map (View 1)
- **Left Click**: Set waypoint
- **Mouse Wheel**: Zoom in/out
- **W/S**: Increase/decrease speed
- **Q/E**: Change depth
- **Tab/1/2/3**: Switch views

### Periscope (View 2)
- **Right Mouse Drag**: Rotate periscope
- **Mouse Wheel**: Zoom

### External (View 3)
- **Camera follows submarine automatically**

## Documentation

- [Current Status](docs/CURRENT_STATUS.md) - Latest development status
- [Controls Reference](docs/KEYBOARD_CONTROLS.md) - Complete control guide
- [Terrain System](docs/TERRAIN_SYSTEM.md) - Terrain and collision system
- [Project Structure](docs/PROJECT_STRUCTURE.md) - Code organization
- [F1 Help](docs/F1_HELP_REFERENCE.md) - In-game help system

## Development

### Requirements
- Godot 4.2 or later
- OpenGL 3.3 compatible graphics card

### Project Structure
```
├── scenes/          # Godot scene files
├── scripts/         # GDScript source code
├── shaders/         # GLSL shader files
├── assets/          # 3D models, textures, audio
├── docs/            # Documentation
└── tests/           # Test scripts
```

### Running Tests
```bash
# Test terrain system
godot --headless --script test_terrain_spawn.gd

# Test submarine movement
godot --headless --script test_submarine_movement.gd
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Status

**Current Version**: Development Build
**Last Updated**: January 2026

The core simulation systems are complete and functional. Current focus is on polish and additional features.