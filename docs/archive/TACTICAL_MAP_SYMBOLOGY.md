# Tactical Map Symbology Guide

## Your Submarine

- **Green Triangle**: Your submarine
  - Points in the direction the submarine is **currently facing**
  - This is your **actual heading** (where the bow points)

## Navigation

- **Cyan Circle**: Your target waypoint
  - Where you clicked on the map
  - The submarine will turn and move toward this point

- **Yellow Dotted Line**: Course line
  - Shows the path from your submarine to the waypoint
  - This is your **intended course**, not your current heading
  - The submarine will gradually turn to align with this line

## Contacts (Enemy/Neutral Units)

- **Yellow Arc**: Sonar bearing indicator
  - Shows the approximate direction of a detected contact
  - The arc represents bearing uncertainty (±15°)
  - Appears when sonar detects a target

- **Contact Icons**:
  - **Red Circle**: Unidentified aircraft
  - **Orange Circle**: Unidentified surface ship
  - **Cyan Circle**: Identified contact (friend or confirmed enemy)

## Compass (Top Right)

- **Red "N"**: North indicator
- **Green Arrow**: Your target heading
  - Shows where you're **trying** to go
  - Updates when you click a new waypoint
- **Heading Number**: Target heading in degrees (000-359)

## Why the Green Triangle and Yellow Line Don't Match

This is **normal submarine behavior**:

1. You click a waypoint (cyan circle appears)
2. The yellow line shows your intended course
3. The green triangle shows where your submarine is **currently** pointing
4. The submarine **slowly turns** to align with the yellow line
5. Once aligned, the submarine moves along the course

Submarines turn very slowly (3-10°/second depending on speed), so there's always a delay between setting a course and actually facing that direction.

## Demo Patrol

The yellow arc you see is from a **test air patrol** that spawns automatically. This is for testing the AI and sonar systems. To remove it, comment out the `_spawn_demo_patrol()` call in `scripts/core/main.gd`.
