#!/usr/bin/env python3
"""
Heightmap Tile Processor

Converts a large heightmap image into smaller tiles for efficient streaming.
Outputs binary tile files and a JSON metadata file.

Usage:
    python3 process_heightmap.py [input_path] [output_dir]

Example:
    python3 process_heightmap.py ../src_assets/World_elevation_map.png ../assets/terrain/tiles/
"""

import os
import sys
import json
import struct
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
    # Allow very large images (heightmaps can be huge)
    Image.MAX_IMAGE_PIXELS = 300000000  # ~300 million pixels
except ImportError:
    print("Error: This script requires PIL and numpy")
    print("Install with: pip3 install Pillow numpy")
    sys.exit(1)

TILE_SIZE = 512  # Pixels per tile


def process_heightmap(input_path: str, output_dir: str) -> None:
    print(f"HeightmapTileProcessor: Starting...")
    print(f"  Input: {input_path}")
    print(f"  Output: {output_dir}")

    # Verify input exists
    if not os.path.exists(input_path):
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Load the image
    print("Loading source image (this may take a moment)...")
    img = Image.open(input_path)
    width, height = img.size
    print(f"  Source image size: {width} x {height}")

    # Convert to grayscale if needed
    if img.mode != 'L':
        print("  Converting to grayscale...")
        img = img.convert('L')

    # Convert to numpy array
    data = np.array(img, dtype=np.float32) / 255.0

    # Find min/max values
    print("Scanning for min/max elevation values...")
    min_value = float(np.min(data))
    max_value = float(np.max(data))
    print(f"  Value range: {min_value:.4f} to {max_value:.4f}")

    # Calculate tile grid
    tiles_x = (width + TILE_SIZE - 1) // TILE_SIZE
    tiles_y = (height + TILE_SIZE - 1) // TILE_SIZE
    total_tiles = tiles_x * tiles_y
    print(f"Creating {tiles_x} x {tiles_y} tile grid ({total_tiles} total tiles)")

    # Initialize metadata
    metadata = {
        "version": 1,
        "source_width": width,
        "source_height": height,
        "tile_size": TILE_SIZE,
        "tiles_x": tiles_x,
        "tiles_y": tiles_y,
        "min_value": min_value,
        "max_value": max_value,
        "mariana_depth": -10994.0,
        "everest_height": 8849.0,
        "tiles": {}
    }

    # Process each tile
    processed = 0
    value_range = max_value - min_value if max_value > min_value else 1.0

    for ty in range(tiles_y):
        for tx in range(tiles_x):
            tile_key = f"{tx}_{ty}"

            # Calculate source region
            src_x = tx * TILE_SIZE
            src_y = ty * TILE_SIZE
            tile_w = min(TILE_SIZE, width - src_x)
            tile_h = min(TILE_SIZE, height - src_y)

            # Extract tile region
            tile_data = data[src_y:src_y + tile_h, src_x:src_x + tile_w]

            # Normalize to 0-1 based on global min/max
            normalized = (tile_data - min_value) / value_range

            # Convert to 16-bit unsigned (0-65535)
            height_16bit = (normalized * 65535.0).astype(np.uint16)

            # Save tile as binary file
            tile_path = os.path.join(output_dir, f"tile_{tile_key}.bin")
            with open(tile_path, 'wb') as f:
                # Write header (little-endian)
                f.write(struct.pack('<HH', tile_w, tile_h))
                # Write heightmap data (little-endian)
                f.write(height_16bit.tobytes())

            # Store tile metadata
            metadata["tiles"][tile_key] = {
                "file": f"tile_{tile_key}.bin",
                "width": tile_w,
                "height": tile_h,
                "src_x": src_x,
                "src_y": src_y
            }

            processed += 1
            if processed % 50 == 0 or processed == total_tiles:
                print(f"  Processed {processed}/{total_tiles} tiles ({100.0 * processed / total_tiles:.1f}%)")

    # Save metadata
    metadata_path = os.path.join(output_dir, "tileset.json")
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)

    print(f"\nComplete!")
    print(f"  Output directory: {output_dir}")
    print(f"  Total tiles: {total_tiles}")
    print(f"  Metadata: {metadata_path}")

    # Calculate approximate storage
    total_size_mb = sum(
        os.path.getsize(os.path.join(output_dir, info["file"]))
        for info in metadata["tiles"].values()
    ) / (1024 * 1024)
    print(f"  Total tile size: {total_size_mb:.1f} MB")


def main():
    # Default paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_input = os.path.join(script_dir, "..", "src_assets", "World_elevation_map.png")
    default_output = os.path.join(script_dir, "..", "assets", "terrain", "tiles")

    # Parse arguments
    if len(sys.argv) >= 2:
        input_path = sys.argv[1]
    else:
        input_path = default_input

    if len(sys.argv) >= 3:
        output_dir = sys.argv[2]
    else:
        output_dir = default_output

    process_heightmap(input_path, output_dir)


if __name__ == "__main__":
    main()
