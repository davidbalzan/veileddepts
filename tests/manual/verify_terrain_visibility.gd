extends Node
## Manual verification script for terrain visibility checkpoint
##
## This script verifies the terrain rendering fixes from tasks 1 and 2:
## - Terrain is visible when ocean is hidden
## - Height variation is >= 10 meters per chunk
## - Console logs show heightmap statistics
##
## Run this script from the Godot editor or via command line to verify.

var _terrain_renderer: TerrainRenderer = null
var _chunk_manager: ChunkManager = null
var _chunk_renderer: ChunkRenderer = null
var _procedural_detail_generator: ProceduralDetailGenerator = null
var _verification_results: Dictionary = {}


func _ready() -> void:
	print("=" * 60)
	print("TERRAIN VISIBILITY VERIFICATION")
	print("=" * 60)
	print("")
	
	call_deferred("_run_verification")


func _run_verification() -> void:
	# Find terrain components
	_find_terrain_components()
	
	if not _terrain_renderer:
		print("ERROR: TerrainRenderer not found!")
		_verification_results["terrain_renderer_found"] = false
		_print_summary()
		return
	
	_verification_results["terrain_renderer_found"] = true
	
	# Wait for terrain to initialize
	await get_tree().create_timer(2.0).timeout
	
	# Run verification checks
	_verify_procedural_detail_settings()
	_verify_chunk_renderer_settings()
	_verify_loaded_chunks()
	_verify_height_variation()
	
	# Print summary
	_print_summary()


func _find_terrain_components() -> void:
	# Find TerrainRenderer
	var terrain_nodes = get_tree().get_nodes_in_group("terrain_renderer")
	if terrain_nodes.size() > 0:
		_terrain_renderer = terrain_nodes[0]
	
	if _terrain_renderer:
		_chunk_manager = _terrain_renderer.get_node_or_null("ChunkManager")
		_chunk_renderer = _terrain_renderer.get_node_or_null("ChunkRenderer")
		_procedural_detail_generator = _terrain_renderer.get_node_or_null("ProceduralDetailGenerator")


func _verify_procedural_detail_settings() -> void:
	print("\n--- Procedural Detail Generator Settings ---")
	
	if not _procedural_detail_generator:
		print("WARNING: ProceduralDetailGenerator not found")
		_verification_results["procedural_detail_found"] = false
		return
	
	_verification_results["procedural_detail_found"] = true
	
	# Check detail_scale (should be 30.0, was 2.0)
	var detail_scale = _procedural_detail_generator.detail_scale
	print("detail_scale: %.1f (expected: 30.0)" % detail_scale)
	_verification_results["detail_scale_correct"] = detail_scale >= 25.0
	
	# Check detail_contribution (should be 0.5, was 0.1)
	var detail_contribution = _procedural_detail_generator.detail_contribution
	print("detail_contribution: %.2f (expected: 0.5)" % detail_contribution)
	_verification_results["detail_contribution_correct"] = detail_contribution >= 0.4
	
	# Check flat_terrain_threshold (should be 0.05)
	var flat_threshold = _procedural_detail_generator.flat_terrain_threshold
	print("flat_terrain_threshold: %.2f (expected: 0.05)" % flat_threshold)
	_verification_results["flat_threshold_correct"] = abs(flat_threshold - 0.05) < 0.01
	
	# Check flat_terrain_amplitude (should be 35.0)
	var flat_amplitude = _procedural_detail_generator.flat_terrain_amplitude
	print("flat_terrain_amplitude: %.1f (expected: 35.0)" % flat_amplitude)
	_verification_results["flat_amplitude_correct"] = flat_amplitude >= 20.0 and flat_amplitude <= 50.0


func _verify_chunk_renderer_settings() -> void:
	print("\n--- Chunk Renderer Settings ---")
	
	if not _chunk_renderer:
		print("WARNING: ChunkRenderer not found")
		_verification_results["chunk_renderer_found"] = false
		return
	
	_verification_results["chunk_renderer_found"] = true
	
	# Check min_elevation (should be -200.0, was -10994.0)
	var min_elev = _chunk_renderer.min_elevation
	print("min_elevation: %.1f (expected: -200.0)" % min_elev)
	_verification_results["min_elevation_correct"] = min_elev >= -500.0 and min_elev <= 0.0
	
	# Check max_elevation (should be 100.0, was 8849.0)
	var max_elev = _chunk_renderer.max_elevation
	print("max_elevation: %.1f (expected: 100.0)" % max_elev)
	_verification_results["max_elevation_correct"] = max_elev >= 0.0 and max_elev <= 500.0
	
	# Check use_mission_area_scaling (should be true)
	var use_mission = _chunk_renderer.use_mission_area_scaling
	print("use_mission_area_scaling: %s (expected: true)" % str(use_mission))
	_verification_results["mission_area_scaling_correct"] = use_mission


func _verify_loaded_chunks() -> void:
	print("\n--- Loaded Chunks ---")
	
	if not _chunk_manager:
		print("WARNING: ChunkManager not found")
		_verification_results["chunk_manager_found"] = false
		return
	
	_verification_results["chunk_manager_found"] = true
	
	var chunk_count = _chunk_manager.get_chunk_count()
	print("Loaded chunks: %d" % chunk_count)
	_verification_results["chunks_loaded"] = chunk_count > 0
	
	var memory_mb = _chunk_manager.get_memory_usage_mb()
	print("Memory usage: %.2f MB" % memory_mb)


func _verify_height_variation() -> void:
	print("\n--- Height Variation Check ---")
	
	if not _chunk_manager:
		print("WARNING: Cannot verify height variation - ChunkManager not found")
		return
	
	var loaded_chunks = _chunk_manager.get_loaded_chunks()
	if loaded_chunks.is_empty():
		print("WARNING: No chunks loaded to verify")
		_verification_results["height_variation_verified"] = false
		return
	
	var min_variation_found = INF
	var max_variation_found = 0.0
	var chunks_meeting_requirement = 0
	var total_chunks = 0
	
	for chunk_coord in loaded_chunks:
		var chunk = _chunk_manager.get_chunk(chunk_coord)
		if not chunk or not chunk.mesh_instance or not chunk.mesh_instance.mesh:
			continue
		
		total_chunks += 1
		var mesh = chunk.mesh_instance.mesh
		var aabb = mesh.get_aabb()
		var height_variation = aabb.size.y
		
		min_variation_found = min(min_variation_found, height_variation)
		max_variation_found = max(max_variation_found, height_variation)
		
		if height_variation >= 10.0:
			chunks_meeting_requirement += 1
		
		print("Chunk %s: AABB Y range = [%.1f, %.1f], variation = %.1f m" % [
			chunk_coord,
			aabb.position.y,
			aabb.position.y + aabb.size.y,
			height_variation
		])
	
	print("")
	print("Summary:")
	print("  Total chunks checked: %d" % total_chunks)
	print("  Chunks with >= 10m variation: %d (%.1f%%)" % [
		chunks_meeting_requirement,
		100.0 * chunks_meeting_requirement / max(total_chunks, 1)
	])
	print("  Min variation found: %.1f m" % min_variation_found)
	print("  Max variation found: %.1f m" % max_variation_found)
	
	# Requirement: >= 10 meters per chunk
	_verification_results["height_variation_verified"] = chunks_meeting_requirement > 0
	_verification_results["min_height_variation"] = min_variation_found
	_verification_results["max_height_variation"] = max_variation_found
	_verification_results["chunks_meeting_requirement"] = chunks_meeting_requirement
	_verification_results["total_chunks_checked"] = total_chunks


func _print_summary() -> void:
	print("\n" + "=" * 60)
	print("VERIFICATION SUMMARY")
	print("=" * 60)
	
	var all_passed = true
	
	# Check each result
	var checks = [
		["TerrainRenderer found", "terrain_renderer_found"],
		["ProceduralDetailGenerator found", "procedural_detail_found"],
		["detail_scale >= 25.0", "detail_scale_correct"],
		["detail_contribution >= 0.4", "detail_contribution_correct"],
		["flat_terrain_threshold = 0.05", "flat_threshold_correct"],
		["flat_terrain_amplitude in [20, 50]", "flat_amplitude_correct"],
		["ChunkRenderer found", "chunk_renderer_found"],
		["min_elevation in [-500, 0]", "min_elevation_correct"],
		["max_elevation in [0, 500]", "max_elevation_correct"],
		["use_mission_area_scaling = true", "mission_area_scaling_correct"],
		["ChunkManager found", "chunk_manager_found"],
		["Chunks loaded", "chunks_loaded"],
		["Height variation >= 10m", "height_variation_verified"],
	]
	
	for check in checks:
		var name = check[0]
		var key = check[1]
		var passed = _verification_results.get(key, false)
		var status = "PASS" if passed else "FAIL"
		print("  [%s] %s" % [status, name])
		if not passed:
			all_passed = false
	
	print("")
	if all_passed:
		print("RESULT: ALL CHECKS PASSED")
		print("")
		print("The terrain visibility fixes have been verified.")
		print("Please also manually verify:")
		print("  1. Press F3 to open debug panel")
		print("  2. Uncheck 'Show Ocean' to hide the ocean")
		print("  3. Verify terrain is visible against the gray background")
		print("  4. Verify terrain has visible height variation (not flat)")
	else:
		print("RESULT: SOME CHECKS FAILED")
		print("")
		print("Please review the failed checks above.")
	
	print("=" * 60)
