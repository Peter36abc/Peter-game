extends CharacterBody2D


# ============================================================
# MOVEMENT
# ============================================================

@export_group("Movement")

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0


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

@export var hurt_animation_time: float = 0.30


# ============================================================
# GUN
# ============================================================

@export_group("Gun")

@export var mag_size: int = 12
@export var starting_reserve_ammo: int = 60

@export var reload_time: float = 1.5
@export var fire_rate: float = 0.15

@export var shoot_distance: float = 2000.0
@export var damage: int = 20
@export var max_reserve_ammo: int = 120


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

	ammo = mag_size
	reserve_ammo = starting_reserve_ammo
	camera_base_offset = camera_2d.offset

	# HUD may finish entering the tree after the player.
	call_deferred("update_hud_lives")
	call_deferred("update_hud_ammo")


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


	# --------------------------------------------------------
	# W = JUMP
	# --------------------------------------------------------

	var w_pressed: bool = Input.is_physical_key_pressed(KEY_W)

	if w_pressed and not was_w_pressed and is_on_floor():
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
	# YELLOW TRACER
	# --------------------------------------------------------

	spawn_temp_projectile(
		muzzle_position,
		shoot_direction
	)


	# --------------------------------------------------------
	# MUZZLE FLASH
	# --------------------------------------------------------

	spawn_muzzle_flash(
		muzzle_position,
		shoot_direction
	)


	# --------------------------------------------------------
	# HITSCAN
	# --------------------------------------------------------

	var shoot_start: Vector2 = (
		muzzle_position
	)


	var shoot_end: Vector2 = (
		shoot_start
		+ shoot_direction
		* shoot_distance
	)


	var space_state: PhysicsDirectSpaceState2D = (
		get_world_2d().direct_space_state
	)


	var query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			shoot_start,
			shoot_end
		)
	)


	query.exclude = [self]


	var result: Dictionary = (
		space_state.intersect_ray(query)
	)


	# --------------------------------------------------------
	# HIT
	# --------------------------------------------------------

	if not result.is_empty():

		var collider: Object = (
			result["collider"]
		)


		if collider.has_method(
			"take_damage"
		):

			collider.call(
				"take_damage",
				damage
			)


	print(
		"Ammo: ",
		ammo,
		"/",
		mag_size,
		" | Reserve: ",
		reserve_ammo
	)

	update_hud_ammo()


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

	is_hurt = true
	hurt_timer = hurt_animation_time

	update_animation()


func update_hud_lives() -> void:

	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("set_lives"):
		hud.call(
			"set_lives",
			current_lives
		)



func update_hud_ammo() -> void:

	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("set_ammo"):
		hud.call(
			"set_ammo",
			ammo,
			reserve_ammo
		)


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
