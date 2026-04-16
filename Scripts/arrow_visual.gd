extends Node

func launch_arrow()->void: 
	GameManager.arrow_released.emit()
