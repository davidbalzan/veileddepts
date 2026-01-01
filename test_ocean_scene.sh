#!/bin/bash
# Test ocean rendering in isolated scene

echo "Testing Ocean Rendering..."
echo "=========================="
echo ""
echo "This will:"
echo "1. Run a minimal test scene with just ocean + camera"
echo "2. Show any errors in console"
echo "3. Help diagnose ocean rendering issues"
echo ""
echo "Press Ctrl+C to exit when done testing"
echo ""

# Run the ocean test scene
~/utils/Godot_v4.5.1-stable_linux.x86_64 --path . scenes/ocean_test.tscn
