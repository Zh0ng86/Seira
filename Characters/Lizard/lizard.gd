class_name Lizard extends Player

var extra_life : bool = true
var recover_percent : float = 0.3
signal on_revive

func _ready() -> void: 
	on_revive.connect(revive)
	
func revive(): 
	stats.hp = stats.max_hp * recover_percent
	GameManager.heal_fx.emit(self.position)
