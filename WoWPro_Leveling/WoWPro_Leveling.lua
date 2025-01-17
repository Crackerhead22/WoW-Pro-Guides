-------------------------------
--      WoWPro_Leveling      --
-------------------------------

WoWPro.Leveling = WoWPro:NewModule("Leveling")
local myUFG = UnitFactionGroup("player")
WoWPro:Embed(WoWPro.Leveling)


-- Called before all addons have loaded, but after saved variables have loaded. --
function WoWPro.Leveling:OnInitialize()
	if WoWProCharDB.AutoHideLevelingInsideInstances == nil then
	    WoWProCharDB.AutoHideLevelingInsideInstances = true
	end
end

-- Called when the module is enabled, and on log-in and /reload, after all addons have loaded. --
function WoWPro.Leveling:OnEnable()
	WoWPro.Leveling:dbp("|cff33ff33Enabled|r")
	
	-- Leveling Tag Setup --
	WoWPro:RegisterTags({"QID", "questtext", "prereq", "noncombat", "leadin", "rep"})
	
	-- Event Registration --
	WoWPro.Leveling.Events = {"QUEST_LOG_UPDATE", 
		"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "MINIMAP_ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", 
		"UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT", "PLAYER_LEVEL_UP", "TRAINER_UPDATE",
		"QUEST_GREETING","GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE"
	}
	WoWPro:RegisterEvents(WoWPro.Leveling.Events)
	
	--Loading Frames--
	if not WoWPro.Leveling.FramesLoaded then --First time the addon has been enabled since UI Load
		WoWPro.Leveling:CreateConfig()
		WoWPro.Leveling.CreateSpellFrame()
		WoWPro.Leveling.CreateSpellListFrame()
		WoWPro.Leveling.CreateGuideList()
		WoWPro.Leveling.FramesLoaded = true
	end
	
	-- Loading Initial Guide --
	local locClass, engClass = UnitClass("player")
	local locRace, engRace = UnitRace("player")
	-- New Level 1 Character --
	if UnitLevel("player") == 1 and UnitXP("player") == 0 then
		local startguides = {
			Orc = "JiyDur0105", 
			Troll = "BitDur0105", 
			Scourge = "JiyTir0112",
			Tauren = "GylMul0105",
			BloodElf = "SnoEve0112",
			Goblin = "MalKez0105", 
			Draenei = "SnoAzu0112",
			NightElf = "BitTel0110",
			Dwarf = "GylDwa0105",
			Gnome = "GylGno0105",
			Human = "KurElw0111",
			Worgen = "RpoGil0113",
		}
		WoWPro:LoadGuide(startguides[engRace])
	-- New Death Knight --
	elseif UnitLevel("player") == 55 and UnitXP("player") < 1000 and engClass == "DEATHKNIGHT" then
		WoWPro:LoadGuide("JamScar5558")
	-- No current guide, but a guide was stored for later use --
	elseif WoWProDB.char.lastlevelingguide and not WoWProDB.char.currentguide then
		WoWPro:LoadGuide(WoWProDB.char.lastlevelingguide)
	end
	
	WoWPro.Leveling.FirstMapCall = true
	
	-- Server query for completed quests --
	QueryQuestsCompleted()
end

-- Called when the module is disabled --
function WoWPro.Leveling:OnDisable()
	-- Unregistering Leveling Module Events --
	WoWPro:UnregisterEvents(WoWPro.Leveling.Events)
	
	--[[ If the current guide is a leveling guide, removes the map point, stores the guide's ID to be resumed later, 
	sets the current guide to nil, and loads the nil guide. ]]
	if WoWPro.Guides[WoWProDB.char.currentguide] and WoWPro.Guides[WoWProDB.char.currentguide].guidetype == "Leveling" then
		WoWPro:RemoveMapPoint()
		WoWProDB.char.lastlevelingguide = WoWProDB.char.currentguide
		WoWProDB.char.currentguide = nil
		WoWPro:LoadGuide()
	end
end

-- Guide Registration Function --
function WoWPro.Leveling:RegisterGuide(GIDvalue, zonename, authorname, startlevelvalue, 
	endlevelvalue, nextGIDvalue, factionname, sequencevalue)
	
--[[ Purpose: 
		Called by guides to register them to the WoWPro.Guide table. All members
		of this table must have a quidetype parameter to let the addon know what 
		module should handle that guide.]]
		
	if factionname and factionname ~= myUFG and factionname ~= "Neutral" then return end 
		-- If the guide is not of the correct faction, don't register it
		
	WoWPro:dbp("Guide Registered: "..GIDvalue)
	if factionname == "Neutral" then
	    -- nextGIDvalue is faction dependent.   Split it and pick the right one "AllianceGUID|HordeGID"
	    local  AllianceGUID, HordeGID = string.split("|",nextGIDvalue)
	    if myUFG == "Alliance" then
	        nextGIDvalue = AllianceGUID
	    else
	        nextGIDvalue = HordeGID
	    end
        WoWPro:dbp("Neutral Guide "..GIDvalue.." for "..myUFG.." chose "..nextGIDvalue)
	end
	WoWPro.Guides[GIDvalue] = {
		guidetype = "Leveling",
		zone = zonename,
		author = authorname,
		startlevel = startlevelvalue,
		endlevel = endlevelvalue,
		sequence = sequencevalue,
		nextGID = nextGIDvalue,
		faction = factionname
	}
end

function WoWPro.Leveling:LoadAllGuides()
    WoWPro:Print("Test Load of All Guides")
    local aCount=0
    local hCount=0
    local nCount=0
    local nextGID
    local zed
	for guidID,guide in pairs(WoWPro.Guides) do
	    if WoWPro.Guides[guidID].guidetype == "Leveling" then
            WoWPro:Print("Test Loading " .. guidID)
	        WoWPro:LoadGuide(guidID)
	        nextGID = WoWPro.Guides[guidID].nextGID
	        zed = strtrim(string.match(WoWPro.Guides[guidID].zone, "([^%(%-]+)" ))
	        if not WoWPro:ValidZone(zed) then
			    WoWPro:Print("Invalid guide zone:"..(WoWPro.Guides[guidID].zone))
			end
	        if nextGID == nil or WoWPro.Guides[nextGID] == nil then	    
	            WoWPro:Print("Successor to " .. guidID .. " which is " .. tostring(nextGID) .. " is invalid.")
	        end
	        if WoWPro.Guides[guidID].faction == "Alliance" then aCount = aCount + 1 end
	        if WoWPro.Guides[guidID].faction == "Neutral"  then nCount = nCount + 1 end
	        if WoWPro.Guides[guidID].faction == "Horde"    then hCount = hCount + 1 end
	    end
	end
        WoWPro:Print(string.format("Done! %d A, %d N, %d H guides present", aCount, nCount, hCount))
end	    

