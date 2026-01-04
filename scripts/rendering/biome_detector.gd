## BiomeDetector class for terrain biome classification
##
## Analyzes terrain heightmaps to detect and classify biomes based on
## elevation and slope. Applies smoothing to prevent biome noise.
## Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6
## Dynamic Sea Level: Requirements 3.1, 3.2, 3.3, 3.4

class_name BiomeDetector extends Node

## Biome classification thresholds
@export var beach_slope_threshold: float = 0.3  # radians (~17 degrees)
@export var cliff_slope_threshold: float = 0.6  # radians (~34 degrees)
@export var shallow_water_depth: float = 50.0  # meters (changed from 10.0 to match design)
@export var sea_level: float = 0.0  # meters (deprecated - use SeaLevelManager instead)

## Elevation thresholds for above-water biomes
@export var grass_max_elevation: float = 1000.0  # meters
@export var snow_min_elevation: float = 3000.0  # meters

## Smoothing configuration
@export var smoothing_enabled: bool = true
@export var smoothing_radius: int = 1  # pixels


## Detect biomes in a heightmap and return a biome map
##
## @param heightmap: The terrain heightmap to analyze
## @param sea_level_override: Optional sea level override (uses SeaLevelManager if not provided)
## @return: Image containing biome type IDs (one byte per pixel)
func detect_biomes(heightmap: Image, sea_level_override: float = NAN) -> Image:
	if not heightmap:
		push_error("BiomeDetector: heightmap is null")
		return null

	# Determine effective sea level
	var effective_sea_level_meters: float
	if not is_nan(sea_level_override):
		# Use override if provided (backward compatibility)
		effective_sea_level_meters = sea_level_override
	else:
		# Query SeaLevelManager for current sea level
		if SeaLevelManager:
			effective_sea_level_meters = SeaLevelManager.get_sea_level_meters()
		else:
			# Fallback to exported sea_level if manager not available
			push_warning("BiomeDetector: SeaLevelManager not available, using exported sea_level")
			effective_sea_level_meters = sea_level

	var _width: int = heightmap.get_width()
	var _height: int = heightmap.get_height()

	# Create biome map (FORMAT_R8 for single byte per pixel)
	var biome_map: Image = Image.create(_width, _height, false, Image.FORMAT_R8)

	# First pass: classify each pixel
	for y in range(_height):
		for x in range(_width):
			var elevation: float = _get_height_at(heightmap, x, y)
			var slope: float = _calculate_slope(heightmap, x, y)
			var biome: int = get_biome(elevation, slope, effective_sea_level_meters)

			# Store biome ID as byte value
			biome_map.set_pixel(x, y, Color(biome / 255.0, 0, 0, 1))

	# Second pass: apply smoothing filter if enabled
	if smoothing_enabled:
		biome_map = _apply_smoothing(biome_map)

	return biome_map


## Get biome type for a specific elevation and slope
##
## @param elevation: Height in meters (negative = underwater)
## @param slope: Slope in radians
## @param sea_level_value: Sea level in meters (optional, uses SeaLevelManager if NAN)
## @return: BiomeType.Type enum value
func get_biome(elevation: float, slope: float, sea_level_value: float = NAN) -> int:
	# Determine effective sea level
	var effective_sea_level: float
	if not is_nan(sea_level_value):
		effective_sea_level = sea_level_value
	else:
		# Query SeaLevelManager for current sea level
		if SeaLevelManager:
			effective_sea_level = SeaLevelManager.get_sea_level_meters()
		else:
			# Fallback to exported sea_level if manager not available
			effective_sea_level = sea_level
	
	var depth: float = effective_sea_level - elevation

	# Underwater biomes
	if elevation < effective_sea_level:
		if depth > shallow_water_depth:
			return BiomeType.Type.DEEP_WATER
		else:
			return BiomeType.Type.SHALLOW_WATER

	# Coastal biomes (near sea level)
	var coastal_threshold: float = 10.0  # meters above sea level
	if elevation < effective_sea_level + coastal_threshold:
		if slope < beach_slope_threshold:
			return BiomeType.Type.BEACH
		elif slope > cliff_slope_threshold:
			return BiomeType.Type.CLIFF
		else:
			# Moderate slope coastal area - treat as beach
			return BiomeType.Type.BEACH

	# Above-water biomes
	if elevation > snow_min_elevation:
		return BiomeType.Type.SNOW
	elif slope > cliff_slope_threshold:
		return BiomeType.Type.ROCK
	elif elevation < grass_max_elevation:
		return BiomeType.Type.GRASS
	else:
		return BiomeType.Type.ROCK


## Get texture parameters for a biome type
##
## @param biome: BiomeType.Type enum value
## @return: BiomeTextureParams resource with rendering properties
func get_biome_texture(biome: int) -> BiomeTextureParams:
	var params: BiomeTextureParams = BiomeTextureParams.new()

	match biome:
		BiomeType.Type.DEEP_WATER:
			params.albedo_color = Color(0.0, 0.1, 0.3, 1.0)  # Dark blue
			params.roughness = 0.1
			params.metallic = 0.0
			params.normal_strength = 0.5

		BiomeType.Type.SHALLOW_WATER:
			params.albedo_color = Color(0.2, 0.5, 0.7, 1.0)  # Light blue
			params.roughness = 0.1
			params.metallic = 0.0
			params.normal_strength = 0.3

		BiomeType.Type.BEACH:
			params.albedo_color = Color(0.9, 0.85, 0.6, 1.0)  # Sand color
			params.roughness = 0.8
			params.metallic = 0.0
			params.normal_strength = 1.0

		BiomeType.Type.CLIFF:
			params.albedo_color = Color(0.4, 0.35, 0.3, 1.0)  # Dark rock
			params.roughness = 0.9
			params.metallic = 0.0
			params.normal_strength = 1.5

		BiomeType.Type.GRASS:
			params.albedo_color = Color(0.3, 0.6, 0.2, 1.0)  # Green
			params.roughness = 0.7
			params.metallic = 0.0
			params.normal_strength = 0.8

		BiomeType.Type.ROCK:
			params.albedo_color = Color(0.5, 0.45, 0.4, 1.0)  # Gray rock
			params.roughness = 0.85
			params.metallic = 0.0
			params.normal_strength = 1.2

		BiomeType.Type.SNOW:
			params.albedo_color = Color(0.95, 0.95, 1.0, 1.0)  # White snow
			params.roughness = 0.3
			params.metallic = 0.0
			params.normal_strength = 0.5

		_:
			# Default to grass
			params.albedo_color = Color(0.3, 0.6, 0.2, 1.0)
			params.roughness = 0.7
			params.metallic = 0.0
			params.normal_strength = 0.8

	return params


## Get height value from heightmap at pixel coordinates
## Handles edge cases by clamping coordinates
func _get_height_at(heightmap: Image, x: int, y: int) -> float:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Clamp coordinates to valid range
	x = clampi(x, 0, width - 1)
	y = clampi(y, 0, height - 1)

	var color: Color = heightmap.get_pixel(x, y)
	# Assuming heightmap stores elevation in red channel
	return color.r


## Calculate slope at a pixel using central differences
## Returns slope in radians
func _calculate_slope(heightmap: Image, x: int, y: int) -> float:
	var _width: int = heightmap.get_width()
	var _height: int = heightmap.get_height()

	# Get neighboring heights
	var _h_center: float = _get_height_at(heightmap, x, y)
	var h_left: float = _get_height_at(heightmap, x - 1, y)
	var h_right: float = _get_height_at(heightmap, x + 1, y)
	var h_up: float = _get_height_at(heightmap, x, y - 1)
	var h_down: float = _get_height_at(heightmap, x, y + 1)

	# Calculate gradients (assuming 1 meter per pixel for simplicity)
	var dx: float = (h_right - h_left) / 2.0
	var dy: float = (h_down - h_up) / 2.0

	# Calculate slope magnitude
	var slope_magnitude: float = sqrt(dx * dx + dy * dy)

	# Convert to angle in radians
	return atan(slope_magnitude)


## Apply smoothing filter to reduce biome noise
## Uses majority voting in a neighborhood
func _apply_smoothing(biome_map: Image) -> Image:
	var width: int = biome_map.get_width()
	var height: int = biome_map.get_height()

	var smoothed: Image = Image.create(width, height, false, Image.FORMAT_R8)

	for y in range(height):
		for x in range(width):
			var biome: int = _get_majority_biome(biome_map, x, y)
			smoothed.set_pixel(x, y, Color(biome / 255.0, 0, 0, 1))

	return smoothed


## Get the majority biome in a neighborhood around a pixel
func _get_majority_biome(biome_map: Image, x: int, y: int) -> int:
	var width: int = biome_map.get_width()
	var height: int = biome_map.get_height()

	# Count occurrences of each biome type
	var counts: Dictionary = {}

	for dy in range(-smoothing_radius, smoothing_radius + 1):
		for dx in range(-smoothing_radius, smoothing_radius + 1):
			var nx: int = clampi(x + dx, 0, width - 1)
			var ny: int = clampi(y + dy, 0, height - 1)

			var color: Color = biome_map.get_pixel(nx, ny)
			var biome: int = int(color.r * 255.0)

			if not counts.has(biome):
				counts[biome] = 0
			counts[biome] += 1

	# Find biome with highest count
	var max_count: int = 0
	var majority_biome: int = 0

	for biome in counts:
		if counts[biome] > max_count:
			max_count = counts[biome]
			majority_biome = biome

	return majority_biome


## Alias for detect_biomes (for ChunkManager compatibility)
func classify_terrain(heightmap: Image) -> Image:
	return detect_biomes(heightmap)
