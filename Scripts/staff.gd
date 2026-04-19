extends Node

func use_spell(is_heavy: bool = false)->void: 
	GameManager.spell_used.emit(is_heavy)
