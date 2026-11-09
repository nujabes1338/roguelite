@tool
class_name DummyEnemy
extends Hittable
## Test dummy for the test room: never moves, never dies, never hurts.
## The origin is at its feet. Shows the hurt frame with a flash when struck.

@export var data: EnemyData:
	set(value):
		data = value
		_apply_data()

var hits_taken := 0

var _hurt_timer := 0.0
var _shape: RectangleShape2D
var _collision: CollisionShape2D
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_shape = RectangleShape2D.new()
	_collision = CollisionShape2D.new()
	_collision.shape = _shape
	add_child(_collision)
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	_apply_data()
	if Engine.is_editor_hint():
		return
	collision_layer = PhysicsLayers.ENEMY_HURTBOX
	collision_mask = 0
	monitoring = false


func _process(delta: float) -> void:
	if _hurt_timer <= 0.0:
		return
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		_show_idle()


func take_hit(damage: int, source: Node2D) -> void:
	hits_taken += 1
	_hurt_timer = data.hurt_time
	_sprite.play(&"hurt")
	_sprite.modulate = data.hurt_flash_color
	super(damage, source)


func _apply_data() -> void:
	if data == null or _sprite == null:
		return
	_shape.size = data.hurtbox_size
	_collision.position = data.hurtbox_offset
	_sprite.sprite_frames = data.sprite_frames
	_sprite.position = data.sprite_offset
	_show_idle()


func _show_idle() -> void:
	_sprite.modulate = Color.WHITE
	_sprite.play(&"idle")
