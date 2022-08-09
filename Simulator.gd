extends Control

var thread_number: int = 1

signal thread_breaked(debug_thread_id: PackedByteArray, is_main_thread: bool, reason: String, severity_code: int, can_debug: bool)
signal thread_paused(debug_thread_id: PackedByteArray, is_main_thread: bool)
signal thread_alert(debug_thread_id: PackedByteArray, is_main_thread: bool, reason: String, severity_code: int, can_debug: bool, has_stack_dump: bool)

signal thread_continued(debug_thread_id: PackedByteArray)
signal thread_exited(debug_thread_id: PackedByteArray)
signal thread_stack_dump(debug_thread_id: PackedByteArray, stack_dump: Array)
signal thread_stack_frame_vars(debug_thread_id: PackedByteArray, num_vars: int)
signal thread_stack_frame_var(debug_thread_id: PackedByteArray, data: Array)
signal thread_info(debug_thread_id: PackedByteArray, language: String, thread_tag: PackedByteArray, thread_name: String)

signal clear_execution(script: Object)

func _on_simulated_thread_thread_alert(debug_thread_id, is_main_thread, reason, severity_code, can_debug, has_stack_dump):
	emit_signal('thread_alert', debug_thread_id, is_main_thread, reason, severity_code, can_debug, has_stack_dump)


func _on_simulated_thread_thread_breaked(debug_thread_id, is_main_thread, reason, severity_code, can_debug):
	emit_signal('thread_breaked', debug_thread_id, is_main_thread, reason, severity_code, can_debug)


func _on_simulated_thread_thread_continued(debug_thread_id):
	emit_signal('thread_continued', debug_thread_id)


func _on_simulated_thread_thread_info(debug_thread_id, language, thread_tag, thread_name):
	emit_signal('thread_info', debug_thread_id, language, thread_tag, thread_name)


func _on_simulated_thread_thread_paused(debug_thread_id, is_main_thread):
	emit_signal('thread_paused', debug_thread_id, is_main_thread)


func _on_simulated_thread_thread_stack_dump(debug_thread_id, stack_dump):
	emit_signal('thread_stack_dump', debug_thread_id, stack_dump)


func _on_simulated_thread_thread_stack_frame_var(debug_thread_id, data):
	emit_signal('thread_stack_frame_var', debug_thread_id, data)


func _on_simulated_thread_thread_stack_frame_vars(debug_thread_id, num_vars):
	emit_signal('thread_stack_frame_vars', debug_thread_id, num_vars)


func _on_simulated_thread_thread_exited(debug_thread_id):
	emit_signal('thread_exited', debug_thread_id)


func _on_clear_execution_pressed():
	emit_signal('clear_execution', null)
