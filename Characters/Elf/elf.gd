class_name Elf extends Player

@onready var arrow: Sprite2D = $Arrow

#passive
var heal_chance : float = 0.2
var heal_percent : float = 0.1

signal on_hit

func _ready() -> void: 
	on_hit.connect(passive)

func passive(): 
	if randf() <= heal_chance: 
		animation_player.play("elf_passive")
		await animation_player.animation_finished
		GameManager.heal_fx.emit(self.position)
		stats.hp += heal_percent * stats.max_hp
