extends LLMProviderAPI
## GeminiAPI: A GDScript class for interacting with Google’s Gemini API,
## supporting both text-bison and chat-bison models in a single provider.
##
## This class implements the LLMProviderAPI interface and chooses the
## correct endpoint and request body based on whether the model is chat-based.

class_name GeminiAPI

var system_prompt: String

func generate_response(params: Dictionary) -> Dictionary:
    if debug: print("Params:", params)

    var model := params.get("model", "gemini-1.5-flash-latest")
    var url_template = "https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key={api_key}"
    var url = url_template.format({"model": model, "api_key": api_key})
    
    var headers := { "Content-Type": "application/json" }
    
    var body := {
            "contents": [
            {
                "role": "user",
                "parts": []
            },
            ],
            "generationConfig": {
            "thinkingConfig": {
                "thinkingBudget": -1,
            },
            },
        }
    
    for msg in params.prompt_messages:
        body.contents[0].parts.append({"text": msg.content})
    
    
    if debug: print("URL: ", url)
    if debug: print("Body: ", body)
    
    var response_body_string = await _make_request(url, headers, body)
    return {"content": response_body_string}


func extract_response_messages(response: Dictionary) -> Array:
    return [response]

func supports_tool_use() -> bool:
    return false


func prepare_tools_for_request(tools: Array) -> Array:
    return []


func has_tool_calls(response: Dictionary) -> bool:
    return false


func extract_tool_calls(response: Dictionary) -> Array:
    return []


func format_tool_results(tool_results: Array) -> Array:
    return []


func supports_system_prompt() -> bool:
    return true


func set_system_prompt(prompt: String) -> void:
    system_prompt = prompt


func get_system_prompt() -> String:
    return system_prompt
