ESODB = {}
ESODB.name = "ESODB"
ESODB.version = "0.0.12"
ESODB.savedVars = {}

-- Saved Variables:
ESODB.activeTarget = {}
ESODB.lastTarget = {}
ESODB.currentPlayer = {}
ESODB.currentConversation = { npcName = "", npcLevel = 0, x = 0, y = 0, subzone = "", world = "" }

ESODB.processingNode = ""

function ESODB.savedVar(version, name, defaultData)
  if defaultData == nil then
    -- Use default data (empty)
    defaultData = { data = {} }
  end
  return ZO_SavedVars:NewAccountWide("ESODB_SavedVariables", version, name, defaultData)
end

function ESODB.InitSavedVariables(...)
  ESODB.savedVars = {
    -- Addon settings
    ["settings"]        = ESODB.savedVar(2, "settings", { debug = 0, info = 0, addonVersion = ESODB.Version, gathertype = "light" }),
    -- Character info
    ["character"]       = ESODB.savedVar(3, "character", nil),
    -- NPC related
    ["npc"]             = ESODB.savedVar(2, "npc", nil),
    ["vendor"]          = ESODB.savedVar(2, "vendor", nil),
    ["conversation"]    = ESODB.savedVar(2, "conversation", nil),
    -- Quests
    ["quest"]           = ESODB.savedVar(2, "quest", nil),
    -- Loot
    ["loot"]            = ESODB.savedVar(2, "loot", nil), -- Search loot, by either NPC or bag/etc
    ["questitem"]       = ESODB.savedVar(2, "questitem", nil), -- Quest item loot, not linkable
    ["take"]            = ESODB.savedVar(2, "take", nil), -- Butterfly's / Mugs
    ["harvest"]         = ESODB.savedVar(2, "harvest", nil), -- Mine nodes, Runes, Plants, Logs
    -- Location of Nodes (Mines/Fish/Books/Doors)
    ["book"]            = ESODB.savedVar(2, "book", nil),
    ["craftingstation"] = ESODB.savedVar(2, "craftingstation", nil),
    ["wayshrine"]       = ESODB.savedVar(2, "wayshrine", nil),
    ["skyshard"]        = ESODB.savedVar(2, "skyshard", nil),
    ["fish"]            = ESODB.savedVar(2, "fish", nil),
    ["chest"]           = ESODB.savedVar(2, "chest", nil),
    ["door"]            = ESODB.savedVar(1, "door", nil),

    -- For debugging and unknown stuff
    ["unknown"]         = ESODB.savedVar(1, "unknown", nil),
  }
end

function ESODB.InitCharacter()
  ESODB.currentPlayerName = ESODB.GetUnitName("player")
  savedVar = ESODB.savedVars["character"].data

  if savedVar[ESODB.currentPlayerName] == nil then
    savedVar[ ESODB.currentPlayerName ] = {}
  end
end

function ESODB.GetUnitAlliance(tag)
  return GetUnitAlliance(tag)
end

function ESODB.GetUnitName(tag)
  return GetUnitName(tag)
end

function ESODB.GetUnitType(tag)
  return GetUnitType(tag)
end

function ESODB.GetUnitLevel(tag)
  return GetUnitLevel(tag)
end

-- Function(fix) from ZAM's Esohead Addon (Thanks ZAM/Esohead)
function ESODB.GetUnitPosition(unitId)
  if unitId ~= nil and IsPlayerActivated() then
    local setMapToLoc = SetMapToPlayerLocation()
    if(setMapToLoc == 2) then
      CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    local x, y, z = GetMapPlayerPosition(unitId)
    local subzone = GetMapName()
    local world = GetUnitZone(unitId)

    return x, y, z, subzone, world
  end
  return
end

function ESODB.GetLootItemInfo(index)
  -- local lootId, name, icon, count, quality, value, isQuest, isFinesse = GetLootItemInfo(i)
  return GetLootItemInfo(index)
end

function ESODB.isLootQuestItem(index)
  -- Only if item is in backpack already, index = number of bagId
  -- return select(8, GetLootItemInfo(index))
end

function ESODB.GatherObject(doNotLogAgain, targetType, keys, ... )
  if doNotLogAgain then

    local xPos = 0
    local yPos = 0

    for key,value in pairs(...) do
      if key == "x" then xPos = value end
      if key == "y" then yPos = value end
    end
    if ESODB.ObjectNotFound(targetType, keys, xPos, yPos ) then
      ESODB.SaveData(targetType, keys, ... )
    else
      ESODB.Debug("Already found in data...")
    end
  else
    ESODB.SaveData(targetType, keys, ... )
  end

end

function ESODB.OnUpdate()
    local objectAction, objectName, interactionBlocked, additionalInfo, context = GetGameCameraInteractableActionInfo()
    local playerInteracting = IsPlayerInteractingWithObject()
    local interactionType = GetInteractionType()

    -- Action is empty
    if objectAction == nil then
        -- Clearing targets
        ESODB.activeTarget = {}
        return
    end

    -- Not interacting with an object
    if objectName == nil then
        -- Clearing targets
        ESODB.activeTarget = {}
        return
    end

    -- Function might run before player is even activated? Just to be safe:
    if not IsPlayerActivated() then
        return
    end

    local activeTarget = ESODB.activeTarget
    local lastTarget = ESODB.lastTarget

    -- Checking if we're already using the target to avoid loops
    if lastTarget ~= nil and lastTarget.name ~= nil and objectName == lastTarget.name then
        if interactionType == INTERACTION_FAST_TRAVEL or interactionType == 23 then
            -- Wayshrines and Craftingstations
            if objectName == activeTarget.name then
                -- Is current target already
                return
            end
        else
            -- Is current target already (just by name)
            return
        end
    end

    local xPos, yPos, z, subzone, world = ESODB.GetUnitPosition("player")

    -- Setting lastTarget that we can process for future references
    ESODB.lastTarget = { interaction = interactionType, action = objectAction, name = objectName, x = xPos, y = yPos }
    -- if GetCraftingInteractionType() ~= CRAFTING_TYPE_INVALID then processingHarvest = false return end

    local dateValue = GetDate()
    local timeValue = GetTimeString()

    -- Harvest
    if objectAction == GetString(SI_GAMECAMERAACTIONTYPE3) then
      ESODB.Debug("Harvest..")
      ESODB.processingNode = "harvest"
      --ESODB.activeTarget = { interaction = interactionType, action = objectAction, name = objectName, x = xPos, y = yPos }

    -- Use
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE5) then
        ESODB.Debug("Use..")
        -- No special Interaction
        if interactionType == INTERACTION_NONE then
            --Skyshard
            if objectName == "Skyshard" then -- Does this work in German/Russian/etc?
                ESODB.Debug("Skyshard..")
                ESODB.GatherObject(true, "skyshard", {subzone, objectName}, { x = xPos, y = yPos, date = dateValue, time = timeValue } )
            else
                ESODB.Debug("Debugging INTERACTION_NONE")
            end
        -- Crafting station
        elseif interactionType == 23 and playerInteracting then
            ESODB.Debug("craftingstation..")
            ESODB.activeTarget = { interaction = interactionType, action = objectAction, name = objectName, x = xPos, y = yPos }
            ESODB.GatherObject(true, "craftingstation", {subzone, objectName}, { x = xPos, y = yPos, date = dateValue, time = timeValue } )

        -- Wayshrine
        elseif interactionType == INTERACTION_FAST_TRAVEL and playerInteracting then
            ESODB.Debug("wayshrine..")
            ESODB.activeTarget = { interaction = interactionType, action = objectAction, name = objectName, x = xPos, y = yPos }
            ESODB.GatherObject(true, "wayshrine", {subzone, objectName}, { x = xPos, y = yPos, date = dateValue, time = timeValue } )

        elseif interactionType == nil then
            ESODB.Debug("Nil!..")
        else
            ESODB.Debug("Uknown Update: " .. objectName .. " " .. interactionType )
        end

    -- Search
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE1) then
        ESODB.Debug("Search..")
        ESODB.processingNode = "loot"
    -- Talk
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE2) then
        -- Not in use
    -- Read
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE6) then
        -- Not in use
    -- Disarm
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE4) then
        -- Not in use
    -- Take
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE7) then
        -- harvest / provisioning / misc
        ESODB.processingNode = "take"
        ESODB.Debug("Take..")
    -- Destroy
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE8) then
    ESODB.Debug("Destroy..")

    -- Repair
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE9) then
        -- Not in use

    -- Inspect
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE10) then
        ESODB.Debug("Inspect..")

    -- Repair
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE11) then
        -- Not in use

    -- Unlock
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE12) then
    -- Chests
        ESODB.Debug("Chests..")
        ESODB.GatherObject(true, "chest", {subzone}, { x = xPos, y = yPos, date = dateValue, time = timeValue } )

    -- Open
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE13) then
        ESODB.GatherObject(true, "door", {subzone, objectName}, { x = xPos, y = yPos, date = dateValue, time = timeValue } )

    -- Examine
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE15) then
        ESODB.Debug("Examine..")

    -- Fish
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE16) then
        ESODB.Debug("Fish..")
        ESODB.GatherObject(true, "fish", {subzone}, { x = xPos, y = yPos, date = dateValue, time = timeValue } )

    -- Reel in
    elseif objectAction == GetString(SI_GAMECAMERAACTIONTYPE17) then
        ESODB.Debug("Reel in..")

    else
        ESODB.Debug("Everything else...should be harvest, if it has loot")
        ESODB.processingNode = "harvest"
    end
end

-- Log ALL NPC's \0/ (And thats also an issue.. so we need to filter this somehow --> BROKEN SINCE LATEST ESO UPDATE!)
function ESODB.OnTargetChange(eventCode)
  local unitType = ESODB.GetUnitType("reticleover")

  -- perhaps use the timeStamp() to give it some time.
  if unitType ~= nil then
    local unitName = ESODB.GetUnitName("reticleover")
    local unitReaction = GetUnitReaction("reticleover")

    -- Checking unitReaction solves not logging Clannfears and familiars pets (type 7)
        -- 3 = UNIT_REACTION_HOSTILE
        -- 4 = UNIT_REACTION_NEUTRAL
        -- 5 = Guards, Butterflies, random npcs in town
        -- 7 = Pets
    if unitType == 2 and unitName ~= nil and unitName ~= "" and unitReaction ~= 7 then
      local xPos, yPos, zPos, subzone, world = ESODB.GetUnitPosition("reticleover")
      -- Didn't get a valid location. Ignore
      if xPos <= 0 or yPos <= 0 then
        return
      end

      if ESODB.savedVars["settings"].gathertype == "light" then  
        local npcs = ESODB.savedVars["npc"].data
        if npcs[subzone] ~= nil then 
          local npcSubzone = npcs[subzone]
          if npcSubzone[unitName] ~= nil then
            local unitNames = npcSubzone[unitName]
            if #unitNames >= 5 then
                ESODB.Debug("Npc name has been counted 5 time already, stopping....")
                return
            end
          end
          if #npcSubzone >= 300 then
            ESODB.Debug("Npc count for zone reached 300, stopping....")
            return
          end
        end
      end

      local dateValue = GetDate()
      local timeValue = GetTimeString()
      local unitCaption = GetUnitCaption("reticleover")

      local unitLevel = ESODB.GetUnitLevel("reticleover")
      ESODB.GatherObject(true, "npc", {subzone, unitName}, { x = xPos, y = yPos, level = unitLevel, date = dateValue, time = timeValue, unitreaction = unitReaction, unitcaption = unitCaption } )
      ESODB.Debug( "Unitreaction: " .. unitReaction .. " for " .. unitName )
    end
  end
end

-- Log Conversations from NPC
function ESODB.OnChatterBegin(_, chatterOptionCount)
  local xPos, yPos, zPos, subzone, world = ESODB.GetUnitPosition("player")
  local npcLevel = ESODB.GetUnitLevel("interact")
  local greeting = GetChatterGreeting()
  local dateValue = GetDate()
  local timeValue = GetTimeString()

  if greeting == nil then
    return
  else
    ESODB.currentConversation = {
      npcName = ESODB.lastTarget.name,
      x = xPos,
      y = yPos,
      npcLevel = npcLevel,
      subzone = subzone
    }
    savedVarConversations = ESODB.savedVars["conversation"].data
    if savedVarConversations[subzone] == nil then
      savedVarConversations[subzone] = {}
    end

    greeting = string.gsub(greeting, "\n", "|") -- remove line breaks
    greeting = string.gsub(greeting, "\"","''") -- replace " to '

    ESODB.GatherObject(true, "conversation", {subzone, ESODB.lastTarget.name}, { x = xPos, y = yPos, options = chatterOptionCount, greeting = greeting, date = dateValue, time = timeValue } )
  end
end

function ESODB.OnShowBook(eventCode, title, body, medium, showTitle)
  local xPos, yPos, zPos, subzone, world = ESODB.GetUnitPosition("player") -- Like a chest, we dont have a loc for books/scrolls/etc
  local dateValue = GetDate()
  local timeValue = GetTimeString()

  if xPos <= 0 or yPos <= 0 then return false end
  if body == nil then return false end
  if type( body ) ~= "string" then return false end

  ESODB.Debug( "Book read. Medium: " .. medium )

  setBody = string.gsub(body, "\n", "|") -- remove line breaks
  setBody = string.gsub(setBody, "\"","''") -- replace " to '

  local newBody = {}

  while string.len(setBody) > 1024 do
    table.insert(newBody, string.sub(setBody, 0, 1024))
    setBody = string.sub(setBody, 1025)
  end
  table.insert(newBody, setBody)

  ESODB.GatherObject(true, "book", {subzone, title}, { x = xPos, y = yPos, text = newBody, medium = medium, date = dateValue, time = timeValue } )
end

function ESODB.OnQuestAdded(_, questIndex)
  local questName = GetJournalQuestInfo(questIndex)
  local questLevel = GetJournalQuestLevel(questIndex)
  local dateValue = GetDate()
  local timeValue = GetTimeString()

  ESODB.Debug("Quest added..")

  if ESODB.currentConversation.npcName == "" or ESODB.currentConversation.npcName == nil then
    -- What happens when you get a quest not by an NPC? Perhaps a book or some sort...
    ESODB.Debug("by non-npc..")
    ESODB.Debug(questName)
    ESODB.Debug(questLevel)
    ESODB.Debug(ESODB.lastTarget)
    ESODB.Debug("/Quest added")
  else
    -- Log quests given by NPC's
    ESODB.GatherObject(true, "quest", {ESODB.currentConversation.subzone, questName}, { x = ESODB.currentConversation.x, y= ESODB.currentConversation.y, date = dateValue, time = timeValue } )
  end
end

-- Update Money on current player
function ESODB.UpdateMoney(_, money)
  sv = ESODB.savedVars["character"].data
  local player = sv[ ESODB.currentPlayerName ]
  if player.money == nil then
    player.money = {}
  end

  player.money = money

  ESODB.Debug( "Debug: [UpdateMoney] data: " .. money )
end

-- Log the vendor with all it's items
function ESODB.ShowStoreWindow()
  local action, npcName, interactionBlocked, additionalInfo, context = GetGameCameraInteractableActionInfo()
  local xPos, yPos, zPos, subzone, world = ESODB.GetUnitPosition("interact")
  local active = IsPlayerInteractingWithObject()
  local storeItems = {}

  ESODB.Debug( "Debugging ShowStoreWindow .... " )
  ESODB.targetStore = true;

  if ESODB.ObjectNotFound("vendor", {subzone, npcName}, xPos, yPos) then
      for entryIndex = 1, GetNumStoreItems() do
      -- ./EsoUI/Ingame/Storewindow/Storewindow.lua
      local icon, name, stack, price, sellPrice, meetsRequirementsToBuy, meetsRequirementsToEquip, quality, questNameColor, currencyType1, currencyId1, currencyQuantity1, currencyIcon1, currencyName1, currencyType2, currencyId2, currencyQuantity2, currencyIcon2, currencyName2 = GetStoreEntryInfo(entryIndex)

      if(stack > 0) then
        local itemData = {
          name = name,
          price = price,
          quality = quality,
          stack = stack,
          sncolor = questNameColor,
          ctype1 = currencyType1,
          ctype2 = currencyType2,
          cq1 = currencyQuantity1,
          cq2 = currencyQuantity2,
          seti = GetStoreEntryTypeInfo(entryIndex),
          sesv = GetStoreEntryStatValue(entryIndex),
        }

        storeItems[#storeItems + 1] = itemData
      end
    end

    ESODB.GatherObject(false,"vendor", {subzone, npcName}, { x = xPos, y = yPos, storeitems = storeItems } ) -- false because we already checked above, no need to check again
  end
end

function ESODB.CloseStoreWindow()
  ESODB.Debug( "Debugging CloseStoreWindow .... " )
  ESODB.targetStore = false;
end


function ESODB.OnStablesInteractStart()
  local action, npcName, interactionBlocked, additionalInfo, context = GetGameCameraInteractableActionInfo()
  local xPos, yPos, zPos, subzone, world = ESODB.GetUnitPosition("interact")
  local active = IsPlayerInteractingWithObject()
  local storeItems = {}

  ESODB.Debug( "Debugging OnStablesInteractStart .... " )

  if ESODB.ObjectNotFound("vendor", {subzone, npcName}, xPos, yPos) then
    for entryIndex = 1, GetNumStoreItems() do
      -- ./EsoUI/Ingame/Storewindow/Storewindow.lua
      local icon, name, stack, price, sellPrice, meetsRequirementsToBuy, meetsRequirementsToEquip, quality, questNameColor, currencyType1, currencyId1, currencyQuantity1, currencyIcon1, currencyName1, currencyType2, currencyId2, currencyQuantity2, currencyIcon2, currencyName2 = GetStoreEntryInfo(entryIndex)

      if(stack > 0) then
        local itemData = {
          name = name,
          price = price,
          quality = quality,
          stack = stack,
          sncolor = questNameColor,
          ctype1 = currencyType1,
          ctype2 = currencyType2,
          cq1 = currencyQuantity1,
          cq2 = currencyQuantity2,
          seti = GetStoreEntryTypeInfo(entryIndex),
          sesv = GetStoreEntryStatValue(entryIndex),
        }

        storeItems[#storeItems + 1] = itemData
      end
    end

    ESODB.GatherObject(false,"vendor", {subzone, npcName}, { x = xPos, y = yPos, storeitems = storeItems, storetype = "stable" } ) -- false because we already checked above, not need to check again
  end
end

function ESODB.OnQuestRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex)

end

function ESODB.OnAbilityProgressionUpdate(event, progressionIndex)

end

-- ./esoui/libraries/globals/debugutils.lua
function ESODB.SendMessage(text)
  if(CHAT_SYSTEM)
  then
    if(text == "") then
      text = "Empty String"
    end
    CHAT_SYSTEM:AddMessage(text)
  end
end

function ESODB.SendTable(t, indent, tableHistory)
  indent          = indent or "."
  tableHistory    = tableHistory or {}

  for k, v in pairs(t)
  do
    local vType = type(v)

    ESODB.SendMessage(indent.."("..vType.."): "..tostring(k).." = "..tostring(v))

    if(vType == "table")
    then
      if(tableHistory[v])
      then
        ESODB.SendMessage(indent.."Avoiding cycle on table...")
      else
        tableHistory[v] = true
        ESODB.SendTable(v, indent.."  ", tableHistory)
      end
    end
  end
end

function ESODB.ObjectNotFound(type, keys, xPos, yPos)
  local savedVars = {}
  local notfound = true

  -- If x or y somehow is empty/nil/or negative, reject
  if xPos <= 0 or yPos <= 0 then return false end
  if ESODB.savedVars[type] == nil then return true end
  if ESODB.savedVars[type].data == nil then return true end
  if keys == nil then return false end -- do not log empty keys

  savedVars = ESODB.savedVars[type].data

  for i = 1, #keys do
    local keyIndex = keys[i]
    if savedVars[keyIndex] == nil then savedVars[keyIndex] = {} end
    savedVars = savedVars[keyIndex]
  end

  for i = 1, #savedVars do
    local item = savedVars[i]
    local xPosSavedVar = 0
    local yPosSavedVar = 0
    for key,value in pairs(item) do
      if key == "x" then xPosSavedVar = value end
      if key == "y" then yPosSavedVar = value end
    end

    if math.abs(xPosSavedVar - xPos) < 0.003 and math.abs(yPosSavedVar - yPos) < 0.003 then
      -- Found a match already, do not save
      notfound = false
    end
  end

  return notfound

end

function ESODB.removeP(value)
  local cleanValue = ""
  cleanValue = tostring(value)
  local b,e = string.find(cleanValue,"^p")
  if b then
    value = string.sub(cleanValue,1,b-1)
  end
  return cleanValue
end

function ESODB.SaveData(dataType, keys, ...)
  local savedVars
  local debugStr = ""

  if (dataType == nil) or (keys == nil) then
    -- Ignore false logging
    return
  elseif ESODB.savedVars[dataType] == nil then
    ESODB.Debug("Uknown type? " .. dataType)
    return
  elseif ESODB.savedVars[dataType].data == nil then
    ESODB.Debug("Uknown type? (data nil) " .. dataType)
    return
  else
    savedVars = ESODB.savedVars[dataType].data
    -- Loop through keys
    for i = 1, #keys do
      local keyIndex = keys[i]
      debugStr = debugStr .. " " .. keyIndex .. " - "
      if keyIndex == nil then keyIndex = "nil" end -- To avoid nasty UI Error in case a key is empty
      if savedVars[keyIndex] == nil then
        savedVars[keyIndex] = {}
      end
      savedVars = savedVars[keyIndex]
    end

    -- To get nice info msg:
    infoData = ...
    local xPos = infoData.x or 0
    local yPos = infoData.y or 0
    xPos = xPos * 100
    yPos = yPos * 100
    local readablePos = string.format("[x=%0.2f,y=%0.2f]",xPos,yPos)
    debugStr = debugStr .. readablePos .. ":\n"

    for key,value in pairs(...) do
      if key ~= "x" and key ~= "y" and key ~= nil then
        debugStr = debugStr .. "[" .. key .. "] "
        if(type(value) == "table") then
          debugStr = debugStr .. "\n"
          for key2,value2 in pairs(value) do
            if value2 ~= nil then
              debugStr = debugStr .. "[" .. ESODB.removeP(value2) .. "] "
            end
          end
        else
          if value ~= nil then
            debugStr = debugStr .. "[" .. ESODB.removeP(value) .. "]"
            debugStr = debugStr .. "\n"
          end
        end
      end
    end

    local countSavedVars = #savedVars
    if countSavedVars == 0 then
        savedVars[1] = ...
    else
        savedVars[countSavedVars+1] = ...
    end

    ESODB.Info("Saved [" .. dataType .. "] {" .. debugStr .. "}" )
  end

end

function ESODB.Info(...)
  if ESODB.savedVars["settings"].info == 1 then
    for i = 1, select("#", ...) do
      local value = select(i, ...)
      if(type(value) == "table") then
        ESODB.SendTable(value)
      else
        ESODB.SendMessage(tostring (value))
      end
    end
  end
end

function ESODB.Debug(...)
  if ESODB.savedVars["settings"].debug == 1 then
    for i = 1, select("#", ...) do
      local value = select(i, ...)
      if(type(value) == "table")
      then
          ESODB.SendTable(value)
      else
          ESODB.SendMessage(tostring (value))
      end
    end
  end
end

function ESODB.GetCoordinates()
  local GetMouseOverControl = WINDOW_MANAGER:GetMouseOverControl()

  if (GetMouseOverControl == ZO_WorldMapContainer or GetMouseOverControl:GetParent() == ZO_WorldMapContainer) then
    local posMouseX, posMouseY = GetUIMousePosition()
    local WPContainerLeft = ZO_WorldMapContainer:GetLeft()
    local WPContainerTop = ZO_WorldMapContainer:GetTop()
    local parentOffsetX = ZO_WorldMap:GetLeft()
    local parentOffsetY = ZO_WorldMap:GetTop()
    local WPContainerWidth, WPContainerHeight = ZO_WorldMapContainer:GetDimensions()
    local WPWidth, WPHeight = ZO_WorldMap:GetDimensions()
    local percentageX = math.ceil(((posMouseX - WPContainerLeft) / WPContainerWidth) * 100)
    local percentageY = math.ceil(((posMouseY - WPContainerTop) / WPContainerHeight) * 100)

    ESODBCords:SetAlpha(0.7)
    ESODBCords:SetAnchor(TOPLEFT, nil, TOPLEFT, parentOffsetX + 0, parentOffsetY + WPHeight)
    ESODBCordsValue:SetText("Coordinates: " .. percentageX .. "," .. percentageY)
  else
    ESODBCords:SetAlpha(0)
  end
end


function ESODB.InitSlashCommands()
  SLASH_COMMANDS["/esodb"] = ESODB.ProcessSlashCommands
end

function ESODB.ProcessSlashCommands(cmd)
  local command = {}
  local i = 0
  -- Put all words in a table
  for word in cmd:gmatch("%w+") do
    if (word ~= "" and word ~= nil) then
      i = i + 1
      command[i] = string.lower(word)
    end
  end

  if #command == 2 then
    if command[1] == "debug" then
      if command[2] == "on" then
          ESODB.savedVars["settings"].debug = 1
          ESODB.SendMessage("ESODB debugger is now on")
      elseif command[2] == "off" then
          ESODB.savedVars["settings"].debug = 0
          ESODB.SendMessage("ESODB debugger is now off")
      else
          ESODB.SendMessage("Use '/esodb debug on' or '/esodb debug off'")
      end
    end
    if command[1] == "info" then
      if command[2] == "on" then
        ESODB.savedVars["settings"].info = 1
        ESODB.SendMessage("ESODB info is now on")
      elseif command[2] == "off" then
        ESODB.savedVars["settings"].info = 0
        ESODB.SendMessage("ESODB info is now off")
      else
        ESODB.SendMessage("Use '/esodb info on' or '/esodb info off'")
      end
    end
    if command[1] == "set" then
      if command[2] == "heavy" then
        ESODB.savedVars["settings"].gathertype = "heavy"
        ESODB.SendMessage("ESODB now gathers heavy (NPC's, book info..etc)")
      elseif command[2] == "light" then
        ESODB.savedVars["settings"].gathertype = "light"
        ESODB.SendMessage("ESODB now gathers lightly (bare info, not so heavy)")
      else
        ESODB.SendMessage("Use '/esodb set heavy' or '/esodb set light'")
      end
    end
    if command[1] == "clear" then
      for type,sv in pairs(ESODB.savedVars) do
        if type == command[2] and type ~= "settings" and ESODB.savedVars[type] ~= nil then
          ESODB.savedVars[type].data = {}
          ESODB.SendMessage("The data " .. command[2] ..  " has been cleared")
        end
      end
    end
  elseif command[1] == "clear" then
    for type,sv in pairs(ESODB.savedVars) do
      if type ~= "settings" then
        ESODB.savedVars[type].data = {}
      end
    end
      ESODB.SendMessage("The data has been cleared")
    elseif command[1] == "size" then
      -- Create a loop that counts all data.
      -- Too high = give warning, upload data and /esodb clear or /esodb clear npc
  else
    ESODB.SendMessage("Not a valid command")
  end
end


function ESODB.SingleSlotUpdate(eventID,bagID,slotID,isNew)
  if not isNew then return end
  ESODB.Debug("SingleSlotUpdate..")
end

function ESODB.OnLootReceived(eventCode, receivedBy, objectName, stackCount, soundCategory, lootType, lootedBySelf)
  ESODB.Debug("OnLootReceived..")

  if not IsGameCameraUIModeActive() then
    lastTarget = ESODB.lastTarget
    local isQuestItem = false
    local loot = {}

    local objectExplode = {}

    local i = 0
    for match in string.gmatch(objectName, ":(%w+)") do
      objectExplode[i] = match
      i = i + 1
    end

    if #objectExplode < 20 then
      loot.type = false
      loot.id = false
      loot.quality = false
    else
      loot.id = tonumber(objectExplode[1])
      loot.type = tonumber(objectExplode[2])
      loot.quality = tonumber(objectExplode[3])
    end

    -- Is a quest item?
    if loot.id == false then
      ESODB.Debug("is a quest item..")
      -- ESODB.isLootQuestItem(index) -- does not work, only for when its looted already
      isQuestItem = true
    end

    local xPos, yPos, zPos, subzone, world = ESODB.GetUnitPosition("player")
    local dateValue = GetDate()
    local timeValue = GetTimeString()

    ESODB.Debug(ESODB.processingNode)

    if isQuestItem then
      ESODB.GatherObject(false, "questitem", {subzone}, { x = xPos, y = yPos, stackcount = stackCount, target = lastTarget.name, object = objectName, date = dateValue, time = timeValue } )
    elseif ESODB.processingNode == "take" then
      -- Deer / Mug / Butterfly
      ESODB.GatherObject(false, "take", {subzone, lastTarget.name}, { x = xPos, y = yPos, object = objectName, stackcount = stackCount, id = loot.id, quality = loot.quality, date = dateValue, time = timeValue } )
    elseif ESODB.processingNode == "harvest" then
      -- Since "mine", collect" and "cut" do not have a seperate interaction (same as use i guess), it will all be logged here:
      ESODB.GatherObject(true, "harvest", {subzone, lastTarget.name}, { x = xPos, y = yPos, object = objectName, stackcount = stackCount, id = loot.id, quality = loot.quality, date = dateValue, time = timeValue } )
    elseif ESODB.processingNode == "loot" then
      -- All other loot thats looted by "Search", this can be an NPC or a chest.
      ESODB.GatherObject(false, "loot", {subzone, lastTarget.name}, { x = xPos, y = yPos, object = objectName, stackcount = stackCount, id = loot.id, quality = loot.quality, date = dateValue, time = timeValue } )
    else
      ESODB.Debug("This is unknown:")
      ESODB.Debug(lastTarget.name)
      ESODB.Debug("-")
      ESODB.Debug(loot)
      ESODB.Debug("-")
      ESODB.Debug(objectName)
      ESODB.Debug("-")
      ESODB.Debug( GetGameCameraInteractableActionInfo() )
      ESODB.Debug( "Interacting:" )
      ESODB.Debug( IsPlayerInteractingWithObject() )
      ESODB.Debug( "GetInteractionType" )
      ESODB.Debug( GetInteractionType() )
      ESODB.GatherObject(false, "unknown", {subzone, lastTarget.name}, { x = xPos, y = yPos, object = objectName, stackcount = stackCount, id = loot.id, quality = loot.quality, date = dateValue, time = timeValue } )
    end
  end

  -- Clear some settings
  ESODB.processingNode = ""
  ESODB.activeTarget = {}
  ESODB.lastTarget = {}

end

-- Gather all info about a player here
function ESODB.OnPlayerActivated(eventCode)
    local currentPlayerName = ESODB.currentPlayerName
    local health, maxHealth = GetUnitPower("player", POWERTYPE_HEALTH)
    local current = GetUnitPower("player", POWERTYPE_ULTIMATE)

    local stats = {
        hp = maxHealth,
        xp = GetUnitXP("player"),
        maxxp = GetUnitXPMax("player"),
        lvl = GetUnitLevel("player"),
        race = GetUnitRace("player"),
        class = GetUnitClass("player"),
        alliance = GetUnitAlliance("player"),
        avapoints = GetUnitAvARankPoints("player"),
        avarank  = GetUnitAvARank("player"),
        gender = GetUnitGender("player")
    }

    sv = ESODB.savedVars["character"].data
    local player = sv[ ESODB.currentPlayerName ]
    if player.stats == nil then
        player.stats = {}
    end
    player.stats = stats
    ESODB.Debug( "Debug: [OnPlayerActivated] data: " )
    ESODB.Debug(stats)
    ESODB.SendMessage("ESODB initialized. Have fun gathering!")
end

function ESODB.OnLoad(eventCode, addOnName)
    if addOnName ~= "ESODB" then return end

    -- Release Addon first in case it's still loaded
    EVENT_MANAGER:UnregisterForEvent(addOnName, eventCode)

    ESODB.InitSavedVariables()
    ESODB.InitCharacter()
    ESODB.InitSlashCommands()
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_LOOT_RECEIVED, ESODB.OnLootReceived)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_RETICLE_TARGET_CHANGED, ESODB.OnTargetChange)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_CHATTER_BEGIN, ESODB.OnChatterBegin)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_SHOW_BOOK, ESODB.OnShowBook)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_QUEST_ADDED, ESODB.OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_MONEY_UPDATE, ESODB.UpdateMoney)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_OPEN_STORE, ESODB.ShowStoreWindow)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_CLOSE_STORE, ESODB.CloseStoreWindow)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_STABLE_INTERACT_START, ESODB.OnStablesInteractStart)
    EVENT_MANAGER:RegisterForEvent(addOnName, EVENT_PLAYER_ACTIVATED, ESODB.OnPlayerActivated )

    -- Debug only so far:
    -- EVENT_MANAGER:RegisterForEvent("ESODB", EVENT_QUEST_REMOVED, ESODB.OnQuestRemoved) --completed quest?
    --EVENT_MANAGER:RegisterForEvent("ESODB", EVENT_ABILITY_PROGRESSION_XP_UPDATE, ESODB.OnAbilityProgressionUpdate)
    --EVENT_MANAGER:RegisterForEvent("ESODB", EVENT_CONVERSATION_UPDATED, ESODB.OnConversationUpdated) -- No use tracking yet, conversations are not in the right order

    EVENT_MANAGER:RegisterForEvent( addonName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ESODB.SingleSlotUpdate) -- Single slot
end

-- Load ESODB Addon:
EVENT_MANAGER:RegisterForEvent("ESODB", EVENT_ADD_ON_LOADED, ESODB.OnLoad)
