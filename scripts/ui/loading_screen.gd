class_name LoadingScreen extends CanvasLayer
## Loading screen with console output
##
## Shows during game initialization and displays log messages.
## Press ~ to toggle console visibility after loading.

signal loading_complete

@export var auto_hide_on_complete: bool = true
@export var min_display_time: float = 2.0  # Minimum time to show loading screen

var _console_visible: bool = true
var _loading_complete: bool = false
var _start_time: float = 0.0
var _log_buffer: Array[String] = []
var _max_log_lines: int = 50

# UI elements
var _background: ColorRect
var _title_label: Label
var _status_label: Label
var _progress_bar: ProgressBar
var _console_panel: Panel
var _console_output: RichTextLabel
var _console_toggle_hint: Label


func _ready() -> void:
	layer = 100  # On top of everything
	_start_time = Time.get_ticks_msec() / 1000.0
	_create_ui()
	_hook_logging()
	_log("Loading Tactical Submarine Simulator...")
	_log("Godot Engine " + Engine.get_version_info().string)


func _create_ui() -> void:
	# Background
	_background = ColorRect.new()
	_background.color = Color(0.05, 0.08, 0.12, 1.0)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	# Title
	_title_label = Label.new()
	_title_label.text = "TACTICAL SUBMARINE SIMULATOR"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position.y = 80
	_title_label.size.x = 800
	_title_label.position.x = -400
	add_child(_title_label)

	# Status label
	_status_label = Label.new()
	_status_label.text = "Initializing..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_label.position.y = 130
	_status_label.size.x = 600
	_status_label.position.x = -300
	add_child(_status_label)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(400, 8)
	_progress_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress_bar.position.y = 170
	_progress_bar.position.x = -200
	add_child(_progress_bar)

	# Console panel
	_console_panel = Panel.new()
	_console_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_console_panel.anchor_top = 0.25
	_console_panel.anchor_bottom = 0.95
	_console_panel.anchor_left = 0.05
	_console_panel.anchor_right = 0.95
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.04, 0.06, 0.95)
	panel_style.border_color = Color(0.2, 0.3, 0.4, 0.8)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	_console_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_console_panel)

	# Console output
	_console_output = RichTextLabel.new()
	_console_output.bbcode_enabled = true
	_console_output.scroll_following = true
	_console_output.set_anchors_preset(Control.PRESET_FULL_RECT)
	_console_output.anchor_top = 0.02
	_console_output.anchor_bottom = 0.98
	_console_output.anchor_left = 0.02
	_console_output.anchor_right = 0.98
	_console_output.add_theme_font_size_override("normal_font_size", 13)
	_console_output.add_theme_color_override("default_color", Color(0.7, 0.8, 0.7))
	_console_panel.add_child(_console_output)

	# Console toggle hint
	_console_toggle_hint = Label.new()
	_console_toggle_hint.text = "Press ~ to toggle console"
	_console_toggle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_console_toggle_hint.add_theme_font_size_override("font_size", 12)
	_console_toggle_hint.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	_console_toggle_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_console_toggle_hint.position.y = -30
	_console_toggle_hint.size.x = 300
	_console_toggle_hint.position.x = -150
	add_child(_console_toggle_hint)


func _hook_logging() -> void:
	# We can't directly hook into Godot's print, but we can provide a method
	# for other scripts to call
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT:  # ~ key
			toggle_console()


func toggle_console() -> void:
	_console_visible = not _console_visible
	_console_panel.visible = _console_visible


func _log(message: String, color: Color = Color(0.7, 0.8, 0.7)) -> void:
	var timestamp = "[%.2f]" % (Time.get_ticks_msec() / 1000.0 - _start_time)
	var colored_msg = "[color=#%s]%s %s[/color]" % [color.to_html(false), timestamp, message]
	_log_buffer.append(colored_msg)

	# Trim buffer if too long
	while _log_buffer.size() > _max_log_lines:
		_log_buffer.pop_front()

	# Update display
	if _console_output:
		_console_output.text = "\n".join(_log_buffer)


func log_info(message: String) -> void:
	_log(message, Color(0.7, 0.8, 0.7))


func log_warning(message: String) -> void:
	_log("[WARN] " + message, Color(1.0, 0.8, 0.3))


func log_error(message: String) -> void:
	_log("[ERROR] " + message, Color(1.0, 0.4, 0.4))


func log_success(message: String) -> void:
	_log(message, Color(0.4, 1.0, 0.5))


func set_status(status: String) -> void:
	if _status_label:
		_status_label.text = status
	log_info(status)


func set_progress(progress: float) -> void:
	if _progress_bar:
		_progress_bar.value = progress * 100


func complete_loading() -> void:
	_loading_complete = true
	set_status("Loading complete!")
	set_progress(1.0)
	log_success("All systems initialized")

	if auto_hide_on_complete:
		# Wait for minimum display time
		var elapsed = Time.get_ticks_msec() / 1000.0 - _start_time
		var wait_time = max(0, min_display_time - elapsed)
		if wait_time > 0:
			await get_tree().create_timer(wait_time).timeout
		hide_loading_screen()

	loading_complete.emit()


func hide_loading_screen() -> void:
	# Fade out or just hide
	visible = false
	# Keep console available via ~ key
	_background.visible = false
	_title_label.visible = false
	_status_label.visible = false
	_progress_bar.visible = false
	_console_toggle_hint.visible = false
	_console_panel.visible = false


func show_console_only() -> void:
	"""Show only the console overlay (for use after loading)"""
	visible = true
	_background.visible = false
	_title_label.visible = false
	_status_label.visible = false
	_progress_bar.visible = false
	_console_toggle_hint.visible = false
	_console_panel.visible = _console_visible
