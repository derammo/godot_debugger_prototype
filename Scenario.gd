extends VBoxContainer

func _ready():
	# this happens when debugger is used in Godot to hook up signals
	$ThreadList.set_debugger($Simulator)
