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
