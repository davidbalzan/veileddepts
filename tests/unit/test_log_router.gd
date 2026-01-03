extends GutTest

## Unit tests for LogRouter
##
## Tests the centralized logging system including:
## - Log entry creation and storage
## - Circular buffer behavior
## - Log level filtering
## - Category filtering
## - Color coding

var log_router: Node


func before_each():
	# Get the LogRouter autoload
	log_router = get_node("/root/LogRouter")
	# Clear any existing logs
	log_router.clear_logs()
	log_router.clear_filters()


func after_each():
	# Clean up
	log_router.clear_logs()
	log_router.clear_filters()


## Test basic log entry creation
func test_log_entry_creation():
	log_router.log("Test message", LogRouter.LogLevel.INFO, "test")

	var logs = log_router.get_all_logs()
	assert_eq(logs.size(), 1, "Should have one log entry")
	assert_eq(logs[0].message, "Test message", "Message should match")
	assert_eq(logs[0].level, LogRouter.LogLevel.INFO, "Level should be INFO")
	assert_eq(logs[0].category, "test", "Category should match")


## Test log level color coding
func test_log_level_colors():
	log_router.log("Debug", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("Info", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error", LogRouter.LogLevel.ERROR, "test")

	var logs = log_router.get_all_logs()
	assert_eq(logs.size(), 4, "Should have four log entries")

	# Check colors
	assert_eq(logs[0].color, Color(0.6, 0.6, 0.6), "DEBUG should be gray")
	assert_eq(logs[1].color, Color(1.0, 1.0, 1.0), "INFO should be white")
	assert_eq(logs[2].color, Color(1.0, 1.0, 0.0), "WARNING should be yellow")
	assert_eq(logs[3].color, Color(1.0, 0.0, 0.0), "ERROR should be red")


## Test circular buffer with max size
func test_circular_buffer_limit():
	# Add more than MAX_BUFFER_SIZE entries
	for i in range(1100):
		log_router.log("Message " + str(i), LogRouter.LogLevel.INFO, "test")

	var logs = log_router.get_all_logs()
	assert_eq(logs.size(), 1000, "Buffer should be limited to 1000 entries")

	# Check that oldest entries were removed (first 100 should be gone)
	assert_eq(logs[0].message, "Message 100", "Oldest entry should be Message 100")
	assert_eq(logs[logs.size() - 1].message, "Message 1099", "Newest entry should be Message 1099")


## Test log level filtering
func test_log_level_filtering():
	log_router.log("Debug", LogRouter.LogLevel.DEBUG, "test")
	log_router.log("Info", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error", LogRouter.LogLevel.ERROR, "test")

	# Filter to WARNING and above
	log_router.set_min_level(LogRouter.LogLevel.WARNING)

	var filtered = log_router.get_filtered_logs()
	assert_eq(filtered.size(), 2, "Should have 2 entries (WARNING and ERROR)")
	assert_eq(filtered[0].level, LogRouter.LogLevel.WARNING, "First should be WARNING")
	assert_eq(filtered[1].level, LogRouter.LogLevel.ERROR, "Second should be ERROR")


## Test category filtering
func test_category_filtering():
	log_router.log("Terrain message", LogRouter.LogLevel.INFO, "terrain")
	log_router.log("Physics message", LogRouter.LogLevel.INFO, "physics")
	log_router.log("System message", LogRouter.LogLevel.INFO, "system")

	# Filter to terrain category only
	log_router.set_category_filter("terrain")

	var filtered = log_router.get_filtered_logs()
	assert_eq(filtered.size(), 1, "Should have 1 terrain entry")
	assert_eq(filtered[0].category, "terrain", "Should be terrain category")
	assert_eq(filtered[0].message, "Terrain message", "Should be terrain message")


## Test hiding warnings
func test_hide_warnings():
	log_router.log("Info", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error", LogRouter.LogLevel.ERROR, "test")

	log_router.set_hide_warnings(true)

	var filtered = log_router.get_filtered_logs()
	assert_eq(filtered.size(), 2, "Should have 2 entries (INFO and ERROR)")
	assert_eq(filtered[0].level, LogRouter.LogLevel.INFO, "First should be INFO")
	assert_eq(filtered[1].level, LogRouter.LogLevel.ERROR, "Second should be ERROR")


## Test hiding errors
func test_hide_errors():
	log_router.log("Info", LogRouter.LogLevel.INFO, "test")
	log_router.log("Warning", LogRouter.LogLevel.WARNING, "test")
	log_router.log("Error", LogRouter.LogLevel.ERROR, "test")

	log_router.set_hide_errors(true)

	var filtered = log_router.get_filtered_logs()
	assert_eq(filtered.size(), 2, "Should have 2 entries (INFO and WARNING)")
	assert_eq(filtered[0].level, LogRouter.LogLevel.INFO, "First should be INFO")
	assert_eq(filtered[1].level, LogRouter.LogLevel.WARNING, "Second should be WARNING")


## Test clear filters
func test_clear_filters():
	log_router.set_min_level(LogRouter.LogLevel.ERROR)
	log_router.set_category_filter("terrain")
	log_router.set_hide_warnings(true)

	log_router.clear_filters()

	assert_eq(log_router.get_min_level(), LogRouter.LogLevel.DEBUG, "Min level should be DEBUG")
	assert_eq(log_router.get_category_filter(), "", "Category filter should be empty")
	assert_false(log_router.get_hide_warnings(), "Hide warnings should be false")
	assert_false(log_router.get_hide_errors(), "Hide errors should be false")


## Test filter status display
func test_filter_status_display():
	# No filters
	assert_eq(log_router.get_filter_status(), "All", "Should show 'All' with no filters")

	# With min level
	log_router.set_min_level(LogRouter.LogLevel.WARNING)
	assert_true(
		log_router.get_filter_status().contains("Level: WARNING"), "Should show level filter"
	)

	# With category
	log_router.clear_filters()
	log_router.set_category_filter("terrain")
	assert_true(
		log_router.get_filter_status().contains("Category: terrain"), "Should show category filter"
	)

	# With hidden warnings
	log_router.clear_filters()
	log_router.set_hide_warnings(true)
	assert_true(
		log_router.get_filter_status().contains("Warnings: OFF"), "Should show warnings hidden"
	)


## Test log_added signal
func test_log_added_signal():
	var signal_watcher = watch_signals(log_router)

	log_router.log("Test", LogRouter.LogLevel.INFO, "test")

	assert_signal_emitted(log_router, "log_added", "Should emit log_added signal")


## Test filters_changed signal
func test_filters_changed_signal():
	var signal_watcher = watch_signals(log_router)

	log_router.set_min_level(LogRouter.LogLevel.WARNING)

	assert_signal_emitted(log_router, "filters_changed", "Should emit filters_changed signal")


## Test default log parameters
func test_default_log_parameters():
	log_router.log("Test message")

	var logs = log_router.get_all_logs()
	assert_eq(logs.size(), 1, "Should have one log entry")
	assert_eq(logs[0].level, LogRouter.LogLevel.INFO, "Default level should be INFO")
	assert_eq(logs[0].category, "system", "Default category should be system")


## Test buffer size getter
func test_buffer_size_getter():
	assert_eq(log_router.get_buffer_size(), 0, "Initial buffer should be empty")

	log_router.log("Test 1", LogRouter.LogLevel.INFO, "test")
	assert_eq(log_router.get_buffer_size(), 1, "Buffer should have 1 entry")

	log_router.log("Test 2", LogRouter.LogLevel.INFO, "test")
	assert_eq(log_router.get_buffer_size(), 2, "Buffer should have 2 entries")


## Test clear logs
func test_clear_logs():
	log_router.log("Test 1", LogRouter.LogLevel.INFO, "test")
	log_router.log("Test 2", LogRouter.LogLevel.INFO, "test")

	assert_eq(log_router.get_buffer_size(), 2, "Should have 2 entries")

	log_router.clear_logs()

	assert_eq(log_router.get_buffer_size(), 0, "Buffer should be empty after clear")
