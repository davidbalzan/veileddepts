extends GutTest
## Unit tests for SealifeRenderer

const SealifeRenderer = preload("res://scripts/rendering/sealife_renderer.gd")

var sealife_renderer

func before_each():
	# Create sealife renderer
	sealife_renderer = SealifeRenderer.new()

func after_each():
	if sealife_renderer:
		sealife_renderer.free()
		sealife_renderer = null

func test_sealife_renderer_creates():
	assert_not_null(sealife_renderer, "SealifeRenderer should be created")

func test_default_parameters():
	assert_almost_eq(sealife_renderer.max_render_distance, 200.0, 0.001, "Default max render distance should be 200")
	assert_almost_eq(sealife_renderer.foam_culling_threshold, 0.5, 0.001, "Default foam culling threshold should be 0.5")
	assert_eq(sealife_renderer.fish_count, 100, "Default fish count should be 100")
	assert_almost_eq(sealife_renderer.spawn_radius, 150.0, 0.001, "Default spawn radius should be 150")

func test_spawn_depth_parameters():
	assert_almost_eq(sealife_renderer.spawn_depth_min, -50.0, 0.001, "Default min spawn depth should be -50")
	assert_almost_eq(sealife_renderer.spawn_depth_max, -5.0, 0.001, "Default max spawn depth should be -5")

func test_fish_scale_parameters():
	assert_almost_eq(sealife_renderer.fish_scale_min, 0.3, 0.001, "Default min fish scale should be 0.3")
	assert_almost_eq(sealife_renderer.fish_scale_max, 0.8, 0.001, "Default max fish scale should be 0.8")

func test_animation_parameters():
	assert_almost_eq(sealife_renderer.swim_speed, 2.0, 0.001, "Default swim speed should be 2.0")
	assert_almost_eq(sealife_renderer.swim_variation, 1.0, 0.001, "Default swim variation should be 1.0")
	assert_almost_eq(sealife_renderer.wave_amplitude, 0.5, 0.001, "Default wave amplitude should be 0.5")
	assert_almost_eq(sealife_renderer.wave_frequency, 2.0, 0.001, "Default wave frequency should be 2.0")

func test_update_interval():
	assert_almost_eq(sealife_renderer.update_interval, 0.5, 0.001, "Default update interval should be 0.5")

func test_foam_intensity_returns_float():
	# Foam intensity should return a value between 0 and 1
	var test_position = Vector3(0, -10, 0)
	var foam_intensity = sealife_renderer._get_foam_intensity_at(test_position)
	
	assert_typeof(foam_intensity, TYPE_FLOAT, "Foam intensity should be a float")
	assert_true(foam_intensity >= 0.0, "Foam intensity should be >= 0")
	assert_true(foam_intensity <= 1.0, "Foam intensity should be <= 1")

	
	assert_typeof(foam_intensity, TYPE_FLOAT, "Foam intensity should be a float")
	assert_true(foam_intensity >= 0.0, "Foam intensity should be >= 0")
	assert_true(foam_intensity <= 1.0, "Foam intensity should be <= 1")
