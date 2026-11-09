class_name PlayerTuning
extends Resource
## Every feel constant for the player. The values live in
## res://data/player/player_tuning.tres; the zero defaults here are deliberate
## so that the .tres stays the single source of truth.
## Units: pixels, seconds, pixels/second, pixels/second^2. Positive y is down.

@export_group("Body")
## Collision box, anchored bottom-centre at the player's feet.
@export var body_size := Vector2.ZERO
## How much smaller than the body the hazard hurtbox is, per side.
@export var hurtbox_inset := 0.0

@export_group("Run")
@export var run_speed := 0.0
@export var ground_acceleration := 0.0
## Also used to brake during the ground attack.
@export var ground_deceleration := 0.0
@export var air_acceleration := 0.0
@export var air_deceleration := 0.0

@export_group("Jump")
@export var jump_velocity := 0.0
## Gravity while moving up.
@export var rise_gravity := 0.0
## Gravity while moving down. Higher than rise_gravity for a weighty arc.
@export var fall_gravity := 0.0
@export var max_fall_speed := 0.0
## Upward speed is multiplied by this when jump is released early.
@export var jump_cut_multiplier := 0.0
@export var coyote_time := 0.0
@export var jump_buffer_time := 0.0

@export_group("Sword")
## Ground attack and jump-attack share this timing and hitbox.
@export var attack_startup := 0.0
@export var attack_active := 0.0
@export var attack_recovery := 0.0
@export var attack_hitbox_size := Vector2.ZERO
## Hitbox centre relative to the feet, for a right-facing player (x is mirrored).
@export var attack_hitbox_offset := Vector2.ZERO
@export var attack_damage := 0

@export_group("Pogo")
@export var pogo_hitbox_size := Vector2.ZERO
## Hitbox centre relative to the feet.
@export var pogo_hitbox_offset := Vector2.ZERO
@export var pogo_bounce_velocity := 0.0
@export var pogo_damage := 0

@export_group("Damage")
@export var max_hearts := 0
@export var hurt_duration := 0.0
## x is pushed away from the damage source, y is applied as-is.
@export var hurt_knockback := Vector2.ZERO
@export var invincibility_time := 0.0
@export var respawn_delay := 0.0
