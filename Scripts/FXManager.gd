class_name FXManager extends Node

const FX_SCENES = {
	"Lightning": preload("res://lightning.tscn"),
	"Explosion": preload("res://explosion.tscn"),
	"Arrow_fx": preload("res://arrow_fx.tscn"),
	"Melee_fx": preload("res://melee_fx.tscn"), 
	"Heal_fx": preload("res://heal_fx.tscn")
}

@onready var arrow = $Arrow

const z : int = 5

var melee_fx : Node2D
var arr_fx : Node2D
var explosion : Node2D
var lightning : Node2D
var heal_fx : Node2D

var active_combatant_ref: Callable  # func() -> Node
var enemies_ref: Callable           # func() -> Array
var active_enemy_ref: Callable      # func() -> int

func _ready() -> void:
	GameManager.arrow_released.connect(_on_arrow_released)
	GameManager.spell_used.connect(_on_spell_used)
	GameManager.melee_fx.connect(_on_melee_used)
	GameManager.heal_fx.connect(_on_heal)

func setup(get_combatant: Callable, get_enemies: Callable, get_active_enemy: Callable) -> void:
	active_combatant_ref = get_combatant
	enemies_ref = get_enemies
	active_enemy_ref = get_active_enemy

func _on_melee_used() -> void: 
	var combatant = active_combatant_ref.call()
	if(combatant.name != "Knight" && combatant.name != "Dwarf" && combatant.name != "Lizard"):
		return
	
	var enemy = enemies_ref.call()[active_enemy_ref.call()]
	if !melee_fx:
		melee_fx = FX_SCENES["Melee_fx"].instantiate()
		melee_fx.z_index = z
		add_child(melee_fx)
		
	melee_fx.visible = true
	melee_fx.global_position = enemy.global_position
	melee_fx.play("default")
	await melee_fx.animation_finished
	melee_fx.visible = false

func _on_arrow_released(is_heavy: bool) -> void:
	var combatant = active_combatant_ref.call()
	var enemy = enemies_ref.call()[active_enemy_ref.call()]
	if(combatant.name != "Elf"):
		return
	
	var elf = combatant
	arrow.global_position = elf.arrow.global_position
	arrow.direction = elf.arrow.global_position.direction_to(enemy.global_position)
	arrow.visible = true
	arrow.released = true
	
	if !is_heavy: return
	if !arr_fx: 
		arr_fx = FX_SCENES["Arrow_fx"].instantiate()
		arr_fx.z_index = z
		add_child(arr_fx)
	
	arr_fx.visible = true
	arr_fx.global_position = elf.arrow.global_position
	arr_fx.play("default")
	await arr_fx.animation_finished
	arr_fx.visible = false

func _on_spell_used(is_heavy: bool) -> void: 	
	var enemy = enemies_ref.call()[active_enemy_ref.call()]
	var spell : Node2D
	if is_heavy:
		if !explosion: 
			explosion = FX_SCENES['Explosion'].instantiate()
			add_child(explosion)
			explosion.z_index = z
		spell = explosion
	else: 
		if !lightning: 
			lightning = FX_SCENES['Lightning'].instantiate()
			add_child(lightning)
			lightning.z_index = z
		spell = lightning
	
	spell.visible = true
	spell.global_position = enemy.global_position
	spell.play("default")
	await spell.animation_finished
	spell.visible = false

func _on_heal(char_pos: Vector2) -> void: 
	if !heal_fx:
		heal_fx = FX_SCENES['Heal_fx'].instantiate()
		add_child(heal_fx)
		heal_fx.z_index = z
	
	heal_fx.visible = true
	heal_fx.global_position = char_pos
	heal_fx.play("default")
	await heal_fx.animation_finished
	heal_fx.visible = false

func _exit_tree() -> void:
	if GameManager.arrow_released.is_connected(_on_arrow_released):
		GameManager.arrow_released.disconnect(_on_arrow_released)
	if GameManager.spell_used.is_connected(_on_spell_used):
		GameManager.spell_used.disconnect(_on_spell_used)
	if GameManager.melee_fx.is_connected(_on_melee_used):
		GameManager.melee_fx.disconnect(_on_melee_used)
	if GameManager.heal_fx.is_connected(_on_heal):
		GameManager.heal_fx.disconnect(_on_heal)
