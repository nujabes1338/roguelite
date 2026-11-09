class_name Player
extends CharacterBody2D
## Side-scrolling hero controller. The origin is at the feet (bottom centre).
## Every feel constant comes from [member tuning]. Only idle and run have art so
## far; other states hold the first idle frame, and the sword and pogo blades
## are drawn as placeholder rectangles.

signal state_changed(previous: State, current: State)
signal jumped(used_coyote: bool, used_buffer: bool)
signal attack_landed(target: Hittable)
signal pogo_bounced(target: Area2D)
signal damaged(hearts_left: int)
signal died
signal respawned

enum State { IDLE, RUN, JUMP, FALL, ATTACK, JUMP_ATTACK, POGO, HURT, DEAD }

const HURT_TINT := Color("ff8080")
const DEAD_TINT := Color("60606c")
const BLADE_COLOR := Color("ffe27a")
const HILT_COLOR := Color("c08a3a")
const MAX_QUERY_RESULTS := 8

@export var tuning: PlayerTuning

var state := State.IDLE
var facing := 1
var hearts := 0
var spawn_position := Vector2.ZERO

var _state_time := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _invincible_timer := 0.0
var _jump_cut_available := false
var _swing_targets: Array[Hittable] = []
var _query_shape := RectangleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	assert(tuning != null, "Player needs a PlayerTuning resource")
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD
	var body_shape := RectangleShape2D.new()
	body_shape.size = tuning.body_size
	_collision.shape = body_shape
	_collision.position = Vector2(0.0, -tuning.body_size.y * 0.5)
	_query.shape = _query_shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	spawn_position = global_position
	hearts = tuning.max_hearts


func _physics_process(delta: float) -> void:
	_state_time += delta
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
	if state != State.DEAD and Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = tuning.jump_buffer_time

	match state:
		State.IDLE, State.RUN:
			_update_grounded(delta)
		State.JUMP, State.FALL:
			_update_airborne(delta)
		State.ATTACK, State.JUMP_ATTACK:
			_update_swing(delta)
		State.POGO:
			_update_pogo(delta)
		State.HURT:
			_update_hurt(delta)
		State.DEAD:
			_update_dead()

	if state != State.DEAD:
		move_and_slide()
		_after_move()

	modulate.a = 0.35 if _invincible_timer > 0.0 and posmod(int(_invincible_timer * 15.0), 2) == 1 else 1.0
	_update_sprite()
	queue_redraw()


## Applies damage from any source at [param source_x]. Ignored while invincible.
func take_damage(amount: int, source_x: float) -> void:
	if state == State.DEAD or _invincible_timer > 0.0:
		return
	hearts = maxi(hearts - amount, 0)
	damaged.emit(hearts)
	if hearts == 0:
		_die()
		return
	var away := signf(global_position.x - source_x)
	if away == 0.0:
		away = -float(facing)
	velocity = Vector2(away * tuning.hurt_knockback.x, tuning.hurt_knockback.y)
	_invincible_timer = tuning.invincibility_time
	_jump_cut_available = false
	_set_state(State.HURT)


func is_sword_active() -> bool:
	if state != State.ATTACK and state != State.JUMP_ATTACK:
		return false
	return _state_time >= tuning.attack_startup and _state_time < tuning.attack_startup + tuning.attack_active


func _update_grounded(delta: float) -> void:
	var direction := _input_direction()
	_steer(direction, tuning.ground_acceleration, tuning.ground_deceleration, delta)
	_apply_gravity(delta)
	if _try_jump():
		return
	if Input.is_action_just_pressed("attack"):
		_start_swing(State.ATTACK)
		return
	_set_state(State.RUN if direction != 0 else State.IDLE)


func _update_airborne(delta: float) -> void:
	_steer(_input_direction(), tuning.air_acceleration, tuning.air_deceleration, delta)
	_apply_jump_cut()
	_apply_gravity(delta)
	if _try_jump():
		return
	if Input.is_action_just_pressed("attack"):
		if Input.is_action_pressed("move_down"):
			_set_state(State.POGO)
		else:
			_start_swing(State.JUMP_ATTACK)
		return
	if state == State.JUMP and velocity.y >= 0.0:
		_set_state(State.FALL)


## Ground attack and jump-attack. Committed: no steering or turning until it ends.
func _update_swing(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, tuning.ground_deceleration * delta)
	_apply_jump_cut()
	_apply_gravity(delta)
	if is_sword_active():
		_hit_with_sword()
	if _state_time >= tuning.attack_startup + tuning.attack_active + tuning.attack_recovery:
		_finish_action()


## Downward strike. Held until landing; bounces are handled after the move.
func _update_pogo(delta: float) -> void:
	_steer(_input_direction(), tuning.air_acceleration, tuning.air_deceleration, delta)
	_apply_gravity(delta)


func _update_hurt(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, tuning.ground_deceleration * delta)
	_apply_gravity(delta)
	if _state_time >= tuning.hurt_duration:
		_finish_action()


func _update_dead() -> void:
	if _state_time >= tuning.respawn_delay:
		_respawn()


func _after_move() -> void:
	var bounced := state == State.POGO and _try_pogo_bounce()
	_check_hazards(bounced)
	match state:
		State.IDLE, State.RUN:
			if not is_on_floor():
				_coyote_timer = tuning.coyote_time
				_set_state(State.FALL)
		State.JUMP, State.FALL, State.POGO:
			if is_on_floor() and not bounced:
				_land()
		State.ATTACK, State.JUMP_ATTACK, State.HURT, State.DEAD:
			pass


func _steer(direction: int, acceleration: float, deceleration: float, delta: float) -> void:
	if direction != 0:
		facing = direction
	var rate := acceleration if direction != 0 else deceleration
	velocity.x = move_toward(velocity.x, direction * tuning.run_speed, rate * delta)


func _apply_gravity(delta: float) -> void:
	var gravity := tuning.rise_gravity if velocity.y < 0.0 else tuning.fall_gravity
	velocity.y = minf(velocity.y + gravity * delta, tuning.max_fall_speed)


func _apply_jump_cut() -> void:
	if not _jump_cut_available:
		return
	if velocity.y >= 0.0:
		_jump_cut_available = false
	elif not Input.is_action_pressed("jump"):
		velocity.y *= tuning.jump_cut_multiplier
		_jump_cut_available = false


func _try_jump() -> bool:
	if _jump_buffer_timer <= 0.0:
		return false
	var grounded := is_on_floor()
	if not grounded and _coyote_timer <= 0.0:
		return false
	var used_buffer := not Input.is_action_just_pressed("jump")
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	velocity.y = -tuning.jump_velocity
	_jump_cut_available = true
	_set_state(State.JUMP)
	jumped.emit(not grounded, used_buffer)
	return true


func _land() -> void:
	if not _try_jump():
		_set_state(State.RUN if _input_direction() != 0 else State.IDLE)


## Leaves a committed action (swing or hurt) into whichever state fits now.
func _finish_action() -> void:
	if is_on_floor():
		_land()
	else:
		_set_state(State.JUMP if velocity.y < 0.0 else State.FALL)


func _start_swing(kind: State) -> void:
	_swing_targets.clear()
	_set_state(kind)


func _hit_with_sword() -> void:
	var offset := Vector2(tuning.attack_hitbox_offset.x * facing, tuning.attack_hitbox_offset.y)
	for area in _overlapping_areas(tuning.attack_hitbox_size, offset, PhysicsLayers.ENEMY_HURTBOX):
		var target := area as Hittable
		if target == null or _swing_targets.has(target):
			continue
		_swing_targets.append(target)
		target.take_hit(tuning.attack_damage, self)
		attack_landed.emit(target)


func _try_pogo_bounce() -> bool:
	if velocity.y < 0.0:
		return false
	var bounce_target: Area2D = null
	var mask := PhysicsLayers.ENEMY_HURTBOX | PhysicsLayers.HAZARD
	for area in _overlapping_areas(tuning.pogo_hitbox_size, tuning.pogo_hitbox_offset, mask):
		if area is Hittable:
			(area as Hittable).take_hit(tuning.pogo_damage, self)
			bounce_target = area
		elif area is Hazard and (area as Hazard).pogoable and bounce_target == null:
			bounce_target = area
	if bounce_target == null:
		return false
	velocity.y = -tuning.pogo_bounce_velocity
	_jump_cut_available = false
	pogo_bounced.emit(bounce_target)
	return true


func _check_hazards(pogo_bounced_this_frame: bool) -> void:
	if state == State.DEAD:
		return
	var hurtbox := tuning.body_size - Vector2.ONE * tuning.hurtbox_inset * 2.0
	var center := Vector2(0.0, -tuning.body_size.y * 0.5)
	for area in _overlapping_areas(hurtbox, center, PhysicsLayers.HAZARD):
		var hazard := area as Hazard
		if hazard == null:
			continue
		if hazard.instant_kill:
			_die()
			return
		if not pogo_bounced_this_frame:
			take_damage(hazard.damage, hazard.get_center().x)
			return


func _die() -> void:
	hearts = 0
	velocity = Vector2.ZERO
	_set_state(State.DEAD)
	died.emit()


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	hearts = tuning.max_hearts
	facing = 1
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_invincible_timer = tuning.invincibility_time
	_set_state(State.IDLE)
	respawned.emit()


func _set_state(next: State) -> void:
	if next == state:
		return
	var previous := state
	state = next
	_state_time = 0.0
	state_changed.emit(previous, next)


func _input_direction() -> int:
	return int(signf(Input.get_axis("move_left", "move_right")))


func _overlapping_areas(box_size: Vector2, local_center: Vector2, mask: int) -> Array[Area2D]:
	_query_shape.size = box_size
	_query.transform = Transform2D(0.0, global_position + local_center)
	_query.collision_mask = mask
	var found: Array[Area2D] = []
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, MAX_QUERY_RESULTS):
		var area := hit["collider"] as Area2D
		if area != null:
			found.append(area)
	return found


func _update_sprite() -> void:
	_sprite.flip_h = facing < 0
	match state:
		State.IDLE:
			_sprite.play(&"idle")
		State.RUN:
			_sprite.play(&"run")
		State.JUMP, State.FALL, State.ATTACK, State.JUMP_ATTACK, State.POGO, State.HURT, State.DEAD:
			_sprite.animation = &"idle"
			_sprite.frame = 0
			_sprite.pause()
	if state == State.HURT:
		_sprite.modulate = HURT_TINT
	elif state == State.DEAD:
		_sprite.modulate = DEAD_TINT
	else:
		_sprite.modulate = Color.WHITE


func _draw() -> void:
	if state == State.ATTACK or state == State.JUMP_ATTACK:
		var offset := Vector2(tuning.attack_hitbox_offset.x * facing, tuning.attack_hitbox_offset.y)
		if is_sword_active():
			draw_rect(_centered_rect(tuning.attack_hitbox_size, offset), BLADE_COLOR)
		else:
			draw_rect(_centered_rect(Vector2(4.0, 3.0), Vector2(tuning.body_size.x * 0.5 * facing, offset.y)), HILT_COLOR)
	elif state == State.POGO:
		draw_rect(_centered_rect(tuning.pogo_hitbox_size, tuning.pogo_hitbox_offset), BLADE_COLOR)


func _centered_rect(box_size: Vector2, center: Vector2) -> Rect2:
	return Rect2(center - box_size * 0.5, box_size)
