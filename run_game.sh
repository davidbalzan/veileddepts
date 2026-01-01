#!/bin/bash
# Launch the Tactical Submarine Simulator

echo "Starting Tactical Submarine Simulator..."
echo "Controls:"
echo "  1 - Tactical Map View"
echo "  2 - Periscope View"
echo "  3 - External View"
echo "  Tab - Cycle Views"
echo ""

godot --path . scenes/main.tscn
