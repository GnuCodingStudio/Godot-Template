class_name GameConsole
extends PanelContainer


@export var auto_help: bool

@onready var input: LineEdit = %Input
@onready var log: RichTextLabel = %Log

var _commands: Array[Command] = []


### BUILT-IN ###


func _ready() -> void:
	var commands = get_children().filter(func (child): return child is Command)
	var has_help = false
	for command in commands:
		_commands.push_back(command)
		if command.name == "help":
			has_help = true

	if not has_help && auto_help:
		_commands.push_front(_create_help())

	log_info("Listed commands: %s" % _commands_as_string())


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("show_game_console"):
		if visible:
			if not input.has_focus():
				hide()
		else:
			show()
			input.call_deferred("grab_focus")

	if Input.is_action_just_pressed("exit"):
		hide()

### SIGNALS ###


func _on_command_submitted(new_text: String) -> void:
	_execute_command(new_text)
	input.text = ""


func _on_submit_pressed() -> void:
	_execute_command(input.text)
	input.text = ""
	input.grab_focus()


### LOGIC ###


func log_info(info: String):
	log.append_text("[i]%s[/i]\n" % info)


func log_error(info: String):
	log.append_text("[color=#FF0000]%s[/color]\n" % info)


func _log_command(command: Command):
	log.append_text("Executing [b]%s[/b]...\n" % command.name)


func _commands_as_string() -> String:
	return ", ".join(_commands.map(func(c): return "[b]%s[/b]" % c.name))


func _create_help() -> Command:
	var help = Command.new()
	help.name = "help"
	help.target = self
	help.function = "_log_help"
	help.help = "Show help message."
	return help


func _execute_command(command_text: String):
	if command_text.is_empty():
		return

	var command_name = _extract_command_name(command_text)
	var matches = _commands.filter(func(c): return c.name == command_name)
	if matches.is_empty():
		log_error("Command not found!")
		prints("Command not found", command_name)
		return

	var command: Command = matches[0]
	var parse_result = _extract_parameters(command, command_text)

	if parse_result.has("parameters"):
		_log_command(command)
		command.target.callv(command.function, parse_result.parameters)
	else:
		log_error(parse_result.error)


func _extract_command_name(command_text: String) -> String:
	return command_text.split(" ", false, 1)[0]


func _extract_parameters(command: Command, command_text: String) -> Dictionary:
	var parameters_strings = command_text.split(" ").slice(1)
	var parameters = []
	var expected_params_count = command.parameters.size()

	if parameters_strings.size() < expected_params_count:
		return {
			 "error": "Command is expecting more parameters (%d < %d)" % [parameters_strings.size(), expected_params_count]
		}

	for i in expected_params_count:
		var expected_param = command.parameters[i].split(":")
		var expected_name = expected_param[0]
		var expected_type = expected_param[1].to_lower()
		var given_value = parameters_strings[i]
		var value
		match(expected_type):
			"string":
				value = given_value
			"int":
				if given_value.is_valid_int():
					value = int(given_value)
				else:
					return {
						 "error": "Parameter \"%s\" is \"%s\" and is not an integer" % [expected_name, given_value]
					}
			"float":
				if given_value.is_valid_float():
					value = float(given_value)
				else:
					return {
						 "error": "Parameter \"%s\" is \"%s\" and is not a float" % [expected_name, given_value]
					}

		parameters.push_back(value)

	return { "parameters": parameters}


func _log_help():
	for command in _commands:
		log.append_text("[b]%s[/b] - " % command.name)
		log.append_text("%s\n" % command.help)
	log.append_text("--------------------\n")
