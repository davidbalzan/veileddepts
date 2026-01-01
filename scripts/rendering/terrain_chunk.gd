## TerrainChunk class for managing individual terrain chunks
##
## Represents a single chunk of terrain with all its associated data:
## heightmaps, biome maps, rendering meshes, and collision geometry.
## Manages the chunk's lifecycle state and memory tracking.

class_name TerrainChunk extends Node3D

## Chunk identification
var chunk_coord: Vector2i = Vector2i.ZERO
var world_bounds: Rect2 = Rect2()

## Terrain data
var base_heightmap: Image = null
var detail_heightmap: Image = null
var biome_map: Image = null
var bump_map: Image = null

## Rendering
var mesh_instance: MeshInstance3D = null
var lod_meshes: Array[ArrayMesh] = []
var current_lod: int = 0
var material: ShaderMaterial = null

## Collision
var static_body: StaticBody3D = null
var collision_shape: CollisionShape3D = null

## State
var state: int = 0  # ChunkState.State enum value
var last_access_time: float = 0.0
var memory_size_bytes: int = 0

## Neighbors (for stitching) - maps direction Vector2i to TerrainChunk
var neighbors: Dictionary = {}


func _init() -> void:
	last_access_time = Time.get_ticks_msec() / 1000.0


## Update the last access time to current time
func touch() -> void:
	last_access_time = Time.get_ticks_msec() / 1000.0


## Calculate approximate memory usage in bytes
func calculate_memory_size() -> int:
	var size: int = 0
	
	# Heightmap images
	if base_heightmap:
		size += base_heightmap.get_width() * base_heightmap.get_height() * 4  # Assuming float format
	if detail_heightmap:
		size += detail_heightmap.get_width() * detail_heightmap.get_height() * 4
	if biome_map:
		size += biome_map.get_width() * biome_map.get_height() * 1  # Assuming byte format
	if bump_map:
		size += bump_map.get_width() * bump_map.get_height() * 4  # RGBA
	
	# LOD meshes (rough estimate)
	for mesh in lod_meshes:
		if mesh:
			size += 1024  # Rough estimate per mesh
	
	memory_size_bytes = size
	return size


## Clean up all resources
func cleanup() -> void:
	# Clear images
	base_heightmap = null
	detail_heightmap = null
	biome_map = null
	bump_map = null
	
	# Clear meshes
	lod_meshes.clear()
	
	# Remove rendering components
	if mesh_instance:
		mesh_instance.queue_free()
		mesh_instance = null
	
	# Remove collision components
	if collision_shape:
		collision_shape.queue_free()
		collision_shape = null
	if static_body:
		static_body.queue_free()
		static_body = null
	
	# Clear material
	material = null
	
	# Clear neighbors
	neighbors.clear()
	
	memory_size_bytes = 0
	state = 0  # ChunkState.State.UNLOADED
