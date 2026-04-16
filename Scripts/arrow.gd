class_name Arrow extends Area2D

var released: bool = false
var direction: Vector2
var speed: float = 500.0

func _ready(): 
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if released:
		global_position += direction * speed * delta

func _on_body_entered(body) -> void:
	if body is Enemy:
		visible = false
		released = false
