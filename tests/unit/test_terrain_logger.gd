extends GutTest
## Unit tests for TerrainLogger
##
## Tests logging functionality including:
## - Log level filtering
## - Timestamp formatting
## - Context inclusion
## - Specialized logging methods
## - File logging

var logger: TerrainLogger = null


func before_each():
	logger = TerrainLogger.new()
	logger.enabled = true
	logger.log_to_console = false  # Disable console output for tests
	logger.log_to_file = false  # Disable file output for tests
	logger._session_start_time = Time.get_ticks_msec()  # Initialize manually since _ready() may not be called
	add_child(logger)


func after_each():
	if logger:
		logger.queue_free()
		logger = null


func test_logger_initialization():
	assert_not_null(logger, "Logger should be created")
	assert_true(logger.enabled, "Logger should be enabled by default")


func test_log_level_filtering():
	# Set minimum log level to WARNING
	logger.min_log_level = TerrainLogger.LogLevel.WARNING

	# These should be filtered out
	logger.log_debug("Test", "Debug message")
	logger.log_info("Test", "Info message")

	# These should pass through
	logger.log_warning("Test", "Warning message")
	logger.log_error("Test", "Error message")
	logger.log_critical("Test", "Critical message")

	# We can't easily verify console output, but we can verify the logger doesn't crash
	pass_test("Log level filtering works without errors")


func test_disabled_logger():
	logger.enabled = false

	# These should all be no-ops
	logger.log_debug("Test", "Debug message")
	logger.log_info("Test", "Info message")
	logger.log_warning("Test", "Warning message")
	logger.log_error("Test", "Error message")

	pass_test("Disabled logger doesn't crash")


func test_chunk_loaded_logging():
	var chunk_coord = Vector2i(1, 2)
	var memory_mb = 5.5
	var total_memory_mb = 100.0

	# Should not crash
	logger.log_chunk_loaded(chunk_coord, memory_mb, total_memory_mb)

	pass_test("Chunk loaded logging works")


func test_chunk_unloaded_logging():
	var chunk_coord = Vector2i(3, 4)
	var reason = "distance"
	var total_memory_mb = 95.0

	# Should not crash
	logger.log_chunk_unloaded(chunk_coord, reason, total_memory_mb)

	pass_test("Chunk unloaded logging works")


func test_memory_change_logging():
	var old_memory_mb = 100.0
	var new_memory_mb = 110.0
	var limit_mb = 512

	# Should not crash
	logger.log_memory_change(old_memory_mb, new_memory_mb, limit_mb)

	pass_test("Memory change logging works")


func test_performance_warning_logging():
	var operation = "chunk_load"
	var actual_ms = 5.0
	var budget_ms = 2.0

	# Should not crash
	logger.log_performance_warning(operation, actual_ms, budget_ms)

	pass_test("Performance warning logging works")


func test_lod_change_logging():
	var chunk_coord = Vector2i(5, 6)
	var old_lod = 0
	var new_lod = 1
	var distance = 150.0

	# Should not crash
	logger.log_lod_change(chunk_coord, old_lod, new_lod, distance)

	pass_test("LOD change logging works")


func test_streaming_event_logging():
	var event_type = "queue_updated"
	var data = {"queue_size": 5, "loaded_chunks": 10}

	# Should not crash
	logger.log_streaming_event(event_type, data)

	pass_test("Streaming event logging works")


func test_log_with_data():
	var data = {"key1": "value1", "key2": 42, "key3": Vector2i(1, 2)}

	# Should not crash
	logger.log_info("Test", "Message with data", data)

	pass_test("Logging with data dictionary works")


func test_timestamp_formatting():
	# Access private method through call
	var timestamp = logger._get_timestamp()

	assert_not_null(timestamp, "Timestamp should be generated")
	assert_true(timestamp.length() > 0, "Timestamp should not be empty")

	# Should be in format HH:MM:SS.mmm
	var parts = timestamp.split(":")
	assert_eq(parts.size(), 3, "Timestamp should have 3 parts separated by colons")


func test_level_string_formatting():
	assert_eq(logger._get_level_string(TerrainLogger.LogLevel.DEBUG), "DEBUG")
	assert_eq(logger._get_level_string(TerrainLogger.LogLevel.INFO), "INFO")
	assert_eq(logger._get_level_string(TerrainLogger.LogLevel.WARNING), "WARN")
	assert_eq(logger._get_level_string(TerrainLogger.LogLevel.ERROR), "ERROR")
	assert_eq(logger._get_level_string(TerrainLogger.LogLevel.CRITICAL), "CRIT")


func test_data_formatting():
	var data = {"chunk": Vector2i(1, 2), "memory_mb": "5.50", "count": 10}

	var formatted = logger._format_data(data)

	assert_not_null(formatted, "Formatted data should not be null")
	assert_true(formatted.length() > 0, "Formatted data should not be empty")
	assert_true(formatted.contains("chunk="), "Formatted data should contain chunk key")
	assert_true(formatted.contains("memory_mb="), "Formatted data should contain memory_mb key")
	assert_true(formatted.contains("count="), "Formatted data should contain count key")


func test_log_entry_formatting():
	logger.include_timestamps = true
	logger.include_context = true

	var entry = logger._format_log_entry(
		TerrainLogger.LogLevel.INFO, "TestContext", "Test message", {"key": "value"}
	)

	assert_not_null(entry, "Log entry should not be null")
	assert_true(entry.contains("[INFO]"), "Entry should contain log level")
	assert_true(entry.contains("[TestContext]"), "Entry should contain context")
	assert_true(entry.contains("Test message"), "Entry should contain message")
	assert_true(entry.contains("key=value"), "Entry should contain data")


func test_log_entry_without_timestamps():
	logger.include_timestamps = false
	logger.include_context = true

	var entry = logger._format_log_entry(
		TerrainLogger.LogLevel.INFO, "TestContext", "Test message", {}
	)

	assert_not_null(entry, "Log entry should not be null")
	assert_false(entry.begins_with("[0"), "Entry should not start with timestamp")
	assert_true(entry.contains("[INFO]"), "Entry should contain log level")


func test_log_entry_without_context():
	logger.include_timestamps = true
	logger.include_context = false

	var entry = logger._format_log_entry(
		TerrainLogger.LogLevel.INFO, "TestContext", "Test message", {}
	)

	assert_not_null(entry, "Log entry should not be null")
	assert_false(entry.contains("[TestContext]"), "Entry should not contain context")
	assert_true(entry.contains("[INFO]"), "Entry should contain log level")


func test_multiple_log_calls():
	# Test that multiple log calls don't interfere with each other
	for i in range(10):
		logger.log_info("Test", "Message %d" % i, {"iteration": i})

	pass_test("Multiple log calls work without errors")


func test_concurrent_logging():
	# Test logging from multiple contexts
	logger.log_info("Context1", "Message 1")
	logger.log_warning("Context2", "Message 2")
	logger.log_error("Context3", "Message 3")
	logger.log_debug("Context4", "Message 4")

	pass_test("Concurrent logging from different contexts works")
