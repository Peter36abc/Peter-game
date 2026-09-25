extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	animated_sprite.sprite_frames.set_animation_loop(&"Explode", false)
	animated_sprite.animation_finished.connect(queue_free)
	animated_sprite.play(&"Explode")
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0
