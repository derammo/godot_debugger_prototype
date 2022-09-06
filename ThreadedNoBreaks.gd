extends Node

var typed: int 

func _ready():
	var thread = Thread.new()
	thread.start(_thread_function)
	for i in range(0, 1000):
		# this loop lets us catch break requests
		OS.delay_msec(10)
	thread.wait_to_finish()

func _thread_function():
	for i in range(0, 1000):
		# this loop lets us catch break requests
		OS.delay_msec(10)
