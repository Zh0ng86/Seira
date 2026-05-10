class_name TimingRing extends Node2D

@onready var timing_ring_neutral: Sprite2D = $TimingRingNeutral  # moving ring
@onready var timing_ring_target: Sprite2D = $TimingRingTarget

var timing_ring : Control
var ring_tween : Tween
var ring_radius : float = 0.0
var dur_constant : int = 50
const RING_START_SCALE: float = 3.5   # how big the moving ring starts
const RING_TARGET_SCALE: float = 1  
const RING_DURATION: float = 0.7
const PERFECT_TOLERANCE: float = 0.05  # scale units around 1.0 = perfect
const GOOD_TOLERANCE: float = 0.2
const OK_TOLERANCE: float = 0.5
var _pending_timing_callback : Callable

signal timing_ring_done

func start(target, combatant, is_light: bool, on_complete: Callable):
	_pending_timing_callback = on_complete
	GameManager.battle_state = "timing"

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
	if combatant:
		ring_dur += combatant.stats.precision / (combatant.stats.precision + dur_constant)
	
	ring_tween.tween_property(timing_ring_neutral, "scale", Vector2.ONE * rand_target_scale * 0.1, ring_dur)
	ring_tween.tween_callback(func():
		# Player did nothing — auto-miss
		if GameManager.battle_state == "timing":
			_resolve_timing()
	)
func _resolve_timing():
	if GameManager.battle_state != "timing":
		return
	GameManager.battle_state = "anim"
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
