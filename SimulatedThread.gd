extends HBoxContainer

signal thread_breaked(debug_thread_id: PackedByteArray, is_main_thread: bool, reason: String, severity_code: int, can_debug: bool)
signal thread_paused(debug_thread_id: PackedByteArray, is_main_thread: bool)
signal thread_alert(debug_thread_id: PackedByteArray, is_main_thread: bool, reason: String, severity_code: int, can_debug: bool, has_stack_dump: bool)

signal thread_continued(debug_thread_id: PackedByteArray)
signal thread_exited(debug_thread_id: PackedByteArray)
signal thread_stack_dump(debug_thread_id: PackedByteArray, stack_dump: Array)
signal thread_stack_frame_vars(debug_thread_id: PackedByteArray, num_vars: int)
signal thread_stack_frame_var(debug_thread_id: PackedByteArray, data: Array)
signal thread_info(debug_thread_id: PackedByteArray, language: String, thread_tag: PackedByteArray, thread_name: String)

var thread_number: int
var thread_id : PackedByteArray
var is_main_thread: bool
var is_crashed: bool

const languages: Array = ['vbscript', 'visualscript', 'python', 'C#']

func _ready():
	thread_number = $"..".thread_number
	thread_id.resize(9)
	for index in 8:
		thread_id[index] = index + 128
	thread_id[8] = thread_number
	is_main_thread = thread_number == 2
	is_crashed = thread_number % 3 == 1
	if thread_number == 2:
		$Label.text = "Main   %d" % thread_number
	elif is_crashed:	
		$Label.text = 'Crash  %d' % thread_number
	else:
		$Label.text = 'Thread %d' % thread_number
	$"..".thread_number += 1


func _on_breaked_pressed(severity: int):
	emit_signal('thread_breaked', thread_id, is_main_thread, "testing reason %s" % thread_id.hex_encode(), severity, !is_crashed)


func _on_paused_pressed():
	emit_signal('thread_paused', thread_id, is_main_thread)


func _on_alert_pressed():
	emit_signal('thread_alert', thread_id, is_main_thread, "alert reason %s" % thread_id.hex_encode(), 3, !is_crashed, true)


func _on_continued_pressed():
	emit_signal('thread_continued', thread_id)


func _on_exited_pressed():
	emit_signal('thread_exited', thread_id)	
	
	
func _on_info_pressed():
	var language: String
	if thread_number < len(languages):
		language = languages[thread_number]
	else:
		language = 'language%d' % thread_number
	emit_signal('thread_info', thread_id, language, thread_id, "Name %d" % thread_number)


func _on_stack_dump_pressed():
	var frames: int = randi_range(1, 7)
	var frame_info: Array = []
	for frame in frames:

		frame_info.append({ 
			'frame': frame,
			'file': 'res://Nonsense.gd',
			'line': randi_range(10,100),
			'function': 'fun%d' % randi_range(200,299)
		})
	emit_signal('thread_stack_dump', thread_id, frame_info)
