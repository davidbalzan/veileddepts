class_name TerrainRenderer extends Node3D
## Terrain rendering system using dynamic chunk streaming
##
## This is a refactored version that delegates to the new streaming system
## while maintaining backward compatibility with the old interface.
##
## The new system provides:
## - Dynamic chunk loading/unloading based on submarine position
## - Real-world elevation data from world map
## - Procedural detail enhancement
## - Biome detection and rendering
## - Efficient memory management
## - LOD system with seamless transitions

# Streaming system configuration
@export_group("Streaming Settings")
@export var chunk_size: float = 512.0  # Size of each terrain chunk in meters
@export var load_distance: float = 2048.0  # Distance to load chunks
@export var unload_distance: float = 3072.0  # Distance to unload chunks
@export var max_cache_memory_mb: int = 512  # Maximum memory for chunk cache

@export_group("LOD Settings")
@export var lod_levels: int = 4  # Number of LOD levels
@export var lod_distance_multiplier: float = 2.0  # Distance multiplier between LOD levels
@export var base_lod_distance: float = 100.0  # Distance for first LOD transition

@export_group("Detail Settings")
@export var enable_procedural_detail: bool = true  # Add fine detail to terrain
@export var detail_scale: float = 2.0  # Height variation in meters for detail
@export var detail_frequency: float = 0.05  # Frequency of detail noise

@export_group("Elevation Data")
@export var elevation_map_path: String = "res://src_assets/World_elevation_map.png"
@export var use_external_heightmap: bool = true  # Use world elevation map
@export var heightmap_region: Rect2 = Rect2(0.47, 0.30, 0.02, 0.02)  # North Sea - shallow water at ~100m depth

@export_group("Debug")
@export var enable_debug_overlay: bool = false  # Show debug visualization

# Legacy compatibility (deprecated, kept for backward compatibility)
@export_group("Legacy Settings (Deprecated)")
@export var terrain_size: Vector2i = Vector2i(2048, 2048)  # Ignored in new system
@export var terrain_resolution: int = 256  # Ignored in new system
@export var max_height: float = 100.0  # Ignored in new system
@export var min_height: float = -200.0  # Ignored in new system
@export var sea_level: float = 0.0  # Always 0 in new system
@export var collision_enabled: bool = true  # Always enabled in new system

# Preload tile-based elevation provider
const TiledElevationProviderScript = preload("res://scripts/rendering/tiled_elevation_provider.gd")

signal mission_area_changed(new_region: Rect2)

# New streaming system components
var _streaming_manager: StreamingManager = null
var _chunk_manager: ChunkManager = null
var _elevation_provider = null  # TiledElevationProvider - uses tile-based loading
var _chunk_renderer: ChunkRenderer = null
var _collision_manager: CollisionManager = null
var _biome_detector: BiomeDetector = null
var _procedural_detail_generator: ProceduralDetailGenerator = null
var _performance_monitor: PerformanceMonitor = null
var _debug_overlay: TerrainDebugOverlay = null
var _logger: TerrainLogger = null

# Submarine reference for streaming updates
var _submarine: RigidBody3D = null

# Initialization flag
var initialized: bool = false

# Incremental update state for sea level changes
var _sea_level_update_queue: Array[Vector2i] = []  # Queue of chunks to update
var _sea_level_update_in_progress: bool = false
var _chunks_per_frame: int = 5  # Number of chunks to update per frame
var _current_sea_level_meters: float = 0.0  # Cached sea level for incremental updates


func _ready() -> void:
	add_to_group("terrain_renderer")

	if not Engine.is_editor_hint():
		call_deferred("_setup_terrain")
		# Connect to SeaLevelManager signal
		if SeaLevelManager:
			SeaLevelManager.sea_level_changed.connect(_on_sea_level_changed)


func _exit_tree() -> void:
	# Disconnect from SeaLevelManager signal
	if SeaLevelManager and SeaLevelManager.sea_level_changed.is_connected(_on_sea_level_changed):
		SeaLevelManager.sea_level_changed.disconnect(_on_sea_level_changed)
	_cleanup_terrain()


func _cleanup_terrain() -> void:
	"""Clean up terrain resources"""
	# The streaming system handles cleanup automatically
	initialized = false


func _setup_terrain() -> void:
	"""Setup the new streaming terrain system"""

	# Create logger first
	_logger = TerrainLogger.new()
	_logger.name = "TerrainLogger"
	add_child(_logger)
	
	# Log initialization to console
	if LogRouter:
		LogRouter.log("TerrainRenderer initializing", LogRouter.LogLevel.INFO, "terrain")

	# Create tile-based elevation provider (memory efficient)
	_elevation_provider = TiledElevationProviderScript.new()
	_elevation_provider.name = "TiledElevationProvider"
	_elevation_provider.tiles_directory = "res://assets/terrain/tiles/"
	add_child(_elevation_provider)
	_elevation_provider.mission_area_center_uv = heightmap_region.get_center()

	# Initialize elevation provider
	if not _elevation_provider.initialize():
		push_warning(
			"TerrainRenderer: Elevation provider using procedural fallback (run HeightmapTileProcessor to generate tiles)"
		)

	# Create chunk manager
	_chunk_manager = ChunkManager.new()
	_chunk_manager.name = "ChunkManager"
	_chunk_manager.chunk_size = chunk_size
	_chunk_manager.max_cache_memory_mb = max_cache_memory_mb
	add_child(_chunk_manager)

	# Create performance monitor
	_performance_monitor = PerformanceMonitor.new()
	_performance_monitor.name = "PerformanceMonitor"
	add_child(_performance_monitor)

	# Create biome detector
	_biome_detector = BiomeDetector.new()
	_biome_detector.name = "BiomeDetector"
	add_child(_biome_detector)

	# Create procedural detail generator
	_procedural_detail_generator = ProceduralDetailGenerator.new()
	_procedural_detail_generator.name = "ProceduralDetailGenerator"
	_procedural_detail_generator.detail_scale = detail_scale
	_procedural_detail_generator.detail_frequency = detail_frequency
	# Note: ProceduralDetailGenerator doesn't have an 'enabled' property
	# The enable_procedural_detail flag is used by ChunkRenderer instead
	add_child(_procedural_detail_generator)

	# Create chunk renderer
	_chunk_renderer = ChunkRenderer.new()
	_chunk_renderer.name = "ChunkRenderer"
	_chunk_renderer.lod_levels = lod_levels
	_chunk_renderer.lod_distance_multiplier = lod_distance_multiplier
	_chunk_renderer.base_lod_distance = base_lod_distance
	add_child(_chunk_renderer)

	# Create collision manager
	_collision_manager = CollisionManager.new()
	_collision_manager.name = "CollisionManager"
	add_child(_collision_manager)

	# Create streaming manager (must be last as it references other components)
	_streaming_manager = StreamingManager.new()
	_streaming_manager.name = "StreamingManager"
	_streaming_manager.chunk_size = chunk_size
	_streaming_manager.load_distance = load_distance
	_streaming_manager.unload_distance = unload_distance
	add_child(_streaming_manager)

	# Create debug overlay if enabled
	if enable_debug_overlay:
		_debug_overlay = TerrainDebugOverlay.new()
		_debug_overlay.name = "TerrainDebugOverlay"
		_debug_overlay.enabled = true
		add_child(_debug_overlay)
	
	# Register debug panels with DebugPanelManager
	if _performance_monitor:
		DebugPanelManager.register_panel("performance", _performance_monitor)
	if _debug_overlay:
		DebugPanelManager.register_panel("terrain", _debug_overlay)

	# Submarine will be set by Main or caller via set_submarine()
	initialized = true

	_logger.log_info(
		"TerrainRenderer",
		"Initialized with streaming system",
		{
			"chunk_size": "%.1f" % chunk_size,
			"load_distance": "%.1f" % load_distance,
			"unload_distance": "%.1f" % unload_distance,
			"lod_levels": str(lod_levels),
			"procedural_detail": str(enable_procedural_detail)
		}
	)
	
	# Log to console
	if LogRouter:
		LogRouter.log(
			"TerrainRenderer initialized: chunk_size=%.1fm, load_distance=%.1fm, lod_levels=%d" % [chunk_size, load_distance, lod_levels],
			LogRouter.LogLevel.INFO,
			"terrain"
		)

	print("TerrainRenderer: Initialized with streaming system")
	print("  Chunk size: %.1f m" % chunk_size)
	print("  Load distance: %.1f m" % load_distance)
	print("  Unload distance: %.1f m" % unload_distance)
	print("  Max cache memory: %d MB" % max_cache_memory_mb)


## Set the submarine reference for streaming
func set_submarine(submarine: Node3D) -> void:
	_submarine = submarine
	if _submarine:
		_logger.log_info("TerrainRenderer", "Submarine reference set for streaming", {"name": submarine.name})
		print("TerrainRenderer: Submarine reference set to ", submarine.name)
	else:
		push_warning("TerrainRenderer: Submarine reference set to null")


var _debug_frame_counter: int = 0

func _process(_delta: float) -> void:
	if not initialized or not _streaming_manager or not _submarine:
		return

	# Update streaming based on submarine position
	_streaming_manager.update(_submarine.global_position)
	
	# Process incremental sea level updates
	_process_sea_level_updates(_delta)

	# Debug: Print chunk status every 120 frames (2 seconds at 60fps)
	_debug_frame_counter += 1
	if _debug_frame_counter >= 120:
		_debug_frame_counter = 0
		if _chunk_manager:
			var chunk_count = _chunk_manager.get_chunk_count()
			print("TerrainRenderer DEBUG: %d chunks loaded, sub at %s" % [chunk_count, _submarine.global_position])


## Callback when sea level changes
## Updates all loaded chunks with the new sea level value using incremental updates
func _on_sea_level_changed(normalized: float, meters: float) -> void:
	if not initialized or not _chunk_manager:
		return
	
	# Store the new sea level
	_current_sea_level_meters = meters
	
	# Log the sea level change
	if _logger:
		_logger.log_info(
			"TerrainRenderer",
			"Sea level changed, queuing chunk updates",
			{
				"normalized": "%.3f" % normalized,
				"meters": "%.1f" % meters,
				"chunk_count": str(_chunk_manager.get_chunk_count())
			}
		)
	
	# Get all loaded chunks and queue them for incremental update
	var loaded_chunks = _chunk_manager.get_loaded_chunks()
	_sea_level_update_queue.clear()
	_sea_level_update_queue.append_array(loaded_chunks)
	_sea_level_update_in_progress = true
	
	if LogRouter:
		LogRouter.log(
			"TerrainRenderer: Queued %d chunks for sea level update to %.1fm" % [_sea_level_update_queue.size(), meters],
			LogRouter.LogLevel.INFO,
			"terrain"
		)
	
	# Report progress to SeaLevelManager
	if SeaLevelManager:
		SeaLevelManager.update_progress.emit(0.0, "TerrainRenderer: Starting chunk updates")


## Process incremental chunk updates (called from _process)
func _process_sea_level_updates(_delta: float) -> void:
	if not _sea_level_update_in_progress or _sea_level_update_queue.is_empty():
		return
	
	var start_time = Time.get_ticks_usec()
	var updated_count = 0
	var total_chunks = _chunk_manager.get_chunk_count()
	var remaining_before = _sea_level_update_queue.size()
	
	# Update a batch of chunks this frame
	for i in range(_chunks_per_frame):
		if _sea_level_update_queue.is_empty():
			break
		
		var chunk_coord = _sea_level_update_queue.pop_front()
		var chunk = _chunk_manager.get_chunk(chunk_coord)
		
		if chunk and chunk.material:
			chunk.material.set_shader_parameter("sea_level", _current_sea_level_meters)
			updated_count += 1
	
	# Calculate progress
	var remaining_after = _sea_level_update_queue.size()
	var progress = 1.0 - (float(remaining_after) / float(remaining_before + updated_count))
	
	# Report progress
	if SeaLevelManager:
		SeaLevelManager.update_progress.emit(
			progress,
			"TerrainRenderer: Updating chunks (%d/%d)" % [remaining_before - remaining_after, remaining_before]
		)
	
	# Check if we're done
	if _sea_level_update_queue.is_empty():
		_sea_level_update_in_progress = false
		
		var duration_ms = (Time.get_ticks_usec() - start_time) / 1000.0
		
		if _logger:
			_logger.log_info(
				"TerrainRenderer",
				"Chunk shader parameters updated",
				{
					"updated_chunks": str(total_chunks),
					"duration_ms": "%.1f" % duration_ms
				}
			)
		
		if LogRouter:
			LogRouter.log(
				"TerrainRenderer: Completed sea level update for %d chunks in %.1fms" % [total_chunks, duration_ms],
				LogRouter.LogLevel.INFO,
				"terrain"
			)
		
		# Report completion
		if SeaLevelManager:
			SeaLevelManager.update_progress.emit(1.0, "TerrainRenderer: Update complete")

# ============================================================================
# Backward Compatibility Interface
# ============================================================================
# These methods maintain compatibility with the old TerrainRenderer interface
# while delegating to the new streaming system


func get_height_at(world_pos: Vector2) -> float:
	"""Get terrain height at a specific world position (XZ plane)"""
	if not _collision_manager:
		return 0.0

	return _collision_manager.get_height_at(world_pos)


func get_height_at_3d(world_pos: Vector3) -> float:
	"""Get terrain height at a specific 3D world position"""
	return get_height_at(Vector2(world_pos.x, world_pos.z))


func check_collision(world_position: Vector3, radius: float = 0.0) -> bool:
	"""Check if a position collides with terrain"""
	var terrain_height = get_height_at_3d(world_position)
	return world_position.y - radius < terrain_height


func get_collision_response(world_position: Vector3, radius: float = 0.0) -> Vector3:
	"""Get collision response vector to push object out of terrain"""
	var terrain_height = get_height_at_3d(world_position)
	var penetration = terrain_height - (world_position.y - radius)

	if penetration > 0:
		return Vector3(0, penetration + 0.1, 0)  # 0.1 is collision margin
	return Vector3.ZERO


func get_normal_at(world_pos: Vector2) -> Vector3:
	"""Get terrain normal at a specific world position"""
	if not _collision_manager:
		return Vector3.UP

	return _collision_manager.get_surface_normal_for_sonar(Vector3(world_pos.x, 0.0, world_pos.y))


func find_safe_spawn_position(
	preferred_position: Vector3 = Vector3.ZERO,
	search_radius: float = 500.0,
	min_depth: float = -50.0
) -> Vector3:
	"""Find a safe spawn position in water (below sea level, above sea floor)
	
	Args:
		preferred_position: Preferred spawn location (will search nearby)
		search_radius: How far to search for a valid position
		min_depth: Minimum depth below sea level for safe spawning
	
	Returns:
		A safe spawn position in water, or preferred_position if no valid position found
	"""
	if not initialized or not _collision_manager:
		push_warning("TerrainRenderer: Cannot find spawn position - terrain not initialized")
		return preferred_position

	# Try the preferred position first
	var terrain_height = get_height_at(Vector2(preferred_position.x, preferred_position.z))
	if terrain_height < min_depth:
		# Position is underwater and safe
		var safe_depth = (terrain_height + min_depth) / 2.0
		return Vector3(preferred_position.x, safe_depth, preferred_position.z)

	# Search in a spiral pattern for a valid water position
	var search_steps = 16
	var angle_step = TAU / 8.0  # 8 directions

	for ring in range(1, search_steps):
		var radius = (float(ring) / search_steps) * search_radius

		for angle_idx in range(8):
			var angle = angle_idx * angle_step
			var test_pos = Vector2(
				preferred_position.x + cos(angle) * radius,
				preferred_position.z + sin(angle) * radius
			)

			var test_height = get_height_at(test_pos)
			if test_height < min_depth:
				# Found a valid water position
				var safe_depth = (test_height + min_depth) / 2.0
				print(
					"TerrainRenderer: Found safe spawn position at ",
					Vector3(test_pos.x, safe_depth, test_pos.y)
				)
				return Vector3(test_pos.x, safe_depth, test_pos.y)

	# No valid position found, return a position well below sea level
	push_warning("TerrainRenderer: Could not find safe spawn position, using default depth")
	return Vector3(preferred_position.x, min_depth, preferred_position.z)


func is_position_underwater(world_position: Vector3, margin: float = 5.0) -> bool:
	"""Check if a position is safely underwater (below sea level, above sea floor)
	
	Args:
		world_position: Position to check
		margin: Safety margin above sea floor
	
	Returns:
		True if position is safely underwater
	"""
	if not _collision_manager:
		return false

	return _collision_manager.is_underwater_safe(world_position, margin)


# Legacy methods (deprecated but kept for compatibility)
func load_heightmap_from_file(_path: String, _region: Rect2 = Rect2(0, 0, 1, 1)) -> bool:
	"""Legacy method - now handled by ElevationDataProvider"""
	push_warning(
		"TerrainRenderer.load_heightmap_from_file() is deprecated - elevation data is now managed by the streaming system"
	)
	return true


func load_world_elevation_map(_region: Rect2 = Rect2(0.25, 0.3, 0.1, 0.1)) -> bool:
	"""Legacy method - now handled by ElevationDataProvider"""
	push_warning(
		"TerrainRenderer.load_world_elevation_map() is deprecated - elevation data is now managed by the streaming system"
	)
	return true


func regenerate_terrain() -> void:
	"""Legacy method - terrain is now managed by streaming system"""
	push_warning(
		"TerrainRenderer.regenerate_terrain() is deprecated - terrain is dynamically managed by the streaming system"
	)


func set_terrain_region(region: Rect2) -> void:
	"""Legacy method - region is now set via heightmap_region export variable"""
	push_warning(
		"TerrainRenderer.set_terrain_region() is deprecated - use heightmap_region export variable instead"
	)
	heightmap_region = region
	if _elevation_provider:
		_elevation_provider.mission_area_center_uv = region.get_center()
	
	if _chunk_manager:
		_chunk_manager.unload_all_chunks()
	
	# Emit signal to notify other systems (like Tactical Map)
	mission_area_changed.emit(region)


func set_terrain_region_earth_scale(region: Rect2, _max_terrain_size: int = 4096) -> void:
	"""Legacy method - scaling is now handled automatically"""
	push_warning(
		"TerrainRenderer.set_terrain_region_earth_scale() is deprecated - scaling is handled automatically by the streaming system"
	)
	heightmap_region = region


# ============================================================================
# Debug and Utility Methods
# ============================================================================


func toggle_debug_overlay() -> void:
	"""Toggle the debug overlay visibility"""
	if not _debug_overlay:
		# Create debug overlay on-demand
		_debug_overlay = TerrainDebugOverlay.new()
		_debug_overlay.name = "TerrainDebugOverlay"
		_debug_overlay.enabled = false  # Start disabled
		add_child(_debug_overlay)
		# Register with DebugPanelManager
		DebugPanelManager.register_panel("terrain", _debug_overlay)
		print("TerrainRenderer: Created debug overlay on-demand")

	_debug_overlay.toggle()
	print("TerrainRenderer: Debug overlay toggled to: ", _debug_overlay.enabled)


func get_performance_metrics() -> Dictionary:
	"""Get performance metrics from the streaming system"""
	if not _streaming_manager:
		return {}

	return _streaming_manager.get_performance_metrics()


func get_loaded_chunk_count() -> int:
	"""Get the number of currently loaded chunks"""
	if not _chunk_manager:
		return 0

	return _chunk_manager.get_chunk_count()


func get_memory_usage_mb() -> float:
	"""Get current memory usage in megabytes"""
	if not _chunk_manager:
		return 0.0

	return _chunk_manager.get_memory_usage_mb()


func get_loading_progress() -> float:
	"""Get loading progress (0.0 to 1.0)"""
	if not _streaming_manager:
		return 1.0

	return _streaming_manager.get_loading_progress()


# ============================================================================
# Sonar Integration
# ============================================================================


func get_terrain_geometry_for_sonar(
	origin: Vector3, max_range: float, simplification_level: int = 1
) -> Dictionary:
	"""Get terrain geometry for sonar system"""
	if not _collision_manager:
		return {"positions": PackedVector3Array(), "normals": PackedVector3Array()}

	return _collision_manager.get_terrain_geometry_for_sonar(
		origin, max_range, simplification_level
	)


func get_surface_normal_for_sonar(world_pos: Vector3) -> Vector3:
	"""Get surface normal at position for sonar"""
	if not _collision_manager:
		return Vector3.UP

	return _collision_manager.get_surface_normal_for_sonar(world_pos)


func query_terrain_for_sonar_beam(
	origin: Vector3, direction: Vector3, max_range: float, beam_width: float = PI / 6.0
) -> Array[Dictionary]:
	"""Query terrain within sonar beam"""
	if not _collision_manager:
		return []

	return _collision_manager.query_terrain_for_sonar_beam(origin, direction, max_range, beam_width)
