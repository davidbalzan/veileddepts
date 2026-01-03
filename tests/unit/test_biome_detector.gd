extends GutTest

## Unit tests for BiomeDetector
## Tests biome classification logic and texture parameter assignment

var biome_detector: BiomeDetector


func before_each():
	biome_detector = BiomeDetector.new()


func after_each():
	biome_detector.free()


## Test that BiomeDetector can be instantiated
func test_biome_detector_instantiation():
	assert_not_null(biome_detector, "BiomeDetector should instantiate")


## Test deep water classification
func test_deep_water_classification():
	var elevation: float = -100.0  # 100m below sea level
	var slope: float = 0.1
	var sea_level: float = 0.0

	var biome: int = biome_detector.get_biome(elevation, slope, sea_level)

	assert_eq(biome, BiomeType.Type.DEEP_WATER, "Should classify as deep water")


## Test shallow water classification
func test_shallow_water_classification():
	var elevation: float = -20.0  # 20m below sea level (< 50m threshold)
	var slope: float = 0.1
	var sea_level: float = 0.0

	var biome: int = biome_detector.get_biome(elevation, slope, sea_level)

	assert_eq(biome, BiomeType.Type.SHALLOW_WATER, "Should classify as shallow water")


## Test beach classification (gentle slope near sea level)
func test_beach_classification():
	var elevation: float = 2.0  # Just above sea level
	var slope: float = 0.2  # Less than beach_slope_threshold (0.3)
	var sea_level: float = 0.0

	var biome: int = biome_detector.get_biome(elevation, slope, sea_level)

	assert_eq(biome, BiomeType.Type.BEACH, "Should classify as beach")


## Test cliff classification (steep slope near sea level)
func test_cliff_classification():
	var elevation: float = 5.0  # Near sea level
	var slope: float = 0.7  # Greater than cliff_slope_threshold (0.6)
	var sea_level: float = 0.0

	var biome: int = biome_detector.get_biome(elevation, slope, sea_level)

	assert_eq(biome, BiomeType.Type.CLIFF, "Should classify as cliff")


## Test grass classification
func test_grass_classification():
	var elevation: float = 500.0  # Above sea level, below grass_max_elevation
	var slope: float = 0.3  # Moderate slope
	var sea_level: float = 0.0

	var biome: int = biome_detector.get_biome(elevation, slope, sea_level)

	assert_eq(biome, BiomeType.Type.GRASS, "Should classify as grass")


## Test rock classification (steep slope)
func test_rock_classification_steep():
	var elevation: float = 1500.0  # Mid elevation
	var slope: float = 0.7  # Steep slope
	var sea_level: float = 0.0

	var biome: int = biome_detector.get_biome(elevation, slope, sea_level)

	assert_eq(biome, BiomeType.Type.ROCK, "Should classify as rock due to steep slope")


## Test snow classification
func test_snow_classification():
	var elevation: float = 3500.0  # Above snow_min_elevation (3000m)
	var slope: float = 0.3
	var sea_level: float = 0.0

	var biome: int = biome_detector.get_biome(elevation, slope, sea_level)

	assert_eq(biome, BiomeType.Type.SNOW, "Should classify as snow")


## Test that shallow water is lighter than deep water
func test_shallow_water_lighter_than_deep():
	var shallow_params: BiomeTextureParams = biome_detector.get_biome_texture(
		BiomeType.Type.SHALLOW_WATER
	)
	var deep_params: BiomeTextureParams = biome_detector.get_biome_texture(
		BiomeType.Type.DEEP_WATER
	)

	# Calculate brightness (simple average of RGB)
	var shallow_brightness: float = (
		(
			shallow_params.albedo_color.r
			+ shallow_params.albedo_color.g
			+ shallow_params.albedo_color.b
		)
		/ 3.0
	)
	var deep_brightness: float = (
		(deep_params.albedo_color.r + deep_params.albedo_color.g + deep_params.albedo_color.b) / 3.0
	)

	assert_gt(
		shallow_brightness, deep_brightness, "Shallow water should be lighter than deep water"
	)


## Test beach texture is sand-colored
func test_beach_texture_sand_colored():
	var beach_params: BiomeTextureParams = biome_detector.get_biome_texture(BiomeType.Type.BEACH)

	# Sand should be yellowish (high red and green, lower blue)
	assert_gt(beach_params.albedo_color.r, 0.7, "Beach should have high red component")
	assert_gt(beach_params.albedo_color.g, 0.7, "Beach should have high green component")
	assert_lt(
		beach_params.albedo_color.b,
		beach_params.albedo_color.r,
		"Beach should have less blue than red"
	)


## Test cliff texture is rock-colored
func test_cliff_texture_rock_colored():
	var cliff_params: BiomeTextureParams = biome_detector.get_biome_texture(BiomeType.Type.CLIFF)

	# Rock should be grayish/brownish (moderate RGB values, relatively balanced)
	assert_gt(cliff_params.albedo_color.r, 0.2, "Cliff should not be too dark")
	assert_lt(cliff_params.albedo_color.r, 0.6, "Cliff should not be too bright")


## Test detect_biomes creates valid biome map
func test_detect_biomes_creates_map():
	# Create a simple test heightmap
	var heightmap: Image = Image.create(16, 16, false, Image.FORMAT_RF)

	# Fill with varying elevations
	for y in range(16):
		for x in range(16):
			var elevation: float = -50.0 + (y * 10.0)  # Gradient from -50 to 100
			heightmap.set_pixel(x, y, Color(elevation, 0, 0, 1))

	var biome_map: Image = biome_detector.detect_biomes(heightmap, 0.0)

	assert_not_null(biome_map, "Should create biome map")
	assert_eq(biome_map.get_width(), 16, "Biome map should have same width as heightmap")
	assert_eq(biome_map.get_height(), 16, "Biome map should have same height as heightmap")


## Test detect_biomes handles null heightmap
func test_detect_biomes_null_heightmap():
	# Expect an error to be logged
	gut.ignore_error_string("BiomeDetector: heightmap is null")

	var biome_map: Image = biome_detector.detect_biomes(null, 0.0)

	assert_null(biome_map, "Should return null for null heightmap")


## Test get_biome_texture returns valid params for all biome types
func test_get_biome_texture_all_types():
	for biome_type in BiomeType.Type.values():
		var params: BiomeTextureParams = biome_detector.get_biome_texture(biome_type)

		assert_not_null(params, "Should return params for biome type %d" % biome_type)
		assert_not_null(
			params.albedo_color, "Should have albedo color for biome type %d" % biome_type
		)
