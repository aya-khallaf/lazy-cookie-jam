extends Node

signal level_up_requested

const BASE_PLAYER_MAX_HEALTH = 200.0
const BASE_KING_MAX_HEALTH = 150.0
const PLAYER_DAMAGE_SOUND = preload("res://assets/grunt3.mp3")
const KING_DAMAGE_SOUND = preload("res://assets/grunt2.mp3")
const HEART_HEAL_SOUND = preload("res://assets/heal1.mp3")
const CLICK_SOUND = preload("res://assets/Click.mp3")

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

var main = null

func _process(delta: float) -> void:
	if !gameplay_started:
		return

	if get_tree().paused:
		return

	run_time += delta

	player_hit_cooldown = max(player_hit_cooldown - delta, 0.0)

	king_hit_cooldown = max(king_hit_cooldown - delta, 0.0)

	if player_health_regen > 0.0:
		heal_player(player_health_regen * delta)

	if king_health_regen > 0.0:
		heal_king(king_health_regen * delta)


func damage_player(amount: float) -> bool:
	if !gameplay_started or player_health <= 0.0 or amount <= 0.0 or player_hit_cooldown > 0.0:
		return false
	player_health = max(player_health - amount * player_damage_taken_multiplier, 0.0)
	player_hit_cooldown = 0.45
	play_player_damage_sound()
	return true

func play_player_damage_sound() -> void:
	var sound = AudioStreamPlayer.new()
	sound.stream = PLAYER_DAMAGE_SOUND
	sound.volume_db = -10.0
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	
func play_king_damage_sound() -> void:
	var sound = AudioStreamPlayer.new()
	sound.stream = KING_DAMAGE_SOUND
	sound.volume_db = -10.0
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	
func play_heart_heal_sound() -> void:
	var sound = AudioStreamPlayer.new()
	sound.stream = HEART_HEAL_SOUND
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	
func play_click_sound() -> void:
	var sound = AudioStreamPlayer.new()
	sound.stream = CLICK_SOUND
	sound.volume_db = -10.0
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func damage_king(amount: float) -> bool:
	if !gameplay_started or king_health <= 0.0 or amount <= 0.0 or king_hit_cooldown > 0.0:
		return false
	play_king_damage_sound()
	king_health = max(king_health - amount * king_damage_taken_multiplier, 0.0)
	king_hit_cooldown = 0.35
	if is_instance_valid(king_node) and king_node.has_method("wake_up"):
		king_node.wake_up(4.0)
	return true


func heal_player(amount: float) -> void:
	if player_health <= 0.0 or amount <= 0.0:
		return

	var previous_health = player_health
	player_health = min(player_health + amount, player_max_health)

	play_heart_heal_sound()

func heal_king(amount: float) -> void:
	if king_health <= 0.0 or amount <= 0.0:
		return
	king_health = min(king_health + amount, king_max_health)


func add_xp(amount: float) -> void:
	if !gameplay_started or player_health <= 0.0 or king_health <= 0.0 or amount <= 0.0:
		return
	xp += amount * xp_gain_multiplier
	var previous_pending = pending_level_ups
	while xp >= max(xp_to_next_level, 1.0):
		xp -= max(xp_to_next_level, 1.0)
		_level_up()
	if pending_level_ups > previous_pending:
		level_up_requested.emit()


func _level_up() -> void:
	level += 1
	var levels_above_one = float(level - 1)
	xp_to_next_level = round(20.0 + levels_above_one * 10.0 + pow(levels_above_one, 1.35) * 2.0)
	king_max_health += 4.0
	king_health = min(king_health + 4.0, king_max_health)
	player_max_health += 3.0
	player_health = min(player_health + 6.0, player_max_health)
	player_speed_multiplier = min(player_speed_multiplier + 0.005, 1.65)
	king_speed_multiplier = min(king_speed_multiplier + 0.01, 2.5)
	pending_level_ups += 1


func get_current_enemy_level() -> int:
	return 1 + int(run_time / 30.0)


func roll_enemy_level() -> int:
	var base_level = get_current_enemy_level()

	if base_level <= 1:
		return 1

	var roll = randf()

	if roll < 0.18:
		return max(base_level - 1, 1)

	if roll < 0.80:
		return base_level

	if roll < 0.97:
		return base_level + 1

	return base_level + 2


func get_upgrade_choices() -> Array:
	var available = ["sword_damage", "player_health", "king_health"]
	var capped = {
		"attack_speed": attack_speed_multiplier < 3.0,
		"player_speed": player_speed_multiplier < 1.65,
		"king_speed": king_speed_multiplier < 2.5,
		"king_regen": king_health_regen < 6.0,
		"heart_healing": heart_heal_amount < 95.0,
		"xp_gain": xp_gain_multiplier < 3.0,
		"magnet": pickup_range_multiplier < 3.0,
		"sword_size": sword_size_multiplier < sword_size_max,
		"swing_arc": swing_arc_bonus < swing_arc_bonus_max,
		"sword_crit": sword_crit_chance < 0.40,
		"sword_crit_damage": sword_crit_chance > 0.0 and sword_crit_multiplier < 3.0,
		"sword_knockback": sword_knockback_multiplier < 2.0,
		"player_regen": player_health_regen < 4.0,
		"player_armor": player_damage_taken_multiplier > 0.50,
		"king_armor": king_damage_taken_multiplier > 0.50,
		"heart_luck": heart_drop_chance_bonus < 0.20
	}
	for upgrade_id in capped:
		if capped[upgrade_id]:
			available.append(upgrade_id)
	if !fireball_enabled:
		available.append("fireball_unlock")
	else:
		available.append("fireball_damage")
		if fireball_cooldown > 0.35:
			available.append("fireball_rate")
		if fireball_projectiles < 5:
			available.append("fireball_volley")
		if fireball_pierce < 4:
			available.append("fireball_pierce")
	if !orbit_sword_enabled:
		available.append("orbit_sword_unlock")
	else:
		available.append("orbit_sword_damage")
		if orbit_sword_count < 4:
			available.append("orbit_sword_count")
		if orbit_sword_speed < 3.5:
			available.append("orbit_sword_speed")
		if orbit_sword_radius < 150.0:
			available.append("orbit_sword_radius")
	if !shockwave_enabled:
		available.append("shockwave_unlock")
	else:
		available.append("shockwave_damage")
		if shockwave_cooldown > 1.8:
			available.append("shockwave_rate")
		if shockwave_radius < 270.0:
			available.append("shockwave_radius")
	if !lightning_enabled:
		available.append("lightning_unlock")
	else:
		available.append("lightning_damage")
		if lightning_cooldown > 0.8:
			available.append("lightning_rate")
		if lightning_chains < 6:
			available.append("lightning_chains")
		if lightning_range < 460.0:
			available.append("lightning_range")
	var offence = []
	var support = []
	var unlocks = []
	for upgrade_id in available:
		if upgrade_id.ends_with("_unlock"):
			unlocks.append(upgrade_id)
		if _is_weapon_upgrade(upgrade_id):
			offence.append(upgrade_id)
		else:
			support.append(upgrade_id)
	var choices = []
	var first_pool = offence
	if level <= 3 and !fireball_enabled and !orbit_sword_enabled and !shockwave_enabled and !lightning_enabled:
		first_pool = unlocks
	var first = _pick_weighted_upgrade(first_pool)
	choices.append(first)
	available.erase(first)
	var recovery = []
	if player_health < player_max_health * 0.45:
		recovery.append("player_health")
	if king_health < king_max_health * 0.45:
		recovery.append("king_health")
	var second = _pick_weighted_upgrade(recovery if !recovery.is_empty() else support)
	choices.append(second)
	available.erase(second)
	choices.append(_pick_weighted_upgrade(available))
	choices.shuffle()
	return choices


func _is_weapon_upgrade(upgrade_id: String) -> bool:
	return upgrade_id == "attack_speed" or upgrade_id == "swing_arc" or upgrade_id.begins_with("sword_") or upgrade_id.begins_with("fireball_") or upgrade_id.begins_with("orbit_sword_") or upgrade_id.begins_with("shockwave_") or upgrade_id.begins_with("lightning_")


func _pick_weighted_upgrade(pool: Array) -> String:
	var weighted = []
	for upgrade_id in pool:
		var weight = 1
		if _is_weapon_upgrade(upgrade_id) and !upgrade_id.ends_with("_unlock"):
			weight = 3
		if upgrade_id == "sword_crit_damage" and sword_crit_chance < 0.16:
			weight = 1
		for i in range(weight):
			weighted.append(upgrade_id)
	return str(weighted.pick_random()) if !weighted.is_empty() else "sword_damage"


func get_upgrade_text(upgrade_id: String) -> String:
	match upgrade_id:
		"sword_damage":
			return "SHARPENED STEEL\nDamage +%d" % int(max(10.0, round(weapon_damage * 0.22)))

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
			return "ROYAL FORTITUDE\nKing max health +30 and heal 30"

		"king_armor":
			return "ROYAL ARMOUR\nKing takes 10% less damage"

		"heart_healing":
			return "BIG HEART\nHearts heal king +15 HP and you +7.5 HP"

		"heart_luck":
			return "LUCKY HEART\nEnemies drop hearts 4% more often"

		"xp_gain":
			return "QUICK LEARNER\nXP gained +20%"

		"magnet":
			return "MAGNETISM\nPickup range +35%"

		"fireball_unlock":
			return "FIREBALL\nUnlock automatic fireballs"

		"fireball_damage":
			return "HOTTER FLAMES\nDamage +%d" % int(max(15.0, round(fireball_damage * 0.22)))

		"fireball_rate":
			return "RAPID FLAME\nFireball cooldown -15%"

		"fireball_volley":
			return "FLAME VOLLEY\nFire one additional fireball"

		"fireball_pierce":
			return "PIERCING FLAME\nFireballs pierce one more enemy"

		"orbit_sword_unlock":
			return "SHORT SWORD\nA sword begins orbiting you"

		"orbit_sword_damage":
			return "SHARP GUARD\nDamage +%d" % int(max(8.0, round(orbit_sword_damage * 0.22)))

		"orbit_sword_count":
			return "MORE STEEL\nAdd another orbiting sword"

		"orbit_sword_speed":
			return "BLADE STORM\nOrbiting swords spin 18% faster"

		"orbit_sword_radius":
			return "WIDER GUARD\nOrbiting swords move 10px further out"

		"shockwave_unlock":
			return "ROYAL SHOCKWAVE\nPeriodically blast nearby enemies"

		"shockwave_damage":
			return "HEAVY SHOCK\nDamage +%d" % int(max(18.0, round(shockwave_damage * 0.22)))

		"shockwave_rate":
			return "RAPID SHOCK\nShockwave cooldown -15%"

		"shockwave_radius":
			return "WIDER SHOCK\nShockwave radius +25"

		"lightning_unlock":
			return "CHAIN LIGHTNING\nLightning automatically strikes enemies"

		"lightning_damage":
			return "HIGH VOLTAGE\nDamage +%d" % int(max(15.0, round(lightning_damage * 0.22)))

		"lightning_rate":
			return "STORM CALLER\nLightning cooldown -15%"

		"lightning_chains":
			return "FORKED LIGHTNING\nLightning jumps to +1 enemy"

		"lightning_range":
			return "LONG ARC\nLightning range +40"

	return "UNKNOWN"


func apply_upgrade(upgrade_id: String) -> void:
	play_click_sound()
	var previous_damage = weapon_damage
	var previous_fireball_damage = fireball_damage
	var previous_orbit_damage = orbit_sword_damage
	var previous_shockwave_damage = shockwave_damage
	var previous_lightning_damage = lightning_damage
	match upgrade_id:
		"sword_damage":
			weapon_damage += max(10.0, round(weapon_damage * 0.22))
			last_upgrade_text = "Sword Damage +%d" % int(weapon_damage - previous_damage)

		"attack_speed":
			attack_speed_multiplier = min(attack_speed_multiplier + 0.18, 3.0)
			last_upgrade_text = "Sword Attack Speed +18%"

		"sword_size":
			sword_size_multiplier = min(sword_size_multiplier + 0.07, sword_size_max)

			last_upgrade_text = "Sword Size +7%"

		"swing_arc":
			swing_arc_bonus = min(swing_arc_bonus + 15.0, swing_arc_bonus_max)

			last_upgrade_text = "Swing Area +15 Degrees"

		"sword_crit":
			sword_crit_chance = min(sword_crit_chance + 0.08, 0.40)

			last_upgrade_text = "Critical Chance +8%"

		"sword_crit_damage":
			sword_crit_multiplier = min(sword_crit_multiplier + 0.25, 3.0)

			last_upgrade_text = "Critical Damage +25%"

		"sword_knockback":
			sword_knockback_multiplier = min(sword_knockback_multiplier + 0.20, 2.0)

			last_upgrade_text = "Sword Knockback +20%"

		"player_health":
			player_max_health += 25.0
			player_health += 25.0

			player_health = min(player_health, player_max_health)

			last_upgrade_text = "Player Max Health +25"

		"player_regen":
			player_health_regen = min(player_health_regen + 0.5, 4.0)

			last_upgrade_text = "Player Regen +0.5 HP/s"

		"player_armor":
			player_damage_taken_multiplier = max(player_damage_taken_multiplier * 0.92, 0.50)

			last_upgrade_text = "Player Damage Taken -8%"

		"player_speed":
			player_speed_multiplier = min(player_speed_multiplier + 0.08, 1.65)
			last_upgrade_text = "Movement Speed +8%"

		"king_regen":
			king_health_regen = min(king_health_regen + 0.75, 6.0)
			last_upgrade_text = "King Regen +0.75 HP/s"

		"king_speed":
			king_speed_multiplier = min(king_speed_multiplier + 0.15, 2.5)
			last_upgrade_text = "King Speed +15%"

		"king_health":
			king_max_health += 30.0
			king_health += 30.0

			last_upgrade_text = "King Max Health +30"

		"king_armor":
			king_damage_taken_multiplier = max(king_damage_taken_multiplier * 0.90, 0.50)

			last_upgrade_text = "King Damage Taken -10%"

		"heart_healing":
			heart_heal_amount = min(heart_heal_amount + 15.0, 95.0)
			last_upgrade_text = "Heart Healing +15"

		"heart_luck":
			heart_drop_chance_bonus = min(heart_drop_chance_bonus + 0.04, 0.20)

			last_upgrade_text = "Heart Drop Chance +4%"

		"xp_gain":
			xp_gain_multiplier = min(xp_gain_multiplier + 0.20, 3.0)
			last_upgrade_text = "XP Gain +20%"

		"magnet":
			pickup_range_multiplier = min(pickup_range_multiplier + 0.35, 3.0)
			last_upgrade_text = "Pickup Range +35%"

		"fireball_unlock":
			fireball_enabled = true
			last_upgrade_text = "Fireball Unlocked"

		"fireball_damage":
			fireball_damage += max(15.0, round(fireball_damage * 0.22))
			fireball_size_multiplier = min(fireball_size_multiplier + 0.06, 1.6)
			last_upgrade_text = "Fireball Damage +%d" % int(fireball_damage - previous_fireball_damage)

		"fireball_rate":
			fireball_cooldown = max(fireball_cooldown * 0.85, 0.35)

			last_upgrade_text = "Fireball Rate +15%"

		"fireball_volley":
			fireball_projectiles = min(fireball_projectiles + 1, 5)

			last_upgrade_text = "Additional Fireball"

		"fireball_pierce":
			fireball_pierce = min(fireball_pierce + 1, 4)

			last_upgrade_text = "Fireball Pierce +1"

		"orbit_sword_unlock":
			orbit_sword_enabled = true
			orbit_sword_count = 1
			last_upgrade_text = "Short Sword Unlocked"

		"orbit_sword_damage":
			orbit_sword_damage += max(8.0, round(orbit_sword_damage * 0.22))
			last_upgrade_text = "Orbit Sword Damage +%d" % int(orbit_sword_damage - previous_orbit_damage)

		"orbit_sword_count":
			orbit_sword_count = min(orbit_sword_count + 1, 4)

			last_upgrade_text = "Additional Orbit Sword"

		"orbit_sword_speed":
			orbit_sword_speed = min(orbit_sword_speed * 1.18, 3.5)

			last_upgrade_text = "Orbit Sword Speed +18%"

		"orbit_sword_radius":
			orbit_sword_radius = min(orbit_sword_radius + 10.0, 150.0)

			last_upgrade_text = "Orbit Radius +10"

		"shockwave_unlock":
			shockwave_enabled = true
			last_upgrade_text = "Royal Shockwave Unlocked"

		"shockwave_damage":
			shockwave_damage += max(18.0, round(shockwave_damage * 0.22))
			last_upgrade_text = "Shockwave Damage +%d" % int(shockwave_damage - previous_shockwave_damage)

		"shockwave_rate":
			shockwave_cooldown = max(shockwave_cooldown * 0.85, 1.8)

			last_upgrade_text = "Shockwave Cooldown -15%"

		"shockwave_radius":
			shockwave_radius = min(shockwave_radius + 25.0, 270.0)

			last_upgrade_text = "Shockwave Radius +25"

		"lightning_unlock":
			lightning_enabled = true
			last_upgrade_text = "Chain Lightning Unlocked"

		"lightning_damage":
			lightning_damage += max(15.0, round(lightning_damage * 0.22))
			last_upgrade_text = "Lightning Damage +%d" % int(lightning_damage - previous_lightning_damage)

		"lightning_rate":
			lightning_cooldown = max(lightning_cooldown * 0.85, 0.8)

			last_upgrade_text = "Lightning Cooldown -15%"

		"lightning_chains":
			lightning_chains = min(lightning_chains + 1, 6)

			last_upgrade_text = "Lightning Chains +1"

		"lightning_range":
			lightning_range = min(lightning_range + 40.0, 460.0)

			last_upgrade_text = "Lightning Range +40"


func reset_run_progress() -> void:
	gameplay_started = false
	player_node = null
	king_node = null

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
