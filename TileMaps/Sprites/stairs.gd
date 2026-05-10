extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		GameManager.current_floor += 1
		GameManager.transition_to(GameManager.GAME_SCENES["Dungeon"])
		print("new level")
