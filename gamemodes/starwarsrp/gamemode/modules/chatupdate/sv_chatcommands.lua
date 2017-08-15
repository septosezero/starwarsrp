
local function comms(ply, args)
   if args == "" then
        DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
        return ""
    end
    local DoSay = function(text)
        if text == "" then
            DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
            return
        end
        for k,v in pairs(player.GetAll()) do
            local col = team.GetColor(ply:Team())
            DarkRP.talkToPerson(v, col, "[COMMS] " .. " " .. ply:Nick(), Color(0, 255, 255, 255), text, ply)
        end
    end
    return args, DoSay
end
DarkRP.defineChatCommand("coms", comms, 1.5)
DarkRP.defineChatCommand("comms", comms, 1.5)


local function advert(ply, args)
   if args == "" then
        DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
        return ""
    end
    local DoSay = function(text)
        if text == "" then
            DarkRP.notify(ply, 1, 4, DarkRP.getPhrase("invalid_x", "argument", ""))
            return
        end
        for k,v in pairs(player.GetAll()) do
            local col = team.GetColor(ply:Team())
            DarkRP.talkToPerson(v, col, "[ADVERT] " .. " " .. ply:Nick(), Color(0, 255, 255, 255), text, ply)
        end
    end
    return args, DoSay
end
DarkRP.defineChatCommand("advert", advert, 1.5)
