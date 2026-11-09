@tool
class_name Hittable
extends Area2D
## Anything the player's sword or pogo can strike. Put it on the enemy_hurtbox layer.

signal struck(damage: int, source: Node2D)


func take_hit(damage: int, source: Node2D) -> void:
	struck.emit(damage, source)
