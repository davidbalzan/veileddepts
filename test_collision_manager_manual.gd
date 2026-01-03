extends Node
## Manual test for CollisionManager
##
## This script tests the CollisionManager functionality in a simple scene.

const CollisionManager = preload("res://scripts/rendering/collision_manager.gd")

var collision_manager: CollisionManager
var chunk_manager: ChunkManager
var elevation_provider: ElevationDataProvider


func _ready() -> void:
	print("=== CollisionManager Manual Test ===")

	# Create elevation provider
	elevation_provider = ElevationDataProvider.new()
	add_child(elevation_provider)
	elevation_provider.initialize()

	# Create chunk manager
	chunk_manager = ChunkManager.new()
	chunk_manager.chunk_size = 512.0
	add_child(chunk_manager)

	# Create collision manager
	collision_manager = CollisionManager.new()
	add_child(collision_manager)
	collision_manager.set_chunk_manager(chunk_manager)

	# Run tests immediately (no await)
	_run_tests()


func _run_tests() -> void:
	print("\n--- Test 1: Load chunk and create collision ---")
	var chunk_coord := Vector2i(0, 0)
	var chunk: TerrainChunk = chunk_manager.load_chunk(chunk_coord)

	if chunk and chunk.base_heightmap:
		print("✓ Chunk loaded successfully")

		# Create collision
		collision_manager.create_collision(chunk)

		if chunk.static_body and chunk.collision_shape:
			print("✓ Collision geometry created")

			var shape: HeightMapShape3D = chunk.collision_shape.shape as HeightMapShape3D
			if shape:
				print(
					(
						"✓ HeightMapShape3D created (resolution: %dx%d)"
						% [shape.map_width, shape.map_depth]
					)
				)
			else:
				print("✗ Failed to create HeightMapShape3D")
		else:
			print("✗ Failed to create collision geometry")
	else:
		print("✗ Failed to load chunk")

	print("\n--- Test 2: Height query ---")
	var test_pos := Vector2(0.0, 0.0)
	var height: float = collision_manager.get_height_at(test_pos)
	print("Height at (0, 0): %.2f m" % height)

	if height >= -11000.0 and height <= 9000.0:
		print("✓ Height is in reasonable range")
	else:
		print("✗ Height is out of range")

	print("\n--- Test 3: Underwater safety check ---")
	var underwater_pos := Vector3(0.0, -100.0, 0.0)
	var is_safe: bool = collision_manager.is_underwater_safe(underwater_pos, 5.0)
	print("Position at -100m is safe: %s" % is_safe)

	var above_sea := Vector3(0.0, 10.0, 0.0)
	var is_safe_above: bool = collision_manager.is_underwater_safe(above_sea, 5.0)
	print("Position at +10m is safe: %s (should be false)" % is_safe_above)

	if not is_safe_above:
		print("✓ Correctly rejects above sea level")
	else:
		print("✗ Failed to reject above sea level")

	print("\n--- Test 4: Raycast ---")
	var ray_origin := Vector3(0.0, 100.0, 0.0)
	var ray_direction := Vector3(0.0, -1.0, 0.0)
	var result: Dictionary = collision_manager.raycast(ray_origin, ray_direction, 200.0)

	if result.get("hit", false):
		print("✓ Raycast hit terrain")
		print("  Hit position: %s" % result.get("position"))
		print("  Hit normal: %s" % result.get("normal"))
		print("  Distance: %.2f m" % result.get("distance"))
	else:
		print("✗ Raycast did not hit terrain")

	print("\n--- Test 5: Remove collision ---")
	collision_manager.remove_collision(chunk)

	if not chunk.static_body and not chunk.collision_shape:
		print("✓ Collision removed successfully")
	else:
		print("✗ Failed to remove collision")

	print("\n=== Tests Complete ===")
	get_tree().quit()
