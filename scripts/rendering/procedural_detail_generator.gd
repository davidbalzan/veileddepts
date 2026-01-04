class_name ProceduralDetailGenerator extends Node
## Generates fine-scale terrain detail that follows base elevation
##
## This class generates procedural detail using multi-octave noise,
## modulated by slope, curvature, and terrain characteristics.
## Detail characteristics change based on terrain features:
## - Steep slopes get rocky detail
## - Flat areas get enhanced detail to ensure visibility
## - Uses world-space coordinates for seamless chunk boundaries

# Detail configuration (MODIFIED VALUES for terrain visibility)
@export var detail_scale: float = 30.0  # meters - base amplitude of detail (was 2.0)
@export var detail_frequency: float = 0.02  # Lower frequency for larger features (was 0.05)
@export var detail_octaves: int = 4  # More octaves for natural variation (was 3)
@export var detail_contribution: float = 0.5  # 50% contribution (was implicit 0.1)

# Flat terrain enhancement parameters
@export var flat_terrain_threshold: float = 0.05  # 5% variation threshold
@export var flat_terrain_amplitude: float = 35.0  # 20-50m range, use 35m for flat areas

# Slope thresholds for detail characteristics
@export var steep_slope_threshold: float = 0.6  # radians - above this is "rocky"
@export var flat_slope_threshold: float = 0.2  # radians - below this is "sediment"

# Internal noise generator
var _noise: FastNoiseLite = null


func _ready() -> void:
	_initialize_noise()


## Initialize the noise generator with configured parameters
func _initialize_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = detail_octaves
	_noise.frequency = detail_frequency
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5


## Check if heightmap is flat (needs enhancement)
##
## A heightmap is considered flat if its value range is less than
## the flat_terrain_threshold (default 5%).
##
## @param heightmap: Heightmap image (FORMAT_RF with values 0-1)
## @return: True if terrain is flat and needs enhancement
func is_flat_terrain(heightmap: Image) -> bool:
	if not heightmap:
		return false
	
	var stats: Dictionary = get_heightmap_stats(heightmap)
	return stats.range < flat_terrain_threshold


## Get heightmap statistics for debugging and flat terrain detection
##
## Calculates min, max, range, and mean values from the heightmap.
##
## @param heightmap: Heightmap image (FORMAT_RF with values 0-1)
## @return: Dictionary with min_value, max_value, range, mean, is_flat
func get_heightmap_stats(heightmap: Image) -> Dictionary:
	var result: Dictionary = {
		"min_value": 1.0,
		"max_value": 0.0,
		"range": 0.0,
		"mean": 0.0,
		"is_flat": true
	}
	
	if not heightmap:
		return result
	
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()
	var total: float = 0.0
	var count: int = 0
	
	for y in range(height):
		for x in range(width):
			var value: float = heightmap.get_pixel(x, y).r
			result.min_value = min(result.min_value, value)
			result.max_value = max(result.max_value, value)
			total += value
			count += 1
	
	if count > 0:
		result.mean = total / float(count)
	
	result.range = result.max_value - result.min_value
	result.is_flat = result.range < flat_terrain_threshold
	
	return result



## Generate detail heightmap for a chunk
##
## Creates procedural detail that follows the base elevation data,
## modulated by slope and curvature. Uses world-space coordinates
## for seamless chunk boundaries.
##
## MODIFIED: Removed submarine_distance parameter - uses world-space coordinates
## for consistent detail regardless of submarine position.
##
## @param base_heightmap: Base elevation data (Image with FORMAT_RF)
## @param chunk_coord: Chunk coordinates (used for world-space positioning)
## @param chunk_size_meters: Size of the chunk in meters
## @return: Detail heightmap (Image with FORMAT_RF) or null on error
func generate_detail(
	base_heightmap: Image,
	chunk_coord: Vector2i,
	chunk_size_meters: float
) -> Image:
	if not base_heightmap:
		push_error("ProceduralDetailGenerator: base_heightmap is null")
		return null

	if not _noise:
		_initialize_noise()

	var width: int = base_heightmap.get_width()
	var height: int = base_heightmap.get_height()

	# Create detail heightmap with same format as base
	var detail_map: Image = Image.create(width, height, false, Image.FORMAT_RF)

	# Check if terrain is flat and needs aggressive enhancement
	var terrain_is_flat: bool = is_flat_terrain(base_heightmap)
	var base_amplitude: float = detail_scale
	
	# Apply aggressive enhancement for flat terrain
	if terrain_is_flat:
		base_amplitude = flat_terrain_amplitude
		print("ProceduralDetailGenerator: Flat terrain detected, using amplitude: ", base_amplitude)

	# Calculate world-space position of chunk corner (bottom-left)
	# This ensures that the same world position always generates the same noise value
	var chunk_world_x: float = float(chunk_coord.x) * chunk_size_meters
	var chunk_world_z: float = float(chunk_coord.y) * chunk_size_meters

	# Calculate world-space size of each pixel
	# For N pixels, we have N-1 intervals, so pixel_size = chunk_size / (N-1)
	# This ensures that the last pixel of one chunk aligns with the first pixel of the next
	var pixel_size: float = chunk_size_meters / float(width - 1) if width > 1 else chunk_size_meters

	# Generate detail for each pixel
	for y in range(height):
		for x in range(width):
			# Get base elevation
			var base_pixel: Color = base_heightmap.get_pixel(x, y)
			var base_elevation: float = base_pixel.r

			# Calculate slope at this point
			var slope: float = _calculate_slope(base_heightmap, x, y)

			# Calculate curvature (convex vs concave)
			var curvature: float = _calculate_curvature(base_heightmap, x, y)

			# Calculate world-space coordinates for this pixel
			# This ensures boundary consistency: the same world position
			# generates the same noise value regardless of which chunk it's in
			var world_x: float = chunk_world_x + (float(x) * pixel_size)
			var world_z: float = chunk_world_z + (float(y) * pixel_size)
			var noise_value: float = _noise.get_noise_2d(world_x, world_z)

			# Modulate amplitude based on slope
			var slope_modulation: float = _get_slope_modulation(slope)

			# Modulate amplitude based on curvature
			# Convex areas (ridges) get erosion (less detail)
			# Concave areas (valleys) get deposition (more detail)
			var curvature_modulation: float = 1.0 + curvature * 0.5

			# Calculate final detail amplitude
			var amplitude: float = base_amplitude * slope_modulation * curvature_modulation

			# Apply detail contribution factor (50% of total height range)
			# The detail is added as a percentage of the amplitude
			var detail_value: float = noise_value * amplitude * detail_contribution

			# Apply detail to base elevation
			var detail_elevation: float = base_elevation + detail_value

			# Store in detail map
			detail_map.set_pixel(x, y, Color(detail_elevation, 0, 0, 1))

	return detail_map


## Generate bump map (normal map) from detailed heightmap
##
## Creates a normal map that can be used for bump mapping to simulate
## surface detail without adding geometry.
##
## @param base_heightmap: Base elevation data (Image with FORMAT_RF)
## @param _chunk_coord: Chunk coordinates (unused, kept for API consistency)
## @return: Bump map (Image with FORMAT_RGBA8) or null on error
func generate_bump_map(base_heightmap: Image, _chunk_coord: Vector2i) -> Image:
	if not base_heightmap:
		push_error("ProceduralDetailGenerator: base_heightmap is null")
		return null

	var width: int = base_heightmap.get_width()
	var height: int = base_heightmap.get_height()

	# Create bump map (normal map)
	var bump_map: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	# Generate normals from heightmap
	for y in range(height):
		for x in range(width):
			# Calculate normal using Sobel operator
			var normal: Vector3 = _calculate_normal(base_heightmap, x, y)

			# Convert normal from [-1, 1] to [0, 1] for storage
			var normal_color: Color = Color(
				(normal.x + 1.0) * 0.5, (normal.y + 1.0) * 0.5, (normal.z + 1.0) * 0.5, 1.0
			)

			bump_map.set_pixel(x, y, normal_color)

	return bump_map


## Calculate slope at a pixel using central differences
##
## @param heightmap: Heightmap image
## @param x: X coordinate
## @param y: Y coordinate
## @return: Slope in radians
func _calculate_slope(heightmap: Image, x: int, y: int) -> float:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Get neighboring heights with boundary clamping
	var x_prev: int = max(0, x - 1)
	var x_next: int = min(width - 1, x + 1)
	var y_prev: int = max(0, y - 1)
	var y_next: int = min(height - 1, y + 1)

	var h_left: float = heightmap.get_pixel(x_prev, y).r
	var h_right: float = heightmap.get_pixel(x_next, y).r
	var h_up: float = heightmap.get_pixel(x, y_prev).r
	var h_down: float = heightmap.get_pixel(x, y_next).r

	# Calculate gradients
	var dx: float = (h_right - h_left) / 2.0
	var dy: float = (h_down - h_up) / 2.0

	# Calculate slope magnitude
	var slope: float = sqrt(dx * dx + dy * dy)

	return atan(slope)


## Calculate curvature at a pixel
##
## Positive curvature = convex (ridge)
## Negative curvature = concave (valley)
##
## @param heightmap: Heightmap image
## @param x: X coordinate
## @param y: Y coordinate
## @return: Curvature value (approximately -1 to 1)
func _calculate_curvature(heightmap: Image, x: int, y: int) -> float:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Get neighboring heights with boundary clamping
	var x_prev: int = max(0, x - 1)
	var x_next: int = min(width - 1, x + 1)
	var y_prev: int = max(0, y - 1)
	var y_next: int = min(height - 1, y + 1)

	var h_center: float = heightmap.get_pixel(x, y).r
	var h_left: float = heightmap.get_pixel(x_prev, y).r
	var h_right: float = heightmap.get_pixel(x_next, y).r
	var h_up: float = heightmap.get_pixel(x, y_prev).r
	var h_down: float = heightmap.get_pixel(x, y_next).r

	# Calculate second derivatives (Laplacian)
	var d2x: float = h_left - 2.0 * h_center + h_right
	var d2y: float = h_up - 2.0 * h_center + h_down

	# Average curvature
	var curvature: float = (d2x + d2y) / 2.0

	# Clamp to reasonable range
	return clamp(curvature * 10.0, -1.0, 1.0)


## Get slope modulation factor for detail amplitude
##
## Steep slopes get rocky detail (higher amplitude)
## Flat areas get sediment detail (lower amplitude)
##
## @param slope: Slope in radians
## @return: Modulation factor (0.5 to 2.0)
func _get_slope_modulation(slope: float) -> float:
	if slope > steep_slope_threshold:
		# Rocky detail - higher amplitude, sharper features
		return 2.0
	elif slope < flat_slope_threshold:
		# Sediment detail - lower amplitude, smoother features
		return 0.5
	else:
		# Transition zone - linear interpolation
		var t: float = (
			(slope - flat_slope_threshold) / (steep_slope_threshold - flat_slope_threshold)
		)
		return lerp(0.5, 2.0, t)


## Calculate normal vector at a pixel using Sobel operator
##
## @param heightmap: Heightmap image
## @param x: X coordinate
## @param y: Y coordinate
## @return: Normal vector (normalized)
func _calculate_normal(heightmap: Image, x: int, y: int) -> Vector3:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Get neighboring heights with boundary clamping
	var x_prev: int = max(0, x - 1)
	var x_next: int = min(width - 1, x + 1)
	var y_prev: int = max(0, y - 1)
	var y_next: int = min(height - 1, y + 1)

	# Sample 3x3 neighborhood for Sobel operator
	var h00: float = heightmap.get_pixel(x_prev, y_prev).r
	var h10: float = heightmap.get_pixel(x, y_prev).r
	var h20: float = heightmap.get_pixel(x_next, y_prev).r

	var h01: float = heightmap.get_pixel(x_prev, y).r
	var h21: float = heightmap.get_pixel(x_next, y).r

	var h02: float = heightmap.get_pixel(x_prev, y_next).r
	var h12: float = heightmap.get_pixel(x, y_next).r
	var h22: float = heightmap.get_pixel(x_next, y_next).r

	# Sobel operator for X gradient
	var dx: float = (h20 + 2.0 * h21 + h22) - (h00 + 2.0 * h01 + h02)

	# Sobel operator for Y gradient
	var dy: float = (h02 + 2.0 * h12 + h22) - (h00 + 2.0 * h10 + h20)

	# Calculate normal (cross product of tangent vectors)
	# Tangent X: (1, 0, dx)
	# Tangent Y: (0, 1, dy)
	# Normal: (-dx, -dy, 1)
	var normal: Vector3 = Vector3(-dx, -dy, 1.0)

	return normal.normalized()
