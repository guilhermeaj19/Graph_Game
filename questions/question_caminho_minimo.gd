@tool
extends Question_Abstract

var source_vertex: Vertex
var list_area: HBoxContainer

func get_distances():
    var distances = {}
    var index = 0
    
    for result in list_area.get_children():
        for element in result.get_children():
            if element is SpinBox:
                distances[vertices[index].id] = element.value
                index += 1
    return distances
    
func avaliar_resposta():
    GraphHelper.set_vertices_edges(vertices.map(func(x): return x.id), edges.map(func(e): return {"from": e["from"].id, "to": e["to"].id, "weight": e["weight"]}))
    var result = GraphHelper.bellman_ford(source_vertex.id, true if graph.graph_type == graph.TypeGraph.DIRIGIDO else false)
    var distances = get_distances()
    print(result)
    print(distances)
    
    for v in vertices:
        if result[1][v.id] != distances[v.id]:
            set_ia_feedback("Resposta errada. Analise o grafo com cuidado!")
            return
    
    set_ia_feedback("Resposta correta. Analisando feedback...")
   
    set_ia_feedback()

func construct_prompt() -> Dictionary:
    var params = super.construct_prompt()
    params["prompt_messages"].insert(3, 
        {
         "role": "user",
         "content": "Distancias a partir de " + str(source_vertex.id) + ": " + str(get_distances()),
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
    
    source_vertex = graph.vertices[randi_range(0,graph.vertices.size()-1)]
    var graph_type = "dirigido" if graph.graph_type == graph.TypeGraph.DIRIGIDO else "nao dirigido"
    enunciado.text = "Analisando o grafo {0}, coloque na lista ao lado os valores de distância mínima a partir do vértice {1} (se inalcançável, selecione INF). Explique seu raciocínio no campo abaixo".format([graph_type, source_vertex.id])
    list_area = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/ScrollContainer/list_area
    for v in graph.vertices:
        var v_box = VBoxContainer.new()
        var label = Label.new()
        label.text = str(v.id)
        var number_edit = SpinBox.new()
        var check_box = CheckBox.new()
        check_box.text = "INF"
        v_box.add_child(label)
        v_box.add_child(number_edit)
        v_box.add_child(check_box)
        list_area.add_child(v_box)
        check_box.connect("toggled", Callable(self, "_on_check_box_c_toggled").bind(number_edit))
    await get_tree().process_frame

func _on_check_box_c_toggled(is_checked, number_edit):
    number_edit.editable = not is_checked
