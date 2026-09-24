extends Area2D


# ============================================================
# HEALTH PICKUP
# ============================================================

@export_group("Health Pickup")

@export var heal_amount: int = 1
@export var lifetime: float = 15.0


# ============================================================
# FLOAT EFFECT
# ============================================================

@export_group("Float Effect")

@export var bob_height: float = 4.0
@export var bob_speed: float = 3.0


var start_y: float = 0.0
var age: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	body_entered.connect(
		_on_body_entered
	)

	start_y = position.y


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	age += delta


	# Floating effect
	position.y = (
		start_y
		+ sin(age * bob_speed)
		* bob_height
	)


	# Despawn timer
	lifetime -= delta


	if lifetime <= 0.0:

		queue_free()


# ============================================================
# PICKUP
# ============================================================

func _on_body_entered(body: Node) -> void:

	# ONLY PLAYER CAN PICK THIS UP
	if not body.is_in_group("players"):
		return


	# Player must have add_health()
	if not body.has_method("add_health"):
		return


	var picked_up: bool = body.call(
		"add_health",
		heal_amount
	)


	# Only remove the pickup if health was actually restored
	if picked_up:

		queue_free()
