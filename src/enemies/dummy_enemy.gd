@tool
class_name DummyEnemy
extends Hittable
## Training dummy for the greybox room: never moves, never dies, never hurts.
## The origin is at its feet. Flashes when struck so hits are readable.

const BODY_COLOR := Color("b0703c")
const FLASH_COLOR := Color("fff4d0")
const EYE_COLOR := Color("101018")

@export var size := Vector2(14, 24):
	set(value):
		size = value
		_sync_shape()
		queue_redraw()
@export var flash_time := 0.12

var hits_taken := 0

var _flash_timer := 0.0
var _shape := RectangleShape2D.new()
var _collision := CollisionShape2D.new()


func _ready() -> void:
	_collision.shape = _shape
	add_child(_collision)
	_sync_shape()
	if Engine.is_editor_hint():
		return
	collision_layer = PhysicsLayers.ENEMY_HURTBOX
	collision_mask = 0
	monitoring = false


func _process(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		queue_redraw()


func take_hit(damage: int, source: Node2D) -> void:
	hits_taken += 1
	_flash_timer = flash_time
	queue_redraw()
	super(damage, source)


func _sync_shape() -> void:
	_shape.size = size
	_collision.position = Vector2(0.0, -size.y * 0.5)


func _draw() -> void:
	var color := FLASH_COLOR if _flash_timer > 0.0 else BODY_COLOR
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y), size), color)
	draw_rect(Rect2(-4.0, -size.y + 6.0, 2.0, 2.0), EYE_COLOR)
	draw_rect(Rect2(2.0, -size.y + 6.0, 2.0, 2.0), EYE_COLOR)
