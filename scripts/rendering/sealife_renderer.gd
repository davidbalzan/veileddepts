class_name SealifeRenderer extends Node3D
## Sealife rendering system using GPU-accelerated instancing
## Renders sparse fish schools with distance and foam-based culling

# MultiMeshInstance for fish schools
var fish_multimesh_instance: MultiMeshInstance3D

# Ocean renderer reference for foam-based culling
var ocean_renderer: OceanRenderer

# Camera reference for distance-based culling
var camera: Camera3D

# Culling parameters
@export_group("Culling Settings")
@export var max_render_distance: float = 200.0  # Distance-based culling threshold
@export var foam_culling_threshold: float = 0.5  # Foam intensity threshold for culling
@export var update_interval: float = 0.5  # How often to update culling (seconds)

# Fish school parameters
@export_group("Fish School Settings")
@export var fish_count: int = 100  # Number of fish instances
@export var spawn_radius: float = 150.0  # Radius around submarine to spawn fish
@export var spawn_depth_min: float = -50.0  # Minimum depth for fish
@export var spawn_depth_max: float = -5.0  # Maximum depth for fish
@export var fish_scale_min: float = 0.3  # Minimum fish scale
@export var fish_scale_max: float = 0.8  # Maximum fish scale

# Animation parameters
@export_group("Animation Settings")
@export var swim_speed: float = 2.0  # Base swimming speed
@export var swim_variation: float = 1.0  # Speed variation per fish
@export var wave_amplitude: float = 0.5  # Vertical wave motion amplitude
@export var wave_frequency: float = 2.0  # Vertical wave motion frequency

# Internal state
var _time_accumulator: float = 0.0
var _fish_positions: Array[Vector3] = []
var _fish_velocities: Array[Vector3] = []
var _fish_scales: Array[float] = []
var _fish_wave_offsets: Array[float] = []
var _initialized: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("_setup_sealife")

func _setup_sealife() -> void:
	"""Initialize the sealife rendering system"""
	
	# Check if we have a rendering device (not available in headless mode)
	var rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_warning("SealifeRenderer: No RenderingDevice available (headless mode?). Using fallback.")
		_initialized = true
		return
	
	# Get camera reference
	camera = get_viewport().get_camera_3d()
	if not camera:
		push_warning("SealifeRenderer: No camera found, sealife rendering disabled")
		_initialized = true
		return
	
	# Find ocean renderer
	var ocean_nodes = get_tree().get_nodes_in_group("ocean_renderer")
	if ocean_nodes.size() > 0:
		ocean_renderer = ocean_nodes[0] as OceanRenderer
	else:
		push_warning("SealifeRenderer: No ocean renderer found, foam culling disabled")
	
	# Create fish mesh (simple low-poly fish)
	var fish_mesh = _create_fish_mesh()
	
	# Create MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = fish_count
	multimesh.mesh = fish_mesh
	
	# Create MultiMeshInstance
	fish_multimesh_instance = MultiMeshInstance3D.new()
	fish_multimesh_instance.multimesh = multimesh
	fish_multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fish_multimesh_instance)
	
	# Initialize fish positions and velocities
	_initialize_fish_school()
	
	_initialized = true
	print("SealifeRenderer: Initialized with ", fish_count, " fish instances")

func _create_fish_mesh() -> Mesh:
	"""Create a simple low-poly fish mesh"""
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Simple fish shape: elongated diamond
	# Body vertices
	var body_length = 1.0
	var body_width = 0.3
	var body_height = 0.2
	
	# Front point
	surface_tool.add_vertex(Vector3(body_length * 0.5, 0, 0))
	# Top
	surface_tool.add_vertex(Vector3(0, body_height, 0))
	# Bottom
	surface_tool.add_vertex(Vector3(0, -body_height, 0))
	# Left
	surface_tool.add_vertex(Vector3(0, 0, body_width))
	# Right
	surface_tool.add_vertex(Vector3(0, 0, -body_width))
	# Back point (tail)
	surface_tool.add_vertex(Vector3(-body_length * 0.5, 0, 0))
	
	# Front triangles
	surface_tool.add_index(0)
	surface_tool.add_index(1)
	surface_tool.add_index(3)
	
	surface_tool.add_index(0)
	surface_tool.add_index(3)
	surface_tool.add_index(2)
	
	surface_tool.add_index(0)
	surface_tool.add_index(2)
	surface_tool.add_index(4)
	
	surface_tool.add_index(0)
	surface_tool.add_index(4)
	surface_tool.add_index(1)
	
	# Back triangles
	surface_tool.add_index(5)
	surface_tool.add_index(3)
	surface_tool.add_index(1)
	
	surface_tool.add_index(5)
	surface_tool.add_index(2)
	surface_tool.add_index(3)
	
	surface_tool.add_index(5)
	surface_tool.add_index(4)
	surface_tool.add_index(2)
	
	surface_tool.add_index(5)
	surface_tool.add_index(1)
	surface_tool.add_index(4)
	
	surface_tool.generate_normals()
	
	var mesh = surface_tool.commit()
	
	# Create simple material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.5, 0.7, 1.0)  # Blueish fish color
	material.metallic = 0.2
	material.roughness = 0.8
	mesh.surface_set_material(0, material)
	
	return mesh

func _initialize_fish_school() -> void:
	"""Initialize fish positions, velocities, and properties"""
	_fish_positions.clear()
	_fish_velocities.clear()
	_fish_scales.clear()
	_fish_wave_offsets.clear()
	
	for i in range(fish_count):
		# Random position within spawn radius
		var angle = randf() * TAU
		var radius = randf() * spawn_radius
		var depth = randf_range(spawn_depth_min, spawn_depth_max)
		
		var pos = Vector3(
			cos(angle) * radius,
			depth,
			sin(angle) * radius
		)
		_fish_positions.append(pos)
		
		# Random velocity (swimming direction)
		var swim_angle = randf() * TAU
		var speed = swim_speed + randf_range(-swim_variation, swim_variation)
		var vel = Vector3(
			cos(swim_angle) * speed,
			0,
			sin(swim_angle) * speed
		)
		_fish_velocities.append(vel)
		
		# Random scale
		var scale = randf_range(fish_scale_min, fish_scale_max)
		_fish_scales.append(scale)
		
		# Random wave offset for animation variation
		_fish_wave_offsets.append(randf() * TAU)
	
	# Update transforms immediately
	_update_fish_transforms()

func _process(delta: float) -> void:
	if not _initialized:
		return
	
	# Update fish animation
	_animate_fish(delta)
	
	# Update culling periodically
	_time_accumulator += delta
	if _time_accumulator >= update_interval:
		_update_culling()
		_time_accumulator = 0.0

func _animate_fish(delta: float) -> void:
	"""Animate fish swimming motion"""
	# Guard against empty arrays (can happen if called before initialization)
	var count = mini(mini(_fish_positions.size(), _fish_velocities.size()), mini(_fish_scales.size(), _fish_wave_offsets.size()))
	if count == 0:
		return
	
	for i in range(count):
		# Update position based on velocity
		_fish_positions[i] += _fish_velocities[i] * delta
		
		# Add vertical wave motion
		var wave_offset = _fish_wave_offsets[i]
		var wave_motion = sin(Time.get_ticks_msec() * 0.001 * wave_frequency + wave_offset) * wave_amplitude
		_fish_positions[i].y += wave_motion * delta
		
		# Keep fish within spawn area (simple boundary)
		var distance_from_origin = Vector2(_fish_positions[i].x, _fish_positions[i].z).length()
		if distance_from_origin > spawn_radius:
			# Turn fish back toward center
			var to_center = -Vector2(_fish_positions[i].x, _fish_positions[i].z).normalized()
			_fish_velocities[i].x = to_center.x * swim_speed
			_fish_velocities[i].z = to_center.y * swim_speed
		
		# Keep fish within depth range
		if _fish_positions[i].y < spawn_depth_min:
			_fish_positions[i].y = spawn_depth_min
		elif _fish_positions[i].y > spawn_depth_max:
			_fish_positions[i].y = spawn_depth_max
	
	# Update transforms
	_update_fish_transforms()

func _update_fish_transforms() -> void:
	"""Update MultiMesh instance transforms"""
	if not fish_multimesh_instance or not fish_multimesh_instance.multimesh:
		return
	
	var count = _fish_positions.size()
	for i in range(count):
		var pos = _fish_positions[i]
		var vel = _fish_velocities[i]
		var scale = _fish_scales[i]
		
		# Calculate rotation to face swimming direction
		var forward = vel.normalized()
		if forward.length() > 0.01:
			var transform = Transform3D()
			transform.origin = pos
			
			# Look in direction of movement
			var up = Vector3.UP
			var right = forward.cross(up).normalized()
			if right.length() < 0.01:
				right = Vector3.RIGHT
			up = right.cross(forward).normalized()
			
			transform.basis.x = right * scale
			transform.basis.y = up * scale
			transform.basis.z = -forward * scale
			
			fish_multimesh_instance.multimesh.set_instance_transform(i, transform)
		else:
			# No movement, just scale
			var transform = Transform3D()
			transform.origin = pos
			transform.basis = transform.basis.scaled(Vector3(scale, scale, scale))
			fish_multimesh_instance.multimesh.set_instance_transform(i, transform)

func _update_culling() -> void:
	"""Update visibility culling based on distance and foam"""
	if not camera or not fish_multimesh_instance or not fish_multimesh_instance.multimesh:
		return
	
	var camera_pos = camera.global_position
	var count = _fish_positions.size()
	
	for i in range(count):
		var fish_pos = _fish_positions[i]
		
		# Distance-based culling
		var distance = camera_pos.distance_to(fish_pos)
		var should_cull = distance > max_render_distance
		
		# Foam-based culling (if ocean renderer available)
		if not should_cull and ocean_renderer:
			var foam_intensity = _get_foam_intensity_at(fish_pos)
			if foam_intensity > foam_culling_threshold:
				should_cull = true
		
		# Update visibility by scaling to zero (culled) or normal scale (visible)
		if should_cull:
			# Scale to zero to hide
			var transform = fish_multimesh_instance.multimesh.get_instance_transform(i)
			transform.basis = Basis().scaled(Vector3.ZERO)
			fish_multimesh_instance.multimesh.set_instance_transform(i, transform)
		# If not culled, normal transform is already set by _update_fish_transforms

func _get_foam_intensity_at(position: Vector3) -> float:
	"""Get foam intensity at a world position (placeholder implementation)"""
	# This is a simplified implementation
	# In a full implementation, we would query the ocean shader's foam texture
	# For now, we'll use a simple heuristic based on wave height variation
	
	if not ocean_renderer:
		return 0.0
	
	# Sample wave height at position and nearby points
	var center_height = ocean_renderer.get_wave_height_3d(position)
	var offset = 2.0
	var north_height = ocean_renderer.get_wave_height_3d(position + Vector3(0, 0, offset))
	var south_height = ocean_renderer.get_wave_height_3d(position + Vector3(0, 0, -offset))
	var east_height = ocean_renderer.get_wave_height_3d(position + Vector3(offset, 0, 0))
	var west_height = ocean_renderer.get_wave_height_3d(position + Vector3(-offset, 0, 0))
	
	# Calculate variation (proxy for foam - high variation = breaking waves = foam)
	var variation = abs(north_height - south_height) + abs(east_height - west_height)
	
	# Normalize to 0-1 range (assuming max variation of ~4 meters)
	return clamp(variation / 4.0, 0.0, 1.0)

func set_spawn_center(center: Vector3) -> void:
	"""Update the center point for fish spawning (e.g., follow submarine)"""
	if not _initialized:
		return
	
	# Shift all fish positions relative to new center
	var offset = center - global_position
	for i in range(_fish_positions.size()):
		_fish_positions[i] += offset
	
	global_position = center

func get_visible_fish_count() -> int:
	"""Get the number of currently visible (non-culled) fish"""
	if not fish_multimesh_instance or not fish_multimesh_instance.multimesh:
		return 0
	
	var visible_count = 0
	for i in range(fish_count):
		var transform = fish_multimesh_instance.multimesh.get_instance_transform(i)
		# Check if scaled to zero (culled)
		if transform.basis.get_scale().length() > 0.01:
			visible_count += 1
	
	return visible_count
