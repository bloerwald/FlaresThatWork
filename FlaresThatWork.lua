-- FlaresThatWork by oscarucb
local addonName, vars = ...
local L = vars.L
local addon = vars
FlaresThatWork = vars
local iconsz = 16

FlaresThatWorkSettings = FlaresThatWorkSettings or {}

local function debug(msg)
  --@debug@
  print(addonName..": "..msg)
  --@end-debug@
end

function addon:updateButtons()
  if SpellIsTargeting() then return end -- may be placing a flare
  if InCombatLockdown() then return end
  if FlaresThatWorkSettings.showFrame and
     GetNumGroupMembers() > 0 and
     (not UnitInRaid("player") or
      (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))) then
    addon.border:Show()
  else
    addon.border:Hide()
  end
  local w, h = addon.border:GetSize()
  local scale = math.min((w-8)/3, (h-8)/3)/iconsz
  for i=1,8 do
    if IsRaidMarkerActive(i) then
      addon.button[i].tex:SetColorTexture(1,1,1,1)
    else
      addon.button[i].tex:SetColorTexture(0,0,0,0)
    end
    addon.button[i]:SetScale(scale)
  end
  addon.button[0]:SetScale(scale)
end

local function makebutton(idx)
  local name = "FTW_Set"..idx
  local tooltip = _G["WORLD_MARKER"..idx]
  local icon
  if idx == 0 then 
     name = "FTW_Clear"
     tooltip = REMOVE_WORLD_MARKERS
     icon = "\124cffffffffC\124r"
  else
     icon = tooltip:match("(\124T.+\124t)")
  end
  local btn = CreateFrame("Button", name, addon.border, "SecureActionButtonTemplate")
  btn.tex = btn:CreateTexture(nil, "BACKGROUND")
  btn.tex:SetAllPoints()
  btn:SetAttribute("type*", "macro")
  btn:SetAttribute("*-type*", "stop")
  if idx == 0 then
    btn:SetAttribute("macrotext", "/clearworldmarker 0") -- ticket 3: 0 works for all locales
  else
    btn:SetAttribute("macrotext", "/clearworldmarker "..idx.."\n/worldmarker "..idx)
  end
  btn:SetScript("OnMouseDown", addon.border:GetScript("OnMouseDown"))
  btn:SetScript("OnMouseUp", addon.border:GetScript("OnMouseUp"))
  btn:RegisterForClicks("AnyDown", "AnyUp")
  btn:SetSize(iconsz, iconsz)
  btn:SetNormalFontObject(GameFontNormal)
  btn:SetText(icon)
  btn:SetScript("OnEnter", function(self) 
            GameTooltip:SetOwner(addon.border, "ANCHOR_TOPRIGHT");
            GameTooltip:SetText(tooltip);
            GameTooltip:Show()
      end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  btn:Show()
  addon.button = addon.button or {}
  addon.button[idx] = btn
  return btn
end

local function OnEvent(self, event,...)
  if event == "PLAYER_ENTERING_WORLD" then
    addon:SetupSettings()
    return
  end
  if InCombatLockdown() then return end
  addon:updateButtons()
end


function addon:SetupSettings()
  if self.settingsRegistered then
    return
  end

  local category, layout = Settings.RegisterVerticalLayoutCategory('FlaresThatWork')
  Settings.RegisterAddOnCategory(category)

  local ConfigureInitializer = function(initializer)
    initializer:AddSearchTags('FlaresThatWork')
    return initializer
  end

  local CreateSetting = function(variable, varType, default, name)
    local globalDummyVariable = '_global_dummy_FlaresThatWorkSettings_' .. variable
    local setting = Settings.RegisterAddOnSetting(category, globalDummyVariable, variable, FlaresThatWorkSettings, varType, name, default)

    setting:SetValueChangedCallback(function(event)
      addon:updateButtons()
    end)

    setting:SetCommitFlags(Settings.CommitFlag.SaveBindings);

    return setting
  end

  local AddBoolean = function(variable, default, name, tooltip)
    local setting = CreateSetting(variable, Settings.VarType.Boolean, default, name)
    local initializer = Settings.CreateCheckbox(category, setting, tooltip)
    return ConfigureInitializer(initializer)
  end

  local showFrameInitializer = AddBoolean("showFrame", Settings.Default.True, 'Show Icon Frame', 'Show Frame with world markers for clicking.')

  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(SETTINGS_KEYBINDINGS_LABEL));

  for i=1,8 do
    local action = "CLICK FTW_Set" .. i .. ":LeftButton";
    local bindingIndex = C_KeyBindings.GetBindingIndex(action);
    local initializer = CreateKeybindingEntryInitializer(bindingIndex, true);
    initializer:AddSearchTags(GetBindingName(action));
    layout:AddInitializer(ConfigureInitializer(initializer))
  end
  do
    local action = "CLICK FTW_Clear:LeftButton"
    local bindingIndex = C_KeyBindings.GetBindingIndex(action);
    local initializer = CreateKeybindingEntryInitializer(bindingIndex, true);
    initializer:AddSearchTags(GetBindingName(action));
    layout:AddInitializer(ConfigureInitializer(initializer))
  end

  addon:updateButtons()

  self.settingsRegistered = true
end

function addon:Initialize()
  local f = CreateFrame("Frame", addonName.."Border", UIParent, "BackdropTemplate")
  f:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile =  "Interface/DialogFrame/UI-DialogBox-Border",
    --bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    --edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 1, right = 1, top = 1, bottom = 1 }
  })
  f:SetBackdropColor(0,0,0,0.5)
  f:SetSize(8+3*iconsz,8+3*iconsz)
  f:SetResizeBounds(f:GetSize())
  f:SetMovable(true)
  f:SetToplevel(true)
  f:EnableMouse(true)
  --settings.winpos = settings.winpos or { x = 0, y = UIParent:GetHeight()/4 }
  f:ClearAllPoints()
  -- f:SetPoint("CENTER", UIParent, settings.winpos.x, settings.winpos.y)
  f:SetUserPlaced(true)
  f:SetResizable(true)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetPoint("BOTTOMLEFT")
  f:SetScript("OnMouseDown",function(self) 
      if IsShiftKeyDown() then 
         f:StartSizing() 
      elseif IsModifierKeyDown() then 
         f:StartMoving() 
      end 
  end)
  f:SetScript("OnMouseUp",function(self) f:StopMovingOrSizing() end)
  f:SetScript("OnEvent",OnEvent)
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("PARTY_LEADER_CHANGED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  addon.border = f

  local xins,yins = 4,4
  makebutton(1):SetPoint("TOPLEFT",xins,-yins)
  makebutton(2):SetPoint("TOP",0,-yins)
  makebutton(3):SetPoint("TOPRIGHT",-xins,-yins)
  makebutton(4):SetPoint("LEFT",xins,0)
  makebutton(5):SetPoint("CENTER",0,0)
  makebutton(6):SetPoint("RIGHT",-xins,0)
  makebutton(7):SetPoint("BOTTOMLEFT",xins,yins)
  makebutton(8):SetPoint("BOTTOM",0,yins)
  makebutton(0):SetPoint("BOTTOMRIGHT",-xins,yins)
  OnEvent(f, "GROUP_ROSTER_UPDATE")
  addon:updateButtons()
end
addon:Initialize()

local function setMarker(idx)
  debug("setMarker "..(idx or "nil"))
  idx = (idx and tonumber(idx)) or -1
  local btn = addon.button[idx]
  if btn then
    btn.tex:SetColorTexture(1,1,1,0.5)
  end
end

local function clearMarker(idx)
  debug("clearMarker "..(idx or "nil"))
  addon:updateButtons()
end

hooksecurefunc("PlaceRaidMarker", setMarker)
hooksecurefunc("ClearRaidMarker", clearMarker)


_G["BINDING_HEADER_FTW"] = WORLD_MARKER:gsub("%%.","")
_G["BINDING_NAME_CLICK FTW_Set1:LeftButton"] = WORLD_MARKER1
_G["BINDING_NAME_CLICK FTW_Set2:LeftButton"] = WORLD_MARKER2
_G["BINDING_NAME_CLICK FTW_Set3:LeftButton"] = WORLD_MARKER3
_G["BINDING_NAME_CLICK FTW_Set4:LeftButton"] = WORLD_MARKER4
_G["BINDING_NAME_CLICK FTW_Set5:LeftButton"] = WORLD_MARKER5
_G["BINDING_NAME_CLICK FTW_Set6:LeftButton"] = WORLD_MARKER6
_G["BINDING_NAME_CLICK FTW_Set7:LeftButton"] = WORLD_MARKER7
_G["BINDING_NAME_CLICK FTW_Set8:LeftButton"] = WORLD_MARKER8
_G["BINDING_NAME_CLICK FTW_Clear:LeftButton"] = REMOVE_WORLD_MARKERS

