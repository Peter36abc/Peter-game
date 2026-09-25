extends Node

# Attach this script to the ROOT "HUD" node.

@export_group("HUD")
@export var starting_lives: int = 8

@onready var wave_label: Label = $TextureRect/Label2
@onready var zombies_label: Label = $TextureRect/Label4
@onready var ammo_label: Label = $TextureRect/Ammo
@onready var level_label: Label = $TextureRect/Level
@onready var experience_bar: ProgressBar = $TextureRect/ExperienceBar
@onready var shield_label: Label = $TextureRect/Shield

@onready var hearts: Array[Control] = [
	$TextureRect/Heart1,
	$TextureRect/Heart2,
	$TextureRect/Heart3,
	$TextureRect/Heart4,
	$TextureRect/Heart5,
	$TextureRect/Heart6,
	$TextureRect/Heart7,
	$TextureRect/Heart8
]

var previous_lives: int = -1
var previous_wave: int = -1
var previous_zombies: int = -1
var previous_magazine: int = -1
var previous_reserve: int = -1
var previous_level: int = -1

var base_scales: Dictionary = {}
var active_tweens: Dictionary = {}
var animations_ready: bool = false


func _ready() -> void:
	add_to_group("hud")
	register_animated_control(wave_label)
	register_animated_control(zombies_label)
	register_animated_control(ammo_label)
	register_animated_control(level_label)
	register_animated_control(shield_label)
	for heart: Control in hearts:
		register_animated_control(heart)

	set_lives(starting_lives)
	set_wave(1)
	set_zombies_remaining(0)
	set_ammo(0, 0)
	set_experience(1, 0, 5)
	set_shield(0)
	animations_ready = true


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
		var heart: Control = hearts[i]
		var should_be_visible: bool = i < visible_hearts

		if not animations_ready or previous_lives < 0:
			heart.visible = should_be_visible
			continue

		if should_be_visible and not heart.visible:
			animate_heart_gained(heart)
		elif not should_be_visible and heart.visible:
			animate_heart_lost(heart)

	previous_lives = visible_hearts


func set_health(lives: int, maximum_lives: int) -> void:
	ensure_heart_count(maximum_lives)
	set_lives(lives)


func ensure_heart_count(maximum_lives: int) -> void:
	var target_count := mini(maximum_lives, 16)
	while hearts.size() < target_count:
		var index := hearts.size()
		var new_heart := hearts[0].duplicate() as TextureRect
		if new_heart == null:
			return
		new_heart.name = "Heart" + str(index + 1)
		var row := index / 8
		var column := index % 8
		new_heart.position = (
			hearts[0].position
			+ Vector2(column * 50.0, row * 44.0)
		)
		new_heart.visible = false
		$TextureRect.add_child(new_heart)
		hearts.append(new_heart)
		register_animated_control(new_heart)


# ============================================================
# WAVE
# ============================================================

func set_wave(wave: int) -> void:
	wave_label.text = "WAVE " + str(wave)
	if animations_ready and wave != previous_wave:
		pulse_control(wave_label, Color(1.0, 0.36, 0.12, 1.0), 1.18)
	previous_wave = wave


# ============================================================
# ZOMBIES LEFT UNTIL WAVE ENDS
# ============================================================

func set_zombies_remaining(amount: int) -> void:
	var safe_amount: int = maxi(amount, 0)
	zombies_label.text = "Zombies: " + str(safe_amount)
	if animations_ready and safe_amount != previous_zombies:
		pulse_control(zombies_label, Color(1.0, 0.2, 0.14, 1.0), 1.1)
	previous_zombies = safe_amount


# ============================================================
# AMMO
# ============================================================

func set_ammo(magazine: int, reserve: int) -> void:
	ammo_label.text = str(magazine) + " / " + str(reserve)
	if (
		animations_ready
		and (magazine != previous_magazine or reserve != previous_reserve)
	):
		pulse_control(ammo_label, Color(1.0, 0.86, 0.18, 1.0), 1.12)
	previous_magazine = magazine
	previous_reserve = reserve


# ============================================================
# EXPERIENCE / SHIELD
# ============================================================

func set_experience(level: int, amount: int, required: int) -> void:
	level_label.text = "LV " + str(level)
	experience_bar.max_value = maxi(required, 1)
	experience_bar.value = clampi(amount, 0, required)

	if animations_ready and level != previous_level:
		pulse_control(level_label, Color(0.2, 0.95, 0.75, 1.0), 1.15)
	previous_level = level


func set_shield(amount: int) -> void:
	shield_label.text = "SHIELD " + str(maxi(amount, 0))
	shield_label.visible = amount > 0


# ============================================================
# UI TWEENS
# ============================================================

func register_animated_control(control: Control) -> void:
	base_scales[control.get_instance_id()] = control.scale
	control.pivot_offset = control.size * 0.5


func get_base_scale(control: Control) -> Vector2:
	return base_scales.get(control.get_instance_id(), Vector2.ONE)


func start_control_tween(control: Control) -> Tween:
	var control_id: int = control.get_instance_id()
	var old_tween: Tween = active_tweens.get(control_id)

	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	var tween: Tween = create_tween()
	active_tweens[control_id] = tween
	return tween


func pulse_control(
	control: Control,
	flash_color: Color,
	peak_scale: float
) -> void:
	var base_scale: Vector2 = get_base_scale(control)
	control.visible = true
	control.scale = base_scale
	control.modulate = Color.WHITE

	var tween: Tween = start_control_tween(control)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", base_scale * peak_scale, 0.1)
	tween.parallel().tween_property(control, "modulate", flash_color, 0.1)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", base_scale, 0.18)
	tween.parallel().tween_property(control, "modulate", Color.WHITE, 0.18)


func animate_heart_gained(heart: Control) -> void:
	var base_scale: Vector2 = get_base_scale(heart)
	heart.visible = true
	heart.scale = base_scale * 0.45
	heart.modulate = Color(0.55, 1.0, 0.55, 0.25)

	var tween: Tween = start_control_tween(heart)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(heart, "scale", base_scale * 1.18, 0.16)
	tween.parallel().tween_property(heart, "modulate", Color.WHITE, 0.12)
	tween.tween_property(heart, "scale", base_scale, 0.12)


func animate_heart_lost(heart: Control) -> void:
	var base_scale: Vector2 = get_base_scale(heart)
	heart.scale = base_scale
	heart.modulate = Color.WHITE

	var tween: Tween = start_control_tween(heart)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(heart, "scale", base_scale * 1.2, 0.08)
	tween.parallel().tween_property(
		heart,
		"modulate",
		Color(1.0, 0.15, 0.12, 1.0),
		0.08
	)
	tween.tween_property(heart, "scale", base_scale * 0.3, 0.16)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.16)
	tween.tween_callback(finish_hiding_heart.bind(heart))


func finish_hiding_heart(heart: Control) -> void:
	heart.visible = false
	heart.scale = get_base_scale(heart)
	heart.modulate = Color.WHITE
