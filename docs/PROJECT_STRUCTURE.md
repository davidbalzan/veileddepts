# Tactical Submarine Simulator - Project Structure

## Directory Layout

```
tactical-submarine-simulator/
├── addons/                    # Third-party addons
│   └── gut/                   # Gut testing framework
├── assets/                    # Game assets
│   ├── audio/                 # Sound effects and music
│   ├── models/                # 3D models
│   └── textures/              # Textures and materials
├── scenes/                    # Godot scene files (.tscn)
│   └── main.tscn              # Main game scene
├── scripts/                   # GDScript source files
│   ├── ai/                    # AI system scripts
│   ├── core/                  # Core game systems
│   │   └── main.gd            # Main entry point
│   ├── physics/               # Physics and submarine dynamics
│   ├── rendering/             # Rendering systems (ocean, terrain, atmosphere)
│   └── views/                 # View management (tactical, periscope, external)
├── tests/                     # Test files
│   ├── property/              # Property-based tests
│   └── unit/                  # Unit tests
│       └── test_example.gd    # Example test
├── .gutconfig.json            # Gut testing configuration
├── icon.svg                   # Project icon
└── project.godot              # Godot project configuration
```

## Input Mappings

### View Switching
- **Tab**: Cycle through views
- **1**: Switch to Tactical Map
- **2**: Switch to Periscope View
- **3**: Switch to External View

### Submarine Controls (Tactical Map)
- **W**: Increase speed
- **S**: Decrease speed
- **Q**: Increase depth (dive)
- **E**: Decrease depth (surface)
- **Left Click**: Place waypoint

### Camera Controls
- **Right Mouse Button**: Rotate camera (periscope/external)
- **Shift + Right Mouse Button**: Tilt camera (external view)
- **Mouse Wheel Up**: Zoom in
- **Mouse Wheel Down**: Zoom out
- **F**: Toggle free camera mode (external view)

## Rendering Configuration

- **Renderer**: Forward+ (Vulkan on Ubuntu, Metal on Mac)
- **MSAA**: 2x for 3D rendering
- **Resolution**: 1920x1080 (windowed fullscreen)

## Testing Framework

The project uses [Gut](https://github.com/bitwes/Gut) for unit and property-based testing.

### Running Tests

1. Open the project in Godot Editor
2. Go to the "Gut" panel (bottom of editor)
3. Click "Run All" to execute all tests

### Test Organization

- **Unit Tests** (`tests/unit/`): Test specific examples and edge cases
- **Property Tests** (`tests/property/`): Test universal properties across randomized inputs

Each property test should:
- Run minimum 100 iterations
- Reference the design document property number
- Use tag format: `# Feature: tactical-submarine-simulator, Property {N}: {description}`

## Platform Support

- **Mac M3**: Metal rendering backend, target 90 FPS @ 1080p
- **Ubuntu**: Vulkan rendering backend, target 60 FPS @ 1080p

## Next Steps

Refer to `.kiro/specs/tactical-submarine-simulator/tasks.md` for the implementation plan.
