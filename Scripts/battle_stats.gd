class_name Battle_Stats extends Resource

signal hp_changed(new_hp: float)

@export var char_name : String = ""
@export var level : int = 5
@export var max_hp : int = 100
@export var hp : int = 100 : 
	set(value):
		hp = value
		hp_changed.emit(hp)
@export var attack : int = 10
@export var defense : int = 5
@export var precision : int = 5
@export var speed : int = 10
var max_ct : int = 100
var current_ct : int = 0

func _reset_state() -> void:
	current_ct = 0

func tick(delta: float) -> bool: 
	current_ct += speed
	return current_ct >= max_ct

func resetCT(): 
	current_ct = 0
