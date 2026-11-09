# SEALBOUND (working title)

Retro side-scrolling action roguelite in Godot 4.3+ / GDScript. This branch has
only the **player controller prototype** (build-order step 2 of `plan_v2.md`):
movement, sword, jump-attack and pogo on a greybox test room. The hero uses the
locked knight sprites (idle and run). Dummies, level, and the sword/pogo blades
are still coloured rectangles.

## Open and run

1. Install **Godot 4.3 or newer** (standard build, not .NET).
2. In the Project Manager, choose **Import** and pick this folder's `project.godot`.
3. Press **F5**. The main scene is the greybox test room
   (`scenes/rooms/greybox/test_room.tscn`).

From the command line:

```bash
godot --headless --import                    # first import, creates .godot/
godot --path .                               # play the test room
godot --headless --path . res://tests/walkthrough/player_walkthrough.tscn
                                             # scripted input pass, exit code 0 = pass
```

The walkthrough injects keyboard and gamepad events through the InputMap, drives
the player through every state, prints each state transition, and fails unless
all nine states are reached and a pogo bounce lands on a dummy.

## Display

320x180 base resolution, `viewport` stretch mode with **integer** scaling only
(black bars fill the remainder), nearest-neighbour texture filtering and 2D
pixel snapping. The default window is 1280x720 (4x). Renderer: GL Compatibility.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | Left/Right arrows, A/D | D-pad, left stick |
| Down (for pogo) | Down arrow, S | D-pad down, left stick down |
| Jump (hold for height) | Z, Space, K | A / Cross (bottom) |
| Attack | X, J | X / Square (left) |
| Pogo down-strike | Down + Attack in the air | Down + X in the air |

Bindings live in the InputMap (Project Settings > Input Map).

## Player states

`IDLE`, `RUN`, `JUMP`, `FALL`, `ATTACK` (ground), `JUMP_ATTACK`, `POGO`, `HURT`, `DEAD`.

- Ground attack and jump-attack are committed: a short startup, a few active
  frames, then recovery. You can't turn or steer during the ground attack, and
  the jump-attack keeps its momentum.
- Pogo lasts until you land. Hitting a dummy or the spikes on the way down
  bounces you up; spikes don't hurt you while you pogo on them.
- Spikes cost 1 heart with knockback and brief invincibility. The pit kills
  instantly. Dead respawns you at the start with full hearts after a short delay.
- Jumping has coyote time, a jump buffer, and variable height (releasing jump
  early cuts upward speed).

## Tuning

**Every feel constant is in one resource: `data/player/player_tuning.tres`**
(script: `src/player/player_tuning.gd`). Select it in the FileSystem dock and
edit it in the Inspector. The scripts hard-code no feel values, only the
placeholder colours. Units are pixels
and seconds. Positive y points down.

Starting values (first pass, design will tune):

| Group | Field | Value | Notes |
|---|---|---|---|
| Body | `body_size` | 12 x 32 | collision box, feet-anchored; matches the knight art (feet 12 px wide, 35 px tall including hair spikes) |
| | `hurtbox_inset` | 2 | hazard hurtbox is 2 px smaller per side |
| Run | `run_speed` | 100 px/s | |
| | `ground_acceleration` | 900 px/s² | full speed in about 0.11 s |
| | `ground_deceleration` | 1100 px/s² | stops in about 0.09 s; also brakes the ground attack |
| | `air_acceleration` | 520 px/s² | committed but steerable arc |
| | `air_deceleration` | 260 px/s² | |
| Jump | `jump_velocity` | 300 px/s | full jump about 46-48 px (3 tiles) |
| | `rise_gravity` | 980 px/s² | |
| | `fall_gravity` | 1300 px/s² | falling is faster than rising (weighty, not floaty) |
| | `max_fall_speed` | 300 px/s | |
| | `jump_cut_multiplier` | 0.45 | tap jump about 17 px |
| | `coyote_time` | 0.10 s | 6 frames |
| | `jump_buffer_time` | 0.12 s | about 7 frames |
| Sword | `attack_startup` | 0.05 s | 3 frames |
| | `attack_active` | 0.10 s | 6 frames |
| | `attack_recovery` | 0.15 s | 9 frames, total about 0.3 s |
| | `attack_hitbox_size` | 18 x 10 | short reach, 6-24 px in front of the body centre |
| | `attack_hitbox_offset` | (15, -14) | mirrored when facing left |
| | `attack_damage` | 1 | |
| Pogo | `pogo_hitbox_size` | 10 x 8 | |
| | `pogo_hitbox_offset` | (0, 4) | just under the feet |
| | `pogo_bounce_velocity` | 260 px/s | bounce about 34 px |
| | `pogo_damage` | 1 | |
| Damage | `max_hearts` | 3 | |
| | `hurt_duration` | 0.35 s | no control during knockback |
| | `hurt_knockback` | (110, -170) | x points away from the source |
| | `invincibility_time` | 1.0 s | player blinks |
| | `respawn_delay` | 0.8 s | |

## Hero sprite

`art/hero/knight/` holds `idle.png` (4 frames, frame 3 is the blink) and
`run.png` (6 frames), both 48x48 per frame. `knight_sprite_frames.tres` defines
the `idle` and `run` animations; their speeds are data there, not in code:

| Animation | Speed | Frame durations | Cycle |
|---|---|---|---|
| `idle` | 5 fps | 2, 2, 2, 1 (blink is half length) | 1.4 s |
| `run` | 10 fps | all 1 | 0.6 s |

The `Sprite` node in `src/player/player.tscn` sits at (0, -21). That puts the
bottom of frame row 44 (the lowest foot row) on the player origin, which is the
bottom of the collision box. The feet are centred on frame x = 24, so
`flip_h` for left-facing keeps them in place. States without art yet (jump,
fall, attacks, pogo, hurt, dead) hold idle frame 0; hurt and dead tint it.

## Layout

Folders follow `plan_v2.md`. Empty folders are kept with `.gitkeep` until their
build step. This step adds:

```
src/player/        player.gd, player.tscn, player_tuning.gd
art/hero/knight/   idle.png, run.png, knight_sprite_frames.tres
src/enemies/       hittable.gd (sword/pogo target base), dummy_enemy.gd
src/world/         greybox_block.gd, hazard.gd (spikes, pit), physics_layers.gd
data/player/       player_tuning.tres
scenes/rooms/greybox/  test_room.tscn (+ debug HUD script)
tests/walkthrough/ scripted input pass
```

`src/world/` and `data/player/` aren't in the plan's tree. They hold the
room-building pieces and the player tuning data.

Physics layers: 1 world, 2 player, 3 enemy_hurtbox, 4 hazard. Sword, pogo and
hazard checks use direct shape queries each physics frame, so hits register on
the same frame without Area2D signal lag.
