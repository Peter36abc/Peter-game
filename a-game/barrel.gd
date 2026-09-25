extends StaticBody2D

@export var explosion_scene: PackedScene = preload("res://Explode.tscn")
@export var explosion_radius: float = 180.0
@export var explosion_damage: int = 100
@export var knockback_strength: float = 520.0
@export var upward_knockback: float = 240.0
@export var explosion_visual_scale: float = 0.45

var has_exploded := false


func _ready() -> void:
	add_to_group("explosive_barrels")


func take_damage(
	_amount: int,
	_hit_direction: Vector2 = Vector2.ZERO
) -> void:
	explode()


func explode() -> void:
	if has_exploded:
		return
	has_exploded = true

	$CollisionShape2D.set_deferred("disabled", true)
	$AnimatedSprite2D.visible = false
	spawn_explosion_effect()
	apply_blast()
	queue_free()


func spawn_explosion_effect() -> void:
	if explosion_scene == null:
		return

	var effect: Node = explosion_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		var effect_2d := effect as Node2D
		effect_2d.global_position = global_position
		effect_2d.scale = Vector2.ONE * explosion_visual_scale


func apply_blast() -> void:
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("players"))
	targets.append_array(get_tree().get_nodes_in_group("zombies"))
	targets.append_array(get_tree().get_nodes_in_group("explosive_barrels"))

	var hit_targets: Dictionary = {}
	for target: Node in targets:
		if target == self or not target is Node2D:
			continue
		if hit_targets.has(target.get_instance_id()):
			continue
		hit_targets[target.get_instance_id()] = true

		var target_2d := target as Node2D
		var offset := target_2d.global_position - global_position
		var distance := offset.length()
		if distance > explosion_radius:
			continue

		var blast_direction := offset.normalized()
		if blast_direction.length_squared() <= 0.001:
			blast_direction = Vector2.UP

		var falloff := lerpf(
			1.0,
			0.55,
			clampf(distance / explosion_radius, 0.0, 1.0)
		)
		var force := blast_direction * knockback_strength * falloff
		force.y -= upward_knockback * falloff

		if target.has_method("apply_knockback"):
			target.call("apply_knockback", force)

		if target.has_method("take_damage"):
			var damage_amount := roundi(float(explosion_damage) * falloff)
			if target.is_in_group("players"):
				target.call("take_damage", damage_amount)
			else:
				target.call("take_damage", damage_amount, blast_direction)
