class_name TiledElevationProvider extends Node
## Tile-based elevation data provider for efficient memory usage
##
## Loads elevation tiles on demand instead of keeping the entire
## 21600x10800 heightmap in memory. Tiles are cached with LRU eviction.
## Supports multi-resolution LOD for zoom-based detail loading.
##
## Requirements: 8.1, 8.2, 8.3, 8.4, 8.5

const MARIANA_TRENCH_DEPTH: float = -10994.0
const MOUNT_EVEREST_HEIGHT: float = 8849.0

@export var tiles_directory: String = "res://assets/terrain/tiles/"
@export var source_image_path: String = "res://src_assets/World_elevation_map.png"
@export var max_cached_tiles: int = 64  # Maximum tiles in memory
@export var max_lod_levels: int = 4  # LOD 0 = full, LOD 3 = 1/8 resolution

# Tileset metadata
var _metadata: Dictionary = {}
var _initialized: bool = false
var _using_procedural: bool = false
var _has_tiles: bool = false

# Source image fallback
var _source_image: Image = null
var _source_loaded: bool = false

# Tile cache with LRU tracking
var _tile_cache: Dictionary = {}  # tile_key -> PackedByteArray
var _tile_access_order: Array[String] = []  # Most recently used at end

# LOD cache for fast map loading
var _lod_cache: LODCache = null

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


## LOD Cache class for fast map loading
class LODCache:
	## Pre-computed world overview images at different resolutions
	var world_overview: Dictionary = {}  # lod_level -> Image
	
	## Tile cache with LRU eviction
	var tile_cache: Dictionary = {}  # "lod_x_y" -> Image
	var cache_order: Array[String] = []  # LRU order
	var max_cached_tiles: int = 64
	
	## Provider reference
	var _provider: TiledElevationProvider = null
	
	func _init(provider: TiledElevationProvider) -> void:
		_provider = provider
	
	## Pre-load world overview at startup
	func preload_world_overview() -> void:
		print("LODCache: Pre-loading world overview images...")
		for lod in range(4):
			var resolution = 256 >> lod  # 256, 128, 64, 32
			world_overview[lod] = _generate_world_overview(lod, resolution)
			if world_overview[lod]:
				print("  LOD %d: %dx%d" % [lod, resolution, resolution])
	
	func _generate_world_overview(_lod: int, resolution: int) -> Image:
		if not _provider or not _provider._initialized:
			return null
		
		# Generate a low-res overview of the entire world
		var overview = Image.create(resolution, resolution, false, Image.FORMAT_RF)
		
		for y in range(resolution):
			for x in range(resolution):
				var u = float(x) / (resolution - 1)
				var v = float(y) / (resolution - 1)
				
				# Sample from source at this UV
				var px = u * (_provider._source_width - 1)
				var py = v * (_provider._source_height - 1)
				
				var elevation = _provider._sample_bilinear(px, py)
				var normalized = (elevation - MARIANA_TRENCH_DEPTH) / (MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH)
				overview.set_pixel(x, y, Color(normalized, 0, 0, 1))
		
		return overview
	
	## Get cached tile or load from disk
	func get_tile(lod: int, x: int, y: int) -> Image:
		var key = "%d_%d_%d" % [lod, x, y]
		if tile_cache.has(key):
			_touch_cache(key)
			return tile_cache[key]
		
		# Load tile at specified LOD
		var tile = _load_tile_at_lod(lod, x, y)
		if tile:
			_add_to_cache(key, tile)
		return tile
	
	func _load_tile_at_lod(lod: int, tile_x: int, tile_y: int) -> Image:
		if not _provider:
			return null
		
		# Calculate the region this tile covers
		var scale = 1 << lod  # 1, 2, 4, 8
		var tile_size = _provider._tile_size
		
		# Source pixel coordinates
		var src_x = tile_x * tile_size * scale
		var src_y = tile_y * tile_size * scale
		var src_w = tile_size * scale
		var src_h = tile_size * scale
		
		# Output resolution (downsampled)
		var out_size = tile_size
		
		var tile_image = Image.create(out_size, out_size, false, Image.FORMAT_RF)
		
		for y in range(out_size):
			for x in range(out_size):
				var px = src_x + (float(x) / out_size) * src_w
				var py = src_y + (float(y) / out_size) * src_h
				
				px = clampf(px, 0, _provider._source_width - 1)
				py = clampf(py, 0, _provider._source_height - 1)
				
				var elevation = _provider._sample_bilinear(px, py)
				var normalized = (elevation - MARIANA_TRENCH_DEPTH) / (MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH)
				tile_image.set_pixel(x, y, Color(normalized, 0, 0, 1))
		
		return tile_image
	
	func _touch_cache(key: String) -> void:
		var idx = cache_order.find(key)
		if idx >= 0:
			cache_order.remove_at(idx)
		cache_order.append(key)
	
	func _add_to_cache(key: String, tile: Image) -> void:
		# Evict oldest if at capacity
		while tile_cache.size() >= max_cached_tiles and not cache_order.is_empty():
			var oldest = cache_order.pop_front()
			tile_cache.erase(oldest)
		
		tile_cache[key] = tile
		cache_order.append(key)
	
	func get_cached_overview(lod: int) -> Image:
		lod = clampi(lod, 0, 3)
		return world_overview.get(lod, null)
	
	func clear() -> void:
		world_overview.clear()
		tile_cache.clear()
		cache_order.clear()


func _ready() -> void:
	# Auto-initialize if not already done
	if not _initialized:
		call_deferred("initialize")


## Initialize the elevation data provider
## Returns true if tiles are available, false if using fallback
func initialize() -> bool:
	if _initialized:
		return _has_tiles

	# Try to load tileset metadata
	var metadata_path = tiles_directory + "tileset.json"

	if FileAccess.file_exists(metadata_path):
		if _load_tileset_metadata(metadata_path):
			_has_tiles = true
			_using_procedural = false
			print("TiledElevationProvider: Initialized with tile-based loading")
			print("  Source size: %d x %d" % [_source_width, _source_height])
			print("  Tile grid: %d x %d (%d total)" % [_tiles_x, _tiles_y, _tiles_x * _tiles_y])
			print("  Max cached tiles: %d (%.1f MB max)" % [max_cached_tiles, max_cached_tiles * _tile_size * _tile_size * 2 / 1048576.0])
		else:
			print("TiledElevationProvider: Failed to load tileset metadata")
	else:
		print("TiledElevationProvider: Tileset not found at " + metadata_path)
	
	# If tiles not available, try source image fallback
	if not _has_tiles:
		if _load_source_image():
			_using_procedural = false
			print("TiledElevationProvider: Using source image fallback")
		else:
			_setup_procedural_fallback()
			_using_procedural = true
			print("TiledElevationProvider: Using procedural fallback")
	
	_initialized = true
	
	# Initialize LOD cache
	_lod_cache = LODCache.new(self)
	
	# Note: World overview pre-loading is disabled by default for faster startup
	# Call preload_world_overview() manually if needed for map display
	# if not _using_procedural:
	#     _lod_cache.preload_world_overview()
	
	return _has_tiles


func _load_tileset_metadata(metadata_path: String) -> bool:
	var file = FileAccess.open(metadata_path, FileAccess.READ)
	if not file:
		push_error("TiledElevationProvider: Failed to open metadata file")
		return false

	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("TiledElevationProvider: Failed to parse metadata JSON")
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

	return true


## Load source image as fallback when tiles unavailable
## Requirements: 8.3
func _load_source_image() -> bool:
	if not FileAccess.file_exists(source_image_path):
		print("TiledElevationProvider: Source image not found at " + source_image_path)
		return false
	
	# Try to load as resource first
	var resource = load(source_image_path)
	if resource:
		if resource is Texture2D:
			_source_image = resource.get_image()
		elif resource is Image:
			_source_image = resource
	
	if not _source_image:
		# Direct file load fallback
		_source_image = Image.new()
		var error = _source_image.load(source_image_path)
		if error != OK:
			push_error("TiledElevationProvider: Failed to load source image: " + str(error))
			_source_image = null
			return false
	
	_source_width = _source_image.get_width()
	_source_height = _source_image.get_height()
	_source_loaded = true
	
	print("TiledElevationProvider: Loaded source image %d x %d" % [_source_width, _source_height])
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
	
	# Set default dimensions for procedural
	_source_width = 21600
	_source_height = 10800


## Check if pre-processed tiles are available
## Requirements: 8.2
func has_tiles() -> bool:
	return _has_tiles


## Get elevation at a specific world position
## Requirements: 8.4
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
	return _sample_bilinear(px, py)


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
	var x1 = mini(x0 + 1, _source_width - 1)
	var y1 = mini(y0 + 1, _source_height - 1)

	var fx = px - x0
	var fy = py - y0

	# Sample four corners
	var v00 = _sample_pixel(x0, y0)
	var v10 = _sample_pixel(x1, y0)
	var v01 = _sample_pixel(x0, y1)
	var v11 = _sample_pixel(x1, y1)

	# Bilinear interpolation
	var v0 = lerpf(v00, v10, fx)
	var v1 = lerpf(v01, v11, fx)
	return lerpf(v0, v1, fy)


func _sample_pixel(px: int, py: int) -> float:
	"""Sample a single pixel, loading tiles as needed or using source image"""
	# Clamp to valid range
	px = clampi(px, 0, _source_width - 1)
	py = clampi(py, 0, _source_height - 1)

	# If using source image fallback
	if _source_loaded and _source_image:
		return _sample_source_image(px, py)
	
	# Use tiles
	if not _has_tiles:
		return _get_default_elevation()

	# Determine which tile this pixel is in
	@warning_ignore("integer_division")
	var tile_x = px / _tile_size
	@warning_ignore("integer_division")
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
	return lerpf(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, normalized)


func _sample_source_image(px: int, py: int) -> float:
	"""Sample elevation from source image"""
	var pixel = _source_image.get_pixel(px, py)
	# Use luminance for grayscale conversion
	var value = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
	# Convert to elevation
	return lerpf(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, value)


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
	return lerpf(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, (noise_value + 1.0) / 2.0)


## Extract elevation data for a specific region
## Requirements: 8.1, 8.4
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
			var u_ratio = float(x) / maxf(resolution - 1, 1)
			var v_ratio = float(y) / maxf(resolution - 1, 1)
			
			var world_x = world_bounds.position.x + u_ratio * world_bounds.size.x
			var world_z = world_bounds.position.y + v_ratio * world_bounds.size.y
			var world_pos = Vector2(world_x, world_z)

			# Get elevation at this position
			var elevation = get_elevation(world_pos)
			min_e = minf(min_e, elevation)
			max_e = maxf(max_e, elevation)
			sum_e += elevation

			# Store as normalized value (0-1) for consistency
			var normalized = (elevation - MARIANA_TRENCH_DEPTH) / (MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH)
			region_image.set_pixel(x, y, Color(normalized, 0, 0, 1))

	var avg_e = sum_e / maxf(resolution * resolution, 1)
	print("TiledElevationProvider: Extracted region %s - Elevation range: [%.1f, %.1f] Avg: %.1f" % [world_bounds, min_e, max_e, avg_e])
	return region_image


## Extract elevation data at a specific LOD level
## Requirements: 8.5
## world_bounds: Rectangle in world coordinates (meters)
## lod_level: 0 = full resolution, 3 = 1/8 resolution
## Returns: Image containing elevation data for the region
func extract_region_lod(world_bounds: Rect2, lod_level: int) -> Image:
	if not _initialized:
		push_error("TiledElevationProvider: Not initialized")
		return null
	
	lod_level = clampi(lod_level, 0, max_lod_levels - 1)
	
	# Calculate resolution based on LOD level
	# LOD 0 = 256, LOD 1 = 128, LOD 2 = 64, LOD 3 = 32
	var base_resolution = 256
	var resolution = base_resolution >> lod_level
	resolution = maxi(resolution, 16)  # Minimum 16x16
	
	return extract_region(world_bounds, resolution)


## Get appropriate LOD level based on zoom scale
## Requirements: 8.5
## meters_per_pixel: How many meters each pixel represents (lower = more zoomed in)
## Returns: LOD level (0-3)
func get_lod_for_zoom(meters_per_pixel: float) -> int:
	# Higher meters_per_pixel = more zoomed out = lower detail needed
	if meters_per_pixel < 10.0:
		return 0  # Very zoomed in, full detail
	elif meters_per_pixel < 50.0:
		return 1  # Medium zoom
	elif meters_per_pixel < 200.0:
		return 2  # Overview
	else:
		return 3  # World map


## Get cached world overview at specified LOD
## Returns pre-computed low-res overview for instant display
func get_cached_overview(lod_level: int) -> Image:
	if _lod_cache:
		return _lod_cache.get_cached_overview(lod_level)
	return null


## Pre-load world overview images for fast map display
## Call this after initialization if you need instant map display
func preload_world_overview() -> void:
	if _lod_cache and not _using_procedural:
		_lod_cache.preload_world_overview()


## Pre-load tiles around a spawn point for faster initial loading
## Requirements: 8.4
func preload_tiles_around(spawn_coord: Vector2i, radius: int = 2) -> void:
	if not _has_tiles:
		return
	
	print("TiledElevationProvider: Pre-loading tiles around %s (radius %d)" % [spawn_coord, radius])
	var loaded_count = 0
	
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tile_x = spawn_coord.x + dx
			var tile_y = spawn_coord.y + dy
			
			# Skip invalid tiles
			if tile_x < 0 or tile_x >= _tiles_x or tile_y < 0 or tile_y >= _tiles_y:
				continue
			
			var tile_key = "%d_%d" % [tile_x, tile_y]
			if not _tile_cache.has(tile_key):
				var data = _get_tile(tile_key)
				if not data.is_empty():
					loaded_count += 1
	
	print("TiledElevationProvider: Pre-loaded %d tiles" % loaded_count)


## Get tile coordinate for a world position
func get_tile_coord_for_world_pos(world_pos: Vector2) -> Vector2i:
	var uv = _world_to_uv(world_pos)
	var px = int(uv.x * (_source_width - 1))
	var py = int(uv.y * (_source_height - 1))
	
	@warning_ignore("integer_division")
	var tile_x = px / _tile_size
	@warning_ignore("integer_division")
	var tile_y = py / _tile_size
	
	return Vector2i(tile_x, tile_y)


# Compatibility methods for existing code

func get_vertical_scale() -> float:
	return (MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH) / maxf(_max_value - _min_value, 0.001)


func get_mariana_depth() -> float:
	return MARIANA_TRENCH_DEPTH


func get_everest_height() -> float:
	return MOUNT_EVEREST_HEIGHT


func is_using_procedural() -> bool:
	return _using_procedural


func get_map_dimensions() -> Vector2i:
	return Vector2i(_source_width, _source_height)


func get_cache_stats() -> Dictionary:
	var tile_memory = _tile_cache.size() * _tile_size * _tile_size * 2 / 1048576.0
	var lod_memory = 0.0
	if _lod_cache:
		# Estimate LOD cache memory (overview images)
		for lod in range(4):
			var res = 256 >> lod
			lod_memory += res * res * 4 / 1048576.0  # FORMAT_RF = 4 bytes per pixel
	
	return {
		"cached_tiles": _tile_cache.size(),
		"max_tiles": max_cached_tiles,
		"tile_memory_mb": tile_memory,
		"lod_memory_mb": lod_memory,
		"total_memory_mb": tile_memory + lod_memory,
		"has_tiles": _has_tiles,
		"using_procedural": _using_procedural
	}


func clear_cache() -> void:
	_tile_cache.clear()
	_tile_access_order.clear()
	if _lod_cache:
		_lod_cache.clear()


## Get tile info for debugging
func get_tile_info(tile_key: String) -> Dictionary:
	if not _metadata.has("tiles"):
		return {}
	return _metadata.get("tiles", {}).get(tile_key, {})


## Get all tile keys
func get_all_tile_keys() -> Array:
	if not _metadata.has("tiles"):
		return []
	return _metadata.get("tiles", {}).keys()
