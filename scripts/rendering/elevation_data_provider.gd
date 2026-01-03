class_name ElevationDataProvider extends Node
## Provides elevation data from world map or procedural generation
##
## This class manages loading elevation data from the world elevation map,
## extracting regions, applying vertical scaling using known reference points
## (Mariana Trench and Mount Everest), and falling back to procedural generation
## when the map is unavailable.

# World elevation map configuration
@export var elevation_map_path: String = "res://src_assets/World_elevation_map.png"

# Vertical scaling reference points (in meters)
const MARIANA_TRENCH_DEPTH: float = -10994.0  # Deepest point on Earth
const MOUNT_EVEREST_HEIGHT: float = 8849.0  # Highest point on Earth

# Internal state
var _elevation_map: Image = null
var _map_width: int = 0
var _map_height: int = 0
var _min_pixel_value: float = 0.0
var _max_pixel_value: float = 1.0
var _vertical_scale: float = 1.0
var _initialized: bool = false
var _using_procedural: bool = false

# Procedural generation fallback
var _procedural_noise: FastNoiseLite = null


func _ready() -> void:
	# Initialize is called explicitly, not in _ready
	pass


## Initialize the elevation data provider
## Returns true if successful, false if fallback to procedural
func initialize() -> bool:
	if _initialized:
		return not _using_procedural

	# Try to load the world elevation map
	if _load_elevation_map():
		_initialized = true
		_using_procedural = false
		print("ElevationDataProvider: Initialized with world elevation map")
		print("  Map size: %d x %d pixels" % [_map_width, _map_height])
		print("  Vertical scale: %.2f m/pixel" % _vertical_scale)
		print(
			"  Min elevation: %.1f m (pixel value: %.3f)" % [MARIANA_TRENCH_DEPTH, _min_pixel_value]
		)
		print(
			"  Max elevation: %.1f m (pixel value: %.3f)" % [MOUNT_EVEREST_HEIGHT, _max_pixel_value]
		)
		return true
	else:
		# Fallback to procedural generation
		_setup_procedural_fallback()
		_initialized = true
		_using_procedural = true
		push_warning("ElevationDataProvider: Using procedural generation fallback")
		return false


## Load the world elevation map and scan for min/max values
func _load_elevation_map() -> bool:
	# Check if file exists
	if not FileAccess.file_exists(elevation_map_path):
		push_error("ElevationDataProvider: Elevation map not found at " + elevation_map_path)
		return false

	# Load the image using ResourceLoader for better export support
	var map_resource = load(elevation_map_path)
	if map_resource:
		if map_resource is Texture2D:
			_elevation_map = map_resource.get_image()
		elif map_resource is Image:
			_elevation_map = map_resource
		else:
			push_error("ElevationDataProvider: Loaded resource is not a Texture2D or Image")
			return false
	else:
		# Fallback to direct file loading if resource loading fails (e.g. not an asset)
		_elevation_map = Image.new()
		var error = _elevation_map.load(elevation_map_path)
		if error != OK:
			push_error("ElevationDataProvider: Failed to load elevation map: " + str(error))
			_elevation_map = null
			return false

	# Store dimensions (metadata only, image stays in memory for region extraction)
	_map_width = _elevation_map.get_width()
	_map_height = _elevation_map.get_height()

	# Scan for min/max pixel values to establish vertical scale
	_scan_for_reference_points()

	return true


## Scan the entire elevation map for min/max pixel values
## This establishes the vertical scale using Mariana Trench and Mount Everest
func _scan_for_reference_points() -> void:
	if not _elevation_map:
		return

	_min_pixel_value = 1.0
	_max_pixel_value = 0.0

	# Sample the image to find min/max
	# For large images, we can sample every Nth pixel for performance
	var sample_step = max(1, int(_map_width / 1024))  # Sample at most 1024x1024 points

	for y in range(0, _map_height, sample_step):
		for x in range(0, _map_width, sample_step):
			var pixel = _elevation_map.get_pixel(x, y)
			# Use luminance for grayscale conversion
			var value = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114

			_min_pixel_value = min(_min_pixel_value, value)
			_max_pixel_value = max(_max_pixel_value, value)

	# Calculate vertical scale factor
	# scale = (max_elevation - min_elevation) / (max_pixel - min_pixel)
	var elevation_range = MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH
	var pixel_range = _max_pixel_value - _min_pixel_value

	if pixel_range > 0.0:
		_vertical_scale = elevation_range / pixel_range
	else:
		_vertical_scale = 1.0
		push_warning("ElevationDataProvider: No pixel value variation found, using default scale")


## Setup procedural generation as fallback
func _setup_procedural_fallback() -> void:
	_procedural_noise = FastNoiseLite.new()
	_procedural_noise.seed = 12345
	_procedural_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_procedural_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_procedural_noise.fractal_octaves = 6
	_procedural_noise.frequency = 0.0001  # Low frequency for large-scale features
	_procedural_noise.fractal_lacunarity = 2.0
	_procedural_noise.fractal_gain = 0.5


## Get elevation at a specific world position (in meters)
## world_pos: Position in world coordinates (x, z)
## Returns: Elevation in meters
func get_elevation(world_pos: Vector2) -> float:
	if not _initialized:
		push_warning("ElevationDataProvider: Not initialized, returning 0")
		return 0.0

	if _using_procedural:
		return _get_procedural_elevation(world_pos)

	# Convert world position to UV coordinates (0-1)
	# This assumes the world map covers the entire Earth
	var uv = _world_to_uv(world_pos)

	# Sample the elevation map
	var pixel_value = _sample_elevation_map(uv)

	# Convert pixel value to elevation using linear interpolation
	return _pixel_to_elevation(pixel_value)


## Extract elevation data for a specific region
## world_bounds: Rectangle in world coordinates (meters)
## resolution: Output image resolution (width and height)
## Returns: Image containing elevation data for the region
func extract_region(world_bounds: Rect2, resolution: int) -> Image:
	if not _initialized:
		push_error("ElevationDataProvider: Not initialized")
		return null

	var region_image = Image.create(resolution, resolution, false, Image.FORMAT_RF)

	for y in range(resolution):
		for x in range(resolution):
			# Calculate world position for this pixel
			var world_x = world_bounds.position.x + (float(x) / resolution) * world_bounds.size.x
			var world_z = world_bounds.position.y + (float(y) / resolution) * world_bounds.size.y
			var world_pos = Vector2(world_x, world_z)

			# Get elevation at this position
			var elevation = get_elevation(world_pos)

			# Store as normalized value (0-1) for consistency
			var normalized = (
				(elevation - MARIANA_TRENCH_DEPTH) / (MOUNT_EVEREST_HEIGHT - MARIANA_TRENCH_DEPTH)
			)
			region_image.set_pixel(x, y, Color(normalized, 0, 0, 1))

	return region_image


## Convert world coordinates to UV coordinates (0-1)
## Assumes world map covers entire Earth using EarthScale constants
func _world_to_uv(world_pos: Vector2) -> Vector2:
	# For now, use a simple mapping
	# In a full implementation, this would use proper map projection
	var u = (world_pos.x / EarthScale.FULL_MAP_WIDTH_METERS) + 0.5
	var v = (world_pos.y / EarthScale.FULL_MAP_HEIGHT_METERS) + 0.5

	# Wrap/clamp to valid range
	u = fmod(u, 1.0)
	if u < 0.0:
		u += 1.0
	v = clamp(v, 0.0, 1.0)

	return Vector2(u, v)


## Sample the elevation map at UV coordinates with bilinear interpolation
func _sample_elevation_map(uv: Vector2) -> float:
	if not _elevation_map:
		return 0.5

	# Clamp UV to valid range
	uv.x = clamp(uv.x, 0.0, 1.0)
	uv.y = clamp(uv.y, 0.0, 1.0)

	# Convert UV to pixel coordinates
	var px = uv.x * (_map_width - 1)
	var py = uv.y * (_map_height - 1)

	var x0 = int(floor(px))
	var y0 = int(floor(py))
	var x1 = min(x0 + 1, _map_width - 1)
	var y1 = min(y0 + 1, _map_height - 1)

	var fx = px - x0
	var fy = py - y0

	# Sample four corners and convert to grayscale
	var p00 = _elevation_map.get_pixel(x0, y0)
	var p10 = _elevation_map.get_pixel(x1, y0)
	var p01 = _elevation_map.get_pixel(x0, y1)
	var p11 = _elevation_map.get_pixel(x1, y1)

	# Convert to luminance
	var v00 = p00.r * 0.299 + p00.g * 0.587 + p00.b * 0.114
	var v10 = p10.r * 0.299 + p10.g * 0.587 + p10.b * 0.114
	var v01 = p01.r * 0.299 + p01.g * 0.587 + p01.b * 0.114
	var v11 = p11.r * 0.299 + p11.g * 0.587 + p11.b * 0.114

	# Bilinear interpolation
	var v0 = lerp(v00, v10, fx)
	var v1 = lerp(v01, v11, fx)
	return lerp(v0, v1, fy)


## Convert pixel value (0-1) to elevation (meters) using linear interpolation
func _pixel_to_elevation(pixel_value: float) -> float:
	# Linear interpolation between Mariana Trench and Mount Everest
	var normalized = (pixel_value - _min_pixel_value) / (_max_pixel_value - _min_pixel_value)
	return lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, normalized)


## Get procedural elevation for fallback mode
func _get_procedural_elevation(world_pos: Vector2) -> float:
	if not _procedural_noise:
		return 0.0

	# Get noise value (-1 to 1)
	var noise_value = _procedural_noise.get_noise_2d(world_pos.x, world_pos.y)

	# Map to elevation range
	return lerp(MARIANA_TRENCH_DEPTH, MOUNT_EVEREST_HEIGHT, (noise_value + 1.0) / 2.0)


## Get the vertical scale factor (meters per pixel value)
func get_vertical_scale() -> float:
	return _vertical_scale


## Get Mariana Trench depth reference
func get_mariana_depth() -> float:
	return MARIANA_TRENCH_DEPTH


## Get Mount Everest height reference
func get_everest_height() -> float:
	return MOUNT_EVEREST_HEIGHT


## Check if using procedural generation fallback
func is_using_procedural() -> bool:
	return _using_procedural


## Get map dimensions (for debugging)
func get_map_dimensions() -> Vector2i:
	return Vector2i(_map_width, _map_height)
