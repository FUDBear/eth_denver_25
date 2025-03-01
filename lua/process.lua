-- Process ID: O1-YNtZd-RMWQVbK2zoYWpvERpFN55Ljea_UHCGx-Hg
local json = require("json")
local sqlite3 = require("lsqlite3")

db = db or sqlite3.open_memory()
dbAdmin = require('DbAdmin').new(db)

GameState = GameState or "NONE" -- NONE, ACTIVE, WON, LOST
GameScenarios = GameScenarios or {}
Resources = Resources or {}
Version = "0.1"
VotingResults = { "", "", "" }

VOTES = [[
  CREATE TABLE IF NOT EXISTS Votes (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Wallet TEXT,
    ScenarioIndex INTEGER NOT NULL,
    ChoiceIndex INTEGER NOT NULL
  );
]]

function InitDb()
    print("--InitDb--")

    db:exec(VOTES)
    local queryVotes = [[
        PRAGMA foreign_keys = OFF;

        CREATE TABLE IF NOT EXISTS Votes_temp (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            Wallet TEXT,
            ScenarioIndex INTEGER NOT NULL,
            ChoiceIndex INTEGER NOT NULL
        );

        INSERT INTO Votes_temp (ID, Wallet, ScenarioIndex, ChoiceIndex)
        SELECT ID, Wallet, ScenarioIndex, ChoiceIndex FROM Votes;

        DROP TABLE Votes;
        ALTER TABLE Votes_temp RENAME TO Votes;

        PRAGMA foreign_keys = ON;
    ]]

    local result = db:exec(queryVotes)
    if result ~= sqlite3.OK then
        print("Error updating VotesDb: " .. db:errmsg())
    else
        print("VotesDb updated successfully.")
    end
end

function TallyVotes()
    -- print("--TallyVotes--")
    
    local scenarios = dbAdmin:exec("SELECT DISTINCT ScenarioIndex FROM Votes;")
    
    if not scenarios or #scenarios == 0 then
        print("No votes found to tally")
        return
    end
    
    for _, scenario in ipairs(scenarios) do
        local scenarioIndex = scenario.ScenarioIndex
        -- print("\nTallying votes for Scenario " .. scenarioIndex)
        
        local query = string.format([[
            SELECT ChoiceIndex, COUNT(*) as VoteCount 
            FROM Votes 
            WHERE ScenarioIndex = %s 
            GROUP BY ChoiceIndex
            ORDER BY ChoiceIndex;
        ]], scenarioIndex)

        local results = dbAdmin:exec(query)
        
        if results then
            for _, result in ipairs(results) do

                CheckQuorumAgainstResult(scenarioIndex, result)

                -- print(string.format("Choice %d: %d votes", 
                --     result.ChoiceIndex, 
                --     result.VoteCount))
            end
        end

        -- CheckQuorum(scenarioIndex, results)
        
    end
end

function CheckQuorumAgainstResult(scenarioIndex, result)
    print("--CheckQuorumAgainstResult-- : " .. result.ChoiceIndex .. " " .. result.VoteCount)
    
    -- Find the corresponding scenario
    local scenario = GameScenarios[scenarioIndex + 1]  -- +1 because Lua arrays start at 1
    if scenario then
        local requiredVotes = scenario.Quorum[result.ChoiceIndex + 1]  -- +1 because choices are 0-based
        if result.VoteCount >= requiredVotes then

            if scenario.Status == "ACTIVE" then
                scenario.Result = scenario.Choices[result.ChoiceIndex + 1]
                scenario.Status = "IN_PROGRESS"

                SendVoteResult(scenario, scenario.Result)

                -- Update vote
            else
                print("Scenario " .. scenarioIndex .. " is not active")

                -- voting is done
            end
            

            -- print("Scenario " .. scenario.Description .. " Result: " .. scenario.Result)

            -- print(string.format("VOTE PASSED: Choice %d met quorum requirement (%d/%d votes)", 
            --     result.ChoiceIndex,
            --     result.VoteCount,
            --     requiredVotes
            -- ))
        end
    end

    -- print("--------------------------------")
    -- UpdateScenarioStatus()
    -- print("--------------------------------")
    
end

function UpdateScenarioStatus( stuff )
    print( "stuff: " .. stuff )
    local endData = json.decode(stuff)
    print( "endData: " .. json.encode(endData) )

    -- print("--UpdateScenarioStatus--")
    
    -- Get all unique wallets from the Votes table
    -- local query = "SELECT DISTINCT Wallet FROM Votes;"
    -- local wallets = dbAdmin:exec(query)
    
    -- if not wallets or #wallets == 0 then
    --     print("No wallets found in the database.")
    --     return
    -- end
    
    -- print("Found " .. #wallets .. " unique wallets:")
    -- for i, wallet in ipairs(wallets) do
    --     print(i .. ": " .. wallet.Wallet)

    --     Send({ Target="" .. wallet.Wallet, Action="update-game-state", Data = endData })
    -- end
end

function CheckQuorum(scenarioIndex, results)
    print("--CheckQuorum--")

    for i, scenario in ipairs(GameScenarios) do
        if i == scenarioIndex then
            print(string.format("\nScenario %d: %s", i, scenario.Description))
            print("Quorum requirements:")
            
            -- Initialize vote counts
            local voteCounts = {0, 0}
            
            -- Fill in actual vote counts from results
            if results then
                for _, result in ipairs(results) do
                    local choiceIdx = result.ChoiceIndex
                    voteCounts[choiceIdx] = result.VoteCount
                end
            end
            
            -- Check each choice against its quorum requirement
            for choiceIdx, requiredVotes in ipairs(scenario.Quorum) do
                local actualVotes = voteCounts[choiceIdx]
                local meetsQuorum = actualVotes >= requiredVotes
                
                print(string.format("Choice %d (%s): %d/%d votes %s", 
                    choiceIdx,
                    scenario.Choices[choiceIdx],
                    actualVotes,
                    requiredVotes,
                    meetsQuorum and "(MEETS QUORUM)" or "(NOT MET)"
                ))
            end
        end
    end
end


function PrintGameScenarios()
    print("--PrintGameScenarios--")

    for i, scenario in ipairs(GameScenarios) do
        print(string.format("Scenario %d: %s", i, scenario.Description))
        print("Choices: " .. table.concat(scenario.Choices, ", "))
        print("Quorum: " .. table.concat(scenario.Quorum, ", "))
        print("Npc: " .. scenario.Npc.Face)
        print("Npc: " .. scenario.Npc.Background)
        print("----------------------")
    end
end

function SendVoteResult( scenario, result )
    print("--SendVoteResult--")
    local message = string.format("Scenario %s Result: %s", scenario.Description, result)
    print(message)

    local data = {
        Scenario = scenario.Description,
        Result = result,
        Resources = Resources
    }

    -- Get current resources
    Send({ Target="MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c", Action="ask-fake-llama", Data = json.encode(data) })

end


Handlers.add("InitDBs", "init-dbs", function (msg)  
    
    if msg.From ~= ao.id then
        return
    end

    InitDb()
    SetScenarios()
    SetResources()
end)


Handlers.add("GetVotes", "get-votes", function (msg)
    print("GetVotes")

    -- Fetch all rows from Votes
    local query = "SELECT * FROM Votes;"
    local entries = dbAdmin:exec(query)

    if not entries or #entries == 0 then
        print("No votes found.")
        return
    end 

    print("--------------------------------------------------")
    print("Votes Table:")

    for _, row in ipairs(entries) do
        print("ID: " .. (row.ID or "N/A"))
        print("Wallet: " .. (row.Wallet or "N/A"))
        print("ScenarioIndex: " .. (row.ScenarioIndex or "N/A"))
        print("ChoiceIndex: " .. (row.ChoiceIndex or "N/A"))

        print("--------------------------------------------------")
    end
end)


Handlers.add("CleanVotes", "clean-votes", function (msg)  
    -- admin only
    if msg.From ~= ao.id then
        return
    end

    print("Cleaning Votes")

    dbAdmin:exec("DROP TABLE IF EXISTS Votes;")

    dbAdmin:exec([[
        CREATE TABLE IF NOT EXISTS Votes (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            Wallet TEXT,
            ScenarioIndex INTEGER NOT NULL,
            ChoiceIndex INTEGER NOT NULL
        );
    ]])

    dbAdmin:exec("DELETE FROM sqlite_sequence WHERE name='Votes';")
    print("Votes table reset successfully.")

    dbAdmin:exec("DELETE FROM sqlite_sequence WHERE name='Votes';")
    print("Votes table reset successfully.")

end)

Handlers.add("NewVote", "new-vote", function (msg)
    print("NewVote" .. msg.Data )

    local raw_json = msg.Data
    if type(raw_json) == "string" then
        raw_json = raw_json:gsub('^"', ''):gsub('"$', '')
    end

    local data = json.decode(raw_json)
    if data then
        local wallet = msg.From
        local scenarioIndex = data.ScenarioIndex or 0
        local choiceIndex = data.ChoiceIndex or 0

        print("Wallet: " .. wallet)
        print("ScenarioIndex: " .. scenarioIndex)
        print("ChoiceIndex: " .. choiceIndex)

        local query = string.format([[      
        INSERT INTO Votes (Wallet, ScenarioIndex, ChoiceIndex) 
        VALUES ("%s", "%s", "%s");
        ]], 
        wallet, 
        scenarioIndex, 
        choiceIndex)

        print("Query: " .. query)

        dbAdmin:exec(query)

        local unique_id = db:last_insert_rowid()
        local entry_id = string.format("Vote-%03d", unique_id)

        local update_query = string.format([[      
        UPDATE Votes SET ID = %d WHERE rowid = %d;
        ]], unique_id, unique_id)

        dbAdmin:exec(update_query)

        print("Vote inserted with ID: " .. entry_id)
        TallyVotes()

    else
        print("Error: Failed to decode JSON")
    end
end)

Handlers.add("AIData", "ai-data", function (msg)
    if msg.From ~= "MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c" then
        print("Invalid Process ID: " .. msg.From)
        return
    end

    local stuff = msg.Data
    print("--------------------------------")
    print( "FakeResponseData: " .. stuff)
    print("--------------------------------")

    ShowVictory()

    -- Send({ Target="eqWPXgEngDqBptVFmSlJT0YC9wgyAD4U8l1wrqKu_WE", Action="ask-fake-llama", Data = '{"Scenario":"br0 XD"}' })

    -- UpdateScenarioStatus( stuff )

    -- local scenario = json.decode(data)
    -- print("Scenario: " .. scenario.Scenario)
    -- print("Result: " .. scenario.Result)
    -- print("Resources: " .. json.encode(scenario.Resources))

end)


-- || Data Builders || --
function SetScenarios()
    print("--SetScenarios--")

    GameScenarios = {
        {
            ID = 1,
            Description = "We found a frog in the soup, what should we do with it?",
            Npc = { 
                Face = "npc.jpeg",
                Background = "temp.jpg",
            },
            Choices = {"Eat it", "Kiss it"},
            Quorum = {2, 3},
            Result = "",
            Status = "ACTIVE" -- ACTIVE, IN_PROGRESS, COMPLETED
        },
        {
            ID = 2,
            Description = "An evil witch stole the broom we were cleaning with, what should we do?",
            Npc = { 
                Face = "npc.jpeg",
                Background = "temp.jpg",
            },
            Choices = {"Chase her", "Leave her alone"},
            Quorum = {2, 1},
            Result = "",
            Status = "ACTIVE"
        },
        {
            ID = 3,
            Description = "The dishes in the kitchen have come to life and are singing a song, what should we do?",
            Npc = { 
                Face = "npc.jpeg",
                Background = "temp.jpg",
            },
            Choices = {"Listen to the song", "Shove them in a drawer"},
            Quorum = {2, 1},
            Result = "",
            Status = "ACTIVE"
        }
    }
end

function SetResources()
    
    Resources = {
        food = 4,
        hunters = 2,
        miners = 3,
        cleaners = 6,
        axemen = 1,
        beer = 10,
    }

    print("SetResources: " ..json.encode(Resources))
end

function ShowVictory()
    Send({ Target="eqWPXgEngDqBptVFmSlJT0YC9wgyAD4U8l1wrqKu_WE", Action="victory", Data = '{"Scenario":"br0 XD"}' })
end