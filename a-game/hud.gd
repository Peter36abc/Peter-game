extends Node

# Attach this script to the ROOT "HUD" node.

@export_group("HUD")
@export var starting_lives: int = 8

@onready var wave_label: Label = $TextureRect/Label2
@onready var zombies_label: Label = $TextureRect/Label4
@onready var ammo_label: Label = $TextureRect/Ammo

@onready var hearts: Array[CanvasItem] = [
	$TextureRect/Heart1,
	$TextureRect/Heart2,
	$TextureRect/Heart3,
	$TextureRect/Heart4,
	$TextureRect/Heart5,
	$TextureRect/Heart6,
	$TextureRect/Heart7,
	$TextureRect/Heart8
]


func _ready() -> void:
	add_to_group("hud")

	set_lives(starting_lives)
	set_wave(1)
	set_zombies_remaining(0)
	set_ammo(0, 0)


# ============================================================
# HEARTS
# ============================================================

func set_lives(lives: int) -> void:

	var visible_hearts: int = clampi(
		lives,
		0,
		hearts.size()
	)

	for i: int in range(hearts.size()):
		hearts[i].visible = i < visible_hearts


# ============================================================
# WAVE
# ============================================================

func set_wave(wave: int) -> void:
	wave_label.text = "WAVE " + str(wave)


# ============================================================
# ZOMBIES LEFT UNTIL WAVE ENDS
# ============================================================

func set_zombies_remaining(amount: int) -> void:
	zombies_label.text = "Zombies: " + str(maxi(amount, 0))


# ============================================================
# AMMO
# ============================================================

func set_ammo(magazine: int, reserve: int) -> void:
	ammo_label.text = str(magazine) + " / " + str(reserve)
