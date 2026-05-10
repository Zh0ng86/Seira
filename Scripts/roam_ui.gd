class_name Roam_UI extends Node

const CHAR_TEXTURE = {
	"Knight": preload("uid://o48daa6rcp68"), 
	"Elf": preload("uid://baauxgu8urha2"),
	"Wizard": preload("uid://di4b3gv3d7wgu"),
	"Dwarf": preload("uid://bihl0q8je0d0f"),
	"Lizard": preload("uid://dmqyo6noiw8nl")
}

const ACTIVE_TEXTURE = preload("uid://d38lnyjfl57gx")
const NONACTIVE_TEXTURE = preload("uid://uxditpn58uys")


var keybind_actions = [
	"up",
	"down",
	"left",
	"right",
	"info",
	"toggle",
	"l atk",
	"h atk",
	"heal",
	"timing",
	"cancel",
	"menu"
]

@onready var panel : Panel = $CanvasLayer/Panel
@onready var audio_btn : TextureButton = $CanvasLayer/Panel/Main/Audio
@onready var keybinds_btn : TextureButton = $CanvasLayer/Panel/Main/Keybinds
@onready var back_btn : TextureButton = $CanvasLayer/Panel/Main/Back
@onready var quit_btn : TextureButton = $CanvasLayer/Panel/Main/Quit
@onready var main_group : Control = $CanvasLayer/Panel/Main
@onready var audio_group : Control = $CanvasLayer/Panel/Audio
@onready var keybinds_group : Control = $CanvasLayer/Panel/Keybinds
@onready var keybinds_error : Label = $CanvasLayer/Panel/Keybinds/Error

@onready var characters_bar : HBoxContainer = $CanvasLayer/Characters 
@onready var floor_label : Label = $CanvasLayer/Floor
@onready var info_container : NinePatchRect = $CanvasLayer/Menu
@onready var menu_floor : Label = $CanvasLayer/Menu/Floor
@onready var menu_potion_label : Label= $CanvasLayer/Menu/Potion/Value
@onready var menu_char_bar : HBoxContainer = $CanvasLayer/Menu/Characters
@onready var lvl_display : Label = $CanvasLayer/Menu/Level
@onready var exp_display : Control = $CanvasLayer/Menu/Exp
@onready var hp_display : Control = $CanvasLayer/Menu/Hp
@onready var atk_label : Label = $CanvasLayer/Menu/Stats/HBoxContainer/Atk
@onready var def_label : Label = $CanvasLayer/Menu/Stats/HBoxContainer/Def
@onready var prc_label : Label = $CanvasLayer/Menu/Stats/HBoxContainer2/Prc
@onready var spd_label : Label = $CanvasLayer/Menu/Stats/HBoxContainer2/Spd
@onready var psv_label : Label = $CanvasLayer/Menu/Passive

var master_bus_idx = 0
var music_bus_idx = -1
var fx_bus_idx = -1

var remapping_action: String = ""
var remapping_button: TextureButton = null
var is_menu : bool = false
var is_keybinding : bool = false

func _ready() -> void:
	characters_bar.visible = GameManager.can_move
	floor_label.visible = GameManager.can_move

	info_container.visible = false
	floor_label.text = "Floor: %d" % GameManager.current_floor
	menu_floor.text = "Floor: %d" % GameManager.current_floor
	menu_potion_label.text = "%d" % GameManager.heal_pot
	
	panel.visible = false
	audio_group.visible = false
	keybinds_group.visible = false
	audio_btn.pressed.connect(open_audio)
	keybinds_btn.pressed.connect(open_keybinds)
	back_btn.pressed.connect(toggle_menu)
	quit_btn.pressed.connect(GameManager.save)
	keybinds_error.text = ""
	
	for btn in keybinds_group.get_children():
		if btn is TextureButton and btn.name != "Back" and btn.name != "Reset":
			btn.pressed.connect(Callable(self, "_on_keybind_button_pressed").bind(btn))
			_sync_button_key_text(btn)
		elif btn.name == "Back": 
			btn.pressed.connect(open_menu)
		elif btn.name == "Reset":
			btn.pressed.connect(restore_default_keybinds)
	
	#audio 
	audio_group.get_child(3).pressed.connect(open_menu)
	var master_slider = audio_group.get_child(0)
	var music_slider  = audio_group.get_child(2)
	var fx_slider     = audio_group.get_child(1)
	master_bus_idx  = AudioServer.get_bus_index("Master")
	music_bus_idx = AudioServer.get_bus_index("Music")
	fx_bus_idx    = AudioServer.get_bus_index("FX")

	var master_db = ProjectSettings.get_setting("audio/master", 0.0)
	var music_db  = ProjectSettings.get_setting("audio/music",  0.0)
	var fx_db     = ProjectSettings.get_setting("audio/fx",     0.0)

	# Apply stored volumes
	AudioServer.set_bus_volume_db(master_bus_idx,  master_db)
	AudioServer.set_bus_volume_db(music_bus_idx, music_db)
	AudioServer.set_bus_volume_db(fx_bus_idx,    fx_db)

	# Sync sliders
	master_slider.value = db_to_linear(master_db)
	music_slider.value = db_to_linear(music_db)
	fx_slider.value = db_to_linear(fx_db)
	
	set_party()
	toggle_stats()

func _input(event): 
	if is_keybinding:
		if event is InputEventKey and event.pressed:
			var conflict = _is_key_conflict(event, remapping_action)
			if conflict[0]:
				var other_action = conflict[1]
				keybinds_error.text = "Conflict: " + other_action
				return 
			
			# Remove old events for this action.
			InputMap.action_erase_events(remapping_action)
			# Add the new key event.
			InputMap.action_add_event(remapping_action, event)

			# Update the button label and finish.
			_sync_button_key_text(remapping_button)
			is_keybinding = false
			remapping_button = null
			remapping_action = ""
			keybinds_error.text = ""
		return
	
	if !audio_group.visible and !keybinds_group.visible and event.is_action_pressed('menu'): 
		toggle_menu()
	if event.is_action_pressed("info"): 
		toggle_info()
	if info_container.visible:
		if event.is_action_pressed("toggle"): 
			GameManager.next_hero()
			toggle_stats()

func open_audio(): 
	main_group.visible = false
	audio_group.visible = true
	keybinds_group.visible = false

func open_keybinds():
	main_group.visible = false
	audio_group.visible = false
	keybinds_group.visible = true

func open_menu(): 
	main_group.visible = true
	audio_group.visible = false
	keybinds_group.visible = false

func toggle_menu(): 
	panel.visible = !panel.visible
	if(panel.visible):
		open_menu()
	else:
		main_group.visible = false
		audio_group.visible = false
		keybinds_group.visible = false
	
func toggle_info(): 
	info_container.visible = !info_container.visible
	toggle_stats()

func _on_slider_value_changed(type: String, value: float):
	var idx = 0
	var settings = ""

	match type:
		"master":
			idx = master_bus_idx
			settings = "audio/master"
		"music":
			idx = music_bus_idx
			settings = "audio/music"
		"fx":
			idx = fx_bus_idx
			settings = "audio/fx"
		_:
			return  # invalid type
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(idx, db)
	ProjectSettings.set_setting(settings, db)

func restore_default_keybinds():
	for action in keybind_actions:
		InputMap.action_erase_events(action)

		var entry = ProjectSettings.get("input/" + action)
		
		if entry is Dictionary and entry.has("events"):
			var events_array = entry["events"]
			if events_array is Array:
				for e in events_array:
					if e is InputEventKey:
						InputMap.action_add_event(action, e)
	refresh_keybinds()

func refresh_keybinds():
	for btn in keybinds_group.get_children():
		if btn is TextureButton and btn.name != "Back" and btn.name != "Reset":
			_sync_button_key_text(btn)
 
func _sync_button_key_text(btn: TextureButton):
	var action_name = btn.get_node("Name").text.to_lower()
	var events = InputMap.action_get_events(action_name)
	var key_text = "Unbound"
	if events.size() > 0:
		key_text = events[0].as_text().trim_suffix(" - Physical")
	
	var key_label = btn.get_node("Key")
	if key_label:
		key_label.text = key_text

func _on_keybind_button_pressed(btn: TextureButton):
	is_keybinding = true
	# Reset any pending remap before starting a new one.
	remapping_button = null
	remapping_action = ""

	remapping_button = btn
	remapping_action = btn.get_node("Name").text.to_lower()

	var key_label = btn.get_node("Key")
	if key_label:
		key_label.text = "___"

func _is_key_conflict(event: InputEventKey, for_action: String) -> Array:
	var key_code = event.physical_keycode
	var actions = InputMap.get_actions()

	for a in actions:
		# Skip the action we’re reassigning.
		if a == for_action:
			continue

		var events_for_a = InputMap.action_get_events(a)
		for e in events_for_a:
			if e is InputEventKey and e.physical_keycode == key_code:
				return [true, a]

	return [false, ""]

func set_party(): 
	var char_bar_children = characters_bar.get_children()
	var menu_char_bar_children = menu_char_bar.get_children()
	for i in range(0, GameManager.party_stats.size()):
		var textRect_main = char_bar_children[i].get_child(0)
		textRect_main.texture = CHAR_TEXTURE[GameManager.party_stats[i].char_name]
		
		var textRect_menu = menu_char_bar_children[i].get_child(0)
		textRect_menu.texture = CHAR_TEXTURE[GameManager.party_stats[i].char_name]
	
func toggle_stats(): 
	var char = GameManager.party_stats[GameManager.active_index]
	
	#change the bar 
	for i in range(0, menu_char_bar.get_children().size()):
		var bar = menu_char_bar.get_child(i)
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
	
	atk_label.text = "Attack: %d" % char.attack
	def_label.text = "Defense: %d" % char.defense
	prc_label.text = "Precision: %d" % char.precision
	spd_label.text = "Speed: %d" % char.speed
	psv_label.text = char.passive
