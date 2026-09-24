extends Area2D


@export var speed: float = 1200.0
@export var life_time: float = 2.0


var direction: Vector2 = Vector2.RIGHT
var damage: int = 20

var shooter: Node = null


func setup(
	new_direction: Vector2,
	new_damage: int,
	new_shooter: Node
) -> void:

	direction = new_direction.normalized()

	damage = new_damage

	shooter = new_shooter

	rotation = direction.angle()


func _ready() -> void:

	body_entered.connect(
		_on_body_entered
	)


func _physics_process(delta: float) -> void:

	global_position += (
		direction
		* speed
		* delta
	)


	life_time -= delta


	if life_time <= 0.0:

		queue_free()


func _on_body_entered(body: Node) -> void:

	# Don't shoot player who fired it
	if body == shooter:
		return


	if body.has_method("take_damage"):

		body.call(
			"take_damage",
			damage
		)


	queue_free()
