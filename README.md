# Veiled Depths - Tactical Submarine Simulator

A realistic submarine simulation built in Godot 4, featuring tactical navigation, sonar systems, and underwater physics.

## Features

- **Realistic Physics**: Submarine movement with proper buoyancy, drag, and propulsion
- **Multiple Views**: Tactical map, periscope, and external camera views
- **Sonar System**: Passive/active sonar with contact detection and tracking
- **AI Patrols**: Enemy vessels with patrol routes and detection systems
- **Terrain System**: Real-world elevation data with underwater collision detection
- **Ocean Simulation**: Wave-based ocean surface with FFT rendering

## Installation

### Prerequisites
- Godot 4.2 or later ([download](https://godotengine.org/download))
- Git
- ~500 MB disk space for project files

### Setup Steps
```bash
# Clone the repository
git clone https://github.com/davidbalzan/veileddepts.git
cd veileddepts

# Open in Godot
godot .

# Or run directly
bash run_game.sh
```

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

## Gallery

Screenshots and gameplay videos coming soon! Visit the [project showcase](https://github.com/davidbalzan/veileddepts/discussions) for development updates.

## Documentation

- [Current Status](docs/CURRENT_STATUS.md) - Latest development status
- [Controls Reference](docs/KEYBOARD_CONTROLS.md) - Complete control guide
- [Terrain System](docs/TERRAIN_SYSTEM.md) - Terrain and collision system
- [Project Structure](docs/PROJECT_STRUCTURE.md) - Code organization
- [F1 Help](docs/F1_HELP_REFERENCE.md) - In-game help system

## Terrain Pipeline

The terrain system uses a multi-stage pipeline to generate realistic underwater environments:

### 1. **Heightmap Loading**
- Loads real-world elevation data from `World_elevation_map.png`
- Supports multiple geographic regions (Mediterranean, North Atlantic, Pacific, Caribbean, etc.)
- Resolution: 256x256 vertices, covering 2048m x 2048m areas
- Height range: -200m to +100m with sea level at 0m

### 2. **Micro-Detail Generation**
- Procedurally adds subtle height variations using Perlin noise
- Prevents completely flat terrain surfaces at submarine scale
- Typical variation: 0.1-0.5 meters over 8-meter distances
- Maintains realistic terrain appearance while improving gameplay

### 3. **Terrain Chunk Processing & LOD System**

The terrain uses a sophisticated Level-of-Detail (LOD) system for optimal performance:

**LOD Configuration:**
- **4 LOD levels** (0=highest detail, 3=lowest)
- **Base distance**: 100m for first LOD transition
- **Distance multiplier**: 2.0x between levels
  - LOD 0: 0-100m (full detail)
  - LOD 1: 100-200m (75% detail)
  - LOD 2: 200-400m (50% detail)  
  - LOD 3: 400m+ (25% detail)

**Per-Chunk Features:**
- Multiple mesh resolutions pre-generated
- HeightMapShape3D collision at appropriate LOD
- Shader-based parallax and normal mapping
- Neighbor stitching to prevent gaps
- Memory tracking per chunk (~1-4KB per LOD mesh)

**Dynamic Loading:**
- Chunks load/unload based on submarine distance
- Seamless LOD transitions without pop-in
- Automatic detail level adjustment based on zoom
- Background loading prevents frame drops

### 4. **Safe Spawn Positioning**
- Automatically finds underwater spawn locations
- Ensures 5m minimum clearance above sea floor
- Uses spiral search pattern for flexible positioning
- Validates depth requirements before spawning

### 5. **Dynamic Region Selection**
- Change terrain regions at runtime using predefined areas
- Custom regions supported via UV coordinates
- Includes 10+ world regions ready to use
- Region switching preserves all terrain features

### 6. **Map Synchronization Between Views**

All views share a centralized **SimulationState** that ensures consistent positioning:

**Synchronization Architecture:**
```
SimulationState (Single Source of Truth)
    ├── Submarine position, velocity, heading, depth
    ├── Contact positions and tracking data
    └── Mission waypoints and commands
         ↓
    ┌────┴────┬─────────┬──────────┐
    ▼         ▼         ▼          ▼
Tactical  Periscope  External  WholeMap
  Map       View      View       View
```

**View-Specific Rendering:**
- **Tactical Map (2D)**: Renders terrain texture at appropriate LOD level
  - Async texture generation based on zoom level
  - Higher zoom = higher detail terrain texture
  - Progressive LOD loading (3→2→1→0) prevents stuttering
  
- **Periscope View (3D)**: Camera positioned at submarine mast
  - Follows submarine position from SimulationState
  - Real-time terrain collision for line-of-sight
  
- **External View (3D)**: Orbiting camera around submarine
  - Position computed from SimulationState submarine location
  - Shows full 3D terrain with active LOD level

**State Updates:**
- Physics engine updates submarine state every frame
- SimulationState broadcasts changes to all views
- Views switch in <100ms with state preserved
- No position desync between view transitions

**For detailed technical documentation, see [Terrain System](docs/TERRAIN_SYSTEM.md)**

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

## Building & Deployment

### Development Build
```bash
# Run in editor
godot .
```

### Export for Distribution
```bash
# Export to Linux
godot --export-release "Linux/X11" build/linux/veileddepts

# Export to Windows
godot --export-release "Windows Desktop" build/windows/veileddepts.exe

# Export to macOS
godot --export-release "macOS" build/macos/veileddepts.dmg
```

Requires export presets to be configured in Godot editor first.

## Known Issues & Limitations

### Current Limitations
- Ocean LOD system can impact performance with very high view distances
- Multiplayer features not yet implemented
- Some terrain tiles may show seams at specific zoom levels
- Audio system is placeholder implementation

### Known Bugs
- Large files (>50MB) require Git LFS for GitHub pushes
- Periscope zoom can occasionally clip through objects
- AI patrol routes don't account for terrain obstacles in some cases

### Planned Features
- [ ] Multiplayer support (co-op submarine crew)
- [ ] More detailed damage simulation
- [ ] Expanded torpedo mechanics
- [ ] Custom mission editor
- [ ] Replay system

## Contributing

Contributions are welcome! Please feel free to:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Status

**Current Version**: Development Build
**Last Updated**: January 2026

The core simulation systems are complete and functional. Current focus is on polish and additional features.