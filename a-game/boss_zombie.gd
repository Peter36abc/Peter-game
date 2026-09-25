extends "res://zombie.gd"

enum SlamState {
	CHASING,
	TELEGRAPHING,
	STRIKING,
	RECOVERING,
}

@export_group("Lightning Slam")
@export var lightning_scene: PackedScene = preload("res://Lightning.tscn")
@export var first_slam_delay: float = 2.0
@export var slam_cooldown: float = 4.5
@export var slam_telegraph_duration: float = 0.95
@export var slam_recovery_duration: float = 0.5
@export var lightning_count: int = 5
@export var lightning_spacing: float = 145.0
@export var lightning_strike_interval: float = 0.09
@export var lightning_hit_radius: float = 82.0
@export var lightning_vertical_range: float = 425.0
@export var lightning_column_height: float = 440.0
@export var lightning_health_damage: int = 3
@export var lightning_knockback_strength: float = 720.0
@export var lightning_upward_knockback: float = 340.0
@export var lightning_visual_scale: float = 1.45
@export var slam_min_distance: float = 30.0
@export var slam_max_distance: float = 700.0

@export_group("Boss Strength")
@export var melee_health_damage: int = 2
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.3

var slam_state: SlamState = SlamState.CHASING
var slam_cooldown_timer: float = 0.0
var slam_timer: float = 0.0
var slam_direction: float = 1.0
var next_strike_index: int = 0
var strike_positions: Array[Vector2] = []
var warning_markers: Array[Node2D] = []
var slam_hit_players: Dictionary = {}


func _ready() -> void:
	anim_running = &"Run"
	anim_die = &"Dead"
	super._ready()
	add_to_group("bosses")
	slam_cooldown_timer = first_slam_delay


func _physics_process(delta: float) -> void:
	if is_dead:
		clear_warning_markers()
		super._physics_process(delta)
		return

	slam_cooldown_timer = maxf(slam_cooldown_timer - delta, 0.0)

	if knockback_timer > 0.0:
		cancel_slam()
		super._physics_process(delta)
		return

	if slam_state != SlamState.CHASING:
		process_slam_state(delta)
		return

	target = get_nearest_player()
	if can_begin_slam():
		begin_slam()
		return

	super._physics_process(delta)


func can_begin_slam() -> bool:
	if target == null or slam_cooldown_timer > 0.0 or not is_on_floor():
		return false

	var offset: Vector2 = target.global_position - global_position
	return (
		absf(offset.x) >= slam_min_distance
		and absf(offset.x) <= slam_max_distance
		and absf(offset.y) <= lightning_vertical_range
	)


func attack_player() -> void:
	if not can_attack or target == null or is_dead or is_hurt:
		return

	if not is_target_in_attack_range():
		return

	can_attack = false
	attack_timer = attack_cooldown
	if target.has_method("take_damage"):
		target.call("take_damage", damage, melee_health_damage)


func apply_knockback(force: Vector2) -> void:
	if slam_state != SlamState.CHASING:
		return

	super.apply_knockback(force * knockback_resistance)


func begin_slam() -> void:
	slam_state = SlamState.TELEGRAPHING
	slam_timer = slam_telegraph_duration
	slam_direction = signf(target.global_position.x - global_position.x)
	if is_zero_approx(slam_direction):
		slam_direction = -1.0 if animated_sprite.flip_h else 1.0

	animated_sprite.flip_h = slam_direction < 0.0
	velocity = Vector2.ZERO
	is_attacking = true
	next_strike_index = 0
	slam_hit_players.clear()
	build_strike_line()
	create_warning_markers()
	play_animation(anim_attack)


func build_strike_line() -> void:
	strike_positions.clear()
	var ground_y := global_position.y + ground_effect_offset
	for index: int in range(lightning_count):
		strike_positions.append(Vector2(
			global_position.x
			+ slam_direction * lightning_spacing * float(index + 1),
			ground_y
		))


func process_slam_state(delta: float) -> void:
	velocity.x = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta

	handle_hurt_timer(delta)
	move_and_slide()

	match slam_state:
		SlamState.TELEGRAPHING:
			process_slam_telegraph(delta)
		SlamState.STRIKING:
			process_lightning_strikes(delta)
		SlamState.RECOVERING:
			process_slam_recovery(delta)


func process_slam_telegraph(delta: float) -> void:
	is_attacking = true
	play_animation(anim_attack)
	slam_timer -= delta

	var progress := 1.0 - maxf(slam_timer, 0.0) / slam_telegraph_duration
	for marker: Node2D in warning_markers:
		if not is_instance_valid(marker):
			continue
		var pulse := 1.0 + sin(progress * TAU * 5.0) * 0.08
		marker.scale = Vector2.ONE * pulse
		marker.modulate.a = 0.45 + progress * 0.55

	if slam_timer <= 0.0:
		slam_state = SlamState.STRIKING
		slam_timer = 0.0


func process_lightning_strikes(delta: float) -> void:
	is_attacking = true
	play_animation(anim_attack)
	slam_timer -= delta

	if next_strike_index < strike_positions.size() and slam_timer <= 0.0:
		strike_at(strike_positions[next_strike_index])
		clear_warning_marker(next_strike_index)
		next_strike_index += 1
		slam_timer = lightning_strike_interval
		return

	if next_strike_index >= strike_positions.size() and slam_timer <= 0.0:
		clear_warning_markers()
		slam_state = SlamState.RECOVERING
		slam_timer = slam_recovery_duration
		is_attacking = false
		play_animation(anim_idle)


func process_slam_recovery(delta: float) -> void:
	is_attacking = false
	play_animation(anim_idle)
	slam_timer -= delta
	if slam_timer <= 0.0:
		slam_state = SlamState.CHASING
		slam_cooldown_timer = slam_cooldown


func strike_at(strike_position: Vector2) -> void:
	spawn_lightning(strike_position)

	for player_node: Node in get_tree().get_nodes_in_group("players"):
		if not player_node is Node2D:
			continue

		var player_id := player_node.get_instance_id()
		if slam_hit_players.has(player_id):
			continue

		var player_2d := player_node as Node2D
		var offset := player_2d.global_position - strike_position
		if (
			absf(offset.x) > lightning_hit_radius
			or absf(offset.y) > lightning_vertical_range
		):
			continue

		slam_hit_players[player_id] = true
		if player_node.has_method("apply_knockback"):
			player_node.call(
				"apply_knockback",
				Vector2(
					slam_direction * lightning_knockback_strength,
					-lightning_upward_knockback
				)
			)

		if player_node.has_method("take_damage"):
			player_node.call(
				"take_damage",
				lightning_health_damage,
				lightning_health_damage
			)


func spawn_lightning(strike_position: Vector2) -> void:
	if lightning_scene == null:
		return

	var effect: Node = lightning_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		var effect_2d := effect as Node2D
		effect_2d.global_position = strike_position
		effect_2d.scale = Vector2.ONE * lightning_visual_scale


func create_warning_markers() -> void:
	clear_warning_markers()
	for strike_position: Vector2 in strike_positions:
		var marker := Node2D.new()
		marker.z_index = 3
		get_tree().current_scene.add_child(marker)
		marker.global_position = strike_position

		var column := Polygon2D.new()
		column.polygon = PackedVector2Array([
			Vector2(-lightning_hit_radius, -lightning_column_height),
			Vector2(lightning_hit_radius, -lightning_column_height),
			Vector2(lightning_hit_radius, 0.0),
			Vector2(-lightning_hit_radius, 0.0),
		])
		column.color = Color(0.12, 0.55, 1.0, 0.12)
		marker.add_child(column)

		var column_outline := Line2D.new()
		column_outline.points = PackedVector2Array([
			Vector2(-lightning_hit_radius, 0.0),
			Vector2(-lightning_hit_radius, -lightning_column_height),
			Vector2(lightning_hit_radius, -lightning_column_height),
			Vector2(lightning_hit_radius, 0.0),
		])
		column_outline.width = 2.0
		column_outline.default_color = Color(0.35, 0.82, 1.0, 0.72)
		column_outline.antialiased = true
		marker.add_child(column_outline)

		var fill := Polygon2D.new()
		fill.polygon = make_warning_ellipse(false)
		fill.color = Color(0.05, 0.48, 1.0, 0.32)
		marker.add_child(fill)

		var outline := Line2D.new()
		outline.points = make_warning_ellipse(true)
		outline.width = 3.0
		outline.default_color = Color(0.3, 0.8, 1.0, 1.0)
		outline.antialiased = true
		marker.add_child(outline)
		warning_markers.append(marker)


func make_warning_ellipse(close_shape: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var point_count := 28
	var total_points := point_count + (1 if close_shape else 0)
	for index: int in range(total_points):
		var angle := TAU * float(index % point_count) / float(point_count)
		points.append(Vector2(
			cos(angle) * lightning_hit_radius,
			sin(angle) * 10.0
		))
	return points


func clear_warning_marker(index: int) -> void:
	if index < 0 or index >= warning_markers.size():
		return
	var marker := warning_markers[index]
	if is_instance_valid(marker):
		marker.queue_free()


func clear_warning_markers() -> void:
	for marker: Node2D in warning_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	warning_markers.clear()


func cancel_slam() -> void:
	if slam_state == SlamState.CHASING:
		return
	clear_warning_markers()
	strike_positions.clear()
	slam_state = SlamState.CHASING
	slam_timer = 0.0
	slam_cooldown_timer = maxf(slam_cooldown_timer, 1.5)
	is_attacking = false


func die() -> void:
	clear_warning_markers()
	super.die()
