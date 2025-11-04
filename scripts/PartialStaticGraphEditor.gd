@tool
extends GraphEditor
class_name PartialStaticGraphEditor

@export var max_new_vertices: int = 4
@export var max_new_edges: int = 4
@export var new_vertices_list: Array = []
@export var new_edges_list: Array = []
var graph_is_loaded: bool = false

func _ready() -> void:
    super._ready()
    self.connect("graph_loaded", Callable(self, "graph_finish_loaded"))

func graph_finish_loaded():
    graph_is_loaded = true

func _pick_edge_at(click_pos: Vector2) -> int:
    var e_index = super._pick_edge_at(click_pos)
    if e_index >= 0 and edges[e_index] in new_edges_list:
        return e_index
    else:
        return -1

func remove_vertex(v: Vertex) -> void:
    if v in new_vertices_list:
        new_vertices_list.erase(v)
        super.remove_vertex(v)
    else:
        print("Its not a new vertex. Nothing removed!")

func _remove_edge_by_index(idx: int) -> void:
    if edges[idx] in new_edges_list:
        new_edges_list.erase(edges[idx])
        super._remove_edge_by_index(idx)
    else:
        print("Its not a new edge. Nothing removed!")
        
func add_vertex(pos: Vector2) -> Vertex:
    if not graph_is_loaded: 
        return super.add_vertex(pos)
    
    if new_vertices_list.size() < max_new_vertices:
        var v = super.add_vertex(pos)
        print(v)
        if v:
            new_vertices_list.append(v)
        return v
    else:
        print("Max Vertices. Nothing added!")
        return null

func add_edge(origin: Vertex, destiny: Vertex) -> Dictionary:
    if not graph_is_loaded: 
        return super.add_edge(origin, destiny)
        
    
    if new_edges_list.size() < max_new_edges:
        var e = super.add_edge(origin, destiny)
        print(e)
        if e != {}:
            new_edges_list.append(e)
        print(new_edges_list)
        return e
    else:
        print("Max Edges. Nothing added!")
        return {}
