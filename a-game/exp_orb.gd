extends Area2D

@export var experience_amount: int = 1
@export var magnet_radius: float = 170.0
@export var magnet_speed: float = 360.0
@export var collect_distance: float = 18.0

var target: Node2D = null
var magnetized := false
var collected := false
var bob_time := 0.0
var resting_y := 0.0
var resting_position_ready := false


func _ready() -> void:
	add_to_group("experience_pickups")
	body_entered.connect(_on_body_entered)
	call_deferred("_capture_resting_position")
	scale = Vector2(0.35, 0.35)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)


func _physics_process(delta: float) -> void:
	if collected:
		return

	if not is_instance_valid(target):
		target = _get_nearest_player()

	if target == null:
		_bob(delta)
		return

	var distance := global_position.distance_to(target.global_position)
	if distance <= magnet_radius:
		magnetized = true

	if magnetized:
		global_position = global_position.move_toward(
			target.global_position,
			magnet_speed * delta
		)
		if distance <= collect_distance:
			_collect(target)
	else:
		_bob(delta)


func _bob(delta: float) -> void:
	if not resting_position_ready:
		_capture_resting_position()
	bob_time += delta
	position.y = resting_y + sin(bob_time * 4.0) * 2.5


func _capture_resting_position() -> void:
	resting_y = position.y
	resting_position_ready = true


func _get_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for node: Node in get_tree().get_nodes_in_group("players"):
		if not node is Node2D:
			continue
		var player := node as Node2D
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = player
	return nearest


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		_collect(body)


func _collect(body: Node) -> void:
	if collected or not body.has_method("add_experience"):
		return
	collected = true
	body.call("add_experience", experience_amount)
	queue_free()
