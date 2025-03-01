-- Process ID: O1-YNtZd-RMWQVbK2zoYWpvERpFN55Ljea_UHCGx-Hg
local json = require("json")
local sqlite3 = require("lsqlite3")

db = db or sqlite3.open_memory()
dbAdmin = require('DbAdmin').new(db)

GAMESTATE = [[
  CREATE TABLE IF NOT EXISTS GameState (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Status TEXT, -- Active, Completed, InProgress
    Index INTEGER, -- Index of the scenario
    Wallets TEXT -- All players in the game
  );
]]

-- SCENARIOS = [[
--   CREATE TABLE IF NOT EXISTS Scenarios (
--     ID INTEGER PRIMARY KEY AUTOINCREMENT,
--     NPC TEXT, -- json
--     Status TEXT, -- Active, Completed, InProgress
--     Outcome TEXT, -- Description & Resource_Effect
--     Scenario TEXT,  -- json
--     Voters TEXT -- wallet addresses
--   );
-- ]]

function InitDb()
    db:exec(GAMESTATE)
    -- db:exec(Scenarios)
    print("--InitDb--")

    local queryGameState = [[
        PRAGMA foreign_keys = OFF;
        BEGIN TRANSACTION;

        CREATE TABLE IF NOT EXISTS GameState_temp (
            Status TEXT,
            Index INTEGER,
            AllPlayers TEXT
        );

        INSERT INTO GameState_temp (Status, Index, AllPlayers)
        SELECT Status, Index, AllPlayers FROM GameState;

        DROP TABLE GameState;
        ALTER TABLE GameState_temp RENAME TO GameState;

        COMMIT;
        PRAGMA foreign_keys = ON;
    ]]

    local result = db:exec(queryGameState)
    if result ~= sqlite3.OK then
        print("Error updating GameStateDb: " .. db:errmsg())
    else
        print("GameStateDb updated successfully.")
    end


end

Handlers.add("InitGame", "init-game", function (msg)  
    
    if msg.From ~= ao.id then
        return
    end

    InitDb()
end)

Handlers.add("NewGame", "new-game", function (msg)
    print("NewGame" .. msg.Data )

    local raw_json = msg.Data
    if type(raw_json) == "string" then
        raw_json = raw_json:gsub('^"', ''):gsub('"$', '')
    end

    -- local data = json.decode(raw_json)
    -- if data then
    --     print("Wallet: " .. data.Wallet)
    --     print("Vote: " .. data.Vote)
    --     print("Choice: " .. data.Choice)

    --     local wallet = msg.From or ""
    --     local vote = data.Vote or ""
    --     local choice = data.Choice or ""

    --     local entry = {
    --         ID = nil,
    --         Wallet = wallet,
    --         Vote = vote,
    --         Choice = choice
    --     }
        
    --     insertEntry(entry)

    -- else
    --     print("Error: Failed to decode JSON")
    -- end
    
end)

Handlers.add("GetGame", "get-game", function (msg)
    print("GetGame")

    local entries = dbAdmin:exec("SELECT * FROM GameState;")

    if #entries == 0 then
        print("No gamestate found.")
        return
    end

    print("GameState:")
    print("Status: " .. (entries[1].Status or "N/A"))
    print("Index: " .. (entries[1].Index or "N/A"))
    print("AllPlayers: " .. (entries[1].AllPlayers or "N/A"))
    print("--------------------------------------------------")

    -- for _, row in ipairs(entries) do
    --     print("Status: " .. (row.Status or "N/A"))
    --     print("Index: " .. (row.Index or "N/A"))
    --     print("AllPlayers: " .. (row.AllPlayers or "N/A"))
    --     print("--------------------------------------------------")
    -- end
end)




Handlers.add("GetGame", "get-game", function (msg)
    print("GetGame")

    -- Fetch all rows from GameState
    local query = "SELECT * FROM GameState;"
    local entries = dbAdmin:exec(query)

    if not entries or #entries == 0 then
        print("No gamestate found.")
        return
    end 

    print("--------------------------------------------------")
    print("GameState Table:")

    for _, row in ipairs(entries) do
        print("ID: " .. (row.ID or "N/A"))
        print("Status: " .. (row.Status or "N/A"))
        print("ScenarioIndex: " .. (row.ScenarioIndex or "N/A"))
        print("Wallets: " .. (row.Wallets or "N/A"))
        print("--------------------------------------------------")
    end
end)

Handlers.add("NewGame", "new-game", function (msg)
    print("NewGame" .. msg.Data )

    if msg.From ~= ao.id then
        return
    end

    local raw_json = msg.Data
    if type(raw_json) == "string" then
        raw_json = raw_json:gsub('^"', ''):gsub('"$', '')
    end

    local data = json.decode(raw_json)
    if data then
        
        local status = data.Status or ""
        local scenarioIndex = data.ScenarioIndex or 0
        local wallets = data.Wallets or ""

        print("Status: " .. status)
        print("ScenarioIndex: " .. scenarioIndex)
        print("Wallets: " .. wallets)

        local query = string.format([[      
        INSERT INTO GameState (Status, ScenarioIndex, Wallets) 
        VALUES ("%s", "%s", "%s");
        ]], 
        status, 
        scenarioIndex, 
        wallets)
        
        dbAdmin:exec(query)

        local unique_id = db:last_insert_rowid()
        local entry_id = string.format("GameState-%03d", unique_id)

        local update_query = string.format([[      
        UPDATE GameState SET ID = %d WHERE rowid = %d;
        ]], unique_id, unique_id)

        dbAdmin:exec(update_query)

        print("GameState inserted with ID: " .. entry_id)

    else
        print("Error: Failed to decode JSON")
    end
    
end)

Handlers.add("GetGame", "get-game", function (msg)
    print("GetGame")

    -- Fetch all rows from GameState
    local query = "SELECT * FROM GameState;"
    local entries = dbAdmin:exec(query)

    if not entries or #entries == 0 then
        print("No gamestate found.")
        return
    end 

    print("--------------------------------------------------")
    print("GameState Table:")

    for _, row in ipairs(entries) do
        print("ID: " .. (row.ID or "N/A"))
        print("Status: " .. (row.Status or "N/A"))
        print("ScenarioIndex: " .. (row.ScenarioIndex or "N/A"))
        print("Wallets: " .. (row.Wallets or "N/A"))

        -- Decode Scenarios JSON for better readability
        local scenarios = row.Scenarios or "[]"
        local scenarios_table = json.decode(scenarios)

        print("Scenarios:")
        for _, scenario in ipairs(scenarios_table) do
            print(" - Scenario ID: " .. (scenario.ID or "N/A"))
            print("   NPC: " .. (scenario.NPC or "N/A"))
            print("   Status: " .. (scenario.Status or "N/A"))
            print("   Outcome: " .. (scenario.Outcome or "N/A"))
            print("   Scenario Text: " .. (scenario.Scenario or "N/A"))
            print("   Voters: " .. (scenario.Voters or "N/A"))
            print("--------------------------------------------------")
        end
    end
end)