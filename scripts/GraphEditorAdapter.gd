extends Node

signal selection_changed(selected_vertices, selected_edges)
signal graph_loaded()

@export var graph_editor_scene: PackedScene 

var editor_node: Control = null
var parent_control: Control = null

# estado interno (cache simples)
var last_selected_vertices: Array = []
var last_selected_edges: Array = []

func _ready():
    pass

# ---------------- Instanciação / Layout ----------------

func set_parent_node(parent: Control) -> void:
    parent_control = parent
    if editor_node:
        if editor_node.get_parent():
            editor_node.get_parent().remove_child(editor_node)
        parent_control.add_child(editor_node)
        editor_node.rect_min_size = parent_control.rect_size if editor_node.has_method("rect_min_size") else editor_node.rect_min_size
    else:
        if graph_editor_scene:
            editor_node = graph_editor_scene.instantiate() as Control
            parent_control.add_child(editor_node)
        else:
            push_error("GraphEditorAdapter: graph_editor_scene não setado")
            return
    _connect_editor_signals()

func _connect_editor_signals() -> void:
    if not editor_node:
        return
    if editor_node.has_signal("selection_changed"):
        editor_node.connect("selection_changed", Callable(self, "_on_editor_selection_changed"))
    elif editor_node.has_signal("edge_clicked"):
        # fallback: edge_clicked provides edge index; map to selection signal
        editor_node.connect("edge_clicked", Callable(self, "_on_editor_edge_clicked"))
    if editor_node.has_signal("graph_loaded"):
        editor_node.connect("graph_loaded", Callable(self, "_on_editor_graph_loaded"))
    if editor_node.has_signal("graph_saved"):
        # não processado aqui, mas conectável externamente
        pass

# ---------------- Carregar / Exportar ----------------

func set_graph_from_json(json: Dictionary) -> void:
    if not editor_node:
        push_error("GraphEditorAdapter: editor_node ausente em set_graph_from_json")
        return
    if editor_node.has_method("build_from_json"):
        editor_node.call("build_from_json", json)
    else:
        # fallback: se editor não tiver build_from_json, tentar carregar via load_graph_from_file não aplicável aqui
        push_error("GraphEditorAdapter: GraphEditor não implementa build_from_json. Adapte o GraphEditor ou o adapter.")
        return
    emit_signal("graph_loaded")

func get_graph_json() -> Dictionary:
    if not editor_node:
        return {}
    if editor_node.has_method("export_graph_json"):
        return editor_node.call("export_graph_json")
    elif editor_node.has_method("save_graph_to_file"):
        # como fallback, pedir export via save em string não ideal — prefer export_graph_json
        push_error("GraphEditorAdapter: GraphEditor não implementa export_graph_json. Implementar para compatibilidade.")
        return {}
    else:
        return {}

# ---------------- Edição / seleção / bloqueio ----------------

func lock_edit(allow_selection_only: bool) -> void:
    if not editor_node:
        return
    # enable_editing(enabled) expects enabled=true to allow creation (per GraphEditor)
    if editor_node.has_method("enable_editing"):
        editor_node.call("enable_editing", not allow_selection_only)
    if editor_node.has_method("set_creation_enabled"):
        editor_node.call("set_creation_enabled", not allow_selection_only)
    # sincroniza controle visual se option button existir
    if editor_node.has_node("MarginContainer/ModeOption"):
        var opt = editor_node.get_node("MarginContainer/ModeOption") as OptionButton
        if opt:
            opt.visible = false
            opt.select(0 if allow_selection_only else 1)

func clear_selection() -> void:
    if not editor_node:
        return
    if editor_node.has_method("clear_selection"):
        editor_node.call("clear_selection")
    # reset local cache and emit
    last_selected_vertices = []
    last_selected_edges = []
    emit_signal("selection_changed", last_selected_vertices, last_selected_edges)

func clear_highlights() -> void:
    if not editor_node:
        return
    if editor_node.has_method("clear_highlights"):
        editor_node.call("clear_highlights")
    # também atualiza overlay se necessário (GraphEditor já tem clear_highlights)
    # nada mais a fazer

func get_user_selected_edges() -> Array:
    # tenta recuperar seleção diretamente do editor via signal/cache
    if last_selected_edges:
        return last_selected_edges.duplicate()
    # fallback: se editor expõe selected_edge_indices, mapear para edges
    if editor_node and editor_node.has_method("get_public_edges"):
        var eds = editor_node.call("get_public_edges")
        # procurar índices selecionados se existir selected_edge_indices
        if editor_node.has_method("selected_edge_indices"):
            var idxs = editor_node.call("selected_edge_indices")
            var out = []
            for i in idxs:
                if i >= 0 and i < eds.size():
                    var e = eds[i]
                    out.append({"u": e["from"].id, "v": e["to"].id})
            return out
    return []

# ---------------- Manipulação de clique/seleção vinda do editor ----------------

func _on_editor_selection_changed(sel_vertices, sel_edges) -> void:
    # editor emite (vertices, edges) conforme nova versão sugerida
    last_selected_vertices = sel_vertices.duplicate() if typeof(sel_vertices) == TYPE_ARRAY else []
    # sel_edges pode ser array de índices; precisamos normalizar para array de {u,v}
    last_selected_edges = []
    if typeof(sel_edges) == TYPE_ARRAY:
        if editor_node and editor_node.has_method("get_public_edges"):
            var eds = editor_node.call("get_public_edges")
            for s in sel_edges:
                if typeof(s) == TYPE_INT and s >= 0 and s < eds.size():
                    var e = eds[s]
                    last_selected_edges.append({"u": e["from"].id, "v": e["to"].id})
                elif typeof(s) == TYPE_DICTIONARY and s.has("u") and s.has("v"):
                    last_selected_edges.append({"u": s.u, "v": s.v})
    emit_signal("selection_changed", last_selected_vertices, last_selected_edges)

func _on_editor_edge_clicked(edge_idx: int) -> void:
    # mapa índice para {u,v} e emite selection_changed com single edge
    last_selected_edges = []
    if editor_node and editor_node.has_method("get_public_edges"):
        var eds = editor_node.call("get_public_edges")
        if edge_idx >= 0 and edge_idx < eds.size():
            var e = eds[edge_idx]
            last_selected_edges.append({"u": e["from"].id, "v": e["to"].id})
            # opcional: obter vertices ids list
            var verts = [e["from"].id, e["to"].id]
            emit_signal("selection_changed", verts, last_selected_edges)
            return
    emit_signal("selection_changed", [], [])

func _on_editor_graph_loaded() -> void:
    emit_signal("graph_loaded")

# ---------------- Destaque de arestas ----------------

# edges_arr: array de {"u":id,"v":id} ou array de pairs [u,v]
func highlight_edges(edges_arr: Array, color: Color=Color(0,1,0)) -> void:
    if not editor_node:
        return
    # Tentativa direta: se GraphEditor expõe find_edge e clear_highlights, usar
    if editor_node.has_method("clear_highlights"):
        editor_node.call("clear_highlights")
    var mapped_indices := []
    if editor_node.has_method("find_edge"):
        for e in edges_arr:
            var u = null
            var v = null
            if typeof(e) == TYPE_DICTIONARY and e.has("u") and e.has("v"):
                u = e.u; v = e.v
            elif typeof(e) == TYPE_ARRAY and e.size() >= 2:
                u = e[0]; v = e[1]
            if u != null and v != null:
                var idx = editor_node.call("find_edge", u, v)
                if idx >= 0:
                    mapped_indices.append(idx)
        # se editor tem selected_edge_indices, setá-los para aproveitar overlay
        if editor_node.has_method("selected_edge_indices"):
            editor_node.call("selected_edge_indices", mapped_indices)
        else:
            # fallback: se editor tem função para selecionar via API, emite seleção_changed manualmente
            var sel_verts = []
            var sel_edges = []
            if editor_node.has_method("get_public_edges"):
                var eds = editor_node.call("get_public_edges")
                for i in mapped_indices:
                    if i >= 0 and i < eds.size():
                        sel_edges.append(i)
                        sel_verts.append(eds[i]["from"].id)
                        sel_verts.append(eds[i]["to"].id)
            last_selected_vertices = sel_verts
            last_selected_edges = []
            for i in mapped_indices:
                var ed = editor_node.call("edge_to_ends", i) if editor_node.has_method("edge_to_ends") else {}
                if ed and ed.has("u") and ed.has("v"):
                    last_selected_edges.append({"u": ed.u, "v": ed.v})
            emit_signal("selection_changed", last_selected_vertices, last_selected_edges)
    else:
        push_warning("GraphEditorAdapter.highlight_edges: GraphEditor não implementa find_edge; destaque via adapter não está disponível.")

# ---------------- Utilitários / export helpers ----------------

func notify_graph_loaded():
    emit_signal("graph_loaded")
