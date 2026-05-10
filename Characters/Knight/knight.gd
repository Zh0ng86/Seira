class_name Knight extends Player

const COUNTER_ANIM : String = "sword_counter"
var counter_percent : float = 1
var is_counter: bool = false

func counter(enemy: Enemy): 
	is_counter = true
	animation_player.play("sword_counter")
	var result = CombatCalc.damage(self, enemy, true, counter_percent)
	await animation_player.animation_finished
	return result.damage
