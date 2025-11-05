extends Node

var vertices: Array = []
var edges: Array = []

func set_vertices_edges(vertices_, edges_) -> void:
    vertices = vertices_
    edges = edges_

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

func bellman_ford(vertice_s: int, dirigido: bool = true):
    
    var _arestas = edges
    
    if not dirigido:
        for i in range(edges.size()):
            var e = edges[i]
            _arestas.push_back({"to": e["from"], "from": e["to"], "weight": e["weight"]})
    
    var distancia = {}
    var antecessor = {}
    
    for vertice in vertices:
        distancia[vertice] = INF
        antecessor[vertice] = null

    distancia[vertice_s] = 0

    for i in range(vertices.size() - 1):
        for aresta in _arestas:
            var u = aresta["from"]
            var v = aresta["to"]
            var peso = aresta["weight"]
            
            if distancia[u] != INF and distancia[v] > distancia[u] + peso:
                distancia[v] = distancia[u] + peso
                antecessor[v] = u
                

    for aresta in _arestas:
        var u = aresta["from"]
        var v = aresta["to"]
        var peso = aresta["weight"]
        
        if distancia[u] != INF and distancia[v] > distancia[u] + peso:
            print("ERRO: O grafo contém um ciclo de peso negativo!")
            return [false, null, null]

    return [true, distancia, antecessor]
