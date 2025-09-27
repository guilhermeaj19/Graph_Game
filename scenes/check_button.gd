extends Button

func _ready():
	toggle_mode = true
	_atualizar_estado()

	# Conecta o sinal de mudança de estado
	toggled.connect(_on_toggle)

func _on_toggle(button_pressed: bool) -> void:
	_atualizar_estado()

func _atualizar_estado():
	if button_pressed:
		text = "Del"
		modulate = Color.RED
	else:
		text = "Add"
		modulate = Color.GREEN
