-- Llama Process: MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c
Llama = require("@sam/Llama-Herder")

Handlers.add("AskLlama", "ask-llama", function (msg)

    if msg.From ~= "O1-YNtZd-RMWQVbK2zoYWpvERpFN55Ljea_UHCGx-Hg" then
        print("Invalid Process ID: " .. msg.From)
        return
    end

    print( msg.From .. " - AskedLlama: " .. msg.Data) 

    -- GetFakerResponse( msg.Data, msg.From )
    
    AskLlama( msg.Data, "You are a master storyteller providing the outcome to various scenarios. When you are given a scenario, please provide a short description, under 100 characters, of the outcome to that scenario. Please give a 50% chance to either a positive or negative outcome. Also give (+1) or take (-1) any resources you think would be fair for this outcome, but the resource adjustments need to make sense for the outcome. Only reply with string like this: { 'resource_1': your_adjustment, 'resource_2': your_adjustment, 'outcome': 'The scenario outcome'}"
, msg.From)   
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
            print("Response: " .. res)
            Send({ Target = responseTarget, Action = "ai-data", Data = res })
        end
    )
end

Handlers.add("AskFakeLlama", "ask-fake-llama", function (msg)

    if msg.From ~= "O1-YNtZd-RMWQVbK2zoYWpvERpFN55Ljea_UHCGx-Hg" then
        print("Invalid Process ID: " .. msg.From)
        return
    end

    -- print( msg.From .. " - AskedFakeLlama: " .. msg.Data) 

    GetFakerResponse( msg.Data, msg.From )
    
--     AskLlama( msg.Data, "You are a master storyteller providing the outcome to various scenarios. When you are given a scenario, please provide a short description, under 100 characters, of the outcome to that scenario. Please give a 50% chance to either a positive or negative outcome. Also give (+1) or take (-1) any resources you think would be fair for this outcome, but the resource adjustments need to make sense for the outcome. Only reply with string like this: { 'resource_1': your_adjustment, 'resource_2': your_adjustment, 'outcome': 'The scenario outcome'}"
-- , msg.From)   
end)

function GetFakerResponse(data, from)
    print("GetFakeResponse: " .. data .. " from: " .. from)
    
    local scenario = json.decode(data)
    -- print("Scenario: " .. scenario.Scenario)
    -- print("Result: " .. scenario.Result)
    -- print("Resources: " .. json.encode(scenario.Resources))

    local fakeResponse = ""

    if scenario.Result == "Eat it" then
        fakeResponse = '{ medicine = -1, food = 1, outcome = "The frogs is delicious but makes everyone sick." , task = 0 }'
    elseif scenario.Result == "Kiss it" then
        fakeResponse = '{ medicine = -2, miners = 1, outcome = "The frog turns into a human and you make him your slave." , task = 0 }'
    elseif scenario.Result == "Chase her" then
        fakeResponse = '{ cleaners = -2, outcome = "You chase the witch down and turn her into stew." , task = 1 }'
    elseif scenario.Result == "Leave her alone" then
        fakeResponse = '{ cleaners = -2, outcome = "You leave the witch alone and she steals another broom." }'
    elseif scenario.Result == "Listen to the song" then
        fakeResponse = '{ food = 1, beer = -2, outcome = "You listen to the song and take part in a musical performance." }'
    elseif scenario.Result == "Shove them in a drawer" then
        fakeResponse = '{ food = 1, beer = -2, outcome = "You hear muffled voices coming from the drawer and it makes you sad." }'
    end

    print("Sending Fake Response: " .. fakeResponse)
    print("--------------------------------")

    Send({ Target = from, Action = "ai-data", Data = fakeResponse })
end