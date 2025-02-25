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
        MaxHealth = 50,
        MaxPower = 5,
        Armor = 2,
        Gold = 10,
        Experience = 10
    },
    Pig = {
        Name = "Pig",
        ID = 2,
        MaxHealth = 75,
        MaxPower = 8,
        Armor = 4,
        Gold = 20,
        Experience = 20
    },
    Cow = {
        Name = "Cow",
        ID = 3,
        MaxHealth = 100,
        MaxPower = 12,
        Armor = 6,
        Gold = 30,
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
    RequiredLevel INTEGER DEFAULT 1,
    CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
]]

function InitDb()
    db:exec(ENTRIES) -- Add Dungeon table creation
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
    local enemies = {}
    local templateNames = {}
    
    for name, template in pairs(EnemyTemplates) do
        table.insert(templateNames, name)
    end
    
    for i = 1, count do
        local randomIndex = math.random(1, #templateNames)
        local enemyName = templateNames[randomIndex]
        table.insert(enemies, EnemyTemplates[enemyName])
    end
    
    return enemies
end

function GenerateDungeon(level)
    print("Generating dungeon for level: " .. level)
    
    local difficulties = {"Easy", "Medium", "Hard"}
    local selectedDifficulty = difficulties[math.random(1, #difficulties)]
    
    local enemyCount = selectedDifficulty == "Easy" and 1 or
                      selectedDifficulty == "Medium" and 2 or 3
    
    local enemies = getRandomEnemies(enemyCount)
    local enemiesJson = json.encode(enemies)
    
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
            '[]',
            %d
        );
    ]], 
        level,
        selectedDifficulty,
        enemiesJson,
        math.max(1, level - 1)  -- Required level is current level - 1, minimum 1
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
        print("Created At: " .. (row.CreatedAt or "N/A"))
        print("--------------------------------------------------")
    end
end)
