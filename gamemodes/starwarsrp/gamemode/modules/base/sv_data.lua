--[[---------------------------------------------------------------------------
Functions and variables
---------------------------------------------------------------------------]]
local migrateDB

--[[---------------------------------------------------------
 Database initialize
 ---------------------------------------------------------]]
function DarkRP.initDatabase()
    MySQLite.begin()
        -- Gotta love the difference between SQLite and MySQL
        local AUTOINCREMENT = MySQLite.isMySQL() and "AUTO_INCREMENT" or "AUTOINCREMENT"

        -- Table that holds all position data (jail, spawns etc.)
        -- Queue these queries because other queries depend on the existence of the darkrp_position table
        -- Race conditions could occur if the queries are executed simultaneously
        MySQLite.queueQuery([[
            CREATE TABLE IF NOT EXISTS darkrp_position(
                id INTEGER NOT NULL PRIMARY KEY ]] .. AUTOINCREMENT .. [[,
                map VARCHAR(45) NOT NULL,
                type CHAR(1) NOT NULL,
                x INTEGER NOT NULL,
                y INTEGER NOT NULL,
                z INTEGER NOT NULL
            );
        ]])

        -- team spawns require extra data
        MySQLite.queueQuery([[
            CREATE TABLE IF NOT EXISTS darkrp_jobspawn(
                id INTEGER NOT NULL PRIMARY KEY,
                team INTEGER NOT NULL
            );
        ]])

        if MySQLite.isMySQL() then
            MySQLite.queueQuery([[
                SELECT NULL FROM information_schema.TABLE_CONSTRAINTS WHERE
                   CONSTRAINT_SCHEMA = DATABASE() AND
                   CONSTRAINT_NAME   = 'fk_darkrp_jobspawn_position' AND
                   CONSTRAINT_TYPE   = 'FOREIGN KEY'
            ]], function(data)
                if data and data[1] then return end

                MySQLite.query([[
                    ALTER TABLE darkrp_jobspawn ADD CONSTRAINT `fk_darkrp_jobspawn_position` FOREIGN KEY(id) REFERENCES darkrp_position(id)
                        ON UPDATE CASCADE
                        ON DELETE CASCADE;
                ]])
            end)
        end

        MySQLite.query([[
            CREATE TABLE IF NOT EXISTS playerinformation(
                uid BIGINT NOT NULL,
                steamID VARCHAR(50) NOT NULL PRIMARY KEY
            )
        ]])

        -- Player information
        MySQLite.query([[
            CREATE TABLE IF NOT EXISTS darkrp_player(
                uid BIGINT NOT NULL PRIMARY KEY,
                rpname VARCHAR(45),
                salary INTEGER NOT NULL DEFAULT 45,
                wallet INTEGER NOT NULL
            );
        ]])

        MySQLite.queueQuery([[
            CREATE TABLE IF NOT EXISTS darkrp_dbversion(version INTEGER NOT NULL PRIMARY KEY)
        ]])

        -- Load the last DBVersion into DarkRP.DBVersion, to allow checks to see whether migration is needed.
        MySQLite.queueQuery([[
            SELECT MAX(version) AS version FROM darkrp_dbversion
        ]], function(data) DarkRP.DBVersion = data and data[1] and tonumber(data[1].version) or 0 end)

        MySQLite.queueQuery([[
            REPLACE INTO darkrp_dbversion VALUES(20160610)
        ]])

        -- SQlite doesn't really handle foreign keys strictly, neither does MySQL by default
        -- So to keep the DB clean, here's a manual partial foreign key enforcement
        -- For now it's deletion only, since updating of the common attribute doesn't happen.

        -- MySQL trigger
        if MySQLite.isMySQL() then
            MySQLite.query("show triggers", function(data)
                -- Check if the trigger exists first
                if data then
                    for k,v in pairs(data) do
                        if v.Trigger == "JobPositionFKDelete" then
                            return
                        end
                    end
                end

                MySQLite.query("SHOW PRIVILEGES", function(privs)
                    if not privs then return end

                    local found;
                    for k,v in pairs(privs) do
                        if v.Privilege == "Trigger" then
                            found = true
                            break;
                        end
                    end

                    if not found then return end
                    MySQLite.query([[
                        CREATE TRIGGER JobPositionFKDelete
                            AFTER DELETE ON darkrp_position
                            FOR EACH ROW
                                IF OLD.type = "T" THEN
                                    DELETE FROM darkrp_jobspawn WHERE darkrp_jobspawn.id = OLD.id;
                                END IF
                        ;
                    ]])
                end)
            end)
        else -- SQLite triggers, quite a different syntax
            MySQLite.query([[
                CREATE TRIGGER IF NOT EXISTS JobPositionFKDelete
                    AFTER DELETE ON darkrp_position
                    FOR EACH ROW
                    WHEN OLD.type = "T"
                    BEGIN
                        DELETE FROM darkrp_jobspawn WHERE darkrp_jobspawn.id = OLD.id;
                    END;
            ]])
        end
    MySQLite.commit(fp{migrateDB, -- Migrate the database
        function() -- Initialize the data after all the tables have been created

            if MySQLite.isMySQL() then -- In a listen server, the connection with the external database is often made AFTER the listen server host has joined,
                                        --so he walks around with the settings from the SQLite database
                for k,v in pairs(player.GetAll()) do
                    DarkRP.offlinePlayerData(v:SteamID(), function(data)
                        if not data or not data[1] then return end

                        local Data = data[1]
                        v:setDarkRPVar("rpname", Data.rpname)
                        v:setSelfDarkRPVar("salary", Data.salary)
                        v:setDarkRPVar("money", Data.wallet)
                    end)
                end
            end

            hook.Call("DarkRPDBInitialized")
        end})
end

--[[---------------------------------------------------------------------------
Database migration
backwards compatibility with older versions of DarkRP
---------------------------------------------------------------------------]]
function migrateDB(callback)
    local migrateCount = 0

    local onFinish = function()
        migrateCount = migrateCount + 1

        if migrateCount == 2 then callback() end
    end

    if not DarkRP.DBVersion or (DarkRP.DBVersion < 20160610 and DarkRP.DBVersion ~= 0) then
        if not MySQLite.isMySQL() then
            -- darkrp_player used to have a UNIQUE rpname field.
            -- This sucks, get rid of it
            MySQLite.query([[PRAGMA foreign_keys=OFF]])

            MySQLite.query([[
                CREATE TABLE IF NOT EXISTS new_darkrp_player(
                    uid BIGINT NOT NULL PRIMARY KEY,
                    rpname VARCHAR(45),
                    salary INTEGER NOT NULL DEFAULT 45,
                    wallet INTEGER NOT NULL
                );
            ]])

            MySQLite.query([[INSERT INTO new_darkrp_player SELECT * FROM darkrp_player]])

            MySQLite.query([[DROP TABLE darkrp_player]])

            MySQLite.query([[ALTER TABLE new_darkrp_player RENAME TO darkrp_player]])

            MySQLite.query([[PRAGMA foreign_keys=ON]])

            onFinish()
        else
            -- if only SQLite were this easy
            MySQLite.query([[DROP INDEX rpname ON darkrp_player]], onFinish)
        end
    else
        onFinish()
    end
end

--[[---------------------------------------------------------
Players
 ---------------------------------------------------------]]
function DarkRP.storeRPName(ply, name)
    if not name or string.len(name) < 2 then return end
    hook.Call("onPlayerChangedName", nil, ply, ply:getDarkRPVar("rpname"), name)
    ply:setDarkRPVar("rpname", name)

    MySQLite.query([[UPDATE darkrp_player SET rpname = ]] .. MySQLite.SQLStr(name) .. [[ WHERE UID = ]] .. ply:SteamID64() .. ";")
    MySQLite.query([[UPDATE darkrp_player SET rpname = ]] .. MySQLite.SQLStr(name) .. [[ WHERE UID = ]] .. ply:UniqueID() .. ";")
end

function DarkRP.retrieveRPNames(name, callback)
    MySQLite.query("SELECT COUNT(*) AS count FROM darkrp_player WHERE rpname = " .. MySQLite.SQLStr(name) .. ";", function(r)
        callback(tonumber(r[1].count) > 0)
    end)
end

function DarkRP.offlinePlayerData(steamid, callback, failed)
    local sid64 = util.SteamIDTo64(steamid)
    local uniqueid = util.CRC("gm_" .. string.upper(steamid) .. "_gm")

    MySQLite.query(string.format([[REPLACE INTO playerinformation VALUES(%s, %s);]], MySQLite.SQLStr(sid64), MySQLite.SQLStr(steamid)), nil, failed)

    local query = [[
    SELECT rpname, wallet, salary, "SID64" AS kind
    FROM darkrp_player
    where uid = %s

    UNION

    SELECT rpname, wallet, salary, "UniqueID" AS kind
    FROM darkrp_player
    where uid = %s
    ;
    ]]

    MySQLite.query(
        query:format(sid64, uniqueid),
        function(data, ...)
            -- The database has no record of the player data in SteamID64 form
            -- Otherwise the first row would have kind SID64
            if data and data[1] and data[1].kind == "UniqueID" then
                -- The rpname must be unique
                -- adding a new row with uid = SteamID64, but the same rpname will remove the uid=UniqueID row

                local replquery = [[
                REPLACE INTO darkrp_player(uid, rpname, wallet, salary)
                VALUES (%s, %s, %s, %s)
                ]]

                MySQLite.begin()
                MySQLite.queueQuery(
                    replquery:format(
                        sid64,
                        data[1].rpname == "NULL" and "NULL" or MySQLite.SQLStr(data[1].rpname),
                        data[1].wallet,
                        data[1].salary
                        ),
                    nil,
                    failed
                    )
                MySQLite.commit()
            end

            return callback and callback(data, ...)
        end
        , failed
        )
end

function DarkRP.retrievePlayerData(ply, callback, failed, attempts, err)
    attempts = attempts or 0

    if attempts > 3 then return failed(err) end

    DarkRP.offlinePlayerData(ply:SteamID(), callback, function(sqlErr)
        DarkRP.retrievePlayerData(ply, callback, failed, attempts + 1, sqlErr)
    end)
end

function DarkRP.createPlayerData(ply, name, wallet, salary)
    MySQLite.query([[REPLACE INTO darkrp_player VALUES(]] ..
            ply:SteamID64() .. [[, ]] ..
            MySQLite.SQLStr(name)  .. [[, ]] ..
            salary  .. [[, ]] ..
            wallet .. ");")

    -- Backwards compatibility
    MySQLite.query([[REPLACE INTO darkrp_player VALUES(]] ..
            ply:UniqueID() .. [[, ]] ..
            MySQLite.SQLStr(name)  .. [[, ]] ..
            salary  .. [[, ]] ..
            wallet .. ");")
end

function DarkRP.storeMoney(ply, amount)
    if not IsValid(ply) then return end
    if not isnumber(amount) or amount < 0 or amount >= 1 / 0 then return end

    -- Also keep deprecated UniqueID data at least somewhat up to date
    MySQLite.query([[UPDATE darkrp_player SET wallet = ]] .. amount .. [[ WHERE uid = ]] .. ply:UniqueID() .. [[ OR uid = ]] .. ply:SteamID64())
end

function DarkRP.storeOfflineMoney(sid64, amount)
    if isnumber(sid64) or isstring(sid64) and string.len(sid64) < 17 then -- smaller than 76561197960265728 is not a SteamID64
        DarkRP.errorNoHalt([[Some addon is giving DarkRP.storeOfflineMoney a UniqueID as its first argument, but this function now expects a SteamID64]], 2,
            { "The function used to take UniqueIDs, but it does not anymore."
            , "If you are a server owner, please look closely to the files mentioned in this error"
            , "After all, these files will tell you WHICH addon is doing it"
            , "This is NOT a DarkRP bug!"
            , "Your server will continue working normally"
            , "But whichever addon just tried to store an offline player's money"
            , "Will NOT take effect!"
            })
    end

    -- Also store on deprecated UniqueID
    local uniqueid = util.CRC("gm_" .. string.upper(util.SteamIDFrom64(sid64)) .. "_gm")
    MySQLite.query([[UPDATE darkrp_player SET wallet = ]] .. amount .. [[ WHERE uid = ]] .. uniqueid .. [[ OR uid = ]] .. sid64)
end

local function resetAllMoney(ply,cmd,args)
    if ply:EntIndex() ~= 0 and not ply:IsSuperAdmin() then return end
    MySQLite.query("UPDATE darkrp_player SET wallet = " .. GAMEMODE.Config.startingmoney .. " ;")
    for k,v in pairs(player.GetAll()) do
        v:setDarkRPVar("money", GAMEMODE.Config.startingmoney)
    end
    if ply:IsPlayer() then
        DarkRP.notifyAll(0,4, DarkRP.getPhrase("reset_money", ply:Nick()))
    else
        DarkRP.notifyAll(0,4, DarkRP.getPhrase("reset_money", "Console"))
    end
end
concommand.Add("rp_resetallmoney", resetAllMoney)

function DarkRP.storeSalary(ply, amount)
    ply:setSelfDarkRPVar("salary", math.floor(amount))

    return amount
end

function DarkRP.retrieveSalary(ply, callback)
    if not IsValid(ply) then return 0 end

    local val =
        ply:getJobTable() and ply:getJobTable().salary or
        RPExtraTeams[GAMEMODE.DefaultTeam].salary or
        (GM or GAMEMODE).Config.normalsalary

    if callback then callback(val) end

    return val
end

--[[---------------------------------------------------------------------------
Players
---------------------------------------------------------------------------]]
local meta = FindMetaTable("Player")
function meta:restorePlayerData()
    if not IsValid(self) then return end
    self.DarkRPUnInitialized = true

    DarkRP.retrievePlayerData(self, function(data)
        if not IsValid(self) then return end

        self.DarkRPUnInitialized = nil

        local info = data and data[1] or {}
        if not info.rpname or info.rpname == "NULL" then info.rpname = string.gsub(self:SteamName(), "\\\"", "\"") end

        info.wallet = info.wallet or GAMEMODE.Config.startingmoney
        info.salary = DarkRP.retrieveSalary(self)

        self:setDarkRPVar("money", tonumber(info.wallet))
        self:setSelfDarkRPVar("salary", tonumber(info.salary))

        self:setDarkRPVar("rpname", info.rpname)

        if not data then
            info = hook.Call("onPlayerFirstJoined", nil, self, info) or info
            DarkRP.createPlayerData(self, info.rpname, info.wallet, info.salary)
        end
    end, function(err) -- Retrieving data failed, go on without it
        self.DarkRPUnInitialized = true -- no information should be saved from here, or the playerdata might be reset

        self:setDarkRPVar("money", GAMEMODE.Config.startingmoney)
        self:setSelfDarkRPVar("salary", DarkRP.retrieveSalary(self))
        local name = string.gsub(self:SteamName(), "\\\"", "\"")
        self:setDarkRPVar("rpname", name)

        self.DarkRPDataRetrievalFailed = true -- marker on the player that says shit is fucked
        DarkRP.error("Failed to retrieve player information from the database. ", nil, {"This means your database or the connection to your database is fucked.", "This is the error given by the database:\n\t\t" .. tostring(err)})
    end)
end
