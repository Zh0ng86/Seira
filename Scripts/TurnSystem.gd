class_name TurnSystem extends Node2D

var party_nodes: Array = []
var enemies: Array = []
var all_combatants : Array = []
var active_combatant = null
var timing_ring : Node

signal ui_changed
signal enemy_turn_started(combatant)

func setup(p_nodes: Array, e_nodes: Array,t_ring: Node) -> void:
	party_nodes = p_nodes
	enemies = e_nodes
	timing_ring = t_ring
	all_combatants.append_array(party_nodes)
	all_combatants.append_array(enemies)

func _process(delta: float) -> void: 
	if GameManager.battle_state == 'idle':
		_tick_ct(delta)

func _tick_ct(delta: float) -> void:
	var ready_combatants = []
	for combatant in all_combatants:
		if combatant.stats.tick(delta):
			ready_combatants.append(combatant)
	if ready_combatants.is_empty():
		return
	
	ready_combatants.sort_custom(func(a, b):
		if abs(a.stats.current_ct - b.stats.current_ct) > 0.001:
			return a.stats.current_ct > b.stats.current_ct
		return all_combatants.find(a) < all_combatants.find(b)
	)
	
	active_combatant = ready_combatants[0]
	active_combatant.stats.resetCT()
	
	GameManager.battle_state = "player_turn" if active_combatant in party_nodes else "enemy_turn"
	ui_changed.emit()
	
	_start_turn()

func _start_turn() -> void:
	if GameManager.battle_state == "enemy_turn":
		enemy_turn_started.emit(active_combatant)
	else:
		# highlight active char, wait for E/Q
		var idx = party_nodes.find(active_combatant)
		GameManager.active_index = idx
		ui_changed.emit()

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
		var min_ticks = INF
		for s in sim:
			if s.speed > 0:
				var ticks_needed = (100.0 - s.ct) / s.speed
				min_ticks = min(min_ticks, ticks_needed)
		
		if min_ticks == INF:
			break
			
		for s in sim:
			s.ct += s.speed * min_ticks
		
		#collect the 100 CT
		var batch = []
		for s in sim:
			if s.ct >= 100.0:
				batch.append(s)
		if batch.is_empty():
			break
			
		batch.sort_custom(func(a, b):
			if abs(a.ct - b.ct) > 0.001:
				return a.ct > b.ct
			return all_combatants.find(a.node) < all_combatants.find(b.node)
		)
		
		var acting = batch[0]
		acting.ct -= 100.0
		order.append(acting.node)
	return order

func remove_combatant(node: Node) -> void:
	all_combatants.erase(node)
	party_nodes.erase(node)
	enemies.erase(node)
