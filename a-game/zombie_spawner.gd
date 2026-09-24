extends Node2D

# ============================================================
# INFINITE ZOMBIE WAVE SPAWNER
# ============================================================

@export_group("Zombie Scene")

# Change the path if your Zombie.tscn is somewhere else.
@export var zombie_scene: PackedScene = preload("res://Zombie.tscn")


@export_group("Wave")

# Wave 1 starts with this many zombies.
@export var starting_zombies: int = 10

# Added every new wave:
# Wave 1 = 10
# Wave 2 = 13
# Wave 3 = 16 ...
@export var zombies_added_per_wave: int = 3

# Delay after killing the last zombie.
@export var time_between_waves: float = 3.0


@export_group("Spawning")

# Time between individual zombie spawns.
@export var spawn_interval: float = 0.75

# Stops hundreds of zombies being alive at once in later waves.
# The rest remain queued and spawn when zombies die.
@export var max_alive_at_once: int = 15

# Zombies appear to the LEFT or RIGHT of the nearest player.
@export var spawn_distance_min: float = 350.0
@export var spawn_distance_max: float = 500.0

# Adjust if the zombie feet appear too high/low.
@export var spawn_y_offset: float = 0.0


var current_wave: int = 0

var zombies_this_wave: int = 0
var zombies_left_to_spawn: int = 0
var zombies_left_to_kill: int = 0
var zombies_alive: int = 0

var spawn_timer: float = 0.0

var waiting_for_next_wave: bool = false
var wave_wait_timer: float = 0.0


func _ready() -> void:
	add_to_group("wave_spawners")

	# Waiting one frame makes it more likely Player + HUD are ready first.
	call_deferred("start_next_wave")


func _process(delta: float) -> void:

	if waiting_for_next_wave:

		wave_wait_timer -= delta

		if wave_wait_timer <= 0.0:
			start_next_wave()

		return


	# Nothing more needs spawning.
	if zombies_left_to_spawn <= 0:
		return


	# Keep a reasonable alive cap.
	if zombies_alive >= max_alive_at_once:
		return


	spawn_timer -= delta

	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		spawn_one_zombie()


# ============================================================
# START WAVE
# ============================================================

func start_next_wave() -> void:

	waiting_for_next_wave = false

	current_wave += 1

	zombies_this_wave = (
		starting_zombies
		+ (current_wave - 1) * zombies_added_per_wave
	)

	zombies_left_to_spawn = zombies_this_wave
	zombies_left_to_kill = zombies_this_wave
	zombies_alive = 0

	spawn_timer = 0.25

	update_hud()

	print(
		"WAVE ",
		current_wave,
		" STARTED - ",
		zombies_this_wave,
		" zombies"
	)


# ============================================================
# SPAWN
# ============================================================

func spawn_one_zombie() -> void:

	if zombie_scene == null:
		push_error("Zombie scene is not assigned.")
		return


	var player: Node2D = get_nearest_player()

	if player == null:
		print("NO PLAYER FOUND IN 'players' GROUP!")
		return


	var side: float = 1.0

	if randf() < 0.5:
		side = -1.0


	var distance: float = randf_range(
		spawn_distance_min,
		spawn_distance_max
	)


	var spawn_position: Vector2 = Vector2(
		player.global_position.x + distance * side,
		player.global_position.y + spawn_y_offset
	)


	var zombie: Node = zombie_scene.instantiate()

	get_tree().current_scene.add_child(zombie)


	if zombie is Node2D:
		var zombie_2d: Node2D = zombie as Node2D
		zombie_2d.global_position = spawn_position


	# zombie.gd below has:
	# signal died(zombie: Node)
	if zombie.has_signal("died"):
		zombie.connect(
			"died",
			Callable(self, "_on_zombie_died")
		)
	else:
		push_warning(
			"Zombie has no 'died' signal. Use the provided zombie.gd."
		)


	zombies_left_to_spawn -= 1
	zombies_alive += 1

	update_hud()


# ============================================================
# ZOMBIE DIED
# ============================================================

func _on_zombie_died(_zombie: Node) -> void:

	zombies_alive = maxi(
		zombies_alive - 1,
		0
	)

	zombies_left_to_kill = maxi(
		zombies_left_to_kill - 1,
		0
	)

	update_hud()


	# Last zombie of the wave was killed.
	if zombies_left_to_kill <= 0:
		begin_wave_break()


# ============================================================
# WAVE BREAK
# ============================================================

func begin_wave_break() -> void:

	if waiting_for_next_wave:
		return


	waiting_for_next_wave = true
	wave_wait_timer = time_between_waves

	# Restore player health/ammo once when the wave is cleared.
	regenerate_players_after_wave()

	print(
		"WAVE ",
		current_wave,
		" COMPLETE!"
	)




func regenerate_players_after_wave() -> void:

	var players: Array[Node] = (
		get_tree().get_nodes_in_group("players")
	)

	for player_node: Node in players:

		if player_node.has_method("regenerate_after_wave"):
			player_node.call(
				"regenerate_after_wave"
			)


# ============================================================
# HUD
# ============================================================

func update_hud() -> void:

	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null:
		return


	if hud.has_method("set_wave"):
		hud.call(
			"set_wave",
			current_wave
		)


	# This is the number that must still DIE for the wave to end.
	# It includes zombies that haven't spawned yet.
	if hud.has_method("set_zombies_remaining"):
		hud.call(
			"set_zombies_remaining",
			zombies_left_to_kill
		)


# ============================================================
# FIND NEAREST PLAYER
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
