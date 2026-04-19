extends Node

func launch_arrow(is_heavy: bool = false)->void: 
	GameManager.arrow_released.emit(is_heavy)
