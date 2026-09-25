extends Control

const MAIN_MENU_SCENE := "res://MainMenu.tscn"

@onready var resume_button: Button = $Center/Menu/ResumeButton
@onready var restart_button: Button = $Center/Menu/RestartButton
@onready var menu_button: Button = $Center/Menu/MenuButton
@onready var exit_button: Button = $Center/Menu/ExitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_restart)
	menu_button.pressed.connect(_go_to_main_menu)
	exit_button.pressed.connect(_exit_game)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	var upgrade_menu := get_tree().get_first_node_in_group("upgrade_menu")
	if upgrade_menu != null and upgrade_menu is CanvasItem and upgrade_menu.visible:
		return

	var death_menu := get_tree().get_first_node_in_group("death_menu")
	if death_menu != null and death_menu is CanvasItem and death_menu.visible:
		return

	if visible:
		_resume()
	else:
		_pause()
	get_viewport().set_input_as_handled()


func _pause() -> void:
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _exit_tree() -> void:
	get_tree().paused = false
