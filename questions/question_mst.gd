@tool
extends Question_Abstract

@onready var sum_weights_mst     : SpinBox   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/InputNumber

func avaliar_resposta():
    GraphHelper.set_vertices_edges(vertices.map(func(x): return x.id), edges.map(func(e): return {"from": e["from"].id, "to": e["to"].id, "weight": e["weight"]}))
    print(GraphHelper.kruskal())
    if sum_weights_mst.value != GraphHelper.kruskal():
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
         "content": "Soma dos pesos: " + str(sum_weights_mst.value),
        })
    
    return params

func _ready() -> void:
    graph        = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/GraphEditor
    enunciado    = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/Label
    resposta     = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/RespostaDiscursiva
    respostaIA   = $ColorRect/SplitContainer/VSplitContainer/RespostaIA
    llm          = $LLM
    vertices = graph.vertices
    edges = graph.edges
    await get_tree().process_frame
    graph.load_graph_from_file("res://graphs/caminho_minimo.json")
