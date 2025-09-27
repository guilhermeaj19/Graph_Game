@tool
extends GraphEditor
class_name LimitedGraphEditor

@export var max_vertices: int = 4
@export var max_edges: int = 5

func add_vertex(pos: Vector2) -> Vertex:
	if vertices.size() < max_vertices:
		return super.add_vertex(pos)
	else:
		print("Max Vertices. Nothing added!")
		return null

func add_edge(origin: Vertex, destiny: Vertex) -> void:
	if edges.size() < max_edges:
		super.add_edge(origin, destiny)
	else:
		print("Max Edges. Nothing added!")
