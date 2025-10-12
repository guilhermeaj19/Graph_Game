@tool
extends Control

class_name WeightDisplay

@onready var background: ColorRect = $Background
@onready var text_label: Label = $TextLabel

const PADDING = 4.0

func update_text_and_resize(new_text: String):
    text_label.text = new_text

    var text_size = text_label.get_minimum_size()

    text_label.size = text_size
    background.size = text_size + Vector2(PADDING * 2, PADDING * 2)

    background.position = -background.size / 2.0
    text_label.position = -text_label.size / 2.0

    self.size = background.size
