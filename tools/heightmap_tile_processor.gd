@tool
class_name HeightmapTileProcessor extends Node
## Preprocesses large heightmap images into efficient tile-based storage
##
## Run this in the editor (via @tool) to convert the World_elevation_map.png
## into smaller tiles that can be loaded on demand.
##
## Usage from editor:
## 1. Add this script to a Node in the scene
## 2. Set the export variables
## 3. Call process_heightmap() from the script editor or button
##
## Or run from command line:
## godot --headless --script res://tools/heightmap_tile_processor.gd

const TILE_SIZE: int = 512  # Pixels per tile

@export var input_path: String = "res://src_assets/World_elevation_map.png"
@export var output_dir: String = "res://assets/terrain/tiles/"
@export_tool_button("Process Heightmap") var process_button = process_heightmap

# Metadata about the tileset
var metadata: Dictionary = {}


func _ready() -> void:
	# When run as main script, process automatically
	if OS.has_feature("editor") and get_parent() == null:
		process_heightmap()
		get_tree().quit()


func process_heightmap() -> void:
	print("HeightmapTileProcessor: Starting...")

	# Check input file
	if not FileAccess.file_exists(input_path):
		push_error("HeightmapTileProcessor: Input file not found: " + input_path)
		return

	# Load the source image
	print("HeightmapTileProcessor: Loading source image (this may take a moment)...")
	var source_image = Image.new()
	var error = source_image.load(input_path)

	if error != OK:
		push_error("HeightmapTileProcessor: Failed to load image: " + str(error))
		return

	var width = source_image.get_width()
	var height = source_image.get_height()
	print("HeightmapTileProcessor: Source image size: %d x %d" % [width, height])

	# Calculate tile grid
	var tiles_x = ceili(float(width) / TILE_SIZE)
	var tiles_y = ceili(float(height) / TILE_SIZE)
	print(
		(
			"HeightmapTileProcessor: Creating %d x %d tile grid (%d total tiles)"
			% [tiles_x, tiles_y, tiles_x * tiles_y]
		)
	)

	# Scan for min/max values
	print("HeightmapTileProcessor: Scanning for min/max elevation values...")
	var min_value: float = 1.0
	var max_value: float = 0.0

	var sample_step = max(1, width / 2048)  # Sample every Nth pixel
	for y in range(0, height, sample_step):
		for x in range(0, width, sample_step):
			var pixel = source_image.get_pixel(x, y)
			var value = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			min_value = min(min_value, value)
			max_value = max(max_value, value)

	print("HeightmapTileProcessor: Value range: %.4f to %.4f" % [min_value, max_value])

	# Create output directory
	_ensure_directory_exists(output_dir)

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
	var processed = 0
	var total_tiles = tiles_x * tiles_y

	for ty in range(tiles_y):
		for tx in range(tiles_x):
			var tile_key = "%d_%d" % [tx, ty]

			# Calculate source region
			var src_x = tx * TILE_SIZE
			var src_y = ty * TILE_SIZE
			var tile_w = min(TILE_SIZE, width - src_x)
			var tile_h = min(TILE_SIZE, height - src_y)

			# Extract tile region
			var tile_rect = Rect2i(src_x, src_y, tile_w, tile_h)
			var tile_image = source_image.get_region(tile_rect)

			# Convert to 16-bit heightmap format
			var heightmap_data = _convert_to_height_data(tile_image, min_value, max_value)

			# Save tile as binary file
			var tile_path = output_dir + "tile_%s.bin" % tile_key
			_save_tile_binary(tile_path, heightmap_data, tile_w, tile_h)

			# Store tile metadata
			metadata["tiles"][tile_key] = {
				"file": "tile_%s.bin" % tile_key,
				"width": tile_w,
				"height": tile_h,
				"src_x": src_x,
				"src_y": src_y
			}

			processed += 1
			if processed % 50 == 0 or processed == total_tiles:
				print(
					(
						"HeightmapTileProcessor: Processed %d/%d tiles (%.1f%%)"
						% [processed, total_tiles, 100.0 * processed / total_tiles]
					)
				)

	# Save metadata
	var metadata_path = output_dir + "tileset.json"
	_save_metadata(metadata_path)

	print("HeightmapTileProcessor: Complete!")
	print("  Output directory: " + output_dir)
	print("  Total tiles: %d" % total_tiles)
	print("  Metadata: " + metadata_path)


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
	"""Save tileset metadata as JSON"""
	var json = JSON.stringify(metadata, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("HeightmapTileProcessor: Failed to create metadata file: " + path)
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
