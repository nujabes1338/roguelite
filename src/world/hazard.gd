@tool
class_name Hazard
extends Area2D
## Damaging zone. The origin is the top-left corner. Not drawn in game; the art
## comes from tiles (see HazardTileLayer). Pits use instant_kill and no pogo.

const EDITOR_ZONE_COLOR := Color(0.9, 0.2, 0.2, 0.35)

@export var size := Vector2(16, 16):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()
@export var damage := 1
@export var instant_kill := false
@export var pogoable := true

var _shape: RectangleShape2D
var _collision: CollisionShape2D


func _ready() -> void:
	_shape = RectangleShape2D.new()
	_collision = CollisionShape2D.new()
	_collision.shape = _shape
	add_child(_collision)
	_sync_shape()
	if Engine.is_editor_hint():
		return
	collision_layer = PhysicsLayers.HAZARD
	collision_mask = 0
	monitoring = false


func get_center() -> Vector2:
	return global_position + size * 0.5


func _sync_shape() -> void:
	if _shape == null:
		return
	_shape.size = size
	_collision.position = size * 0.5


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), EDITOR_ZONE_COLOR)
