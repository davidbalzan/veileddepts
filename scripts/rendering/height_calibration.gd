class_name HeightCalibration extends RefCounted
## Height calibration system for terrain elevation data
##
## Scans heightmap data to find min/max pixel values and maps them to
## real-world reference points (Mariana Trench and Mount Everest).
## Stores calibration data for runtime use.
##
## Requirements: 7.4

## Real-world reference points
const MARIANA_TRENCH_DEPTH: float = -10994.0  # meters
const MOUNT_EVEREST_HEIGHT: float = 8849.0    # meters

## Calibration data
var min_pixel_value: float = 0.0
var max_pixel_value: float = 1.0
var min_elevation_meters: float = MARIANA_TRENCH_DEPTH
var max_elevation_meters: float = MOUNT_EVEREST_HEIGHT
var is_calibrated: bool = false

## Optional sea level offset for fine-tuning
var sea_level_offset_meters: float = 0.0


## Create a new calibration from heightmap analysis
## @param heightmap: The source heightmap to analyze
## @return: HeightCalibration instance with calibrated values
static func from_heightmap(heightmap: Image) -> HeightCalibration:
	if not heightmap:
		push_error("HeightCalibration: Cannot calibrate from null heightmap")
		return null
	
	var calibration = HeightCalibration.new()
	calibration._scan_heightmap(heightmap)
	calibration.is_calibrated = true
	
	return calibration


## Create a calibration from saved data
## @param data: Dictionary containing calibration values
## @return: HeightCalibration instance
static func from_dict(data: Dictionary) -> HeightCalibration:
	var calibration = HeightCalibration.new()
	
	calibration.min_pixel_value = data.get("min_pixel_value", 0.0)
	calibration.max_pixel_value = data.get("max_pixel_value", 1.0)
	calibration.min_elevation_meters = data.get("min_elevation_meters", MARIANA_TRENCH_DEPTH)
	calibration.max_elevation_meters = data.get("max_elevation_meters", MOUNT_EVEREST_HEIGHT)
	calibration.sea_level_offset_meters = data.get("sea_level_offset_meters", 0.0)
	calibration.is_calibrated = data.get("is_calibrated", false)
	
	return calibration


## Convert calibration to dictionary for saving
## @return: Dictionary containing all calibration values
func to_dict() -> Dictionary:
	return {
		"min_pixel_value": min_pixel_value,
		"max_pixel_value": max_pixel_value,
		"min_elevation_meters": min_elevation_meters,
		"max_elevation_meters": max_elevation_meters,
		"sea_level_offset_meters": sea_level_offset_meters,
		"is_calibrated": is_calibrated,
		"calibration_version": 1
	}


## Scan heightmap to find min/max pixel values
## @param heightmap: The heightmap to scan
func _scan_heightmap(heightmap: Image) -> void:
	var width = heightmap.get_width()
	var height = heightmap.get_height()
	
	var min_val = 1.0
	var max_val = 0.0
	
	print("HeightCalibration: Scanning heightmap %dx%d..." % [width, height])
	
	# Sample every pixel to find true min/max
	for y in range(height):
		for x in range(width):
			var pixel = heightmap.get_pixel(x, y)
			# Use luminance for grayscale conversion
			var value = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			
			min_val = minf(min_val, value)
			max_val = maxf(max_val, value)
	
	min_pixel_value = min_val
	max_pixel_value = max_val
	
	print("HeightCalibration: Found pixel range [%.6f, %.6f]" % [min_pixel_value, max_pixel_value])
	print("HeightCalibration: Mapped to elevation range [%.1fm, %.1fm]" % [
		min_elevation_meters,
		max_elevation_meters
	])


## Convert pixel value to elevation in meters
## @param pixel_value: Normalized pixel value (0.0-1.0)
## @return: Elevation in meters
func pixel_to_elevation(pixel_value: float) -> float:
	if not is_calibrated:
		push_warning("HeightCalibration: Using uncalibrated conversion")
	
	# Normalize pixel value to 0-1 range based on actual min/max
	var normalized = inverse_lerp(min_pixel_value, max_pixel_value, pixel_value)
	
	# Map to elevation range
	var elevation = lerp(min_elevation_meters, max_elevation_meters, normalized)
	
	# Apply sea level offset
	return elevation + sea_level_offset_meters


## Convert elevation in meters to pixel value
## @param elevation_meters: Elevation in meters
## @return: Normalized pixel value (0.0-1.0)
func elevation_to_pixel(elevation_meters: float) -> float:
	if not is_calibrated:
		push_warning("HeightCalibration: Using uncalibrated conversion")
	
	# Remove sea level offset
	var adjusted_elevation = elevation_meters - sea_level_offset_meters
	
	# Normalize elevation to 0-1 range
	var normalized = inverse_lerp(min_elevation_meters, max_elevation_meters, adjusted_elevation)
	
	# Map to pixel value range
	return lerp(min_pixel_value, max_pixel_value, normalized)


## Get the elevation range in meters
## @return: Vector2 with x=min, y=max elevation
func get_elevation_range() -> Vector2:
	return Vector2(
		min_elevation_meters + sea_level_offset_meters,
		max_elevation_meters + sea_level_offset_meters
	)


## Get the pixel value range
## @return: Vector2 with x=min, y=max pixel value
func get_pixel_range() -> Vector2:
	return Vector2(min_pixel_value, max_pixel_value)


## Set sea level offset for fine-tuning
## @param offset_meters: Offset in meters (positive = raise sea level, negative = lower)
func set_sea_level_offset(offset_meters: float) -> void:
	sea_level_offset_meters = offset_meters
	print("HeightCalibration: Sea level offset set to %.1fm" % offset_meters)


## Get current sea level offset
## @return: Sea level offset in meters
func get_sea_level_offset() -> float:
	return sea_level_offset_meters


## Save calibration to file
## @param path: File path to save to (e.g., "user://terrain_calibration.cfg")
## @return: true if successful
func save_to_file(path: String) -> bool:
	var config = ConfigFile.new()
	
	var data = to_dict()
	for key in data.keys():
		config.set_value("calibration", key, data[key])
	
	var error = config.save(path)
	if error != OK:
		push_error("HeightCalibration: Failed to save calibration to %s: %d" % [path, error])
		return false
	
	print("HeightCalibration: Saved calibration to %s" % path)
	return true


## Load calibration from file
## @param path: File path to load from
## @return: HeightCalibration instance or null if failed
static func load_from_file(path: String) -> HeightCalibration:
	if not FileAccess.file_exists(path):
		print("HeightCalibration: No calibration file found at %s" % path)
		return null
	
	var config = ConfigFile.new()
	var error = config.load(path)
	if error != OK:
		push_error("HeightCalibration: Failed to load calibration from %s: %d" % [path, error])
		return null
	
	var data = {}
	for key in config.get_section_keys("calibration"):
		data[key] = config.get_value("calibration", key)
	
	var calibration = from_dict(data)
	print("HeightCalibration: Loaded calibration from %s" % path)
	print("  Pixel range: [%.6f, %.6f]" % [calibration.min_pixel_value, calibration.max_pixel_value])
	print("  Elevation range: [%.1fm, %.1fm]" % [calibration.min_elevation_meters, calibration.max_elevation_meters])
	print("  Sea level offset: %.1fm" % calibration.sea_level_offset_meters)
	
	return calibration


## Get a summary string of the calibration
## @return: Human-readable calibration summary
func get_summary() -> String:
	if not is_calibrated:
		return "Not calibrated"
	
	return "Pixel [%.6f, %.6f] → Elevation [%.1fm, %.1fm] (offset: %.1fm)" % [
		min_pixel_value,
		max_pixel_value,
		min_elevation_meters + sea_level_offset_meters,
		max_elevation_meters + sea_level_offset_meters,
		sea_level_offset_meters
	]
