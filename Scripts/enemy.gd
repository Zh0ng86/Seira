class_name Enemy extends CharacterBody2D

@export var stats : Battle_Stats

@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var detectedArea : Area2D = $Area2D
@onready var health_bar : TextureProgressBar = $Health

var enemy_name : String = "enemy"
var move_speed : float = 80
var wander_timer : float = 0.0
var wander_duration : float = 2.0 + randf() * 1
var target_pos : Vector2
var noise : FastNoiseLite = FastNoiseLite.new()
var player_detected : bool = false

var smooth_speed: float = 0.0
var SMOOTH_FACTOR: float = 14.0
var current_anim: String = ""
var MIN_SPEED: float = 20.0

var WANDER_ARRIVE_DIST: float = 16.0
var IDLE_AT_POINT_MIN: float = 0.5
var IDLE_AT_POINT_MAX: float = 1.5
var idle_at_point_timer: float = 0.0
var arrived: bool = false

func _ready() -> void:
	stats = stats.duplicate()
	
	noise.seed = randi()
	noise.frequency = 0.1
	pick_new_target()
	detectedArea.body_entered.connect(_on_detection_area_body_entered)
	detectedArea.body_exited.connect(_on_detection_area_body_exited)
	animated_sprite.play("idle")
	
	health_bar.max_value = stats.max_hp
	health_bar.value = stats.hp
	stats.hp_changed.connect(_on_hp_changed)

func _physics_process(delta: float) -> void:
	var player_pos = GameManager.player_pos
	if GameManager.can_move: 
		if player_detected:
			target_pos = player_pos
			arrived = false
			wander_timer = wander_duration
		else:
			if arrived:
				# Wait out the idle pause, then pick a new point
				idle_at_point_timer -= delta
				if idle_at_point_timer <= 0:
					arrived = false
					pick_new_target()
					wander_timer = wander_duration
			else:
				wander_timer -= delta
				if wander_timer <= 0:
					pick_new_target()
					wander_timer = wander_duration
		move()
	else: 
		velocity = Vector2.ZERO
		smooth_speed = 0.0
	animator(delta)

func move() -> void:
	if player_detected:
		var dir = global_position.direction_to(target_pos)
		velocity = dir * move_speed
	elif arrived:
		velocity = Vector2.ZERO
	else:
		var dist = global_position.distance_to(target_pos)
		if dist < WANDER_ARRIVE_DIST:
			# Just arrived — start idle pause
			arrived = true
			idle_at_point_timer = randf_range(IDLE_AT_POINT_MIN, IDLE_AT_POINT_MAX)
			velocity = Vector2.ZERO
		else:
			var dir = global_position.direction_to(target_pos)
			dir = dir.rotated(
				noise.get_noise_2d(global_position.x * 0.01, Time.get_time_dict_from_system().second) * 0.3
			)
			dir += Vector2(randf() - 0.5, randf() - 0.5) * 0.2
			velocity = dir.normalized() * move_speed

	move_and_slide()
	on_collide_player()

func pick_new_target():
	target_pos = global_position + Vector2(randf_range(-150, 150), randf_range(-100, 100))

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_detected = true

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player_detected = false

func on_collide_player(): 
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player"):
			start_battle()
			return 

func start_battle(): 
	velocity = Vector2.ZERO
	GameManager.battle_enemy = enemy_name
	GameManager.transition_to("res://battle.tscn")

func animator(delta: float) -> void:
	smooth_speed = lerp(smooth_speed, velocity.length(), SMOOTH_FACTOR * delta)
	
	if smooth_speed > MIN_SPEED:
		if current_anim != "run":
			animated_sprite.play("run")
			current_anim = "run"
	else:
		if current_anim != "idle":
			animated_sprite.play("idle")
			current_anim = "idle"
			
	if !GameManager.can_move: 
		animated_sprite.flip_h = true
	elif smooth_speed > MIN_SPEED:
		if velocity.x < 0 : 
			animated_sprite.flip_h = true
		elif velocity.x > 0: 
			animated_sprite.flip_h = false

func _on_hp_changed(new_hp: float) -> void:
	health_bar.value = new_hp
