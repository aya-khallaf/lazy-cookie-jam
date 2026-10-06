extends Node

signal level_up_requested

const BASE_PLAYER_MAX_HEALTH = 100.0
const BASE_KING_MAX_HEALTH = 100.0

var player_node = null
var king_node = null

var gameplay_started = false

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
var sword_size_max = 1.35

var swing_arc_bonus = 0.0
var swing_arc_bonus_max = 75.0

var sword_crit_chance = 0.0
var sword_crit_multiplier = 2.0
var sword_knockback_multiplier = 1.0

var player_health_regen = 0.0
var player_damage_taken_multiplier = 1.0

var king_health_regen = 0.0
var king_damage_taken_multiplier = 1.0

var player_speed_multiplier = 1.0
var king_speed_multiplier = 1.0

var xp_gain_multiplier = 1.0
var pickup_range_multiplier = 1.0

var heart_heal_amount = 20.0
var heart_drop_chance_bonus = 0.0

var fireball_enabled = false
var fireball_damage = 40.0
var fireball_cooldown = 1.6
var fireball_speed = 700.0
var fireball_size_multiplier = 1.0
var fireball_projectiles = 1
var fireball_pierce = 0

var orbit_sword_enabled = false
var orbit_sword_count = 1
var orbit_sword_damage = 18.0
var orbit_sword_speed = 1.8
var orbit_sword_radius = 110.0

var shockwave_enabled = false
var shockwave_damage = 30.0
var shockwave_cooldown = 4.5
var shockwave_radius = 170.0

var lightning_enabled = false
var lightning_damage = 35.0
var lightning_cooldown = 2.7
var lightning_chains = 2
var lightning_range = 300.0

var player_hit_cooldown = 0.0
var king_hit_cooldown = 0.0


func _process(delta: float) -> void:
	if !gameplay_started:
		return

	if get_tree().paused:
		return

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


func damage_player(amount: float) -> bool:
	if player_hit_cooldown > 0.0:
		return false

	var final_damage = (
		amount *
		player_damage_taken_multiplier
	)

	player_health -= final_damage

	player_health = max(
		player_health,
		0.0
	)

	player_hit_cooldown = 0.35

	return true


func damage_king(amount: float) -> bool:
	if king_hit_cooldown > 0.0:
		return false

	var final_damage = (
		amount *
		king_damage_taken_multiplier
	)

	king_health -= final_damage

	king_health = max(
		king_health,
		0.0
	)

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
		xp_to_next_level * 1.18 + 4.0
	)

	king_max_health += 4.0
	king_health += 4.0

	king_health = min(
		king_health,
		king_max_health
	)

	player_speed_multiplier += 0.005
	king_speed_multiplier += 0.01

	pending_level_ups += 1

	level_up_requested.emit()


func get_current_enemy_level() -> int:
	return 1 + int(
		run_time / 30.0
	)


func roll_enemy_level() -> int:
	var base_level = get_current_enemy_level()

	if base_level <= 1:
		return 1

	var roll = randf()

	if roll < 0.18:
		return max(
			base_level - 1,
			1
		)

	if roll < 0.80:
		return base_level

	if roll < 0.97:
		return base_level + 1

	return base_level + 2


func get_upgrade_choices() -> Array:
	var available_upgrades = [
		"sword_damage",
		"attack_speed",
		"player_health",
		"player_speed",
		"king_health",
		"king_speed",
		"king_regen",
		"heart_healing",
		"xp_gain",
		"magnet"
	]

	if sword_size_multiplier < sword_size_max:
		available_upgrades.append(
			"sword_size"
		)

	if swing_arc_bonus < swing_arc_bonus_max:
		available_upgrades.append(
			"swing_arc"
		)

	if sword_crit_chance < 0.40:
		available_upgrades.append(
			"sword_crit"
		)

	if sword_crit_multiplier < 3.0:
		available_upgrades.append(
			"sword_crit_damage"
		)

	if sword_knockback_multiplier < 2.0:
		available_upgrades.append(
			"sword_knockback"
		)

	if player_health_regen < 4.0:
		available_upgrades.append(
			"player_regen"
		)

	if player_damage_taken_multiplier > 0.55:
		available_upgrades.append(
			"player_armor"
		)

	if king_damage_taken_multiplier > 0.55:
		available_upgrades.append(
			"king_armor"
		)

	if heart_drop_chance_bonus < 0.20:
		available_upgrades.append(
			"heart_luck"
		)

	if !fireball_enabled:
		available_upgrades.append(
			"fireball_unlock"
		)

	else:
		available_upgrades.append(
			"fireball_damage"
		)

		if fireball_cooldown > 0.4:
			available_upgrades.append(
				"fireball_rate"
			)

		if fireball_projectiles < 5:
			available_upgrades.append(
				"fireball_volley"
			)

		if fireball_pierce < 4:
			available_upgrades.append(
				"fireball_pierce"
			)

	if !orbit_sword_enabled:
		available_upgrades.append(
			"orbit_sword_unlock"
		)

	else:
		available_upgrades.append(
			"orbit_sword_damage"
		)

		if orbit_sword_count < 4:
			available_upgrades.append(
				"orbit_sword_count"
			)

		if orbit_sword_speed < 3.5:
			available_upgrades.append(
				"orbit_sword_speed"
			)

		if orbit_sword_radius < 150.0:
			available_upgrades.append(
				"orbit_sword_radius"
			)

	if !shockwave_enabled:
		available_upgrades.append(
			"shockwave_unlock"
		)

	else:
		available_upgrades.append(
			"shockwave_damage"
		)

		if shockwave_cooldown > 2.0:
			available_upgrades.append(
				"shockwave_rate"
			)

		if shockwave_radius < 260.0:
			available_upgrades.append(
				"shockwave_radius"
			)

	if !lightning_enabled:
		available_upgrades.append(
			"lightning_unlock"
		)

	else:
		available_upgrades.append(
			"lightning_damage"
		)

		if lightning_cooldown > 0.9:
			available_upgrades.append(
				"lightning_rate"
			)

		if lightning_chains < 6:
			available_upgrades.append(
				"lightning_chains"
			)

		if lightning_range < 450.0:
			available_upgrades.append(
				"lightning_range"
			)

	var choices = []

	while (
		choices.size() < 3
		and
		!available_upgrades.is_empty()
	):
		var index = randi_range(
			0,
			available_upgrades.size() - 1
		)

		choices.append(
			available_upgrades[index]
		)

		available_upgrades.remove_at(
			index
		)

	return choices


func get_upgrade_text(upgrade_id: String) -> String:
	match upgrade_id:
		"sword_damage":
			return "SHARPENED STEEL\nSword damage +10"

		"attack_speed":
			return "QUICK HANDS\nSword attack speed +18%"

		"sword_size":
			return "LONGER BLADE\nSword size +7%"

		"swing_arc":
			return "WIDE SWING\nSwing area +15 degrees"

		"sword_crit":
			return "DEADLY EDGE\nCritical chance +8%"

		"sword_crit_damage":
			return "BRUTAL EDGE\nCritical damage +25%"

		"sword_knockback":
			return "HEAVY STRIKES\nSword knockback +20%"

		"player_health":
			return "BODYGUARD'S VIGOR\nMax health +25 and heal 25"

		"player_regen":
			return "SECOND WIND\nRegenerate 0.5 HP/s"

		"player_armor":
			return "PLATE ARMOUR\nTake 8% less damage"

		"player_speed":
			return "LIGHT FEET\nMovement speed +8%"

		"king_regen":
			return "ROYAL REST\nKing regeneration +0.75 HP/s"

		"king_speed":
			return "MOVE YOUR MAJESTY\nKing speed +15%"

		"king_health":
			return "ROYAL FORTITUDE\nKing max health +30"

		"king_armor":
			return "ROYAL ARMOUR\nKing takes 10% less damage"

		"heart_healing":
			return "BIG HEART\nHearts heal king +15 HP"

		"heart_luck":
			return "LUCKY HEART\nEnemies drop hearts 4% more often"

		"xp_gain":
			return "QUICK LEARNER\nXP gained +20%"

		"magnet":
			return "MAGNETISM\nPickup range +35%"

		"fireball_unlock":
			return "FIREBALL\nUnlock automatic fireballs"

		"fireball_damage":
			return "HOTTER FLAMES\nFireball damage +15"

		"fireball_rate":
			return "RAPID FLAME\nFireballs fire 15% faster"

		"fireball_volley":
			return "FLAME VOLLEY\nFire one additional fireball"

		"fireball_pierce":
			return "PIERCING FLAME\nFireballs pierce one more enemy"

		"orbit_sword_unlock":
			return "SHORT SWORD\nA sword begins orbiting you"

		"orbit_sword_damage":
			return "SHARP GUARD\nOrbiting sword damage +8"

		"orbit_sword_count":
			return "MORE STEEL\nAdd another orbiting sword"

		"orbit_sword_speed":
			return "BLADE STORM\nOrbiting swords spin 18% faster"

		"orbit_sword_radius":
			return "WIDER GUARD\nOrbiting swords move 10px further out"

		"shockwave_unlock":
			return "ROYAL SHOCKWAVE\nPeriodically blast nearby enemies"

		"shockwave_damage":
			return "HEAVY SHOCK\nShockwave damage +18"

		"shockwave_rate":
			return "RAPID SHOCK\nShockwave cooldown -15%"

		"shockwave_radius":
			return "WIDER SHOCK\nShockwave radius +25"

		"lightning_unlock":
			return "CHAIN LIGHTNING\nLightning automatically strikes enemies"

		"lightning_damage":
			return "HIGH VOLTAGE\nLightning damage +15"

		"lightning_rate":
			return "STORM CALLER\nLightning cooldown -15%"

		"lightning_chains":
			return "FORKED LIGHTNING\nLightning jumps to +1 enemy"

		"lightning_range":
			return "LONG ARC\nLightning range +40"

	return "UNKNOWN"


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"sword_damage":
			weapon_damage += 10.0
			last_upgrade_text = "Sword Damage +10"

		"attack_speed":
			attack_speed_multiplier += 0.18
			last_upgrade_text = "Sword Attack Speed +18%"

		"sword_size":
			sword_size_multiplier = min(
				sword_size_multiplier + 0.07,
				sword_size_max
			)

			last_upgrade_text = "Sword Size +7%"

		"swing_arc":
			swing_arc_bonus = min(
				swing_arc_bonus + 15.0,
				swing_arc_bonus_max
			)

			last_upgrade_text = "Swing Area +15 Degrees"

		"sword_crit":
			sword_crit_chance = min(
				sword_crit_chance + 0.08,
				0.40
			)

			last_upgrade_text = "Critical Chance +8%"

		"sword_crit_damage":
			sword_crit_multiplier = min(
				sword_crit_multiplier + 0.25,
				3.0
			)

			last_upgrade_text = "Critical Damage +25%"

		"sword_knockback":
			sword_knockback_multiplier = min(
				sword_knockback_multiplier + 0.20,
				2.0
			)

			last_upgrade_text = "Sword Knockback +20%"

		"player_health":
			player_max_health += 25.0
			player_health += 25.0

			player_health = min(
				player_health,
				player_max_health
			)

			last_upgrade_text = "Player Max Health +25"

		"player_regen":
			player_health_regen = min(
				player_health_regen + 0.5,
				4.0
			)

			last_upgrade_text = "Player Regen +0.5 HP/s"

		"player_armor":
			player_damage_taken_multiplier = max(
				player_damage_taken_multiplier * 0.92,
				0.50
			)

			last_upgrade_text = "Player Damage Taken -8%"

		"player_speed":
			player_speed_multiplier += 0.08
			last_upgrade_text = "Movement Speed +8%"

		"king_regen":
			king_health_regen += 0.75
			last_upgrade_text = "King Regen +0.75 HP/s"

		"king_speed":
			king_speed_multiplier += 0.15
			last_upgrade_text = "King Speed +15%"

		"king_health":
			king_max_health += 30.0
			king_health += 30.0

			last_upgrade_text = "King Max Health +30"

		"king_armor":
			king_damage_taken_multiplier = max(
				king_damage_taken_multiplier * 0.90,
				0.50
			)

			last_upgrade_text = "King Damage Taken -10%"

		"heart_healing":
			heart_heal_amount += 15.0
			last_upgrade_text = "Heart Healing +15"

		"heart_luck":
			heart_drop_chance_bonus = min(
				heart_drop_chance_bonus + 0.04,
				0.20
			)

			last_upgrade_text = "Heart Drop Chance +4%"

		"xp_gain":
			xp_gain_multiplier += 0.20
			last_upgrade_text = "XP Gain +20%"

		"magnet":
			pickup_range_multiplier += 0.35
			last_upgrade_text = "Pickup Range +35%"

		"fireball_unlock":
			fireball_enabled = true
			last_upgrade_text = "Fireball Unlocked"

		"fireball_damage":
			fireball_damage += 15.0
			fireball_size_multiplier += 0.06
			last_upgrade_text = "Fireball Damage +15"

		"fireball_rate":
			fireball_cooldown = max(
				fireball_cooldown * 0.85,
				0.35
			)

			last_upgrade_text = "Fireball Rate +15%"

		"fireball_volley":
			fireball_projectiles = min(
				fireball_projectiles + 1,
				5
			)

			last_upgrade_text = "Additional Fireball"

		"fireball_pierce":
			fireball_pierce = min(
				fireball_pierce + 1,
				4
			)

			last_upgrade_text = "Fireball Pierce +1"

		"orbit_sword_unlock":
			orbit_sword_enabled = true
			orbit_sword_count = 1
			last_upgrade_text = "Short Sword Unlocked"

		"orbit_sword_damage":
			orbit_sword_damage += 8.0
			last_upgrade_text = "Orbit Sword Damage +8"

		"orbit_sword_count":
			orbit_sword_count = min(
				orbit_sword_count + 1,
				4
			)

			last_upgrade_text = "Additional Orbit Sword"

		"orbit_sword_speed":
			orbit_sword_speed = min(
				orbit_sword_speed * 1.18,
				3.5
			)

			last_upgrade_text = "Orbit Sword Speed +18%"

		"orbit_sword_radius":
			orbit_sword_radius = min(
				orbit_sword_radius + 10.0,
				150.0
			)

			last_upgrade_text = "Orbit Radius +10"

		"shockwave_unlock":
			shockwave_enabled = true
			last_upgrade_text = "Royal Shockwave Unlocked"

		"shockwave_damage":
			shockwave_damage += 18.0
			last_upgrade_text = "Shockwave Damage +18"

		"shockwave_rate":
			shockwave_cooldown = max(
				shockwave_cooldown * 0.85,
				1.8
			)

			last_upgrade_text = "Shockwave Cooldown -15%"

		"shockwave_radius":
			shockwave_radius = min(
				shockwave_radius + 25.0,
				270.0
			)

			last_upgrade_text = "Shockwave Radius +25"

		"lightning_unlock":
			lightning_enabled = true
			last_upgrade_text = "Chain Lightning Unlocked"

		"lightning_damage":
			lightning_damage += 15.0
			last_upgrade_text = "Lightning Damage +15"

		"lightning_rate":
			lightning_cooldown = max(
				lightning_cooldown * 0.85,
				0.8
			)

			last_upgrade_text = "Lightning Cooldown -15%"

		"lightning_chains":
			lightning_chains = min(
				lightning_chains + 1,
				6
			)

			last_upgrade_text = "Lightning Chains +1"

		"lightning_range":
			lightning_range = min(
				lightning_range + 40.0,
				460.0
			)

			last_upgrade_text = "Lightning Range +40"


func reset_run_progress() -> void:
	gameplay_started = false

	run_time = 0.0
	kills = 0

	level = 1
	xp = 0.0
	xp_to_next_level = 20.0

	pending_level_ups = 0
	last_upgrade_text = ""

	player_max_health = BASE_PLAYER_MAX_HEALTH
	player_health = player_max_health

	king_max_health = BASE_KING_MAX_HEALTH
	king_health = king_max_health

	weapon_damage = 20.0
	attack_speed_multiplier = 1.0

	sword_size_multiplier = 1.0
	swing_arc_bonus = 0.0

	sword_crit_chance = 0.0
	sword_crit_multiplier = 2.0
	sword_knockback_multiplier = 1.0

	player_health_regen = 0.0
	player_damage_taken_multiplier = 1.0

	king_health_regen = 0.0
	king_damage_taken_multiplier = 1.0

	player_speed_multiplier = 1.0
	king_speed_multiplier = 1.0

	xp_gain_multiplier = 1.0
	pickup_range_multiplier = 1.0

	heart_heal_amount = 20.0
	heart_drop_chance_bonus = 0.0

	fireball_enabled = false
	fireball_damage = 40.0
	fireball_cooldown = 1.6
	fireball_speed = 700.0
	fireball_size_multiplier = 1.0
	fireball_projectiles = 1
	fireball_pierce = 0

	orbit_sword_enabled = false
	orbit_sword_count = 1
	orbit_sword_damage = 18.0
	orbit_sword_speed = 1.8
	orbit_sword_radius = 110.0

	shockwave_enabled = false
	shockwave_damage = 30.0
	shockwave_cooldown = 4.5
	shockwave_radius = 170.0

	lightning_enabled = false
	lightning_damage = 35.0
	lightning_cooldown = 2.7
	lightning_chains = 2
	lightning_range = 300.0

	player_hit_cooldown = 0.0
	king_hit_cooldown = 0.0
