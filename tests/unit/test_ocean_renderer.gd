extends GutTest
## Unit tests for OceanRenderer

var ocean_renderer: OceanRenderer

func before_each():
	ocean_renderer = OceanRenderer.new()
	add_child_autofree(ocean_renderer)
	# Wait for _ready to complete
	await get_tree().process_frame

func after_each():
	if ocean_renderer:
		ocean_renderer.queue_free()
		ocean_renderer = null

func test_ocean_renderer_initializes():
	assert_not_null(ocean_renderer, "OceanRenderer should be created")
	assert_not_null(ocean_renderer.ocean_mesh, "Ocean mesh should be initialized")
	assert_not_null(ocean_renderer.ocean_material, "Ocean material should be initialized")

func test_wave_spectrum_generation():
	var wind_speed = 15.0
	var wind_direction = Vector2(1.0, 0.5).normalized()
	
	ocean_renderer.generate_wave_spectrum(wind_speed, wind_direction)
	
	assert_almost_eq(ocean_renderer.wind_speed, wind_speed, 0.001, "Wind speed should be set")
	assert_almost_eq(ocean_renderer.wind_direction.x, wind_direction.x, 0.001, "Wind direction X should be set")
	assert_almost_eq(ocean_renderer.wind_direction.y, wind_direction.y, 0.001, "Wind direction Y should be set")
	assert_not_null(ocean_renderer.wave_spectrum, "Wave spectrum texture should be generated")

func test_get_wave_height_returns_value():
	var test_position = Vector2(100.0, 200.0)
	var wave_height = ocean_renderer.get_wave_height(test_position)
	
	assert_typeof(wave_height, TYPE_FLOAT, "Wave height should be a float")
	# Wave height should be within reasonable bounds
	assert_true(abs(wave_height) < 100.0, "Wave height should be within reasonable bounds")

func test_get_wave_height_at_different_positions():
	var pos1 = Vector2(0.0, 0.0)
	var pos2 = Vector2(100.0, 100.0)
	
	var height1 = ocean_renderer.get_wave_height(pos1)
	var height2 = ocean_renderer.get_wave_height(pos2)
	
	# Different positions should generally give different heights
	# (though they could occasionally be the same)
	assert_typeof(height1, TYPE_FLOAT, "Height at pos1 should be float")
	assert_typeof(height2, TYPE_FLOAT, "Height at pos2 should be float")

func test_wave_textures_initialized():
	assert_not_null(ocean_renderer.displacement_texture, "Displacement texture should be initialized")
	assert_not_null(ocean_renderer.normal_texture, "Normal texture should be initialized")
	assert_not_null(ocean_renderer.foam_texture, "Foam texture should be initialized")
	assert_not_null(ocean_renderer.caustics_texture, "Caustics texture should be initialized")

func test_update_waves():
	var initial_time = ocean_renderer.time
	ocean_renderer.update_waves(0.1)
	
	assert_gt(ocean_renderer.time, initial_time, "Time should advance after update_waves")

func test_phillips_spectrum_positive():
	var k = Vector2(0.1, 0.1)
	var spectrum_value = ocean_renderer._phillips_spectrum(k)
	
	assert_gte(spectrum_value, 0.0, "Phillips spectrum should be non-negative")

func test_phillips_spectrum_zero_for_zero_k():
	var k = Vector2(0.0, 0.0)
	var spectrum_value = ocean_renderer._phillips_spectrum(k)
	
	assert_almost_eq(spectrum_value, 0.0, 0.001, "Phillips spectrum should be zero for k=0")

func test_apply_buoyancy_with_null_body():
	# Should not crash with null body
	ocean_renderer.apply_buoyancy(null)
	pass_test("apply_buoyancy handles null body gracefully")

func test_apply_buoyancy_with_rigid_body():
	var rigid_body = RigidBody3D.new()
	add_child_autofree(rigid_body)
	rigid_body.global_position = Vector3(0, -5, 0)  # Below water
	
	# Should not crash
	ocean_renderer.apply_buoyancy(rigid_body)
	pass_test("apply_buoyancy works with RigidBody3D")

func test_foam_parameters_set():
	assert_typeof(ocean_renderer.foam_threshold, TYPE_FLOAT, "Foam threshold should be float")
	assert_typeof(ocean_renderer.foam_decay, TYPE_FLOAT, "Foam decay should be float")
	assert_lt(ocean_renderer.foam_threshold, 0.0, "Foam threshold should be negative")
	assert_gt(ocean_renderer.foam_decay, 0.0, "Foam decay should be positive")

func test_grid_size_is_power_of_two():
	var grid_size = ocean_renderer.grid_size
	# Check if power of 2
	var is_power_of_two = (grid_size > 0) and ((grid_size & (grid_size - 1)) == 0)
	assert_true(is_power_of_two, "Grid size should be power of 2 for FFT")

func test_ocean_material_has_shader():
	assert_not_null(ocean_renderer.ocean_material.shader, "Ocean material should have shader")

func test_caustics_texture_generated():
	assert_not_null(ocean_renderer.caustics_texture, "Caustics texture should be generated")
	var image = ocean_renderer.caustics_texture.get_image()
	assert_not_null(image, "Caustics texture should have image data")
	assert_eq(image.get_width(), 512, "Caustics texture should be 512x512")
	assert_eq(image.get_height(), 512, "Caustics texture should be 512x512")
