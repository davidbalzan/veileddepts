#!/bin/bash
# Force Godot to recompile shaders by opening the editor

echo "This script will:"
echo "1. Delete all shader caches"
echo "2. Touch the shader file to mark it as modified"
echo "3. Open the Godot editor (YOU MUST WAIT FOR IT TO LOAD)"
echo "4. You should see 'Importing' or 'Compiling' messages"
echo "5. Once loaded, CLOSE the editor"
echo "6. Then test the ocean scene"
echo ""
echo "Press Enter to continue..."
read

# Clear all caches
echo "Clearing caches..."
rm -rf .godot/

# Touch shader to mark as modified
echo "Marking shader as modified..."
touch addons/tessarakkt.oceanfft/shaders/SurfaceVisual.gdshader

# Touch material to force reload
touch addons/tessarakkt.oceanfft/OceanFixed.tres

echo ""
echo "Opening Godot Editor..."
echo "WAIT for it to fully load, then CLOSE it."
echo ""

~/utils/Godot_v4.5.1-stable_linux.x86_64 project.godot

echo ""
echo "Editor closed. Now test with:"
echo "  bash test_ocean_scene.sh"
