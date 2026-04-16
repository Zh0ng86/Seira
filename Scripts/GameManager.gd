extends Node

# Overworld
var player_pos : Vector2 = Vector2.ZERO
var _overlay : ColorRect
var _canvas : CanvasLayer
var can_move : bool = true


# Combat
var party : Array = []
var active_index : int = 0
var battle_enemy : String = ""
signal arrow_released

func ready_seeder(): 
	var char1 = Battle_Stats.new()
	char1.char_name = "Knight"
	party.append(char1)
	var char2 = Battle_Stats.new()
	char2.char_name = "Wizard"
	char2.defense = 2
	party.append(char2)
	var char3 = Battle_Stats.new()
	char3.char_name = "Elf"
	char3.speed = 20
	party.append(char3)

func _ready() -> void: 
	ready_seeder()
	
	transition_canvas()

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
