class_name TiledElevationProvider extends Node
## Tile-based elevation data provider for efficient memory usage
##
## Loads elevation tiles on demand instead of keeping the entire
## 21600x10800 heightmap in memory. Tiles are cached with LRU eviction.

const MARIANA_TRENCH_DEPTH: float = -10994.0
const MOUNT_EVEREST_HEIGHT: float = 8849.0

@export var tiles_directory: String = "res://assets/terrain/tiles/"
@export var max_cached_tiles: int = 64  # Maximum tiles in memory

# Tileset metadata
var _metadata: Dictionary = {}
var _initialized: bool = false
var _using_procedural: bool = false

# Tile cache with LRU tracking
var _tile_cache: Dictionary = {}  # tile_key -> PackedByteArray
var _tile_access_order: Array[String] = []  # Most recently used at end

# Elevation conversion values
var _min_value: float = 0.0
var _max_value: float = 1.0
var _tile_size: int = 512
var _tiles_x: int = 0
var _tiles_y: int = 0
var _source_width: int = 0
var _source_height: int = 0

# Mission area mapping
var mission_area_center_uv: Vector2 = Vector2(0.5, 0.5)

# Procedural fallback
var _procedural_noise: FastNoiseLite = null


func initialize() -> bool:
	if _initialized:
		return not _using_procedural

	# Try to load tileset metadata
	var metadata_path = tiles_directory + "tileset.json"

	if not FileAccess.file_exists(metadata_path):
		print("TiledElevationProvider: Tileset not found at " + metadata_path)
		print("  Run the HeightmapTileProcessor tool to generate tiles")
		_setup_procedural_fallback()
		_initialized = true
		_using_procedural = true
		return false

	# Load metadata
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		push_error("TiledElevationProvider: Failed to open metadata file")
		_setup_procedural_fallback()
		_initialized = true
		_using_procedural = true
		return false

	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("TiledElevationProvider: Failed to parse metadata JSON")
		_setup_procedural_fallback()
		_initialized = true
		_using_procedural = true
		return false

	_metadata = json.get_data()

	# Extract metadata values
	_source_width = int(_metadata.get("source_width", 21600))
	_source_height = int(_metadata.get("source_height", 10800))
	_tile_size = int(_metadata.get("tile_size", 512))
	_tiles_x = int(_metadata.get("tiles_x", 43))
	_tiles_y = int(_metadata.get("tiles_y", 22))
	_min_value = float(_metadata.get("min_value", 0.0))
	_max_value = float(_metadata.get("max_value", 1.0))

	_initialized = true
	_using_procedural = false

	print("TiledElevationProvider: Initialized with tile-based loading")
	print("  Source size: %d x %d" % [_source_width, _source_height])
	print("  Tile grid: %d x %d (%d total)" % [_tiles_x, _tiles_y, _tiles_x * _tiles_y])
	print(
		(
			"  Max cached tiles: %d (%.1f MB max)"
			% [max_cached_tiles, max_cached_tiles * _tile_size * _tile_size * 2 / 1048576.0]
		)
	)

	return true


func _setup_procedural_fallback() -> void:
	_procedural_noise = FastNoiseLite.new()
	_procedural_noise.seed = 12345
	_procedural_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_procedural_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_procedural_noise.fractal_octaves = 6
	_procedural_noise.frequency = 0.0001
	_procedural_noise.fractal_lacunarity = 2.0
	_procedural_noise.fractal_gain = 0.5
	print("TiledElevationProvider: Using procedural fallback")


func get_elevation(world_pos: Vector2) -> float:
	if not _initialized:
		push_warning("TiledElevationProvider: Not initialized")
		return -500.0

	if _using_procedural:
		return _get_procedural_elevation(world_pos)

	# Convert world position to UV coordinates (0-1)
	var uv = _world_to_uv(world_pos)

	# Convert UV to pixel coordinates
	var px = uv.x * (_source_width - 1)
	var py = uv.y * (_source_height - 1)

	# Sample with bilinear interpolation
	var elev = _sample_bilinear(px, py)
	
	return elev


func _world_to_uv(world_pos: Vector2) -> Vector2:
	# Convert world coordinates to UV (0-1), relative to mission center
	var u = mission_area_center_uv.x + (world_pos.x / EarthScale.FULL_MAP_WIDTH_METERS)
	var v = mission_area_center_uv.y + (world_pos.y / EarthScale.FULL_MAP_HEIGHT_METERS)

	# Wrap/clamp
	u = fmod(u, 1.0)
	if u < 0.0:
		u += 1.0
	v = clamp(v, 0.0, 1.0)

	return Vector2(u, v)


func _sample_bilinear(px: float, py: float) -> float:
	"""Sample elevation at pixel coordinates with bilinear interpolation"""
	var x0 = int(floor(px))
	var y0 = int(floor(py))
	var x1 = min(x0 + 1, _source_width - 1)
	var y1 = min(y0 + 1, _source_height - 1)

	var fx = px - x0
	var fy = py - y0

	# Sample four corners
	var v00 = _sample_pixel(x0, y0)
	var v10 = _sample_pixel(x1, y0)
	var v01 = _sample_pixel(x0, y1)
	var v11 = _sample_pixel(x1, y1)

	# Bilinear interpolation
	var v0 = lerp(v00, v10, fx)
	var v1 = lerp(v01, v11, fx)
	return lerp(v0, v1, fy)


func _sample_pixel(px: int, py: int) -> float:
	"""Sample a single pixel, loading tiles as needed"""
	# Clamp to valid range
	px = clampi(px, 0, _source_width - 1)
	py = clampi(py, 0, _source_height - 1)

	# Determine which tile this pixel is in
	var tile_x = px / _tile_size
	var tile_y = py / _tile_size
	var tile_key = "%d_%d" % [tile_x, tile_y]

	# Get or load tile
	var tile_data = _get_tile(tile_key)
	if tile_data.is_empty():
		return _get_default_elevation()

	# Calculate local coordinates within tile
	var local_x = px % _tile_size
	var local_y = py % _tile_size

	# Get tile dimensions from metadata
	var tile_info = _metadata.get("tiles", {}).get(tile_key, {})
	var tile_width = int(tile_info.get("width", _tile_size))

	# Handle edge tiles that may be smaller
	if local_x >= tile_width:
		local_x = tile_width - 1

	# Read 16-bit height value (little-endian)
	var idx = (local_y * tile_width + local_x) * 2
	if idx + 1 >= tile_data.size():
		return _get_default_elevation()

	var height_16bit = tile_data[idx] | (tile_data[idx + 1] << 8)

	# Convert to normalized value (0-1)
	var normalized = float(height_16bit) / 65535.0

	# Convert to elevation
	return lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, normalized)


func _get_tile(tile_key: String) -> PackedByteArray:
	"""Get tile data, loading from disk if not cached"""
	# Check cache
	if _tile_cache.has(tile_key):
		# Move to end of access order (most recently used)
		_tile_access_order.erase(tile_key)
		_tile_access_order.append(tile_key)
		return _tile_cache[tile_key]

	# Load from disk
	var tile_info = _metadata.get("tiles", {}).get(tile_key, {})
	if tile_info.is_empty():
		return PackedByteArray()

	var tile_file = tile_info.get("file", "")
	var tile_path = tiles_directory + tile_file

	if not FileAccess.file_exists(tile_path):
		push_warning("TiledElevationProvider: Tile file not found: " + tile_path)
		return PackedByteArray()

	var file = FileAccess.open(tile_path, FileAccess.READ)
	if not file:
		push_warning("TiledElevationProvider: Failed to open tile: " + tile_path)
		return PackedByteArray()

	# Read header
	var _width = file.get_16()
	var _height = file.get_16()

	# Read heightmap data
	var data = file.get_buffer(file.get_length() - 4)
	file.close()

	# Add to cache
	_cache_tile(tile_key, data)

	return data


func _cache_tile(tile_key: String, data: PackedByteArray) -> void:
	"""Add tile to cache with LRU eviction"""
	# Evict oldest tiles if at capacity
	while _tile_cache.size() >= max_cached_tiles and not _tile_access_order.is_empty():
		var oldest_key = _tile_access_order.pop_front()
		_tile_cache.erase(oldest_key)

	# Add new tile
	_tile_cache[tile_key] = data
	_tile_access_order.append(tile_key)


func _get_default_elevation() -> float:
	"""Return default ocean floor depth"""
	return -500.0


func _get_procedural_elevation(world_pos: Vector2) -> float:
	if not _procedural_noise:
		return 0.0
	var noise_value = _procedural_noise.get_noise_2d(world_pos.x, world_pos.y)
	return lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, (noise_value + 1.0) / 2.0)


# Compatibility methods for existing code
func get_vertical_scale() -> float:
	return (MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH) / (_max_value - _min_value)


func get_mariana_depth() -> float:
	return MARIANA_TRENCH_DEPTH


func get_everest_height() -> float:
	return MOUNT_EVEREST_HEIGHT


func is_using_procedural() -> bool:
	return _using_procedural


func get_map_dimensions() -> Vector2i:
	return Vector2i(_source_width, _source_height)


func get_cache_stats() -> Dictionary:
	return {
		"cached_tiles": _tile_cache.size(),
		"max_tiles": max_cached_tiles,
		"memory_mb": _tile_cache.size() * _tile_size * _tile_size * 2 / 1048576.0
	}


func clear_cache() -> void:
	_tile_cache.clear()
	_tile_access_order.clear()


## Extract elevation data for a specific region (compatibility with ElevationDataProvider)
## world_bounds: Rectangle in world coordinates (meters)
## resolution: Output image resolution (width and height)
## Returns: Image containing elevation data for the region
func extract_region(world_bounds: Rect2, resolution: int) -> Image:
	if not _initialized:
		push_error("TiledElevationProvider: Not initialized")
		return null

	var region_image = Image.create(resolution, resolution, false, Image.FORMAT_RF)
	var min_e = 99999.0
	var max_e = -99999.0
	var sum_e = 0.0

	for y in range(resolution):
		for x in range(resolution):
			# Calculate world position for this pixel
			var u_ratio = float(x) / (resolution - 1)
			var v_ratio = float(y) / (resolution - 1)
			
			var world_x = world_bounds.position.x + u_ratio * world_bounds.size.x
			var world_z = world_bounds.position.y + v_ratio * world_bounds.size.y
			var world_pos = Vector2(world_x, world_z)

			# Get elevation at this position
			var elevation = get_elevation(world_pos)
			min_e = min(min_e, elevation)
			max_e = max(max_e, elevation)
			sum_e += elevation

			# Store as normalized value (0-1) for consistency
			var normalized = (
				(elevation - MARIANA_TRENCH_DEPTH) / (MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH)
			)
			region_image.set_pixel(x, y, Color(normalized, 0, 0, 1))

	print("TiledElevationProvider: Extracted region %s - Elevation range: [%.1f, %.1f] Avg: %.1f" % [world_bounds, min_e, max_e, sum_e / (resolution * resolution)])
	return region_image
