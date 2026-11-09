extends Node2D
## Test room for tuning the player controller. The debug HUD (state and hearts)
## is off by default; the scripted walkthrough turns it on.

@export var show_debug_hud := false

@onready var _player: Player = $Player
@onready var _hud: CanvasLayer = $Hud
@onready var _state_label: Label = $Hud/StateLabel


func _ready() -> void:
	_hud.visible = show_debug_hud


func _process(_delta: float) -> void:
	if show_debug_hud:
		_state_label.text = "%s  HP %d/%d" % [Player.State.keys()[_player.state], _player.hearts, _player.tuning.max_hearts]
