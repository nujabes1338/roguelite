extends Node2D
## Greybox room for tuning the player controller. The debug HUD shows the
## player's state and hearts.

@onready var _player: Player = $Player
@onready var _state_label: Label = $Hud/StateLabel


func _process(_delta: float) -> void:
	_state_label.text = "%s  HP %d/%d" % [Player.State.keys()[_player.state], _player.hearts, _player.tuning.max_hearts]
