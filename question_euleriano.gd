@tool
extends Control
class_name Question

@onready var graph     : GraphEditor   = $ColorRect/SplitContainer/GraphEditor
@onready var enunciado : Label         = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/Label
@onready var resposta  : TextEdit      = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/RespostaDiscursiva
@onready var respostaIA: TextEdit      = $ColorRect/SplitContainer/VSplitContainer/RespostaIA
@onready var vertices  : Array[Vertex] = []
@onready var edges  : Array = []
@onready var llm    : LLM = $LLM

func avaliar_resposta():
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
         "content": "Arestas: " + str(edges.map(func(e): return [e["from"].id, e["to"].id, e["weight"]])),
        },
        {
         "role": "user", 
         "content": "Avalie, em até 300 caracteres, em texto plano, essa resposta e atribua uma nota de 0 a 10, justificando a nota."
        },
        {
         "role": "user", 
         "content": "O formato da resposta deve ser: 'Nota: <Nota> \n 'Justificativa:'" 
        }
        ]

    var params := {
        "prompt_messages": messages,
    }
    var result = await llm.generate_response("", params)
    #print(result["choices"][0]["message"]["content"])
    respostaIA.text = ""
    for part in result.content:
        respostaIA.text += part.candidates[0].content.parts[0].text
    print(result)
    #respostaIA.text = result["choices"][0]["message"]["content"]
        

func _ready() -> void:
    vertices = graph.vertices
    edges = graph.edges
    
    var max_v = randi_range(3,7)
    graph.max_vertices = max_v
    var max_possible_edges = round(max_v*(max_v-1)/2)
    
    graph.max_edges = randi_range(graph.max_vertices,max_possible_edges)
    enunciado.text =   ("Crie um grafo com ciclo euleriano utilizando {0} vértices e {1} arestas. " +\
                       "No campo abaixo, justifique seu raciocínio.").format([graph.max_vertices, graph.max_edges])
    
    await get_tree().process_frame
    graph.load_graph_from_file(graph.graph_file_path)

func _on_button_send_pressed() -> void:
    if vertices.size() == graph.max_vertices and edges.size() == graph.max_edges: 
        #print(vertices)
        #print(edges)
        var result = es_ciclo_euleriano()
        print("É Euleriano? ", "Sim" if result["ok"] else "Não")
        print("Ciclo: ", result["ciclo"].map(func(v): return v.id))
        if result["ok"]:
            avaliar_resposta()
        else:
            respostaIA.text = "O ciclo não é Euleriano. Revise as propriedades!"
    else:
        respostaIA.text = "O grafo deve ter {0} vértices (tem {1}) e {2} arestas (tem {3})!".format([graph.max_vertices, vertices.size(), graph.max_edges, edges.size()])

# Verifica se o grafo tem ciclo euleriano
func es_ciclo_euleriano() -> Dictionary:
    if vertices.size() == 0 or edges.size() == 0:
        return {"ok": true, "ciclo": []}
    # known[i] = se a aresta edges[i] já foi usada
    var known: Array = []
    known.resize(edges.size())
    for i in known.size():
        known[i] = false

    # Ponto de partida: "from" da primeira aresta
    var start_vert = edges[0]["from"]

    var result = busca_ciclo(start_vert, known)
    var ok = result.ok
    var ciclo = result.ciclo

    if not ok:
        return {"ok": false, "ciclo": []}
        
    # Verifica se todas as arestas foram visitadas
    var used_count = 0
    for flag in known:
        if flag:
            used_count += 1
    if used_count < edges.size():
        return {"ok": false, "ciclo": []}
    else:
        return {"ok": true, "ciclo": ciclo}

# Busca um ciclo a partir de vertice_v
func busca_ciclo(vertice_v: Variant, known: Array) -> Dictionary:
    var ciclo: Array = [vertice_v]
    var start_v = vertice_v

    while true:
        # Encontra vizinhos conectados por arestas não usadas
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
        # Usa a primeira aresta disponível
        for i in edges.size():
            var e = edges[i]
            if not known[i] and (e["from"] == vertice_v or e["to"] == vertice_v):
                known[i] = true
                vertice_v =  e['to'] if (e["from"] == vertice_v) else e["from"]
                ciclo.append(vertice_v)
                break

        if vertice_v == start_v:
            break

    # Detecta vértices do ciclo com arestas ainda não usadas
    var vertices_x: Array = []
    for v in ciclo:
        for i in edges.size():
            var e = edges[i]
            if not known[i] and (e["from"] == v or e["to"] == v) and not vertices_x.has(v):
                vertices_x.append(v)

    # Para cada vértice x, expande o ciclo
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

# Função auxiliar: retorna array de vértices vizinhos de v
func _vizinhos(v: Variant) -> Array:
    var result: Array = []
    for e in edges:
        if e["from"] == v and not result.has(e["to"]):
            result.append(e["to"])
        elif e["to"] == v and not result.has(e["from"]):
            result.append(e["from"])
    return result
