# move_log.gd
extends Control

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var move_list: VBoxContainer = $ScrollContainer/VBoxContainer

const FONT_SIZE = 20

func add_move(turn_number: int, move_text: String) -> void:
	var label = Label.new()
	label.text = "Turn %d %s" % [turn_number, move_text]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	
	move_list.add_child(label)
	_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
