## BiomeType enum for terrain classification
##
## Defines the different biome types that can be detected in terrain.
## Used for texture assignment and rendering characteristics.

class_name BiomeType

enum Type { DEEP_WATER, SHALLOW_WATER, BEACH, CLIFF, GRASS, ROCK, SNOW }  ## Below sea level, depth > 50m  ## Below sea level, depth < 50m  ## Coastal, slope < 0.3 rad  ## Coastal, slope > 0.6 rad  ## Above sea level, low elevation, gentle slope  ## Above sea level, steep slope or high elevation  ## Above sea level, very high elevation
