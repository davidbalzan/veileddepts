class_name TerrainRegions
## Predefined terrain regions for the world elevation map
## Use these constants to easily switch between different areas of the world

## Mediterranean Sea - Good mix of coastal areas and deep water
const MEDITERRANEAN = Rect2(0.25, 0.3, 0.1, 0.1)

## North Atlantic - Open ocean with varied depth
const NORTH_ATLANTIC = Rect2(0.2, 0.2, 0.15, 0.15)

## Pacific Ocean - Large open water area
const PACIFIC = Rect2(0.6, 0.3, 0.2, 0.2)

## Caribbean Sea - Island chains and shallow waters
const CARIBBEAN = Rect2(0.15, 0.35, 0.1, 0.1)

## Norwegian Sea - Deep fjords and coastal features
const NORWEGIAN_SEA = Rect2(0.52, 0.15, 0.08, 0.08)

## South China Sea - Complex coastal geography
const SOUTH_CHINA_SEA = Rect2(0.65, 0.4, 0.1, 0.1)

## Arctic Ocean - Polar region
const ARCTIC = Rect2(0.4, 0.05, 0.2, 0.1)

## Indian Ocean - Tropical waters
const INDIAN_OCEAN = Rect2(0.6, 0.5, 0.15, 0.15)

## Baltic Sea - Enclosed sea with varied depth
const BALTIC_SEA = Rect2(0.53, 0.22, 0.05, 0.05)

## Persian Gulf - Shallow waters
const PERSIAN_GULF = Rect2(0.58, 0.38, 0.05, 0.05)


## Get a region by name (case-insensitive)
static func get_region_by_name(region_name: String) -> Rect2:
	match region_name.to_lower():
		"mediterranean":
			return MEDITERRANEAN
		"north_atlantic", "atlantic":
			return NORTH_ATLANTIC
		"pacific":
			return PACIFIC
		"caribbean":
			return CARIBBEAN
		"norwegian_sea", "norwegian", "norway":
			return NORWEGIAN_SEA
		"south_china_sea", "south_china":
			return SOUTH_CHINA_SEA
		"arctic":
			return ARCTIC
		"indian_ocean", "indian":
			return INDIAN_OCEAN
		"baltic_sea", "baltic":
			return BALTIC_SEA
		"persian_gulf", "persian":
			return PERSIAN_GULF
		_:
			push_warning("Unknown region name: " + region_name + ", using Mediterranean")
			return MEDITERRANEAN


## Get all available region names
static func get_all_region_names() -> Array[String]:
	return [
		"Mediterranean",
		"North Atlantic",
		"Pacific",
		"Caribbean",
		"Norwegian Sea",
		"South China Sea",
		"Arctic",
		"Indian Ocean",
		"Baltic Sea",
		"Persian Gulf"
	]


## Get a random region
static func get_random_region() -> Rect2:
	var regions = [
		MEDITERRANEAN,
		NORTH_ATLANTIC,
		PACIFIC,
		CARIBBEAN,
		NORWEGIAN_SEA,
		SOUTH_CHINA_SEA,
		ARCTIC,
		INDIAN_OCEAN,
		BALTIC_SEA,
		PERSIAN_GULF
	]
	return regions[randi() % regions.size()]
