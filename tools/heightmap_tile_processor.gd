@tool
class_name HeightmapTileProcessor extends Node
## Preprocesses large heightmap images into efficient tile-based storage with multi-LOD support
##
## Run this in the editor (via @tool) to convert the World_elevation_map.png
## into smaller tiles at multiple LOD levels that can be loaded on demand.
##
## Tile Storage Structure:
## assets/terrain/tiles/
## ├── lod0/           # Full resolution tiles (512x512 pixels)
## │   ├── tile_0_0.bin
## │   └── ...
## ├── lod1/           # Half resolution (256x256 pixels)
## │   └── ...
## ├── lod2/           # Quarter resolution (128x128 pixels)
## │   └── ...
## ├── lod3/           # Eighth resolution (64x64 pixels)
## │   └── ...
## └── tile_index.json # Metadata for all tiles
##
## Usage from editor:
## 1. Add this script to a Node in the scene
## 2. Set the export variables
## 3. Call process_heightmap() from the script editor or button
##
## Or run from command line:
## godot --headless --script res://tools/heightmap_tile_processor.gd
##
## Requirements: 8.1

const TILE_SIZE: int = 512  # Pixels per tile at LOD 0
const MAX_LOD_LEVELS: int = 4  # LOD 0-3

@export var input_path: String = "res://src_assets/World_elevation_map.png"
@export var output_dir: String = "res://assets/terrain/tiles/"
@export var generate_lod_levels: bool = true  # Generate multi-LOD tiles
@export_tool_button("Process Heightmap") var process_button = process_heightmap

# Metadata about the tileset
var metadata: Dictionary = {}

# Source image reference
var _source_image: Image = null
var _source_width: int = 0
var _source_height: int = 0


func _ready() -> void:
	# When run as main script, process automatically
	if OS.has_feature("editor") and get_parent() == null:
		process_heightmap()
		get_tree().quit()


func process_heightmap() -> void:
	print("HeightmapTileProcessor: Starting multi-LOD tile generation...")

	# Check input file
	if not FileAccess.file_exists(input_path):
		push_error("HeightmapTileProcessor: Input file not found: " + input_path)
		return

	# Load the source image
	print("HeightmapTileProcessor: Loading source image (this may take a moment)...")
	_source_image = Image.new()
	var error = _source_image.load(input_path)

	if error != OK:
		push_error("HeightmapTileProcessor: Failed to load image: " + str(error))
		return

	_source_width = _source_image.get_width()
	_source_height = _source_image.get_height()
	print("HeightmapTileProcessor: Source image size: %d x %d" % [_source_width, _source_height])

	# Calculate tile grid for LOD 0
	var tiles_x = ceili(float(_source_width) / TILE_SIZE)
	var tiles_y = ceili(float(_source_height) / TILE_SIZE)
	print(
		(
			"HeightmapTileProcessor: LOD 0 tile grid: %d x %d (%d total tiles)"
			% [tiles_x, tiles_y, tiles_x * tiles_y]
		)
	)

	# Scan for min/max values
	print("HeightmapTileProcessor: Scanning for min/max elevation values...")
	var min_value: float = 1.0
	var max_value: float = 0.0

	var sample_step = max(1, _source_width / 2048)  # Sample every Nth pixel
	for y in range(0, _source_height, sample_step):
		for x in range(0, _source_width, sample_step):
			var pixel = _source_image.get_pixel(x, y)
			var value = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			min_value = min(min_value, value)
			max_value = max(max_value, value)

	print("HeightmapTileProcessor: Value range: %.4f to %.4f" % [min_value, max_value])

	# Create output directory structure
	_ensure_directory_exists(output_dir)
	
	# Create LOD directories
	if generate_lod_levels:
		for lod in range(MAX_LOD_LEVELS):
			_ensure_directory_exists(output_dir + "lod%d/" % lod)

	# Initialize metadata
	metadata = {
		"version": 2,
		"source_width": _source_width,
		"source_height": _source_height,
		"tile_size": TILE_SIZE,
		"tiles_x": tiles_x,
		"tiles_y": tiles_y,
		"min_value": min_value,
		"max_value": max_value,
		"mariana_depth": -10994.0,
		"everest_height": 8849.0,
		"lod_levels": MAX_LOD_LEVELS if generate_lod_levels else 1,
		"tiles": {},
		"lod_tiles": {}
	}
	
	# Initialize LOD tile metadata
	for lod in range(MAX_LOD_LEVELS if generate_lod_levels else 1):
		metadata["lod_tiles"][str(lod)] = {}

	# Process tiles at each LOD level
	if generate_lod_levels:
		for lod in range(MAX_LOD_LEVELS):
			_process_lod_level(lod, tiles_x, tiles_y, min_value, max_value)
	else:
		# Just process LOD 0 (full resolution)
		_process_lod_level(0, tiles_x, tiles_y, min_value, max_value)
	
	# Also generate flat tiles for backward compatibility (LOD 0 tiles in root)
	print("HeightmapTileProcessor: Generating backward-compatible flat tiles...")
	_process_flat_tiles(tiles_x, tiles_y, min_value, max_value)

	# Save metadata as tile_index.json
	var index_path = output_dir + "tile_index.json"
	_save_metadata(index_path)
	
	# Also save as tileset.json for backward compatibility
	var tileset_path = output_dir + "tileset.json"
	_save_tileset_metadata(tileset_path, tiles_x, tiles_y, min_value, max_value)

	print("HeightmapTileProcessor: Complete!")
	print("  Output directory: " + output_dir)
	print("  LOD levels: %d" % (MAX_LOD_LEVELS if generate_lod_levels else 1))
	print("  Tile index: " + index_path)
	print("  Tileset (compat): " + tileset_path)


func _process_lod_level(lod: int, tiles_x: int, tiles_y: int, min_val: float, max_val: float) -> void:
	"""Process all tiles at a specific LOD level"""
	var scale = 1 << lod  # 1, 2, 4, 8
	var output_size = TILE_SIZE >> lod  # 512, 256, 128, 64
	output_size = max(output_size, 32)  # Minimum 32x32
	
	# Calculate effective tile grid at this LOD
	# At higher LODs, we cover more source pixels per tile
	var effective_tiles_x = ceili(float(tiles_x) / scale)
	var effective_tiles_y = ceili(float(tiles_y) / scale)
	
	print("HeightmapTileProcessor: Processing LOD %d (%dx%d output, %d x %d tiles)" % [
		lod, output_size, output_size, effective_tiles_x, effective_tiles_y
	])
	
	var processed = 0
	var total_tiles = effective_tiles_x * effective_tiles_y
	
	for ty in range(effective_tiles_y):
		for tx in range(effective_tiles_x):
			var tile_key = "%d_%d" % [tx, ty]
			
			# Calculate source region for this tile
			var src_x = tx * TILE_SIZE * scale
			var src_y = ty * TILE_SIZE * scale
			var src_w = min(TILE_SIZE * scale, _source_width - src_x)
			var src_h = min(TILE_SIZE * scale, _source_height - src_y)
			
			# Skip if source region is invalid
			if src_w <= 0 or src_h <= 0:
				continue
			
			# Calculate actual output size for this tile
			var out_w = mini(output_size, ceili(float(src_w) / scale))
			var out_h = mini(output_size, ceili(float(src_h) / scale))
			
			# Generate downsampled tile
			var tile_data = _generate_lod_tile(src_x, src_y, src_w, src_h, out_w, out_h, min_val, max_val)
			
			# Save tile
			var lod_dir = output_dir + "lod%d/" % lod
			var tile_path = lod_dir + "tile_%s.bin" % tile_key
			_save_tile_binary(tile_path, tile_data, out_w, out_h)
			
			# Store tile metadata
			metadata["lod_tiles"][str(lod)][tile_key] = {
				"file": "lod%d/tile_%s.bin" % [lod, tile_key],
				"width": out_w,
				"height": out_h,
				"src_x": src_x,
				"src_y": src_y,
				"src_w": src_w,
				"src_h": src_h,
				"lod": lod
			}
			
			processed += 1
			if processed % 100 == 0 or processed == total_tiles:
				print(
					(
						"  LOD %d: Processed %d/%d tiles (%.1f%%)"
						% [lod, processed, total_tiles, 100.0 * processed / total_tiles]
					)
				)


func _generate_lod_tile(src_x: int, src_y: int, src_w: int, src_h: int, 
						out_w: int, out_h: int, min_val: float, max_val: float) -> PackedByteArray:
	"""Generate a downsampled tile from source region"""
	var data = PackedByteArray()
	data.resize(out_w * out_h * 2)  # 2 bytes per pixel (16-bit)
	
	var range_val = max_val - min_val
	if range_val <= 0:
		range_val = 1.0
	
	var idx = 0
	for y in range(out_h):
		for x in range(out_w):
			# Calculate source position with bilinear sampling
			var u = float(x) / maxf(out_w - 1, 1)
			var v = float(y) / maxf(out_h - 1, 1)
			
			var px = src_x + u * (src_w - 1)
			var py = src_y + v * (src_h - 1)
			
			# Clamp to valid range
			px = clampf(px, 0, _source_width - 1)
			py = clampf(py, 0, _source_height - 1)
			
			# Sample with bilinear interpolation
			var value = _sample_bilinear(px, py)
			
			# Normalize to 0-1
			var normalized = (value - min_val) / range_val
			
			# Convert to 16-bit unsigned (0-65535)
			var height_16bit = int(clamp(normalized * 65535.0, 0, 65535))
			
			# Store as little-endian
			data[idx] = height_16bit & 0xFF
			data[idx + 1] = (height_16bit >> 8) & 0xFF
			idx += 2
	
	return data


func _sample_bilinear(px: float, py: float) -> float:
	"""Sample source image with bilinear interpolation"""
	var x0 = int(floor(px))
	var y0 = int(floor(py))
	var x1 = mini(x0 + 1, _source_width - 1)
	var y1 = mini(y0 + 1, _source_height - 1)
	
	var fx = px - x0
	var fy = py - y0
	
	# Sample four corners
	var v00 = _get_grayscale(x0, y0)
	var v10 = _get_grayscale(x1, y0)
	var v01 = _get_grayscale(x0, y1)
	var v11 = _get_grayscale(x1, y1)
	
	# Bilinear interpolation
	var v0 = lerpf(v00, v10, fx)
	var v1 = lerpf(v01, v11, fx)
	return lerpf(v0, v1, fy)


func _get_grayscale(x: int, y: int) -> float:
	"""Get grayscale value from source image"""
	var pixel = _source_image.get_pixel(x, y)
	return pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114


func _process_flat_tiles(tiles_x: int, tiles_y: int, min_val: float, max_val: float) -> void:
	"""Process tiles in flat structure for backward compatibility"""
	var processed = 0
	var total_tiles = tiles_x * tiles_y
	
	for ty in range(tiles_y):
		for tx in range(tiles_x):
			var tile_key = "%d_%d" % [tx, ty]
			
			# Calculate source region
			var src_x = tx * TILE_SIZE
			var src_y = ty * TILE_SIZE
			var tile_w = min(TILE_SIZE, _source_width - src_x)
			var tile_h = min(TILE_SIZE, _source_height - src_y)
			
			# Extract tile region
			var tile_rect = Rect2i(src_x, src_y, tile_w, tile_h)
			var tile_image = _source_image.get_region(tile_rect)
			
			# Convert to 16-bit heightmap format
			var heightmap_data = _convert_to_height_data(tile_image, min_val, max_val)
			
			# Save tile as binary file
			var tile_path = output_dir + "tile_%s.bin" % tile_key
			_save_tile_binary(tile_path, heightmap_data, tile_w, tile_h)
			
			# Store tile metadata (for backward compatibility)
			metadata["tiles"][tile_key] = {
				"file": "tile_%s.bin" % tile_key,
				"width": tile_w,
				"height": tile_h,
				"src_x": src_x,
				"src_y": src_y
			}
			
			processed += 1
			if processed % 100 == 0 or processed == total_tiles:
				print(
					(
						"  Flat tiles: Processed %d/%d tiles (%.1f%%)"
						% [processed, total_tiles, 100.0 * processed / total_tiles]
					)
				)


func _convert_to_height_data(image: Image, min_val: float, max_val: float) -> PackedByteArray:
	"""Convert image to 16-bit heightmap data (little-endian)"""
	var width = image.get_width()
	var height = image.get_height()
	var data = PackedByteArray()
	data.resize(width * height * 2)  # 2 bytes per pixel

	var range_val = max_val - min_val
	if range_val <= 0:
		range_val = 1.0

	var idx = 0
	for y in range(height):
		for x in range(width):
			var pixel = image.get_pixel(x, y)
			# Convert to grayscale
			var value = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			# Normalize to 0-1
			var normalized = (value - min_val) / range_val
			# Convert to 16-bit unsigned (0-65535)
			var height_16bit = int(clamp(normalized * 65535.0, 0, 65535))
			# Store as little-endian
			data[idx] = height_16bit & 0xFF
			data[idx + 1] = (height_16bit >> 8) & 0xFF
			idx += 2

	return data


func _save_tile_binary(path: String, data: PackedByteArray, width: int, height: int) -> void:
	"""Save tile as binary file with header"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("HeightmapTileProcessor: Failed to create file: " + path)
		return

	# Write simple header
	file.store_16(width)  # 2 bytes
	file.store_16(height)  # 2 bytes

	# Write heightmap data
	file.store_buffer(data)
	file.close()


func _save_metadata(path: String) -> void:
	"""Save tile index metadata as JSON"""
	var json = JSON.stringify(metadata, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("HeightmapTileProcessor: Failed to create metadata file: " + path)
		return
	file.store_string(json)
	file.close()


func _save_tileset_metadata(path: String, tiles_x: int, tiles_y: int, min_val: float, max_val: float) -> void:
	"""Save backward-compatible tileset.json"""
	var tileset = {
		"version": 1,
		"source_width": _source_width,
		"source_height": _source_height,
		"tile_size": TILE_SIZE,
		"tiles_x": tiles_x,
		"tiles_y": tiles_y,
		"min_value": min_val,
		"max_value": max_val,
		"mariana_depth": -10994.0,
		"everest_height": 8849.0,
		"tiles": metadata["tiles"]
	}
	
	var json = JSON.stringify(tileset, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("HeightmapTileProcessor: Failed to create tileset file: " + path)
		return
	file.store_string(json)
	file.close()


func _ensure_directory_exists(path: String) -> void:
	"""Create directory if it doesn't exist"""
	var dir = DirAccess.open("res://")
	if not dir:
		push_error("HeightmapTileProcessor: Cannot access res://")
		return

	# Remove res:// prefix for path operations
	var relative_path = path.replace("res://", "")

	# Create each directory in the path
	var parts = relative_path.split("/")
	var current_path = ""
	for part in parts:
		if part.is_empty():
			continue
		current_path += part + "/"
		if not dir.dir_exists(current_path):
			var err = dir.make_dir(current_path)
			if err != OK:
				push_error("HeightmapTileProcessor: Failed to create directory: " + current_path)
				return


## Get tile resolution at a specific LOD level
static func get_tile_resolution_at_lod(lod: int) -> int:
	var resolution = TILE_SIZE >> lod
	return max(resolution, 32)


## Get the number of source pixels covered by a tile at a specific LOD level
static func get_source_coverage_at_lod(lod: int) -> int:
	return TILE_SIZE * (1 << lod)
