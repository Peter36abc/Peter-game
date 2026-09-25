extends CharacterBody2D

const DustParticles = preload("res://dust_particles.gd")


# ============================================================
# MOVEMENT
# ============================================================

@export_group("Movement")

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var knockback_duration: float = 0.24
@export var knockback_drag: float = 650.0


@export_group("Movement Particles")

@export var footstep_interval: float = 0.16
@export var footstep_particle_amount: int = 5
@export var jump_particle_amount: int = 14
@export var particle_ground_offset: float = 23.0
@export var movement_dust_color: Color = Color(0.76, 0.68, 0.53, 0.9)


# ============================================================
# LIVES
# ============================================================

@export_group("Lives")

# You currently have Heart1 through Heart7 in the HUD.
@export var max_lives: int = 8


# ============================================================
# AIMING
# ============================================================

@export_group("Aiming")

@export var aim_smoothing: float = 18.0


# ============================================================
# CAMERA SHAKE
# ============================================================

@export_group("Camera Shake")

@export var camera_shake_strength: float = 8.0
@export var camera_shake_duration: float = 0.18


# ============================================================
# ANIMATIONS
# ============================================================

@export_group("Animations")

@export var anim_idle: StringName = &"Idle"
@export var anim_run: StringName = &"Run"
@export var anim_jump: StringName = &"Jumping"

@export var anim_shoot_standing: StringName = &"Shootingstanding"
@export var anim_shoot_running: StringName = &"Shootingrunning"
@export var anim_shoot_jumping: StringName = &"Shootingjumping"

@export var anim_reload: StringName = &"Reloading-standing"
@export var anim_hurt: StringName = &"Hurt"

@export var hurt_animation_time: float = 0.45


# ============================================================
# GUN
# ============================================================

@export_group("Gun")

@export var mag_size: int = 12
@export var starting_reserve_ammo: int = 150

@export var reload_time: float = 1.5
@export var fire_rate: float = 0.15

@export var shoot_distance: float = 2000.0
@export var damage: int = 20
@export var max_reserve_ammo: int = 300


@export_group("Upgrades")

@export var starting_experience_to_level: int = 5
@export var extra_experience_per_level: int = 2
@export var levels_per_upgrade: int = 2
@export var multishot_spread_degrees: float = 8.0
@export var max_multishot_count: int = 10


# ============================================================
# WAVE REGEN
# ============================================================

@export_group("Wave Regen")

# Hearts restored when a wave is cleared.
@export var health_regen_per_wave: int = 2

# Reserve ammo restored when a wave is cleared.
@export var ammo_regen_per_wave: int = 24

# Also fill the magazine after a wave.
@export var refill_magazine_after_wave: bool = true


# ============================================================
# PROJECTILE
# ============================================================

@export_group("Projectile")

@export var projectile_speed: float = 1400.0
@export var projectile_lifetime: float = 0.12

@export var projectile_length: float = 22.0
@export var projectile_thickness: float = 1.5

@export var projectile_color: Color = Color(
	1.0,
	0.92,
	0.10,
	1.0
)


# ============================================================
# MUZZLE POSITION
# ============================================================

@export_group("Muzzle Position")

# How far forward the bullet starts
@export var muzzle_forward: float = 15.0

# IMPORTANT:
#
# Positive number = LOWER
#
# Standing and running are lower because their
# sprite frames are positioned differently.
#
# Jumping stays untouched at 0.

@export var muzzle_y_standing: float = 9.0
@export var muzzle_y_running: float = 9.0
@export var muzzle_y_jumping: float = 0.0


# ============================================================
# MUZZLE FLASH
# ============================================================

@export_group("Muzzle Flash")

@export var muzzle_flash_length: float = 18.0
@export var muzzle_flash_width: float = 5.0

@export var muzzle_flash_time: float = 0.05

@export var muzzle_flash_color: Color = Color(
	1.0,
	0.82,
	0.08,
	1.0
)


# ============================================================
# VARIABLES
# ============================================================

var current_lives: int = 0
var is_dead: bool = false

var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 5
var pending_upgrade_choices: int = 0
var multishot_count: int = 1
var shield_hits: int = 0

var ammo: int
var reserve_ammo: int

var can_shoot: bool = true
var fire_timer: float = 0.0

var is_shooting: bool = false

var is_reloading: bool = false
var reload_timer: float = 0.0

var is_hurt: bool = false
var hurt_timer: float = 0.0

var movement_direction: float = 0.0
var footstep_particle_timer: float = 0.0
var was_on_floor_for_particles: bool = false
var floor_particles_initialized: bool = false
var knockback_timer: float = 0.0

# Used so W only jumps once per key press
var was_w_pressed: bool = false

# Camera shake state
var camera_shake_timer: float = 0.0
var camera_base_offset: Vector2 = Vector2.ZERO


# ============================================================
# NODES
# ============================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera_2d: Camera2D = $Camera2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	add_to_group("players")

	current_lives = max_lives
	experience_to_next_level = starting_experience_to_level

	ammo = mag_size
	reserve_ammo = starting_reserve_ammo
	camera_base_offset = camera_2d.offset

	# HUD may finish entering the tree after the player.
	call_deferred("update_hud_lives")
	call_deferred("update_hud_ammo")
	call_deferred("update_hud_progress")


	# Make shooting animations loop while holding mouse

	if animated_sprite.sprite_frames.has_animation(
		anim_shoot_standing
	):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_shoot_standing,
			true
		)


	if animated_sprite.sprite_frames.has_animation(
		anim_shoot_running
	):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_shoot_running,
			true
		)


	if animated_sprite.sprite_frames.has_animation(
		anim_shoot_jumping
	):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_shoot_jumping,
			true
		)


	if animated_sprite.sprite_frames.has_animation(anim_hurt):
		animated_sprite.sprite_frames.set_animation_loop(
			anim_hurt,
			false
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

	# --------------------------------------------------------
	# GRAVITY
	# --------------------------------------------------------

	if not is_on_floor():
		velocity += get_gravity() * delta

	if process_knockback(delta):
		return


	# --------------------------------------------------------
	# W = JUMP
	# --------------------------------------------------------

	var w_pressed: bool = Input.is_physical_key_pressed(KEY_W)

	if w_pressed and not was_w_pressed and is_on_floor():
		spawn_movement_dust(jump_particle_amount, true)
		velocity.y = jump_velocity

	was_w_pressed = w_pressed


	# --------------------------------------------------------
	# A / D = MOVE
	# --------------------------------------------------------

	movement_direction = 0.0

	if Input.is_physical_key_pressed(KEY_A):
		movement_direction -= 1.0

	if Input.is_physical_key_pressed(KEY_D):
		movement_direction += 1.0


	if movement_direction != 0.0:

		velocity.x = movement_direction * speed

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			speed
		)


	move_and_slide()
	update_movement_particles(delta)


	# --------------------------------------------------------
	# HOLD SHOOTING ANIMATION
	# --------------------------------------------------------

	is_shooting = (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		and not is_reloading
		and not is_hurt
		and ammo > 0
	)


	update_animation()


func update_movement_particles(delta: float) -> void:
	var grounded_now: bool = is_on_floor()

	if (
		floor_particles_initialized
		and grounded_now
		and not was_on_floor_for_particles
	):
		spawn_movement_dust(jump_particle_amount + 4, true)

	if grounded_now and absf(velocity.x) > 5.0:
		footstep_particle_timer -= delta
		if footstep_particle_timer <= 0.0:
			footstep_particle_timer = footstep_interval
			spawn_movement_dust(footstep_particle_amount, false)
	else:
		footstep_particle_timer = 0.0

	was_on_floor_for_particles = grounded_now
	floor_particles_initialized = true


func spawn_movement_dust(
	particle_amount: int,
	strong_burst: bool
) -> void:
	DustParticles.spawn(
		get_tree(),
		global_position + Vector2(0.0, particle_ground_offset),
		particle_amount,
		strong_burst,
		movement_dust_color
	)


func apply_knockback(force: Vector2) -> void:
	if is_dead:
		return
	velocity = force
	knockback_timer = knockback_duration


func process_knockback(delta: float) -> bool:
	if knockback_timer <= 0.0:
		return false

	knockback_timer = maxf(knockback_timer - delta, 0.0)
	velocity.x = move_toward(velocity.x, 0.0, knockback_drag * delta)
	move_and_slide()
	update_movement_particles(delta)
	return true


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	if is_dead:
		handle_camera_shake(delta)
		return

	aim_at_mouse(delta)
	handle_camera_shake(delta)

	handle_fire_timer(delta)
	handle_reload(delta)
	handle_hurt(delta)


	# HOLD LEFT CLICK
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):

		shoot()


	# R TO RELOAD
	if Input.is_key_pressed(KEY_R):

		start_reload()


# ============================================================
# AIM AT MOUSE
# ============================================================

func aim_at_mouse(delta: float) -> void:

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)


	var mouse_direction: Vector2 = (
		mouse_position
		- animated_sprite.global_position
	)


	if mouse_direction.length_squared() <= 0.001:
		return


	var target_angle: float = (
		mouse_direction.angle()
	)


	# Smooth aim
	var smooth_amount: float = (
		1.0
		- exp(-aim_smoothing * delta)
	)


	smooth_amount = clampf(
		smooth_amount,
		0.0,
		1.0
	)


	animated_sprite.rotation = lerp_angle(
		animated_sprite.rotation,
		target_angle,
		smooth_amount
	)


	# Flip when aiming left
	if mouse_direction.x < 0.0:

		animated_sprite.flip_v = true

	else:

		animated_sprite.flip_v = false


# ============================================================
# ANIMATION SYSTEM
# ============================================================

func update_animation() -> void:

	# --------------------------------------------------------
	# HURT
	# --------------------------------------------------------

	if is_hurt:

		play_animation(anim_hurt)

		return


	# --------------------------------------------------------
	# RELOAD
	# --------------------------------------------------------

	if is_reloading:

		play_animation(anim_reload)

		return


	# --------------------------------------------------------
	# SHOOTING
	# --------------------------------------------------------

	if is_shooting:

		# Jumping + shooting
		if not is_on_floor():

			play_animation(
				anim_shoot_jumping
			)


		# Running + shooting
		elif absf(velocity.x) > 5.0:

			play_animation(
				anim_shoot_running
			)


		# Standing + shooting
		else:

			play_animation(
				anim_shoot_standing
			)


		return


	# --------------------------------------------------------
	# NORMAL
	# --------------------------------------------------------

	if not is_on_floor():

		play_animation(
			anim_jump
		)


	elif absf(velocity.x) > 5.0:

		play_animation(
			anim_run
		)


	else:

		play_animation(
			anim_idle
		)


# ============================================================
# PLAY ANIMATION
# ============================================================

func play_animation(
	animation_name: StringName
) -> void:

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):

		push_warning(
			"Missing animation: "
			+ String(animation_name)
		)

		return


	# Don't restart it every frame
	if animated_sprite.animation != animation_name:

		animated_sprite.play(
			animation_name
		)


# ============================================================
# GET MUZZLE POSITION
# ============================================================

func get_muzzle_position() -> Vector2:

	var y_offset: float = 0.0


	# --------------------------------------------------------
	# JUMPING
	#
	# Jump sprite is already at correct height.
	# --------------------------------------------------------

	if not is_on_floor():

		y_offset = muzzle_y_jumping


	# --------------------------------------------------------
	# RUNNING
	#
	# LOWER than jumping.
	# --------------------------------------------------------

	elif absf(velocity.x) > 5.0:

		y_offset = muzzle_y_running


	# --------------------------------------------------------
	# STANDING
	#
	# LOWER than jumping.
	# --------------------------------------------------------

	else:

		y_offset = muzzle_y_standing


	# --------------------------------------------------------
	# LOCAL MUZZLE POSITION
	# --------------------------------------------------------

	var local_muzzle: Vector2 = Vector2(
		muzzle_forward,
		y_offset
	)


	# When character aims left, flip the local Y
	# because the sprite uses flip_v.
	if animated_sprite.flip_v:

		local_muzzle.y = -local_muzzle.y


	# Rotate the muzzle position with the sprite
	local_muzzle = local_muzzle.rotated(
		animated_sprite.global_rotation
	)


	return (
		animated_sprite.global_position
		+ local_muzzle
	)


# ============================================================
# SHOOT
# ============================================================

func shoot() -> void:

	if is_reloading:
		return


	if is_hurt:
		return


	if not can_shoot:
		return


	# --------------------------------------------------------
	# EMPTY
	# --------------------------------------------------------

	if ammo <= 0:

		start_reload()

		return


	# --------------------------------------------------------
	# USE AMMO
	# --------------------------------------------------------

	ammo -= 1


	# --------------------------------------------------------
	# FIRE RATE
	# --------------------------------------------------------

	can_shoot = false

	fire_timer = fire_rate


	# --------------------------------------------------------
	# DIRECTION TO MOUSE
	# --------------------------------------------------------

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)


	var shoot_direction: Vector2 = (
		mouse_position
		- global_position
	).normalized()


	# --------------------------------------------------------
	# CORRECT MUZZLE POSITION
	# --------------------------------------------------------

	var muzzle_position: Vector2 = (
		get_muzzle_position()
	)


	# --------------------------------------------------------
	# MUZZLE FLASH
	# --------------------------------------------------------

	spawn_muzzle_flash(
		muzzle_position,
		shoot_direction
	)

	var center_index := float(multishot_count - 1) * 0.5
	for shot_index: int in range(multishot_count):
		var angle_offset := deg_to_rad(
			(float(shot_index) - center_index) * multishot_spread_degrees
		)
		var bullet_direction := shoot_direction.rotated(angle_offset)
		spawn_temp_projectile(muzzle_position, bullet_direction)
		fire_hitscan(muzzle_position, bullet_direction)


	print(
		"Ammo: ",
		ammo,
		"/",
		mag_size,
		" | Reserve: ",
		reserve_ammo
	)

	update_hud_ammo()


func fire_hitscan(start_position: Vector2, direction: Vector2) -> void:
	var shoot_end := start_position + direction * shoot_distance
	var query := PhysicsRayQueryParameters2D.create(
		start_position,
		shoot_end
	)
	query.exclude = [self]

	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Object = result["collider"]
	if collider.has_method("take_damage"):
		collider.call("take_damage", damage, direction)


# ============================================================
# THIN YELLOW TRACER
# ============================================================

func spawn_temp_projectile(
	start_position: Vector2,
	direction: Vector2
) -> void:

	var projectile := Polygon2D.new()


	var half_length: float = (
		projectile_length
		* 0.5
	)


	var half_thickness: float = (
		projectile_thickness
		* 0.5
	)


	projectile.polygon = PackedVector2Array([

		Vector2(
			-half_length,
			-half_thickness
		),

		Vector2(
			half_length,
			-half_thickness
		),

		Vector2(
			half_length,
			half_thickness
		),

		Vector2(
			-half_length,
			half_thickness
		)

	])


	projectile.color = (
		projectile_color
	)


	projectile.z_index = 100


	get_tree().current_scene.add_child(
		projectile
	)


	projectile.global_position = (
		start_position
	)


	projectile.global_rotation = (
		direction.angle()
	)


	# --------------------------------------------------------
	# MOVE TRACER
	# --------------------------------------------------------

	var end_position: Vector2 = (
		start_position
		+ direction
		* projectile_speed
		* projectile_lifetime
	)


	var tween: Tween = (
		create_tween()
	)


	tween.tween_property(
		projectile,
		"global_position",
		end_position,
		projectile_lifetime
	)


	tween.tween_callback(
		projectile.queue_free
	)


# ============================================================
# MUZZLE FLASH
# ============================================================

func spawn_muzzle_flash(
	start_position: Vector2,
	direction: Vector2
) -> void:

	var flash := Polygon2D.new()


	# Diamond / flame-like flash
	flash.polygon = PackedVector2Array([

		Vector2(
			0.0,
			0.0
		),

		Vector2(
			muzzle_flash_length * 0.35,
			-muzzle_flash_width
		),

		Vector2(
			muzzle_flash_length,
			0.0
		),

		Vector2(
			muzzle_flash_length * 0.35,
			muzzle_flash_width
		)

	])


	flash.color = (
		muzzle_flash_color
	)


	flash.z_index = 101


	get_tree().current_scene.add_child(
		flash
	)


	flash.global_position = (
		start_position
	)


	flash.global_rotation = (
		direction.angle()
	)


	flash.scale = Vector2(
		0.75,
		0.75
	)


	# --------------------------------------------------------
	# FLASH FADE
	# --------------------------------------------------------

	var tween: Tween = (
		create_tween()
	)


	tween.tween_property(
		flash,
		"scale",
		Vector2(
			1.35,
			1.35
		),
		muzzle_flash_time
	)


	tween.parallel().tween_property(
		flash,
		"modulate:a",
		0.0,
		muzzle_flash_time
	)


	tween.tween_callback(
		flash.queue_free
	)


# ============================================================
# FIRE TIMER
# ============================================================

func handle_fire_timer(
	delta: float
) -> void:

	if can_shoot:
		return


	fire_timer -= delta


	if fire_timer <= 0.0:

		can_shoot = true


# ============================================================
# START RELOAD
# ============================================================

func start_reload() -> void:

	if is_reloading:
		return


	if ammo >= mag_size:
		return


	if reserve_ammo <= 0:
		return


	is_reloading = true
	is_shooting = false

	reload_timer = reload_time


	update_animation()


	print("Reloading...")


# ============================================================
# HANDLE RELOAD
# ============================================================

func handle_reload(
	delta: float
) -> void:

	if not is_reloading:
		return


	reload_timer -= delta


	if reload_timer <= 0.0:

		finish_reload()


# ============================================================
# FINISH RELOAD
# ============================================================

func finish_reload() -> void:

	var ammo_needed: int = (
		mag_size
		- ammo
	)


	var ammo_to_load: int = mini(
		ammo_needed,
		reserve_ammo
	)


	ammo += ammo_to_load

	reserve_ammo -= ammo_to_load


	is_reloading = false


	update_animation()


	print(
		"Reloaded! Ammo: ",
		ammo,
		"/",
		mag_size,
		" | Reserve: ",
		reserve_ammo
	)

	update_hud_ammo()


# ============================================================
# CAMERA SHAKE
# ============================================================

func start_camera_shake() -> void:
	camera_shake_timer = camera_shake_duration


func handle_camera_shake(delta: float) -> void:

	if camera_shake_timer > 0.0:

		camera_shake_timer = maxf(
			camera_shake_timer - delta,
			0.0
		)

		var intensity: float = 1.0

		if camera_shake_duration > 0.0:
			intensity = camera_shake_timer / camera_shake_duration


		var shake_offset: Vector2 = Vector2(
			randf_range(
				-camera_shake_strength,
				camera_shake_strength
			),
			randf_range(
				-camera_shake_strength,
				camera_shake_strength
			)
		) * intensity


		camera_2d.offset = (
			camera_base_offset
			+ shake_offset
		)

	else:

		camera_2d.offset = camera_base_offset


# ============================================================
# TAKE DAMAGE / LIVES
# ============================================================

func take_damage(
	amount: int
) -> void:

	if is_dead:
		return

	if shield_hits > 0:
		shield_hits -= 1
		start_camera_shake()
		update_hud_progress()
		return

	# One zombie hit = one heart lost.
	current_lives = maxi(
		current_lives - 1,
		0
	)

	print(
		"Player hit! Lives: ",
		current_lives,
		"/",
		max_lives,
		" | Incoming damage value: ",
		amount
	)

	start_camera_shake()
	update_hud_lives()

	if current_lives <= 0:
		die()
		return

	start_hurt_animation()


func start_hurt_animation() -> void:
	is_hurt = true
	hurt_timer = get_animation_duration(
		anim_hurt,
		hurt_animation_time
	)

	if animated_sprite.sprite_frames.has_animation(anim_hurt):
		animated_sprite.play(anim_hurt)
		animated_sprite.frame = 0
		animated_sprite.frame_progress = 0.0
	else:
		update_animation()


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


func update_hud_lives() -> void:

	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null:
		return

	if hud.has_method("set_health"):
		hud.call("set_health", current_lives, max_lives)
	elif hud.has_method("set_lives"):
		hud.call("set_lives", current_lives)



func update_hud_ammo() -> void:

	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("set_ammo"):
		hud.call(
			"set_ammo",
			ammo,
			reserve_ammo
		)


func update_hud_progress() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return

	if hud.has_method("set_experience"):
		hud.call(
			"set_experience",
			level,
			experience,
			experience_to_next_level
		)

	if hud.has_method("set_shield"):
		hud.call("set_shield", shield_hits)


# ============================================================
# EXPERIENCE / UPGRADES
# ============================================================

func add_experience(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		experience_to_next_level = (
			starting_experience_to_level
			+ (level - 1) * extra_experience_per_level
		)

		if level % levels_per_upgrade == 0:
			pending_upgrade_choices += 1

	update_hud_progress()
	if pending_upgrade_choices > 0:
		call_deferred("show_upgrade_choice")


func show_upgrade_choice() -> void:
	if pending_upgrade_choices <= 0:
		return

	var menu: Node = get_tree().get_first_node_in_group("upgrade_menu")
	if menu != null and menu.has_method("show_for_player"):
		menu.call("show_for_player", self)


func has_pending_upgrades() -> bool:
	return pending_upgrade_choices > 0


func apply_upgrade(upgrade_id: StringName) -> void:
	if pending_upgrade_choices <= 0:
		return

	pending_upgrade_choices -= 1
	match upgrade_id:
		&"multishot":
			multishot_count = mini(
				multishot_count + 1,
				max_multishot_count
			)
		&"big_bullets":
			projectile_length *= 1.2
			projectile_thickness *= 1.45
			damage += 5
		&"damage":
			damage += 10
		&"rapid_fire":
			fire_rate = maxf(fire_rate * 0.85, 0.05)
		&"max_ammo":
			mag_size += 4
			max_reserve_ammo += 24
			ammo += 4
			reserve_ammo = mini(reserve_ammo + 24, max_reserve_ammo)
		&"shield":
			shield_hits += 2
		&"health":
			max_lives = mini(max_lives + 1, 16)
			current_lives = mini(current_lives + 2, max_lives)

	update_hud_lives()
	update_hud_ammo()
	update_hud_progress()


# ============================================================
# PICKUPS
# ============================================================

func add_health(amount: int = 1) -> bool:

	if is_dead:
		return false

	if current_lives >= max_lives:
		return false

	current_lives = mini(
		current_lives + amount,
		max_lives
	)

	update_hud_lives()

	print(
		"Health pickup! Lives: ",
		current_lives,
		"/",
		max_lives
	)

	return true


func add_ammo(amount: int = 12) -> bool:

	if is_dead:
		return false

	if reserve_ammo >= max_reserve_ammo:
		return false

	reserve_ammo = mini(
		reserve_ammo + amount,
		max_reserve_ammo
	)

	update_hud_ammo()

	print(
		"Ammo pickup! Reserve: ",
		reserve_ammo
	)

	return true


# ============================================================
# WAVE CLEAR REGEN
# ============================================================

func regenerate_after_wave() -> void:

	if is_dead:
		return

	current_lives = mini(
		current_lives + health_regen_per_wave,
		max_lives
	)

	reserve_ammo = mini(
		reserve_ammo + ammo_regen_per_wave,
		max_reserve_ammo
	)

	if refill_magazine_after_wave:
		var bullets_needed: int = mag_size - ammo
		var bullets_to_load: int = mini(
			bullets_needed,
			reserve_ammo
		)

		ammo += bullets_to_load
		reserve_ammo -= bullets_to_load

	update_hud_lives()
	update_hud_ammo()

	print(
		"WAVE REGEN -> Lives: ",
		current_lives,
		"/",
		max_lives,
		" | Ammo: ",
		ammo,
		"/",
		mag_size,
		" | Reserve: ",
		reserve_ammo
	)


func die() -> void:

	if is_dead:
		return

	is_dead = true
	is_hurt = false
	is_shooting = false
	is_reloading = false

	velocity = Vector2.ZERO

	print("PLAYER DIED")

	var death_menu: Node = get_tree().get_first_node_in_group("death_menu")
	if death_menu != null and death_menu.has_method("show_death"):
		death_menu.call_deferred("show_death", self)


# ============================================================
# HURT TIMER
# ============================================================

func handle_hurt(
	delta: float
) -> void:

	if not is_hurt:
		return


	hurt_timer -= delta


	if hurt_timer <= 0.0:

		is_hurt = false

		update_animation()
