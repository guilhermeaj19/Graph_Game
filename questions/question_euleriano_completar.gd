@tool
extends Control

@onready var graph     : PartialStaticGraphEditor   = $ColorRect/SplitContainer/GraphEditor
@onready var enunciado : Label         = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/Label
@onready var resposta  : TextEdit      = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/RespostaDiscursiva
@onready var respostaIA: TextEdit      = $ColorRect/SplitContainer/VSplitContainer/RespostaIA
@onready var buttonReturn: Button      = $ColorRect/SplitContainer/VSplitContainer/RespostaIA/ButtonReturnToMenu
@onready var vertices  : Array[Vertex] = []
@onready var edges  : Array = []
@onready var llm    : LLM = $LLM

func avaliar_resposta():
    if graph.new_vertices_list.size() == graph.max_new_vertices and graph.new_edges_list.size() == graph.max_new_edges: 
        var result = es_ciclo_euleriano()
        print("É Euleriano? ", "Sim" if result["ok"] else "Não")
        print("Ciclo: ", result["ciclo"].map(func(v): return v.id))
        if result["ok"]:
            respostaIA.text = "Grafo correto! Avaliando justificativa..."
        else:
            respostaIA.text = "O ciclo não é Euleriano. Revise as propriedades!"
            return
    else:
        respostaIA.text = "O grafo deve ter {0} vértices (tem {1}) e {2} arestas (tem {3})!".format([graph.max_new_vertices, vertices.size(), graph.max_new_edges, edges.size()])
        return
    
    var result_llm = await llm.generate_response("", construct_prompt())

    respostaIA.text = ""
    for part in result_llm.content:
        respostaIA.text += part.candidates[0].content.parts[0].text
    buttonReturn.visible = true
    #print(result)

func construct_prompt() -> Dictionary:
    var messages =  [
        {"role": "user",
         "content": "Você é um avaliador de respostas sobre questões de teoria de grafos. Avalie clareza, correção conceitual e completude da resposta."
        },
        {"role": "user",
         "content": "O enunciado da questão é: " + enunciado.text
        },
        {
         "role": "user",
         "content": "Resposta: " + resposta.text,
        },
        {
         "role": "user",
         "content": "Vértices: " + str(vertices.map(func(x): return x.id)),
        },
        {
         "role": "user",
         "content": "Arestas: " + str(edges.map(func(e): return [e["from"].id, e["to"].id])),
        },
        {
         "role": "user", 
         "content": "Avalie, em até 300 caracteres, em texto plano, essa resposta e atribua uma nota de 0 a 10, justificando a nota. O grafo estar correto vale 3, e a qualidade da justificativa vale até 7."
        },
        {
         "role": "user", 
         "content": "O formato da resposta deve ser: 'Nota: <Nota> \n 'Justificativa:'" 
        }
        ]

    var params := {
        "prompt_messages": messages,
    }
    
    return params

func _ready() -> void:
    vertices = graph.vertices
    edges = graph.edges
    
    var max_v = 0#randi_range(3,7)
    graph.max_new_vertices = max_v
    #var max_possible_edges = round(max_v*(max_v-1)/2)
    
    graph.max_new_edges = 2#randi_range(graph.max_vertices,max_possible_edges)
    enunciado.text =   ("Complete o grafo utilizando {0} vértices e {1} arestas, de forma que possua um ciclo euleriano . " +\
                       "No campo abaixo, justifique seu raciocínio.").format([graph.max_new_vertices, graph.max_new_edges])
    
    await get_tree().process_frame
    graph.load_graph_from_file("res://graphs/eulerian_incomplete_graph.json")
    
func _on_button_send_pressed() -> void:
    avaliar_resposta()

func es_ciclo_euleriano() -> Dictionary:
    if vertices.size() == 0 or edges.size() == 0:
        return {"ok": true, "ciclo": []}
    var known: Array = []
    known.resize(edges.size())
    for i in known.size():
        known[i] = false

    var start_vert = edges[0]["from"]

    var result = busca_ciclo(start_vert, known)
    var ok = result.ok
    var ciclo = result.ciclo

    if not ok:
        return {"ok": false, "ciclo": []}
        
    var used_count = 0
    for flag in known:
        if flag:
            used_count += 1
    if used_count < edges.size():
        return {"ok": false, "ciclo": []}
    else:
        return {"ok": true, "ciclo": ciclo}

func busca_ciclo(vertice_v: Variant, known: Array) -> Dictionary:
    var ciclo: Array = [vertice_v]
    var start_v = vertice_v

    while true:
        var ha_disponivel = false
        var vizinhos = _vizinhos(vertice_v)
        for viz in vizinhos:
            for i in edges.size():
                var e = edges[i]
                if not known[i] and ((e["from"] == vertice_v and e["to"] == viz) or (e["to"] == vertice_v and e["from"] == viz)):
                    ha_disponivel = true
                    break
            if ha_disponivel:
                break

        if not ha_disponivel:
            return {"ok": false, "ciclo": []}
            
        for i in edges.size():
            var e = edges[i]
            if not known[i] and (e["from"] == vertice_v or e["to"] == vertice_v):
                known[i] = true
                vertice_v =  e['to'] if (e["from"] == vertice_v) else e["from"]
                ciclo.append(vertice_v)
                break

        if vertice_v == start_v:
            break

    var vertices_x: Array = []
    for v in ciclo:
        for i in edges.size():
            var e = edges[i]
            if not known[i] and (e["from"] == v or e["to"] == v) and not vertices_x.has(v):
                vertices_x.append(v)

    for x in vertices_x:
        var res = busca_ciclo(x, known)
        if not res.ok:
            return {"ok": false, "ciclo": []}
        var ciclo2 = res.ciclo
        for idx in ciclo.size():
            if ciclo[idx] == x:
                ciclo = ciclo.slice(0,idx) + ciclo2 + ciclo.slice(idx + 1,ciclo.size())
                break

    return {"ok": true, "ciclo": ciclo}

func _vizinhos(v: Variant) -> Array:
    var result: Array = []
    for e in edges:
        if e["from"] == v and not result.has(e["to"]):
            result.append(e["to"])
        elif e["to"] == v and not result.has(e["from"]):
            result.append(e["from"])
    return result

func _on_button_return_to_menu_pressed() -> void:
    get_tree().change_scene_to_file("res://main.tscn")
