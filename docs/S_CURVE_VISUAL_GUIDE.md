# S-Curve Depth Control - Visual Guide

## Depth vs Time Profile

```
Depth
  |
  |  Start ────┐
  |            │ Phase 1: Acceleration (smooth curve)
  |            │  - Dive planes gradually deflect
  |            │  - Pitch angle builds smoothly
  |            └─────┐
  |                  │ Phase 2: Cruise (linear)
  |                  │  - Constant dive plane angle
  |                  │  - Steady pitch (12°)
  |                  │  - Efficient depth change
  |                  └─────┐
  |                        │ Phase 3: Deceleration (smooth)
  |                        │  - Dive planes return to neutral
  |                        │  - Pitch reduces to 0°
  |                        └─────┐
  |                              │ Phase 4: Counter-Pitch
  |                              │  - Opposite pitch applied
  |                              │  - Arrests vertical velocity
  |  Target ──────────────────────┘
  |
  └─────────────────────────────────────> Time
```

## Dive Plane Angle vs Distance

```
Plane Angle
    15° │
        │     Phase 2 (Steady)
    12° │  ┌──────────────────┐
        │ ╱                    ╲
     8° │╱                      ╲
        │                        ╲
     4° │                         ╲        Phase 4 (Counter)
        │                          ╲     ╱
     0° ├───────────────────────────┴───┴────────
        │ Phase 1 (Accel)    Phase 3 (Decel)
    -4° │                                    ╲
        │                                     ╲
    -8° │                                      └─
        │
   -12° │
        └────────────────────────────────────────> Distance to Target
        100%    70%      30%     15%      0%
```

## Special Case: Surfacing from 100m

```
Depth (m)
    100 │ Start ────┐
        │           │ Phase 1: Target 25m
     80 │           │  - S-curve to intermediate waypoint
        │           │
     60 │           │ Phase 2: Cruise to 25m
        │           │
     40 │           │
        │           │ Phase 3: Arrive at 25m
     25 │ ──────────┘
        │           │ Phase 1 (restart): Gentle approach
     20 │           │  - Reduced pitch (3° max)
        │           │  - Slower ascent rate
     15 │           │
        │           │ Phase 3: Final approach
     10 │           │
        │           │ Phase 4: Surface entry
      5 │           │  - Counter-pitch for smooth arrival
        │           │  - Zero vertical velocity at surface
      0 │ ──────────┘ Target (Surface)
        └────────────────────────────────────────> Time
```

## Pitch Angle Timeline

```
Pitch (°)
  +15 │     Ascending (Nose Up)
      │         ╱─────────╲
  +12 │        ╱           ╲
      │       ╱             ╲
   +8 │      ╱               ╲
      │     ╱                 ╲
   +4 │    ╱                   ╲
      │   ╱                     ╲___
    0 ├──┘                          ╲___
      │                                  ╲___
   -4 │                                      ╲
      │                                       │
   -8 │                                       │ Counter-pitch
      │                                       │ arrests ascent
  -12 │
      └────────────────────────────────────────> Time
       P1    P2         P3            P4

      
Pitch (°)
    0 │──╲
      │   ╲___
   -4 │       ╲___
      │           ╲
   -8 │            ╲
      │             ╲
  -12 │              ╲───────╱
      │     Descending (Nose Down)
  -15 │                     ╱
      │                    ╱  Counter-pitch
      │                   │   arrests descent
      │                   │
      └────────────────────────────────────────> Time
       P1    P2         P3            P4
```

## Key Parameters

| Phase | Distance | Pitch Behavior | Dive Plane Action |
|-------|----------|----------------|-------------------|
| **Phase 1** | First 30% (max 50m) | Smooth ramp 0° → 12° | Gradual deflection |
| **Phase 2** | Middle 30% | Hold 12° | Full deflection |
| **Phase 3** | Next 30% (max 75m) | Ramp 12° → 0° | Return to neutral |
| **Phase 4** | Last 20m | Counter 0° → -5° | Reverse deflection |

## Benefits Visualization

```
OLD SYSTEM (Direct Proportional):
    Pitch oscillates, overshoots target
    
    ╱╲        ╱╲      ╱
   ╱  ╲      ╱  ╲    ╱
  ╱    ╲____╱    ╲__╱
  
  = Uncomfortable, inefficient


NEW SYSTEM (S-Curve):
    Smooth acceleration, perfect arrival
    
      _______________
     ╱               ╲
    ╱                 ╲___
   ╱                      
  
  = Comfortable, efficient, realistic
```

## Predictive Control

The system looks ahead 3 seconds to prevent overshoot:

```
              Current     Predicted
              Position    Position (3s ahead)
                 ↓            ↓
Depth: ─────────●────────────◯─────────[Target]
                 │            │
                 │← Velocity →│
                 
If predicted position overshoots target:
  → Reduce dive plane angle early
  → Apply counter-pitch sooner
```

## Surface Approach Detail

```
From 100m to Surface:
  
  100m ──┐ Standard S-curve
         │ Target: 25m waypoint
         │
   25m ──┤ Pause at waypoint
         │
         └─┐ Gentle S-curve
           │ Reduced angles (3° max)
           │ Slower approach
    0m ───┘ Smooth surface arrival
```
