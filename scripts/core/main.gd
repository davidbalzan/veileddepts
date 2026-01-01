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
@onready var ocean_renderer: OceanRenderer = $OceanRenderer
@onready var terrain_renderer: Node = $TerrainRenderer
@onready var ai_system: Node = $AISystem

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
	"""Setup the ocean renderer reference (already exists in scene)"""
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
	
	print("Submarine physics created and initialized")


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
		
		# Update ocean renderer camera reference (in case view changed)
		_update_ocean_camera()


func _update_ocean_camera() -> void:
	"""Update ocean renderer camera to current active camera"""
	if not ocean_renderer:
		return
	
	var current_camera = get_viewport().get_camera_3d()
	if current_camera and ocean_renderer.camera != current_camera:
		ocean_renderer.camera = current_camera
