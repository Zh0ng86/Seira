extends Node2D

const CHAR_SCENES = {
	"Knight": preload("res://knight.tscn"),
	"Wizard": preload("res://wizard.tscn"),
	"Dwarf": preload("res://dwarf.tscn"),
	"Elf": preload("res://elf.tscn")
}

const FX_SCENES = {
	"Lightning": preload("res://lightning.tscn"),
	"Explosion": preload("res://explosion.tscn"),
	"Arrow_fx": preload("res://arrow_fx.tscn"),
	"Melee_fx": preload("res://melee_fx.tscn")
}

const ENEMY_SCENES = {
	"gremlin": preload("res://gremlin.tscn"),
	"goblin": preload("res://goblin.tscn"),
	"shaman": preload("res://shaman.tscn")
}

const TURN_SLOT_ENEMY = preload("res://UI/turn_bar_enemy.tscn")
const TURN_SLOT_CHARACTER = preload("res://UI/turn_bar_character.tscn")
const TURN_SLOT_FIRST = preload("res://UI/turn_bar_first.tscn")

#UI
@onready var enemy_spawns : Node2D = $EnemySpawns
@onready var char_spawns : Node2D = $CharSpawns
@onready var char_highlight : AnimatedSprite2D = $CharHighlight
@onready var enemy_highlight : AnimatedSprite2D = $EnemyHighlight
#Info Container
@onready var info_rect : NinePatchRect = $CanvasLayer/InfoRect
@onready var info_name = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Head/Name
@onready var level_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Head/Level
@onready var hp_bar = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Hp/VBoxContainer/Bar
@onready var hp_value = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Hp/VBoxContainer/Value
@onready var attack_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row1/Attack
@onready var defense_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row1/Defense
@onready var precision_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row2/Precision
@onready var speed_label = $CanvasLayer/InfoRect/MarginContainer/InfoContainer/Stats/Row2/Speed
@onready var lightAtk_btn : TextureButton = $CanvasLayer/LightAtkButton
@onready var heavyAtk_btn : TextureButton = $CanvasLayer/HeavyAtkButton
@onready var turn_order_container : HBoxContainer = $CanvasLayer/TurnOrder
@onready var timing_ring_neutral: Sprite2D = $TimingRingNeutral  # moving ring
@onready var timing_ring_target: Sprite2D = $TimingRingTarget
@onready var dmg_label : Label = $DamageLabel

@onready var arrow = $Arrow

var party_nodes : Array
var char_spawn_points : Array
var enemies : Array = []
var active_enemy : int = 0
var enemy_spawn_points : Array
var show_menu : bool = false
var state : String = "idle"
var all_combatants : Array = []
var active_combatant = null

var ORDER_NUM : int = 5
var def_constant : int = 50
var crit_constant: int = 100
var dur_constant : int = 50
var dodge_constant: int = 50
var dodge_base : float = 0.3
var crit_mult : float = 1.5
var crit_rate : float = 0.10
var lightAtk_mult : float = 1
var heavyAtk_mult : float = 1.5

var timing_ring : Control
var timing_active : bool = false
var ring_tween : Tween
var ring_radius : float = 0.0
const RING_START_SCALE: float = 3.5   # how big the moving ring starts
const RING_TARGET_SCALE: float = 1  
const RING_DURATION: float = 0.7
const PERFECT_TOLERANCE: float = 0.05  # scale units around 1.0 = perfect
const GOOD_TOLERANCE: float = 0.2
const OK_TOLERANCE: float = 0.5
var _pending_timing_callback : Callable
signal timing_ring_done

var melee_fx : Node2D
var arr_fx : Node2D
var explosion : Node2D
var lightning : Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	on_ready()
	spawn_characters()
	spawn_enemies()
	all_combatants.append_array(party_nodes)
	all_combatants.append_array(enemies)
	
	refresh_turn_order_ui()
	update_ui()

func _draw():
	for node in party_nodes:
		draw_circle(node.global_position, 3.0, Color.GREEN)
	#for point in char_spawn_points:
		#draw_circle(point.global_position, 3.0, Color.RED)
	draw_circle(enemy_highlight.global_position, 3.0, Color.RED)
	
func _process(delta: float) -> void:
	queue_redraw()
	if state == "idle":
		_tick_ct(delta)

func _input(event):
	if timing_active:
		if event.is_action_pressed("timing"):
			_resolve_timing()
			return

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

#TURN SYSTEM
func _tick_ct(delta: float) -> void:
	for combatant in all_combatants:
		if combatant.stats.tick(delta):
			active_combatant = combatant
			state = "player_turn" if combatant in party_nodes else "enemy_turn"
			combatant.stats.resetCT()
			update_ui()
			_start_turn()
			return
func _start_turn() -> void:
	if state == "enemy_turn":
		_do_enemy_turn()
	else:
		# highlight active char, wait for E/Q
		var idx = party_nodes.find(active_combatant)
		GameManager.active_index = idx
		update_ui()
func _do_enemy_turn() -> void:
	state = "fight"
	# pick a random living party member to attack
	var target = party_nodes.pick_random()
	var original = active_combatant.global_position
	
	var move_tween = create_tween()
	move_tween.tween_property(active_combatant, "global_position",
		target.global_position + Vector2(20, 0), 0.6).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await move_tween.finished
	
	start_timing_ring(target, true, func(mult: float):
		char_hit(target, mult)
	)
	await timing_ring_done
	#if target.state == "hit":
		#print('wait')
		#await target.animated_sprite.animation_finished
	
	
	var return_tween = create_tween()
	#return_tween.tween_interval(0.3)
	return_tween.tween_property(active_combatant, "global_position", original, 0.3)
	await return_tween.finished
	state = "idle"
	refresh_turn_order_ui()
	update_ui()
func get_turn_order(steps: int = 5) -> Array:
	#simulation
	var sim: Array = []
	for c in all_combatants:
		sim.append({
			"node": c,
			"ct": c.stats.current_ct,
			"speed": c.stats.speed
		})
	
	var order: Array = []
	while order.size() < steps:
		# find minimum ticks needed for next turn
		var min_ticks = INF
		for s in sim:
			var ticks_needed = (100.0 - s.ct) / s.speed
			min_ticks = min(min_ticks, ticks_needed)
		
		# advance all CTs by that amount
		for s in sim:
			s.ct += s.speed * min_ticks
		
		# collect everyone who hit 100 (could be ties)
		for s in sim:
			if s.ct >= 100.0:
				s.ct -= 100.0
				order.append(s.node)
	return order
func refresh_turn_order_ui() -> void:
	# clear old slots
	for child in turn_order_container.get_children():
		child.queue_free()
	var order = get_turn_order(ORDER_NUM)
	
	for i in range(ORDER_NUM):
		var slot 
		if i == 0: 
			slot = TURN_SLOT_FIRST.instantiate()
		elif order[i] in party_nodes: 
			slot = TURN_SLOT_CHARACTER.instantiate()
		else: 
			slot = TURN_SLOT_ENEMY.instantiate()
		
		turn_order_container.add_child(slot)
		slot.setup(order[i])

#Attack 
func start_timing_ring(target, is_light: bool, on_complete: Callable):
	_pending_timing_callback = on_complete
	timing_active = true

	var rand_target_scale = randf_range(RING_TARGET_SCALE, RING_START_SCALE)
	timing_ring_neutral.global_position = target.global_position
	timing_ring_target.global_position = target.global_position
	
	timing_ring_neutral.visible = true
	timing_ring_target.visible = true
	timing_ring_neutral.scale = Vector2.ONE * RING_START_SCALE
	timing_ring_target.scale = Vector2.ONE * rand_target_scale

	if ring_tween:
		ring_tween.kill()
	ring_tween = create_tween()
	ring_tween.set_ease(Tween.EASE_IN)
	ring_tween.set_trans(Tween.TRANS_QUAD)
	
	var ring_dur = RING_DURATION * 1 if is_light else RING_DURATION * 0.8
	ring_dur += active_combatant.stats.precision / (active_combatant.stats.precision + dur_constant)
	ring_tween.tween_property(timing_ring_neutral, "scale",
		Vector2.ONE * rand_target_scale * 0.1, ring_dur)
	ring_tween.tween_callback(func():
		# Player did nothing — auto-miss
		if timing_active:
			_resolve_timing()
	)
func _resolve_timing():
	if not timing_active:
		return
	timing_active = false
	ring_tween.kill()

	var current_scale = timing_ring_neutral.scale.x
	var target_scale = timing_ring_target.scale.x
	var diff = abs(current_scale - target_scale)

	var mult: float
	if diff <= target_scale * PERFECT_TOLERANCE:
		mult = 1.0
	elif diff <= target_scale *  GOOD_TOLERANCE:
		mult = 0.8
	elif diff <= target_scale *  OK_TOLERANCE:
		mult = 0.6
	else:
		mult = 0.0

	timing_ring_neutral.visible = false
	timing_ring_target.visible = false

	_pending_timing_callback.call(mult)
	timing_ring_done.emit()
func attack(is_light: bool):
	if state != "player_turn":
		return
	state = "fight"
	var character = active_combatant
	var original_pos = character.global_position
	var target_pos = enemies[active_enemy].global_position + Vector2(-20, 0)
	
	if character.name != "Elf" && character.name != "Wizard":
		var move_tween = create_tween()
		move_tween.tween_property(character, "global_position", target_pos, 0.6).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		await move_tween.finished
	
	var tween = create_tween()
	tween.tween_callback(func():
		start_timing_ring(enemies[active_enemy], is_light, func(mult: float):
			if is_light:
				character.light_attack()
			else:
				character.heavy_attack()
			if(character.name == "Elf" || character.name == "Wizard"):
				await active_combatant.animation_player.animation_finished
			damage(is_light, mult)
		)
	)
	if enemies[active_enemy].animated_sprite.animation == "hit":
		await enemies[active_enemy].animated_sprite.animation_finished
	else: 
		await character.animation_player.animation_finished
	
	if(character.name != "Elf" && character.name != "Wizard"):
		var move_tween = create_tween()
		move_tween.tween_property(character, "global_position", original_pos, 0.3)
		await move_tween.finished
		
	state = "idle"
	refresh_turn_order_ui()
	update_ui()
func damage(is_light: bool, mult: float):
	var character = active_combatant
	
	var char_atk_dmg : int
	if(is_light):
		char_atk_dmg = lightAtk_mult * mult * character.stats.attack
	else:
		char_atk_dmg = heavyAtk_mult * mult * character.stats.attack
	
	var crit_chance : float = crit_rate + (character.stats.precision / float(character.stats.precision + crit_constant)) 
	print(crit_chance)
	
	var label_scale = Vector2(mult, mult)
	var crit = false
	if randf() <= crit_chance * mult: 
		char_atk_dmg *= crit_mult
		label_scale *= 1.2
		crit = true
	
	var enemy_stats = enemies[active_enemy].stats
	var damage_reduction = enemy_stats.defense / (enemy_stats.defense + def_constant)
	var damage = char_atk_dmg * (1 - damage_reduction)
	
	show_damage_label(enemies[active_enemy], damage, label_scale, mult, crit)
	enemy_stats.hp -= damage
	if mult != 0 && enemy_stats.hp > 0: 
		enemies[active_enemy].hit = true
		await enemies[active_enemy].animated_sprite.animation_finished
		enemies[active_enemy].hit = false
	
	if enemy_stats.hp <= 0:
		remove_combatant(enemies[active_enemy])
func char_hit(target, mult: float):
	var dodge_chance = (dodge_base + (target.stats.speed /float(target.stats.speed + dodge_constant))) * mult
	if randf() <= dodge_chance:
		show_damage_label(active_combatant, 0, Vector2(1,1), 0, false)
		return
	
	var crit = randf() <= crit_rate
	var dmg = active_combatant.stats.attack * 1.5 if crit else active_combatant.stats.attack
	var label_scale = Vector2(0.8,0.8) if !crit else Vector2(1,1)
	show_damage_label(target, dmg, label_scale, 1, crit)
	target.stats.hp -= dmg
	target.state = "hit"
	await target.animated_sprite.animation_finished
	target.state = 'idle'
	if target.stats.hp <= 0:
		remove_combatant(target)
func show_damage_label(target, damage: int, label_scale: Vector2, multiplier: float, crit: bool) -> void:
	var tween = create_tween()
	
	# Random offset close to the enemy
	var rand_offset = Vector2(randf_range(-15, 15), randf_range(-20, -5))
	dmg_label.global_position = target.global_position + rand_offset
	
	if multiplier <= 0:
		dmg_label.scale = Vector2(0.8, 0.8)
		dmg_label.text = "MISS!"
		dmg_label.modulate = Color(0.8, 0.8, 0.8, 1.0) # grey for miss
	else:
		dmg_label.scale = label_scale
		dmg_label.text = "%d" % damage
		
		# Color based on multiplier
		if crit: 
			dmg_label.modulate = Color(0.995, 0.121, 0.111, 1.0) 
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

func update_ui():
	var char_name = GameManager.get_active_char()
	if state == "idle" || state == "player_turn":
		char_highlight.visible = true
		enemy_highlight.visible = true
	else:
		char_highlight.visible = false
		enemy_highlight.visible = false
		show_menu = false
	
	if active_combatant:
		var active_char_node = active_combatant
		char_highlight.position = active_char_node.position
		char_highlight.position.y -= 25
		var active_enemy_node = enemies[active_enemy]
		enemy_highlight.position = active_enemy_node.global_position
	
	if show_menu:
		info_rect.visible = true
	else:
		info_rect.visible = false
	
	var char = party_nodes[GameManager.active_index].stats
	info_name.text = char_name
	hp_bar.max_value = char.max_hp
	hp_bar.value = char.hp
	hp_value.text = "%d / %d" % [char.hp, char.max_hp]
	attack_label.text = "Atk: %d" % char.attack
	defense_label.text = "Def: %d" % char.defense
	precision_label.text = "Prc: %d" % char.precision
	speed_label.text = "Spd: %d" % char.speed

func remove_combatant(node: Node) -> void:
	all_combatants.erase(node)
	party_nodes.erase(node)
	enemies.erase(node)
	node.queue_free()
	refresh_turn_order_ui()
func spawn_characters():
	for i in GameManager.party.size():
		var char_name = GameManager.party[i]
		if char_name in CHAR_SCENES:
			var char_scene = CHAR_SCENES[char_name]
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
		enemy.health_bar.visible = true
		enemies.append(enemy)
	
	for i in range(1, enemy_spawn_points.size()):
		if randf() < 0.5:  # 50% chance per spawn point
			var random_key = ENEMY_SCENES.keys().pick_random()
			var extra_enemy = ENEMY_SCENES[random_key].instantiate()
			extra_enemy.global_position = enemy_spawn_points[i].global_position
			add_child(extra_enemy)
			extra_enemy.health_bar.visible = true
			enemies.append(extra_enemy)
func next_enemy():
	active_enemy = (active_enemy + 1) % enemies.size()

func _on_melee_used() -> void: 
	if(active_combatant.name != "Knight" && active_combatant.name != "Dwarf"):
		return
	
	var enemy = enemies[active_enemy]
	if !melee_fx:
		melee_fx = FX_SCENES["Melee_fx"].instantiate()
		add_child(melee_fx)
		
	melee_fx.visible = true
	melee_fx.global_position = enemy.global_position
	melee_fx.play("default")
	await melee_fx.animation_finished
	melee_fx.visible = false
func _on_arrow_released(is_heavy: bool) -> void:
	if(active_combatant.name != "Elf"):
		return
	
	var elf = active_combatant
	arrow.global_position = elf.arrow.global_position
	arrow.direction = elf.arrow.global_position.direction_to(enemies[active_enemy].global_position)
	arrow.visible = true
	arrow.released = true
	
	if !is_heavy: return
	if !arr_fx: 
		arr_fx = FX_SCENES["Arrow_fx"].instantiate()
		add_child(arr_fx)
	
	arr_fx.visible = true
	arr_fx.global_position = elf.arrow.global_position
	arr_fx.play("default")
	await arr_fx.animation_finished
	arr_fx.visible = false
func _on_spell_used(is_heavy: bool) -> void: 
	if(active_combatant.name != "Wizard"):
		return
	
	var enemy = enemies[active_enemy]
	var spell : Node2D
	if is_heavy:
		if !explosion: 
			explosion = FX_SCENES['Explosion'].instantiate()
			add_child(explosion)
		spell = explosion
	else: 
		if !lightning: 
			lightning = FX_SCENES['Lightning'].instantiate()
			add_child(lightning)
		spell = lightning
	
	spell.visible = true
	spell.global_position = enemy.global_position
	spell.play("default")
	await spell.animation_finished
	spell.visible = false

func on_ready() -> void:
	GameManager.can_move = false
	char_spawn_points = char_spawns.get_children()
	enemy_spawn_points = enemy_spawns.get_children()
	char_highlight.play("default")
	enemy_highlight.play("default")
	GameManager.arrow_released.connect(_on_arrow_released)
	GameManager.spell_used.connect(_on_spell_used)
	GameManager.melee_fx.connect(_on_melee_used)
	
	lightAtk_btn.pressed.connect(attack.bind(true))
	heavyAtk_btn.pressed.connect(attack.bind(false))
