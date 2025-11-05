@tool
extends Question_Abstract


func avaliar_resposta():
    if vertices.size() == graph.max_new_vertices and edges.size() == graph.max_new_edges: 
        GraphHelper.set_vertices_edges(vertices, edges)
        var result_eulerian = GraphHelper.es_ciclo_euleriano()
        print("É Euleriano? ", "Sim" if result_eulerian["ok"] else "Não")
        print("Ciclo: ", result_eulerian["ciclo"].map(func(v): return v.id))
        if result_eulerian["ok"]:
            set_ia_feedback("Grafo correto! Avaliando justificativa...")
        else:
            set_ia_feedback("O ciclo não é Euleriano. Revise as propriedades!")
            return
    else:
        set_ia_feedback("O grafo deve ter {0} vértices (tem {1}) e {2} arestas (tem {3})!".format([graph.max_new_vertices, vertices.size(), graph.max_new_edges, edges.size()]))
        return
    
    set_ia_feedback()

func _ready() -> void:
    graph        = $ColorRect/SplitContainer/GraphEditor
    enunciado    = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/Label
    resposta     = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/RespostaDiscursiva
    respostaIA   = $ColorRect/SplitContainer/VSplitContainer/RespostaIA
    llm          = $LLM
    vertices = graph.vertices
    edges = graph.edges
    
    var max_new_v = 4#randi_range(3,7)
    graph.max_new_vertices = max_new_v
    var max_new_possible_edges = round(max_new_v*(max_new_v-1)/2)
    
    graph.max_new_edges = 4#randi_range(graph.max_new_vertices,max_new_possible_edges)
    enunciado.text =   ("Crie um grafo com ciclo euleriano utilizando {0} vértices e {1} arestas. " +\
                       "No campo abaixo, justifique seu raciocínio.").format([graph.max_new_vertices, graph.max_new_edges])
    graph.graph_is_loaded = true
    await get_tree().process_frame
