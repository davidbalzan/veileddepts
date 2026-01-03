extends Node

## Test script to verify tactical map terrain generation and F2 debug overlay


func _ready():
	print("=== Tactical Map Debug Test ===")

	# Wait for scene to load
	await get_tree().create_timer(2.0).timeout

	# Find tactical map view
	var tactical_map = get_node_or_null("/root/Main/TacticalMapView")
	if not tactical_map:
		print("ERROR: TacticalMapView not found")
		get_tree().quit()
		return

	print("Found TacticalMapView")

	# Check terrain renderer
	var terrain_renderer = get_node_or_null("/root/Main/TerrainRenderer")
	if not terrain_renderer:
		print("ERROR: TerrainRenderer not found")
		get_tree().quit()
		return

	print("Found TerrainRenderer")
	print("  Initialized: ", terrain_renderer.initialized)

	# Check elevation provider
	var elevation_provider = terrain_renderer.get_node_or_null("ElevationDataProvider")
	if not elevation_provider:
		print("ERROR: ElevationDataProvider not found")
	else:
		print("Found ElevationDataProvider")

	# Check if tactical map has terrain texture
	await get_tree().create_timer(1.0).timeout
	print("Tactical map terrain_texture: ", tactical_map.terrain_texture != null)
	print("Tactical map show_terrain: ", tactical_map.show_terrain)

	# Try to toggle debug overlay
	print("\nTesting F2 debug overlay toggle...")
	terrain_renderer.toggle_debug_overlay()

	await get_tree().create_timer(0.5).timeout

	# Check if debug overlay was created
	var debug_overlay = terrain_renderer.get_node_or_null("TerrainDebugOverlay")
	if debug_overlay:
		print("Debug overlay created successfully")
		print("  Enabled: ", debug_overlay.enabled)
		print("  Visible: ", debug_overlay.visible)
	else:
		print("ERROR: Debug overlay not created")

	print("\n=== Test Complete ===")
	get_tree().quit()
