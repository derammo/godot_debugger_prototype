extends Node

var typed: int 

func _ready():
	var thread = Thread.new()
	thread.start(_thread_function)
	breakpoint
	thread.wait_to_finish()
	
func bar():
	var worker_thread_only_var: int = 1
	var another_worker_thread_only_var: int = 2

	var _ignored = worker_thread_only_var
	_ignored = another_worker_thread_only_var
	
	# assert(typed > 0, "this was only shown on stderr before, with no indication in the Editor")
	OS.delay_msec(1000)
	breakpoint
	OS.delay_msec(1000)
	breakpoint
	OS.delay_msec(1000)
	breakpoint
	
	
func foo():
	var worker_thread_foo_var: int = 1
	bar()
	var _ignored = worker_thread_foo_var	
		
func _thread_function():
	var worker_thread_fun_var: int = 1
	foo()
	var _ignored = worker_thread_fun_var
