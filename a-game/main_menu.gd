extends Control

const GAME_SCENE := "res://level_1.tscn"

@onready var menu: Control = $Center/Menu
@onready var play_button: Button = $Center/Menu/PlayButton
@onready var credits_button: Button = $Center/Menu/CreditsButton
@onready var exit_button: Button = $Center/Menu/ExitButton
@onready var credits_layer: Control = $CreditsLayer
@onready var back_button: Button = $CreditsLayer/Center/Credits/BackButton


func _ready() -> void:
	get_tree().paused = false
	play_button.pressed.connect(_start_game)
	credits_button.pressed.connect(_show_credits)
	exit_button.pressed.connect(_exit_game)
	back_button.pressed.connect(_hide_credits)
	play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and credits_layer.visible:
		_hide_credits()
		get_viewport().set_input_as_handled()


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _show_credits() -> void:
	menu.visible = false
	credits_layer.visible = true
	back_button.grab_focus()


func _hide_credits() -> void:
	credits_layer.visible = false
	menu.visible = true
	play_button.grab_focus()


func _exit_game() -> void:
	get_tree().quit()
