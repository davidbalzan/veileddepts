class_name SubmarineBubbleTrail extends Node3D
## Creates underwater bubble trails along the submarine fuselage and behind rudder/prop
##
## Spawns GPU particles for:
## - Fuselage bubbles (along the hull when moving underwater)
## - Rudder bubbles (behind control surfaces)
## - Propeller bubbles (cavitation from the propeller)

@export var enabled: bool = true
@export var min_speed_for_bubbles: float = 2.0  # Minimum speed to show bubbles (m/s)
@export var max_depth_for_effect: float = 500.0  # Maximum depth for bubble effects

var submarine_body: RigidBody3D

# Particle emitters
var fuselage_bubbles_port: GPUParticles3D
var fuselage_bubbles_starboard: GPUParticles3D
var fuselage_bubbles_top: GPUParticles3D
var rudder_bubbles: GPUParticles3D
var propeller_bubbles: GPUParticles3D

# Materials
var bubble_material: StandardMaterial3D


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	# Find submarine
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		submarine_body = main.get_node_or_null("SubmarineModel")

	if not submarine_body:
		push_warning("SubmarineBubbleTrail: SubmarineModel not found")
		return

	_create_bubble_material()
	_create_fuselage_bubbles()
	_create_rudder_bubbles()
	_create_propeller_bubbles()

	print("SubmarineBubbleTrail: Initialized with underwater bubble effects")


func _create_bubble_material() -> void:
	# Material for bubbles - small translucent spheres
	bubble_material = StandardMaterial3D.new()
	bubble_material.albedo_color = Color(0.9, 0.95, 1.0, 0.6)
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Add slight rim lighting effect
	bubble_material.rim_enabled = true
	bubble_material.rim = 0.3
	bubble_material.rim_tint = 0.5


func _create_fuselage_bubbles() -> void:
	# Port side bubbles - along the left side of the hull
	fuselage_bubbles_port = GPUParticles3D.new()
	fuselage_bubbles_port.name = "FuselageBubblesPort"
	fuselage_bubbles_port.amount = 80
	fuselage_bubbles_port.lifetime = 2.5
	fuselage_bubbles_port.explosiveness = 0.0
	fuselage_bubbles_port.randomness = 0.4
	fuselage_bubbles_port.emitting = false

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.1, 0.5, 8.0)  # Long strip along the hull
	mat.direction = Vector3(-0.3, 1.0, -0.2)  # Mostly up, slight outward and back
	mat.spread = 20.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0, 2.0, 0)  # Bubbles float up
	mat.damping_min = 0.3
	mat.damping_max = 0.8
	mat.scale_min = 0.02  # 2cm bubbles
	mat.scale_max = 0.08  # 8cm bubbles
	mat.color = Color(0.9, 0.95, 1.0, 0.6)
	
	# Add some turbulence for realistic movement
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.5
	mat.turbulence_noise_scale = 2.0
	mat.turbulence_influence_min = 0.05
	mat.turbulence_influence_max = 0.15

	fuselage_bubbles_port.process_material = mat

	# Use sphere mesh for bubbles
	var sphere = SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 6
	sphere.radius = 0.05
	sphere.height = 0.1
	fuselage_bubbles_port.draw_pass_1 = sphere
	fuselage_bubbles_port.material_override = bubble_material

	# Position along left side of submarine
	fuselage_bubbles_port.position = Vector3(-1.5, 0, 0)
	add_child(fuselage_bubbles_port)

	# Starboard side bubbles - mirror of port
	fuselage_bubbles_starboard = GPUParticles3D.new()
	fuselage_bubbles_starboard.name = "FuselageBubblesStarboard"
	fuselage_bubbles_starboard.amount = 80
	fuselage_bubbles_starboard.lifetime = 2.5
	fuselage_bubbles_starboard.explosiveness = 0.0
	fuselage_bubbles_starboard.randomness = 0.4
	fuselage_bubbles_starboard.emitting = false

	var starboard_mat = mat.duplicate()
	starboard_mat.direction = Vector3(0.3, 1.0, -0.2)  # Mirror direction
	fuselage_bubbles_starboard.process_material = starboard_mat
	fuselage_bubbles_starboard.draw_pass_1 = sphere.duplicate()
	fuselage_bubbles_starboard.material_override = bubble_material.duplicate()

	# Position along right side of submarine
	fuselage_bubbles_starboard.position = Vector3(1.5, 0, 0)
	add_child(fuselage_bubbles_starboard)

	# Top bubbles - along the top of the hull
	fuselage_bubbles_top = GPUParticles3D.new()
	fuselage_bubbles_top.name = "FuselageBubblesTop"
	fuselage_bubbles_top.amount = 60
	fuselage_bubbles_top.lifetime = 2.0
	fuselage_bubbles_top.explosiveness = 0.0
	fuselage_bubbles_top.randomness = 0.5
	fuselage_bubbles_top.emitting = false

	var top_mat = ParticleProcessMaterial.new()
	top_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	top_mat.emission_box_extents = Vector3(1.0, 0.1, 7.0)  # Wide strip along top
	top_mat.direction = Vector3(0, 1.0, -0.3)  # Up and back
	top_mat.spread = 25.0
	top_mat.initial_velocity_min = 0.5
	top_mat.initial_velocity_max = 1.5
	top_mat.gravity = Vector3(0, 2.5, 0)  # Stronger float up
	top_mat.damping_min = 0.4
	top_mat.damping_max = 1.0
	top_mat.scale_min = 0.03
	top_mat.scale_max = 0.1
	top_mat.color = Color(0.85, 0.92, 1.0, 0.5)
	
	top_mat.turbulence_enabled = true
	top_mat.turbulence_noise_strength = 0.6
	top_mat.turbulence_noise_scale = 1.5
	top_mat.turbulence_influence_min = 0.1
	top_mat.turbulence_influence_max = 0.2

	fuselage_bubbles_top.process_material = top_mat
	fuselage_bubbles_top.draw_pass_1 = sphere.duplicate()
	fuselage_bubbles_top.material_override = bubble_material.duplicate()

	# Position on top of submarine
	fuselage_bubbles_top.position = Vector3(0, 1.2, 0)
	add_child(fuselage_bubbles_top)


func _create_rudder_bubbles() -> void:
	# Bubbles from rudder and control surfaces
	rudder_bubbles = GPUParticles3D.new()
	rudder_bubbles.name = "RudderBubbles"
	rudder_bubbles.amount = 100
	rudder_bubbles.lifetime = 2.0
	rudder_bubbles.explosiveness = 0.0
	rudder_bubbles.randomness = 0.5
	rudder_bubbles.emitting = false

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.8, 0.8, 0.3)  # Around rudder area
	mat.direction = Vector3(0, 0.5, 1.0)  # Up and back
	mat.spread = 35.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.5
	mat.gravity = Vector3(0, 1.5, 0)  # Float up
	mat.damping_min = 0.5
	mat.damping_max = 1.2
	mat.scale_min = 0.03
	mat.scale_max = 0.12
	mat.color = Color(0.88, 0.94, 1.0, 0.6)
	
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.8
	mat.turbulence_noise_scale = 1.8
	mat.turbulence_influence_min = 0.1
	mat.turbulence_influence_max = 0.25

	rudder_bubbles.process_material = mat

	var sphere = SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 6
	sphere.radius = 0.06
	sphere.height = 0.12
	rudder_bubbles.draw_pass_1 = sphere
	rudder_bubbles.material_override = bubble_material.duplicate()

	# Position at tail/rudder area
	rudder_bubbles.position = Vector3(0, 0, 11)
	add_child(rudder_bubbles)


func _create_propeller_bubbles() -> void:
	# Cavitation bubbles from propeller
	propeller_bubbles = GPUParticles3D.new()
	propeller_bubbles.name = "PropellerBubbles"
	propeller_bubbles.amount = 150
	propeller_bubbles.lifetime = 3.0
	propeller_bubbles.explosiveness = 0.1  # Slight burst effect
	propeller_bubbles.randomness = 0.6
	propeller_bubbles.emitting = false

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.6  # Around propeller
	mat.direction = Vector3(0, 0, 1.0)  # Backward
	mat.spread = 40.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0, 1.2, 0)  # Slow float up
	mat.damping_min = 0.8
	mat.damping_max = 1.8
	mat.scale_min = 0.02
	mat.scale_max = 0.15
	
	# Color variation for more realism
	mat.color = Color(0.9, 0.96, 1.0, 0.7)
	mat.color_ramp = _create_bubble_color_ramp()
	
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 1.0
	mat.turbulence_noise_scale = 2.5
	mat.turbulence_influence_min = 0.15
	mat.turbulence_influence_max = 0.35

	propeller_bubbles.process_material = mat

	var sphere = SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 6
	sphere.radius = 0.05
	sphere.height = 0.1
	propeller_bubbles.draw_pass_1 = sphere
	
	var prop_material = bubble_material.duplicate()
	prop_material.albedo_color = Color(0.92, 0.97, 1.0, 0.65)
	propeller_bubbles.material_override = prop_material

	# Position at propeller (stern)
	propeller_bubbles.position = Vector3(0, 0, 12)
	add_child(propeller_bubbles)


func _create_bubble_color_ramp() -> GradientTexture1D:
	# Create color gradient for bubbles fading over time
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.96, 1.0, 0.8))
	gradient.add_point(0.5, Color(0.85, 0.93, 1.0, 0.5))
	gradient.add_point(1.0, Color(0.8, 0.9, 1.0, 0.1))
	
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _process(_delta: float) -> void:
	if not enabled or not submarine_body:
		_stop_all_emitters()
		return

	# Get submarine state
	var sub_pos = submarine_body.global_position
	var sub_velocity = submarine_body.linear_velocity
	var speed = Vector2(sub_velocity.x, sub_velocity.z).length()
	var depth = abs(sub_pos.y)  # Depth below sea level

	# Update this node's position and rotation to follow submarine
	global_position = sub_pos
	global_rotation = submarine_body.global_rotation

	# Check if submarine is underwater and moving
	var underwater = sub_pos.y < -3.0  # At least 3m below surface
	var shallow_enough = depth < max_depth_for_effect
	var moving = speed > min_speed_for_bubbles

	if underwater and shallow_enough and moving:
		# Scale particle emission based on speed
		var speed_factor = clamp(speed / 15.0, 0.2, 1.0)
		
		# Fuselage bubbles - less intense
		if fuselage_bubbles_port:
			fuselage_bubbles_port.emitting = true
			fuselage_bubbles_port.amount_ratio = speed_factor * 0.5
		if fuselage_bubbles_starboard:
			fuselage_bubbles_starboard.emitting = true
			fuselage_bubbles_starboard.amount_ratio = speed_factor * 0.5
		if fuselage_bubbles_top:
			fuselage_bubbles_top.emitting = true
			fuselage_bubbles_top.amount_ratio = speed_factor * 0.4
		
		# Rudder bubbles - moderate intensity
		if rudder_bubbles:
			rudder_bubbles.emitting = true
			rudder_bubbles.amount_ratio = speed_factor * 0.7
		
		# Propeller bubbles - most intense
		if propeller_bubbles:
			propeller_bubbles.emitting = true
			propeller_bubbles.amount_ratio = clamp(speed / 12.0, 0.3, 1.0)
	else:
		_stop_all_emitters()


func _stop_all_emitters() -> void:
	if fuselage_bubbles_port:
		fuselage_bubbles_port.emitting = false
	if fuselage_bubbles_starboard:
		fuselage_bubbles_starboard.emitting = false
	if fuselage_bubbles_top:
		fuselage_bubbles_top.emitting = false
	if rudder_bubbles:
		rudder_bubbles.emitting = false
	if propeller_bubbles:
		propeller_bubbles.emitting = false
