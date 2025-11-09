@tool
extends Control
class_name Question_Abstract

@onready var graph     : GraphEditor
@onready var enunciado : Label
@onready var resposta  : TextEdit
@onready var respostaIA: TextEdit
@onready var vertices  : Array[Vertex] = []
@onready var edges  : Array = []
@onready var llm    : LLM

func avaliar_resposta():
    pass
    #set_ia_feddback()

func set_ia_feedback(text: String = ""):
    if text == "":
        
        var result = await llm.generate_response("", construct_prompt())
        if result.content:
            respostaIA.text = ""
            for part in result.content:
                respostaIA.text += part.candidates[0].content.parts[0].text
        else:
            respostaIA.text += "\nErro ao se conectar com a LLM. Verifique a conexão e tente novamente."
    else:
        respostaIA.text = text

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
         "content": "Arestas: " + str(edges.map(func(e): return {"from": e["from"].id, "to": e["to"].id, "weight": e["weight"]})),
        },
        {
         "role": "user", 
         "content": "Avalie, em até 300 caracteres, em texto plano, essa resposta e atribua uma nota de 0 a 10, justificando a nota. O grafo estar correto vale 3, e a qualidade da justificativa vale até 7."
        },
        {
         "role": "user", 
         "content": "Também leve em consideração que a parte objetiva da questão está correta. Seu objetivo é apenas avaliar a resposta discursiva"
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
    pass

func _on_button_send_pressed() -> void:
    avaliar_resposta()

func _on_button_return_to_menu_pressed() -> void:
    get_tree().change_scene_to_file("res://main.tscn")
