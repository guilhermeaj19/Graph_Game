@tool
extends Question_Abstract

@onready var graph1     : GraphEditor   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/GraphEditor2
@onready var graph2     : GraphEditor   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer/GraphEditor
@onready var check1     : CheckBox   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/CheckBox2
@onready var check2     : CheckBox   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer/CheckBox

func avaliar_resposta():
    if check1.is_pressed() and check2.is_pressed():
        set_ia_feedback("Selecione apenas um grafo")
        return
        
    if check2.is_pressed():
        set_ia_feedback("Resposta incorreta.")
        return
    elif check1.is_pressed():
        set_ia_feedback("Resposta correta. Analisando feedback...")
    else:
        set_ia_feedback("Selecione um grafo.")
        return    
        
    set_ia_feedback()

func _ready() -> void:
    enunciado    = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/Label
    resposta     = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/RespostaDiscursiva
    respostaIA   = $ColorRect/SplitContainer/VSplitContainer/RespostaIA
    llm          = $LLM
    vertices = graph1.vertices
    edges = graph1.edges
    await get_tree().process_frame
    graph1.load_graph_from_file("res://graphs/complete_graph.json")
    await get_tree().process_frame
    graph2.load_graph_from_file("res://graphs/incomplete_graph.json")
