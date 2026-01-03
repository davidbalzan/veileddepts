## UnderwaterFeatureDetector class for detecting and preserving underwater terrain features
##
## Responsible for:
## - Detecting trenches, ridges, and seamounts in heightmaps
## - Marking important feature vertices for LOD preservation
## - Analyzing terrain curvature and depth variations
## - Supporting feature-aware LOD mesh generation

class_name UnderwaterFeatureDetector extends Node

## Feature detection thresholds
@export var trench_depth_threshold: float = -1000.0  # meters below sea level
@export var ridge_prominence_threshold: float = 500.0  # meters of elevation change
@export var seamount_height_threshold: float = 1000.0  # meters of rise from seafloor
@export var feature_curvature_threshold: float = 0.1  # curvature threshold for feature detection

## Sea level reference
@export var sea_level: float = 0.0

## Underwater feature types
enum FeatureType { NONE, TRENCH, RIDGE, SEAMOUNT, ABYSSAL_PLAIN }  # Deep underwater valley  # Underwater mountain range  # Underwater mountain  # Flat deep ocean floor


## Feature information for a heightmap region
class FeatureInfo:
	var feature_type: FeatureType = FeatureType.NONE
	var importance: float = 0.0  # 0.0 to 1.0, higher = more important to preserve
	var center_position: Vector2i = Vector2i.ZERO
	var extent: Rect2i = Rect2i()


## Detect underwater features in a heightmap
##
## Analyzes the heightmap to identify trenches, ridges, seamounts, and other
## significant underwater terrain features.
##
## @param heightmap: Height data to analyze
## @return: Array of FeatureInfo objects describing detected features
func detect_features(heightmap: Image) -> Array[FeatureInfo]:
	if not heightmap:
		return []

	var features: Array[FeatureInfo] = []
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Create curvature map for feature detection
	var curvature_map: Array = _calculate_curvature_map(heightmap)

	# Scan for features using a sliding window approach
	var window_size: int = max(8, min(width, height) / 8)
	var step: int = window_size / 2

	for y in range(0, height - window_size, step):
		for x in range(0, width - window_size, step):
			var region: Rect2i = Rect2i(x, y, window_size, window_size)
			var feature: FeatureInfo = _analyze_region(heightmap, curvature_map, region)

			if feature and feature.feature_type != FeatureType.NONE:
				features.append(feature)

	# Merge overlapping features
	features = _merge_overlapping_features(features)

	return features


## Create a feature importance map for LOD preservation
##
## Generates a 2D map where each pixel indicates how important that vertex is
## for preserving terrain features. Higher values mean the vertex should be
## preserved at lower LOD levels.
##
## @param heightmap: Height data to analyze
## @param features: Detected features from detect_features()
## @return: Image with importance values (0.0 to 1.0 in red channel)
func create_importance_map(heightmap: Image, features: Array[FeatureInfo]) -> Image:
	if not heightmap:
		return null

	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Create importance map (grayscale, 0.0 = not important, 1.0 = very important)
	var importance_map: Image = Image.create(width, height, false, Image.FORMAT_RF)
	importance_map.fill(Color(0.0, 0.0, 0.0, 1.0))

	# Calculate base importance from curvature
	var curvature_map: Array = _calculate_curvature_map(heightmap)

	for y in range(height):
		for x in range(width):
			var curvature: float = curvature_map[y * width + x]
			var base_importance: float = clamp(
				abs(curvature) / feature_curvature_threshold, 0.0, 0.5
			)
			importance_map.set_pixel(x, y, Color(base_importance, 0.0, 0.0, 1.0))

	# Boost importance for detected features
	for feature in features:
		_apply_feature_importance(importance_map, feature)

	return importance_map


## Get important vertices for a specific LOD level
##
## Returns a list of vertex indices that should be preserved at the given LOD level
## based on feature importance.
##
## @param importance_map: Importance map from create_importance_map()
## @param lod_level: LOD level (0 = highest detail, higher = lower detail)
## @param base_resolution: Base heightmap resolution
## @return: Array of Vector2i vertex positions to preserve
func get_important_vertices(
	importance_map: Image, lod_level: int, base_resolution: int
) -> Array[Vector2i]:
	if not importance_map:
		return []

	var important_vertices: Array[Vector2i] = []

	# Calculate importance threshold based on LOD level
	# Higher LOD = lower threshold = preserve more vertices
	var importance_threshold: float = 0.3 + (lod_level * 0.15)
	importance_threshold = clamp(importance_threshold, 0.3, 0.9)

	# Calculate LOD resolution
	var lod_resolution: int = max(4, base_resolution >> lod_level)
	var step: float = float(base_resolution - 1) / float(lod_resolution - 1)

	# Scan importance map for high-importance vertices
	var width: int = importance_map.get_width()
	var height: int = importance_map.get_height()

	for y in range(height):
		for x in range(width):
			var importance: float = importance_map.get_pixel(x, y).r

			if importance >= importance_threshold:
				# This vertex is important, check if it would be skipped at this LOD
				var grid_x: int = int(float(x) / step + 0.5)
				var grid_z: int = int(float(y) / step + 0.5)
				var expected_x: int = int(grid_x * step)
				var expected_z: int = int(grid_z * step)

				# If this vertex doesn't align with the LOD grid, mark it for preservation
				if abs(x - expected_x) > 1 or abs(y - expected_z) > 1:
					important_vertices.append(Vector2i(x, y))

	return important_vertices


## Calculate curvature at each point in the heightmap
##
## Curvature indicates how much the terrain is bending. High curvature
## indicates features like ridges, trenches, or seamount peaks.
##
## @param heightmap: Height data to analyze
## @return: Array of float curvature values (one per pixel)
func _calculate_curvature_map(heightmap: Image) -> Array:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()
	var curvature_map: Array = []
	curvature_map.resize(width * height)

	for y in range(height):
		for x in range(width):
			var curvature: float = _calculate_curvature_at(heightmap, x, y)
			curvature_map[y * width + x] = curvature

	return curvature_map


## Calculate curvature at a specific point
##
## Uses second derivatives to measure terrain curvature.
## Positive curvature = convex (ridge, seamount peak)
## Negative curvature = concave (trench, valley)
##
## @param heightmap: Height data
## @param x: X coordinate
## @param y: Y coordinate
## @return: Curvature value (positive = convex, negative = concave)
func _calculate_curvature_at(heightmap: Image, x: int, y: int) -> float:
	var width: int = heightmap.get_width()
	var height: int = heightmap.get_height()

	# Get neighboring heights
	var h_center: float = heightmap.get_pixel(x, y).r
	var h_left: float = heightmap.get_pixel(max(0, x - 1), y).r
	var h_right: float = heightmap.get_pixel(min(width - 1, x + 1), y).r
	var h_up: float = heightmap.get_pixel(x, max(0, y - 1)).r
	var h_down: float = heightmap.get_pixel(x, min(height - 1, y + 1)).r

	# Calculate second derivatives (curvature)
	var d2x: float = h_left - 2.0 * h_center + h_right
	var d2y: float = h_up - 2.0 * h_center + h_down

	# Total curvature (Laplacian)
	return d2x + d2y


## Analyze a region of the heightmap for features
##
## @param heightmap: Height data
## @param curvature_map: Pre-calculated curvature values
## @param region: Region to analyze
## @return: FeatureInfo if a feature is detected, null otherwise
func _analyze_region(heightmap: Image, curvature_map: Array, region: Rect2i) -> FeatureInfo:
	var width: int = heightmap.get_width()

	# Calculate statistics for this region
	var min_height: float = INF
	var max_height: float = -INF
	var avg_height: float = 0.0
	var avg_curvature: float = 0.0
	var sample_count: int = 0

	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			if x >= width or y >= heightmap.get_height():
				continue

			var h: float = heightmap.get_pixel(x, y).r
			var c: float = curvature_map[y * width + x]

			min_height = min(min_height, h)
			max_height = max(max_height, h)
			avg_height += h
			avg_curvature += c
			sample_count += 1

	if sample_count == 0:
		return null

	avg_height /= sample_count
	avg_curvature /= sample_count

	# Determine feature type based on characteristics
	var feature: FeatureInfo = FeatureInfo.new()
	feature.extent = region
	feature.center_position = Vector2i(
		region.position.x + region.size.x / 2, region.position.y + region.size.y / 2
	)

	var elevation_range: float = max_height - min_height
	var is_underwater: bool = avg_height < sea_level

	if not is_underwater:
		# Not an underwater feature
		return null

	# Detect feature type
	if avg_height < trench_depth_threshold and avg_curvature < -feature_curvature_threshold:
		# Deep and concave = trench
		feature.feature_type = FeatureType.TRENCH
		feature.importance = clamp((trench_depth_threshold - avg_height) / 5000.0, 0.5, 1.0)

	elif (
		elevation_range > ridge_prominence_threshold
		and abs(avg_curvature) > feature_curvature_threshold
	):
		# High elevation range with curvature = ridge
		feature.feature_type = FeatureType.RIDGE
		feature.importance = clamp(elevation_range / 2000.0, 0.5, 1.0)

	elif (
		(max_height - avg_height) > seamount_height_threshold
		and avg_curvature > feature_curvature_threshold
	):
		# Significant rise above average with positive curvature = seamount
		feature.feature_type = FeatureType.SEAMOUNT
		feature.importance = clamp((max_height - avg_height) / 2000.0, 0.5, 1.0)

	elif elevation_range < 100.0 and abs(avg_curvature) < feature_curvature_threshold * 0.5:
		# Very flat and deep = abyssal plain
		feature.feature_type = FeatureType.ABYSSAL_PLAIN
		feature.importance = 0.2  # Low importance, but still track it

	else:
		# No significant feature
		return null

	return feature


## Merge overlapping features
##
## @param features: Array of detected features
## @return: Array of merged features
func _merge_overlapping_features(features: Array[FeatureInfo]) -> Array[FeatureInfo]:
	if features.size() <= 1:
		return features

	var merged: Array[FeatureInfo] = []
	var used: Array[bool] = []
	used.resize(features.size())
	used.fill(false)

	for i in range(features.size()):
		if used[i]:
			continue

		var feature: FeatureInfo = features[i]
		var merged_extent: Rect2i = feature.extent
		var max_importance: float = feature.importance

		# Find overlapping features of the same type
		for j in range(i + 1, features.size()):
			if used[j]:
				continue

			var other: FeatureInfo = features[j]

			if (
				other.feature_type == feature.feature_type
				and merged_extent.intersects(other.extent)
			):
				# Merge extents
				merged_extent = merged_extent.merge(other.extent)
				max_importance = max(max_importance, other.importance)
				used[j] = true

		# Create merged feature
		var merged_feature: FeatureInfo = FeatureInfo.new()
		merged_feature.feature_type = feature.feature_type
		merged_feature.importance = max_importance
		merged_feature.extent = merged_extent
		merged_feature.center_position = Vector2i(
			merged_extent.position.x + merged_extent.size.x / 2,
			merged_extent.position.y + merged_extent.size.y / 2
		)

		merged.append(merged_feature)
		used[i] = true

	return merged


## Apply feature importance to the importance map
##
## @param importance_map: Importance map to modify
## @param feature: Feature to apply
func _apply_feature_importance(importance_map: Image, feature: FeatureInfo) -> void:
	var width: int = importance_map.get_width()
	var height: int = importance_map.get_height()

	# Apply importance boost in the feature region
	for y in range(feature.extent.position.y, feature.extent.position.y + feature.extent.size.y):
		for x in range(
			feature.extent.position.x, feature.extent.position.x + feature.extent.size.x
		):
			if x < 0 or x >= width or y < 0 or y >= height:
				continue

			# Calculate distance from feature center
			var dx: float = x - feature.center_position.x
			var dy: float = y - feature.center_position.y
			var dist: float = sqrt(dx * dx + dy * dy)
			var max_dist: float = feature.extent.size.length()

			# Apply importance with falloff from center
			var falloff: float = 1.0 - clamp(dist / max_dist, 0.0, 1.0)
			var boost: float = feature.importance * falloff

			# Combine with existing importance (take maximum)
			var current: float = importance_map.get_pixel(x, y).r
			var new_importance: float = max(current, boost)

			importance_map.set_pixel(x, y, Color(new_importance, 0.0, 0.0, 1.0))
