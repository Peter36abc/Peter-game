extends CharacterBody2D

const DustParticles = preload("res://dust_particles.gd")
const ExpOrbScene = preload("res://ExpOrb.tscn")

signal died(zombie: Node)


# ============================================================
# ZOMBIE SETTINGS
# ============================================================

@export_group("Zombie")

@export var speed: float = 100.0
@export var max_health: int = 100
@export var damage: int = 10

@export var attack_distance: float = 45.0
@export var attack_vertical_distance: float = 24.0
@export var attack_cooldown: float = 1.0
@export var spawn_y_adjustment: float = 0.0
@export var knockback_duration: float = 0.28
@export var knockback_drag: float = 520.0


@export_group("Movement Particles")

@export var footstep_interval: float = 0.25
@export var footstep_particle_amount: int = 4
@export var ground_effect_offset: float = 24.0
@export var dust_color: Color = Color(0.68, 0.61, 0.48, 0.82)


# ============================================================
# ANIMATIONS
# ============================================================

@export_group("Animations")

@export var anim_idle: StringName = &"Idle"
@export var anim_running: StringName = &"Running"
@export var anim_attack: StringName = &"Attack"
@export var anim_hurt: StringName = &"Hurt"
@export var anim_die: StringName = &"Die"

@export var hurt_time: float = 0.25


# ============================================================
# BLOOD VFX
# ============================================================

@export_group("Blood VFX")

@export var blood_amount: int = 10

@export var blood_size_min: float = 1.5
@export var blood_size_max: float = 4.0

@export var blood_distance_min: float = 20.0
@export var blood_distance_max: float = 55.0

@export var blood_lifetime: float = 0.35
@export var blood_y_offset: float = -10.0

@export var blood_color: Color = Color(
	0.65,
	0.02,
	0.02,
	1.0
)



# ============================================================
# PICKUP DROPS
# ============================================================

@export_group("Pickup Drops")

# Drag your Health pickup scene here.
@export var health_pickup_scene: PackedScene

# Drag your Ammo/BulletRegen pickup scene here.
@export var ammo_pickup_scene: PackedScene

# 0.15 = 15% chance.
@export_range(0.0, 1.0, 0.01) var health_drop_chance: float = 0.15
@export_range(0.0, 1.0, 0.01) var ammo_drop_chance: float = 0.20

# Small random horizontal separation if both drop.
@export var pickup_drop_spread: float = 12.0

@export_group("Experience")
@export var experience_value: int = 1


# ============================================================
# VARIABLES
# ============================================================

var health: int

var target: Node2D = null

var can_attack: bool = true
var attack_timer: float = 0.0

var is_attacking: bool = false

var is_hurt: bool = false
var hurt_timer: float = 0.0

var is_dead: bool = false
var footstep_particle_timer: float = 0.0
var knockback_timer: float = 0.0


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	add_to_group("zombies")

	health = max_health


	if animated_sprite.sprite_frames.has_animation(anim_idle):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_idle,
			true
		)


	if animated_sprite.sprite_frames.has_animation(anim_running):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_running,
			true
		)


	if animated_sprite.sprite_frames.has_animation(anim_attack):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_attack,
			true
		)


	if animated_sprite.sprite_frames.has_animation(anim_hurt):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_hurt,
			false
		)


	if animated_sprite.sprite_frames.has_animation(anim_die):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_die,
			false
		)


	animated_sprite.animation_finished.connect(
		_on_animation_finished
	)


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:

	if is_dead:

		velocity.x = 0.0

		if not is_on_floor():
			velocity += get_gravity() * delta

		move_and_slide()
		return


	if not is_on_floor():
		velocity += get_gravity() * delta

	if process_knockback(delta):
		return


	handle_attack_timer(delta)
	handle_hurt_timer(delta)


	if is_hurt:

		velocity.x = 0.0

		update_animation()
		move_and_slide()
		return


	target = get_nearest_player()


	if target == null:

		velocity.x = 0.0
		is_attacking = false

		update_animation()
		move_and_slide()
		return


	var direction: float = sign(
		target.global_position.x
		- global_position.x
	)


	if direction < 0.0:
		animated_sprite.flip_h = true

	elif direction > 0.0:
		animated_sprite.flip_h = false


	if not is_target_in_attack_range():

		is_attacking = false
		velocity.x = direction * speed

	else:

		velocity.x = 0.0
		is_attacking = true

		attack_player()


	update_animation()

	move_and_slide()
	process_footstep_particles(delta)


func process_footstep_particles(delta: float) -> void:
	if not is_on_floor() or absf(velocity.x) <= 1.0:
		footstep_particle_timer = 0.0
		return

	footstep_particle_timer -= delta
	if footstep_particle_timer > 0.0:
		return

	footstep_particle_timer = footstep_interval
	spawn_dust_burst(
		global_position + Vector2(0.0, ground_effect_offset),
		footstep_particle_amount,
		false
	)


func spawn_dust_burst(
	world_position: Vector2,
	particle_amount: int,
	strong_burst: bool
) -> void:
	DustParticles.spawn(
		get_tree(),
		world_position,
		particle_amount,
		strong_burst,
		dust_color
	)


func apply_knockback(force: Vector2) -> void:
	if is_dead:
		return
	velocity = force
	knockback_timer = knockback_duration
	is_attacking = false


func process_knockback(delta: float) -> bool:
	if knockback_timer <= 0.0:
		return false

	knockback_timer = maxf(knockback_timer - delta, 0.0)
	velocity.x = move_toward(velocity.x, 0.0, knockback_drag * delta)
	is_attacking = false
	handle_hurt_timer(delta)
	update_animation()
	move_and_slide()
	process_footstep_particles(delta)
	return true


# ============================================================
# ANIMATIONS
# ============================================================

func update_animation() -> void:

	if is_dead:
		play_animation(anim_die)
		return


	if is_hurt:
		play_animation(anim_hurt)
		return


	if is_attacking:
		play_animation(anim_attack)
		return


	if absf(velocity.x) > 1.0:
		play_animation(anim_running)
		return


	play_animation(anim_idle)


func play_animation(animation_name: StringName) -> void:

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		push_warning(
			"Zombie animation missing: "
			+ String(animation_name)
		)
		return


	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


# ============================================================
# FIND PLAYER
# ============================================================

func get_nearest_player() -> Node2D:

	var players: Array[Node] = (
		get_tree().get_nodes_in_group("players")
	)


	if players.is_empty():
		return null


	var nearest_player: Node2D = null
	var nearest_distance: float = INF


	for player_node: Node in players:

		if not player_node is Node2D:
			continue


		var player: Node2D = player_node as Node2D

		var distance: float = (
			global_position.distance_squared_to(
				player.global_position
			)
		)


		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = player


	return nearest_player


# ============================================================
# ATTACK
# ============================================================

func attack_player() -> void:

	if not can_attack:
		return

	if target == null:
		return

	if is_dead or is_hurt:
		return

	# Do not hit a player who is jumping over or standing on the zombie.
	if not is_target_in_attack_range():
		return


	can_attack = false
	attack_timer = attack_cooldown


	if target.has_method("take_damage"):
		target.call(
			"take_damage",
			damage
		)


func is_target_in_attack_range() -> bool:
	if target == null:
		return false

	var offset: Vector2 = target.global_position - global_position
	return (
		absf(offset.x) <= attack_distance
		and absf(offset.y) <= attack_vertical_distance
	)


func handle_attack_timer(delta: float) -> void:

	if can_attack:
		return


	attack_timer -= delta


	if attack_timer <= 0.0:
		can_attack = true


# ============================================================
# DAMAGE
# ============================================================

func take_damage(
	amount: int,
	hit_direction: Vector2 = Vector2.ZERO
) -> void:

	if is_dead:
		return


	health -= amount

	spawn_blood(hit_direction)


	if health <= 0:
		die()
		return


	start_hurt_animation()


func start_hurt_animation() -> void:
	is_hurt = true
	is_attacking = false
	hurt_timer = get_animation_duration(anim_hurt, hurt_time) + 0.05

	# Restart the complete hurt animation from frame 0 on every hit.
	if animated_sprite.sprite_frames.has_animation(anim_hurt):
		animated_sprite.play(anim_hurt)
		animated_sprite.frame = 0
		animated_sprite.frame_progress = 0.0


func get_animation_duration(
	animation_name: StringName,
	fallback_duration: float
) -> float:
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if not frames.has_animation(animation_name):
		return fallback_duration

	var animation_speed: float = absf(
		frames.get_animation_speed(animation_name)
		* animated_sprite.speed_scale
	)
	if animation_speed <= 0.001:
		return fallback_duration

	var duration: float = 0.0
	for frame_index: int in range(frames.get_frame_count(animation_name)):
		duration += frames.get_frame_duration(
			animation_name,
			frame_index
		)

	return maxf(fallback_duration, duration / animation_speed)


func handle_hurt_timer(delta: float) -> void:

	if not is_hurt:
		return


	hurt_timer -= delta


	if hurt_timer <= 0.0:
		is_hurt = false
		update_animation()


# ============================================================
# DIE
# ============================================================

func die() -> void:

	if is_dead:
		return


	is_dead = true
	is_hurt = false
	is_attacking = false
	can_attack = false

	velocity.x = 0.0

	spawn_pickup_drops()
	spawn_experience_drop()


	# Tell the wave spawner immediately that this zombie is dead.
	emit_signal(
		"died",
		self
	)


	var collision: CollisionShape2D = (
		get_node_or_null("CollisionShape2D")
	)


	if collision != null:
		collision.set_deferred(
			"disabled",
			true
		)


	if animated_sprite.sprite_frames.has_animation(anim_die):

		animated_sprite.play(anim_die)

	else:

		queue_free()


func _on_animation_finished() -> void:

	if is_dead and animated_sprite.animation == anim_die:
		queue_free()
	elif is_hurt and animated_sprite.animation == anim_hurt:
		is_hurt = false
		hurt_timer = 0.0
		update_animation()




# ============================================================
# PICKUP DROPS
# ============================================================

func spawn_pickup_drops() -> void:

	# Health drop
	if health_pickup_scene != null and randf() <= health_drop_chance:

		var health_pickup: Node = (
			health_pickup_scene.instantiate()
		)

		get_tree().current_scene.add_child(
			health_pickup
		)

		if health_pickup is Node2D:
			var health_2d: Node2D = health_pickup as Node2D
			health_2d.global_position = (
				global_position
				+ Vector2(
					randf_range(
						-pickup_drop_spread,
						pickup_drop_spread
					),
					0.0
				)
			)


	# Ammo drop
	if ammo_pickup_scene != null and randf() <= ammo_drop_chance:

		var ammo_pickup: Node = (
			ammo_pickup_scene.instantiate()
		)

		get_tree().current_scene.add_child(
			ammo_pickup
		)

		if ammo_pickup is Node2D:
			var ammo_2d: Node2D = ammo_pickup as Node2D
			ammo_2d.global_position = (
				global_position
				+ Vector2(
					randf_range(
						-pickup_drop_spread,
						pickup_drop_spread
					),
					0.0
				)
			)


func spawn_experience_drop() -> void:
	if experience_value <= 0:
		return

	var orb: Node = ExpOrbScene.instantiate()
	orb.set("experience_amount", experience_value)
	get_tree().current_scene.add_child(orb)

	if orb is Node2D:
		var orb_2d := orb as Node2D
		orb_2d.global_position = (
			global_position
			+ Vector2(randf_range(-8.0, 8.0), ground_effect_offset)
		)


# ============================================================
# BLOOD SPLASH
# ============================================================

func spawn_blood(
	hit_direction: Vector2 = Vector2.ZERO
) -> void:

	var blood_origin: Vector2 = (
		global_position
		+ Vector2(
			0.0,
			blood_y_offset
		)
	)


	var base_direction: Vector2 = (
		hit_direction.normalized()
	)


	if base_direction.length_squared() <= 0.001:

		if animated_sprite.flip_h:
			base_direction = Vector2.RIGHT

		else:
			base_direction = Vector2.LEFT


	for i: int in range(blood_amount):

		var blood := Polygon2D.new()


		var size: float = randf_range(
			blood_size_min,
			blood_size_max
		)


		blood.polygon = PackedVector2Array([
			Vector2(0.0, -size),
			Vector2(size, 0.0),
			Vector2(0.0, size),
			Vector2(-size, 0.0)
		])


		var brightness: float = randf_range(
			0.65,
			1.0
		)


		blood.color = Color(
			blood_color.r * brightness,
			blood_color.g,
			blood_color.b,
			1.0
		)


		blood.z_index = 200


		get_tree().current_scene.add_child(
			blood
		)


		blood.global_position = blood_origin


		var splash_direction: Vector2 = (
			base_direction.rotated(
				randf_range(
					-1.2,
					1.2
				)
			)
		)


		splash_direction.y -= randf_range(
			0.1,
			0.8
		)


		splash_direction = (
			splash_direction.normalized()
		)


		var end_position: Vector2 = (
			blood_origin
			+ splash_direction
			* randf_range(
				blood_distance_min,
				blood_distance_max
			)
		)


		end_position.y += randf_range(
			5.0,
			20.0
		)


		var tween: Tween = create_tween()

		tween.set_parallel(true)


		tween.tween_property(
			blood,
			"global_position",
			end_position,
			blood_lifetime
		)


		tween.tween_property(
			blood,
			"rotation",
			randf_range(
				-4.0,
				4.0
			),
			blood_lifetime
		)


		tween.tween_property(
			blood,
			"modulate:a",
			0.0,
			blood_lifetime
		)


		get_tree().create_timer(
			blood_lifetime + 0.05
		).timeout.connect(
			blood.queue_free
		)
