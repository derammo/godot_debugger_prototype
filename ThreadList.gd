extends Tree

class_name ThreadList

@tool 

signal thread_frame_selected(tid: PackedByteArray, frame: int)
signal thread_nodebug_frame_selected(tid: PackedByteArray, frame: int)

@onready var play_start_icon = ResourceLoader.load('res://play_start.png')
@onready var crashed_icon = ResourceLoader.load('res://status_error.png')

const ICON_SIZE: int = 24
const H_SEPARATION: int = 6
const H_CHILD_MARGIN: int = 18

class FieldInfo:
	var title: String
	var long_title: String
	var column_visible: bool = false
	var column_index: int 	
	
	func _init(_title: String, _long_title: String, _column_visible: bool, _column_index: int):
		title = _title
		long_title = _long_title
		column_visible = _column_visible
		column_index = _column_index

var field_info: Array = [
	FieldInfo.new('Pin State', 'Pin and State', true, -1),	
	FieldInfo.new('ID', 'ID', true, -1),	
	FieldInfo.new('Name', 'Name', true, -1),	
	FieldInfo.new('Where', 'Where', true, -1),	
	FieldInfo.new('Lang.', 'Language', false, -1),	
	FieldInfo.new('Category', 'Category', false, -1),	
	FieldInfo.new('Debug ID', 'Debug ID', false, -1)	
]

enum Field {
	# WARNING: pin and status must be combined in first column to make it wide enoug for child connectors
	STATUS = 0,
	ID,
	NAME,
	STACK,
	LANGUAGE,
	CATEGORY,
	DEBUG_ID,
	NUM_FIELDS
}

enum Meta {
	STACK = 0,
	THREAD = 1,
	FRAME
}

# Index from tree column to field.
var field_index: Array = []

var root: TreeItem
var column_title_context_menu: PopupMenu

var threads: Dictionary = {}
var current: ThreadInfo = null

var next_main_thread_number: int = 1
var next_thread_number: int = 100
var sort_field: Field = Field.DEBUG_ID
var placeholder_main: ThreadInfo = null

const color_by_severity: Array = [
	Color(1.0, 1.0, 1.0, 0.5),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 0.0, 1.0),
	Color(1.0, 0.89, 0.027, 1.0),
	Color(1.0, 0.78, 0.054, 1.0),
	Color(1.0, 0.0, 0.0, 1.0)	
]

enum Status {
	BLOCKED,
	RUNNING,
	PAUSED,
	ALERT,
	BREAKPOINT,
	CRASHED,
	DEAD
}

const status_tooltip: Array = [
	'Thread is blocked and not avaialable for debugging',
	'Thread is running',
	'Thread is paused after step executing another thread',
	'Thread hit break or error during step execution',
	'Thread is paused for debugging',
	'Thread has crashed',
	'Thread has exited'
]


class ThreadInfo:
	extends RefCounted
	
	var tree_item: TreeItem = null
	var thread_number: int = -1
	var debug_thread_id: PackedByteArray:
		set(value):
			debug_thread_id = value
			debug_thread_id_hex = value.hex_encode()
	var debug_thread_id_hex: String
	var is_main_thread: bool
	var reason: String = ""
	var status: Status
	var severity_code: int
	var can_debug: bool
	var has_stack_dump: bool
	var language: String = ""
	var thread_tag: PackedByteArray
	var thread_name: String = ""
	var stack_dump_info: Array = []
	
	func _init(p_thread_number: int, p_debug_thread_id: PackedByteArray, p_is_main_thread: bool):
		thread_number = p_thread_number
		debug_thread_id = p_debug_thread_id
		is_main_thread = p_is_main_thread
		

func _ready():
	select_mode = Tree.SELECT_ROW
	allow_reselect = true
	column_titles_visible = true
	rebuild()

	column_title_context_menu = PopupMenu.new()
	column_title_context_menu.allow_search = true
	column_title_context_menu.hide_on_checkable_item_selection = false
	for field in [ Field.NAME, Field.CATEGORY, Field.LANGUAGE, Field.DEBUG_ID ]:
		column_title_context_menu.add_check_item(field_info[field].long_title, field)
		var index: int = column_title_context_menu.get_item_index(field)
		column_title_context_menu.set_item_as_checkable(index, true)	
		column_title_context_menu.set_item_checked(index, field_info[field].column_visible)
	add_child(column_title_context_menu)

	var _ignored = connect('item_edited', _on_thread_list_item_edited)
	_ignored = connect('item_selected', _on_thread_list_item_selected)
	if has_signal('column_title_pressed'):
		_ignored = connect('column_title_pressed', _on_thread_list_column_title_pressed)
	_ignored = connect('item_activated', _on_thread_list_item_activated)
	if has_signal('column_title_clicked'):
		_ignored = connect('column_title_clicked', _on_thread_list_column_title_clicked)
	_ignored = column_title_context_menu.connect('id_pressed', _on_column_title_context_pressed)	
	
func rebuild():
	# pass 0: tear down
	for thread in threads.values():
		thread.tree_item = null
	clear()
	field_index = []
	
	# pass 1: measure columns
	var column: int = 0
	for field in Field.NUM_FIELDS:
		if field_info[field].column_visible:
			column += 1
	columns = column
		
	# pass 2: build
	root = create_item()
	assert(root != null)
	column = 0
	for field in Field.NUM_FIELDS:
		if !field_info[field].column_visible:
			field_info[field].column_index = -1
			continue
		match field:
			Field.STATUS:
				# last separation is due to an error in child size calculation in Tree
				set_column_custom_minimum_width(column, (ICON_SIZE + H_SEPARATION) * 2 + H_CHILD_MARGIN + H_SEPARATION)
				set_column_expand(column, false)
			Field.ID:
				set_column_custom_minimum_width(column, 48) 	
				set_column_expand(column, false)
			Field.DEBUG_ID, Field.NAME, Field.LANGUAGE, Field.CATEGORY:
				set_column_expand(column, false)
		set_column_title(column, field_info[field].title)
		field_info[field].column_index = column
		field_index.append(field)
		column += 1
	var _tree_item: TreeItem
	for thread in threads.values():
		# Add row in correct sort position.
		_tree_item = add_row(thread)
	update_status_for_threads()
	
	
func _exit_tree():
	# undo circularity
	for thread in threads.values():
		thread.tree_item = null
	threads.clear()	

	column_title_context_menu.disconnect('id_pressed', _on_column_title_context_pressed)	
	if has_signal('column_title_clicked'):
		disconnect('column_title_clicked', _on_thread_list_column_title_clicked)
	disconnect('item_activated', _on_thread_list_item_activated)
	if has_signal('column_title_pressed'):
		disconnect('column_title_pressed', _on_thread_list_column_title_pressed)
	disconnect('item_selected', _on_thread_list_item_selected)
	disconnect('item_edited', _on_thread_list_item_edited)


func set_debugger(debugger: Object) -> int:
	var err: int
	err = debugger.connect('thread_breaked', _on_debugger_thread_breaked)
	if err != OK:
		return err
	err = debugger.connect('thread_paused', _on_debugger_thread_paused)
	if err != OK:
		return err
	err = debugger.connect('thread_alert', _on_debugger_thread_alert)
	if err != OK:
		return err
	err = debugger.connect('thread_continued', _on_debugger_thread_continued)
	if err != OK:
		return err
	err = debugger.connect('thread_exited', _on_debugger_thread_exited)
	if err != OK:
		return err
	err = debugger.connect('thread_stack_dump', _on_debugger_thread_stack_dump)
	if err != OK:
		return err
	err = debugger.connect('thread_info', _on_debugger_thread_info)
	if err != OK:
		return err
	err = debugger.connect('clear_execution', _on_debugger_clear_execution)
	if err != OK:
		return err
	return OK		


func update_info(info: ThreadInfo):
	var column: int = field_info[Field.NAME].column_index
	if column > -1:
		info.tree_item.set_text(column, info.thread_name)
	column = field_info[Field.LANGUAGE].column_index
	if column > -1:
		info.tree_item.set_text(column, info.language)

	
func find_least_greater(info: ThreadInfo) -> int:
	assert(root != null)
	var before: TreeItem = root.get_first_child()
	var before_index: int = 0
	while before != null:
		if less_than(info, before.get_metadata(Meta.THREAD), sort_field):
			# found the first greater
			break
		before = before.get_next()
		before_index += 1
	return before_index	
				
				
func add_row(info: ThreadInfo):
	var item: TreeItem = create_item(root, find_least_greater(info))
	item.set_metadata(Meta.THREAD, info)
	item.set_metadata(Meta.FRAME, 0)
	item.set_metadata(Meta.STACK, {})	
	info.tree_item = item

	var column: int
	column = field_info[Field.STATUS].column_index
	if column > -1:
		item.set_cell_mode(column, TreeItem.CELL_MODE_CHECK)
		item.set_editable(column, true)
		item.set_icon_max_width(column, ICON_SIZE)
		item.set_selectable(column, false)		
		item.set_icon(column, null)
	column = field_info[Field.ID].column_index
	if column > -1:
		item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text(column, '%d' % info.thread_number)
	column = field_info[Field.DEBUG_ID].column_index
	if column > -1:
		item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text(column, info.debug_thread_id.hex_encode())
	column = field_info[Field.CATEGORY].column_index
	if column > -1:
		item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text(column, 'Main' if info.is_main_thread else 'Worker')
	column = field_info[Field.NAME].column_index
	if column > -1:
		item.set_text(column, '')
	column = field_info[Field.LANGUAGE].column_index
	if column > -1:
		item.set_text(column, '')
	column = field_info[Field.STACK].column_index
	if column > -1:
		if len(info.stack_dump_info) > 0:
			build_stack_dump(info)
		else:
			item.set_text(column, '')
			item.set_tooltip(column, '%s\n%s' % [info.reason, '(no stack info received)' if info.has_stack_dump else '(stack info unavailable)'])
	item.collapsed = true
	return item

	
func set_current(thread: ThreadInfo):
	current = thread
	if (len(field_index) < 3):
		return
	thread.tree_item.select(2)
	update_status_for_threads()
	

func update_status(thread: ThreadInfo):
	var column: int = field_info[Field.STATUS].column_index
	if column < 0:
		return
	if thread == current:
		thread.tree_item.set_icon_modulate(column, color_by_severity[thread.severity_code])
	else:
		thread.tree_item.set_icon_modulate(column, color_by_severity[thread.severity_code] * 0.5)
	match thread.status:
		Status.PAUSED, Status.ALERT, Status.BREAKPOINT:
			if thread.can_debug:	
				thread.tree_item.set_icon(column, play_start_icon)
			else:
				thread.tree_item.set_icon(column, crashed_icon)
		Status.CRASHED:
			thread.tree_item.set_icon(column, crashed_icon)
		_:
			thread.tree_item.set_icon(column, null)
	thread.tree_item.set_tooltip(column, status_tooltip[thread.status])


func update_status_for_threads():
	for thread in threads.values():
		update_status(thread)


func less_than(left: ThreadInfo, right: ThreadInfo, p_sort_field: Field) -> bool:
	var pin_column: int = field_info[Field.STATUS].column_index
	if pin_column > -1:
		var left_flag: bool = left.tree_item and left.tree_item.is_checked(pin_column)
		var right_flag: bool = right.tree_item and right.tree_item.is_checked(pin_column)
		
		if right_flag and not left_flag:
			return false
			
		if left_flag and not right_flag:
			return true
		
	match p_sort_field:
		Field.ID:
			if left.thread_number < right.thread_number:
				return true
			return false
		Field.DEBUG_ID:
			if left.debug_thread_id_hex < right.debug_thread_id_hex:
				return true
			return false
		Field.NAME:
			# sort empty last instead of first
			if left.thread_name == null or left.thread_name == '':
				return false
			if right.thread_name == null or right.thread_name == '':
				return true
			if left.thread_name < right.thread_name:
				return true
			return false
		Field.LANGUAGE:
			# sort empty last instead of first
			if left.language == null or left.language == '':
				return false
			if right.language == null or right.language == '':
				return true
			if left.language < right.language:
				return true
			return false
	return false

	
func sort_table():
	var index: Array = threads.values().duplicate(false)
	if len(index) < 2:
		return
	if sort_field != Field.DEBUG_ID:
		# sort secondary as tie breaker otherwise insertion order will be relevant
		index.sort_custom(func(left, right):
			return less_than(left, right, Field.DEBUG_ID))
	index.sort_custom(func(left, right):
		return less_than(left, right, sort_field))
	
	# last one never needs to move
	index.pop_back()
		
	# start the subtree with the first item by sort order
	var item: TreeItem = index.pop_front().tree_item
	var previous: TreeItem = root.get_first_child()
	if item != previous:
		item.move_before(previous)
	previous = item
		
	for thread in index:
		item = thread.tree_item
		item.move_after(previous)
		previous = item


func format_frame_text(frame: Dictionary) -> String:
	return '%d - %s:%d - at function: %s' % [frame.frame, frame.file, frame.line, frame.function ]
	
	
func format_stack_text(stack: Array) -> String:
	var lines: Array = []
	for frame in stack:
		lines.append(format_frame_text(frame))
	return '\n'.join(lines)
	
	
func clear_threads():
	for thread in threads.values():
		if thread.tree_item:
			thread.tree_item.free()
			thread.tree_item = null
	threads.clear()
	placeholder_main = null
	
	
func disable_selection_on_status_columns(row: TreeItem):
	var column: int = field_info[Field.STATUS].column_index
	if column > -1:
		row.set_selectable(column, false)


func build_stack_dump(thread: ThreadInfo):
	var stack_dump_info: Array = thread.stack_dump_info
	if len(stack_dump_info) < 1:
		thread.tree_item.set_metadata(Meta.STACK, {})
		return
		
	thread.tree_item.set_metadata(Meta.STACK, stack_dump_info[0])
	var stack_column = field_info[Field.STACK].column_index
	if stack_column > -1:
		thread.tree_item.set_text(stack_column, format_frame_text(stack_dump_info[0]))
		thread.tree_item.set_tooltip(stack_column, '%s\n%s' % [thread.reason, format_stack_text(stack_dump_info)])
	for frame in range(1, len(stack_dump_info)):
		var frame_line : TreeItem = create_item(thread.tree_item)
		frame_line.set_metadata(Meta.STACK, stack_dump_info[frame])
		frame_line.set_metadata(Meta.THREAD, thread)
		frame_line.set_metadata(Meta.FRAME, frame)
		for scan in columns:
			frame_line.set_selectable(scan, false)	
		var column: int
		column = field_info[Field.STATUS].column_index
		if column > -1:
			frame_line.set_icon(column, null)
			frame_line.set_icon_max_width(column, ICON_SIZE)
		column = field_info[Field.ID].column_index
		if column > -1:
			frame_line.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
			frame_line.set_text(column, '')
		column = field_info[Field.DEBUG_ID].column_index
		if column > -1:
			frame_line.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
			frame_line.set_text(column, '')
		column = field_info[Field.CATEGORY].column_index
		if column > -1:
			frame_line.set_text_alignment(column, HORIZONTAL_ALIGNMENT_CENTER)
			frame_line.set_text(column, '')
		if stack_column > -1:
			frame_line.set_selectable(stack_column, true)		
			frame_line.set_text(stack_column, format_frame_text(stack_dump_info[frame]))
		frame_line.collapsed = true
				
	
func create_thread_info(debug_thread_id: PackedByteArray, is_main_thread: bool) -> ThreadInfo:
	var thread_number: int
	if is_main_thread:
		thread_number = next_main_thread_number
		next_main_thread_number += 1
	else:
		thread_number = next_thread_number
		next_thread_number += 1
	return ThreadInfo.new(thread_number, debug_thread_id, is_main_thread)
	
	
func notify_frame_selected(thread: ThreadInfo, frame: int, frame_info: Dictionary):
	emit_signal('thread_frame_selected' if thread.can_debug else 'thread_nodebug_frame_selected', 
		thread.debug_thread_id, 
		frame, 
		frame_info)	
	

func _on_debugger_clear_execution(_script: Script):
	clear_threads();
	

func update_placeholder_main(is_main_thread: bool):
	var placeholder_thread_id: PackedByteArray = PackedByteArray()
	if not is_main_thread and placeholder_main == null and threads.is_empty():
		# Show Main status as unavailable so it does not appear died.
		var thread: ThreadInfo = create_thread_info(placeholder_thread_id, true)
		thread.reason = 'Main thread is blocked and unavailable for debugging'
		thread.can_debug = false
		thread.severity_code = 0
		thread.status = Status.BLOCKED
		thread.thread_name = 'Main (blocked)'
		placeholder_main = thread
		threads[placeholder_thread_id] = thread
		add_row(thread)
		return
	if is_main_thread and placeholder_main != null:
		# Replace with real status.
		threads.erase(placeholder_thread_id)
		placeholder_main.tree_item.free()
		placeholder_main.tree_item = null
		placeholder_main = null


func _on_debugger_thread_breaked(debug_thread_id, is_main_thread, reason, severity_code, can_debug):
	update_placeholder_main(is_main_thread)
	var thread: ThreadInfo
	if threads.has(debug_thread_id):
		thread = threads[debug_thread_id]
		thread.reason = reason
		thread.tree_item.set_metadata(Meta.STACK, {})	
	else:
		thread = create_thread_info(debug_thread_id, is_main_thread)
		thread.reason = reason
		threads[debug_thread_id] = thread
		add_row(thread)
	thread.can_debug = true
	thread.has_stack_dump = true
	thread.severity_code = severity_code
	thread.status = Status.BREAKPOINT if can_debug else Status.CRASHED
	# This will also update status:
	set_current(thread)
	notify_frame_selected(thread, 0, {})
	
	
func _on_debugger_thread_paused(debug_thread_id, is_main_thread):
	update_placeholder_main(is_main_thread)
	var thread: ThreadInfo
	if threads.has(debug_thread_id):
		thread = threads[debug_thread_id]
		thread.reason = ''
	else:
		thread = create_thread_info(debug_thread_id, is_main_thread)
		thread.reason = ''
		threads[debug_thread_id] = thread
		add_row(thread)
	thread.can_debug = true
	thread.has_stack_dump = true
	thread.severity_code = 0
	thread.status = Status.PAUSED
	update_status(thread)
	

func _on_debugger_thread_alert(debug_thread_id, is_main_thread, reason, severity_code, can_debug, has_stack_dump):
	update_placeholder_main(is_main_thread)
	var thread: ThreadInfo
	if threads.has(debug_thread_id):
		thread = threads[debug_thread_id]
		thread.reason = reason
	else:
		thread = create_thread_info(debug_thread_id, is_main_thread)
		thread.reason = reason
		threads[debug_thread_id] = thread
		add_row(thread)
	thread.can_debug = can_debug
	thread.has_stack_dump = has_stack_dump
	thread.severity_code = severity_code
	thread.status = Status.ALERT if can_debug else Status.CRASHED
	update_status_for_threads()


func _on_debugger_thread_continued(debug_thread_id):
	if !threads.has(debug_thread_id):
		return
	var thread: ThreadInfo = threads[debug_thread_id]
	thread.can_debug = false
	thread.severity_code = 0
	thread.status = Status.RUNNING
	update_status(thread)


func _on_debugger_thread_info(debug_thread_id, language, thread_tag, thread_name):
	if !threads.has(debug_thread_id):
		return
	var thread: ThreadInfo = threads[debug_thread_id]
	thread.language = language
	thread.thread_tag = thread_tag
	thread.thread_name = thread_name
	update_info(thread)
	if sort_field in [Field.NAME, Field.LANGUAGE]:
		sort_table()
		

func _on_debugger_thread_stack_dump(debug_thread_id, stack_dump_info: Array):
	if !threads.has(debug_thread_id):
		return
	var thread: ThreadInfo = threads[debug_thread_id]
	var existing: Array = []
	var scan: TreeItem = thread.tree_item.get_first_child()
	while scan != null:
		existing.append(scan)
		scan = scan.get_next()
	if thread == current:
		# Mmove focus off of any stack frames that are now being removed.
		if (len(field_index) > 2):
			thread.tree_item.select(2)
	for removeme in existing:
		thread.tree_item.remove_child(removeme)
	thread.stack_dump_info = stack_dump_info
	build_stack_dump(thread)
			
				
func _on_debugger_thread_exited(debug_thread_id):
	if !threads.has(debug_thread_id):
		return
	var thread: ThreadInfo = threads[debug_thread_id]
	thread.tree_item.free()
	threads.erase(debug_thread_id)


func _on_thread_list_item_selected():
	var row: TreeItem = get_selected()
	var thread: ThreadInfo = row.get_metadata(Meta.THREAD)
	current = thread
	update_status_for_threads()	
	notify_frame_selected(thread, row.get_metadata(Meta.FRAME), row.get_metadata(Meta.STACK))


func _on_thread_list_column_title_clicked(column, mouse_button_index):
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		column_title_context_menu.visible = true
		return
		
	if column > len(field_index) - 1:
		# invalid click (deferred?)
		return
		
	var field: int = field_index[column]
	match field:
		Field.ID, Field.DEBUG_ID, Field.NAME, Field.LANGUAGE:
			sort_field = field as Field
			sort_table()
		_:
			return


func _on_thread_list_column_title_pressed(column):
	if column == 0 and not has_signal('column_title_clicked'):
		# legacy Tree class: simulate right click when first column is left clicked
		_on_thread_list_column_title_clicked(column, MOUSE_BUTTON_RIGHT)
		return
		
	# translate
	_on_thread_list_column_title_clicked(column, MOUSE_BUTTON_LEFT)
			

func _on_thread_list_item_edited():
	sort_table()


func _on_thread_list_item_activated():
	# XXX show code
	pass
	
	
func _on_column_title_context_pressed(id: int):
	var index: int = column_title_context_menu.get_item_index(id)
	column_title_context_menu.toggle_item_checked(index)
	field_info[id].column_visible = column_title_context_menu.is_item_checked(index)
	rebuild()
