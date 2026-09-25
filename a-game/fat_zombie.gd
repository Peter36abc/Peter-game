extends "res://zombie.gd"


func _ready() -> void:
	anim_running = &"Run"
	anim_die = &"Dead"
	super._ready()
