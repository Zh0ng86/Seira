class_name CombatCalc

const def_constant : int = 50
const crit_constant: int = 100
const dodge_constant: int = 50
const dodge_base : float = 0.3
const crit_mult : float = 1.5
const crit_rate : float = 0.10
const lightAtk_mult : float = 1
const heavyAtk_mult : float = 1.5

static func damage(character: Player, enemy: Enemy, is_light: bool, mult: float):	
	var char_atk_dmg : int
	if(is_light):
		char_atk_dmg = lightAtk_mult * mult * character.stats.attack
	else:
		char_atk_dmg = heavyAtk_mult * mult * character.stats.attack
	
	var crit_chance : float = crit_rate + (character.stats.precision / float(character.stats.precision + crit_constant)) 
	
	var crit = false
	if randf() <= crit_chance * mult: 
		char_atk_dmg *= crit_mult
		crit = true
	
	var damage_reduction = enemy.stats.defense / (enemy.stats.defense + def_constant)
	var damage = char_atk_dmg * (1 - damage_reduction)
	
	return { "damage": damage, "crit": crit }

static func char_hit(enemy, target, mult: float):
	var base_dodge = dodge_base + (target.stats.speed / float(target.stats.speed + dodge_constant))
	var precision_reduction = enemy.stats.precision / float(enemy.stats.precision + dodge_constant)
	var dodge_chance = (base_dodge * (1.0 - precision_reduction)) * mult
	if randf() <= dodge_chance:
		return { "dodged": true }
	
	var crit = randf() <= crit_rate
	var enemy_atk = enemy.stats.attack * 1.5 if crit else enemy.stats.attack
	var damage_reduction = target.stats.defense / (target.stats.defense + def_constant) * mult
	var dmg = enemy_atk * (1 - damage_reduction)
	
	return { "damage": dmg, "crit": crit, "dodged": false }
	
	
