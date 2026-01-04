#!/usr/bin/env python3
"""
Heightmap Tile Processor with Multi-LOD Support

Converts a large heightmap image into smaller tiles at multiple LOD levels
for efficient streaming. Outputs binary tile files and JSON metadata files.

Tile Storage Structure:
assets/terrain/tiles/
├── lod0/           # Full resolution tiles (512x512 pixels)
│   ├── tile_0_0.bin
│   └── ...
├── lod1/           # Half resolution (256x256 pixels)
│   └── ...
├── lod2/           # Quarter resolution (128x128 pixels)
│   └── ...
├── lod3/           # Eighth resolution (64x64 pixels)
│   └── ...
├── tile_index.json # Metadata for all tiles (new format)
└── tileset.json    # Backward-compatible metadata

Usage:
    python3 process_heightmap.py [input_path] [output_dir] [--no-lod]

Example:
    python3 process_heightmap.py ../src_assets/World_elevation_map.png ../assets/terrain/tiles/

Requirements: 8.1
"""

import os
import sys
import json
import struct
import math
from pathlib import Path

try:
    from PIL import Image
    import numpy as np
    from scipy import ndimage
    # Allow very large images (heightmaps can be huge)
    Image.MAX_IMAGE_PIXELS = 300000000  # ~300 million pixels
    HAS_SCIPY = True
except ImportError:
    try:
        from PIL import Image
        import numpy as np
        Image.MAX_IMAGE_PIXELS = 300000000
        HAS_SCIPY = False
    except ImportError:
        print("Error: This script requires PIL and numpy")
        print("Install with: pip3 install Pillow numpy scipy")
        sys.exit(1)

TILE_SIZE = 512  # Pixels per tile at LOD 0
MAX_LOD_LEVELS = 4  # LOD 0-3


def process_heightmap(input_path: str, output_dir: str, generate_lod: bool = True) -> None:
    print(f"HeightmapTileProcessor: Starting multi-LOD tile generation...")
    print(f"  Input: {input_path}")
    print(f"  Output: {output_dir}")
    print(f"  Generate LOD levels: {generate_lod}")

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

    # Convert to numpy array (float32 for precision)
    data = np.array(img, dtype=np.float32) / 255.0

    # Find min/max values
    print("Scanning for min/max elevation values...")
    min_value = float(np.min(data))
    max_value = float(np.max(data))
    print(f"  Value range: {min_value:.4f} to {max_value:.4f}")

    # Calculate tile grid for LOD 0
    tiles_x = math.ceil(width / TILE_SIZE)
    tiles_y = math.ceil(height / TILE_SIZE)
    print(f"LOD 0 tile grid: {tiles_x} x {tiles_y} ({tiles_x * tiles_y} total tiles)")

    # Create LOD directories
    if generate_lod:
        for lod in range(MAX_LOD_LEVELS):
            lod_dir = os.path.join(output_dir, f"lod{lod}")
            os.makedirs(lod_dir, exist_ok=True)

    # Initialize metadata
    metadata = {
        "version": 2,
        "source_width": width,
        "source_height": height,
        "tile_size": TILE_SIZE,
        "tiles_x": tiles_x,
        "tiles_y": tiles_y,
        "min_value": min_value,
        "max_value": max_value,
        "mariana_depth": -10994.0,
        "everest_height": 8849.0,
        "lod_levels": MAX_LOD_LEVELS if generate_lod else 1,
        "tiles": {},
        "lod_tiles": {}
    }

    # Initialize LOD tile metadata
    for lod in range(MAX_LOD_LEVELS if generate_lod else 1):
        metadata["lod_tiles"][str(lod)] = {}

    value_range = max_value - min_value if max_value > min_value else 1.0

    # Pre-generate downsampled versions of the full image for each LOD level
    # This is MUCH faster than downsampling each tile individually
    lod_images = {0: data}
    if generate_lod:
        print("Pre-generating LOD images...")
        for lod in range(1, MAX_LOD_LEVELS):
            scale = 1 << lod
            new_h = max(height // scale, 1)
            new_w = max(width // scale, 1)
            
            # Use PIL for fast high-quality downsampling
            pil_img = Image.fromarray((data * 255).astype(np.uint8))
            pil_img = pil_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
            lod_images[lod] = np.array(pil_img, dtype=np.float32) / 255.0
            print(f"  LOD {lod}: {new_w} x {new_h}")

    # Process tiles at each LOD level
    if generate_lod:
        for lod in range(MAX_LOD_LEVELS):
            process_lod_level_fast(lod_images[lod], lod, tiles_x, tiles_y, width, height, 
                                  min_value, value_range, output_dir, metadata)
    else:
        process_lod_level_fast(data, 0, tiles_x, tiles_y, width, height,
                              min_value, value_range, output_dir, metadata)

    # Generate flat tiles for backward compatibility (LOD 0 tiles in root)
    print("Generating backward-compatible flat tiles...")
    process_flat_tiles(data, tiles_x, tiles_y, width, height, 
                      min_value, value_range, output_dir, metadata)

    # Save tile_index.json (new format)
    index_path = os.path.join(output_dir, "tile_index.json")
    with open(index_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"  Saved tile index: {index_path}")

    # Save tileset.json (backward-compatible format)
    tileset = {
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
        "tiles": metadata["tiles"]
    }
    tileset_path = os.path.join(output_dir, "tileset.json")
    with open(tileset_path, 'w') as f:
        json.dump(tileset, f, indent=2)
    print(f"  Saved tileset (compat): {tileset_path}")

    print(f"\nComplete!")
    print(f"  Output directory: {output_dir}")
    print(f"  LOD levels: {MAX_LOD_LEVELS if generate_lod else 1}")

    # Calculate approximate storage
    total_size = 0
    for root, dirs, files in os.walk(output_dir):
        for file in files:
            if file.endswith('.bin'):
                total_size += os.path.getsize(os.path.join(root, file))
    print(f"  Total tile size: {total_size / (1024 * 1024):.1f} MB")


def process_lod_level_fast(lod_data: np.ndarray, lod: int, tiles_x: int, tiles_y: int,
                          orig_width: int, orig_height: int, min_value: float, value_range: float,
                          output_dir: str, metadata: dict) -> None:
    """Process all tiles at a specific LOD level using pre-downsampled data"""
    scale = 1 << lod  # 1, 2, 4, 8
    lod_height, lod_width = lod_data.shape
    
    # Tile size at this LOD level
    tile_size_at_lod = max(TILE_SIZE // scale, 32)
    
    # Calculate effective tile grid at this LOD
    effective_tiles_x = math.ceil(lod_width / tile_size_at_lod)
    effective_tiles_y = math.ceil(lod_height / tile_size_at_lod)
    
    print(f"Processing LOD {lod} ({tile_size_at_lod}x{tile_size_at_lod} tiles, {effective_tiles_x} x {effective_tiles_y} grid)")
    
    processed = 0
    total_tiles = effective_tiles_x * effective_tiles_y
    lod_dir = os.path.join(output_dir, f"lod{lod}")
    
    for ty in range(effective_tiles_y):
        for tx in range(effective_tiles_x):
            tile_key = f"{tx}_{ty}"
            
            # Calculate region in LOD image
            src_x = tx * tile_size_at_lod
            src_y = ty * tile_size_at_lod
            tile_w = min(tile_size_at_lod, lod_width - src_x)
            tile_h = min(tile_size_at_lod, lod_height - src_y)
            
            # Skip if region is invalid
            if tile_w <= 0 or tile_h <= 0:
                continue
            
            # Extract tile region directly from pre-downsampled image
            tile_data = lod_data[src_y:src_y + tile_h, src_x:src_x + tile_w]
            
            # Normalize to 0-1 based on global min/max
            normalized = (tile_data - min_value) / value_range
            
            # Convert to 16-bit unsigned (0-65535)
            height_16bit = (normalized * 65535.0).clip(0, 65535).astype(np.uint16)
            
            # Save tile
            tile_path = os.path.join(lod_dir, f"tile_{tile_key}.bin")
            save_tile_binary(tile_path, height_16bit, tile_w, tile_h)
            
            # Calculate original source coordinates
            orig_src_x = tx * TILE_SIZE
            orig_src_y = ty * TILE_SIZE
            orig_src_w = min(TILE_SIZE * scale, orig_width - orig_src_x)
            orig_src_h = min(TILE_SIZE * scale, orig_height - orig_src_y)
            
            # Store tile metadata
            metadata["lod_tiles"][str(lod)][tile_key] = {
                "file": f"lod{lod}/tile_{tile_key}.bin",
                "width": tile_w,
                "height": tile_h,
                "src_x": orig_src_x,
                "src_y": orig_src_y,
                "src_w": orig_src_w,
                "src_h": orig_src_h,
                "lod": lod
            }
            
            processed += 1
            if processed % 200 == 0 or processed == total_tiles:
                print(f"  LOD {lod}: Processed {processed}/{total_tiles} tiles ({100.0 * processed / total_tiles:.1f}%)")


def process_flat_tiles(data: np.ndarray, tiles_x: int, tiles_y: int,
                      width: int, height: int, min_value: float, value_range: float,
                      output_dir: str, metadata: dict) -> None:
    """Process tiles in flat structure for backward compatibility"""
    processed = 0
    total_tiles = tiles_x * tiles_y
    
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
            height_16bit = (normalized * 65535.0).clip(0, 65535).astype(np.uint16)
            
            # Save tile
            tile_path = os.path.join(output_dir, f"tile_{tile_key}.bin")
            save_tile_binary(tile_path, height_16bit, tile_w, tile_h)
            
            # Store tile metadata
            metadata["tiles"][tile_key] = {
                "file": f"tile_{tile_key}.bin",
                "width": tile_w,
                "height": tile_h,
                "src_x": src_x,
                "src_y": src_y
            }
            
            processed += 1
            if processed % 200 == 0 or processed == total_tiles:
                print(f"  Flat tiles: Processed {processed}/{total_tiles} tiles ({100.0 * processed / total_tiles:.1f}%)")


def save_tile_binary(path: str, data: np.ndarray, width: int, height: int) -> None:
    """Save tile as binary file with header"""
    with open(path, 'wb') as f:
        # Write header (little-endian)
        f.write(struct.pack('<HH', width, height))
        # Write heightmap data (little-endian)
        f.write(data.tobytes())


def main():
    # Default paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_input = os.path.join(script_dir, "..", "src_assets", "World_elevation_map.png")
    default_output = os.path.join(script_dir, "..", "assets", "terrain", "tiles")

    # Parse arguments
    generate_lod = True
    input_path = default_input
    output_dir = default_output
    
    args = sys.argv[1:]
    non_flag_args = []
    
    for arg in args:
        if arg == "--no-lod":
            generate_lod = False
        elif not arg.startswith("--"):
            non_flag_args.append(arg)
    
    if len(non_flag_args) >= 1:
        input_path = non_flag_args[0]
    if len(non_flag_args) >= 2:
        output_dir = non_flag_args[1]

    process_heightmap(input_path, output_dir, generate_lod)


if __name__ == "__main__":
    main()
