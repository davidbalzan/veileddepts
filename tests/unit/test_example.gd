extends GutTest
## Example test to verify Gut testing framework is working


func test_example_assertion():
	"""Basic test to verify testing framework is operational."""
	assert_true(true, "This test should always pass")
	assert_eq(1 + 1, 2, "Basic arithmetic should work")


func test_godot_version():
	"""Verify we're running on Godot 4.x."""
	var version = Engine.get_version_info()
	assert_eq(version.major, 4, "Should be running Godot 4.x")
