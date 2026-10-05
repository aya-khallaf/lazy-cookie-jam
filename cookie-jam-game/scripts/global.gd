extends Node

signal level_up_requested

const BASE_PLAYER_MAX_HEALTH = 100.0
const BASE_KING_MAX_HEALTH = 100.0

var player_node = null
var king_node = null

var player_health = BASE_PLAYER_MAX_HEALTH
var player_max_health = BASE_PLAYER_MAX_HEALTH

var king_health = BASE_KING_MAX_HEALTH
var king_max_health = BASE_KING_MAX_HEALTH

var respawning = false

var run_time = 0.0
var kills = 0

var level = 1
var xp = 0.0
var xp_to_next_level = 20.0

var pending_level_ups = 0

var last_upgrade_text = ""

var weapon_damage = 20.0
var attack_speed_multiplier = 1.0
var sword_size_multiplier = 1.0

var lifesteal = 0.0

var player_health_regen = 0.0
var king_health_regen = 0.0

var player_speed_multiplier = 1.0
var king_speed_multiplier = 1.0

var xp_gain_multiplier = 1.0
var pickup_range_multiplier = 1.0

var heart_heal_amount = 20.0

var enemy_health_multiplier = 1.0
var enemy_speed_multiplier = 1.0
var enemy_damage_multiplier = 1.0

var player_hit_cooldown = 0.0
var king_hit_cooldown = 0.0


func _process(delta: float) -> void:
	run_time += delta

	player_hit_cooldown = max(
		player_hit_cooldown - delta,
		0.0
	)

	king_hit_cooldown = max(
		king_hit_cooldown - delta,
		0.0
	)

	if player_health_regen > 0.0:
		heal_player(
			player_health_regen * delta
		)

	if king_health_regen > 0.0:
		heal_king(
			king_health_regen * delta
		)

	enemy_health_multiplier = (
		1.0 +
		run_time / 120.0
	)

	enemy_speed_multiplier = min(
		1.0 + run_time / 600.0,
		1.5
	)

	enemy_damage_multiplier = (
		1.0 +
		run_time / 240.0
	)


func damage_player(amount: float) -> bool:
	if player_hit_cooldown > 0.0:
		return false

	player_health -= amount

	player_hit_cooldown = 0.35

	return true


func damage_king(amount: float) -> bool:
	if king_hit_cooldown > 0.0:
		return false

	king_health -= amount

	king_hit_cooldown = 0.25

	return true


func heal_player(amount: float) -> void:
	player_health = min(
		player_health + amount,
		player_max_health
	)


func heal_king(amount: float) -> void:
	king_health = min(
		king_health + amount,
		king_max_health
	)


func add_xp(amount: float) -> void:
	xp += (
		amount *
		xp_gain_multiplier
	)

	while xp >= xp_to_next_level:
		xp -= xp_to_next_level

		_level_up()


func _level_up() -> void:
	level += 1

	xp_to_next_level = round(
		xp_to_next_level * 1.22 + 5.0
	)

	player_max_health += 2.0
	king_max_health += 3.0

	player_health += 2.0
	king_health += 3.0

	player_health = min(
		player_health,
		player_max_health
	)

	king_health = min(
		king_health,
		king_max_health
	)

	player_speed_multiplier += 0.01
	king_speed_multiplier += 0.015

	pending_level_ups += 1

	level_up_requested.emit()


func get_upgrade_choices() -> Array:
	var available_upgrades = [
		"sword_damage",
		"attack_speed",
		"sword_size",
		"king_regen",
		"king_speed",
		"player_speed",
		"king_health",
		"heart_healing",
		"xp_gain"
	]

	var choices = []

	while choices.size() < 3:
		var index = randi_range(
			0,
			available_upgrades.size() - 1
		)

		choices.append(
			available_upgrades[index]
		)

		available_upgrades.remove_at(index)

	return choices


func get_upgrade_text(
	upgrade_id: String
) -> String:

	match upgrade_id:
		"sword_damage":
			return "SHARPENED STEEL\nSword damage +5"

		"attack_speed":
			return "QUICK HANDS\nSword attack speed +12%"

		"sword_size":
			return "LONG BLADE\nSword size and range +10%"

		"king_regen":
			return "ROYAL REST\nKing regen +0.4 HP/s"

		"king_speed":
			return "MOVE YOUR MAJESTY\nKing speed +10%"

		"player_speed":
			return "LIGHT FEET\nMovement speed +6%"

		"king_health":
			return "ROYAL FORTITUDE\nKing max health +20"

		"heart_healing":
			return "BIG HEART\nHearts heal king +8 HP"

		"xp_gain":
			return "QUICK LEARNER\nXP gain and pickup range +15%"

	return "UNKNOWN"


func apply_upgrade(
	upgrade_id: String
) -> void:

	match upgrade_id:
		"sword_damage":
			weapon_damage += 5.0

			last_upgrade_text = (
				"Sword Damage +5"
			)


		"attack_speed":
			attack_speed_multiplier += 0.12

			last_upgrade_text = (
				"Sword Attack Speed +12%"
			)


		"sword_size":
			sword_size_multiplier += 0.10

			last_upgrade_text = (
				"Sword Size +10%"
			)


		"king_regen":
			king_health_regen += 0.4

			last_upgrade_text = (
				"King Regen +0.4 HP/s"
			)


		"king_speed":
			king_speed_multiplier += 0.10

			last_upgrade_text = (
				"King Speed +10%"
			)


		"player_speed":
			player_speed_multiplier += 0.06

			last_upgrade_text = (
				"Movement Speed +6%"
			)


		"king_health":
			king_max_health += 20.0
			king_health += 20.0

			last_upgrade_text = (
				"King Max Health +20"
			)


		"heart_healing":
			heart_heal_amount += 8.0

			last_upgrade_text = (
				"Heart Healing +8"
			)


		"xp_gain":
			xp_gain_multiplier += 0.15
			pickup_range_multiplier += 0.15

			last_upgrade_text = (
				"XP Gain +15%"
			)


func reset_run_progress() -> void:
	run_time = 0.0
	kills = 0

	level = 1
	xp = 0.0
	xp_to_next_level = 20.0

	pending_level_ups = 0

	last_upgrade_text = ""

	player_max_health = BASE_PLAYER_MAX_HEALTH
	king_max_health = BASE_KING_MAX_HEALTH

	player_health = player_max_health
	king_health = king_max_health

	weapon_damage = 20.0
	attack_speed_multiplier = 1.0
	sword_size_multiplier = 1.0

	lifesteal = 0.0

	player_health_regen = 0.0
	king_health_regen = 0.0

	player_speed_multiplier = 1.0
	king_speed_multiplier = 1.0

	xp_gain_multiplier = 1.0
	pickup_range_multiplier = 1.0

	heart_heal_amount = 20.0

	enemy_health_multiplier = 1.0
	enemy_speed_multiplier = 1.0
	enemy_damage_multiplier = 1.0

	player_hit_cooldown = 0.0
	king_hit_cooldown = 0.0
