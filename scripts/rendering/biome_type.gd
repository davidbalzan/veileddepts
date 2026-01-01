## BiomeType enum for terrain classification
##
## Defines the different biome types that can be detected in terrain.
## Used for texture assignment and rendering characteristics.

class_name BiomeType

enum Type {
	DEEP_WATER,      ## Below sea level, depth > 50m
	SHALLOW_WATER,   ## Below sea level, depth < 50m
	BEACH,           ## Coastal, slope < 0.3 rad
	CLIFF,           ## Coastal, slope > 0.6 rad
	GRASS,           ## Above sea level, low elevation, gentle slope
	ROCK,            ## Above sea level, steep slope or high elevation
	SNOW             ## Above sea level, very high elevation
}
