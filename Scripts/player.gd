class_name Player extends CharacterBody2D


@export var attacks: Array[Attack] = []
@export var stats : Battle_Stats
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_sprite: Sprite2D = $Weapon
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var health_bar : TextureProgressBar = $Health

var cardinal_dir : Vector2 = Vector2.DOWN
var dir : Vector2 = Vector2.ZERO
var move_speed : float = 100
var state : String = 'idle'


func _ready() -> void:
	health_bar.visible = false
	health_bar.max_value = stats.max_hp
	health_bar.value = stats.hp
	stats.hp_changed.connect(_on_hp_changed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GameManager.can_move:
		dir.x = Input.get_action_strength("right") - Input.get_action_strength("left")
		dir.y = Input.get_action_strength("down") - Input.get_action_strength("up")
		velocity = dir * move_speed
	else: 
		velocity = Vector2.ZERO
		dir = Vector2.ZERO	
	
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

func light_attack(): 
	animation_player.play(attacks[0].animation_name)
func heavy_attack(): 
	animation_player.play(attacks[1].animation_name)
	pass

func _on_hp_changed(new_hp: float) -> void:
	health_bar.value = new_hp
