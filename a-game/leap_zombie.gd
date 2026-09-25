extends "res://zombie.gd"


enum LeapState {
	CHASING,
	TELEGRAPHING,
	LEAPING,
	RECOVERING,
}


@export_group("Leap")

@export var leap_min_distance: float = 110.0
@export var leap_max_distance: float = 420.0
@export var leap_cooldown: float = 3.5
@export var telegraph_duration: float = 0.8
@export var leap_duration: float = 0.48
@export var leap_height: float = 105.0
@export var landing_radius: float = 42.0
@export var landing_vertical_range: float = 32.0
@export var landing_damage: int = 15
@export var recovery_duration: float = 0.35
@export var leap_particle_amount: int = 16


var leap_state: LeapState = LeapState.CHASING
var state_timer: float = 0.0
var leap_cooldown_timer: float = 0.0
var leap_start_position: Vector2 = Vector2.ZERO
var landing_position: Vector2 = Vector2.ZERO
var landing_marker: Node2D = null


func _ready() -> void:
	# The leap-zombie sheet uses different names from the regular zombie.
	anim_running = &"Run"
	anim_die = &"Dead"
	super._ready()

	# Give the first leap a little breathing room after spawning.
	leap_cooldown_timer = randf_range(1.25, 2.25)


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	if knockback_timer > 0.0:
		cancel_leap()
		if not is_on_floor():
			velocity += get_gravity() * delta
		process_knockback(delta)
		return

	handle_attack_timer(delta)
	handle_hurt_timer(delta)
	leap_cooldown_timer = maxf(leap_cooldown_timer - delta, 0.0)

	if is_hurt:
		cancel_leap()
		velocity.x = 0.0
		if not is_on_floor():
			velocity += get_gravity() * delta
		update_animation()
		move_and_slide()
		return

	target = get_nearest_player()

	if target == null:
		cancel_leap()
		velocity.x = 0.0
		update_animation()
		move_and_slide()
		return

	face_target()

	match leap_state:
		LeapState.CHASING:
			process_chasing(delta)
		LeapState.TELEGRAPHING:
			process_telegraph(delta)
		LeapState.LEAPING:
			process_leap(delta)
		LeapState.RECOVERING:
			process_recovery(delta)


func process_chasing(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var offset: Vector2 = target.global_position - global_position
	var horizontal_distance: float = absf(offset.x)
	var vertical_distance: float = absf(offset.y)

	if (
		leap_cooldown_timer <= 0.0
		and is_on_floor()
		and horizontal_distance >= leap_min_distance
		and horizontal_distance <= leap_max_distance
		and vertical_distance <= landing_vertical_range
	):
		begin_telegraph()
		return

	if is_target_in_attack_range():
		velocity.x = 0.0
		is_attacking = true
		attack_player()
	else:
		is_attacking = false
		velocity.x = signf(offset.x) * speed
		process_footstep_particles(delta)

	update_animation()
	move_and_slide()


func begin_telegraph() -> void:
	leap_state = LeapState.TELEGRAPHING
	state_timer = telegraph_duration
	velocity = Vector2.ZERO
	is_attacking = true

	# Lock the destination now so the marker truthfully shows the landing spot.
	var target_offset_x: float = clampf(
		target.global_position.x - global_position.x,
		-leap_max_distance,
		leap_max_distance
	)
	landing_position = Vector2(
		global_position.x + target_offset_x,
		global_position.y
	)
	create_landing_marker()
	play_animation(anim_attack)


func process_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	state_timer -= delta

	if is_instance_valid(landing_marker):
		var progress: float = 1.0 - maxf(state_timer, 0.0) / telegraph_duration
		var pulse: float = 1.0 + sin(progress * TAU * 4.0) * 0.09
		landing_marker.scale = Vector2.ONE * pulse
		landing_marker.modulate.a = 0.65 + progress * 0.35

	if state_timer <= 0.0:
		spawn_dust_burst(
			global_position + Vector2(0.0, ground_effect_offset),
			leap_particle_amount,
			true
		)
		leap_state = LeapState.LEAPING
		state_timer = 0.0
		leap_start_position = global_position
		is_attacking = false
		play_animation(anim_attack)


func process_leap(delta: float) -> void:
	state_timer += delta
	var progress: float = clampf(state_timer / leap_duration, 0.0, 1.0)
	var next_position: Vector2 = leap_start_position.lerp(
		landing_position,
		progress
	)
	next_position.y -= sin(progress * PI) * leap_height
	global_position = next_position

	if progress >= 1.0:
		land()


func land() -> void:
	global_position = landing_position
	spawn_dust_burst(
		global_position + Vector2(0.0, ground_effect_offset),
		leap_particle_amount + 6,
		true
	)
	clear_landing_marker()
	leap_cooldown_timer = leap_cooldown
	leap_state = LeapState.RECOVERING
	state_timer = recovery_duration
	velocity = Vector2.ZERO

	var offset: Vector2 = target.global_position - global_position
	if (
		absf(offset.x) <= landing_radius
		and absf(offset.y) <= landing_vertical_range
		and target.has_method("take_damage")
	):
		target.call("take_damage", landing_damage)


func process_recovery(delta: float) -> void:
	velocity.x = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	state_timer -= delta
	play_animation(anim_idle)

	if state_timer <= 0.0:
		leap_state = LeapState.CHASING


func face_target() -> void:
	var direction: float = signf(target.global_position.x - global_position.x)
	if direction < 0.0:
		animated_sprite.flip_h = true
	elif direction > 0.0:
		animated_sprite.flip_h = false


func create_landing_marker() -> void:
	clear_landing_marker()

	landing_marker = Node2D.new()
	landing_marker.z_index = 2
	get_tree().current_scene.add_child(landing_marker)
	landing_marker.global_position = (
		landing_position
		+ Vector2(0.0, ground_effect_offset)
	)

	var circle_points: PackedVector2Array = make_ellipse_points(
		landing_radius,
		landing_radius * 0.32,
		32,
		false
	)
	var fill := Polygon2D.new()
	fill.polygon = circle_points
	fill.color = Color(0.95, 0.02, 0.02, 0.48)
	landing_marker.add_child(fill)

	var outline := Line2D.new()
	outline.points = make_ellipse_points(
		landing_radius,
		landing_radius * 0.32,
		32,
		true
	)
	outline.width = 3.0
	outline.default_color = Color(1.0, 0.1, 0.04, 1.0)
	outline.antialiased = true
	landing_marker.add_child(outline)

	var cross_a := Line2D.new()
	cross_a.points = PackedVector2Array([
		Vector2(-landing_radius * 0.55, 0.0),
		Vector2(landing_radius * 0.55, 0.0),
	])
	cross_a.width = 2.0
	cross_a.default_color = Color(1.0, 0.35, 0.12, 0.9)
	landing_marker.add_child(cross_a)

	var cross_b := Line2D.new()
	cross_b.points = PackedVector2Array([
		Vector2(0.0, -landing_radius * 0.18),
		Vector2(0.0, landing_radius * 0.18),
	])
	cross_b.width = 2.0
	cross_b.default_color = Color(1.0, 0.35, 0.12, 0.9)
	landing_marker.add_child(cross_b)


func make_ellipse_points(
	radius_x: float,
	radius_y: float,
	point_count: int,
	close_shape: bool
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var total_points: int = point_count + (1 if close_shape else 0)

	for index: int in range(total_points):
		var angle: float = TAU * float(index % point_count) / float(point_count)
		points.append(Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		))

	return points


func cancel_leap() -> void:
	if leap_state == LeapState.CHASING:
		return

	clear_landing_marker()
	leap_state = LeapState.CHASING
	state_timer = 0.0
	leap_cooldown_timer = maxf(leap_cooldown_timer, 1.0)


func clear_landing_marker() -> void:
	if is_instance_valid(landing_marker):
		landing_marker.queue_free()
	landing_marker = null


func die() -> void:
	clear_landing_marker()
	super.die()
