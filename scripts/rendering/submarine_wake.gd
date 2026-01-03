class_name SubmarineWake extends Node3D
## Creates foam and wake effects around the submarine when at or near the surface
##
## Spawns GPU particles for:
## - Bow wake (V-shaped spray at front)
## - Stern wake (propeller wash trail)
## - Hull foam (bubbles along sides when moving)
## - Persistent wake trail (behind submarine)

@export var enabled: bool = true
@export var surface_threshold: float = 5.0  # Max depth for wake effects (meters)
@export var min_speed_for_wake: float = 1.0  # Minimum speed to show wake (m/s)
@export var trail_length: float = 100.0  # Length of wake trail in meters
@export var trail_fade_time: float = 15.0  # How long trail persists (seconds)

var submarine_body: RigidBody3D
var ocean_renderer: OceanRenderer

# Particle emitters
var bow_wake: GPUParticles3D
var stern_wake: GPUParticles3D
var hull_foam_port: GPUParticles3D
var hull_foam_starboard: GPUParticles3D
var wake_trail: GPUParticles3D

# Materials
var foam_material: StandardMaterial3D


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	# Find submarine and ocean
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		submarine_body = main.get_node_or_null("SubmarineModel")
		ocean_renderer = main.get_node_or_null("OceanRenderer")

	if not submarine_body:
		push_warning("SubmarineWake: SubmarineModel not found")
		return

	_create_draw_material()
	_create_bow_wake()
	_create_stern_wake()
	_create_hull_foam()
	_create_wake_trail()

	print("SubmarineWake: Initialized with tiny particles and wake trail")


func _create_draw_material() -> void:
	# Draw material for all particles - small foam bubbles
	foam_material = StandardMaterial3D.new()
	foam_material.albedo_color = Color(0.95, 0.98, 1.0, 0.7)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED


func _create_bow_wake() -> void:
	bow_wake = GPUParticles3D.new()
	bow_wake.name = "BowWake"
	bow_wake.amount = 100  # More particles for denser foam
	bow_wake.lifetime = 1.0
	bow_wake.explosiveness = 0.0
	bow_wake.randomness = 0.3
	bow_wake.emitting = false

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.8, 0.1, 0.3)  # Thin horizontal spread
	mat.direction = Vector3(0, 0.3, -0.7)  # Mostly back, slight up
	mat.spread = 30.0
	mat.initial_velocity_min = 0.5  # Very slow - just foam
	mat.initial_velocity_max = 1.2  # Max ~1.2 m/s
	mat.gravity = Vector3(0, -1.0, 0)  # Light gravity
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.03  # 3cm particles
	mat.scale_max = 0.08  # 8cm particles max
	mat.color = Color(0.95, 0.97, 1.0, 0.6)
	bow_wake.process_material = mat

	# Tiny quad mesh for particles
	var quad = QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)  # 10cm base size
	bow_wake.draw_pass_1 = quad
	bow_wake.material_override = foam_material

	# Position at bow (front of submarine)
	bow_wake.position = Vector3(0, 0, -10)
	add_child(bow_wake)


func _create_stern_wake() -> void:
	stern_wake = GPUParticles3D.new()
	stern_wake.name = "SternWake"
	stern_wake.amount = 150  # More particles for propeller wash
	stern_wake.lifetime = 2.0
	stern_wake.explosiveness = 0.0
	stern_wake.randomness = 0.5
	stern_wake.emitting = false

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.5, 0.3, 0.5)  # Centered around propeller
	mat.direction = Vector3(0, 0.2, 1)  # Mostly backward
	mat.spread = 45.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, -0.5, 0)  # Very light gravity
	mat.damping_min = 0.8
	mat.damping_max = 1.5
	mat.scale_min = 0.05  # 5cm particles
	mat.scale_max = 0.15  # 15cm particles max
	mat.color = Color(0.90, 0.95, 1.0, 0.5)
	stern_wake.process_material = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)  # 12cm base size
	stern_wake.draw_pass_1 = quad

	var stern_material = foam_material.duplicate()
	stern_material.albedo_color = Color(0.92, 0.96, 1.0, 0.5)
	stern_wake.material_override = stern_material

	# Position at stern (rear of submarine)
	stern_wake.position = Vector3(0, 0, 10)
	add_child(stern_wake)


func _create_hull_foam() -> void:
	# Port side foam - tiny bubbles along hull
	hull_foam_port = GPUParticles3D.new()
	hull_foam_port.name = "HullFoamPort"
	hull_foam_port.amount = 60
	hull_foam_port.lifetime = 1.5
	hull_foam_port.emitting = false

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.2, 0.1, 6.0)  # Long strip along hull
	mat.direction = Vector3(-0.5, 0.3, 0)  # Away from hull, slight up
	mat.spread = 25.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0, -1.0, 0)
	mat.damping_min = 2.0
	mat.damping_max = 3.0
	mat.scale_min = 0.02  # 2cm particles (tiny bubbles)
	mat.scale_max = 0.06  # 6cm particles max
	mat.color = Color(0.95, 0.98, 1.0, 0.4)
	hull_foam_port.process_material = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)  # 8cm base size
	hull_foam_port.draw_pass_1 = quad

	var hull_material = foam_material.duplicate()
	hull_material.albedo_color = Color(0.95, 0.98, 1.0, 0.4)
	hull_foam_port.material_override = hull_material

	hull_foam_port.position = Vector3(-1.3, 0, 0)
	add_child(hull_foam_port)

	# Starboard side foam (mirror of port)
	hull_foam_starboard = GPUParticles3D.new()
	hull_foam_starboard.name = "HullFoamStarboard"
	hull_foam_starboard.amount = 60
	hull_foam_starboard.lifetime = 1.5
	hull_foam_starboard.emitting = false

	var starboard_mat = mat.duplicate()
	starboard_mat.direction = Vector3(0.5, 0.3, 0)  # Mirror direction
	hull_foam_starboard.process_material = starboard_mat
	hull_foam_starboard.draw_pass_1 = quad.duplicate()
	hull_foam_starboard.material_override = hull_material.duplicate()

	hull_foam_starboard.position = Vector3(1.3, 0, 0)
	add_child(hull_foam_starboard)


func _create_wake_trail() -> void:
	# Persistent wake trail that follows behind the submarine
	wake_trail = GPUParticles3D.new()
	wake_trail.name = "WakeTrail"
	wake_trail.amount = 400  # Many particles for continuous trail
	wake_trail.lifetime = trail_fade_time
	wake_trail.explosiveness = 0.0
	wake_trail.randomness = 0.2
	wake_trail.emitting = false

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1.0, 0.05, 0.5)  # Wide, thin line at stern
	mat.direction = Vector3(0, 0, 0)  # No initial movement
	mat.spread = 5.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.1
	mat.gravity = Vector3(0, 0, 0)  # No gravity - stays on surface
	mat.damping_min = 0.1
	mat.damping_max = 0.3
	mat.scale_min = 0.1  # 10cm particles
	mat.scale_max = 0.25  # 25cm particles

	# Use color ramp for fading
	mat.color = Color(0.85, 0.92, 1.0, 0.35)

	# Scale curve - particles grow slightly then shrink
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.3))
	mat.scale_curve = CurveTexture.new()
	mat.scale_curve.curve = scale_curve

	# Alpha curve - fade out over time
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.8))
	alpha_curve.add_point(Vector2(0.3, 0.6))
	alpha_curve.add_point(Vector2(1.0, 0.0))
	mat.alpha_curve = CurveTexture.new()
	mat.alpha_curve.curve = alpha_curve

	wake_trail.process_material = mat

	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)  # 20cm base size
	wake_trail.draw_pass_1 = quad

	var trail_material = StandardMaterial3D.new()
	trail_material.albedo_color = Color(0.90, 0.95, 1.0, 0.5)
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	wake_trail.material_override = trail_material

	# Position at stern
	wake_trail.position = Vector3(0, 0, 12)
	add_child(wake_trail)


func _process(_delta: float) -> void:
	if not enabled or not submarine_body:
		_stop_all_emitters()
		return

	# Get submarine state
	var sub_pos = submarine_body.global_position
	var sub_velocity = submarine_body.linear_velocity
	var speed = Vector2(sub_velocity.x, sub_velocity.z).length()

	# Get wave height at submarine position
	var wave_height = 0.0
	if ocean_renderer and ocean_renderer.initialized:
		wave_height = ocean_renderer.get_wave_height_3d(sub_pos)

	# Calculate depth below surface
	var depth_below_surface = wave_height - sub_pos.y

	# Update this node's position to follow submarine
	global_position = sub_pos
	global_rotation.y = submarine_body.global_rotation.y

	# Adjust particle Y position to wave surface
	var surface_offset = wave_height - sub_pos.y
	if bow_wake:
		bow_wake.position.y = surface_offset
	if stern_wake:
		stern_wake.position.y = surface_offset
	if hull_foam_port:
		hull_foam_port.position.y = surface_offset
	if hull_foam_starboard:
		hull_foam_starboard.position.y = surface_offset
	if wake_trail:
		wake_trail.position.y = surface_offset

	# Enable/disable emitters based on depth and speed
	var near_surface = depth_below_surface < surface_threshold and depth_below_surface > -2.0
	var moving = speed > min_speed_for_wake

	if near_surface and moving:
		# Scale particle emission based on speed
		var speed_factor = clamp(speed / 10.0, 0.3, 1.0)

		if bow_wake:
			bow_wake.emitting = true
			bow_wake.amount_ratio = speed_factor
		if stern_wake:
			stern_wake.emitting = true
			stern_wake.amount_ratio = speed_factor
		if hull_foam_port:
			hull_foam_port.emitting = true
			hull_foam_port.amount_ratio = speed_factor * 0.6
		if hull_foam_starboard:
			hull_foam_starboard.emitting = true
			hull_foam_starboard.amount_ratio = speed_factor * 0.6
		if wake_trail:
			wake_trail.emitting = true
			# Trail emission rate based on speed
			wake_trail.amount_ratio = clamp(speed / 8.0, 0.2, 1.0)
	else:
		_stop_all_emitters()


func _stop_all_emitters() -> void:
	if bow_wake:
		bow_wake.emitting = false
	if stern_wake:
		stern_wake.emitting = false
	if hull_foam_port:
		hull_foam_port.emitting = false
	if hull_foam_starboard:
		hull_foam_starboard.emitting = false
	if wake_trail:
		wake_trail.emitting = false
