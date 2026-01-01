#!/bin/bash
# Open the project in Godot Editor to compile shaders and register addon classes

echo "Opening Tactical Submarine Simulator in Godot Editor..."
echo ""
echo "This will:"
echo "  1. Register addon classes (Ocean3D, QuadTree3D, etc.)"
echo "  2. Compile custom shaders (including the fixed SurfaceVisual.gdshader)"
echo "  3. Build the project cache"
echo ""
echo "Please wait for the editor to fully load before testing."
echo "Look for the progress bar at the bottom to complete."
echo ""

~/utils/Godot_v4.5.1-stable_linux.x86_64 project.godot
