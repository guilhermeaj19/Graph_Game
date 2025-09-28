@tool
extends Control
class_name GraphEditor

@export var VertexScene: PackedScene

enum State {
    IDLE,          
    DRAG_VERTEX,  
    CONNECT_EDGE,
}

enum TypeGraph {
    DIRIGIDO,
    NAO_DIRIGIDO
}

@export var graph_type: TypeGraph = TypeGraph.NAO_DIRIGIDO

var vertices: Array[Vertex] = []
var edges:    Array  = []
var current_state: State = State.IDLE
var selected_vertex: Vertex = null
var dragging_pan:    bool   = false
var next_id_vertex:  int    = 0

@onready var batch_edges: MultiMeshInstance2D = $EdgesBatch
@onready var batch_arrows:  MultiMeshInstance2D = $ArrowsBatch

@export var edge_thickness: float  = 4.0
@export var edge_color:     Color  = Color.WHITE
@export var guide_line:     Color  = Color.GREEN

@onready var toggle_button: CheckButton = $MarginContainer/CheckButton

func _ready() -> void:

    if not batch_edges:
        push_error("❌ batch é null — nó 'EdgesBatch' não foi encontrado.")
        return

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
        var len = dir.length()
        var ang = dir.angle()

        var t = Transform2D.IDENTITY.scaled(Vector2(len, edge_thickness)).rotated(ang).translated(a_l + dir * 0.5)

        mm.set_instance_transform_2d(i, t)

func _draw_grafo_dirigido() -> void:
    var ml = batch_edges.multimesh
    var ma = batch_arrows.multimesh
    ml.instance_count = edges.size()
    ma.instance_count = edges.size()

    for i in range(edges.size()):
        var seg = _get_edge_segment(edges[i])
        if seg == {}:
            continue

        # linha
        var len      = seg["end"].distance_to(seg["start"])
        var mid_pt   = (seg["start"] + seg["end"]) * 0.5
        var t_line   = Transform2D.IDENTITY.scaled(Vector2(len, edge_thickness)).rotated(seg["angle"]).translated(mid_pt)
        ml.set_instance_transform_2d(i, t_line)

        # ponta
        var t_arrow  = Transform2D.IDENTITY.scaled(Vector2(edge_thickness * 4, edge_thickness * 4)).rotated(seg["angle"]).translated(seg["tip"])
        ma.set_instance_transform_2d(i, t_arrow)

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

func _input(event: InputEvent) -> void:
    var mouse_position = get_local_mouse_position()
    var graph_rect = Rect2(Vector2.ZERO, get_size())
    
    if not graph_rect.has_point(mouse_position):
        return
        
    if toggle_button.get_global_rect().has_point(event.position):
        return  # clique foi 

    _unhandled_input(event)
    if event is InputEventMouseButton:
        
        match event.button_index:
            #MOUSE_BUTTON_WHEEL_UP:
                #scale *= 1.1
            #MOUSE_BUTTON_WHEEL_DOWN:
                #scale /= 1.1
            MOUSE_BUTTON_MIDDLE:
                dragging_pan = event.pressed

func _unhandled_input(event: InputEvent) -> void:
    match current_state:
        State.IDLE:
            _state_idle_input(event)
        State.DRAG_VERTEX:
            _state_drag_input(event)
        State.CONNECT_EDGE:
            _state_connect_input(event)

func _state_idle_input(event) -> void:
    if event is InputEventMouseButton and event.pressed:
        var hit_vertex = _pick_vertex_at(event.position)
        var hit_edge   = _pick_edge_at(event.position)
        print(hit_edge)
        match event.button_index:
            MOUSE_BUTTON_MASK_LEFT:
                if toggle_button.text == 'Add':   
                    if hit_vertex:
                        selected_vertex = hit_vertex
                        selected_vertex.drag()
                        current_state = State.DRAG_VERTEX
                    else:
                        add_vertex(event.position)
                else:
                    if hit_vertex:
                        remove_vertex(hit_vertex)
                    elif hit_edge >= 0:
                        edges.remove_at(hit_edge)
            MOUSE_BUTTON_MASK_RIGHT:
                if hit_vertex:
                    selected_vertex = hit_vertex
                    selected_vertex.select()
                    current_state = State.CONNECT_EDGE
        queue_redraw()

func _state_drag_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and selected_vertex:
        # move vértice
        selected_vertex.global_position += event.relative
        queue_redraw()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        # solta e volta para IDLE
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

func add_vertex(pos: Vector2) -> Vertex:
    var v = VertexScene.instantiate() as Vertex
    add_child(v)
    v.set_id(next_id_vertex)
    v.global_position = pos
    vertices.append(v)
    next_id_vertex += 1
    print("Vertices:", vertices.map(func(x): return x.id))
    return v

func remove_vertex(v: Vertex) -> void:
    edges = edges.filter(func(e):
        return e["from"] != v and e["to"] != v
    )

    vertices.erase(v)
    v.queue_free()
    
func add_edge(origin: Vertex, destiny: Vertex) -> void:
    if not _edge_exists(origin, destiny):
        edges.append({ "from": origin, "to": destiny })
    else:
        print("The edge {0}--{1} already exists".format([origin.id, destiny.id]))
    print("Edges:", edges.map(func(e): return [e["from"].id, e["to"].id] ))

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
    # 1. transform global→local
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

    # 2. detecta reversa
    var has_rev := false
    for other in edges:
        if other["from"] == v2 and other["to"] == v1:
            has_rev = true
            break

    # 3. calcula offset perp
    var base_dir   = raw_dir if (v1.id < v2.id) else -raw_dir
    base_dir       = base_dir.normalized()
    var perp       = Vector2(-base_dir.y, base_dir.x)
    var sign       = 1 if (v1.id < v2.id) else -1
    var offset_amt = edge_thickness * 2.3
    var offset_vec = perp * offset_amt * sign if has_rev else Vector2.ZERO

    # 4. marge to e tamanho da seta
    var margin_to  = v2.radius
    var arrow_sz   = edge_thickness * 4

    # 5. define pontos com offset
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

    # Itera todas arestas
    for i in range(edges.size()):
        var e = edges[i]
        # transforma os endpoints no espaço local
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
