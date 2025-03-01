-- Process ID: O1-YNtZd-RMWQVbK2zoYWpvERpFN55Ljea_UHCGx-Hg
local json = require("json")
local sqlite3 = require("lsqlite3")

db = db or sqlite3.open_memory()
dbAdmin = require('DbAdmin').new(db)

GameState = {
    currentRound = 1,
    totalPlayers = 0,
    isGameActive = false,
    roundResults = {},
    lastUpdateTime = 0
}

EnemyTemplates = {
    Sheep = {
        Name = "Sheep",
        ID = 1,
        MaxHealth = 3,
        MaxPower = 5,
        Armor = 2,
        Gold = 1,
        Experience = 10
    },
    Pig = {
        Name = "Pig",
        ID = 2,
        MaxHealth = 5,
        MaxPower = 8,
        Armor = 4,
        Gold = 3,
        Experience = 20
    },
    Cow = {
        Name = "Cow",
        ID = 3,
        MaxHealth = 4,
        MaxPower = 12,
        Armor = 6,
        Gold = 2,
        Experience = 30
    }
}

-- Shold be renamed to "Players"
ENTRIES = [[
  CREATE TABLE IF NOT EXISTS Entries (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Wallet TEXT UNIQUE,
    Vote TEXT,
    Choice TEXT
  );
]]

DUNGEON = [[
  CREATE TABLE IF NOT EXISTS Dungeon (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Level INTEGER NOT NULL,
    Difficulty TEXT,
    Enemy TEXT,  -- json
    Status TEXT,      -- Active, Completed, Locked
    Votes TEXT, -- Active votes for this room
    RequiredLevel INTEGER DEFAULT 1
  );
]]

function InitDb()
    db:exec(ENTRIES)
    print("--InitDb--")

    local alterQuery = [[
        PRAGMA foreign_keys = OFF;
        BEGIN TRANSACTION;

        CREATE TABLE IF NOT EXISTS Entry_temp (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            Wallet TEXT,
            Vote TEXT,
            Choice TEXT
        );

        INSERT INTO Entry_temp (ID, Wallet, Vote, Choice)
        SELECT ID, Wallet, Vote, Choice FROM Entries;

        DROP TABLE Entries;
        ALTER TABLE Entry_temp RENAME TO Entries;

        COMMIT;
        PRAGMA foreign_keys = ON;
    ]]
    
    local result = db:exec(alterQuery)
    if result ~= sqlite3.OK then
        print("Error updating Entries table to include only WALLET, VOTE, CHOICE.")
    else
        print("Entries table updated successfully with WALLET, VOTE, CHOICE columns.")
    end
end

function InitDungeon()
    print("--InitDungeon--")
    
    db:exec("DROP TABLE IF EXISTS Dungeon;")
    db:exec(DUNGEON) 

    for i = 1, 6 do
        GenerateDungeon(i)
    end
end

local function insertEntry(entry)
    print("--------------- Insert Entry ---------------")

    local wallet = entry.Wallet or "Unknown"
    local vote = entry.Vote or ""
    local choice = entry.Choice or ""

    -- print("Wallet: " .. wallet)
    -- print("Vote: " .. vote)
    -- print("Choice: " .. choice)

    local query = string.format([[      
      INSERT INTO Entries (Wallet, Vote, Choice) 
      VALUES ("%s", "%s", "%s");
    ]], 
    wallet, 
    vote, 
    choice)
    -- print("Query: " .. query)

    dbAdmin:exec(query)

    local unique_id = db:last_insert_rowid()
    local entry_id = string.format("ENT-%03d", unique_id)

    local update_query = string.format([[      
      UPDATE Entries SET ID = %d WHERE rowid = %d;
    ]], unique_id, unique_id)

    dbAdmin:exec(update_query)

    print("Entry inserted with ID: " .. entry_id)

    CheckSendTurnToAI()
end

function CastVote(msg)
    print("--CastVote--")

    local wallet = msg.From
    local timestamp_ms = msg["Timestamp"]
    local timestamp_seconds = math.floor(timestamp_ms / 1000)
    local voteIndex = 0
    local votePower = 0

    local raw_json = msg.Data
    if type(raw_json) == "string" then
        raw_json = raw_json:gsub('^"', ''):gsub('"$', '')
    end

    local data = json.decode(raw_json)
    if data then
        voteIndex = tonumber(data.Vote)
        if voteIndex ~= nil then
            voteIndex = voteIndex + 1
        else
            print("Error: Vote is not a number")
            return
        end
        votePower = data.Power
    else
        print("Error: Failed to decode JSON")
        return
    end

    local activeRoom = dbAdmin:exec([[
        SELECT ID, Votes FROM Dungeon 
        WHERE Status = 'Active' 
        ORDER BY Level ASC 
        LIMIT 1;
    ]])

    if #activeRoom == 0 then
        print("No active dungeon room found")
        return
    end

    local votesData = json.decode(activeRoom[1].Votes)
    if not votesData or not votesData.options then
        print("Invalid votes data structure")
        return
    end

    -- Debug print before update
    -- print("Before vote - Option " .. voteIndex .. " count: " .. 
          -- (votesData.options[voteIndex] and votesData.options[voteIndex].voteCount or "nil"))

    -- Increment the vote count for the selected option
    if votesData.options[voteIndex] then
        votesData.options[voteIndex].voteCount = (votesData.options[voteIndex].voteCount or 0) + 1
        -- print("After vote - New count: " .. votesData.options[voteIndex].voteCount)
        
        -- Check if vote count has reached or exceeded max votes
        if votesData.options[voteIndex].voteCount >= votesData.options[voteIndex].maxVotes then
            print("Maximum votes reached for option " .. voteIndex .. "! Ready to trigger next action.")
            TriggerVoteAction(activeRoom[1])
        end
    else
        -- print("Invalid vote index: " .. tostring(voteIndex))
        -- print("Available options: " .. #votesData.options)
        return
    end

    -- Debug print the full votes data
    -- print("Updated votes data: " .. json.encode(votesData))

    local updatedVotesJson = json.encode(votesData)
    local updateQuery = string.format([[
        UPDATE Dungeon 
        SET Votes = '%s'
        WHERE ID = %d;
    ]], updatedVotesJson, activeRoom[1].ID)
    
    dbAdmin:exec(updateQuery)

    -- Get the fresh room data after the vote update
    local updatedRoom = dbAdmin:exec(string.format([[
        SELECT * FROM Dungeon WHERE ID = %d;
    ]], activeRoom[1].ID))[1]
    
    print("Vote successfully recorded")
    
    -- Check if any option reached max votes and trigger action with updated room data
    if votesData.options[voteIndex].voteCount >= votesData.options[voteIndex].maxVotes then
        print("Maximum votes reached for option " .. voteIndex .. "! Ready to trigger next action.")
        TriggerVoteAction(updatedRoom)
    end
end

function TriggerVoteAction(room)
    print("--TriggerVoteAction--")

    if not room then
        print("No room data provided")
        return
    end

    local votesData = json.decode(room.Votes)
    if not votesData or not votesData.options then
        print("Invalid votes data structure")
        return
    end

    local winningOption = nil
    for i, option in ipairs(votesData.options) do
        if option.voteCount >= option.maxVotes then
            winningOption = option
            break  -- Exit the loop as soon as we find a winner
        end
    end

    if winningOption then
        print("Winning action: " .. winningOption.action)

        -- Send to AI
        -- Send({ Target = "MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c", Action = "ask-llama", Data = 'Scenario: A dig team finds a magical stone. They have chosen to keep it and return it back to the village. Please give or take what resources you think would be fair for this outcome. Resources: { "stone": 3, "wood": 4, "food": 8, "medicine": 2 } Only reply with a json string like this: { "stone": -1, "wood": 0, "food": +2, "medicine": 0 }' })
        -- Send({ Target = "MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c", Action = "ask-llama", Data = 'Scenario: A dig team finds a magical gem. They have chosen to keep it and return it back to the village. Please give or take what resources you think would be fair for this outcome. Resources: { "stone": 3, "wood": 4, "food": 8, "medicine": 2 } Only reply with a json string like this: { "stone": -1, "story": "The magical gem absorbs nearby stones" }' })

        Send({ Target = "MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c", Action = "ask-llama", Data = 'Scenario: The expedition is attacked by orcs and they decide to fight back. Current resources: { "stone": 13, "wood": 18, "food": 12, "medicine": 1 }' })

        -- -- Get and update enemy data
        -- local enemyData = json.decode(room.Enemy)
        -- if enemyData then
        --     enemyData.MaxHealth = enemyData.MaxHealth - 1
        --     local updatedEnemyJson = json.encode(enemyData)
            
        --     -- Update both enemy health and room status
        --     local updateQuery = string.format([[
        --         UPDATE Dungeon 
        --         SET Status = 'Completed',
        --             Enemy = '%s'
        --         WHERE ID = %d;   
        --     ]], updatedEnemyJson, room.ID)
            
        --     dbAdmin:exec(updateQuery)
        --     print("Enemy health reduced to: " .. enemyData.MaxHealth)
        -- end
    else
        print("No winning action found")
    end
end


-- || AI Handlers/Functions || --

function CheckSendTurnToAI()
    local entries = dbAdmin:exec("SELECT COUNT(*) AS count FROM Entries;")

    if entries and entries[1] and entries[1].count then
        print("Entries: " .. tostring(entries[1].count))
        if entries[1].count >= 5 then
            print("Sending turn to AI")
        else
            print("Not enough entries to send turn to AI")
        end
    else
        print("Error: COUNT query did not return valid data")
    end
end


-- || User Handlers/Functions || --

Handlers.add("CreateNewUser", "Create-New-User", function (msg)
    print("CreateNewUser" .. msg.Data )

    local raw_json = msg.Data
    if type(raw_json) == "string" then
        raw_json = raw_json:gsub('^"', ''):gsub('"$', '')
    end

    local data = json.decode(raw_json)
    if data then
        print("Wallet: " .. data.Wallet)
        print("Vote: " .. data.Vote)
        print("Choice: " .. data.Choice)

        local wallet = msg.From or ""
        local vote = data.Vote or ""
        local choice = data.Choice or ""

        local entry = {
            ID = nil,
            Wallet = wallet,
            Vote = vote,
            Choice = choice
        }
        
        insertEntry(entry)

    else
        print("Error: Failed to decode JSON")
    end
    
end)


-- || Admin Handlers || --
Handlers.add("Init", "Init", function (msg)  
    
    if msg.From ~= ao.id then
        return
    end

    -- InitDb()
    InitDungeon()
end)

-- || Testing Handlers || --
Handlers.add("AskLlamaRelay", "ask-llama-relay", function (msg)
    print("AskLlamaRelay: " .. msg.Data)
    Send({ Target="MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c", Action="ask-llama", Data = msg.Data })
end)

Handlers.add("pingpong", "ping-pong", function (msg)
    print("pingpong" .. msg.Data )
    Send({ Target = msg.From, Data = "ETH Denver 2025 - pong" })
end)

Handlers.add("PrintEntries", "print-entries", function (msg)
    print("All Entries:")

    local entries = dbAdmin:exec("SELECT * FROM Entries;")

    if #entries == 0 then
        print("No entries found.")
        return
    end

    for _, row in ipairs(entries) do
        print("ID: " .. (row.ID or "N/A"))
        print("Wallet: " .. (row.Wallet or "N/A"))
        print("Vote: " .. (row.Vote or "N/A"))
        print("Choice: " .. (row.Choice or "N/A"))
        print("--------------------------------------------------")
    end
end)

Handlers.add("GetState", "get-state", function (msg)
    print("Get Game State")
    
    local gameStateJson = json.encode(GameState)
    Send({ Target = msg.From, ID = "GameState", Data = gameStateJson })
end)

Handlers.add("AIData", "ai-data", function (msg)
    if msg.From ~= "MfEzqw2ES0OB1HNye5E03CVZp_F5sXqmXuYPMZPGG2c" then
        print("Invalid Process ID: " .. msg.From)
        return
    end

    local data = msg.Data
    print("AIData: " .. data)
        
end)

local function getRandomEnemies(count)
    local templateNames = {}
    
    for name, _ in pairs(EnemyTemplates) do
        table.insert(templateNames, name)
    end
    
    local randomIndex = math.random(1, #templateNames)
    local enemyName = templateNames[randomIndex]
    return EnemyTemplates[enemyName]  -- Return single enemy object directly
end

local function createVoteData(difficulty, enemy)
    local voteData = {
        info = string.format("You encounter a %s in a %s difficulty room!", 
            enemy.Name,
            difficulty),
        rewards = {
            gold = 2
        },
        options = {
            {
                text = "Fight the enemies head on",
                action = "Fight",
                voteCount = 0,
                maxVotes = 3
            },
            {
                text = "Try to sneak past",
                action = "Sneak",
                voteCount = 0,
                maxVotes = 4
            },
            {
                text = "Attempt to negotiate",
                action = "Negotiate",
                voteCount = 0,
                maxVotes = 3
            }
        }
    }
    
    return json.encode(voteData)
end

function GenerateDungeon(level)
    print("Generating dungeon for level: " .. level)
    
    local difficulties = {"Easy", "Medium", "Hard"}
    local selectedDifficulty = difficulties[math.random(1, #difficulties)]
    
    local enemy = getRandomEnemies(1)  -- count parameter no longer needed but kept for compatibility
    local enemyJson = json.encode(enemy)
    local votesJson = createVoteData(selectedDifficulty, enemy)
    
    local query = string.format([[
        INSERT INTO Dungeon (
            Level,
            Difficulty,
            Enemy,
            Status,
            Votes,
            RequiredLevel
        ) VALUES (
            %d,
            '%s',
            '%s',
            'Active',
            '%s',
            %d
        );
    ]], 
        level,
        selectedDifficulty,
        enemyJson,
        votesJson,
        math.max(1, level - 1)
    )
    
    dbAdmin:exec(query)
    local dungeonId = db:last_insert_rowid()
    print("Created dungeon with ID: " .. dungeonId)
    
    return dungeonId
end

Handlers.add("PrintDungeon", "print-dungeon", function (msg)
    print("All Dungeon Entries:")

    local dungeons = dbAdmin:exec("SELECT * FROM Dungeon;")

    if #dungeons == 0 then
        print("No dungeon entries found.")
        return
    end

    for _, row in ipairs(dungeons) do
        print("ID: " .. (row.ID or "N/A"))
        print("Level: " .. (row.Level or "N/A"))
        print("Difficulty: " .. (row.Difficulty or "N/A"))
        print("Enemy: " .. (row.Enemy or "N/A"))
        print("Status: " .. (row.Status or "N/A"))
        print("Votes: " .. (row.Votes or "N/A"))
        print("Required Level: " .. (row.RequiredLevel or "N/A"))
        print("--------------------------------------------------")
    end
end)

Handlers.add("CastVote", "cast-vote", function (msg)
    print("CastVote: " .. msg.From)
    CastVote(msg)
end)
