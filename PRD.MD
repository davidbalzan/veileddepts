# Product Requirements Document (PRD): Tactical Submarine Simulator Game

## 1. Document Overview
### 1.1 Purpose
This PRD outlines the requirements for developing a tactical submarine simulator game. The game emphasizes strategic command-giving and map-based gameplay over detailed internal submarine rendering. It targets a prototype that can be iteratively developed using Godot engine on Mac M3 and Ubuntu workstations. The focus is on achieving graphics quality superior to Cold Waters (2017), with realistic sea simulation, periscope views, and air patrols. Low-poly substitutes will be used for ship models initially to facilitate rapid prototyping.

This document compiles all discussed details for import into the project as a reference. Development approach: "Vibe code" iteratively, starting from an MVP (Minimum Viable Product) prototype.

### 1.2 Scope
- **In Scope**: Tactical map interface, command system, periscope view, advanced sea/coastal/atmospheric simulation, sparse sealife, air patrols, basic AI for contacts (ships/planes).
- **Out of Scope (Initial Prototype)**: Full submarine internals, multiplayer, advanced campaigns, detailed weapon systems (add iteratively), high-fidelity audio beyond basics.
- **Target Platforms**: Desktop (Mac M3 via Metal, Ubuntu via Vulkan). Exportable standalone builds.
- **Development Time Estimate**: 1-2 weeks part-time for MVP prototype; iterative expansion.

### 1.3 Assumptions and Dependencies
- Developer has experience with enterprise software; will learn Godot basics.
- Use free/open-source tools and assets to avoid costs.
- Fork OpenSSN for realism shortcuts if needed (GPL-licensed).
- Low-poly models as placeholders; replace with better assets later.
- No strict deadlines; focus on fun, iterative "vibe coding."

## 2. Product Vision and Goals
### 2.1 Vision
Create an engaging tactical sub sim where players command a submarine via a strategic map, with seamless switches to a realistic periscope view for immersion. Emphasize simulation of ocean dynamics, coastal features, and threats like air patrols, surpassing Cold Waters in visual fidelity (e.g., dynamic waves, caustics, volumetric clouds).

### 2.2 Goals
- **Functional**: Deliver core tactical gameplay (commands, contacts, evasion) with polished visuals.
- **Technical**: Cross-compatible on Mac M3 and Ubuntu; high performance (60-120+ FPS at 1080p/4K).
- **User Experience**: Intuitive map/periscope toggle; realistic but not overwhelming sim elements.
- **Quality Targets**: Graphics better than Cold Waters – e.g., FFT waves, foam, caustics, SDFGI lighting.
- **Success Metrics**: Playable MVP with map commands propagating to 3D sim; positive dev feedback during iteration.

## 3. User Personas and Use Cases
### 3.1 Primary Persona
- **Enterprise Dev Gamer**: Adult software developer with tactical sim interest (e.g., inspired by Cold Waters). Uses Mac M3 for creative work, Ubuntu for heavy computation. Wants a project to "vibe code" through, learning game dev.

### 3.2 Key Use Cases
1. **Map-Based Commanding**: Player views top-down map, sets waypoints/speed/depth, monitors sonar contacts (ships/planes), issues evasion maneuvers.
2. **Periscope Observation**: Switch to 3D periscope for visual confirmation; raise/lower mast, zoom, observe waves/coasts/sealife.
3. **Threat Engagement**: Detect/simulate air patrols; respond with dives or countermeasures.
4. **Environmental Interaction**: Navigate realistic seas (storms/calm), avoid shallow coasts/floors, use thermal layers for stealth.

## 4. Functional Requirements
### 4.1 Core Features
- **Tactical Map (2D View)**:
  - Top-down overview with sub position, course, speed, depth controls.
  - Sonar/ESM/radar displays: Contacts as icons with arcs (pings, bearings).
  - Command inputs: Waypoints, speed/depth changes, torpedo launches (basic).
  - UI: CanvasLayer with buttons/sliders; toggle to periscope.
- **Periscope Experience (3D View)**:
  - Raiseable mast with Camera3D; zoom, rotation.
  - Lens effects: Distortion, chromatic aberration, vignette.
  - View switching: Seamless toggle via input actions.
- **Sea Simulation**:
  - Realistic waves: FFT-based (spectrum-driven, no tiling) with buoyancy for sub.
  - Foam/spray/whitecaps: Dynamic Jacobian foam, GPU particles.
  - Refraction/caustics: Screen-space + animated on floor/shallows.
  - Underwater effects: Subsurface scattering, depth fog (for dives).
- **Coastal and Sea Floor Features**:
  - Procedural terrain: Heightmaps with LOD, parallax occlusion.
  - Collidable floors/coasts: NoiseTexture3D for generation; sub collision detection.
- **Sparse Sealife**:
  - Fish schools: MultiMeshInstance3D or GPUParticles3D; culled by distance/foam.
  - Low density; adds immersion without performance hit.
- **Atmospheric Elements**:
  - Clouds: Volumetric, dynamic (ProceduralSkyMaterial3D).
  - Sky: Day/night cycles with god rays.
- **Air Patrols**:
  - AI planes/helos: NavigationAgent3D paths; dipping sonar, ASW attacks.
  - Detection: Radar/visual; particle contrails, shadows on waves.
- **Simulation Logic**:
  - Hydrodynamics: Depth/thermal layers, simplified physics (no full internals).
  - AI Contacts: State machines for patrol/search/attack.
  - Integration: Commands from map affect 3D world (e.g., sub movement sync).

### 4.2 Non-Functional Requirements
- **Performance**: 90+ FPS on M3 Max, 60+ on mid Ubuntu GPU; scale LOD/compute.
- **Graphics Quality**: Surpass Cold Waters:
  - Ocean: godot4-oceanfft (FFT waves, buoyancy, CDLOD).
  - Shaders: Gerstner for caustics/foam; underwater scattering.
  - Lighting: SDFGI/VoxelGI, SSR for reflections.
- **Audio**: Basic sonar pings, propeller noise, waves (Freesound.org).
- **Controls**: Keyboard/mouse; customizable inputs.
- **Export**: Standalone builds for testing on both platforms.

## 5. Technical Specifications
### 5.1 Engine and Tools
- **Game Engine**: Godot 4.6 beta 2 (download from godotengine.org/download/archive/4.6-beta2/).
  - Renderers: Metal (Mac M3), Vulkan (Ubuntu).
  - Languages: GDScript (primary; Python-like), C# optional.
  - Features: Node system for modularity; 2D/3D hybrid.
- **Assets and Addons**:
  - Ocean: Fork godot4-oceanfft (GitHub: tessarakkt/godot4-oceanfft); alt: 2Retr0/GodotOceanWaves.
  - Terrain: Terrain3D addon (free from Godot AssetLib).
  - Models: Low-poly ships/planes/subs from Kenney.nl, OpenGameArt, Sketchfab (glTF export).
  - Shaders: godotshaders.com (e.g., water-shader-3d-godot-4-3 for caustics).
  - Physics: Built-in Bullet for torpedoes/buoyancy.
- **Realism Shortcuts**: Fork OpenSSN (SourceForge; GPL C++/SDL) for sonar/hydro logic; port to Godot.
- **Development Setup**:
  - Install Godot on both workstations.
  - Use Blender for custom models (free; export glTF).
  - Version Control: Git for project tracking.

### 5.2 System Requirements
- **Development**: Mac M3 (native), Ubuntu (with Vulkan GPU).
- **Runtime**: Mid-range hardware; optimize for 1080p.

## 6. Development Plan
### 6.1 Step-by-Step Roadmap
Follow this iterative plan; "vibe code" by prototyping and refining.

| Step | Goal | Key Godot Features/Tools | Resources/Tutorials | Time Est. |
|------|------|--------------------------|---------------------|-----------|
| **1. Setup & Basics** | Install engine, basic 3D scene with sub movement. | Download Godot 4.6 beta 2. KinematicBody3D for sub. | Official "Your First 3D Game" docs. Test cross-platform. | 1-2 days |
| **2. Tactical Map** | 2D map with commands, contacts, sonar. | Control nodes, CanvasLayer UI, Line2D for arcs. | Godot 2D UI docs; Cold Waters YouTube refs. Port OpenSSN if forking. | 3-4 days |
| **3. Periscope View** | 3D camera on mast, zoom, effects. | Camera3D, Raycast for depth, shaders for distortion. | "Godot Ocean Waves" YouTube; underwater shader tutorials. | 2-3 days |
| **4. Sea/Coastal/Floor** | High-fidelity ocean, terrain. | ProceduralMesh (LOD), Terrain3D addon, godot4-oceanfft. | "Making an Ocean in Godot" series; Gerstner shader. | 3-5 days |
| **5. Atmosphere & Patrols** | Clouds/sky, AI planes. | Environment3D, NavigationAgent3D, state machines. | Godot sky docs; simple AI tutorials. | 2 days |
| **6. Polish & Integrate** | View switching, audio, exports. | Scene instancing, AnimationPlayer. | Thalassa sub prototype refs. | 2 days |

### 6.2 Iteration and Testing
- **MVP Milestone**: Playable map + periscope with basic sea sim.
- **Testing**: Run on both machines; export Web/Desktop for quick tests.
- **Enhancements**: Add weapons, storms, campaigns post-MVP.
- **Community Support**: Godot Discord/Reddit for shaders/help.

## 7. Risks and Mitigations
- **Risk**: Performance on Ubuntu – Mitigate: Optimize LOD, test early.
- **Risk**: Learning Curve – Mitigate: Start with official tutorials; use pre-built assets.
- **Risk**: Asset Quality – Mitigate: Low-poly placeholders; upgrade later.
- **Risk**: Scope Creep – Mitigate: Stick to MVP; iterate based on "vibe."

## 8. Appendices
### 8.1 Graphics Comparison Targets
| Feature | Cold Waters Level | Target Level |
|---------|-------------------|--------------|
| Ocean Waves | Simple sinusoidal | FFT-based, realistic spectrum. |
| Foam/Spray | Minimal | Dynamic foam, particle spray. |
| Caustics | Basic | Animated, projected on floor. |
| Sealife | None | Sparse GPUParticles3D fish. |
| Clouds | Basic | Volumetric, dynamic. |
| Lighting | Static | SDFGI + SSR for dynamics. |

### 8.2 References
- Godot Docs: godotengine.org.
- Assets: Kenney.nl, Freesound.org, Sketchfab.
- Inspirations: Cold Waters gameplay (YouTube), Jane's Fighting Ships (for tactics).
- Demos: godot4-oceanfft GitHub repo.

This PRD serves as a living document; update as development progresses. Import into project as Markdown or PDF for reference. Dive into coding! 🚀