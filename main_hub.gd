extends Control

const COLUMNS: int = 3
const ROWS: int = 2
const ITEMS_PER_PAGE: int = COLUMNS * ROWS
@export_file("*.json") var questions_index_path: String = "res://questions_data.json"

@export var grid_spacing_h: int = 8
@export var grid_spacing_v: int = 8
@export var cell_size_param: Vector2 = Vector2(260, 160)

@onready var lbl_title: Label = $ColorRect/VBoxContainer/lbl_title
@onready var grid_thumbs: GridContainer = $ColorRect/VBoxContainer/MarginContainer/grid_thumbs
@onready var btn_prev: Button = $ColorRect/VBoxContainer/pagination_row/btn_prev
@onready var btn_next: Button = $ColorRect/VBoxContainer/pagination_row/btn_next
@onready var lbl_page: Label = $ColorRect/VBoxContainer/pagination_row/lbl_page
@onready var left_pane: Control = self 

var questions_list: Array = []
var current_page: int = 0
var total_pages: int = 1

func _ready() -> void:
    grid_thumbs.columns = COLUMNS
    grid_thumbs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid_thumbs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    btn_prev.connect("pressed", Callable(self, "_on_prev_page"))
    btn_next.connect("pressed", Callable(self, "_on_next_page"))
    get_viewport().connect("size_changed", Callable(self, "_on_resized"))
    
    _load_index_json()
    _calculate_total_pages()
    _refresh_page()

func _load_index_json() -> bool:
    questions_list.clear()
    var p = questions_index_path
    if p == "":
        return false
    var f := FileAccess.open(p, FileAccess.ModeFlags.READ)
    if not f:
        push_error("Não foi possível abrir: %s" % p)
        return false
    var txt := f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(txt)
    questions_list = parsed["questions"]
    return true

func _calculate_total_pages() -> void:
    total_pages = int((questions_list.size() + ITEMS_PER_PAGE - 1) / ITEMS_PER_PAGE)
    if total_pages <= 0:
        total_pages = 1
    current_page = clamp(current_page, 0, total_pages - 1)

func _on_next_page() -> void:
    if current_page < total_pages - 1:
        current_page += 1
        _refresh_page()

func _on_prev_page() -> void:
    if current_page > 0:
        current_page -= 1
        _refresh_page()

func go_to_page(page: int) -> void:
    var target = clamp(page, 0, max(0, total_pages - 1))
    if target == current_page:
        return
    current_page = target
    _refresh_page()

func _compute_cell_size() -> Vector2:
    var avail := left_pane.get_size()
    var cols := COLUMNS
    var rows := ROWS
    var total_h_spacing := grid_spacing_h * (cols - 1)
    var total_v_spacing := grid_spacing_v * (rows - 1)
    var cell_w := int(floor((avail.x - total_h_spacing) / cols))
    var cell_h := int(floor((avail.y - total_v_spacing) / rows))
    cell_w = max(48, cell_w)
    cell_h = max(48, cell_h)
    return Vector2(cell_w, cell_h)

func _make_thumb(item: Dictionary, index: int, cell_size: Vector2) -> Control:
    var half_h := int(grid_spacing_h / 2)
    var half_v := int(grid_spacing_v / 2)

    var wrapper := Control.new()
    wrapper.name = "thumb_%d" % index
    wrapper.custom_minimum_size = cell_size
    wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

    var inner := PanelContainer.new()
    inner.name = "thumb_inner"
    inner.set_anchors_preset(Control.PRESET_FULL_RECT)
    inner.mouse_filter = Control.MOUSE_FILTER_PASS
    wrapper.add_child(inner)

    var pad := MarginContainer.new()
    pad.name = "thumb_pad"
    pad.set_anchors_preset(Control.PRESET_FULL_RECT)
    inner.add_child(pad)

    var col := VBoxContainer.new()
    col.name = "thumb_col"
    col.set_anchors_preset(Control.PRESET_FULL_RECT)
    pad.add_child(col)

    var center := CenterContainer.new()
    center.name = "thumb_center"
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(center)

    #var img := TextureRect.new()
    #img.name = "thumb_img"
    #img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    #img.mouse_filter = Control.MOUSE_FILTER_IGNORE
    #img.size_flags_horizontal = 0
    #img.size_flags_vertical = 0
    #img.custom_minimum_size = Vector2(int(cell_size.x * 0.7), int(cell_size.y * 0.7))
    #center.add_child(img)
    #if item.has("image") and str(item.image) != "":
        #var path := str(item.image)
        #if ResourceLoader.exists(path):
            #var tex := ResourceLoader.load(path)
            #if tex and tex is Texture2D:
                #img.texture = tex

    # Label título abaixo da imagem
    var title := Label.new()
    title.name = "thumb_title"
    title.text = str(item.get("title", ""))
    title.size_flags_horizontal = 0
    title.size_flags_vertical = 0
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    # opcional: limitar altura do título (ajuste conforme preferir)
    title.custom_minimum_size = Vector2(0, 36)
    col.add_child(title)

    # Botão overlay POR ÚLTIMO, cobrindo todo o pad (captura cliques)
    var btn := Button.new()
    btn.name = "thumb_btn_%d" % index
    var sb_normal := StyleBoxFlat.new()
    sb_normal.bg_color = Color(0,0,0,0) 

    var sb_hover := StyleBoxFlat.new()
    sb_hover.bg_color = Color(0.347, 0.551, 0.633, 0.06)

    var sb_pressed := StyleBoxFlat.new()
    sb_pressed.bg_color = Color(0.717, 0.969, 0.837, 0.122)
    btn.add_theme_stylebox_override("normal", sb_normal)
    btn.add_theme_stylebox_override("hover", sb_hover)
    btn.add_theme_stylebox_override("pressed", sb_pressed)

    btn.set_anchors_preset(Control.PRESET_FULL_RECT)
    btn.mouse_filter = Control.MOUSE_FILTER_STOP
    btn.focus_mode = Control.FOCUS_NONE
    pad.add_child(btn)

    btn.connect("pressed", Callable(self, "_on_thumb_pressed").bind(index))

    return wrapper
    
func _clear_grid_children() -> void:
    for c in grid_thumbs.get_children():
        c.queue_free()

func _refresh_page() -> void:
    _clear_grid_children()
    _calculate_total_pages()
    var cell_size := cell_size_param
    var start := current_page * ITEMS_PER_PAGE
    var finish = min(start + ITEMS_PER_PAGE, questions_list.size())
    for i in range(start, finish):
        var item = questions_list[i]
        var thumb := _make_thumb(item, i, cell_size)
        grid_thumbs.add_child(thumb)
    lbl_page.text = "Página %d / %d" % [current_page + 1, total_pages]
    btn_prev.disabled = current_page <= 0
    btn_next.disabled = current_page >= total_pages - 1
    grid_thumbs.queue_sort()

func set_cell_size(new_size: Vector2) -> void:
    cell_size_param = new_size
    _refresh_page()

func _on_thumb_pressed(index: int) -> void:
    #print(index)
    _load_question_scene(questions_list[index]["path"])

func _load_question_scene(scene_path: String) -> void:
    var err = get_tree().change_scene_to_file(scene_path)
    set_meta("last_loaded_index", null)

func _on_resized() -> void:

    if questions_list.size() > 0:
        _refresh_page()
