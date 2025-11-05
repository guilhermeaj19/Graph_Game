@tool
extends Question_Abstract

var list_area: HBoxContainer
    
func get_vertexs_ids():
    var vertexs_ids = []
    
    for result in list_area.get_children():
        for element in result.get_children():
            if element is SpinBox:
                vertexs_ids.push_back(int(element.value))
    return vertexs_ids
    
func verificar_ordenacao_topologica() -> bool:
    var resposta_usuario = get_vertexs_ids()
    if resposta_usuario.size() != self.vertices.size():
        return false

    var vertices_validos = {}
    for v in vertices:
        vertices_validos[v.id] = true
        
    var posicoes = {}
    for i in range(resposta_usuario.size()):
        var vertice_id = resposta_usuario[i]
        
        if posicoes.has(vertice_id) or not vertices_validos.has(vertice_id):
            return false
            
        posicoes[vertice_id] = i

    for aresta in edges:
        var u_id = aresta["from"].id
        var v_id = aresta["to"].id
        
        if posicoes[u_id] > posicoes[v_id]:
            return false
            
    return true

func avaliar_resposta():

    if not verificar_ordenacao_topologica():
        set_ia_feedback("Resposta incorreta. Verifique o grafo com cuidado!")
        return
            
    set_ia_feedback("Resposta correta. Analisando feedback...")

    set_ia_feedback()

func construct_prompt() -> Dictionary:
    var params = super.construct_prompt()
    params["prompt_messages"].insert(3, 
        {
         "role": "user",
         "content": "Ordenação: " + str(get_vertexs_ids()),
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
    graph.load_graph_from_file("res://graphs/ord_top.json")
    
    list_area = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/ScrollContainer/list_area
    for v in graph.vertices:
        var v_box = VBoxContainer.new()
        var number_edit = SpinBox.new()
        v_box.add_child(number_edit)
        list_area.add_child(v_box)
    await get_tree().process_frame
