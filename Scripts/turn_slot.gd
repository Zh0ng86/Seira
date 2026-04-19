extends Control

@onready var portrait: AnimatedSprite2D = $Control/Portrait
@onready var bg: TextureRect = $BG

func setup(combatant: Node) -> void:
	portrait.sprite_frames = combatant.get_node("AnimatedSprite2D").sprite_frames
	portrait.play("idle")
