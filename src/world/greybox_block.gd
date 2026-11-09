@tool
class_name GreyboxBlock
extends StaticBody2D
## Solid rectangle for greybox rooms. The origin is the top-left corner.

@export var size := Vector2(16, 16):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()
@export var color := Color("5a5a6e")

var _shape := RectangleShape2D.new()
var _collision := CollisionShape2D.new()


func _ready() -> void:
	_collision.shape = _shape
	add_child(_collision)
	_sync_shape()
	if Engine.is_editor_hint():
		return
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0


func _sync_shape() -> void:
	_shape.size = size
	_collision.position = size * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 1.0)), color.lightened(0.25))
