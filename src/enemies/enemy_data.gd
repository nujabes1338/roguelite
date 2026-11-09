class_name EnemyData
extends Resource
## Per-enemy numbers and art. Values live in res://data/enemies/*.tres.
## Units: pixels and seconds, relative to the enemy's feet. Positive y is down.

@export var sprite_frames: SpriteFrames
## Centre of the 32x32 cell relative to the feet (the cell's pivot is its bottom centre).
@export var sprite_offset := Vector2.ZERO
## Hurtbox for the sword and the pogo. Its top edge is the pogo surface.
@export var hurtbox_size := Vector2.ZERO
## Hurtbox centre relative to the feet.
@export var hurtbox_offset := Vector2.ZERO
## How long the hurt frame and flash show after a hit.
@export var hurt_time := 0.0
@export var hurt_flash_color := Color.WHITE
