extends Node2D

const CHAR_SCENES = {
	"Knight": preload("res://knight.tscn"),
	"Wizard": preload("res://wizard.tscn")	
}

const ENEMY_SCENES = {
	"gremlin": preload("res://gremlin.tscn")
}

@onready var enemy_spawns : Node2D = $EnemySpawns
@onready var char_spawns : Node2D = $CharSpawns
@onready var highlight_rect : NinePatchRect = $HighlightRect
@onready var info_name = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Name
@onready var hp_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Hp/Value
@onready var mp_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Mana/Value
@onready var attack_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Attack/Value

var party_nodes : Array
var enemy_spawn_points : Array
var char_spawn_points : Array

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
	draw_circle(highlight_rect.global_position, 3.0, Color.RED)
	
func _process(delta: float) -> void:
	queue_redraw()

func _input(event): 
	if event.is_action_pressed("battle_right"): 
		GameManager.next_hero()
		update_ui()
	elif event.is_action_pressed("battle_left"):
		GameManager.prev_hero()
		update_ui()

func update_ui(): 
	var char = GameManager.get_active_char()
	var active_node = party_nodes[GameManager.active_index]
	highlight_rect.position.x = active_node.global_position.x - 15
	highlight_rect.position.y = active_node.global_position.y - 15
	
	info_name.text = char.char_name
	hp_label.text = "%d / %d" % [char.hp, char.max_hp]
	mp_label.text = "%d / %d" % [char.mp, char.max_mp]
	attack_label.text = "%d" % char.attack

func spawn_characters(): 
	for i in GameManager.party.size(): 
		var stats = GameManager.party[i]
		if stats.char_name in CHAR_SCENES: 
			var char_scene = CHAR_SCENES[stats.char_name]
			var char = char_scene.instantiate()
			char.global_position = char_spawn_points[i].global_position
			add_child(char)
			party_nodes.append(char)

func spawn_enemies(): 
	var enemy_key = GameManager.battle_enemy
	if enemy_key in ENEMY_SCENES: 
		var enemy_scene = ENEMY_SCENES[enemy_key]
		var enemy = enemy_scene.instantiate()
		enemy.global_position = enemy_spawn_points[0].global_position
		add_child(enemy)

func on_ready() -> void: 
	GameManager.can_move = false
	char_spawn_points = char_spawns.get_children()
	enemy_spawn_points = enemy_spawns.get_children()
