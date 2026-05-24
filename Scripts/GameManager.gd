extends Node

const CHAR_STATS = {
	"Knight": preload("res://Characters/Knight/knight_stats.tres"),
	"Elf": preload("res://Characters/Elf/elf_stats.tres"),
	"Wizard": preload("res://Characters/Wizard/wizard_stats.tres"),
	"Dwarf": preload("res://Characters/Dwarf/dwarf_stats.tres"),
	"Lizard": preload("res://Characters/Lizard/lizard_stats.tres")
}

const GAME_SCENES = {
	"Dungeon": "res://dungeon.tscn", 
	"Battle": "res://battle.tscn"
}

# Overworld
var roaming_char : String = "Knight"
var player_pos : Vector2 = Vector2.ZERO
var _overlay : ColorRect
var _canvas : CanvasLayer
var can_move : bool = true
var heal_pot : int = 5
var current_floor : int = 1

# Combat
var _dungeon_scene : Node = null
var _battle_scene : Node = null
var party : Array[String] = []
var party_stats : Array[Battle_Stats] = []
var active_index : int = 0
var battle_enemy : String = ""
var battle_state : String = "idle"
signal melee_fx()
signal arrow_released(is_heavy: bool)
signal spell_used(is_heavy: bool)
signal heal_fx(char_pos: Vector2)

var _battle_loading : bool = false

func ready_seeder(): 
	party.append("Elf")
	party.append("Knight")
	party.append("Wizard")
	
	for member in party:
		var stats = CHAR_STATS[member].duplicate()
		party_stats.append(stats)

func _ready() -> void: 
	ready_seeder()
	
	transition_canvas()

func save(): 
	print("save")

func transition_canvas(): 
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)
	
	_overlay = ColorRect.new()
	_overlay.color = Color(0,0,0,0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)

func transition_to(scene_path: String) -> void:
	var tween = create_tween()
	tween.tween_property(_overlay, 'color:a', 1.0, 0.4)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	fade_in()
	
func fade_in() -> void: 
	var tween = create_tween()
	tween.tween_property(_overlay, 'color:a', 0.0, 0.4)

func get_active_char(): 
	return party[active_index]

func next_hero():
	active_index = (active_index + 1) % party.size()

func prev_hero():
	active_index = (active_index - 1 + party.size()) % party.size() 

func start_battle(enemy_name: String):
	if _battle_loading:
		return
	_battle_loading = true
	battle_enemy = enemy_name
	can_move = false
	battle_state = "loading"
	
	call_deferred("_do_start_battle")

func on_battle_finished() -> void:     
	battle_state = "loading" 
	
	_battle_scene.process_mode = Node.PROCESS_MODE_DISABLED
	_battle_scene.visible = false
	
	get_tree().root.remove_child(_battle_scene)
	get_tree().current_scene = _dungeon_scene
	_dungeon_scene.process_mode = Node.PROCESS_MODE_INHERIT
	_dungeon_scene.visible = true
	
	_battle_scene.call_deferred("free")
	_battle_scene = null
	_dungeon_scene = null
	
	
	_battle_loading = false
	can_move = true
	
func _do_start_battle() -> void:
	_dungeon_scene = get_tree().current_scene
	_dungeon_scene.process_mode = Node.PROCESS_MODE_DISABLED
	_dungeon_scene.visible = false
	
	_battle_scene = load(GAME_SCENES["Battle"]).instantiate()
	get_tree().root.add_child(_battle_scene)
	get_tree().current_scene = _battle_scene
	
	battle_state = "idle"
