class_name EarthScale
## Earth scale calculations for the World Elevation Map
## The full image covers the entire Earth surface

# Earth dimensions (in meters)
const EARTH_CIRCUMFERENCE_EQUATOR: float = 40075000.0  # 40,075 km
const EARTH_CIRCUMFERENCE_MERIDIAN: float = 40008000.0  # 40,008 km (pole to pole)
const EARTH_RADIUS: float = 6371000.0  # 6,371 km average radius

# Image covers full Earth, so:
# - Full image width = Earth circumference at equator = 40,075 km
# - Full image height = Earth circumference / 2 (pole to pole) = 20,004 km

const FULL_MAP_WIDTH_METERS: float = EARTH_CIRCUMFERENCE_EQUATOR  # 40,075 km
const FULL_MAP_HEIGHT_METERS: float = EARTH_CIRCUMFERENCE_MERIDIAN / 2.0  # 20,004 km

## Calculate the real-world size of a UV region in meters
## region: Rect2 with position and size in UV coordinates (0-1)
## Returns: Vector2 with width and height in meters
static func get_region_size_meters(region: Rect2) -> Vector2:
	return Vector2(
		region.size.x * FULL_MAP_WIDTH_METERS,
		region.size.y * FULL_MAP_HEIGHT_METERS
	)

## Calculate the terrain_size needed for a given UV region
## to maintain proper Earth scale
## region: Rect2 with position and size in UV coordinates (0-1)
## Returns: Vector2i terrain size in meters
static func get_terrain_size_for_region(region: Rect2) -> Vector2i:
	var size_meters = get_region_size_meters(region)
	return Vector2i(int(size_meters.x), int(size_meters.y))

## Get a region that covers a specific real-world area in meters
## centered at a UV position
## center_uv: Vector2 center position in UV coordinates (0-1)
## size_meters: Vector2 desired size in meters
## Returns: Rect2 UV region
static func get_region_for_size_meters(center_uv: Vector2, size_meters: Vector2) -> Rect2:
	var uv_width = size_meters.x / FULL_MAP_WIDTH_METERS
	var uv_height = size_meters.y / FULL_MAP_HEIGHT_METERS
	
	return Rect2(
		center_uv.x - uv_width / 2.0,
		center_uv.y - uv_height / 2.0,
		uv_width,
		uv_height
	)

## Get a square region of a specific size in km
## center_uv: Vector2 center position in UV coordinates (0-1)
## size_km: float size of the square region in kilometers
## Returns: Rect2 UV region (note: will be rectangular in UV space due to map projection)
static func get_square_region_km(center_uv: Vector2, size_km: float) -> Rect2:
	var size_meters = Vector2(size_km * 1000.0, size_km * 1000.0)
	return get_region_for_size_meters(center_uv, size_meters)

## Calculate what UV region size gives a specific terrain size in meters
## terrain_size_meters: desired terrain size (e.g., 2048 for 2km x 2km)
## Returns: Vector2 UV region size
static func get_uv_size_for_terrain(terrain_size_meters: float) -> Vector2:
	return Vector2(
		terrain_size_meters / FULL_MAP_WIDTH_METERS,
		terrain_size_meters / FULL_MAP_HEIGHT_METERS
	)

## Print scale information for debugging
static func print_scale_info(region: Rect2) -> void:
	var size_m = get_region_size_meters(region)
	print("=== Earth Scale Info ===")
	print("UV Region: position=(%.4f, %.4f) size=(%.4f, %.4f)" % [region.position.x, region.position.y, region.size.x, region.size.y])
	print("Real-world size: %.1f km x %.1f km" % [size_m.x / 1000.0, size_m.y / 1000.0])
	print("Full map: %.0f km x %.0f km" % [FULL_MAP_WIDTH_METERS / 1000.0, FULL_MAP_HEIGHT_METERS / 1000.0])
	print("Region covers: %.4f%% x %.4f%% of Earth" % [region.size.x * 100, region.size.y * 100])

## Example regions at Earth scale
## A 2km x 2km mission area would be:
## UV size = 2000 / 40075000 = 0.0000499 (very tiny!)
## 
## Current default region Rect2(0.25, 0.3, 0.1, 0.1) covers:
## Width: 0.1 * 40075 km = 4007.5 km
## Height: 0.1 * 20004 km = 2000.4 km
## This is HUGE - about the size of Western Europe!
##
## For a realistic submarine mission area of ~100km x 100km:
## UV size would be: 100000 / 40075000 = 0.0025
## Region: Rect2(center_x - 0.00125, center_y - 0.00125, 0.0025, 0.0025)
