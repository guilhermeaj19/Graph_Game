@tool
extends Question_Abstract

@onready var number_colors     : SpinBox   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/InputNumber

func avaliar_resposta():
    if number_colors.value != vertices.size():
        set_ia_feedback("Resposta errada. Analise o grafo com cuidado!")
        return
    else:
        set_ia_feedback("Resposta correta. Analisando feedback...")
   
    set_ia_feedback()

func construct_prompt() -> Dictionary:
    var params = super.construct_prompt()
    params["prompt_messages"].insert(3, 
        {
         "role": "user",
         "content": "Número de cores: " + str(number_colors.value),
        })
    
    return params

func _ready() -> void:
    graph        = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/GraphEditor
    enunciado    = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/Enunciado
    resposta     = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/RespostaDiscursiva
    respostaIA   = $ColorRect/SplitContainer/VSplitContainer/RespostaIA
    llm          = $LLM
    vertices = graph.vertices
    edges = graph.edges
    await get_tree().process_frame
    graph.load_graph_from_file("res://graphs/complete_graph.json")
