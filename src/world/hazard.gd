@tool
class_name Hazard
extends Area2D
## Damaging zone for rooms. The origin is the top-left corner.
## Spikes: damage + pogoable. Pits: instant_kill, not pogoable, not drawn in game.

const SPIKE_COLOR := Color("c8c8d4")
const SPIKE_TIP_COLOR := Color("e05a5a")
const EDITOR_ZONE_COLOR := Color(0.9, 0.2, 0.2, 0.35)
const SPIKE_WIDTH := 8.0

@export var size := Vector2(16, 8):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()
@export var damage := 1
@export var instant_kill := false
@export var pogoable := true
@export var draw_spikes := true

var _shape := RectangleShape2D.new()
var _collision := CollisionShape2D.new()


func _ready() -> void:
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
	_shape.size = size
	_collision.position = size * 0.5


func _draw() -> void:
	if not draw_spikes:
		if Engine.is_editor_hint():
			draw_rect(Rect2(Vector2.ZERO, size), EDITOR_ZONE_COLOR)
		return
	var x := 0.0
	while x + SPIKE_WIDTH <= size.x:
		var tip := Vector2(x + SPIKE_WIDTH * 0.5, 0.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), tip, Vector2(x + SPIKE_WIDTH, size.y)]), SPIKE_COLOR)
		draw_rect(Rect2(tip - Vector2(0.5, 0.0), Vector2(1.0, 2.0)), SPIKE_TIP_COLOR)
		x += SPIKE_WIDTH
