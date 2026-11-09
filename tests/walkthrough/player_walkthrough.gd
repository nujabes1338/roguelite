extends Node
## Scripted input pass over the greybox room. Injects keyboard and gamepad
## events through the InputMap, logs every player state transition, and quits
## with exit code 0 only if every state was reached and a pogo bounce landed
## on each test enemy.
## Run: godot --headless --path . res://tests/walkthrough/player_walkthrough.tscn

enum Device { KEYBOARD, GAMEPAD }

const TEST_ROOM := preload("res://scenes/rooms/greybox/test_room.tscn")
const KEYS := {
	&"move_left": KEY_LEFT,
	&"move_right": KEY_RIGHT,
	&"move_down": KEY_DOWN,
	&"jump": KEY_Z,
	&"attack": KEY_X,
}
const PAD_BUTTONS := {
	&"move_left": JOY_BUTTON_DPAD_LEFT,
	&"move_right": JOY_BUTTON_DPAD_RIGHT,
	&"jump": JOY_BUTTON_A,
	&"attack": JOY_BUTTON_X,
}
const DEFAULT_TIMEOUT := 240

var _player: Player
var _hopper: DummyEnemy
var _daruma: DummyEnemy
var _start_frame := 0
var _reached := {}
var _enemy_bounces := {}
var _spike_bounces := 0
var _failed := false
var _held_direction := 0


func _ready() -> void:
	Input.use_accumulated_input = false
	var room := TEST_ROOM.instantiate()
	room.set(&"show_debug_hud", true)
	add_child(room)
	_player = room.get_node("Player") as Player
	_hopper = room.get_node("Enemies/PotHopper") as DummyEnemy
	_daruma = room.get_node("Enemies/GrumbleDaruma") as DummyEnemy
	_player.state_changed.connect(_on_state_changed)
	_player.jumped.connect(_on_jumped)
	_player.attack_landed.connect(_on_attack_landed)
	_player.pogo_bounced.connect(_on_pogo_bounced)
	_player.damaged.connect(func(hearts_left: int) -> void: _log("  damaged, hearts left %d" % hearts_left))
	_player.died.connect(func() -> void: _log("  died"))
	_player.respawned.connect(func() -> void: _log("  respawned at %s, hearts %d" % [_player.global_position, _player.hearts]))
	_start_frame = Engine.get_physics_frames()
	_reached[_player.state] = true
	_log("start in %s at %s" % [_state_name(_player.state), _player.global_position])
	_run.call_deferred()


func _run() -> void:
	_section("idle at spawn")
	await _frames(20)

	_section("variable jump height: tap jump (keyboard) vs hold jump (gamepad)")
	var tap_height := await _jump_and_measure(3, Device.KEYBOARD)
	var hold_height := await _jump_and_measure(40, Device.GAMEPAD)
	_log("  apex: tap %.1f px, hold %.1f px" % [tap_height, hold_height])
	_check(hold_height > tap_height * 1.5, "holding jump should go clearly higher than a tap")

	_section("run right to the pot hopper")
	_press(&"move_right")
	await _until(func() -> bool: return _player.global_position.x >= 176.0, "reach x>=176")
	_release(&"move_right")
	await _until(_is_grounded_idle, "stop")

	_section("ground attack on the pot hopper")
	var hits_before := _hopper.hits_taken
	await _tap(&"attack")
	await _until(func() -> bool: return _player.state == Player.State.ATTACK, "attack starts")
	await _until(func() -> bool: return _player.state != Player.State.ATTACK, "attack ends")
	_check(_hopper.hits_taken > hits_before, "ground attack should hit the pot hopper")

	_section("jump-attack on the pot hopper (gamepad)")
	_press(&"jump", Device.GAMEPAD)
	await _frames(2)
	await _until(func() -> bool: return _player.velocity.y > 0.0 and _player.global_position.y >= 130.0, "descend to enemy height")
	_release(&"jump", Device.GAMEPAD)
	await _tap(&"attack", Device.GAMEPAD)
	await _until(func() -> bool: return _player.state == Player.State.JUMP_ATTACK, "jump-attack starts")
	await _until(_is_grounded_idle, "land after jump-attack")

	_section("pogo down-strike on the pot hopper (keyboard: Down + X in the air)")
	await _pogo_on(_hopper.global_position.x, 2, Device.KEYBOARD, _bounces_on.bind(_hopper))
	await _steer_until(182.0, _is_grounded_idle, "land beside the pot hopper")
	_release(&"move_down")

	_section("coyote jump: walk off the ledge, press jump a few frames late")
	_press(&"move_right")
	await _until(func() -> bool: return _player.state == Player.State.FALL, "walk off the ledge")
	await _frames(4)
	_press(&"jump")
	await _frames(2)
	await _until(func() -> bool: return _player.velocity.y >= 0.0, "reach apex")
	_release(&"jump")
	await _until(func() -> bool: return _player.is_on_floor() and _player.global_position.x >= 300.0, "land across the pit")
	_release(&"move_right")
	await _until(_is_grounded_idle, "stop")

	_section("jump buffer: press jump just before landing")
	_press(&"jump")
	await _frames(2)
	await _until(func() -> bool: return _player.velocity.y > 0.0, "reach apex")
	_release(&"jump")
	await _until(func() -> bool: return _player.global_position.y >= 146.0, "fall to 14 px above the floor")
	_press(&"jump")
	await _until(func() -> bool: return _player.state == Player.State.JUMP, "buffered jump fires on landing")
	await _frames(10)
	_release(&"jump")
	await _until(_is_grounded_idle, "land")

	_section("pogo down-strike on the grumble daruma (gamepad: stick down + X)")
	var daruma_x := _daruma.global_position.x
	await _steer_until(daruma_x, _is_grounded_idle_near.bind(daruma_x), "stand under the grumble daruma")
	await _pogo_on(daruma_x, 1, Device.GAMEPAD, _bounces_on.bind(_daruma))
	await _steer_until(304.0, _is_grounded_idle, "land left of the grumble daruma")
	_release(&"move_down", Device.GAMEPAD)

	_section("pogo down-strike on the spike strip (no damage)")
	await _steer_until(336.0, _is_grounded_idle_near.bind(336.0), "stand left of the spikes")
	var hearts_before := _player.hearts
	await _pogo_on(368.0, 1, Device.KEYBOARD, func() -> int: return _spike_bounces)
	await _steer_until(334.0, _is_grounded_idle, "land left of the spikes")
	_release(&"move_down")
	_check(_player.hearts == hearts_before, "pogo on spikes should not cost a heart")

	_section("walk into the spikes: hurt and knockback")
	_hold_direction(1)
	await _until(func() -> bool: return _player.state == Player.State.HURT, "get hurt")
	_hold_direction(0)
	await _until(_is_grounded_idle, "recover")

	_section("walk into the pit: dead, then respawn")
	_hold_direction(-1)
	await _until(func() -> bool: return _player.state == Player.State.DEAD, "die in the pit")
	_hold_direction(0)
	await _until(func() -> bool: return _player.state == Player.State.IDLE, "respawn")
	await _frames(30)

	_finish()


func _pogo_on(target_x: float, bounces: int, device: Device, counter: Callable) -> void:
	var start_count: int = counter.call()
	_press(&"jump", device)
	await _frames(2)
	await _steer_until(target_x, func() -> bool: return _player.velocity.y > -60.0, "near apex")
	_release(&"jump", device)
	_press(&"move_down", device)
	await _tap(&"attack", device)
	await _until(func() -> bool: return _player.state == Player.State.POGO, "pogo starts")
	await _steer_until(target_x, func() -> bool: return int(counter.call()) >= start_count + bounces, "%d pogo bounce(s)" % bounces)


func _jump_and_measure(hold_frames: int, device: Device) -> float:
	var start_y := _player.global_position.y
	var apex := start_y
	_press(&"jump", device)
	for i in hold_frames:
		apex = minf(apex, _player.global_position.y)
		await get_tree().physics_frame
	_release(&"jump", device)
	for i in DEFAULT_TIMEOUT:
		apex = minf(apex, _player.global_position.y)
		if _is_grounded_idle():
			return start_y - apex
		await get_tree().physics_frame
	_fail("land after measured jump")
	return 0.0


func _bounces_on(enemy: DummyEnemy) -> int:
	return _enemy_bounces.get(enemy, 0)


func _is_grounded_idle() -> bool:
	return _player.state == Player.State.IDLE and _player.is_on_floor() and _player.velocity.x == 0.0


func _is_grounded_idle_near(x: float) -> bool:
	return _is_grounded_idle() and absf(_player.global_position.x - x) <= 2.0


## Holds left/right toward [param target_x], letting go once the remaining
## distance is within braking distance so it doesn't overshoot.
func _steer_toward(target_x: float) -> void:
	var dx := target_x - _player.global_position.x
	var tuning := _player.tuning
	var braking := tuning.ground_deceleration if _player.is_on_floor() else tuning.air_deceleration
	var speed := _player.velocity.x
	var stopping_distance := speed * speed / (2.0 * braking)
	var moving_toward := signf(speed) == signf(dx)
	if absf(dx) <= 1.0 or (moving_toward and absf(dx) <= stopping_distance):
		_hold_direction(0)
	else:
		_hold_direction(int(signf(dx)))


func _steer_until(target_x: float, condition: Callable, what: String) -> void:
	for i in DEFAULT_TIMEOUT:
		if condition.call():
			_hold_direction(0)
			return
		_steer_toward(target_x)
		await get_tree().physics_frame
	_hold_direction(0)
	_fail(what)


func _hold_direction(direction: int) -> void:
	if direction == _held_direction:
		return
	if _held_direction == 1:
		_release(&"move_right")
	elif _held_direction == -1:
		_release(&"move_left")
	if direction == 1:
		_press(&"move_right")
	elif direction == -1:
		_press(&"move_left")
	_held_direction = direction


func _until(condition: Callable, what: String, timeout := DEFAULT_TIMEOUT) -> void:
	for i in timeout:
		if condition.call():
			return
		await get_tree().physics_frame
	_fail(what)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _tap(action: StringName, device := Device.KEYBOARD) -> void:
	_press(action, device)
	await get_tree().physics_frame
	_release(action, device)


func _press(action: StringName, device := Device.KEYBOARD) -> void:
	Input.parse_input_event(_make_event(action, device, true))


func _release(action: StringName, device := Device.KEYBOARD) -> void:
	Input.parse_input_event(_make_event(action, device, false))


func _make_event(action: StringName, device: Device, pressed: bool) -> InputEvent:
	if device == Device.KEYBOARD:
		var key := InputEventKey.new()
		key.physical_keycode = KEYS[action]
		key.pressed = pressed
		return key
	if action == &"move_down":
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_Y
		motion.axis_value = 1.0 if pressed else 0.0
		return motion
	var button := InputEventJoypadButton.new()
	button.button_index = PAD_BUTTONS[action]
	button.pressed = pressed
	return button


func _on_state_changed(previous: Player.State, current: Player.State) -> void:
	_reached[current] = true
	_log("%-11s -> %-11s pos=(%.0f, %.0f) vel=(%.0f, %.0f)" % [
		_state_name(previous), _state_name(current),
		_player.global_position.x, _player.global_position.y,
		_player.velocity.x, _player.velocity.y,
	])


func _on_jumped(used_coyote: bool, used_buffer: bool) -> void:
	if used_coyote:
		_log("  jump used COYOTE time")
	if used_buffer:
		_log("  jump came from the JUMP BUFFER")


func _on_attack_landed(target: Hittable) -> void:
	_log("  sword hit %s (state %s)" % [target.name, _state_name(_player.state)])


func _on_pogo_bounced(target: Area2D) -> void:
	if target is DummyEnemy:
		_enemy_bounces[target] = _bounces_on(target as DummyEnemy) + 1
	else:
		_spike_bounces += 1
	_log("  POGO BOUNCE off %s at (%.0f, %.0f), vel.y now %.0f" % [
		target.name, _player.global_position.x, _player.global_position.y, _player.velocity.y,
	])


func _finish() -> void:
	if _failed:
		return
	var missing: Array[String] = []
	for value: int in Player.State.values():
		if not _reached.has(value):
			missing.append(_state_name(value))
	print("")
	print("==== SUMMARY ====")
	var reached_names: Array[String] = []
	for value: int in Player.State.values():
		if _reached.has(value):
			reached_names.append(_state_name(value))
	print("states reached (%d/%d): %s" % [reached_names.size(), Player.State.size(), ", ".join(reached_names)])
	print("pogo bounces: PotHopper=%d GrumbleDaruma=%d spikes=%d" % [_bounces_on(_hopper), _bounces_on(_daruma), _spike_bounces])
	print("enemy hits: PotHopper=%d GrumbleDaruma=%d" % [_hopper.hits_taken, _daruma.hits_taken])
	_check(missing.is_empty(), "missing states: %s" % ", ".join(missing))
	_check(_bounces_on(_hopper) > 0, "expected a pogo bounce on the pot hopper")
	_check(_bounces_on(_daruma) > 0, "expected a pogo bounce on the grumble daruma")
	if _failed:
		return
	print("RESULT: PASS")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(what: String) -> void:
	if _failed:
		return
	_failed = true
	print("RESULT: FAIL (%s) at frame %d, state %s, pos %s" % [what, _frame(), _state_name(_player.state), _player.global_position])
	get_tree().quit(1)


func _section(title: String) -> void:
	_log("--- %s ---" % title)


func _log(message: String) -> void:
	print("[f%04d] %s" % [_frame(), message])


func _frame() -> int:
	return Engine.get_physics_frames() - _start_frame


func _state_name(value: int) -> String:
	return Player.State.keys()[value]
