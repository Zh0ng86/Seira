extends Node2D

const CHAR_SCENES = {
	"Knight": preload("res://knight.tscn"),
	"Wizard": preload("res://wizard.tscn"),
	"Dwarf": preload("res://dwarf.tscn"),
	"Elf": preload("res://elf.tscn")
}

const ENEMY_SCENES = {
	"gremlin": preload("res://gremlin.tscn"),
	#"goblin": preload("res://goblin.tscn"),
	#"shaman": preload("res://shaman.tscn")
}

@onready var enemy_spawns : Node2D = $EnemySpawns
@onready var char_spawns : Node2D = $CharSpawns
@onready var char_highlight : AnimatedSprite2D = $CharHighlight
@onready var enemy_highlight : AnimatedSprite2D = $EnemyHighlight
@onready var info_rect : NinePatchRect = $CanvasLayer/InfoRect
@onready var info_name = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Head/Name
@onready var level_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Head/Level
@onready var hp_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Hp/Value
@onready var attack_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row1/Attack
@onready var defense_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row1/Defense
@onready var precision_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row2/Precision
@onready var speed_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row2/Speed
@onready var arrow = $Arrow

var party_nodes : Array
var char_spawn_points : Array
var enemies : Array = []
var active_enemy : int = 0
var enemy_spawn_points : Array
var show_menu : bool = false
var state : String = "idle"

var def_constant : int = 50
var lightAtk_mult : float = 1
var heavyAtk_mult : float = 1.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	on_ready()
	spawn_characters()
	spawn_enemies()
	update_ui()

func _draw():
	for node in party_nodes:
		draw_circle(node.global_position, 3.0, Color.GREEN)
	#for point in char_spawn_points:
		#draw_circle(point.global_position, 3.0, Color.RED)
	draw_circle(enemy_highlight.global_position, 3.0, Color.RED)
	
func _process(delta: float) -> void:
	queue_redraw()

func _input(event):
	if state == "fight":
		return
	
	if event.is_action_pressed("battle_info"):
		show_menu = !show_menu
	if event.is_action_pressed("battle_right"):
		GameManager.next_hero()
	elif event.is_action_pressed("battle_left"):
		GameManager.prev_hero()
	if event.is_action_pressed("toggle_enemy"):
		next_enemy()
	
	if event.is_action_pressed("light_attack"):
		attack(true)
	elif event.is_action_pressed("heavy_attack"):
		attack(false)

	update_ui()

func attack(is_light: bool):
	state = "fight"
	var character = party_nodes[GameManager.active_index]
	if(character.name != "Elf" && character.name != "Wizard"):
		var original_pos = character.global_position
		var target_pos = enemies[active_enemy].global_position + Vector2(-20, 0)
		
		var tween = create_tween()
		tween.tween_property(character, "global_position", target_pos, 1)
		tween.tween_callback(func():
			var char_atk_dmg : int
			if(is_light):
				char_atk_dmg = lightAtk_mult * character.stats.attack
				character.light_attack()
			else:
				
				
				char_atk_dmg = heavyAtk_mult * character.stats.attack
				character.heavy_attack()
			
			var enemy_stats = enemies[active_enemy].stats
			var damage_reduction = enemy_stats.defense / (enemy_stats.defense + def_constant)
			var damage = char_atk_dmg * (1 - damage_reduction)
			enemy_stats.hp -= damage
		)
		tween.tween_interval(1)
		tween.tween_property(character, "global_position", original_pos, 0.3)
		tween.tween_callback(func(): 
			state = "idle" 
			update_ui()
		)

	#if(is_light):
		#party_nodes[GameManager.active_index].light_attack()
	#else:
		#party_nodes[GameManager.active_index].heavy_attack()
	

func _on_arrow_released() -> void:
	if(party_nodes[GameManager.active_index].name != "Elf"):
		return
	
	var elf = party_nodes[GameManager.active_index]
	arrow.global_position = elf.arrow.global_position
	arrow.direction = elf.arrow.global_position.direction_to(enemies[active_enemy].global_position)
	arrow.visible = true
	arrow.released = true

func update_ui():
	if state == "idle":
		char_highlight.visible = true
		enemy_highlight.visible = true
	else:
		char_highlight.visible = false
		enemy_highlight.visible = false
		show_menu = false
	
	var char = GameManager.get_active_char()
	var active_char_node = party_nodes[GameManager.active_index]
	char_highlight.position = active_char_node.position
	char_highlight.position.y -= 25
	
	var active_enemy_node = enemies[active_enemy]
	enemy_highlight.position = active_enemy_node.global_position
	
	if show_menu:
		info_rect.visible = true
	else:
		info_rect.visible = false
	
	info_name.text = char.char_name
	hp_label.max_value = char.max_hp
	hp_label.value = char.hp
	attack_label.text = "Atk: %d" % char.attack
	defense_label.text = "Def: %d" % char.defense
	precision_label.text = "Prc: %d" % char.precision
	speed_label.text = "Spd: %d" % char.speed

func spawn_characters():
	for i in GameManager.party.size():
		var stats = GameManager.party[i]
		if stats.char_name in CHAR_SCENES:
			var char_scene = CHAR_SCENES[stats.char_name]
			var char = char_scene.instantiate()
			char.global_position = char_spawn_points[i].global_position
			add_child(char)
			char.health_bar.visible = true
			party_nodes.append(char)

func spawn_enemies():
	var enemy_key = GameManager.battle_enemy
	if enemy_key in ENEMY_SCENES:
		var enemy_scene = ENEMY_SCENES[enemy_key]
		var enemy = enemy_scene.instantiate()
		enemy.global_position = enemy_spawn_points[0].global_position
		add_child(enemy)
		enemies.append(enemy)
	
	for i in range(1, enemy_spawn_points.size()):
		if randf() < 0.5:  # 50% chance per spawn point
			var random_key = ENEMY_SCENES.keys().pick_random()
			var extra_enemy = ENEMY_SCENES[random_key].instantiate()
			extra_enemy.global_position = enemy_spawn_points[i].global_position
			add_child(extra_enemy)
			enemies.append(extra_enemy)

func next_enemy():
	active_enemy = (active_enemy + 1) % enemies.size()

func on_ready() -> void:
	GameManager.can_move = false
	char_spawn_points = char_spawns.get_children()
	enemy_spawn_points = enemy_spawns.get_children()
	char_highlight.play("default")
	enemy_highlight.play("default")
	GameManager.arrow_released.connect(_on_arrow_released)
	
	
