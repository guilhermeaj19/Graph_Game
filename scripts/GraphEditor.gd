@tool
extends Control
class_name GraphEditor

@export var VertexScene: PackedScene
@export var edge_thickness: float  = 4.0
@export var edge_color:     Color  = Color.WHITE
@export var guide_line:     Color  = Color.GREEN

enum State {
	IDLE,          
	DRAG_VERTEX,  
	CONNECT_EDGE,
}

enum TypeGraph {
	DIRIGIDO,
	NAO_DIRIGIDO
}

@export var type: TypeGraph = TypeGraph.NAO_DIRIGIDO

var vertices: Array[Vertex] = []
var edges:    Array  = []
var current_state: State = State.IDLE
var selected_vertex: Vertex = null
var dragging_pan:    bool   = false
var next_id_vertex:  int    = 0


@onready var batch: MultiMeshInstance2D = $EdgesBatch
@onready var toggle_button: CheckButton = $MarginContainer/CheckButton

func _ready() -> void:

	if not batch:
		push_error("❌ batch é null — nó 'EdgesBatch' não foi encontrado.")
		return

	var quad = QuadMesh.new()
	quad.size = Vector2(1, 1)

	var mm = MultiMesh.new()
	mm.mesh             = quad
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.instance_count   = 0
	batch.multimesh     = mm

func _update_edges_batch() -> void:
	var mm  = batch.multimesh
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

func _draw() -> void:
	if selected_vertex and current_state == State.CONNECT_EDGE:
		var a = (selected_vertex.global_position 
				 - get_global_position())       
		var b = get_local_mouse_position()
		draw_line(a, b, guide_line, edge_thickness)

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
		var hit = _pick_vertex_at(event.position)
		match event.button_index:
			MOUSE_BUTTON_MASK_LEFT:
				if hit:
					selected_vertex = hit
					selected_vertex.drag()
					current_state = State.DRAG_VERTEX
				else:
					add_vertex(event.position)
			MOUSE_BUTTON_MASK_RIGHT:
				if hit:
					selected_vertex = hit
					selected_vertex.select()
					current_state = State.CONNECT_EDGE
		queue_redraw()
		_update_edges_batch()

func _state_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and selected_vertex:
		# move vértice
		selected_vertex.global_position += event.relative
		_update_edges_batch()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# solta e volta para IDLE
		selected_vertex.idle()
		selected_vertex = null
		current_state = State.IDLE
		queue_redraw()
		_update_edges_batch()

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
		_update_edges_batch()

func _on_vertex_clicked(v: Vertex) -> void:
	if not selected_vertex:
		selected_vertex = v
		v.select()
	else:
		if v != selected_vertex:
			add_edge(selected_vertex, v)
			_update_edges_batch()
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

func add_edge(origin: Vertex, destiny: Vertex) -> void:
	if not _edge_exists(origin, destiny):
		edges.append({ "from": origin, "to": destiny })
	else:
		print("The edge {0}--{1} already exists".format([origin.id, destiny.id]))
	print("Edges:", edges.map(func(e): return [e["from"].id, e["to"].id] ))

func _edge_exists(origin: Vertex, destiny: Vertex) -> bool:
	for e in edges:
		if e['from'] == origin and e['to'] == destiny or e['to'] == origin and e['from'] == destiny:
			return true
	return false
	
func _pick_vertex_at(pos: Vector2) -> Vertex:
	for v in vertices:
		if v.global_position.distance_to(pos) <= v.radius:
			return v
	return null
