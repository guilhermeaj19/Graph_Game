@tool
extends Control

@onready var graph1     : GraphEditor   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/GraphEditor2
@onready var number_colors     : SpinBox   = $ColorRect/SplitContainer/VSplitContainer2/VSplitContainer2/InputNumber
@onready var enunciado : Label         = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/Label
@onready var resposta  : TextEdit      = $ColorRect/SplitContainer/VSplitContainer/VSplitContainer/RespostaDiscursiva
@onready var respostaIA: TextEdit      = $ColorRect/SplitContainer/VSplitContainer/RespostaIA
@onready var buttonReturn: Button      = $ColorRect/SplitContainer/VSplitContainer/RespostaIA/ButtonReturnToMenu
@onready var vertices  : Array[Vertex] = []
@onready var edges  : Array = []
@onready var llm    : LLM = $LLM

func avaliar_resposta():
    if number_colors.value != vertices.size():
        respostaIA.text = "Resposta errada. Analise o grafo com cuidado!"
        return
    else:
        respostaIA.text = "Resposta correta. Analisando feedback..."
   
        
    var result = await llm.generate_response("", construct_prompt())

    respostaIA.text = ""
    for part in result.content:
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
    vertices = graph1.vertices
    edges = graph1.edges
    await get_tree().process_frame
    graph1.load_graph_from_file("res://graphs/complete_graph.json")


func _on_button_send_pressed() -> void:
    avaliar_resposta()

func _on_button_return_to_menu_pressed() -> void:
    get_tree().change_scene_to_file("res://main.tscn")
