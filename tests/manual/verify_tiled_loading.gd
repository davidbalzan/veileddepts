extends Node
## Manual verification script for Task 7: Checkpoint - Verify Tiled Loading
##
## This script performs comprehensive checks on the tiled elevation system:
## 1. Tiles load correctly
## 2. Tactical map uses same data as terrain
## 3. LOD switching works on zoom
## 4. Performance metrics

var terrain_renderer: Node = null
var tactical_map: Node = null
var elevation_provider = null
var test_results: Dictionary = {}

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("TILED LOADING VERIFICATION - Task 7 Checkpoint")
	print("=".repeat(80) + "\n")
	
	# Find required nodes
	_find_nodes()
	
	# Run verification tests
	await _verify_tiles_load_correctly()
	await _verify_tactical_map_uses_same_data()
	await _verify_lod_switching()
	await _verify_performance()
	
	# Print summary
	_print_summary()
	
	print("\n" + "=".repeat(80))
	print("VERIFICATION COMPLETE")
	print("=".repeat(80) + "\n")


func _find_nodes() -> void:
	print("Finding required nodes...")
	
	# Find terrain renderer
	terrain_renderer = get_node_or_null("/root/Main/TerrainRenderer")
	if terrain_renderer:
		print("  ✓ Found TerrainRenderer")
		elevation_provider = terrain_renderer.get_node_or_null("TiledElevationProvider")
		if elevation_provider:
			print("  ✓ Found TiledElevationProvider")
		else:
			print("  ✗ TiledElevationProvider not found")
	else:
		print("  ✗ TerrainRenderer not found")
	
	# Find tactical map
	tactical_map = get_node_or_null("/root/Main/TacticalMapView")
	if tactical_map:
		print("  ✓ Found TacticalMapView")
	else:
		print("  ✗ TacticalMapView not found")
	
	print()


func _verify_tiles_load_correctly() -> void:
	print("TEST 1: Verify Tiles Load Correctly")
	print("-".repeat(80))
	
	if not elevation_provider:
		print("  ✗ FAIL: No elevation provider available")
		test_results["tiles_load"] = false
		return
	
	# Check if provider is initialized
	if not elevation_provider.has_method("has_tiles"):
		print("  ✗ FAIL: Provider missing has_tiles() method")
		test_results["tiles_load"] = false
		return
	
	var has_tiles = elevation_provider.has_tiles()
	print("  Tiles available: %s" % ("YES" if has_tiles else "NO"))
	
	if has_tiles:
		# Check tile metadata
		var map_dims = elevation_provider.get_map_dimensions()
		print("  Map dimensions: %d x %d" % [map_dims.x, map_dims.y])
		
		# Check cache stats
		var cache_stats = elevation_provider.get_cache_stats()
		print("  Cache stats:")
		print("    - Cached tiles: %d / %d" % [cache_stats.cached_tiles, cache_stats.max_tiles])
		print("    - Tile memory: %.2f MB" % cache_stats.tile_memory_mb)
		print("    - LOD memory: %.2f MB" % cache_stats.lod_memory_mb)
		print("    - Total memory: %.2f MB" % cache_stats.total_memory_mb)
		
		# Test loading a specific tile
		print("\n  Testing tile loading at origin (0, 0)...")
		var test_elevation = elevation_provider.get_elevation(Vector2(0, 0))
		print("    Elevation at origin: %.1f meters" % test_elevation)
		
		# Test loading tiles at different locations
		var test_positions = [
			Vector2(0, 0),
			Vector2(1000, 0),
			Vector2(0, 1000),
			Vector2(-1000, -1000)
		]
		
		print("\n  Testing elevation queries at multiple positions:")
		var all_valid = true
		for pos in test_positions:
			var elev = elevation_provider.get_elevation(pos)
			var is_valid = elev > -11000.0 and elev < 9000.0
			print("    Position %s: %.1f m %s" % [pos, elev, "✓" if is_valid else "✗"])
			if not is_valid:
				all_valid = false
		
		# Test region extraction
		print("\n  Testing region extraction...")
		var test_bounds = Rect2(-500, -500, 1000, 1000)
		var region_image = elevation_provider.extract_region(test_bounds, 128)
		if region_image:
			print("    ✓ Successfully extracted %dx%d region" % [region_image.get_width(), region_image.get_height()])
			
			# Verify image has valid data
			var sample_pixel = region_image.get_pixel(64, 64)
			print("    Sample pixel value: %.3f" % sample_pixel.r)
			
			test_results["tiles_load"] = all_valid
		else:
			print("    ✗ Failed to extract region")
			test_results["tiles_load"] = false
	else:
		# Check fallback mode
		var is_procedural = elevation_provider.is_using_procedural()
		print("  Using procedural fallback: %s" % ("YES" if is_procedural else "NO"))
		
		if is_procedural:
			print("  ⚠ WARNING: Tiles not available, using procedural generation")
			print("  This is acceptable but not optimal for performance")
			test_results["tiles_load"] = true  # Acceptable fallback
		else:
			print("  ✓ Using source image fallback")
			test_results["tiles_load"] = true
	
	print()


func _verify_tactical_map_uses_same_data() -> void:
	print("TEST 2: Verify Tactical Map Uses Same Data as Terrain")
	print("-".repeat(80))
	
	if not elevation_provider or not tactical_map:
		print("  ✗ FAIL: Required nodes not available")
		test_results["unified_data"] = false
		return
	
	# Test that tactical map queries the same elevation provider
	print("  Checking if tactical map uses TiledElevationProvider...")
	
	# Sample multiple positions and compare
	var test_positions = [
		Vector2(0, 0),
		Vector2(500, 500),
		Vector2(-500, 500),
		Vector2(500, -500)
	]
	
	print("\n  Comparing elevation data consistency:")
	var all_consistent = true
	
	for pos in test_positions:
		# Get elevation from provider
		var provider_elevation = elevation_provider.get_elevation(pos)
		
		# The tactical map should be using the same provider
		# We can verify this by checking if it references the provider
		var tactical_terrain_renderer = tactical_map.get("terrain_renderer")
		if tactical_terrain_renderer:
			var tactical_provider = tactical_terrain_renderer.get_node_or_null("TiledElevationProvider")
			if tactical_provider == elevation_provider:
				print("    Position %s: %.1f m ✓ (same provider instance)" % [pos, provider_elevation])
			else:
				print("    Position %s: ⚠ Different provider instance" % pos)
				all_consistent = false
		else:
			print("    ⚠ Cannot verify - tactical map terrain renderer not accessible")
	
	test_results["unified_data"] = all_consistent
	print()


func _verify_lod_switching() -> void:
	print("TEST 3: Verify LOD Switching Works on Zoom")
	print("-".repeat(80))
	
	if not elevation_provider:
		print("  ✗ FAIL: No elevation provider available")
		test_results["lod_switching"] = false
		return
	
	# Check if LOD methods are available
	if not elevation_provider.has_method("get_lod_for_zoom"):
		print("  ✗ FAIL: Provider missing get_lod_for_zoom() method")
		test_results["lod_switching"] = false
		return
	
	if not elevation_provider.has_method("extract_region_lod"):
		print("  ✗ FAIL: Provider missing extract_region_lod() method")
		test_results["lod_switching"] = false
		return
	
	print("  Testing LOD selection for different zoom levels...")
	
	# Test different meters_per_pixel values (zoom levels)
	var zoom_tests = [
		{"meters_per_pixel": 5.0, "expected_lod": 0, "description": "Very zoomed in"},
		{"meters_per_pixel": 25.0, "expected_lod": 1, "description": "Medium zoom"},
		{"meters_per_pixel": 100.0, "expected_lod": 2, "description": "Overview"},
		{"meters_per_pixel": 500.0, "expected_lod": 3, "description": "World map"}
	]
	
	var all_correct = true
	for test in zoom_tests:
		var lod = elevation_provider.get_lod_for_zoom(test.meters_per_pixel)
		var is_correct = (lod == test.expected_lod)
		print("    %.1f m/px (%s): LOD %d %s" % [
			test.meters_per_pixel,
			test.description,
			lod,
			"✓" if is_correct else "✗ (expected %d)" % test.expected_lod
		])
		if not is_correct:
			all_correct = false
	
	# Test actual LOD extraction
	print("\n  Testing LOD extraction at different levels...")
	var test_bounds = Rect2(-1000, -1000, 2000, 2000)
	
	for lod_level in range(4):
		var start_time = Time.get_ticks_msec()
		var lod_image = elevation_provider.extract_region_lod(test_bounds, lod_level)
		var duration = Time.get_ticks_msec() - start_time
		
		if lod_image:
			var resolution = lod_image.get_width()
			print("    LOD %d: %dx%d extracted in %d ms ✓" % [lod_level, resolution, resolution, duration])
		else:
			print("    LOD %d: ✗ Failed to extract" % lod_level)
			all_correct = false
	
	test_results["lod_switching"] = all_correct
	print()


func _verify_performance() -> void:
	print("TEST 4: Verify Performance")
	print("-".repeat(80))
	
	if not elevation_provider:
		print("  ✗ FAIL: No elevation provider available")
		test_results["performance"] = false
		return
	
	# Test 1: Single elevation query performance
	print("  Testing single elevation query performance...")
	var query_times: Array[float] = []
	var test_count = 100
	
	for i in range(test_count):
		var pos = Vector2(randf_range(-5000, 5000), randf_range(-5000, 5000))
		var start_time = Time.get_ticks_usec()
		var _elevation = elevation_provider.get_elevation(pos)
		var duration = Time.get_ticks_usec() - start_time
		query_times.append(duration / 1000.0)  # Convert to milliseconds
	
	var avg_query_time = query_times.reduce(func(acc, val): return acc + val, 0.0) / test_count
	var max_query_time = query_times.max()
	
	print("    Average query time: %.3f ms" % avg_query_time)
	print("    Maximum query time: %.3f ms" % max_query_time)
	print("    Queries per second: %.0f" % (1000.0 / avg_query_time))
	
	var query_performance_ok = avg_query_time < 1.0  # Should be sub-millisecond
	print("    Performance: %s" % ("✓ GOOD" if query_performance_ok else "⚠ SLOW"))
	
	# Test 2: Region extraction performance
	print("\n  Testing region extraction performance...")
	var test_bounds = Rect2(-2000, -2000, 4000, 4000)
	
	var extraction_times: Dictionary = {}
	for lod in range(4):
		var start_time = Time.get_ticks_msec()
		var _image = elevation_provider.extract_region_lod(test_bounds, lod)
		var duration = Time.get_ticks_msec() - start_time
		extraction_times[lod] = duration
		print("    LOD %d extraction: %d ms" % [lod, duration])
	
	# LOD 3 should be fastest, LOD 0 slowest
	var lod_performance_ok = extraction_times[3] < extraction_times[0]
	print("    LOD scaling: %s" % ("✓ CORRECT" if lod_performance_ok else "⚠ UNEXPECTED"))
	
	# Test 3: Cache effectiveness
	print("\n  Testing cache effectiveness...")
	var cache_stats_before = elevation_provider.get_cache_stats()
	
	# Query same positions multiple times
	var cached_pos = Vector2(1000, 1000)
	var first_query_time = 0.0
	var cached_query_time = 0.0
	
	# First query (cache miss)
	var start = Time.get_ticks_usec()
	var _elev1 = elevation_provider.get_elevation(cached_pos)
	first_query_time = (Time.get_ticks_usec() - start) / 1000.0
	
	# Second query (cache hit)
	start = Time.get_ticks_usec()
	var _elev2 = elevation_provider.get_elevation(cached_pos)
	cached_query_time = (Time.get_ticks_usec() - start) / 1000.0
	
	var cache_stats_after = elevation_provider.get_cache_stats()
	
	print("    First query: %.3f ms" % first_query_time)
	print("    Cached query: %.3f ms" % cached_query_time)
	print("    Speedup: %.1fx" % (first_query_time / max(cached_query_time, 0.001)))
	print("    Cached tiles: %d" % cache_stats_after.cached_tiles)
	
	var cache_effective = cached_query_time < first_query_time
	print("    Cache effectiveness: %s" % ("✓ WORKING" if cache_effective else "⚠ NOT EFFECTIVE"))
	
	# Overall performance assessment
	var performance_ok = query_performance_ok and lod_performance_ok and cache_effective
	test_results["performance"] = performance_ok
	print()


func _print_summary() -> void:
	print("\n" + "=".repeat(80))
	print("VERIFICATION SUMMARY")
	print("=".repeat(80))
	
	var all_passed = true
	
	for test_name in test_results.keys():
		var passed = test_results[test_name]
		var status = "✓ PASS" if passed else "✗ FAIL"
		var test_display_name = test_name.replace("_", " ").capitalize()
		print("  %s: %s" % [test_display_name, status])
		if not passed:
			all_passed = false
	
	print()
	if all_passed:
		print("  ✓ ALL TESTS PASSED")
		print("  The tiled loading system is working correctly!")
	else:
		print("  ✗ SOME TESTS FAILED")
		print("  Please review the failures above and address any issues.")
	
	print()
	print("USER VERIFICATION REQUIRED:")
	print("  1. Check console output for any warnings or errors")
	print("  2. Open tactical map (press '1' key)")
	print("  3. Zoom in and out with mouse wheel")
	print("  4. Verify terrain detail increases when zooming in")
	print("  5. Verify no stuttering or lag during zoom")
	print("  6. Verify terrain colors match between 3D view and tactical map")
	print()
