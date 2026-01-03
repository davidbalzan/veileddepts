extends GutTest
## Unit tests for CommandParser
##
## Tests command parsing, validation, execution, and suggestion system.

const CommandParser = preload("res://scripts/ui/command_parser.gd")

var parser: CommandParser


func before_each():
	parser = CommandParser.new()


func after_each():
	parser = null


# Test parsing valid commands


func test_parse_simple_command():
	var parsed = parser.parse("/help")
	assert_not_null(parsed, "Should parse simple command")
	assert_eq(parsed.command, "help", "Command should be 'help'")
	assert_eq(parsed.args.size(), 0, "Should have no arguments")


func test_parse_command_with_args():
	var parsed = parser.parse("/relocate 100 200 -50")
	assert_not_null(parsed, "Should parse command with args")
	assert_eq(parsed.command, "relocate", "Command should be 'relocate'")
	assert_eq(parsed.args.size(), 3, "Should have 3 arguments")
	assert_eq(parsed.args[0], "100", "First arg should be '100'")
	assert_eq(parsed.args[1], "200", "Second arg should be '200'")
	assert_eq(parsed.args[2], "-50", "Third arg should be '-50'")


func test_parse_command_with_quoted_args():
	var parsed = parser.parse('/save "my preset"')
	assert_not_null(parsed, "Should parse command with quoted args")
	assert_eq(parsed.command, "save", "Command should be 'save'")
	assert_eq(parsed.args.size(), 1, "Should have 1 argument")
	assert_eq(parsed.args[0], "my preset", "Arg should be 'my preset' without quotes")


func test_parse_command_case_insensitive():
	var parsed = parser.parse("/HELP")
	assert_not_null(parsed, "Should parse uppercase command")
	assert_eq(parsed.command, "help", "Command should be lowercase 'help'")


func test_parse_command_with_extra_spaces():
	var parsed = parser.parse("  /help   ")
	assert_not_null(parsed, "Should parse command with extra spaces")
	assert_eq(parsed.command, "help", "Command should be 'help'")


# Test parsing invalid commands


func test_parse_without_slash():
	var parsed = parser.parse("help")
	assert_null(parsed, "Should return null for command without /")


func test_parse_empty_string():
	var parsed = parser.parse("")
	assert_null(parsed, "Should return null for empty string")


func test_parse_only_slash():
	var parsed = parser.parse("/")
	assert_null(parsed, "Should return null for only slash")


# Test validation


func test_validate_valid_command():
	var parsed = parser.parse("/help")
	var result = parser.validate(parsed)
	assert_true(result.success, "Should validate valid command")


func test_validate_unknown_command():
	var parsed = parser.parse("/unknown")
	var result = parser.validate(parsed)
	assert_false(result.success, "Should fail validation for unknown command")
	assert_true(result.message.contains("Unknown command"), "Should mention unknown command")


func test_validate_too_few_args():
	var parsed = parser.parse("/relocate 100 200")
	var result = parser.validate(parsed)
	assert_false(result.success, "Should fail validation for too few args")
	assert_true(result.message.contains("Too few arguments"), "Should mention too few arguments")


func test_validate_too_many_args():
	var parsed = parser.parse("/clear extra arg")
	var result = parser.validate(parsed)
	assert_false(result.success, "Should fail validation for too many args")
	assert_true(result.message.contains("Too many arguments"), "Should mention too many arguments")


func test_validate_null_parsed_command():
	var result = parser.validate(null)
	assert_false(result.success, "Should fail validation for null command")
	assert_true(result.message.contains("Invalid command format"), "Should mention invalid format")


# Test command execution


func test_execute_help_no_args():
	var parsed = parser.parse("/help")
	var result = parser.execute(parsed)
	assert_true(result.success, "Help command should succeed")
	assert_true(result.message.contains("Available commands"), "Should list available commands")


func test_execute_help_with_command():
	var parsed = parser.parse("/help debug")
	var result = parser.execute(parsed)
	assert_true(result.success, "Help for specific command should succeed")
	assert_true(result.message.contains("debug"), "Should contain command name")


func test_execute_help_unknown_command():
	var parsed = parser.parse("/help unknown")
	var result = parser.execute(parsed)
	assert_false(result.success, "Help for unknown command should fail")


func test_execute_debug_on():
	var parsed = parser.parse("/debug on")
	var result = parser.execute(parsed)
	assert_true(result.success, "Debug on should succeed")


func test_execute_debug_off():
	var parsed = parser.parse("/debug off")
	var result = parser.execute(parsed)
	assert_true(result.success, "Debug off should succeed")


func test_execute_debug_invalid_mode():
	var parsed = parser.parse("/debug invalid")
	var result = parser.execute(parsed)
	assert_false(result.success, "Invalid debug mode should fail")


func test_execute_clear():
	var parsed = parser.parse("/clear")
	var result = parser.execute(parsed)
	assert_true(result.success, "Clear command should succeed")


func test_execute_relocate_valid():
	var parsed = parser.parse("/relocate 100 200 -50")
	var result = parser.execute(parsed)
	assert_true(result.success, "Relocate with valid coords should succeed")
	assert_not_null(result.data, "Should return coordinate data")
	assert_eq(result.data, Vector3(100, 200, -50), "Should return correct coordinates")


func test_execute_relocate_invalid_coords():
	var parsed = parser.parse("/relocate abc 200 -50")
	var result = parser.execute(parsed)
	assert_false(result.success, "Relocate with invalid coords should fail")


func test_execute_log_valid_level():
	var parsed = parser.parse("/log warning")
	var result = parser.execute(parsed)
	assert_true(result.success, "Log level command should succeed")
	assert_eq(result.data, LogRouter.LogLevel.WARNING, "Should return correct log level")


func test_execute_log_invalid_level():
	var parsed = parser.parse("/log invalid")
	var result = parser.execute(parsed)
	assert_false(result.success, "Invalid log level should fail")


func test_execute_filter_reset():
	var parsed = parser.parse("/filter reset")
	var result = parser.execute(parsed)
	assert_true(result.success, "Filter reset should succeed")


func test_execute_filter_warnings_on():
	var parsed = parser.parse("/filter warnings on")
	var result = parser.execute(parsed)
	assert_true(result.success, "Filter warnings on should succeed")


func test_execute_filter_warnings_off():
	var parsed = parser.parse("/filter warnings off")
	var result = parser.execute(parsed)
	assert_true(result.success, "Filter warnings off should succeed")


func test_execute_filter_category():
	var parsed = parser.parse("/filter category terrain")
	var result = parser.execute(parsed)
	assert_true(result.success, "Filter category should succeed")


func test_execute_filter_invalid_state():
	var parsed = parser.parse("/filter warnings maybe")
	var result = parser.execute(parsed)
	assert_false(result.success, "Invalid filter state should fail")


func test_execute_save():
	var parsed = parser.parse("/save mypreset")
	var result = parser.execute(parsed)
	assert_true(result.success, "Save command should succeed")


func test_execute_load():
	var parsed = parser.parse("/load mypreset")
	var result = parser.execute(parsed)
	assert_true(result.success, "Load command should succeed")


func test_execute_history():
	var parsed = parser.parse("/history")
	var result = parser.execute(parsed)
	assert_true(result.success, "History command should succeed")


# Test command suggestions


func test_get_suggestions_close_match():
	var suggestions = parser.get_suggestions("hlep")
	assert_true(suggestions.size() > 0, "Should return suggestions for close match")
	assert_true(suggestions.has("/help"), "Should suggest /help for 'hlep'")


func test_get_suggestions_partial_match():
	var suggestions = parser.get_suggestions("deb")
	assert_true(suggestions.size() > 0, "Should return suggestions for partial match")
	assert_true(suggestions.has("/debug"), "Should suggest /debug for 'deb'")


func test_get_suggestions_no_match():
	var suggestions = parser.get_suggestions("zzzzzzz")
	assert_eq(suggestions.size(), 0, "Should return no suggestions for very different string")


func test_get_suggestions_sorted_by_distance():
	var suggestions = parser.get_suggestions("hel")
	if suggestions.size() > 1:
		# First suggestion should be closest match
		assert_eq(suggestions[0], "/help", "Closest match should be first")


# Test Levenshtein distance calculation


func test_levenshtein_identical_strings():
	var distance = parser._levenshtein_distance("help", "help")
	assert_eq(distance, 0, "Distance between identical strings should be 0")


func test_levenshtein_one_char_difference():
	var distance = parser._levenshtein_distance("help", "helm")
	assert_eq(distance, 1, "Distance for one char difference should be 1")


func test_levenshtein_insertion():
	var distance = parser._levenshtein_distance("help", "helps")
	assert_eq(distance, 1, "Distance for one insertion should be 1")


func test_levenshtein_deletion():
	var distance = parser._levenshtein_distance("helps", "help")
	assert_eq(distance, 1, "Distance for one deletion should be 1")


func test_levenshtein_completely_different():
	var distance = parser._levenshtein_distance("abc", "xyz")
	assert_eq(distance, 3, "Distance for completely different strings should be 3")


# Test edge cases


func test_parse_command_with_multiple_spaces_between_args():
	var parsed = parser.parse("/relocate  100   200   -50")
	assert_not_null(parsed, "Should handle multiple spaces between args")
	assert_eq(parsed.args.size(), 3, "Should have 3 arguments")


func test_parse_command_with_nested_quotes():
	var parsed = parser.parse('/save "preset with \\"quotes\\""')
	assert_not_null(parsed, "Should parse command with nested quotes")
	# Note: Current implementation doesn't handle escaped quotes, but should not crash


func test_execute_invalid_parsed_command():
	var result = parser.execute(null)
	assert_false(result.success, "Should fail for null parsed command")


func test_validate_command_with_exact_arg_count():
	var parsed = parser.parse("/relocate 100 200 -50")
	var result = parser.validate(parsed)
	assert_true(result.success, "Should validate command with exact arg count")


func test_command_definitions_complete():
	# Verify all commands have required fields
	for cmd_name in parser.COMMANDS.keys():
		var cmd_def = parser.COMMANDS[cmd_name]
		assert_true(cmd_def.has("usage"), "Command %s should have usage" % cmd_name)
		assert_true(cmd_def.has("description"), "Command %s should have description" % cmd_name)
		assert_true(cmd_def.has("min_args"), "Command %s should have min_args" % cmd_name)
		assert_true(cmd_def.has("max_args"), "Command %s should have max_args" % cmd_name)
