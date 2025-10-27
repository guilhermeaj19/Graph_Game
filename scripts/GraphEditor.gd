@tool
extends Control
class_name GraphEditor

# Sinais públicos para integração com adapters e UIs externas
signal edge_selected(edge_idx)            # emite índice da aresta clicada
signal edge_clicked(edge_idx)             # sinônimo para cliques
signal selection_changed(vertices, edges) # emite arrays de vértices e arestas selecionados
signal graph_loaded()                     # emite quando um grafo é (re)carregado
signal graph_saved(path)                  # emite quando grafo é salvo em disco
signal weight_changed(edge_idx, new_w)

@export var VertexScene: PackedScene
@export var WeightDisplayScene: PackedScene

enum State {
    IDLE,
    DRAG_VERTEX,
    CONNECT_EDGE,
    EDITING_WEIGHT
}

enum Mode {
    ADD,
    DELETE,
    SELECT,
    STATIC
}

enum TypeGraph {
    DIRIGIDO,
    NAO_DIRIGIDO
}

@export var graph_type: TypeGraph = TypeGraph.NAO_DIRIGIDO
@export var ponderado: bool = false
@export var editavel: bool = true

var mode: Mode = Mode.ADD

var vertices: Array[Vertex] = []
var edges:    Array  = []
var current_state: State = State.IDLE
var selected_vertex: Vertex = null
var dragging_pan:    bool   = false
var next_id_vertex:  int    = 0

var highlight_layer: Node2D = null
var selected_edge_indices: Array = Array()

@onready var batch_edges: MultiMeshInstance2D = $EdgesBatch
@onready var batch_arrows:  MultiMeshInstance2D = $ArrowsBatch

@export var edge_thickness: float  = 4.0
@export var edge_color:     Color  = Color.WHITE
@export var guide_line:     Color  = Color.GREEN

@onready var mode_option: OptionButton = $MarginContainer/ModeOption

@onready var weights_container: Node2D = $WeightsContainer
@onready var weight_editor: LineEdit = $WeightEditor
@export var default_weight: int = 1
var editing_edge_idx: int = -1

@export_group("File")
@export_file("*.json") var graph_file_path: String = ""
@export var load_graph_: bool = false:
    set(value):
        if value:
            call_deferred("load_graph_from_file", graph_file_path)

@export var save_graph_: bool = false:
    set(value):
        if value:
            call_deferred("save_graph_to_file", graph_file_path)

@export var clear_graph_: bool = false:
    set(value):
        if value:
            call_deferred("clear_graph")

# -------------------- Inicialização --------------------

func _ready() -> void:
    weight_editor.visible = false
    weight_editor.size = Vector2(50, 24)

    var quad = QuadMesh.new()
    quad.size = Vector2(1, 1)

    var mm = MultiMesh.new()
    mm.mesh               = quad
    mm.transform_format   = MultiMesh.TRANSFORM_2D
    mm.instance_count     = 0
    batch_edges.multimesh = mm

    if graph_type == TypeGraph.DIRIGIDO:
        var arrow_mesh = ArrayMesh.new()
        var verts3 = PackedVector3Array([
            Vector3(0, 0, 0),
            Vector3(-1, 0.5, 0),
            Vector3(-1, -0.5, 0)
        ])
        var arrays = []
        arrays.resize(ArrayMesh.ARRAY_MAX)
        arrays[ArrayMesh.ARRAY_VERTEX] = verts3
        arrow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

        var arr_mm = MultiMesh.new()
        arr_mm.mesh             = arrow_mesh
        arr_mm.transform_format = MultiMesh.TRANSFORM_2D
        arr_mm.instance_count   = 0
        batch_arrows.multimesh   = arr_mm
        batch_arrows.modulate    = edge_color
        batch_arrows.z_index     = 1

    highlight_layer = Node2D.new()
    highlight_layer.name = "_HighlightLayer"
    add_child(highlight_layer)
    highlight_layer.z_index = 100
    
    if editavel:
        if mode_option.get_item_count() == 0:
            mode_option.add_item("Add/Edit", Mode.ADD)
            mode_option.add_item("Delete", Mode.DELETE)
            mode_option.select(mode)
    else:
        mode = Mode.STATIC
        mode_option.visible = false
        
    mode_option.connect("item_selected", Callable(self, "_on_mode_changed"))
    

# -------------------- Renderização --------------------

func _draw_grafo_nao_dirigido() -> void:
    var mm  = batch_edges.multimesh
    var gt  = get_global_transform_with_canvas()
    var inv = gt.affine_inverse()

    mm.instance_count = edges.size()
    for i in range(edges.size()):
        var e   = edges[i]
        var a_l = inv * e["from"].global_position
        var b_l = inv * e["to"].global_position
        var dir = b_l - a_l
        var len_ = dir.length()
        var ang = dir.angle()

        var t = Transform2D.IDENTITY.scaled(Vector2(len_, edge_thickness)).rotated(ang).translated(a_l + dir * 0.5)

        mm.set_instance_transform_2d(i, t)

        if ponderado:
            var weight_display = weights_container.get_child(i) as WeightDisplay
            if weight_display and editing_edge_idx != i:
                weight_display.global_position = gt * (a_l + dir * 0.5)
                weight_display.update_text_and_resize(str(edges[i]["weight"]))

func _draw_grafo_dirigido() -> void:
    var ml = batch_edges.multimesh
    var ma = batch_arrows.multimesh
    var gt  = get_global_transform_with_canvas()
    ml.instance_count = edges.size()
    ma.instance_count = edges.size()

    for i in range(edges.size()):
        var seg = _get_edge_segment(edges[i])
        if seg == {}:
            continue

        var len_      = seg["end"].distance_to(seg["start"])
        var mid_pt   = (seg["start"] + seg["end"]) * 0.5
        var t_line   = Transform2D.IDENTITY.scaled(Vector2(len_, edge_thickness)).rotated(seg["angle"]).translated(mid_pt)
        ml.set_instance_transform_2d(i, t_line)

        var t_arrow  = Transform2D.IDENTITY.scaled(Vector2(edge_thickness * 4, edge_thickness * 4)).rotated(seg["angle"]).translated(seg["tip"])
        ma.set_instance_transform_2d(i, t_arrow)

        if ponderado:
            var weight_display = weights_container.get_child(i) as Control
            var e = edges[i]
            if weight_display and editing_edge_idx != i:
                weight_display.global_position = gt * mid_pt
                weight_display.update_text_and_resize(str(e["weight"]))

func _draw() -> void:
    if selected_vertex and current_state == State.CONNECT_EDGE:
        var a = (selected_vertex.global_position 
                 - get_global_position())       
        var b = get_local_mouse_position()
        draw_line(a, b, guide_line, edge_thickness)

    if graph_type == TypeGraph.NAO_DIRIGIDO:
        _draw_grafo_nao_dirigido()
    else:
        _draw_grafo_dirigido()

# -------------------- Input / Estados --------------------

func _input(event: InputEvent) -> void:
    var mouse_position = get_local_mouse_position()
    var graph_rect = Rect2(Vector2.ZERO, get_size())

    if not graph_rect.has_point(mouse_position):
        return

    if event is InputEventMouseButton and mode_option.get_global_rect().has_point(event.position):
        return

    _unhandled_input(event)

func _unhandled_input(event: InputEvent) -> void:
    match current_state:
        State.IDLE:
            _state_idle_input(event)
        State.DRAG_VERTEX:
            _state_drag_input(event)
        State.CONNECT_EDGE:
            _state_connect_input(event)
        State.EDITING_WEIGHT:
            _state_editing_weight_input(event)

func _state_editing_weight_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_ENTER, KEY_KP_ENTER:
                if _on_weight_edit_finished(editing_edge_idx):
                    current_state = State.IDLE
                    queue_redraw()
            KEY_ESCAPE:
                weight_editor.visible = false
                var label = weights_container.get_child(editing_edge_idx) as WeightDisplay
                if label:
                    label.visible = true
                editing_edge_idx = -1
                current_state = State.IDLE
                queue_redraw()

func _state_idle_input(event) -> void:
    if event is InputEventMouseButton and event.pressed:
        var hit_vertex = _pick_vertex_at(event.position)
        var hit_edge   = _pick_edge_at(event.position)
        match event.button_index:
            MOUSE_BUTTON_MASK_LEFT:
                if mode == Mode.ADD:
                    if hit_vertex:
                        selected_vertex = hit_vertex
                        selected_vertex.drag()
                        current_state = State.DRAG_VERTEX
                    elif hit_edge >= 0 and ponderado:
                        current_state = State.EDITING_WEIGHT
                        _start_editing_weight(hit_edge)
                    else:
                        add_vertex(event.position)
                elif mode == Mode.DELETE:
                    if hit_vertex:
                        remove_vertex(hit_vertex)
                    elif hit_edge >= 0:
                        _remove_edge_by_index(hit_edge)
                elif mode == Mode.SELECT:
                    if hit_edge >= 0:
                        _toggle_select_edge(hit_edge)
                        emit_signal("edge_clicked", hit_edge)
                else:
                    return
            MOUSE_BUTTON_MASK_RIGHT:
                if hit_vertex:
                    selected_vertex = hit_vertex
                    selected_vertex.select()
                    current_state = State.CONNECT_EDGE
        queue_redraw()

func _state_drag_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and selected_vertex:
        selected_vertex.global_position += event.relative
        queue_redraw()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        selected_vertex.idle()
        selected_vertex = null
        current_state = State.IDLE
        queue_redraw()

func _state_connect_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        queue_redraw()

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            var hit = _pick_vertex_at(event.position)
            if hit and hit != selected_vertex:
                    add_edge(selected_vertex, hit)

            selected_vertex.idle()
            selected_vertex = null
            current_state = State.IDLE

        queue_redraw()

# -------------------- Eventos de clique em vértice --------------------

func _on_vertex_clicked(v: Vertex) -> void:
    if not selected_vertex:
        selected_vertex = v
        v.select()
    else:
        if v != selected_vertex:
            add_edge(selected_vertex, v)
            queue_redraw()
        selected_vertex.idle()
        selected_vertex = null

# -------------------- CRUD vértices/arestas --------------------
func clear_graph():
    for child in weights_container.get_children():
        child.queue_free()
        
    for v in vertices:
        v.queue_free()
    vertices.clear()
    edges.clear()
    
    next_id_vertex = 0
    queue_redraw()

func add_vertex(pos: Vector2) -> Vertex:
    var v = VertexScene.instantiate() as Vertex
    add_child(v)
    v.set_id(next_id_vertex)
    v.global_position = pos
    vertices.append(v)
    next_id_vertex += 1
    #print("Vertices:", vertices.map(func(x): return x.id))
    return v

func remove_vertex(v: Vertex) -> void:
    var remaining_edges = []
    var removed_indices = []
    for i in range(edges.size()):
        var e = edges[i]
        if e["from"] != v and e["to"] != v:
            remaining_edges.append(e)
        else:
            removed_indices.append(i)

    for i in range(removed_indices.size(),):
        if weights_container.get_child_count() > i:
            weights_container.get_child(i).queue_free()

    edges = remaining_edges
    vertices.erase(v)
    v.queue_free()

func add_edge(origin: Vertex, destiny: Vertex) -> Dictionary:
    if not _edge_exists(origin, destiny):
        var new_edge = { "from": origin, "to": destiny, "weight": default_weight }
        edges.append(new_edge)

        if ponderado:
            var weight_display = WeightDisplayScene.instantiate() as WeightDisplay
            weights_container.add_child(weight_display)
            weight_display.update_text_and_resize(str(new_edge["weight"]))
        return new_edge
    else:
        pass
        return {}
        #print("The edge {0}--{1} already exists".format([origin.id, destiny.id]))
    #print("Edges:", edges.map(func(e): return [e["from"].id, e["to"].id, e["weight"]] ))

func _remove_edge_by_index(idx: int) -> void:
    if idx >= 0 and idx < edges.size():
        edges.remove_at(idx)
        if weights_container.get_child_count() > idx:
            weights_container.get_child(idx).queue_free()

func _edge_exists(origin: Vertex, destiny: Vertex) -> bool:
    if graph_type == TypeGraph.NAO_DIRIGIDO:
        for e in edges:
            if e['from'] == origin and e['to'] == destiny or e['to'] == origin and e['from'] == destiny:
                return true
        return false
    else:
        for e in edges:
            if e['from'] == origin and e['to'] == destiny:
                return true
        return false

func _on_mode_changed(index:int) -> void:
    mode = index as Mode
    
    if mode != Mode.SELECT:
        clear_highlights()
# -------------------- Picking --------------------

func _pick_vertex_at(pos: Vector2) -> Vertex:
    for v in vertices:
        if v.global_position.distance_to(pos) <= v.radius:
            return v
    return null

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
    var ab = b - a
    var t = (p - a).dot(ab) / ab.length_squared()
    t = clamp(t, 0.0, 1.0)
    var proj = a + ab * t
    return p.distance_to(proj)

func _pick_edge_at(click_pos: Vector2) -> int:
    if graph_type == TypeGraph.NAO_DIRIGIDO:
        return _pick_edge_nao_dirigido_at(click_pos)
    else:
        return _pick_edge_dirigido_at(click_pos)

func _get_edge_segment(e: Dictionary) -> Dictionary:
    var gt   = get_global_transform_with_canvas()
    var inv  = gt.affine_inverse()
    var v1   = e["from"]
    var v2   = e["to"]
    var a    = inv * v1.global_position
    var b    = inv * v2.global_position

    var raw_dir = b - a
    if raw_dir.length() < 1e-3:
        return {}

    var dir_n      = raw_dir.normalized()
    var ang        = raw_dir.angle()

    var has_rev := false
    for other in edges:
        if other["from"] == v2 and other["to"] == v1:
            has_rev = true
            break

    var base_dir   = raw_dir if (v1.id < v2.id) else -raw_dir
    base_dir       = base_dir.normalized()
    var perp       = Vector2(-base_dir.y, base_dir.x)
    var sign_       = 1 if (v1.id < v2.id) else -1
    var offset_amt = edge_thickness * 2.3
    var offset_vec = perp * offset_amt * sign_ if has_rev else Vector2.ZERO

    var margin_to  = v2.radius
    var arrow_sz   = edge_thickness * 4

    var start_pt   = a + offset_vec
    var tip_pt     = b - dir_n * margin_to + offset_vec
    var base_pt    = tip_pt - dir_n * arrow_sz

    return {
        "start": start_pt,
        "end":   base_pt,
        "tip":   tip_pt,
        "angle": ang
    }

func _pick_edge_nao_dirigido_at(click_pos: Vector2) -> int:
    var gt  = get_global_transform_with_canvas()
    var inv = gt.affine_inverse()
    var local_click = inv * click_pos

    var best_idx  = -1
    var best_dist = edge_thickness * 1.2

    for i in range(edges.size()):
        var e = edges[i]
        var a = inv * e["from"].global_position
        var b = inv * e["to"].global_position

        var d = _distance_to_segment(local_click, a, b)
        if d < best_dist:
            best_dist = d
            best_idx  = i
    return best_idx

func _pick_edge_dirigido_at(click_pos: Vector2) -> int:
    var gt          = get_global_transform_with_canvas()
    var inv         = gt.affine_inverse()
    var local_click = inv * click_pos
    var best_idx    = -1
    var best_dist   = edge_thickness * 1.2

    for i in range(edges.size()):
        var seg = _get_edge_segment(edges[i])
        if seg == {}:
            continue
        var d = _distance_to_segment(local_click, seg["start"], seg["end"])
        if d < best_dist:
            best_dist = d
            best_idx  = i
    return best_idx

# -------------------- Edição peso --------------------

func _start_editing_weight(edge_idx: int) -> bool:
    editing_edge_idx = edge_idx
    var edge = edges[edge_idx]
    var label = weights_container.get_child(edge_idx) as WeightDisplay

    if label:
        label.visible = false

    weight_editor.global_position = label.global_position if label else Vector2.ZERO
    weight_editor.text = str(edge["weight"])
    weight_editor.visible = true

    weight_editor.grab_focus()
    weight_editor.select_all()
    return true

func _on_weight_edit_finished(edge_idx: int) -> bool:
    var new_text = weight_editor.text

    if new_text.is_valid_float():
        edges[edge_idx]["weight"] = int(new_text)
        emit_signal("weight_changed", edge_idx, int(new_text))
    else:
        print("INPUT INVALID")
        return false

    weight_editor.visible = false

    var label = weights_container.get_child(edge_idx) as WeightDisplay
    if label:
        label.visible = true

    editing_edge_idx = -1
    return true

# -------------------- Export / Import JSON públicos --------------------

func build_from_json(data: Dictionary) -> void:
    clear_graph()
    var container_size = get_size()
    var meta = data.get("meta", {})
    var type_str = meta.get("graph_type", "NAO_DIRIGIDO")

    self.graph_type = TypeGraph.DIRIGIDO if type_str == "DIRIGIDO" else TypeGraph.NAO_DIRIGIDO
    ponderado = meta.get("ponderado", false)

    var id_to_vertex_map = {}
    var loaded_vertices = data.get("vertices", [])
    for v_data in loaded_vertices:
        var normalized_pos = Vector2(v_data.get("pos_x", 0.5), v_data.get("pos_y", 0.5))
        var local_pos = normalized_pos * container_size
        var global_pos = local_pos + get_global_position()
        var new_v = add_vertex(global_pos)
        new_v.set_id(int(v_data.get("id", 0)))
        id_to_vertex_map[v_data.get("id")] = new_v

    var loaded_edges = data.get("edges", [])
    for e_data in loaded_edges:
        var from_v = id_to_vertex_map.get(e_data.get("from_id"))
        var to_v = id_to_vertex_map.get(e_data.get("to_id"))

        if from_v and to_v:
            add_edge(from_v, to_v)
            var added_edge = edges.back()
            added_edge["weight"] = int(e_data.get("weight", default_weight))

    next_id_vertex = int(meta.get("next_id_vertex", next_id_vertex))
    queue_redraw()
    emit_signal("graph_loaded")

func export_graph_json() -> Dictionary:
    var container_size = get_size()
    var graph_data = {
        "meta": {
            "graph_type": "DIRIGIDO" if graph_type == TypeGraph.DIRIGIDO else "NAO_DIRIGIDO",
            "ponderado": ponderado,
            "next_id_vertex": next_id_vertex
        },
        "vertices": [],
        "edges": []
    }
    for v in vertices:
        var local_pos = v.global_position - get_global_position()
        var normalized_pos_x = local_pos.x / container_size.x if container_size.x != 0 else 0.0
        var normalized_pos_y = local_pos.y / container_size.y if container_size.y != 0 else 0.0
        graph_data["vertices"].append({"id": v.id, "pos_x": normalized_pos_x, "pos_y": normalized_pos_y})
    for e in edges:
        graph_data["edges"].append({"from_id": e["from"].id, "to_id": e["to"].id, "weight": e.get("weight", default_weight)})
    return graph_data

# -------------------- Lookups e utilitários públicos --------------------

func find_edge(u_id, v_id) -> int:
    for i in range(edges.size()):
        var e = edges[i]
        if e["from"].id == u_id and e["to"].id == v_id:
            return i
        if graph_type == TypeGraph.NAO_DIRIGIDO and e["from"].id == v_id and e["to"].id == u_id:
            return i
    return -1

func edge_to_ends(edge_idx: int) -> Dictionary:
    if edge_idx >= 0 and edge_idx < edges.size():
        var e = edges[edge_idx]
        return {"u": e["from"].id, "v": e["to"].id}
    return {}

func get_public_vertices():
    return vertices

func get_public_edges():
    return edges

func enable_editing(enabled: bool) -> void:
    mode = Mode.ADD if enabled else Mode.STATIC
    if mode_option:
        mode_option.select(int(mode))

func set_creation_enabled(enabled: bool) -> void:
    enable_editing(enabled)

func clear_selection() -> void:
    selected_edge_indices = Array()
    # limpa seleção visual de vértices também
    if selected_vertex:
        selected_vertex.idle()
        selected_vertex = null
    _update_highlight_visuals()
    emit_signal("selection_changed", [], [])

func clear_highlights() -> void:
    selected_edge_indices = Array()
    _update_highlight_visuals()

# -------------------- Seleção multi-aresta e highlights overlay --------------------

func _toggle_select_edge(idx: int) -> void:
    if idx < 0:
        return
    var arr = selected_edge_indices
    var found = false
    for i in range(arr.size()):
        if arr[i] == idx:
            arr.remove(i)
            found = true
            break
    if not found:
        arr.append(idx)
    selected_edge_indices = arr
    _update_highlight_visuals()
    # constrói arrays de vértices e arestas selecionadas para o sinal
    var sel_edges = []
    var sel_vertices = []
    for i in range(selected_edge_indices.size()):
        var e = edges[selected_edge_indices[i]]
        sel_edges.append(selected_edge_indices[i])
        sel_vertices.append(e["from"].id)
        sel_vertices.append(e["to"].id)
    emit_signal("selection_changed", sel_vertices, sel_edges)

func _update_highlight_visuals() -> void:
    # remove filhos antigos
    for c in highlight_layer.get_children():
        c.queue_free()

    for i in range(selected_edge_indices.size()):
        var idx = selected_edge_indices[i]
        if idx < 0 or idx >= edges.size():
            continue
        var e = edges[idx]
        var line = Line2D.new()
        line.width = max(edge_thickness * 1.6, 2.0)
        line.gradient = null
        line.default_color = Color(0.952, 0.349, 0.372, 0.9) # vermelho por padrão para seleção
        var gt = get_global_transform_with_canvas()
        var inv = gt.affine_inverse()
        var a = inv * e["from"].global_position
        var b = inv * e["to"].global_position
        line.points = [a, b]
        highlight_layer.add_child(line)

# -------------------- Utils e helpers --------------------

func _noop(): pass

func _remove_all_weights_children():
    for c in weights_container.get_children():
        c.queue_free()

# -------------------- Salvamento / Carregamento --------------------

func load_graph_from_file(filepath: String) -> void:
    if not FileAccess.file_exists(filepath):
        push_error("Arquivo de grafo não encontrado: " + filepath)
        return

    var file = FileAccess.open(filepath, FileAccess.READ)
    var content = file.get_as_text()
    file.close()

    var data = JSON.parse_string(content)
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Arquivo JSON inválido ou corrompido.")
        return

    build_from_json(data)
    emit_signal("graph_loaded")

func save_graph_to_file(filepath: String) -> void:
    if filepath.is_empty():
        push_error("Caminho do arquivo para salvar está vazio.")
        return

    var json_string = JSON.stringify(export_graph_json(), "  ")
    var file = FileAccess.open(filepath, FileAccess.WRITE)
    if not FileAccess.get_open_error() == OK:
        push_error("Falha ao abrir o arquivo para escrita: " + filepath)
        return

    file.store_string(json_string)
    file.close()
    emit_signal("graph_saved", filepath)
    print("Grafo salvo com sucesso em: ", filepath)
