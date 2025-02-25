-- Llama Process: MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c
Llama = require("@sam/Llama-Herder")

Handlers.add("AskLlama", "ask-llama", function (msg)

    if msg.From ~= "O1-YNtZd-RMWQVbK2zoYWpvERpFN55Ljea_UHCGx-Hg" then
        print("Invalid Process ID: " .. msg.From)
        return
    end

    print( msg.From .. " - AskedLlama: " .. msg.Data) 

    AskLlama( msg.Data, "You are a helpful assistant.", msg.From)    
end)

function CreatePrompt(systemPrompt, userContent)
    return [[<|system|>
    ]] .. systemPrompt .. [[<|end|>
    <|user|>
    ]] .. userContent .. [[<|end|>
    <|assistant|>
    ]]
end

function AskLlama(systemPrompt, userContent, responseTarget)
    local prompt = CreatePrompt(systemPrompt, userContent)
    
    Llama.run(
        prompt, 60, function(generated_text)

            print("--------------------------------")
            print("Generated Text: " .. generated_text)
            print("--------------------------------")

            local res = generated_text:match("^(.-)\n")
            if res == nil then
                return print("Could not find response in: " .. generated_text)
            end
            -- print("Response: " .. res)
            Send({ Target = responseTarget, Action = "ai-data", Data = res })
        end
    )
end