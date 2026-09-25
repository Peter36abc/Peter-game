extends Control

const MAIN_MENU_SCENE := "res://MainMenu.tscn"

@onready var result_label: Label = $Center/Menu/Result
@onready var retry_button: Button = $Center/Menu/RetryButton
@onready var menu_button: Button = $Center/Menu/MenuButton
@onready var exit_button: Button = $Center/Menu/ExitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("death_menu")
	retry_button.pressed.connect(_retry)
	menu_button.pressed.connect(_go_to_main_menu)
	exit_button.pressed.connect(_exit_game)


func show_death(player: Node) -> void:
	if visible:
		return

	var reached_level := int(player.get("level"))
	var reached_wave := 1
	var spawner := get_tree().get_first_node_in_group("wave_spawners")
	if spawner != null:
		reached_wave = int(spawner.get("current_wave"))

	result_label.text = (
		"LEVEL " + str(reached_level)
		+ "   WAVE " + str(reached_wave)
	)
	visible = true
	get_tree().paused = true
	retry_button.grab_focus()


func _retry() -> void:
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
