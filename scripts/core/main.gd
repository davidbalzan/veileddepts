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

# Physics and rendering systems
var submarine_physics: Node  # SubmarinePhysics instance
var submarine_body: RigidBody3D
var ocean_renderer: OceanRenderer

func _ready() -> void:
	print("Tactical Submarine Simulator - Initializing...")
	print("Godot Version: ", Engine.get_version_info())
	print("Rendering API: ", RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device() else "Unknown")
	
	# Initialize systems
	_initialize_systems()
	
	print("Initialization complete.")

func _initialize_systems() -> void:
	"""Initialize all game systems in the correct order."""
	# Create submarine rigid body
	_create_submarine_body()
	
	# Create ocean renderer
	_create_ocean_renderer()
	
	# Create and initialize submarine physics
	_create_submarine_physics()
	
	print("All systems initialized")

func _create_submarine_body() -> void:
	"""Create the submarine rigid body for physics simulation"""
	submarine_body = RigidBody3D.new()
	submarine_body.name = "SubmarineBody"
	add_child(submarine_body)
	
	# Set initial position at surface
	submarine_body.global_position = Vector3.ZERO
	
	# Add collision shape (simplified box for now)
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(10.0, 5.0, 50.0)  # Approximate submarine dimensions
	collision_shape.shape = box_shape
	submarine_body.add_child(collision_shape)
	
	# Configure physics properties
	submarine_body.mass = 8000000.0  # 8000 tons in kg
	submarine_body.gravity_scale = 1.0
	submarine_body.linear_damp = 0.1
	submarine_body.angular_damp = 0.5
	
	print("Submarine body created")

func _create_ocean_renderer() -> void:
	"""Create the ocean rendering system"""
	ocean_renderer = OceanRenderer.new()
	ocean_renderer.name = "OceanRenderer"
	add_child(ocean_renderer)
	
	print("Ocean renderer created")

func _create_submarine_physics() -> void:
	"""Create and initialize the submarine physics system"""
	submarine_physics = SubmarinePhysicsClass.new()
	submarine_physics.name = "SubmarinePhysics"
	add_child(submarine_physics)
	
	# Initialize with references to required systems
	submarine_physics.initialize(submarine_body, ocean_renderer, simulation_state)
	
	print("Submarine physics created and initialized")

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
