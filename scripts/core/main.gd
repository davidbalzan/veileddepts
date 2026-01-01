extends Node
## Main entry point for the Tactical Submarine Simulator
##
## This script initializes all core systems and manages the main game loop.

# Preload physics class
const SubmarinePhysicsClass = preload("res://scripts/physics/submarine_physics.gd")

# References to core systems
@onready var view_manager: Node = $ViewManager
@onready var simulation_state: SimulationState = $SimulationState
@onready var input_system: Node = $InputSystem
@onready var audio_system: Node = $AudioSystem
@onready var sonar_system: Node = $SonarSystem
@onready var terrain_renderer: Node = $TerrainRenderer
@onready var ai_system: Node = $AISystem

# Ocean renderer - found dynamically to avoid type issues
var ocean_renderer: OceanRenderer

# Physics and rendering systems
var submarine_physics: Node  # SubmarinePhysics instance
var submarine_body: RigidBody3D

func _ready() -> void:
	print("Tactical Submarine Simulator - Initializing...")
	print("Godot Version: ", Engine.get_version_info())
	print("Rendering API: ", RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device() else "Unknown")
	
	# Initialize systems (async to wait for terrain)
	await _initialize_systems()
	
	print("Initialization complete.")

func _initialize_systems() -> void:
	"""Initialize all game systems in the correct order."""
	# Setup terrain first (needed for spawn position calculation)
	await _setup_terrain_renderer()
	
	# Create submarine rigid body and position it safely
	_create_submarine_body()
	
	# Get reference to ocean renderer (already in scene)
	_setup_ocean_renderer()
	
	# Create and initialize submarine physics
	_create_submarine_physics()
	
	# Initialize AI system
	_setup_ai_system()
	
	print("All systems initialized")

func _create_submarine_body() -> void:
	"""Get reference to the submarine rigid body from the scene"""
	submarine_body = get_node_or_null("SubmarineModel")
	
	if not submarine_body:
		push_error("SubmarineModel not found in scene!")
		return
	
	# Add collision shape
	var collision_shape = submarine_body.get_node_or_null("CollisionShape3D")
	if collision_shape and not collision_shape.shape:
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(10.0, 5.0, 50.0)  # Approximate submarine dimensions
		collision_shape.shape = box_shape
	
	# Position submarine in safe water location using terrain data
	if terrain_renderer and terrain_renderer.initialized:
		var safe_position = terrain_renderer.find_safe_spawn_position(Vector3.ZERO, 1000.0, -50.0)
		submarine_body.global_position = safe_position
		print("Submarine spawned at safe position: ", safe_position)
	else:
		# Fallback to default depth if terrain not ready
		submarine_body.global_position = Vector3(0, -50, 0)
		print("Submarine spawned at default position (terrain not ready)")
	
	print("Submarine body initialized - mass=%.0f kg" % submarine_body.mass)

func _setup_ocean_renderer() -> void:
	"""Setup the ocean renderer reference (find it in scene)"""
	var ocean_nodes = get_tree().get_nodes_in_group("ocean_renderer")
	if ocean_nodes.size() > 0:
		ocean_renderer = ocean_nodes[0] as OceanRenderer
		if ocean_renderer:
			print("Using ocean renderer from scene")
			_ensure_ocean_camera()
	else:
		push_error("OceanRenderer not found in scene! Add it to main.tscn")


func _setup_terrain_renderer() -> void:
	"""Setup the terrain renderer and wait for initialization"""
	if terrain_renderer:
		# Terrain renderer initializes itself in _ready()
		# We need to wait for it to be ready
		var max_wait_frames = 10
		var frames_waited = 0
		
		while not terrain_renderer.initialized and frames_waited < max_wait_frames:
			print("Waiting for terrain to initialize...")
			await get_tree().process_frame
			frames_waited += 1
		
		if terrain_renderer.initialized:
			print("Terrain renderer ready")
			var terrain_height_range = "%.1f to %.1f meters" % [terrain_renderer.min_height, terrain_renderer.max_height]
			print("  Height range: ", terrain_height_range)
			print("  Using external heightmap: ", terrain_renderer.use_external_heightmap)
			print("  Micro detail enabled: ", terrain_renderer.enable_micro_detail)
		else:
			push_warning("Terrain renderer failed to initialize after waiting")
	else:
		push_error("TerrainRenderer not found in scene! Add it to main.tscn")


func _create_submarine_physics() -> void:
	"""Create and initialize the submarine physics system"""
	submarine_physics = SubmarinePhysicsClass.new()
	submarine_physics.name = "SubmarinePhysics"
	add_child(submarine_physics)
	
	# Initialize with references to required systems
	submarine_physics.initialize(submarine_body, ocean_renderer, simulation_state)
	
	# Load default submarine class if using SubmarinePhysicsV2
	if submarine_physics.has_method("load_submarine_class"):
		submarine_physics.load_submarine_class("Default")
		print("Submarine physics created with Default class")
	else:
		print("Submarine physics created and initialized")


## Change the submarine class at runtime
## Available classes: Los_Angeles_Class, Ohio_Class, Virginia_Class, Seawolf_Class, Default
func change_submarine_class(submarine_class: String) -> bool:
	if not submarine_physics:
		push_error("Submarine physics not initialized")
		return false
	
	if not submarine_physics.has_method("load_submarine_class"):
		push_error("Current physics system does not support submarine classes")
		return false
	
	var success = submarine_physics.load_submarine_class(submarine_class)
	if success:
		print("Changed submarine class to: ", submarine_class)
		# Reset velocity to prevent physics issues when mass changes
		if submarine_body:
			submarine_body.linear_velocity = Vector3.ZERO
			submarine_body.angular_velocity = Vector3.ZERO
	else:
		push_error("Failed to load submarine class: ", submarine_class)
	
	return success


## Get list of available submarine classes
func get_available_submarine_classes() -> Array[String]:
	if not submarine_physics:
		return []
	
	if submarine_physics.has_method("get_available_classes"):
		return submarine_physics.get_available_classes()
	
	return []


func _setup_ai_system() -> void:
	"""Setup the AI system with references to simulation state and submarine"""
	if ai_system:
		ai_system.set_simulation_state(simulation_state)
		ai_system.set_submarine_node(submarine_body)
		print("AI system initialized")
		
		# Spawn a test patrol for demonstration
		_spawn_demo_patrol()
	else:
		push_error("AISystem not found in scene! Add it to main.tscn")


func _spawn_demo_patrol() -> void:
	"""Spawn a demonstration air patrol for testing"""
	# Create a circular patrol around the submarine's starting position
	var patrol_center = Vector3(0, 0, 0)
	var patrol_radius = 1000.0  # 1km radius
	var patrol_altitude = 200.0  # 200m altitude
	
	# Spawn the patrol
	ai_system.spawn_circular_patrol(patrol_center, patrol_radius, 6, patrol_altitude)
	print("Demo air patrol spawned")


func _ensure_ocean_camera() -> void:
	"""Ensure the ocean renderer has a camera for wave height queries"""
	if not ocean_renderer:
		return
	
	# Find the current camera in the scene
	var camera = get_viewport().get_camera_3d()
	if camera:
		ocean_renderer.camera = camera
		print("Ocean renderer camera set to: ", camera.name)
	else:
		# Create a temporary camera for physics queries
		var physics_camera = Camera3D.new()
		physics_camera.name = "PhysicsCamera"
		physics_camera.position = Vector3(0, 50, 100)
		physics_camera.far = 16000.0
		add_child(physics_camera)
		ocean_renderer.camera = physics_camera
		print("Created physics camera for ocean renderer")

func _process(_delta: float) -> void:
	"""Main game loop - called every frame."""
	pass

func _physics_process(delta: float) -> void:
	"""Physics update loop - called at fixed timestep (60 Hz)."""
	if submarine_physics and submarine_body:
		# Update submarine physics
		submarine_physics.update_physics(delta)
		
		# Synchronize physics state back to simulation state
		var physics_state = submarine_physics.get_submarine_state()
		if not physics_state.is_empty():
			simulation_state.update_submarine_state(
				physics_state["position"],
				physics_state["velocity"],
				physics_state["depth"],
				physics_state["heading"],
				physics_state["speed"]
			)
		
		# Update ocean renderer camera reference (only if in a 3D view)
		if view_manager.current_view in [ViewManager.ViewType.PERISCOPE, ViewManager.ViewType.EXTERNAL]:
			_update_ocean_camera()
		
		# Proactively manage 3D visibility to avoid shader errors in 2D views
		_manage_3d_visibility()


func _update_ocean_camera() -> void:
	"""Update ocean renderer camera to current active camera"""
	if not ocean_renderer:
		return
	
	var current_camera = get_viewport().get_camera_3d()
	if current_camera and is_instance_valid(current_camera) and current_camera.is_visible_in_tree():
		if ocean_renderer.camera != current_camera:
			print("Main: Updating ocean camera to ", current_camera.name)
			ocean_renderer.camera = current_camera
	else:
		# Don't unset it, keep the last good one to avoid null pointer errors in some ocean versions
		pass

func _manage_3d_visibility() -> void:
	"""Hide 3D systems when in 2D views to save performance and avoid shader errors"""
	if not view_manager:
		return
		
	var is_2d_view = view_manager.current_view in [ViewManager.ViewType.TACTICAL_MAP, ViewManager.ViewType.WHOLE_MAP]
	var show_3d = not is_2d_view
	
	if ocean_renderer:
		ocean_renderer.visible = show_3d
	if terrain_renderer:
		terrain_renderer.visible = show_3d
	if submarine_body:
		submarine_body.visible = show_3d
	
	# Sealife usually depends on ocean, hide it too
	var sealife = get_node_or_null("SealifeRenderer")
	if sealife:
		sealife.visible = show_3d


## Teleport submarine to a new position
func teleport_submarine(target_position: Vector3) -> void:
	if not submarine_body:
		return
	
	print("Main: Teleporting submarine to %s" % target_position)
	
	# Keep current depth if target_position.y is 0 (default from map)
	var final_pos = target_position
	if abs(target_position.y) < 0.1:
		final_pos.y = submarine_body.global_position.y
	
	# Update rigid body position and reset physics state for stability
	submarine_body.global_position = final_pos
	submarine_body.linear_velocity = Vector3.ZERO
	submarine_body.angular_velocity = Vector3.ZERO
	
	# Reset rotation to level
	var current_heading = submarine_body.rotation.y
	submarine_body.rotation = Vector3(0, current_heading, 0)
	
	# Synchronize simulation state immediately
	if simulation_state:
		simulation_state.update_submarine_state(
			final_pos,
			Vector3.ZERO,
			-final_pos.y,
			rad_to_deg(current_heading),
			0.0
		)
		
		# Also reset target waypoint and speed to prevent immediate movement
		simulation_state.update_submarine_command(
			final_pos,
			0.0,
			-final_pos.y
		)
	
	print("Main: Teleportation complete")


## Teleport submarine and shift terrain mission area
## Used by the Whole Map to jump to a new part of the world
func teleport_and_shift(click_uv: Vector2) -> void:
	if not terrain_renderer:
		push_error("Main: TerrainRenderer not found for teleport_and_shift")
		return
	
	print("Main: Shifting mission area to UV %s" % click_uv)
	
	# Calculate new region rect (centered on click_uv, same 0.1 size)
	var new_region = Rect2(
		click_uv.x - 0.05,
		click_uv.y - 0.05,
		0.1,
		0.1
	)
	
	# Update terrain renderer (this will regenerate the mesh and collision)
	if terrain_renderer.has_method("set_terrain_region"):
		terrain_renderer.set_terrain_region(new_region)
	
	# Teleport submarine to center of new mission area
	# Reset to surface (depth 20) or similar
	teleport_submarine(Vector3(0, -20.0, 0))
	
	print("Main: Mission shift complete")
