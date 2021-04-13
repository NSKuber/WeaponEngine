--The script which handles alternative fire modes switching
--By NSKuber

local worldInfo = worldGlobals.worldInfo
if worldInfo:IsMenuSimulationWorld() then return end

local isSP = worldInfo:IsSinglePlayer()

--player : CPlayerPuppetEntity
--weapon : CWeaponEntity

worldGlobals.WeaponEngineFiringModes = {}
worldGlobals.AltFireChangeWeaponMode = {}
worldGlobals.AltFireFunctions = {}
worldGlobals.AltFireFiringModes = {}
worldGlobals.AltFireCurrentFiringModes = {}

local altFireCommand = "plcmdAltFireSwitch"
if corIsAppEditor() then
  altFireCommand = "plcmdUse"
end

local anyAltFireWeaponOnLevel = false

--Wait until a weapon supporting alt modes is on the level
while true do
  local Weapons = worldInfo:GetAllEntitiesOfClass("CWeaponEntity")
  for i=1,#Weapons,1 do
    local path = Weapons[i]:GetParams():GetFileName()
    if (worldGlobals.WeaponEngineFiringModes[path] ~= nil) then
      anyAltFireWeaponOnLevel = true
    end
  end
  if anyAltFireWeaponOnLevel then break end
  Wait(Delay(0.1))
end

worldGlobals.AltFireTemplates = LoadResource("Content/Shared/Scripts/Templates/AltFire/AltFire.rsc")

--BASE FUNCTIONS--

--Function switching weapon modes
worldGlobals.WeaponEngineChangeWeaponMode = function(player,weapon,path,mode)
  local Table = worldGlobals.WeaponEngineFiringModes[path][mode]
  
  --EVENTS SWITCH
  if (Table["eventsSwitch"] ~= nil) then
    for _,pair in pairs(Table["eventsSwitch"]) do
      worldGlobals.CurrentWeaponScriptedParams[weapon][pair[1]] = worldGlobals.CurrentWeaponScriptedParams[weapon][pair[2]]
    end
  end
  
  --SPEED MULTIPLIERS
  if (Table["speedMult"] ~= nil) then
    weapon:SetRateOfFireMultiplier(Table["speedMult"])
  end
  
  --ATTACHMENTS
  for i,NewTable in pairs(worldGlobals.WeaponEngineFiringModes[path]) do
    if (i ~= mode) and (type(NewTable) == "table") then
      if (NewTable["attachments"] ~= nil) then
        for j=1,#NewTable["attachments"],1 do
          player:HideAttachmentOnWeapon(NewTable["attachments"][j])
        end
      end
    end
  end
  if (Table["attachments"] ~= nil) then
    for j=1,#Table["attachments"],1 do
      player:ShowAttachmentOnWeapon(Table["attachments"][j])
    end
  end
  
  --MISC
  if (Table["extras"] ~= nil) then
    RunAsync(function()
      Table["extras"](player,weapon)
    end)
  end 
  
end


local MyAltFireModes = {}

--Function synchronizing modes switching
worldGlobals.CreateRPC("server","reliable","AltFireSetFiringModeServer",function(player,weapon,path,mode)
  if not IsDeleted(weapon) and not IsDeleted(player) then
    if not player:IsLocalOperator() then
      while (worldGlobals.CurrentWeaponScriptedParams[weapon] == nil) do
        Wait(CustomEvent("OnStep"))
      end
      worldGlobals.AltFireCurrentFiringModes[weapon] = mode
      worldGlobals.WeaponEngineChangeWeaponMode(player,weapon,path,mode)
    end
  end
end)
worldGlobals.CreateRPC("client","reliable","AltFireSetFiringModeClient",function(player,weapon,path,mode)
  if IsDeleted(player) or IsDeleted(weapon) then return end
  worldGlobals.AltFireCurrentFiringModes[weapon] = mode
  worldGlobals.WeaponEngineChangeWeaponMode(player,weapon,path,mode)
  MyAltFireModes[path] = mode
  if worldGlobals.netIsHost and not isSP then
    worldGlobals.AltFireSetFiringModeServer(player,weapon,path,mode)
  end 
end)

--Function which tracks player's button presses to switch firing modes
worldGlobals.HandleAltFireSwitchModes = function(player,weapon,path,bAllowAltFire,bAllowReload)
  RunAsync(function()
    
    if not player:IsLocalOperator() then return end
    
    local switchSound = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("SwitchMode",worldInfo,player:GetPlacement())
    switchSound:SetParent(player,"")
    
    worldGlobals.AltFireCurrentFiringModes[weapon] = 1
    
    if (MyAltFireModes[path] ~= nil) then
      worldGlobals.AltFireCurrentFiringModes[weapon] = MyAltFireModes[path]
    end
     
    Wait(CustomEvent("OnStep"))
    worldGlobals.AltFireSetFiringModeClient(player,weapon,path,worldGlobals.AltFireCurrentFiringModes[weapon])
  
    while not IsDeleted(player) do
      if IsDeleted(weapon) then break end
      
      if (player:IsCommandPressed(altFireCommand) or (bAllowAltFire and player:IsCommandPressed("plcmdAltFire")) or (bAllowReload and player:IsCommandPressed("plcmdReload"))) and not player:IsWeaponBusy() then
        worldGlobals.AltFireCurrentFiringModes[weapon] = worldGlobals.AltFireCurrentFiringModes[weapon] % #worldGlobals.WeaponEngineFiringModes[path] + 1
        if IsDeleted(switchSound) then
          switchSound = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("SwitchMode",worldInfo,player:GetPlacement())
          switchSound:SetParent(player,"")          
        end        
        switchSound:PlayOnce()
        worldGlobals.AltFireSetFiringModeClient(player,weapon,path,worldGlobals.AltFireCurrentFiringModes[weapon])
      end
      
      Wait(CustomEvent("OnStep"))
    end
    
    if not IsDeleted(switchSound) then
      switchSound:Delete()
    end
      
  end)
end

------------------

--Base functions which catch and track players' weapons

local HandlePlayer = function(player)
  RunAsync(function()
    
    while not IsDeleted(player) do
      local weapon = player:GetRightHandWeapon()
      if weapon then
        local path = weapon:GetParams():GetFileName()
        if (worldGlobals.WeaponEngineFiringModes[path] ~= nil) then
          worldGlobals.HandleAltFireSwitchModes(player,weapon,path,worldGlobals.WeaponEngineFiringModes[path]["allowAltFire"],worldGlobals.WeaponEngineFiringModes[path]["allowReload"])
        end
        while not IsDeleted(weapon) do
          Wait(CustomEvent("OnStep"))
        end
      else 
        Wait(CustomEvent("OnStep"))
      end
    end    
    
  end)
end

local localPlayer
local IsHandled = {}

RunHandled(WaitForever,
OnEvery(CustomEvent("OnStep")),
function()
  if IsDeleted(localPlayer) then
    local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
    for i=1,#Players,1 do
      if not IsHandled[Players[i]] then
        IsHandled[Players[i]] = true 
        HandlePlayer(Players[i])
      end
    end
  end
end)