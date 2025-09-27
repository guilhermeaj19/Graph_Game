@tool
extends Sprite2D
class_name Vertex

@export var color_idle: Texture2D
@export var color_dragged: Texture2D
@export var color_selected: Texture2D
@export var radius: float = 16.0

@onready var label: RichTextLabel = $id_label

var dragging: bool = false
var id:       int  = 0

func set_id(id_: int):
    id = id_
    label.text = str(id)
    
func _ready() -> void:
    centered = true

    if color_idle and color_dragged and color_selected:
        texture = color_idle
        radius = max(texture.get_width(), texture.get_height()) * 0.5      
    else:
        push_warning("Texturas não atribuídas! Atribua no Inspector.")

    set_process_input(true)

func drag() -> void:
    texture = color_dragged

func select() -> void:
    texture = color_selected

func idle() -> void:
    texture = color_idle
