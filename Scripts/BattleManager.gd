extends Node2D

const TURN_SLOT_ENEMY = preload("res://UI/turn_bar_enemy.tscn")
const TURN_SLOT_CHARACTER = preload("res://UI/turn_bar_character.tscn")
const TURN_SLOT_FIRST = preload("res://UI/turn_bar_first.tscn")

const CHAR_TEXTURE = {
	"Knight": preload("uid://o48daa6rcp68"), 
	"Elf": preload("uid://baauxgu8urha2"),
	"Wizard": preload("uid://di4b3gv3d7wgu"),
	"Dwarf": preload("uid://bihl0q8je0d0f"),
	"Lizard": preload("uid://dmqyo6noiw8nl")
}
const ACTIVE_TEXTURE = preload("uid://d38lnyjfl57gx")
const NONACTIVE_TEXTURE = preload("uid://uxditpn58uys")

@onready var turn_system : Node2D = $TurnSystem
@onready var timing_ring : Node2D = $TimingRing
@onready var fx_manager : Node2D = $FXManager
#UI
@onready var enemy_spawns : Node2D = $EnemySpawns
@onready var char_spawns : Node2D = $CharSpawns
@onready var char_highlight : AnimatedSprite2D = $CharHighlight
@onready var enemy_highlight : AnimatedSprite2D = $EnemyHighlight
@onready var heal_highlight: AnimatedSprite2D = $HealHighlight
@onready var turn_order_container : HBoxContainer = $CanvasLayer/Actions/TurnOrder
@onready var lightAtk_btn : TextureButton = $CanvasLayer/Actions/LightAtkButton
@onready var heavyAtk_btn : TextureButton = $CanvasLayer/Actions/HeavyAtkButton
@onready var pot_btn: TextureButton = $CanvasLayer/Actions/PotionButton
@onready var pot_label : Label = $CanvasLayer/Actions/PotionButton/Value
@onready var dmg_label : Label = $DamageLabel
#Exp status
@onready var exp_rect : NinePatchRect = $CanvasLayer/Exp
@onready var stats_rect1 : HBoxContainer = $CanvasLayer/Exp/Stats/HBoxContainer
@onready var stats_rect2 : HBoxContainer = $CanvasLayer/Exp/Stats/HBoxContainer2

var party_nodes : Array
var char_spawn_points : Array
var enemies : Array = []
var active_enemy : int = 0
var enemy_spawn_points : Array
var all_combatants : Array = []
var lvlUp_status : Array[bool] = []
var stats_inc : Array[Dictionary] = []

var ORDER_NUM : int = 5
var total_exp : int = 0

signal player_attack_done

func _ready() -> void:
	$Camera2D.make_current()
	binding()
	spawn_characters()
	spawn_enemies()
	all_combatants.append_array(party_nodes)
	all_combatants.append_array(enemies)
	
	set_party()
	exp_rect.visible = false
	
	turn_system.setup(party_nodes, enemies, timing_ring)
	turn_system.enemy_turn_started.connect(_on_enemy_turn)
	turn_system.ui_changed.connect(update_ui)
	call_deferred("_setup_fx")
	
	#Stat increase btn
	
	
	refresh_turn_order_ui()
	update_ui()

func _input(event):
	if  Input.is_key_pressed(KEY_P): 
		on_enemies_dead()
	if GameManager.can_move: 
		return
		
	if GameManager.battle_state == "timing":
		if event.is_action_pressed("timing"):
			timing_ring._resolve_timing()
			return
	elif GameManager.battle_state == "healing": 
		if event.is_action_pressed("heal"): 
			heal()
			return 
		elif event.is_action("cancel"):
			GameManager.battle_state = "player_turn"
	elif GameManager.battle_state == "fight": return
	
	
	if event.is_action_pressed("right"):
		GameManager.next_hero()
		if GameManager.battle_state == "battle_conclusion":
			exp_toggle()
	elif event.is_action_pressed("left"):
		GameManager.prev_hero()
		if GameManager.battle_state == "battle_conclusion":
			exp_toggle()
	if event.is_action_pressed("toggle"):
		next_enemy()
	
	if event.is_action_pressed("l atk"):
		player_turn(true)
	elif event.is_action_pressed("h atk"):	
		player_turn(false)
	elif event.is_action_pressed("heal"):
		GameManager.battle_state = "healing"

	update_ui()

func on_enemies_dead(): 
	GameManager.battle_state = "battle_conclusion"
	exp_gain()
	exp_rect.visible = true
	exp_toggle()
	fx_manager._exit_tree()
	
func heal():
	print("Healed: ", party_nodes[GameManager.active_index].name)
	party_nodes[GameManager.active_index].stats.hp = party_nodes[GameManager.active_index].stats.max_hp
	GameManager.heal_pot -= 1
	GameManager.battle_state = "idle"
	pot_label.text = "%d" % GameManager.heal_pot
	GameManager.heal_fx.emit(party_nodes[GameManager.active_index].position)
	
	refresh_turn_order_ui()
	update_ui()

func player_turn(is_light: bool):
	if GameManager.battle_state != "player_turn":
		return
	GameManager.battle_state = "fight"
	
	var character = turn_system.active_combatant
	var enemy = enemies[active_enemy]
	var original_pos = character.global_position
	var target_pos = enemies[active_enemy].global_position + Vector2(-20, 0)
	
	if character.name != "Elf" && character.name != "Wizard":
		var move_tween = create_tween()
		move_tween.tween_property(character, "global_position", target_pos, 0.6).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		await move_tween.finished

	timing_ring.start(enemy, character, is_light, func(mult: float):
		if is_light:
			character.light_attack()
		else:
			character.heavy_attack()
			
		var result = CombatCalc.damage(character, enemy, is_light, mult)
		await character.animation_player.animation_finished
		enemy.stats.hp -= result.damage
		show_damage_label(enemy, result.damage, mult, result.crit)

		if mult != 0 and is_instance_valid(enemy):
			enemy.hit = true
			await enemy.animated_sprite.animation_finished
			enemy.hit = false

		if enemy.stats.hp <= 0:
			remove_combatant(enemy)
		
		if character.name != "Wizard" && GameManager.party.has("Wizard") && enemy.stats.hp > 0: 
			var wizard = party_nodes.filter(func(o): return o.name == "Wizard")[0]
			var wizard_dmg = await wizard.follow_up(enemy)
			enemy.stats.hp -= wizard_dmg
			if wizard_dmg > 0:
				show_damage_label(enemy, wizard_dmg, 0.8, false)
			if enemy.stats.hp <= 0:
				remove_combatant(enemy)
		player_attack_done.emit()
	)
	
	await player_attack_done
	
	if(character.name != "Elf" && character.name != "Wizard"):
		var move_tween = create_tween()
		move_tween.tween_property(character, "global_position", original_pos, 0.3)
		await move_tween.finished
		
	refresh_turn_order_ui()
	update_ui()
	GameManager.battle_state = "idle"

func enemy_turn(enemy) -> void:
	GameManager.battle_state = "fight"
	# pick a random living party member to attack
	var target : Node2D
	if GameManager.party.has("Dwarf"):
		var dwarf = party_nodes.filter(func(o): return o.name == "Dwarf")[0]
		target = dwarf if randf() <= dwarf.aggro_chance else party_nodes.pick_random()
	else: 
		target = party_nodes.pick_random()
	var original = enemy.global_position
	
	var move_tween = create_tween()
	move_tween.tween_property(enemy, "global_position",
		target.global_position + Vector2(20, 0), 0.6).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await move_tween.finished
	
	timing_ring.start(target, target, true, func(mult: float):
		var result = CombatCalc.char_hit(enemy, target, mult)
		if result["dodged"]:
			show_damage_label(target, 0, 0, false)
			if target.name == "Knight": 
				var dmg = await target.counter(enemy)
				enemy.stats.hp -= dmg
				show_damage_label(target, dmg, 1, false)
				target.is_counter = false
			return
		
		var x = 0
		if mult >= 1: 
			x = 0.5
		elif mult >= 0: 
			x = 1
		
		show_damage_label(target, result["damage"], x, result["crit"])
		target.stats.hp -= result["damage"]
		target.state = "hit"
		if target.name == "Elf": 
			target.on_hit.emit()
		
		if is_instance_valid(target) and target.animated_sprite.sprite_frames.has_animation("hit"):
			await target.animated_sprite.animation_finished
		
		if not is_instance_valid(target):
			return
		
		target.state = 'idle'
		
		if target.stats.hp <= 0:
			if target.name == "Lizard" && target.extra_life:
				target.on_revive.emit()
			else: 
				remove_combatant(target)
	)
	await timing_ring.timing_ring_done
	if target.name == "Knight" && target.is_counter: 
		await target.animation_player.animation_finished
	
	if enemy.stats.hp <= 0: 
		remove_combatant(enemy)
		refresh_turn_order_ui()
		update_ui()
		return
	
	if is_instance_valid(target) and target.state == "hit":
		await target.animated_sprite.animation_finished
	
	var return_tween = create_tween()
	return_tween.tween_property(enemy, "global_position", original, 0.3)
	await return_tween.finished
	GameManager.battle_state = "idle"
	refresh_turn_order_ui()
	update_ui()

func show_damage_label(target, damage: int, multiplier: float, crit: bool) -> void:
	var tween = create_tween()
	
	# Random offset close to the enemy
	var rand_offset = Vector2(randf_range(-15, 15), randf_range(-20, -5))
	dmg_label.global_position = target.global_position + rand_offset
	
	if multiplier <= 0:
		dmg_label.scale = Vector2(0.8, 0.8)
		dmg_label.text = "MISS!"
		dmg_label.modulate = Color(0.8, 0.8, 0.8, 1.0) # grey for miss
	else:
		dmg_label.scale = Vector2(multiplier, multiplier)
		dmg_label.text = "%d" % damage
		
		# Color based on multiplier
		if crit: 
			dmg_label.modulate = Color(0.995, 0.121, 0.111, 1.0) 
			dmg_label.scale *= 1.2
		elif multiplier >= 1:
			dmg_label.modulate = Color(1.0, 0.4, 0.1, 1.0) 
		else:
			dmg_label.modulate = Color(1.0, 1.0, 0.3, 1.0) 
	
	# Pop in, float up, fade out
	dmg_label.visible = true
	var start_pos = dmg_label.global_position
	var end_pos = start_pos + Vector2(randf_range(-5, 5), -22)
	
	tween.set_parallel(true)
	tween.tween_property(dmg_label, "global_position", end_pos, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(func(): dmg_label.visible = false)

func exp_gain(): 
	var party = GameManager.party_stats
	for i in range(0, party.size()):
		party[i].exp += total_exp
		if party[i].exp >= party[i].exp_to_next_level():
			party[i].exp -= party[i].exp_to_next_level()
			party[i].level += 1
			lvlUp_status.append(true)
		else: 
			lvlUp_status.append(false)			

func exp_toggle(): 
	var char = GameManager.party_stats[GameManager.active_index]
	var exp_char_bar = exp_rect.get_child(0)
	var lvl_display = exp_rect.get_child(1)
	var exp_display = exp_rect.get_child(2)
	var hp_display = exp_rect.get_child(3)
	var status_display = exp_rect.get_child(6)
	
	#change the bar 
	for i in range(0, exp_char_bar.get_children().size()):
		var bar = exp_char_bar.get_child(i)
		if i != GameManager.active_index:
			bar.texture = NONACTIVE_TEXTURE
		else: 
			bar.texture = ACTIVE_TEXTURE
	
	lvl_display.text = "Level %d" % char.level
	
	var exp_value = exp_display.get_child(1)
	var exp_progressbar = exp_display.get_child(2)
	var max_exp = char.exp_to_next_level()
	exp_value.text = "%d/%d" % [char.exp, max_exp]
	exp_progressbar.max_value = max_exp
	exp_progressbar.value = char.exp
	
	var hp_value = hp_display.get_child(1)
	var hp_progressbar = hp_display.get_child(2)
	hp_value.text = "%d/%d" % [char.hp, char.max_hp]
	hp_progressbar.max_value = char.max_hp
	hp_progressbar.value = char.hp
	

	status_display.text = "Gained: %d xp" % total_exp

func update_ui():
	if enemies.size() <= 0 && !GameManager.can_move: 
		on_enemies_dead()
		return
	
	var char_name = GameManager.get_active_char()
	var char = party_nodes[GameManager.active_index]
	if GameManager.battle_state == "player_turn":
		char_highlight.visible = true
		enemy_highlight.visible = true
		heal_highlight.visible = false
	elif GameManager.battle_state == "healing":
		heal_highlight.visible = true
	else:
		char_highlight.visible = false
		enemy_highlight.visible = false
		heal_highlight.visible = false
	
	if GameManager.battle_state == "healing":
		heal_highlight.position = char.position
		heal_highlight.position.y -= 25
	elif turn_system.active_combatant in party_nodes:
		var active_char_node = turn_system.active_combatant
		char_highlight.position = active_char_node.position
		char_highlight.position.y -= 25
		var active_enemy_node = enemies[active_enemy]
		enemy_highlight.position = active_enemy_node.global_position

func refresh_turn_order_ui() -> void:
	# clear old slots
	for child in turn_order_container.get_children():
		child.queue_free()
	
	var order = turn_system.get_turn_order(ORDER_NUM)
	
	for i in range(order.size()):
		var slot 
		if i == 0: 
			slot = TURN_SLOT_FIRST.instantiate()
		elif order[i] in party_nodes: 
			slot = TURN_SLOT_CHARACTER.instantiate()
		else: 
			slot = TURN_SLOT_ENEMY.instantiate()
		
		turn_order_container.add_child(slot)
		slot.setup(order[i])

func remove_combatant(node: Node) -> void:
	turn_system.remove_combatant(node)
	all_combatants.erase(node)
	party_nodes.erase(node)
	enemies.erase(node)
	node.queue_free()
	refresh_turn_order_ui()
func spawn_characters():
	for i in GameManager.party.size():
		var char_name = GameManager.party[i]
		if char_name in Scenes.CHAR_SCENES:
			var stats = GameManager.party_stats[i]
			var char_scene = Scenes.CHAR_SCENES[char_name]
			var char = char_scene.instantiate()
			char.global_position = char_spawn_points[i].global_position
			char.stats = stats
			add_child(char)
			char.weapon_sprite.visible = true
			char.health_bar.visible = true
			char.health_bar.max_value = stats.max_hp
			char.health_bar.value = stats.hp
			char.stats.hp_changed.connect(char._on_hp_changed)
			party_nodes.append(char)
func spawn_enemies():
	var enemy_key = GameManager.battle_enemy
	if enemy_key in Scenes.ENEMY_SCENES:
		var enemy_scene = Scenes.ENEMY_SCENES[enemy_key]
		var enemy = enemy_scene.instantiate()
		enemy.global_position = enemy_spawn_points[0].global_position
		add_child(enemy)
		enemy.health_bar.visible = true
		enemies.append(enemy)
		scale_enemy_stats(enemy)
		total_exp += get_exp_reward(enemy)
	
	for i in range(1, enemy_spawn_points.size()):
		if randf() < 0.5:  # 50% chance per spawn point
			var random_key = Scenes.ENEMY_SCENES.keys().pick_random()
			var extra_enemy = Scenes.ENEMY_SCENES[random_key].instantiate()
			extra_enemy.global_position = enemy_spawn_points[i].global_position
			add_child(extra_enemy)
			extra_enemy.health_bar.visible = true
			enemies.append(extra_enemy)
			scale_enemy_stats(extra_enemy)
			total_exp += get_exp_reward(extra_enemy)

func next_enemy():
	active_enemy = (active_enemy + 1) % enemies.size()

func scale_enemy_stats(enemy: Enemy) -> void:
	var floor_num = GameManager.current_floor
	enemy.stats.max_hp = int(enemy.stats.max_hp * (1 + 0.1 * floor_num))
	enemy.stats.hp = enemy.stats.max_hp
	enemy.stats.attack = int(enemy.stats.attack * (1 + 0.1 * floor_num))
	enemy.stats.defense = int(enemy.stats.defense * (1 + 0.1 * floor_num))
	enemy.stats.precision = int(enemy.stats.precision * (1 + 0.1 * floor_num))
	enemy.stats.speed = int(enemy.stats.speed * (1 + 0.1 * floor_num))

func get_exp_reward(enemy: Enemy) -> int:
	var base_exp = (enemy.stats.max_hp * 0.5) + (enemy.stats.attack * 2) + (enemy.stats.defense * 1.5)
	var floor_bonus = 1 + (GameManager.current_floor * 0.15)
	var level_bonus = 1 + (enemy.stats.level * 0.1)
	var num_enemies_bonus = 1 + (enemies.size() * 0.05)
	return int(base_exp * floor_bonus * level_bonus * num_enemies_bonus)

func binding() -> void:
	pot_label.text = "%d" % GameManager.heal_pot
	GameManager.can_move = false
	char_spawn_points = char_spawns.get_children()
	enemy_spawn_points = enemy_spawns.get_children()
	char_highlight.play("default")
	enemy_highlight.play("default")
	heal_highlight.play('default')
	
	lightAtk_btn.pressed.connect(player_turn.bind(true))
	heavyAtk_btn.pressed.connect(player_turn.bind(false))
	pot_btn.pressed.connect(_on_pot_btn_press)

func _setup_fx() -> void:
	fx_manager.setup(
		func(): return turn_system.active_combatant,
		func(): return enemies,
		func(): return active_enemy
	)
func _on_pot_btn_press(): 
	if GameManager.battle_state == "healing":
		heal()
	else: 
		GameManager.battle_state = "healing"

func _on_enemy_turn(combatant) -> void:
	await enemy_turn(combatant)

func set_party(): 
	var exp_char_bar = exp_rect.get_child(0)
	var exp_char_bar_children = exp_char_bar.get_children()
	for i in range(0, GameManager.party_stats.size()):
		var textRect_menu = exp_char_bar_children[i].get_child(0)
		textRect_menu.texture = CHAR_TEXTURE[GameManager.party_stats[i].char_name]
