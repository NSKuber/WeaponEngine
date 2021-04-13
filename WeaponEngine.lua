--The script which handles scripted firing for the Weapon Engine
--By NSKuber

--weapon : CWeaponEntity
--player : CPlayerPuppetEntity
--collision : CCollisionTestTool
--monster : CLeggedCharacterEntity
--effect : CStaticSoundEntity
--decal : CDecalMarkerEntity

local worldInfo = worldGlobals.worldInfo
if worldInfo:IsMenuSimulationWorld() then return end

--Some preliminary setup
worldGlobals.WeaponScriptedFiringParams = {}
worldGlobals.WeaponScriptedFiringSoundsParams = {}

local gamemode = worldInfo:GetGameMode()
local isCoop = false
local CoopGamemodes = {"SinglePlayer","Survival","TeamSurvival","Cooperative","CooperativeCoinOp","CooperativeStandard","OneShotSurvival",
                       "Arcade","ArcadeSurvival","ArcadeSurvivalCoop","SeriousRPG","SeriousRPG_MP","WeaponShop","WeaponShop_MP",
                       "WeaponShopSurvival","WeaponShopSurvival_MP"}
for i = 1,#CoopGamemodes,1 do
  if gamemode == CoopGamemodes[i] then
    isCoop = true
    break
  end
end

local nonSolidCollisionType = "player_bullet_no_solids"
local solidCollisionType = "player_bullet"
if not isCoop then
  nonSolidCollisionType = "bullet"
  solidCollisionType = "bullet"
end

local bulletProj = LoadResource("Content/Shared/Scripts/Templates/WeaponEngine/Databases/Bullet.ep")
local isSP = worldInfo:IsSinglePlayer()

local EnemyToMaterial = worldGlobals.WeaponEngineEnemyToMaterial

local RegularPuppetClasses = {
  ["CPlayerPuppetEntity"] = true,
  ["CLeggedCharacterEntity"] = true,
  ["CSpiderPuppetEntity"] = true,
  ["CCaveDemonPuppetEntity"] = true,
  ["CPsykickPuppetEntity"] = true,
  ["CKhnumPuppetEntity"] = true,
  ["CAircraftCharacterEntity"] = true,
  ["CAutoTurretEntity"] = true,
  ["CScrapJackBossPuppetEntity"] = true,
  ["CUghZanPuppetEntity"] = true,
  ["CSS1LavaElementalPuppetEntity"] = true,     
  ["CSS1CannonRotatingEntity"] = true,   
  ["CSS1CannonStaticEntity"] = true,  
  ["CSS1ExotechLarvaPuppetEntity"] = true,  
  ["CSS1KukulkanPuppetEntity"] = true,
  ["CSS1SummonerPuppetEntity"] = true,
  ["CSS1UghZanPuppetEntity"] = true,
} 
worldGlobals.WERegularPuppetClasses = RegularPuppetClasses

local MaterialTemplates = {}
worldGlobals.WeaponEngineProjectileParams = {}
local IsFirePressed = {}
local HitEffects = {}
local DecalsTemplates = {}
local FiringSounds = {}
local TracerEffects = {}
local BeamEffects = {}

worldGlobals.WeaponEngineIsPlayerPoweredUp = {}

local bloodAndGoreSettings = 0

local Pi = 3.14159265359
local qNullQuat = mthHPBToQuaternion(0,0,0)

local QV = function(x,y,z,h,p,b)
  return mthQuatVect(mthHPBToQuaternion(h,p,b),mthVector3f(x,y,z))
end

local RndL = function(a,b)
  return (a + mthFloorF(mthRndF() * (b - a + 1)) % (b - a + 1))
end

--Function which is used to copy a fireable object from one table to another
worldGlobals.WeaponEngineCopyFireableObject = function(pathFrom,strEventFrom,iFrom,pathTo,strEventTo,iTo)
  worldGlobals.WeaponScriptedFiringParams[pathTo][strEventTo][iTo] = {}
  for name,value in pairs(worldGlobals.WeaponScriptedFiringParams[pathFrom][strEventFrom][iFrom]) do
    if (type(value) == "table") then
      worldGlobals.WeaponScriptedFiringParams[pathTo][strEventTo][iTo][name] = {}
      for i,val in pairs(value) do
        if (type(val) == "table") then
          worldGlobals.WeaponScriptedFiringParams[pathTo][strEventTo][iTo][name][i] = {}
          for j,v in pairs(val) do
            worldGlobals.WeaponScriptedFiringParams[pathTo][strEventTo][iTo][name][i][j] = v
          end
        else
          worldGlobals.WeaponScriptedFiringParams[pathTo][strEventTo][iTo][name][i] = val
        end
      end
    else
      worldGlobals.WeaponScriptedFiringParams[pathTo][strEventTo][iTo][name] = value
    end
  end
end

--Templates : CTemplatePropertiesHolder
if worldGlobals.NSKuberIsBFE then
  worldGlobals.WeaponEngineTemplates = LoadResource("Content/Shared/Scripts/Templates/WeaponEngine.rsc")
else
  worldGlobals.WeaponEngineTemplates = LoadResource("Content/Shared/Scripts/Templates/WeaponEngine_HD.rsc")
end

dofile("Content/Shared/Scripts/WeaponEngineAltFire.lua")

--Function which produces hit effects on solids
local SolidHitEffects = function(vPoint,vNormal,EffectPaths,SoundPaths,Decals,bDisableDefault)
  local qvHitEffects = mthQuatVect(mthDirectionToQuaternion((-1)*vNormal),vPoint+0.001*vNormal)
  qvHitEffects.qb = mthRndF() * Pi * 2
  
  if not bDisableDefault and isSP then
    worldInfo:SpawnProjectile(worldInfo:GetClosestLivingPlayer(worldInfo,10000),bulletProj,qvHitEffects,40,nil)
  end
    
  local Effects = {}

  if not bDisableDefault and not isSP then
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitDecal0"..RndL(1,2),worldInfo,qvHitEffects)
  end
  if (Decals ~= nil) then
    if (DecalsTemplates[Decals[1]] == nil) then
      DecalsTemplates[Decals[1]] = LoadResource(Decals[1])
    end
    Effects[#Effects+1] = DecalsTemplates[Decals[1]]:SpawnEntityFromTemplate(RndL(0,Decals[2] - 1),worldInfo,qvHitEffects)
  end
  qvHitEffects:SetQuat(mthDirectionToQuaternion(vNormal))
  if not bDisableDefault and not isSP then
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitEffect",worldInfo,qvHitEffects)
    Effects[#Effects]:Start()
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitSound0"..RndL(1,2),worldInfo,qvHitEffects)
    Effects[#Effects]:PlayOnce()    
  end
  if (EffectPaths ~= nil) then
    local strEffectPath = EffectPaths[RndL(1,#EffectPaths)]
    if (HitEffects[strEffectPath] == nil) then
      HitEffects[strEffectPath] = LoadResource(strEffectPath)
    end
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitEffect",worldInfo,qvHitEffects)
    Effects[#Effects]:ChangeEffect(HitEffects[strEffectPath])
    Effects[#Effects]:Start()
  end
  if (SoundPaths ~= nil) then
    local strSoundPath = SoundPaths[RndL(1,#SoundPaths)]
    if (HitEffects[strSoundPath] == nil) then
      HitEffects[strSoundPath] = LoadResource(strSoundPath)
    end
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitSound01",worldInfo,qvHitEffects)
    Effects[#Effects]:SetSound(HitEffects[strSoundPath])
    Effects[#Effects]:PlayOnce()
  end  

  RunAsync(function()
    Wait(Delay(10))
    for i=1,#Effects,1 do
      if not IsDeleted(Effects[i]) then
        Effects[i]:Delete()
      end
    end      
  end)
end


--Function which produces hit effects on non-solids (bodies)
local NoSolidHitEffects = function(hitEntity,vPoint,vNormal,EffectPaths,SoundPaths,bDisableDefault,iPelletNumber)
  local Effects = {}
  
  local bPlayDefaultEffect = (not bDisableDefault) and (iPelletNumber % 3 == 1)
  
  local qvHitEffects = mthQuatVect(mthDirectionToQuaternion(vNormal),vPoint+0.001*vNormal)
  
  if bPlayDefaultEffect and isSP then
    worldInfo:SpawnProjectile(worldInfo:GetClosestLivingPlayer(worldInfo,10000),bulletProj,mthQuatVect(mthDirectionToQuaternion((-1)*vNormal),vPoint+0.001*vNormal),40,nil)
  end  
  
  local entityClass = hitEntity:GetClassName()
  if bPlayDefaultEffect and not isSP and RegularPuppetClasses[entityClass] and not (isCoop and (entityClass == "CPlayerPuppetEntity")) then
    local mat = EnemyToMaterial[hitEntity:GetCharacterClass()]
    if (mat == nil) then
      if worldGlobals.NSKuberIsBFE then
        mat = {"Flesh",1}
      else
        mat = {"Flesh_HD",1}
      end
    end
    if not (mat[1] == "NULL") then
      if (MaterialTemplates[mat[1]] == nil) then
        MaterialTemplates[mat[1]] = LoadResource("Content/Shared/Scripts/Templates/WeaponEngine/Material_"..mat[1]..".rsc")
      end
      Effects[#Effects+1] = MaterialTemplates[mat[1]]:SpawnEntityFromTemplate(bloodAndGoreSettings,worldInfo,qvHitEffects)
      Effects[#Effects]:SetStretch(mat[2])
      Effects[#Effects]:Start()
      Effects[#Effects+1] = MaterialTemplates[mat[1]]:SpawnEntityFromTemplateByName("Sound0"..RndL(1,2),worldInfo,qvHitEffects)
      Effects[#Effects]:PlayOnce()        
    end
  end
  if (EffectPaths ~= nil) then
    local strEffectPath = EffectPaths[RndL(1,#EffectPaths)]
    if (HitEffects[strEffectPath] == nil) then
      HitEffects[strEffectPath] = LoadResource(strEffectPath)
    end
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitEffect",worldInfo,qvHitEffects)
    Effects[#Effects]:ChangeEffect(HitEffects[strEffectPath])
    Effects[#Effects]:Start()
  end
  if (SoundPaths ~= nil) then
    local strSoundPath = SoundPaths[RndL(1,#SoundPaths)]
    if (HitEffects[strSoundPath] == nil) then
      HitEffects[strSoundPath] = LoadResource(strSoundPath)
    end
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitSound01",worldInfo,qvHitEffects)
    Effects[#Effects]:SetSound(HitEffects[strSoundPath])
    Effects[#Effects]:PlayOnce()
  end
  
  RunAsync(function()
    Wait(Delay(10))
    for i=1,#Effects,1 do
      if not IsDeleted(Effects[i]) then
        Effects[i]:Delete()
      end
    end      
  end)   
end

--Function which produces explosion effects for hitscan/ray weapons which produce explosion in hit point 
local ExplosionEffects = function(qvExplosion,EffectPaths,SoundPaths)
  local Effects = {}
  if (EffectPaths ~= nil) then
    local strEffectPath = EffectPaths[RndL(1,#EffectPaths)]
    if (HitEffects[strEffectPath] == nil) then
      HitEffects[strEffectPath] = LoadResource(strEffectPath)
    end
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitEffect",worldInfo,qvExplosion)
    Effects[#Effects]:ChangeEffect(HitEffects[strEffectPath])
    Effects[#Effects]:Start()
  end
  if (SoundPaths ~= nil) then
    local strSoundPath = SoundPaths[RndL(1,#SoundPaths)]
    if (HitEffects[strSoundPath] == nil) then
      HitEffects[strSoundPath] = LoadResource(strSoundPath)
    end
    Effects[#Effects+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletHitSound01",worldInfo,qvExplosion)
    Effects[#Effects]:SetSound(HitEffects[strSoundPath])
    Effects[#Effects]:SetRanges(10,200)
    Effects[#Effects]:PlayOnce()
  end
  
  RunAsync(function()
    Wait(Delay(10))
    for i=1,#Effects,1 do
      if not IsDeleted(Effects[i]) then
        Effects[i]:Delete()
      end
    end      
  end)   
end

--Function which displays bullet tracers as particle effects
local DisplayTracer = function(qvOrigin,TracerPaths)
  local tracer = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletTracer",worldInfo,qvOrigin)
  if (TracerPaths ~= nil) then
    local num = RndL(1,#TracerPaths)
    if (TracerEffects[TracerPaths[num]] == nil) then
      TracerEffects[TracerPaths[num]] = LoadResource(TracerPaths[num])
    end
    tracer:ChangeEffect(TracerEffects[TracerPaths[num]])
  end
  tracer:Start()
  RunAsync(function()
    Wait(Delay(10))
    if not IsDeleted(tracer) then tracer:Delete() end
  end)
end

--Function which displays a beam between qvStart and vHitPoint
--The beam consists of multiple consecutive particle effects
local DisplayBeam = function(qvStart,vHitPoint,BeamPaths)
  RunAsync(function()
   
    local vRayDir = mthNormalize(vHitPoint - qvStart:GetVect())
    qvStart:SetQuat(mthDirectionToQuaternion(vRayDir))
    
    local particleLife = BeamPaths[1]
    local maxRayLength = BeamPaths[2]
    
    local rayLen = mthMinF(mthLenV3f(vHitPoint - qvStart:GetVect()),maxRayLength)
    
    local currentIndex = 3
    local currentLength = BeamPaths[currentIndex][1]
    
    local Particles = {}
    
    while (rayLen > 0) do
      local path
      if (currentLength <= rayLen) then
        rayLen = rayLen - currentLength
        path = BeamPaths[currentIndex][2]
      else
        while (BeamPaths[currentIndex+1] ~= nil) do
          currentIndex = currentIndex + 1
          currentLength = BeamPaths[currentIndex][1]
          if (currentLength <= rayLen) then break end
        end
        rayLen = rayLen - currentLength
        path = BeamPaths[currentIndex][2]
      end
      
      if (BeamEffects[path] == nil) then
        BeamEffects[path] = LoadResource(path)
      end
      
      Particles[#Particles+1] = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("BulletTracer",worldInfo,qvStart)
      Particles[#Particles]:ChangeEffect(BeamEffects[path])      
      Particles[#Particles]:Start()
      qvStart:SetVect(qvStart:GetVect() + vRayDir*currentLength)            
      
    end
        
    Wait(Delay(particleLife))
    
    for i=1,#Particles,1 do
      if not IsDeleted(Particles[i]) then
        Particles[i]:Delete()
      end
    end        
    
  end)
end


--Function which plays a firing sound for the weapon
local PlayFiringSound = function(player,weapon,SoundsTable)
  RunAsync(function()

    local num = RndL(1,#SoundsTable)
    if (FiringSounds[SoundsTable[num][1]] == nil) then
      FiringSounds[SoundsTable[num][1]] = LoadResource(SoundsTable[num][1])
    end
    local firingSound
    local fVolume = 1
    local fPitch = 1
    local fHotspot = 10
    local fFalloff = 50
    if (SoundsTable[num][2] ~= nil) then fVolume = SoundsTable[num][2] end
    if (SoundsTable[num][3] ~= nil) then fPitch = SoundsTable[num][3] end
    if (SoundsTable[num][4] ~= nil) then fPitch = fPitch + (1 - 2 * mthRndF()) * SoundsTable[num][4] end
    --firingSound : CStaticSoundEntity
    if player:IsLocalOperator() and IsDeleted(player:GetVRHandler()) then
      firingSound = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("FiringSoundSingle",worldInfo,weapon:GetPlacement())
    else
      firingSound = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("FiringSoundSingle3D",worldInfo,weapon:GetPlacement())
      if (SoundsTable[num][5] ~= nil) then fHotspot = SoundsTable[num][5] end
      if (SoundsTable[num][6] ~= nil) then fFalloff = SoundsTable[num][6] end
      firingSound:SetRanges(fHotspot,fFalloff)
    end
    firingSound:SetSound(FiringSounds[SoundsTable[num][1]])
    firingSound:SetVolume(fVolume)
    firingSound:SetPitch(fPitch)
                
    RunHandled(function()
      Wait(Any(firingSound:PlayOnceWait(0,0),Delay(10)))
    end,
                
    OnEvery(CustomEvent("OnStep")),
    function()
      if not IsDeleted(firingSound) and not IsDeleted(weapon) then
        firingSound:SetPlacement(weapon:GetPlacement())
      end
    end)
                
    if not IsDeleted(firingSound) then
      firingSound:Delete()
    end                 
  end)
end


--WeaponRNG table contains random number generator for the weapon spread
local WeaponRNG = {}

--Function which calculates actual weapon firing source
--with firing direction, accounting for offset/random spread
local CalculateFiringSource = function(player,weapon,ParamsTable,isWeaponVR,PlayerSourcesPlacement,Timestamps)
  
  local qvCastRay
  local qvCurrentLook = player:GetLookOrigin()
  
  if (Timestamps[2] == worldInfo:SimGetStep()) then
    qvCastRay = mthCloneQuatVect(PlayerSourcesPlacement["lookOrigin"][1])
  else
    qvCastRay = mthCloneQuatVect(PlayerSourcesPlacement["lookOrigin"][2])
  end
  
  qvCastRay:SetVect(qvCurrentLook:GetVect())
              
  if (ParamsTable["source"] == "lookOrigin") then
    if (ParamsTable["direction"] == "look") and not isWeaponVR then qvCastRay:SetQuat(mthEulerToQuaternion(player:GetLookDirEul())) end            
  else
    
    local qvBarrel
    if (Timestamps[2] == worldInfo:SimGetStep()) then
      qvBarrel = mthCloneQuatVect(PlayerSourcesPlacement[ParamsTable["source"]][1])
    else
      qvBarrel = mthCloneQuatVect(PlayerSourcesPlacement[ParamsTable["source"]][2])
    end
    qvBarrel:SetVect(qvBarrel:GetVect() + (qvCurrentLook:GetVect() - qvCastRay:GetVect()))
    
    local vDiff = qvBarrel:GetVect()-qvCastRay:GetVect()
    
    if (ParamsTable["direction"] == "look") and not isWeaponVR then
                    
      local vLookDir = player:GetLookDir(false)
      local fBackMove = mthMaxF(mthDotV3f(vLookDir,vDiff),0.001)
      local hitEntity,vPoint,vNormal = CastRay(worldInfo,player,qvBarrel:GetVect() - fBackMove*vLookDir,vLookDir,fBackMove,0.1,solidCollisionType)
      if (hitEntity ~= nil) then
        qvCastRay:SetVect(vPoint)
      else
        qvCastRay:SetVect(qvBarrel:GetVect())
      end     
      qvCastRay:SetQuat(mthDirectionToQuaternion(vLookDir))
                  
    elseif not isWeaponVR then
                    
      local tempEntity,vAimedPoint,vNormal = CastRay(worldInfo,player,qvCastRay:GetVect(),mthQuaternionToDirection(qvCastRay:GetQuat()),1000,0,"camera_aim_ray")
  
      if (ParamsTable["type"] == "projectile") or (ParamsTable["type"] == "beam") then
        local hitEntity,vPoint,vNormal = CastRay(worldInfo,player,qvCastRay:GetVect(),mthNormalize(vDiff),mthLenV3f(vDiff),0,solidCollisionType)
        if (hitEntity == nil) then
          qvCastRay:SetVect(qvBarrel:GetVect())
        end
      end
                    
      if (tempEntity ~= nil) then
        qvCastRay:SetQuat(mthDirectionToQuaternion(mthNormalize(vAimedPoint - qvCastRay:GetVect())))
      else
        local vLookDir = player:GetLookDir(false)
        qvCastRay:SetQuat(mthDirectionToQuaternion(vLookDir))
      end
    
    else
      qvCastRay = qvBarrel
    end 
                
  end

  local ranPhi = WeaponRNG[weapon]:RndF()*2*Pi
  local ranR = mthSqrtF(WeaponRNG[weapon]:RndF())
  
  if (ParamsTable["offset"] == nil) then ParamsTable["offset"] = {0,0} end
  if (ParamsTable["randomSpread"] == nil) then ParamsTable["randomSpread"] = {0,0} end
  local qvOffset = QV(0,0,0,(-1)*mthATan2F(ParamsTable["offset"][1]+mthSinF(ranPhi)*ranR*ParamsTable["randomSpread"][1],100),mthATan2F(ParamsTable["offset"][2]+mthCosF(ranPhi)*ranR*ParamsTable["randomSpread"][2],100),0)
               
  return mthMulQV(qvCastRay,qvOffset)
  
end


local IsPlayerVR = {}
worldGlobals.CurrentWeaponScriptedParams = {}
worldGlobals.WeaponEngineProjectileOwner = {}
worldGlobals.WeaponEngineLastHit = {}

--Function which synchronizes (over network) the seed for the 
--RNG for the weapon so that all players have the same randomized spread
worldGlobals.CreateRPC("server","reliable","AltFireSendWeaponSeed",function(weapon,seed)
  if IsDeleted(weapon) then return end
  if not worldGlobals.netIsHost and not IsDeleted(weapon) then
    WeaponRNG[weapon]:RndSeed(tonumber(seed))
  end
end)


--The main function which handles a weapon entity
local HandleScriptedFiring = function(player,weapon,path,isRight)
  
  --Before start, Weapon Engine params for the weapon are copied into a new table
  --This is done so that other scripts can dynamically modify firing parameters
  --for the weapon without affecting the original parameters
  worldGlobals.CurrentWeaponScriptedParams[weapon] = {}
  for event,value in pairs(worldGlobals.WeaponScriptedFiringParams[path]) do
    
    if (type(value) == "table") then
    
      worldGlobals.CurrentWeaponScriptedParams[weapon][event] = {}
      
      for object,params in pairs(value) do
        
        if (type(params) == "table") then
          
          worldGlobals.CurrentWeaponScriptedParams[weapon][event][object] = {}
          
          for name,param in pairs(params) do
          
            if (type(param) == "table") then
            
              worldGlobals.CurrentWeaponScriptedParams[weapon][event][object][name] = {}
              
              for index,par in pairs(param) do
            
                  if (type(par) == "table") then
            
                  worldGlobals.CurrentWeaponScriptedParams[weapon][event][object][name][index] = {}   
                  
                  for i,p in pairs(par) do
                    worldGlobals.CurrentWeaponScriptedParams[weapon][event][object][name][index][i] = p
                  end
                else
                  worldGlobals.CurrentWeaponScriptedParams[weapon][event][object][name][index] = par
                end
              end
            else
              worldGlobals.CurrentWeaponScriptedParams[weapon][event][object][name] = param
            end
          end
        else
          worldGlobals.CurrentWeaponScriptedParams[weapon][event][object] = params
        end
      end
    else
      worldGlobals.CurrentWeaponScriptedParams[weapon][event] = value
    end
    
  end
  
  --Some preliminary setup
  --RNG : CScriptedRandomNumberGenerator
  WeaponRNG[weapon] = CreateRandomNumberGenerator(0)
  if worldGlobals.netIsHost then
    local time = GetDateTimeLocal()
    local seed = 3600*tonumber(string.sub(time,-8,-7))+60*tonumber(string.sub(time,-5,-4))+tonumber(string.sub(time,-2,-1)) + mthTruncF(mthRndF() * 1000)
    WeaponRNG[weapon]:RndSeed(seed)
    if not worldInfo:IsSinglePlayer() then
      RunAsync(function()
        Wait(Delay(0.1))
        worldGlobals.AltFireSendWeaponSeed(weapon,tostring(seed))
      end)
    end
  end
  
  local weaponParams = weapon:GetParams()
  local weaponIndex = player:GetWeaponIndex(weaponParams)
  
  local isWeaponVR = IsPlayerVR[player]
  
  local Timestamps = {worldInfo:SimGetStep(),worldInfo:SimGetStep()}
  local PlayerSourcesPlacement = {
    ["lookOrigin"] = {player:GetLookOrigin(),player:GetLookOrigin()}
  }
  local chargingTimer = 0
  local noCharging = false
  local hasReclicked = false 
  local weaponMaxCharge = 0
  local isAutoFire = false
  
  local AllBarrels = {}
  for strEvent,FireableObjectsTable in pairs(worldGlobals.CurrentWeaponScriptedParams[weapon]) do
    if (strEvent ~= "charging") then
      for i,ParamsTable in pairs(FireableObjectsTable) do
        if (i ~= "ammoSpent") and (i ~= "firingSounds") and (i ~= "fireWithoutAmmo") then
          local name = ParamsTable["source"]
          if (name ~= "lookOrigin") then
            AllBarrels[name] = true
            PlayerSourcesPlacement[name] = {weapon:GetBarrelPlacement(name),weapon:GetBarrelPlacement(name)}
          end
        end
      end
    end
  end
  
  --TRACKING CHARGING AND PLACEMENTS OF THE BARRELS
  RunAsync(function()  
    local step = 0
    
    local maxZ = 0
    local maxDiff = 0      
    
    while not IsDeleted(weapon) do
      
      if worldGlobals.netIsHost then
        if (weaponMaxCharge > 0) then
          if not player:IsWeaponBusy() and IsFirePressed[player] then  
            hasReclicked = false
            if not noCharging then
              chargingTimer = mthMinF(chargingTimer + step, weaponMaxCharge)
            end
          elseif IsFirePressed[player] and not isAutoFire and not hasReclicked then
            noCharging = true
          end
          
          if (noCharging or player:IsWeaponBusy()) and not IsFirePressed[player] then
            noCharging = false
            hasReclicked = true
          end
          
          if isWeaponVR then
            chargingTimer = weaponMaxCharge
          end
          
        end
      end
      
      Timestamps[1] = Timestamps[2]
      Timestamps[2] = worldInfo:SimGetStep()
     
      PlayerSourcesPlacement["lookOrigin"][1] = PlayerSourcesPlacement["lookOrigin"][2]
      if not isWeaponVR then
        PlayerSourcesPlacement["lookOrigin"][2] = player:GetLookOrigin()        
      else
        PlayerSourcesPlacement["lookOrigin"][2] = weapon:GetPlacement()
      end
      
      for barrel,_ in pairs(AllBarrels) do
        PlayerSourcesPlacement[barrel][1] = PlayerSourcesPlacement[barrel][2]
        PlayerSourcesPlacement[barrel][2] = weapon:GetBarrelPlacement(barrel)
        if isWeaponVR then
          PlayerSourcesPlacement[barrel][2]:SetQuat(PlayerSourcesPlacement["lookOrigin"][2]:GetQuat())
        end
      end      
      
      step = Wait(CustomEvent("OnStep")):GetTimeStep()
    end 
  end)
  
  
  for strEvent,FireableObjectsTable in pairs(worldGlobals.CurrentWeaponScriptedParams[weapon]) do
    --For each "event" in the weapon engine params of the weapon,
    --run a function which will "catch" them
    
    RunAsync(function()
    
      if (strEvent == "charging") then
        
        weaponMaxCharge = FireableObjectsTable[1]
        isAutoFire = FireableObjectsTable[2]
     
      else  
    
        for i,ParamsTable in pairs(FireableObjectsTable) do
          if (i ~= "ammoSpent") and (i ~= "firingSounds") and (i ~= "fireWithoutAmmo") then
            if (ParamsTable["projectile"] ~= nil) then
              if (worldGlobals.WeaponEngineProjectileParams[ParamsTable["projectile"]] == nil) then
                worldGlobals.WeaponEngineProjectileParams[ParamsTable["projectile"]] = LoadResource(ParamsTable["projectile"])
              end
            end
            if (ParamsTable["explosionProjectile"] ~= nil) then
              if (worldGlobals.WeaponEngineProjectileParams[ParamsTable["explosionProjectile"]] == nil) then
                worldGlobals.WeaponEngineProjectileParams[ParamsTable["explosionProjectile"]] = LoadResource(ParamsTable["explosionProjectile"])
              end
            end            
          end
        end
  
        RunHandled(
        
        function()
          while not IsDeleted(weapon) do
            Wait(CustomEvent("OnStep"))
          end
        end,
        
        OnEvery(Any(CustomEvent(weapon,strEvent),CustomEvent(path.."_"..strEvent))),
        function(pay)
          
          --Caught a firing event
          
          local index = weaponIndex
          
          if (pay.any.signaledIndex == 2) then
            if (weapon ~= pay.any.signaled:GetEventThrower()) then
              return
            end
          end
          
          if not player:IsWeaponBusy() then return end
          if (worldGlobals.CurrentWeaponScriptedParams[weapon][strEvent]["ammoSpent"] ~= nil) then
            if (player:GetAmmoForWeapon(weaponParams) < worldGlobals.CurrentWeaponScriptedParams[weapon][strEvent]["ammoSpent"]) and not worldGlobals.CurrentWeaponScriptedParams[weapon][strEvent]["fireWithoutAmmo"] then
              return
            end
          end          
                
          local PelletsPerBodyHit = {}
          local TotalImpulse = {}
          
          for i,ParamsTable in pairs(worldGlobals.CurrentWeaponScriptedParams[weapon][strEvent]) do
            
            if (i == "ammoSpent") then
              if worldGlobals.netIsHost then
                player:SetAmmoForWeapon(weaponParams,mthMaxF(0,player:GetAmmoForWeapon(weaponParams)-ParamsTable))
              end
              
            elseif (i == "firingSounds") then
              PlayFiringSound(player,weapon,ParamsTable)
              
            elseif (i ~= "fireWithoutAmmo") then
              
              --For each fireable object, perform calculations and fire it
              
              local qvCastRay = CalculateFiringSource(player,weapon,ParamsTable,isWeaponVR,PlayerSourcesPlacement,Timestamps)
              local vCastOrigin = qvCastRay:GetVect()
              local vCastDirection = mthQuaternionToDirection(qvCastRay:GetQuat())
              
              local damage
              
              if (ParamsTable["type"] == "hitscan") or (ParamsTable["type"] == "beam") then
              
                if (ParamsTable["tracerProbability"] ~= nil) and (not ParamsTable["noBulletTracersOnViewer"] or not player:IsLocalViewer()) then
                  if (mthRndF() < ParamsTable["tracerProbability"]) then
                    DisplayTracer(qvCastRay,ParamsTable["customTracerEffects"])
                  end
                end
              
                if (ParamsTable["range"] == nil) then ParamsTable["range"] = 500 end
                if (ParamsTable["bulletRadius"] == nil) then ParamsTable["bulletRadius"] = 0.1 end
                if (ParamsTable["bulletRadius"] < 0) or not isCoop then ParamsTable["bulletRadius"] = 0 end
                
                if (ParamsTable["damage"][2] == nil) then ParamsTable["damage"][2] = ParamsTable["damage"][1] end
                if (weaponMaxCharge > 0) then
                  damage = (ParamsTable["damage"][1] + (ParamsTable["damage"][2]-ParamsTable["damage"][1]) * chargingTimer / weaponMaxCharge) * player:GetDamageMultiplierForWeapon(weaponParams)
                else
                  damage = (ParamsTable["damage"][1] + RndL(0,ParamsTable["damage"][2] - ParamsTable["damage"][1])) * player:GetDamageMultiplierForWeapon(weaponParams)
                end
                
                if (worldGlobals.WeaponEngineIsPlayerPoweredUp[player] > 0) then
                  damage = damage * 4
                end
              
              end
              
              
              if (ParamsTable["type"] == "hitscan") then
              --HITSCAN WEAPON 

                if (ParamsTable["damageType"] == nil) then ParamsTable["damageType"] = "Bullet" end
                
                local fDistanceSolid,fDistanceNoSolid
                
                local hitEntitySolid, vPointSolid, vNormalSolid = CastRay(worldInfo,player,vCastOrigin,vCastDirection,ParamsTable["range"],0,solidCollisionType)
                
                while (hitEntitySolid ~= nil) do
                  if (worldGlobals.WeaponEngineProjectileOwner[hitEntitySolid] == player) then
                    fDistanceSolid = mthLenV3f(vCastOrigin - vPointSolid)
                    hitEntitySolid, vPointSolid, vNormalSolid = CastRay(worldInfo,hitEntitySolid,vPointSolid,vCastDirection,ParamsTable["range"]-fDistanceSolid,0,solidCollisionType)
                  else
                    break                  
                  end
                end
                
                local hitEntityNoSolid, vPointNoSolid, vNormalNoSolid = CastRay(worldInfo,player,vCastOrigin,vCastDirection,ParamsTable["range"],ParamsTable["bulletRadius"],nonSolidCollisionType)
                while (hitEntityNoSolid ~= nil) do
                  if (worldGlobals.WeaponEngineProjectileOwner[hitEntityNoSolid] == player) then
                    fDistanceNoSolid = mthLenV3f(vCastOrigin - vPointNoSolid)
                    hitEntityNoSolid, vPointNoSolid, vNormalNoSolid = CastRay(worldInfo,hitEntityNoSolid,vPointNoSolid,vCastDirection,ParamsTable["range"]-fDistanceNoSolid,ParamsTable["bulletRadius"],nonSolidCollisionType)
                  else
                    break
                  end
                end

                if hitEntitySolid then fDistanceSolid = mthLenV3f(vCastOrigin - vPointSolid) end
                if hitEntityNoSolid then fDistanceNoSolid = mthLenV3f(vCastOrigin - vPointNoSolid) end
                
                --hit types: 0 - nothing, 1 - non-solid (body), 2 - solid
                local hitType = 0
                if hitEntitySolid then
                  if hitEntityNoSolid then
                    if (fDistanceNoSolid <= fDistanceSolid) and isCoop then
                      hitType = 1
                    else
                      hitType = 2
                    end
                  else
                    hitType = 2
                  end
                elseif hitEntityNoSolid then
                  hitType = 1
                end
                
                --performing hit effects/damage/impulse
                if (hitType == 1) then
                  if ParamsTable["signalHitEvents"] then
                    if RegularPuppetClasses[hitEntityNoSolid:GetClassName()] then
                      SignalEvent(weapon,"WeaponEngineHitscanHit",{entity = hitEntityNoSolid, point = vPointNoSolid, normal = vNormalNoSolid, dam = damage, hp = hitEntityNoSolid:GetHealth()})
                    else
                      SignalEvent(weapon,"WeaponEngineHitscanHit",{entity = hitEntityNoSolid, point = vPointNoSolid, normal = vNormalNoSolid, dam = damage})
                    end
                  end
                  
                  worldGlobals.WeaponEngineLastHit[weapon] = {hitEntityNoSolid, vPointNoSolid, vNormalNoSolid}
                  --hitEntityNoSolid : CLeggedCharacterEntity
                  if (PelletsPerBodyHit[hitEntityNoSolid] == nil) then 
                    PelletsPerBodyHit[hitEntityNoSolid] = 1
                  else
                    PelletsPerBodyHit[hitEntityNoSolid] = PelletsPerBodyHit[hitEntityNoSolid] + 1
                  end
                  
                  NoSolidHitEffects(hitEntityNoSolid,vPointNoSolid,vNormalNoSolid,ParamsTable["bodyHitEffects"],ParamsTable["bodyHitSounds"],ParamsTable["noDefaultBodyHitEffect"],PelletsPerBodyHit[hitEntityNoSolid])
                  
                  if worldGlobals.netIsHost then
                    player:InflictDamageToTarget(hitEntityNoSolid,damage,weaponIndex,ParamsTable["damageType"])
                    if RegularPuppetClasses[hitEntityNoSolid:GetClassName()] then
                      if (ParamsTable["impulse"] ~= nil) then
                        if (TotalImpulse[hitEntityNoSolid] == nil) then
                          TotalImpulse[hitEntityNoSolid] = vCastDirection * ParamsTable["impulse"]
                        else
                          TotalImpulse[hitEntityNoSolid] = TotalImpulse[hitEntityNoSolid] + vCastDirection * ParamsTable["impulse"]
                        end
                      end
                    end
                  end                  
                  
                elseif (hitType == 2) then
                  if ParamsTable["signalHitEvents"] then
                    if RegularPuppetClasses[hitEntitySolid:GetClassName()] then
                      SignalEvent(weapon,"WeaponEngineHitscanHit",{entity = hitEntitySolid, point = vPointSolid, normal = vNormalSolid, dam = damage, hp = hitEntitySolid:GetHealth()})
                    else
                      SignalEvent(weapon,"WeaponEngineHitscanHit",{entity = hitEntitySolid, point = vPointSolid, normal = vNormalSolid, dam = damage})
                    end
                  end
                  
                  worldGlobals.WeaponEngineLastHit[weapon] = {hitEntitySolid, vPointSolid, vNormalSolid}
                
                  if worldGlobals.netIsHost then
                    player:InflictDamageToTarget(hitEntitySolid,damage,weaponIndex,ParamsTable["damageType"])
                  end
                  
                  if RegularPuppetClasses[hitEntitySolid:GetClassName()] then
                    if not isSP then
                      if (ParamsTable["impulse"] ~= nil) then
                        if (TotalImpulse[hitEntitySolid] == nil) then
                          TotalImpulse[hitEntitySolid] = vCastDirection * ParamsTable["impulse"]
                        else
                          TotalImpulse[hitEntitySolid] = TotalImpulse[hitEntitySolid] + vCastDirection * ParamsTable["impulse"]
                        end
                      end
                    end                      
                  
                    if (PelletsPerBodyHit[hitEntitySolid] == nil) then 
                      PelletsPerBodyHit[hitEntitySolid] = 1
                    else
                      PelletsPerBodyHit[hitEntitySolid] = PelletsPerBodyHit[hitEntitySolid] + 1
                    end                    
                    NoSolidHitEffects(hitEntitySolid,vPointSolid,vNormalSolid,ParamsTable["bodyHitEffects"],ParamsTable["bodyHitSounds"],ParamsTable["noDefaultBodyHitEffect"],PelletsPerBodyHit[hitEntitySolid])
                  else
                    SolidHitEffects(vPointSolid,vNormalSolid,ParamsTable["solidHitEffects"],ParamsTable["solidHitSounds"],ParamsTable["solidHitDecals"],ParamsTable["noDefaultSolidHitEffect"])
                  end
                    
                else
                
                  worldGlobals.WeaponEngineLastHit[weapon] = {hitEntitySolid, vCastOrigin + vCastDirection * ParamsTable["range"], vNormalSolid}
                
                end
                
                if (ParamsTable["explosionProjectile"] ~= nil) then
                  local qvExplosionSpawn = mthQuatVect(qvCastRay:GetQuat(),worldGlobals.WeaponEngineLastHit[weapon][2])
                  if worldGlobals.netIsHost then
                    --projExpl : CGenericProjectileEntity
                    local projExpl = worldInfo:SpawnProjectile(player,worldGlobals.WeaponEngineProjectileParams[ParamsTable["explosionProjectile"]],qvExplosionSpawn,0,nil)
                    projExpl:SetAutoDestroyTimer(0)
                  end
                  ExplosionEffects(qvExplosionSpawn,ParamsTable["explosionEffects"],ParamsTable["explosionSounds"])
                end
                
              elseif (ParamsTable["type"] == "beam") then
              --BEAM WEAPON
                
                if (ParamsTable["damageType"] == nil) then ParamsTable["damageType"] = "Piercing" end
                if (ParamsTable["piercingPower"] == nil) then ParamsTable["piercingPower"] = {1000000,1000000} end
                if (ParamsTable["piercingPower"][2] == nil) then ParamsTable["piercingPower"][2] = ParamsTable["piercingPower"][1] end
                
                local piercingPower
                if (weaponMaxCharge > 0) then
                  piercingPower = (ParamsTable["piercingPower"][1] + (ParamsTable["piercingPower"][2]-ParamsTable["piercingPower"][1]) * chargingTimer / weaponMaxCharge) * player:GetDamageMultiplierForWeapon(weaponParams)
                else
                  piercingPower = ParamsTable["piercingPower"][1] * player:GetDamageMultiplierForWeapon(weaponParams)
                end  
                if (worldGlobals.WeaponEngineIsPlayerPoweredUp[player] > 0) then
                  piercingPower = piercingPower * 4
                end                              
                
                local remainingRange = ParamsTable["range"]
                local caster = player
                
                --Same as hitscan, but on repeat until the full length of the beam is used
                --or an unpiercable solid/enemy is hit
                while (remainingRange > 0) do
                  local hitEntitySolid, vPointSolid, vNormalSolid = CastRay(worldInfo,caster,vCastOrigin,vCastDirection,remainingRange,0,solidCollisionType)
                  local hitEntityNoSolid, vPointNoSolid, vNormalNoSolid = CastRay(worldInfo,caster,vCastOrigin,vCastDirection,remainingRange,ParamsTable["bulletRadius"],nonSolidCollisionType)
                  
                  local fDistanceSolid,fDistanceNoSolid
                  
                  if hitEntitySolid then fDistanceSolid = mthLenV3f(vCastOrigin - vPointSolid) end
                  if hitEntityNoSolid then fDistanceNoSolid = mthLenV3f(vCastOrigin - vPointNoSolid) end
                  
                  local hitType = 0
                  if hitEntitySolid then
                    if hitEntityNoSolid then
                      if (fDistanceNoSolid <= fDistanceSolid) then
                        hitType = 1
                      else
                        hitType = 2
                      end
                    else
                      hitType = 2
                    end
                  elseif hitEntityNoSolid then
                    hitType = 1
                  end
                  
                  if (hitType == 1) then
                  
                    if ParamsTable["signalHitEvents"] then
                      if RegularPuppetClasses[hitEntitySolid:GetClassName()] then
                        SignalEvent(weapon,"WeaponEngineBeamHit",{entity = hitEntityNoSolid, point = vPointNoSolid, normal = vNormalNoSolid, dam = damage, hp = hitEntityNoSolid:GetHealth()})
                      else
                        SignalEvent(weapon,"WeaponEngineBeamHit",{entity = hitEntityNoSolid, point = vPointNoSolid, normal = vNormalNoSolid, dam = damage})
                      end
                    end
                      
                    --hitEntityNoSolid : CLeggedCharacterEntity
                    if not RegularPuppetClasses[hitEntityNoSolid:GetClassName()] then
                      caster = hitEntityNoSolid
                      remainingRange = remainingRange - mthLenV3f(vCastOrigin - vPointNoSolid)
                      vCastOrigin = vPointNoSolid                      
                    elseif (hitEntityNoSolid:GetMaxHealth() <= piercingPower) then
                      caster = hitEntityNoSolid
                      remainingRange = remainingRange - mthLenV3f(vCastOrigin - vPointNoSolid)
                      vCastOrigin = vPointNoSolid
                    else
                      worldGlobals.WeaponEngineLastHit[weapon] = {hitEntityNoSolid, vPointNoSolid, vNormalNoSolid}
                      remainingRange = 0                         
                    end
                    
                    if RegularPuppetClasses[hitEntityNoSolid:GetClassName()] then
                      if (ParamsTable["impulse"] ~= nil) then
                        if (TotalImpulse[hitEntityNoSolid] == nil) then
                          TotalImpulse[hitEntityNoSolid] = vCastDirection * ParamsTable["impulse"]
                        else
                          TotalImpulse[hitEntityNoSolid] = TotalImpulse[hitEntityNoSolid] + vCastDirection * ParamsTable["impulse"]
                        end
                      end 
                    end                   
                    
                    if (PelletsPerBodyHit[hitEntityNoSolid] == nil) then 
                      PelletsPerBodyHit[hitEntityNoSolid] = 1
                    else
                      PelletsPerBodyHit[hitEntityNoSolid] = PelletsPerBodyHit[hitEntityNoSolid] + 1
                    end                    
                    NoSolidHitEffects(hitEntityNoSolid,vPointNoSolid,vNormalNoSolid,ParamsTable["bodyHitEffects"],ParamsTable["bodyHitSounds"],ParamsTable["noDefaultBodyHitEffect"],PelletsPerBodyHit[hitEntityNoSolid])
                    
                    if worldGlobals.netIsHost then
                      player:InflictDamageToTarget(hitEntityNoSolid,damage,weaponIndex,ParamsTable["damageType"])
                    end                    
                    
                  elseif (hitType == 2) then
                    
                    if ParamsTable["signalHitEvents"] then
                      if RegularPuppetClasses[hitEntitySolid:GetClassName()] then
                        SignalEvent(weapon,"WeaponEngineBeamHit",{entity = hitEntitySolid, point = vPointSolid, normal = vNormalSolid, dam = damage, hp = hitEntitySolid:GetHealth()})
                      else
                        SignalEvent(weapon,"WeaponEngineBeamHit",{entity = hitEntitySolid, point = vPointSolid, normal = vNormalSolid, dam = damage})
                      end                      
                    end
                    
                    if worldGlobals.netIsHost then
                      player:InflictDamageToTarget(hitEntitySolid,damage,weaponIndex,ParamsTable["damageType"])
                    end                        
                  
                    local className = hitEntitySolid:GetClassName()
                    
                    if (className == "CStaticModelEntity") then
                      --hitEntitySolid : CStaticModelEntity
                      if hitEntitySolid:IsDestroyed() then
                        caster = hitEntitySolid
                        remainingRange = remainingRange - mthLenV3f(vCastOrigin - vPointSolid)
                        vCastOrigin = vPointSolid                     
                      else
                        worldGlobals.WeaponEngineLastHit[weapon] = {hitEntitySolid, vPointSolid, vNormalSolid}
                        remainingRange = 0                     
                      end
                      SolidHitEffects(vPointSolid,vNormalSolid,ParamsTable["solidHitEffects"],ParamsTable["solidHitSounds"],ParamsTable["solidHitDecals"],ParamsTable["noDefaultSolidHitEffect"])  
                    
                    elseif RegularPuppetClasses[className] then
                      
                      if (hitEntitySolid:GetMaxHealth() <= piercingPower) then
                        caster = hitEntitySolid
                        remainingRange = remainingRange - mthLenV3f(vCastOrigin - vPointSolid)
                        vCastOrigin = vPointSolid
                      else
                        worldGlobals.WeaponEngineLastHit[weapon] = {hitEntitySolid, vPointSolid, vNormalSolid}
                        remainingRange = 0                         
                      end
                      
                      if not isSP then
                        if (ParamsTable["impulse"] ~= nil) then
                          if (TotalImpulse[hitEntitySolid] == nil) then
                            TotalImpulse[hitEntitySolid] = vCastDirection * ParamsTable["impulse"]
                          else
                            TotalImpulse[hitEntitySolid] = TotalImpulse[hitEntitySolid] + vCastDirection * ParamsTable["impulse"]
                          end
                        end
                      end                        
                      
                      if (PelletsPerBodyHit[hitEntitySolid] == nil) then 
                        PelletsPerBodyHit[hitEntitySolid] = 1
                      else
                        PelletsPerBodyHit[hitEntitySolid] = PelletsPerBodyHit[hitEntitySolid] + 1
                      end                        
                      
                      NoSolidHitEffects(hitEntitySolid,vPointSolid,vNormalSolid,ParamsTable["bodyHitEffects"],ParamsTable["bodyHitSounds"],ParamsTable["noDefaultBodyHitEffect"],PelletsPerBodyHit[hitEntitySolid])
                    else
                      remainingRange = 0 
                      worldGlobals.WeaponEngineLastHit[weapon] = {hitEntitySolid, vPointSolid, vNormalSolid}
                      SolidHitEffects(vPointSolid,vNormalSolid,ParamsTable["solidHitEffects"],ParamsTable["solidHitSounds"],ParamsTable["solidHitDecals"],ParamsTable["noDefaultSolidHitEffect"])                  
                    end                

                  else
                    worldGlobals.WeaponEngineLastHit[weapon] = {hitEntitySolid, vCastOrigin + vCastDirection*remainingRange, vNormalSolid}
                    remainingRange = 0 
                  end
                  
                  if ParamsTable["explosionEveryHit"] and (remainingRange > 0) and (ParamsTable["explosionProjectile"] ~= nil) then
                    local qvExplosionSpawn = mthQuatVect(qvCastRay:GetQuat(),vCastOrigin)
                    if worldGlobals.netIsHost then
                      --projExpl : CGenericProjectileEntity
                      local projExpl = worldInfo:SpawnProjectile(player,worldGlobals.WeaponEngineProjectileParams[ParamsTable["explosionProjectile"]],qvExplosionSpawn,0,nil)
                      projExpl:SetAutoDestroyTimer(0)
                    end
                    ExplosionEffects(qvExplosionSpawn,ParamsTable["explosionEffects"],ParamsTable["explosionSounds"])
                  end                   
                 
                end
                
                if (ParamsTable["beamEffects"] ~= nil) then
                  DisplayBeam(qvCastRay,worldGlobals.WeaponEngineLastHit[weapon][2],ParamsTable["beamEffects"])
                end
                
                if (ParamsTable["explosionProjectile"] ~= nil) then
                  local qvExplosionSpawn = mthQuatVect(qvCastRay:GetQuat(),worldGlobals.WeaponEngineLastHit[weapon][2])
                  if worldGlobals.netIsHost then
                    --projExpl : CGenericProjectileEntity
                    local projExpl = worldInfo:SpawnProjectile(player,worldGlobals.WeaponEngineProjectileParams[ParamsTable["explosionProjectile"]],qvExplosionSpawn,0,nil)
                    projExpl:SetAutoDestroyTimer(0)
                  end
                  ExplosionEffects(qvExplosionSpawn,ParamsTable["explosionEffects"],ParamsTable["explosionSounds"])
                end                              
                
                  
              elseif worldGlobals.netIsHost then
              --PROJECTILE WEAPON
              
                if (ParamsTable["velocity"][2] == nil) then ParamsTable["velocity"][2] = ParamsTable["velocity"][1] end
                local velocity
                if (weaponMaxCharge > 0) then
                  velocity = ParamsTable["velocity"][1] + (ParamsTable["velocity"][2]-ParamsTable["velocity"][1]) * chargingTimer / weaponMaxCharge
                else
                  velocity = ParamsTable["velocity"][1] + RndL(0,ParamsTable["velocity"][2] - ParamsTable["velocity"][1])
                end
             
                worldGlobals.WeaponEngineProjectileOwner[worldInfo:SpawnProjectile(player,worldGlobals.WeaponEngineProjectileParams[ParamsTable["projectile"]],qvCastRay,velocity,nil)] = player
              end

            end
            
          end
          
          chargingTimer = 0
          
          for entity,push in pairs(TotalImpulse) do
            local vDir = mthDirectionVectorToEuler(mthNormalize(push))/Pi*180
            entity:PushAbs(vDir.x,vDir.y,mthLenV3f(push))
          end
          
        end)
      
      end
      
    end)
  end
end

--Function which handles looping firing sounds for weapons.
--These may be long sounds which loop while the weapon is firing.
local HandleFiringSound = function(player,weapon,weaponPath)
  RunAsync(function()    
  
    local place = player:GetPlacement()
    local suffix
    if player:IsLocalViewer() and IsDeleted(player:GetVRHandler()) then
      suffix = ""
    else
      suffix = "3D"
    end

    for name,Sounds in pairs(worldGlobals.WeaponScriptedFiringSoundsParams[weaponPath]) do
      
      RunAsync(function()
        
        local isFiring = 0
        
        --firingSound : CStaticSoundEntity
        
        local fLoopVolume = 1
        local fLoopPitch = 1
        local fLoopHotspot = 10
        local fLoopFalloff = 50
        if (Sounds[1][2] ~= nil) then fLoopVolume = Sounds[1][2] end
        if (Sounds[1][5] ~= nil) then fLoopHotspot = Sounds[1][5] end
        if (Sounds[1][6] ~= nil) then fLoopFalloff = Sounds[1][6] end
        
        if (Sounds[2] == nil) then
          Sounds[2] = Sounds[1]
          Sounds[3] = -1
        end        
        
        local fStartVolume = 1
        local fStartPitch = 1
        local fStartHotspot = 10
        local fStartFalloff = 50
        if (Sounds[2][2] ~= nil) then fStartVolume = Sounds[2][2] end
        if (Sounds[2][5] ~= nil) then fStartHotspot = Sounds[2][5] end
        if (Sounds[2][6] ~= nil) then fStartFalloff = Sounds[2][6] end                   
        --firingSound : CStaticSoundEntity
        
        local GenerateLoopPitch = function()
          fLoopPitch = 1
          if (Sounds[1][3] ~= nil) then fLoopPitch = Sounds[1][3] end     
          if (Sounds[1][4] ~= nil) then fLoopPitch = fLoopPitch + (1 - 2 * mthRndF()) * Sounds[1][4] end          
        end
        local GenerateStartPitch = function()
          fStartPitch = 1
          if (Sounds[2][3] ~= nil) then fStartPitch = Sounds[2][3] end     
          if (Sounds[2][4] ~= nil) then fStartPitch = fStartPitch + (1 - 2 * mthRndF()) * Sounds[2][4] end          
        end
        local PrepareSound = function(firingSound,resSound,fVolume,fPitch,fHotspot,fFalloff)
          firingSound:SetSound(resSound)
          firingSound:SetRanges(fHotspot,fFalloff)
          firingSound:SetVolume(fVolume)
          firingSound:SetPitch(fPitch)              
        end
        
        GenerateLoopPitch()
        GenerateStartPitch()

        local firingSound = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("FiringSound"..suffix,worldInfo,weapon:GetPlacement())
        local loopingSound = LoadResource(Sounds[1][1])
        local baseSound
        baseSound = LoadResource(Sounds[2][1])
        PrepareSound(firingSound,baseSound,fStartVolume,fStartPitch,fStartHotspot,fStartFalloff) 
        
        local existingTime = 0
        local firingSoundPlaying = false    
        
        RunHandled(function()
          while not IsDeleted(weapon) do 
            if IsDeleted(firingSound) then
              existingTime = 0
              firingSound = worldGlobals.WeaponEngineTemplates:SpawnEntityFromTemplateByName("FiringSound"..suffix,worldInfo,weapon:GetPlacement())
              GenerateStartPitch()
              PrepareSound(firingSound,baseSound,fStartVolume,fStartPitch,fStartHotspot,fStartFalloff)                   
              firingSoundPlaying = false
            end
            firingSound:SetPlacement(weapon:GetPlacement())
            if (isFiring > 0) and not firingSoundPlaying then  
              firingSoundPlaying = true
              GenerateStartPitch()
              PrepareSound(firingSound,baseSound,fStartVolume,fStartPitch,fStartHotspot,fStartFalloff)                          
              existingTime = 0          
              firingSound:PlayLooping()
            end
            if (isFiring == 0) and firingSoundPlaying then
              firingSoundPlaying = false
              firingSound:StopLoopingFadeOut(0.1)
            end          
            if firingSoundPlaying and (existingTime > Sounds[3]) then
              firingSound:StopLoopingFadeOut(0.1)
              GenerateLoopPitch()
              PrepareSound(firingSound,loopingSound,fLoopVolume,fLoopPitch,fLoopHotspot,fLoopFalloff)             
              firingSound:PlayLooping()
              existingTime = -100000
            end
            existingTime = existingTime + Wait(CustomEvent("OnStep")):GetTimeStep()
          end    
        end,
        
        OnEvery(CustomEvent(weapon, name)),
        function()        
          isFiring = isFiring + 1
          Wait(Delay(0.15))
          isFiring = isFiring - 1
        end)
        
        if not IsDeleted(firingSound) then
          firingSound:Delete()
        end 
      
      end)
   
    end 
  end)
end

--Functions which track the weapons the player holds
--and passes them to the corresponding functions whenever
--a scripted weapon is drawn
local HandleRightWeapon = function(player)
  RunAsync(function()
    while not IsDeleted(player) do
      local weapon = player:GetRightHandWeapon()
      if weapon then
        local path = weapon:GetParams():GetFileName()
        if (worldGlobals.WeaponScriptedFiringParams[path] ~= nil) then
          HandleScriptedFiring(player,weapon,path,false)   
        end
        if (worldGlobals.WeaponScriptedFiringSoundsParams[path] ~= nil) then
          HandleFiringSound(player,weapon,path)   
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
local HandleLeftWeapon = function(player)
  RunAsync(function()
    while not IsDeleted(player) do
      local weapon = player:GetLeftHandWeapon()
      if weapon then
        local path = weapon:GetParams():GetFileName()
        if (worldGlobals.WeaponScriptedFiringParams[path] ~= nil) then
          HandleScriptedFiring(player,weapon,path,false)       
        end
        if (worldGlobals.WeaponScriptedFiringSoundsParams[path] ~= nil) then
          HandleFiringSound(player,weapon,path)   
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

--Syncronizes fire button presses for the charging weapons functionality
worldGlobals.CreateRPC("client","reliable","WeaponEngineFirePressed",function(player,bPressed)
  if IsDeleted(player) then return end
  IsFirePressed[player] = bPressed
end)

--player : CPlayerPuppetEntity
--Handles each player
local HandlePlayer = function(player)
  
  RunAsync(function()
   
    if (worldGlobals.WeaponEngineIsPlayerPoweredUp[player] == nil) then
      worldGlobals.WeaponEngineIsPlayerPoweredUp[player] = 0
    end    
    
    HandleRightWeapon(player)
    HandleLeftWeapon(player)
    
    IsFirePressed[player] = false
    if player:IsLocalOperator() then
      while not IsDeleted(player) do
        if not IsFirePressed[player] and (player:GetCommandValue("plcmdFire") > 0) then
          worldGlobals.WeaponEngineFirePressed(player,true)
        elseif IsFirePressed[player] and (player:GetCommandValue("plcmdFire") < 1) then
          worldGlobals.WeaponEngineFirePressed(player,false)
        end
        Wait(CustomEvent("OnStep"))
      end
    end
    
  end)
end

--Functions which synchronize VR status of players
worldGlobals.CreateRPC("server","reliable","WeaponEngineSendVR",function(player)
  IsPlayerVR[player] = true
end)

worldGlobals.CreateRPC("client","reliable","WeaponEngineRequestVR",function()
  if worldGlobals.netIsHost and not isVR then
    for player,_ in pairs(IsPlayerVR) do
      worldGlobals.WeaponEngineSendVR(player)
    end
  end
end)

worldGlobals.CreateRPC("client","reliable","WeaponEngineIAmVR",function(player)
  if worldGlobals.netIsHost then
    IsPlayerVR[player] = true
    if not isSP then
      worldGlobals.WeaponEngineSendVR(player)
    end
  end
end)

--Wait until a weapon which utilizes the Weapon Engine is found on the level
--to reduce unnecessary code executing
local bHasWeaponEngineWeaponOnLevel = false
RunAsync(function()
  --item : CGenericItemParams
  while not bHasWeaponEngineWeaponOnLevel do
    Wait(Delay(0.2))
    local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
    for i=1,#Players,1 do
      if bHasWeaponEngineWeaponOnLevel then break end
      for path,_ in pairs(worldGlobals.WeaponScriptedFiringParams) do
        if Players[i]:HasWeaponInInventory(path) then
          bHasWeaponEngineWeaponOnLevel = true
          break
        end
      end
      for path,_ in pairs(worldGlobals.WeaponScriptedFiringSoundsParams) do
        if Players[i]:HasWeaponInInventory(path) then
          bHasWeaponEngineWeaponOnLevel = true
          break
        end
      end      
    end  
  end
end)

RunAsync(function()
  Wait(Delay(1))
  worldGlobals.WeaponEngineRequestVR()
end)

local PowerUpDuration = {}

--Handle powerup functionality since it may increase damage
local HandlePowerUp = function(powerUp)
  
  if not worldGlobals.netIsHost then return end
  if IsDeleted(powerUp) then return end
  if (string.find(powerUp:GetItemParams():GetFileName(),"Damage") == nil) then return end
  
  Wait(CustomEvent("OnStep"))
  local duration = 40
  
  if (PowerUpDuration[powerUp] ~= nil) then
    duration = PowerUpDuration[powerUp]
  end
  
  RunAsync(function()
    RunHandled(function()
      while not IsDeleted(powerUp) do
        Wait(CustomEvent("OnStep"))
      end
    end,
    
    OnEvery(Event(powerUp.Picked)),
    --picked : CPickedScriptEvent
    function(picked)
      local picker = picked:GetPicker()
      if (worldGlobals.WeaponEngineIsPlayerPoweredUp[picker] == nil) then
        worldGlobals.WeaponEngineIsPlayerPoweredUp[picker] = 0
      end
      worldGlobals.WeaponEngineIsPlayerPoweredUp[picker] = worldGlobals.WeaponEngineIsPlayerPoweredUp[picker] + 1
      local timer = 0
      while (timer < duration) do
        if IsDeleted(picker) then break end
        if not picker:IsAlive() then
          local PowerUpEntities = worldInfo:GetAllEntitiesOfClass("CGenericPowerUpItemEntity")
          for i=1,#PowerUpEntities,1 do
            if (worldInfo:GetDistance(picker,PowerUpEntities[i]) < 0.4) then
              PowerUpDuration[PowerUpEntities[i]] = duration - timer
              break
            end
          end
          break
        end
        timer = timer + Wait(CustomEvent("OnStep")):GetTimeStep()
      end
      
      if not IsDeleted(picker) then
        worldGlobals.WeaponEngineIsPlayerPoweredUp[picker] = worldGlobals.WeaponEngineIsPlayerPoweredUp[picker] - 1
      end
    end)
  end)
end

local IsHandled = {}

--Main function which launches all of the above
RunHandled(WaitForever,

OnEvery(Delay(0.1)),
function()
  string = prjGetCustomOccasion()
  local config = string.match(string, "{WeaponEngine=.-}")
  if not (config == nil) then
    local arg = string.sub(config,15,-2)
    if not (arg == "") then
      bloodAndGoreSettings = tonumber(arg) % 5
      if (bloodAndGoreSettings == -1) then
        bloodAndGoreSettings = 0
      end
    end
  end
end,

On(Delay(0.5)),
function()
  local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
  for i=1,#Players,1 do
    if Players[i]:IsLocalOperator() and CorIsAppVR() then
      worldGlobals.WeaponEngineIAmVR(Players[i])
    end
  end  
end,

OnEvery(Any(Times(6,CustomEvent("OnStep")), Delay(0.1))),
function()
  if bHasWeaponEngineWeaponOnLevel then
    local Players = worldInfo:GetAllPlayersInRange(worldInfo,10000)
    for i=1,#Players,1 do
      if not IsHandled[Players[i]] then
        IsHandled[Players[i]] = true
        HandlePlayer(Players[i])
      end
    end
  end
  
  local PowerUpEntities = worldInfo:GetAllEntitiesOfClass("CGenericPowerUpItemEntity")
  for i=1,#PowerUpEntities,1 do
    if not IsHandled[PowerUpEntities[i]] then
      IsHandled[PowerUpEntities[i]] = true
      HandlePowerUp(PowerUpEntities[i])
    end
  end  
end)