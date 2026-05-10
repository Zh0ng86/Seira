class_name Wizard extends Player

var follow_up_chance : float = 0.2
var follow_up_percent : float = 0.6

func follow_up(enemy: Enemy) -> float:
	if randf() <= follow_up_chance:
		light_attack()
		var result = CombatCalc.damage(self, enemy, true, follow_up_percent)
		await animation_player.animation_finished
		return result.damage
	return 0
