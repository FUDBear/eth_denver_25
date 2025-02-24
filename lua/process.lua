-- Process ID: V6B7QPRht21wl7sBykVsIt914j8A-6mnXHBUDH-SjyI
local json = require("json")
local sqlite3 = require("lsqlite3")

db = db or sqlite3.open_memory()
dbAdmin = require('DbAdmin').new(db)


function InitDb()
    db:exec(INVOICES)
    print("--InitDb--")

    local alterQuery = [[
        PRAGMA foreign_keys = OFF;
        BEGIN TRANSACTION;

        -- Create a temporary table with only WALLET, VOTE, and CHOICE columns
        CREATE TABLE IF NOT EXISTS Invoices_temp (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            Wallet TEXT UNIQUE,  -- Renamed from InvoiceID to Wallet
            Vote TEXT,
            Choice TEXT
        );

        -- Copy relevant data from the old table, assuming mappings
        INSERT INTO Invoices_temp (ID, Wallet, Vote, Choice)
        SELECT ID, InvoiceID, InvoiceType, Category FROM Invoices;

        -- Drop old table and rename the new table
        DROP TABLE Invoices;
        ALTER TABLE Invoices_temp RENAME TO Invoices;

        COMMIT;
        PRAGMA foreign_keys = ON;
    ]]
    
    local result = db:exec(alterQuery)
    if result ~= sqlite3.OK then
        print("Error updating Invoices table to include only WALLET, VOTE, CHOICE.")
    else
        print("Invoices table updated successfully with WALLET, VOTE, CHOICE columns.")
    end
end

-- || Admin Handlers || --

Handlers.add("Init", "Init", function (msg)  
    
    if msg.From ~= ao.id then
        return
    end

    InitDb()
end)

-- || Testing Handlers || --

Handlers.add(
  "pingpong",
  Handlers.utils.hasMatchingTag("Action", "pingpong"),
  Handlers.utils.reply("ETH Denver 2025 - pong")
)