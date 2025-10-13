extends LLMProviderAPI
class_name HuggingFaceAPI

const API_URL_BASE := "https://api-inference.huggingface.co/models/"

## Gera uma resposta usando a Hugging Face Inference API
func generate_response(params: Dictionary) -> Dictionary:
    var model := params.get("model", "mistralai/Mistral-7B-Instruct-v0.2")
    print("Model: ", model)
    var prompt := params.get("prompt", "")
    var temperature := params.get("temperature", 0.3)
    var max_tokens := params.get("max_tokens", 512)

    var headers := {
        "Authorization": "Bearer " + api_key,
        "Content-Type": "application/json"
    }

    var body := {
        "model": model,
        "messages": params.prompt,
        "parameters": {
            "max_new_tokens": params.max_tokens,
            "temperature": temperature
        }
    }

    var response = await _make_request("https://router.huggingface.co/v1/chat/completions", headers, body)
    
    if typeof(response) == TYPE_DICTIONARY and response.has("error"):
        var error_message := "Hugging Face API error: " + str(response.error)
        push_error(error_message)
        return { "error": error_message }

    return response

#func _make_request(url: String, headers: Array, body: Dictionary) -> Dictionary:
    #var http := HTTPRequest.new()
    #add_child(http)
    #var json_body := JSON.stringify(body)
    #var result := await http.request(url, headers, false, HTTPClient.METHOD_POST, json_body)
    #var code := result[1]
    #var response_body := result[3]
    #return JSON.parse_string(response_body)
