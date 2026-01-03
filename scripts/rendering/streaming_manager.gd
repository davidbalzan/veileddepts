class_name StreamingManager extends Node
## Orchestrates chunk loading/unloading based on submarine position and memory constraints
##
## Responsibilities:
## - Monitor submarine position and determine needed chunks
## - Prioritize chunk loading by distance
## - Manage asynchronous chunk loading with frame time budget
## - Coordinate with ChunkManager for actual loading/unloading

## Configuration
@export var chunk_size: float = 512.0  # meters
@export var load_distance: float = 2048.0  # meters
@export var unload_distance: float = 3072.0  # meters
@export var max_chunks_per_frame: int = 1
@export var max_load_time_ms: float = 2.0

## Internal state
var _chunk_manager: ChunkManager = null
var _performance_monitor: PerformanceMonitor = null
var _chunk_renderer: ChunkRenderer = null
var _logger: TerrainLogger = null
var _submarine_position: Vector3 = Vector3.ZERO
var _load_queue: Array[Dictionary] = []  # Array of {coord: Vector2i, distance: float}
var _unload_queue: Array[Vector2i] = []
var _background_thread: Thread = null
var _thread_mutex: Mutex = Mutex.new()
var _thread_should_exit: bool = false
var _pending_load: Dictionary = {}  # {coord: Vector2i, chunk: TerrainChunk, complete: bool, error: String}
var _use_async_loading: bool = true  # Enable/disable async loading


func _ready() -> void:
	# Find or create logger
	_logger = get_node_or_null("/root/TerrainLogger")
	if not _logger:
		_logger = TerrainLogger.new()
		_logger.name = "TerrainLogger"

	# Find or create ChunkManager
	_chunk_manager = get_node_or_null("../ChunkManager")
	if not _chunk_manager:
		_chunk_manager = ChunkManager.new()
		_chunk_manager.chunk_size = chunk_size
		get_parent().add_child(_chunk_manager)
		_chunk_manager.name = "ChunkManager"

	# Sync chunk size
	_chunk_manager.chunk_size = chunk_size

	# Find or create PerformanceMonitor
	_performance_monitor = get_node_or_null("../PerformanceMonitor")
	if not _performance_monitor:
		_performance_monitor = PerformanceMonitor.new()
		get_parent().add_child(_performance_monitor)
		_performance_monitor.name = "PerformanceMonitor"

	# Connect performance signals
	_performance_monitor.lod_reduction_requested.connect(_on_lod_reduction_requested)
	_performance_monitor.emergency_unload_requested.connect(_on_emergency_unload_requested)

	# Find ChunkRenderer
	_chunk_renderer = get_node_or_null("../ChunkRenderer")
	if not _chunk_renderer:
		_chunk_renderer = ChunkRenderer.new()
		get_parent().add_child(_chunk_renderer)
		_chunk_renderer.name = "ChunkRenderer"

	if _logger:
		_logger.log_info(
			"StreamingManager",
			"Initialized",
			{
				"chunk_size": "%.1f" % chunk_size,
				"load_distance": "%.1f" % load_distance,
				"unload_distance": "%.1f" % unload_distance,
				"max_chunks_per_frame": str(max_chunks_per_frame),
				"max_load_time_ms": "%.1f" % max_load_time_ms,
				"async_loading": str(_use_async_loading)
			}
		)


func _exit_tree() -> void:
	# Clean up background thread
	if _background_thread and _background_thread.is_alive():
		_thread_mutex.lock()
		_thread_should_exit = true
		_thread_mutex.unlock()
		_background_thread.wait_to_finish()
		_background_thread = null


## Update streaming based on submarine position
##
## This is the main entry point called each frame to manage chunk streaming.
## Determines which chunks should be loaded/unloaded and processes the queues.
##
## @param submarine_position: Current submarine world position
func update(submarine_position: Vector3) -> void:
	# Begin frame time measurement
	if _performance_monitor:
		_performance_monitor.begin_frame()
		_performance_monitor.begin_terrain_operation()

	_submarine_position = submarine_position

	# Determine chunks that should be loaded
	_update_load_queue()

	# Determine chunks that should be unloaded
	_update_unload_queue()

	# Process queues
	_process_unload_queue()
	_process_load_queue()

	# Update LOD for loaded chunks based on distance
	_update_chunk_lods()

	# End terrain operation measurement
	if _performance_monitor:
		_performance_monitor.end_terrain_operation()
		_performance_monitor.end_frame()


## Force load a specific chunk
##
## @param chunk_coord: Chunk coordinates to load
func load_chunk(chunk_coord: Vector2i) -> void:
	if not _chunk_manager:
		return

	# Add to front of load queue with high priority
	var distance: float = _chunk_manager.get_distance_to_chunk(_submarine_position, chunk_coord)
	_load_queue.insert(0, {"coord": chunk_coord, "distance": distance})


## Force unload a specific chunk
##
## @param chunk_coord: Chunk coordinates to unload
func unload_chunk(chunk_coord: Vector2i) -> void:
	if not _chunk_manager:
		return

	_chunk_manager.unload_chunk(chunk_coord)


## Get loading progress (0.0 to 1.0)
##
## Returns the ratio of loaded chunks to total needed chunks.
##
## @return: Progress value between 0.0 and 1.0
func get_loading_progress() -> float:
	if _load_queue.is_empty():
		return 1.0

	var loaded_chunks: Array[Vector2i] = _chunk_manager.get_loaded_chunks()
	var needed_chunks: int = loaded_chunks.size() + _load_queue.size()

	if needed_chunks == 0:
		return 1.0

	return float(loaded_chunks.size()) / float(needed_chunks)


## Get list of currently loaded chunks
##
## @return: Array of Vector2i chunk coordinates
func get_loaded_chunks() -> Array[Vector2i]:
	if not _chunk_manager:
		return []

	return _chunk_manager.get_loaded_chunks()


## Enable or disable asynchronous loading
##
## @param enabled: True to enable async loading, false for synchronous
func set_async_loading(enabled: bool) -> void:
	_use_async_loading = enabled


## Check if asynchronous loading is enabled
##
## @return: True if async loading is enabled
func is_async_loading_enabled() -> bool:
	return _use_async_loading


## Update the load queue based on submarine position
##
## Calculates all chunks within load_distance and adds missing ones to the queue.
## Sorts queue by distance (closest first).
func _update_load_queue() -> void:
	if not _chunk_manager:
		return

	# Get all chunks within load distance
	var needed_chunks: Array[Vector2i] = _chunk_manager.get_chunks_in_radius(
		_submarine_position, load_distance
	)

	# Find chunks that need loading
	var to_load: Array[Dictionary] = []
	for chunk_coord in needed_chunks:
		# Skip if already loaded or in queue
		if _chunk_manager.is_chunk_loaded(chunk_coord):
			continue

		if _is_in_load_queue(chunk_coord):
			continue

		# Calculate distance for priority
		var distance: float = _chunk_manager.get_distance_to_chunk(_submarine_position, chunk_coord)
		to_load.append({"coord": chunk_coord, "distance": distance})

	# Add to load queue
	_load_queue.append_array(to_load)

	# Sort by distance (closest first)
	_load_queue.sort_custom(_compare_load_priority)


## Update the unload queue based on submarine position
##
## Finds all loaded chunks beyond unload_distance and adds them to unload queue.
func _update_unload_queue() -> void:
	if not _chunk_manager:
		return

	var loaded_chunks: Array[Vector2i] = _chunk_manager.get_loaded_chunks()

	for chunk_coord in loaded_chunks:
		var distance: float = _chunk_manager.get_distance_to_chunk(_submarine_position, chunk_coord)

		# If beyond unload distance, add to unload queue
		if distance > unload_distance:
			if not _unload_queue.has(chunk_coord):
				_unload_queue.append(chunk_coord)


## Process the unload queue
##
## Unloads all chunks in the unload queue immediately.
func _process_unload_queue() -> void:
	if not _chunk_manager:
		return

	while not _unload_queue.is_empty():
		var chunk_coord: Vector2i = _unload_queue.pop_front()
		_chunk_manager.unload_chunk(chunk_coord)
		
		# Log chunk unload to console
		if LogRouter:
			LogRouter.log(
				"Chunk unloaded at (%d, %d)" % [chunk_coord.x, chunk_coord.y],
				LogRouter.LogLevel.DEBUG,
				"terrain"
			)


## Process the load queue with frame time budget
##
## Loads chunks from the queue respecting max_chunks_per_frame and max_load_time_ms.
## Uses asynchronous loading when enabled to avoid blocking the main thread.
func _process_load_queue() -> void:
	if not _chunk_manager:
		return

	if _load_queue.is_empty():
		return

	# Check if we have a pending async load to complete
	if _use_async_loading and not _pending_load.is_empty():
		_check_async_load_completion()
		return

	var start_time: int = Time.get_ticks_msec()
	var chunks_loaded: int = 0

	while not _load_queue.is_empty() and chunks_loaded < max_chunks_per_frame:
		# Check frame time budget
		var elapsed_ms: float = Time.get_ticks_msec() - start_time
		if elapsed_ms >= max_load_time_ms:
			break

		# Get next chunk to load
		var load_item: Dictionary = _load_queue.pop_front()
		var chunk_coord: Vector2i = load_item["coord"]

		# Skip if already loaded (might have been loaded by another system)
		if _chunk_manager.is_chunk_loaded(chunk_coord):
			continue

		# Load the chunk (async or sync)
		if _use_async_loading:
			_start_async_load(chunk_coord)
			chunks_loaded += 1
			break  # Only start one async load at a time
		else:
			_chunk_manager.load_chunk(chunk_coord)
			chunks_loaded += 1
			
			# Log chunk load to console
			if LogRouter:
				LogRouter.log(
					"Chunk loaded at (%d, %d)" % [chunk_coord.x, chunk_coord.y],
					LogRouter.LogLevel.DEBUG,
					"terrain"
				)


## Start asynchronous chunk loading in background thread
##
## @param chunk_coord: Chunk coordinates to load
func _start_async_load(chunk_coord: Vector2i) -> void:
	# Initialize pending load data
	_thread_mutex.lock()
	_pending_load = {"coord": chunk_coord, "chunk": null, "complete": false, "error": ""}
	_thread_mutex.unlock()

	# Start background thread
	if _background_thread != null:
		_background_thread.wait_to_finish()
		_background_thread = null
		
	_background_thread = Thread.new()
	var error: int = _background_thread.start(_background_load_chunk.bind(chunk_coord))

	if error != OK:
		push_error("StreamingManager: Failed to start background thread: %d" % error)
		_thread_mutex.lock()
		_pending_load = {}
		_thread_mutex.unlock()
		# Fall back to synchronous loading
		_chunk_manager.load_chunk(chunk_coord)


## Background thread function for loading a chunk
##
## This runs in a separate thread to avoid blocking the main thread.
## Due to Godot threading restrictions, we can only prepare data here,
## not create scene nodes. The main thread will finalize the chunk.
##
## @param chunk_coord: Chunk coordinates to load
func _background_load_chunk(chunk_coord: Vector2i) -> void:
	var start_time: int = Time.get_ticks_msec()

	# Check if we should exit
	_thread_mutex.lock()
	var should_exit: bool = _thread_should_exit
	_thread_mutex.unlock()

	if should_exit:
		return

	# Simulate heavy data preparation work
	# In a real implementation, this would:
	# - Extract elevation data from world map
	# - Generate procedural detail
	# - Detect biomes
	# - Prepare mesh data
	# All without touching the scene tree

	var error_msg: String = ""

	# Simulate some work (in real implementation, this would be actual data processing)
	OS.delay_msec(1)  # Minimal delay to simulate work

	var elapsed_ms: float = Time.get_ticks_msec() - start_time

	# Update pending load status
	_thread_mutex.lock()
	_pending_load["complete"] = true
	_pending_load["error"] = error_msg
	_thread_mutex.unlock()

	print(
		(
			"StreamingManager: Background preparation of chunk %s completed in %.2f ms"
			% [chunk_coord, elapsed_ms]
		)
	)


## Check if async load is complete and finalize it on main thread
func _check_async_load_completion() -> void:
	_thread_mutex.lock()
	var is_complete: bool = _pending_load.get("complete", false)
	var chunk_coord: Vector2i = _pending_load.get("coord", Vector2i.ZERO)
	var error_msg: String = _pending_load.get("error", "")
	_thread_mutex.unlock()

	if not is_complete:
		return

	# Wait for thread to finish
	if _background_thread != null:
		_background_thread.wait_to_finish()
		_background_thread = null

	# Handle errors
	if error_msg != "":
		push_error(
			"StreamingManager: Async load failed for chunk %s: %s" % [chunk_coord, error_msg]
		)
		_thread_mutex.lock()
		_pending_load = {}
		_thread_mutex.unlock()
		return

	# Finalize loading on main thread
	# Due to Godot's threading restrictions, we need to do the actual loading here
	var start_time: int = Time.get_ticks_msec()
	_chunk_manager.load_chunk(chunk_coord)
	var elapsed_ms: float = Time.get_ticks_msec() - start_time
	
	# Log async chunk load to console
	if LogRouter:
		LogRouter.log(
			"Chunk loaded (async) at (%d, %d) in %.1fms" % [chunk_coord.x, chunk_coord.y, elapsed_ms],
			LogRouter.LogLevel.DEBUG,
			"terrain"
		)

	# Ensure we didn't exceed frame budget
	if elapsed_ms > max_load_time_ms:
		if _logger:
			_logger.log_performance_warning("chunk_load", elapsed_ms, max_load_time_ms)
		else:
			push_warning(
				(
					"StreamingManager: Chunk load exceeded frame budget: %.2f ms > %.2f ms"
					% [elapsed_ms, max_load_time_ms]
				)
			)

	# Clear pending load
	_thread_mutex.lock()
	_pending_load = {}
	_thread_mutex.unlock()


## Check if a chunk is already in the load queue
##
## @param chunk_coord: Chunk coordinates to check
## @return: True if chunk is in load queue
func _is_in_load_queue(chunk_coord: Vector2i) -> bool:
	for item in _load_queue:
		if item["coord"] == chunk_coord:
			return true
	return false


## Compare function for sorting load queue by distance
##
## @param a: First load item dictionary
## @param b: Second load item dictionary
## @return: True if a should come before b (a is closer)
func _compare_load_priority(a: Dictionary, b: Dictionary) -> bool:
	return a["distance"] < b["distance"]


## Update LOD levels for all loaded chunks based on distance
func _update_chunk_lods() -> void:
	if not _chunk_manager or not _chunk_renderer:
		return

	var loaded_chunks: Array[Vector2i] = _chunk_manager.get_loaded_chunks()

	for chunk_coord in loaded_chunks:
		var chunk: TerrainChunk = _chunk_manager.get_chunk(chunk_coord)
		if not chunk:
			continue

		var distance: float = _chunk_manager.get_distance_to_chunk(_submarine_position, chunk_coord)
		_chunk_renderer.update_chunk_lod(chunk, distance)


## Handle LOD reduction request from performance monitor
func _on_lod_reduction_requested() -> void:
	if not _chunk_manager or not _chunk_renderer:
		return

	if _logger:
		_logger.log_warning("StreamingManager", "Reducing LOD levels to improve performance", {})
	else:
		print("StreamingManager: Reducing LOD levels to improve performance")
	
	# Log to console
	if LogRouter:
		LogRouter.log(
			"Reducing LOD levels to improve performance",
			LogRouter.LogLevel.WARNING,
			"terrain"
		)

	# Reduce LOD for all loaded chunks
	var loaded_chunks: Array[Vector2i] = _chunk_manager.get_loaded_chunks()

	for chunk_coord in loaded_chunks:
		var chunk: TerrainChunk = _chunk_manager.get_chunk(chunk_coord)
		if not chunk:
			continue

		# Force lower LOD (increase LOD level number)
		var current_lod: int = chunk.current_lod
		var new_lod: int = min(current_lod + 1, _chunk_renderer.lod_levels - 1)

		if new_lod != current_lod:
			chunk.current_lod = new_lod
			if chunk.mesh_instance and chunk.lod_meshes.size() > new_lod:
				chunk.mesh_instance.mesh = chunk.lod_meshes[new_lod]

			if _logger:
				_logger.log_lod_change(chunk_coord, current_lod, new_lod, 0.0)


## Handle emergency unload request from performance monitor
func _on_emergency_unload_requested() -> void:
	if not _chunk_manager:
		return

	if _logger:
		_logger.log_warning("StreamingManager", "Emergency unloading distant chunks", {})
	else:
		print("StreamingManager: Emergency unloading distant chunks")
	
	# Log to console
	if LogRouter:
		LogRouter.log(
			"Emergency unloading distant chunks",
			LogRouter.LogLevel.WARNING,
			"terrain"
		)

	# Find furthest chunks and unload them
	var loaded_chunks: Array[Vector2i] = _chunk_manager.get_loaded_chunks()

	# Sort by distance (furthest first)
	var chunks_with_distance: Array[Dictionary] = []
	for chunk_coord in loaded_chunks:
		var distance: float = _chunk_manager.get_distance_to_chunk(_submarine_position, chunk_coord)
		chunks_with_distance.append({"coord": chunk_coord, "distance": distance})

	chunks_with_distance.sort_custom(func(a, b): return a["distance"] > b["distance"])

	# Unload furthest 25% of chunks
	var unload_count: int = max(1, loaded_chunks.size() / 4)

	for i in range(min(unload_count, chunks_with_distance.size())):
		var chunk_coord: Vector2i = chunks_with_distance[i]["coord"]
		_chunk_manager.unload_chunk(chunk_coord)


## Get performance metrics
func get_performance_metrics() -> Dictionary:
	if not _performance_monitor:
		return {}

	return _performance_monitor.get_performance_metrics()
