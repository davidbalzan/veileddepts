extends GutTest
## Unit tests for OceanRenderer (tessarakkt.oceanfft integration)

var ocean_renderer: OceanRenderer

func before_each():
	ocean_renderer = OceanRenderer.new()
	# Set up a camera for the ocean renderer
	var camera = Camera3D.new()
	camera.far = 16000.0
	add_child_autofree(camera)
	camera.make_current()
	
	add_child_autofree(ocean_renderer)
	# Wait for initialization
	await get_tree().process_frame
	await get_tree().process_frame

func after_each():
	if ocean_renderer:
		ocean_renderer.queue_free()
		ocean_renderer = null

func test_ocean_renderer_initializes():
	assert_not_null(ocean_renderer, "OceanRenderer should be created")
	# Give time for async initialization
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(ocean_renderer.initialized, "OceanRenderer should be initialized")

func test_ocean_has_ocean3d_resource():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# In headless mode (no RenderingDevice), ocean won't be created
	var rd = RenderingServer.get_rendering_device()
	if rd == null:
		pass_test("Skipping ocean resource test in headless mode")
		return
	
	assert_not_null(ocean_renderer.ocean, "Ocean3D resource should be created")

func test_ocean_has_quad_tree():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# In headless mode (no RenderingDevice), quad_tree won't be created
	var rd = RenderingServer.get_rendering_device()
	if rd == null:
		pass_test("Skipping quad tree test in headless mode")
		return
	
	assert_not_null(ocean_renderer.quad_tree, "QuadTree3D should be created")

func test_wind_speed_property():
	ocean_renderer.wind_speed = 20.0
	assert_almost_eq(ocean_renderer.wind_speed, 20.0, 0.001, "Wind speed should be set")

func test_wind_direction_property():
	ocean_renderer.wind_direction_degrees = 90.0
	assert_almost_eq(ocean_renderer.wind_direction_degrees, 90.0, 0.001, "Wind direction should be set")

func test_choppiness_property():
	ocean_renderer.choppiness = 2.0
	assert_almost_eq(ocean_renderer.choppiness, 2.0, 0.001, "Choppiness should be set")

func test_time_scale_property():
	ocean_renderer.time_scale = 0.5
	assert_almost_eq(ocean_renderer.time_scale, 0.5, 0.001, "Time scale should be set")

func test_get_wave_height_returns_float():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var test_position = Vector2(100.0, 200.0)
	var wave_height = ocean_renderer.get_wave_height(test_position)
	
	assert_typeof(wave_height, TYPE_FLOAT, "Wave height should be a float")

func test_get_wave_height_3d_returns_float():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var test_position = Vector3(100.0, 0.0, 200.0)
	var wave_height = ocean_renderer.get_wave_height_3d(test_position)
	
	assert_typeof(wave_height, TYPE_FLOAT, "Wave height 3D should be a float")

func test_set_wind():
	ocean_renderer.set_wind(25.0, 180.0)
	
	assert_almost_eq(ocean_renderer.wind_speed, 25.0, 0.001, "Wind speed should be updated")
	assert_almost_eq(ocean_renderer.wind_direction_degrees, 180.0, 0.001, "Wind direction should be updated")

func test_get_wind_direction():
	ocean_renderer.wind_direction_degrees = 0.0
	var wind_dir = ocean_renderer.get_wind_direction()
	
	assert_almost_eq(wind_dir.x, 1.0, 0.001, "Wind direction X should be 1 at 0 degrees")
	assert_almost_eq(wind_dir.y, 0.0, 0.001, "Wind direction Y should be 0 at 0 degrees")

func test_get_wind_direction_90_degrees():
	ocean_renderer.wind_direction_degrees = 90.0
	var wind_dir = ocean_renderer.get_wind_direction()
	
	assert_almost_eq(wind_dir.x, 0.0, 0.001, "Wind direction X should be 0 at 90 degrees")
	assert_almost_eq(wind_dir.y, 1.0, 0.001, "Wind direction Y should be 1 at 90 degrees")

func test_apply_buoyancy_with_null_body():
	# Should not crash with null body
	ocean_renderer.apply_buoyancy(null)
	pass_test("apply_buoyancy handles null body gracefully")

func test_apply_buoyancy_with_rigid_body():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var rigid_body = RigidBody3D.new()
	rigid_body.mass = 1000.0
	add_child_autofree(rigid_body)
	rigid_body.global_position = Vector3(0, -5, 0)  # Below water
	
	# Should not crash
	ocean_renderer.apply_buoyancy(rigid_body)
	pass_test("apply_buoyancy works with RigidBody3D")

func test_default_parameters():
	assert_almost_eq(ocean_renderer.wind_speed, 15.0, 0.001, "Default wind speed should be 15")
	assert_almost_eq(ocean_renderer.choppiness, 1.8, 0.001, "Default choppiness should be 1.8")
	assert_almost_eq(ocean_renderer.time_scale, 1.0, 0.001, "Default time scale should be 1.0")

func test_fft_resolution_index():
	assert_eq(ocean_renderer.fft_resolution_index, 2, "Default FFT resolution index should be 2 (256x256)")

func test_horizontal_dimension():
	assert_eq(ocean_renderer.horizontal_dimension, 512, "Default horizontal dimension should be 512")

func test_lod_level():
	assert_eq(ocean_renderer.lod_level, 5, "Default LOD level should be 5")

func test_quad_size():
	assert_almost_eq(ocean_renderer.quad_size, 8192.0, 0.001, "Default quad size should be 8192")
