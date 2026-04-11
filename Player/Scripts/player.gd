class_name Player extends CharacterBody2D

var cardinal_dir : Vector2 = Vector2.DOWN
var dir : Vector2 = Vector2.ZERO
var move_speed : float = 100
var state : String = 'idle'

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	dir.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	dir.y = Input.get_action_strength("down") - Input.get_action_strength("up")
	
	velocity = dir * move_speed
	
	animator()
	pass
	
func _physics_process(delta) -> void:
	move_and_slide()
	GameManager.player_pos = global_position

func animator() -> void: 
	if velocity.length() > 0: 
		animated_sprite.play('run')
	else: 
		animated_sprite.play("idle")
		
	if dir.x > 0:
		animated_sprite.flip_h = false
	elif dir.x < 0: 
		animated_sprite.flip_h = true 
