class_name CommandParser extends RefCounted
## CommandParser - Parses and executes developer console commands
##
## Interprets console commands, validates arguments, provides suggestions for
## invalid commands, and routes execution to appropriate handlers.

# Command result structure
class CommandResult:
	var success: bool
	var message: String
	var data: Variant  # Optional command-specific data
	
	func _init(p_success: bool, p_message: String, p_data: Variant = null):
		success = p_success
		message = p_message
		data = p_data


# Parsed command structure
class ParsedCommand:
	var command: String
	var args: Array[String]
	
	func _init(p_command: String, p_args: Array[String]):
		command = p_command
		args = p_args


# Command definitions with usage information
const COMMANDS = {
	"help": {
		"usage": "/help [command]",
		"description": "Show all commands or help for specific command",
		"min_args": 0,
		"max_args": 1
	},
	"debug": {
		"usage": "/debug <on|off|terrain|performance>",
		"description": "Control debug panels",
		"min_args": 1,
		"max_args": 1
	},
	"clear": {
		"usage": "/clear",
		"description": "Clear console log",
		"min_args": 0,
		"max_args": 0
	},
	"relocate": {
		"usage": "/relocate <x> <y> <z>",
		"description": "Move submarine to coordinates",
		"min_args": 3,
		"max_args": 3
	},
	"log": {
		"usage": "/log <debug|info|warning|error>",
		"description": "Set minimum log level",
		"min_args": 1,
		"max_args": 1
	},
	"filter": {
		"usage": "/filter <warnings|errors> <on|off> OR /filter category <name|all> OR /filter reset",
		"description": "Filter console logs",
		"min_args": 1,
		"max_args": 2
	},
	"save": {
		"usage": "/save <name>",
		"description": "Save console preset",
		"min_args": 1,
		"max_args": 1
	},
	"load": {
		"usage": "/load <name>",
		"description": "Load console preset",
		"min_args": 1,
		"max_args": 1
	},
	"history": {
		"usage": "/history",
		"description": "Display command history",
		"min_args": 0,
		"max_args": 0
	},
	"terrain": {
		"usage": "/terrain [status|reload]",
		"description": "Show terrain status or force reload chunks",
		"min_args": 0,
		"max_args": 1
	}
}


## Parse a command string into command and arguments
func parse(command_text: String) -> ParsedCommand:
	var trimmed = command_text.strip_edges()
	
	# Check if command starts with /
	if not trimmed.begins_with("/"):
		return null
	
	# Remove leading /
	trimmed = trimmed.substr(1)
	
	# Split by spaces, handling quoted strings
	var parts = _split_respecting_quotes(trimmed)
	
	if parts.is_empty():
		return null
	
	var command = parts[0].to_lower()
	var args: Array[String] = []
	
	# Collect remaining parts as arguments
	for i in range(1, parts.size()):
		args.append(parts[i])
	
	return ParsedCommand.new(command, args)


## Split string by spaces while respecting quoted strings
func _split_respecting_quotes(text: String) -> Array[String]:
	var parts: Array[String] = []
	var current_part = ""
	var in_quotes = false
	var i = 0
	
	while i < text.length():
		var c = text[i]
		
		if c == '"':
			in_quotes = not in_quotes
			i += 1
			continue
		
		if c == ' ' and not in_quotes:
			if not current_part.is_empty():
				parts.append(current_part)
				current_part = ""
			i += 1
			continue
		
		current_part += c
		i += 1
	
	# Add final part
	if not current_part.is_empty():
		parts.append(current_part)
	
	return parts


## Validate command and arguments
func validate(parsed_command: ParsedCommand) -> CommandResult:
	if parsed_command == null:
		return CommandResult.new(false, "Invalid command format. Commands must start with /")
	
	var command = parsed_command.command
	
	# Check if command exists
	if not COMMANDS.has(command):
		var suggestions = get_suggestions(command)
		var error_msg = "Unknown command: /" + command
		if not suggestions.is_empty():
			error_msg += "\nDid you mean: " + ", ".join(suggestions)
		return CommandResult.new(false, error_msg)
	
	# Check argument count
	var cmd_def = COMMANDS[command]
	var arg_count = parsed_command.args.size()
	
	if arg_count < cmd_def.min_args:
		return CommandResult.new(
			false,
			"Too few arguments for /" + command + "\nUsage: " + cmd_def.usage
		)
	
	if arg_count > cmd_def.max_args:
		return CommandResult.new(
			false,
			"Too many arguments for /" + command + "\nUsage: " + cmd_def.usage
		)
	
	return CommandResult.new(true, "Command validated")


## Execute a parsed and validated command
func execute(parsed_command: ParsedCommand) -> CommandResult:
	# Validate first
	var validation = validate(parsed_command)
	if not validation.success:
		return validation
	
	var command = parsed_command.command
	var args = parsed_command.args
	
	# Route to appropriate handler
	match command:
		"help":
			return _execute_help(args)
		"debug":
			return _execute_debug(args)
		"clear":
			return _execute_clear(args)
		"relocate":
			return _execute_relocate(args)
		"log":
			return _execute_log(args)
		"filter":
			return _execute_filter(args)
		"save":
			return _execute_save(args)
		"load":
			return _execute_load(args)
		"history":
			return _execute_history(args)
		"terrain":
			return _execute_terrain(args)
		_:
			return CommandResult.new(false, "Command not implemented: /" + command)


## Get command suggestions using Levenshtein distance
func get_suggestions(partial: String) -> Array[String]:
	var suggestions: Array[String] = []
	var max_distance = 3  # Maximum edit distance for suggestions
	
	for cmd in COMMANDS.keys():
		var distance = _levenshtein_distance(partial.to_lower(), cmd)
		if distance <= max_distance:
			suggestions.append("/" + cmd)
	
	# Sort by distance (closest first)
	suggestions.sort_custom(func(a, b):
		var dist_a = _levenshtein_distance(partial.to_lower(), a.substr(1))
		var dist_b = _levenshtein_distance(partial.to_lower(), b.substr(1))
		return dist_a < dist_b
	)
	
	return suggestions


## Calculate Levenshtein distance between two strings
func _levenshtein_distance(s1: String, s2: String) -> int:
	var len1 = s1.length()
	var len2 = s2.length()
	
	# Create distance matrix
	var matrix = []
	for i in range(len1 + 1):
		matrix.append([])
		for j in range(len2 + 1):
			matrix[i].append(0)
	
	# Initialize first row and column
	for i in range(len1 + 1):
		matrix[i][0] = i
	for j in range(len2 + 1):
		matrix[0][j] = j
	
	# Calculate distances
	for i in range(1, len1 + 1):
		for j in range(1, len2 + 1):
			var cost = 0 if s1[i - 1] == s2[j - 1] else 1
			matrix[i][j] = min(
				matrix[i - 1][j] + 1,      # Deletion
				min(
					matrix[i][j - 1] + 1,  # Insertion
					matrix[i - 1][j - 1] + cost  # Substitution
				)
			)
	
	return matrix[len1][len2]


# Command execution handlers


func _execute_help(args: Array[String]) -> CommandResult:
	if args.is_empty():
		# Show all commands
		var help_text = "Available commands:\n"
		for cmd in COMMANDS.keys():
			var cmd_def = COMMANDS[cmd]
			help_text += "  " + cmd_def.usage + "\n"
			help_text += "    " + cmd_def.description + "\n"
		return CommandResult.new(true, help_text)
	else:
		# Show help for specific command
		var cmd = args[0].to_lower()
		if cmd.begins_with("/"):
			cmd = cmd.substr(1)
		
		if not COMMANDS.has(cmd):
			return CommandResult.new(false, "Unknown command: /" + cmd)
		
		var cmd_def = COMMANDS[cmd]
		var help_text = cmd_def.usage + "\n" + cmd_def.description
		return CommandResult.new(true, help_text)


func _execute_debug(args: Array[String]) -> CommandResult:
	var mode = args[0].to_lower()
	
	match mode:
		"on", "off", "terrain", "performance":
			# Return success with mode data for external handler
			return CommandResult.new(true, "Debug command: " + mode, mode)
		_:
			return CommandResult.new(
				false,
				"Invalid debug mode: " + mode + "\nValid modes: on, off, terrain, performance"
			)


func _execute_clear(args: Array[String]) -> CommandResult:
	# Return success - DevConsole will handle the actual clearing
	return CommandResult.new(true, "clear")


func _execute_relocate(args: Array[String]) -> CommandResult:
	# Parse coordinates
	var x = args[0].to_float()
	var y = args[1].to_float()
	var z = args[2].to_float()
	
	# Validate coordinates - check if they're valid numbers
	# to_float() returns 0.0 for invalid strings, so we need to check if the string is actually "0" or a valid number
	if not args[0].is_valid_float() and args[0] != "0":
		return CommandResult.new(false, "Invalid X coordinate: " + args[0])
	if not args[1].is_valid_float() and args[1] != "0":
		return CommandResult.new(false, "Invalid Y coordinate: " + args[1])
	if not args[2].is_valid_float() and args[2] != "0":
		return CommandResult.new(false, "Invalid Z coordinate: " + args[2])
	
	# Return success with coordinates for external handler
	var coords = Vector3(x, y, z)
	return CommandResult.new(
		true,
		"Relocate command: (%s, %s, %s)" % [x, y, z],
		coords
	)


func _execute_log(args: Array[String]) -> CommandResult:
	var level_name = args[0].to_lower()
	
	# Map level name to LogRouter.LogLevel
	var level_map = {
		"debug": LogRouter.LogLevel.DEBUG,
		"info": LogRouter.LogLevel.INFO,
		"warning": LogRouter.LogLevel.WARNING,
		"error": LogRouter.LogLevel.ERROR
	}
	
	if not level_map.has(level_name):
		return CommandResult.new(
			false,
			"Invalid log level: " + level_name + "\nValid levels: debug, info, warning, error"
		)
	
	var level = level_map[level_name]
	
	# Return success with level data for DevConsole to apply
	return CommandResult.new(
		true,
		"log level: " + level_name,
		level
	)


func _execute_filter(args: Array[String]) -> CommandResult:
	var filter_type = args[0].to_lower()
	
	match filter_type:
		"reset":
			# Return success - DevConsole will handle the reset
			return CommandResult.new(true, "filter reset")
		
		"warnings", "errors":
			if args.size() < 2:
				return CommandResult.new(false, "Missing on/off argument for filter")
			
			var state = args[1].to_lower()
			if state != "on" and state != "off":
				return CommandResult.new(false, "Invalid state: " + state + "\nUse 'on' or 'off'")
			
			# Return success - DevConsole will handle the filter
			return CommandResult.new(true, "filter " + filter_type + " " + state)
		
		"category":
			if args.size() < 2:
				return CommandResult.new(false, "Missing category name")
			
			var category = args[1].to_lower()
			# Return success - DevConsole will handle the category filter
			return CommandResult.new(true, "filter category " + category)
		
		_:
			return CommandResult.new(
				false,
				"Invalid filter type: " + filter_type + "\nValid types: warnings, errors, category, reset"
			)


func _execute_save(args: Array[String]) -> CommandResult:
	var preset_name = args[0]
	
	# TODO: Implement preset saving in future task
	return CommandResult.new(
		true,
		"Preset '" + preset_name + "' saved (Preset system not yet implemented)"
	)


func _execute_load(args: Array[String]) -> CommandResult:
	var preset_name = args[0]
	
	# TODO: Implement preset loading in future task
	return CommandResult.new(
		true,
		"Preset '" + preset_name + "' loaded (Preset system not yet implemented)"
	)


func _execute_history(args: Array[String]) -> CommandResult:
	# Return success - DevConsole will display the history
	return CommandResult.new(true, "history")


func _execute_terrain(args: Array[String]) -> CommandResult:
	var action = "status" if args.is_empty() else args[0].to_lower()
	
	match action:
		"status", "reload":
			return CommandResult.new(true, "terrain " + action, action)
		_:
			return CommandResult.new(
				false,
				"Invalid terrain action: " + action + "\nValid actions: status, reload"
			)

