extends Control

const UPGRADE_POOL: Array[Dictionary] = [
	{
		"id": &"multishot",
		"title": "MULTI SHOT",
		"description": "Add one bullet. Stacks up to 10."
	},
	{
		"id": &"big_bullets",
		"title": "BIG BULLETS",
		"description": "Larger bullets and +5 damage."
	},
	{
		"id": &"damage",
		"title": "HIGHER DAMAGE",
		"description": "+10 damage for every bullet."
	},
	{
		"id": &"rapid_fire",
		"title": "RAPID FIRE",
		"description": "Shoot 15% faster."
	},
	{
		"id": &"max_ammo",
		"title": "MORE AMMO",
		"description": "+4 magazine and +24 reserve."
	},
	{
		"id": &"shield",
		"title": "SHIELD",
		"description": "Block the next two hits."
	},
	{
		"id": &"health",
		"title": "MORE HEALTH",
		"description": "+1 maximum heart and heal two."
	}
]

@onready var level_label: Label = $Content/LevelLabel
@onready var buttons: Array[Button] = [
	$Content/Cards/Card1,
	$Content/Cards/Card2,
	$Content/Cards/Card3
]

var player: Node = null
var choosing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_menu")
	for index: int in range(buttons.size()):
		buttons[index].pressed.connect(_choose_upgrade.bind(index))


func show_for_player(target_player: Node) -> void:
	if visible or not is_instance_valid(target_player):
		return

	player = target_player
	choosing = false
	level_label.text = "LEVEL " + str(player.get("level"))

	var pool: Array[Dictionary] = []
	for upgrade: Dictionary in UPGRADE_POOL:
		pool.append(upgrade)
	pool.shuffle()

	for index: int in range(buttons.size()):
		var choice: Dictionary = pool[index]
		buttons[index].text = (
			String(choice["title"])
			+ "\n\n"
			+ String(choice["description"])
		)
		buttons[index].set_meta("upgrade_id", choice["id"])

	visible = true
	get_tree().paused = true
	buttons[0].grab_focus()


func _choose_upgrade(index: int) -> void:
	if choosing or not is_instance_valid(player):
		return
	choosing = true

	var upgrade_id: StringName = buttons[index].get_meta("upgrade_id", &"")
	player.call("apply_upgrade", upgrade_id)
	visible = false
	get_tree().paused = false

	if (
		player.has_method("has_pending_upgrades")
		and bool(player.call("has_pending_upgrades"))
	):
		call_deferred("show_for_player", player)
