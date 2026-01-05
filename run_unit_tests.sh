#!/bin/bash
# Run GUT unit tests for submarine physics

echo "Running submarine stability unit tests..."
echo ""

# Detect Godot executable based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
    if [ ! -f "$GODOT" ]; then
        echo "Godot not found at $GODOT"
        echo "Please update the GODOT path in this script"
        exit 1
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    GODOT=~/utils/Godot_v4.5.1-stable_linux.x86_64
    if [ ! -f "$GODOT" ]; then
        echo "Godot not found at $GODOT"
        echo "Please update the GODOT path in this script"
        exit 1
    fi
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

# Run GUT tests with headless mode
"$GODOT" --path . --headless -s addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/unit/ -gfile=test_submarine_stability.gd

echo ""
echo "Test run complete!"
