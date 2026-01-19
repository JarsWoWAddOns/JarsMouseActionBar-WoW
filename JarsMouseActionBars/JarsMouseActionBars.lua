-- Jar's Mouse Action Bars
-- Mirrors action bar buttons next to mouse cursor

-- Configuration
local MAX_BUTTONS = 12  -- Default number of buttons to show

-- Saved variables (per-character)
JarsMouseActionBarsDB = JarsMouseActionBarsDB or {}

-- Profile management
local currentProfile = "default"
local activeProfile = {}

-- Get current spec and talent loadout for profile naming
local function GetCurrentProfileKey()
    local specIndex = GetSpecialization()
    if not specIndex then return "default" end
    
    local specID = GetSpecializationInfo(specIndex)
    if not specID then return "default" end
    
    -- Try to get active talent loadout if API exists
    local talentLoadoutID = "base"
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local configID = C_ClassTalents.GetActiveConfigID()
        if configID then
            talentLoadoutID = tostring(configID)
        end
    end
    
    -- Format: spec123_talent456
    return "spec" .. specID .. "_talent" .. talentLoadoutID
end

-- Get or create profile data
local function GetProfile(profileKey)
    profileKey = profileKey or currentProfile
    
    if not JarsMouseActionBarsDB.profiles then
        JarsMouseActionBarsDB.profiles = {}
    end
    
    if not JarsMouseActionBarsDB.profiles[profileKey] then
        JarsMouseActionBarsDB.profiles[profileKey] = {
            actionSlots = {
                1, 2, 3, 4, 5, 6,  -- Default: First 6 slots of action bar 1
                61, 62, 63, 64, 65, 66  -- Default: First 6 slots of action bar 6
            }
        }
    end
    
    return JarsMouseActionBarsDB.profiles[profileKey]
end

-- Initialize global settings (shared across all profiles)
local function InitializeGlobalSettings()
    if not JarsMouseActionBarsDB.global then
        JarsMouseActionBarsDB.global = {
            iconSize = 36,
            cursorOffsetX = 5,
            cursorOffsetY = 5,
            buttonsPerRow = 6,
        }
    end
end

-- Switch to a different profile
local function LoadProfile(profileKey)
    currentProfile = profileKey or GetCurrentProfileKey()
    activeProfile = GetProfile(currentProfile)
    
    -- Update tracker if it exists
    if trackerFrame then
        UpdateButtons()
    end
    
    -- Update config frame if it exists and is visible
    if configFrame and configFrame:IsShown() then
        -- Update profile label
        if configFrame.profileLabel then
            local specIndex = GetSpecialization()
            if specIndex then
                local _, specName = GetSpecializationInfo(specIndex)
                local talentText = ""
                if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
                    local configID = C_ClassTalents.GetActiveConfigID()
                    if configID then
                        talentText = " (Loadout " .. configID .. ")"
                    end
                end
                configFrame.profileLabel:SetText("Profile: " .. (specName or "Unknown") .. talentText)
            else
                configFrame.profileLabel:SetText("Profile: Default")
            end
        end
        
        -- Reload the config UI to show new profile data
        if configFrame.Reload then
            configFrame:Reload()
        end
    end
end

-- Forward declarations
local trackerFrame
local configFrame
local RecreateTrackerFrame  -- Forward declaration
local UpdateButtons  -- Forward declaration

-- Create tracker frame with action button mirrors
local function CreateTrackerFrame()
    local frame = CreateFrame("Frame", "JMAB_Tracker", UIParent)
    
    local iconSize = JarsMouseActionBarsDB.global.iconSize or 36
    local spacing = 2
    local buttonsPerRow = JarsMouseActionBarsDB.global.buttonsPerRow or 6
    local rows = math.ceil(MAX_BUTTONS / buttonsPerRow)
    
    local frameWidth = iconSize * buttonsPerRow + spacing * (buttonsPerRow - 1)
    local frameHeight = iconSize * rows + spacing * (rows - 1)
    frame:SetSize(frameWidth, frameHeight)
    frame:SetFrameStrata("HIGH")
    
    frame.buttons = {}
    
    for i = 1, MAX_BUTTONS do
        -- Create simple button frame
        local button = CreateFrame("Frame", "JMAB_Button" .. i, frame)
        button:SetSize(iconSize, iconSize)
        
        local row = math.floor((i - 1) / buttonsPerRow)
        local col = (i - 1) % buttonsPerRow
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", col * (iconSize + spacing), -row * (iconSize + spacing))
        
        -- Background
        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        button.bg:SetColorTexture(0, 0, 0, 0.5)
        
        -- Border (for active ability highlighting)
        button.border = button:CreateTexture(nil, "OVERLAY")
        button.border:SetAllPoints()
        button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        button.border:SetBlendMode("ADD")
        button.border:Hide()
        
        -- Icon texture
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        
        -- Cooldown frame
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints()
        button.cooldown:SetDrawEdge(false)
        
        -- Count text
        button.count = button:CreateFontString(nil, "OVERLAY")
        -- Use NumberFontNormal at its natural size, positioned like regular action bars
        local fontName, fontSize, fontFlags = NumberFontNormal:GetFont()
        button.count:SetFont(fontName, fontSize, fontFlags)
        button.count:SetJustifyH("RIGHT")
        button.count:SetJustifyV("BOTTOM")
        button.count:SetPoint("BOTTOMRIGHT", -2, 2)
        
        -- Overlay glow (for spell activation procs)
        button.overlay = CreateFrame("Frame", "JMAB_Button" .. i .. "Overlay", button)
        button.overlay:SetAllPoints(button)
        
        -- Create glow texture
        button.overlay.spark = button.overlay:CreateTexture(nil, "OVERLAY")
        button.overlay.spark:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
        button.overlay.spark:SetBlendMode("ADD")
        button.overlay.spark:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
        button.overlay.spark:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.overlay.spark:SetSize(iconSize * 1.4, iconSize * 1.4)
        
        button.overlay:Hide()
        
        button:Hide()
        frame.buttons[i] = button
    end
    
    -- Frame follows cursor (throttled to reduce flickering)
    frame._lastX = 0
    frame._lastY = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local offsetX = JarsMouseActionBarsDB.global.cursorOffsetX or 5
        local offsetY = JarsMouseActionBarsDB.global.cursorOffsetY or 5
        
        local newX = (x / scale) + offsetX
        local newY = (y / scale) + offsetY
        
        -- Only update position if cursor moved at least 1 pixel
        if math.abs(newX - self._lastX) > 1 or math.abs(newY - self._lastY) > 1 then
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newX, newY)
            self._lastX = newX
            self._lastY = newY
        end
    end)
    
    return frame
end

-- Recreate tracker frame with new settings
function RecreateTrackerFrame()
    if trackerFrame then
        trackerFrame:Hide()
        trackerFrame:SetParent(nil)
        trackerFrame = nil
    end
    
    trackerFrame = CreateTrackerFrame()
    UpdateButtons()
end

-- Update buttons to mirror action bar slots
local updateThrottle = 0
function UpdateButtons(forceUpdate)
    if not trackerFrame then return end
    
    -- Only throttle timer-based updates, not event-driven ones
    if not forceUpdate then
        local now = GetTime()
        if now - updateThrottle < 5 then  -- 5 seconds - only flickers once every 5 seconds
            return
        end
        updateThrottle = now
    end
    
    for i = 1, MAX_BUTTONS do
        local button = trackerFrame.buttons[i]
        local actionSlot = activeProfile.actionSlots[i]
        
        if actionSlot and actionSlot > 0 then
            local hasAction = HasAction(actionSlot)
            
            if hasAction then
                -- Get action info
                local texture = GetActionTexture(actionSlot)
                local actionType, id = GetActionInfo(actionSlot)
                
                -- Only update icon texture if it changed
                if texture and button._lastTexture ~= texture then
                    button.icon:SetTexture(texture)
                    button._lastTexture = texture
                end
                
                -- Update cooldown - native frame handles secrets, no caching needed
                if C_ActionBar and C_ActionBar.GetActionCooldown then
                    -- WoW 12.0+ API - returns table with possibly secret values
                    local cooldownInfo = C_ActionBar.GetActionCooldown(actionSlot)
                    if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
                        -- Just pass values directly, cooldown frame handles secrets
                        button.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
                    end
                else
                    -- Fallback for older WoW versions
                    local start, duration, enable = GetActionCooldown(actionSlot)
                    if start and duration then
                        button.cooldown:SetCooldown(start, duration)
                    end
                end
                if not button.cooldown:IsShown() then
                    button.cooldown:Show()
                end
                
                -- Update count - just set directly like Bartender4, no caching
                if C_ActionBar and C_ActionBar.GetActionDisplayCount then
                    -- WoW 12.0+ API - directly set whatever it returns (secret-safe)
                    local displayCount = C_ActionBar.GetActionDisplayCount(actionSlot, 9999)
                    button.count:SetText(displayCount)
                else
                    -- Fallback for older WoW versions
                    local count = GetActionCount(actionSlot)
                    if count and count > 0 then
                        button.count:SetText(count)
                    else
                        button.count:SetText("")
                    end
                end
                
                -- Check usability (can also be secret)
                pcall(function()
                    local isUsable, notEnoughMana = IsUsableAction(actionSlot)
                    local colorKey = isUsable and "usable" or (notEnoughMana and "mana" or "unusable")
                    if button._lastColorKey ~= colorKey then
                        if isUsable then
                            button.icon:SetVertexColor(1, 1, 1)
                        elseif notEnoughMana then
                            button.icon:SetVertexColor(0.5, 0.5, 1)
                        else
                            button.icon:SetVertexColor(0.4, 0.4, 0.4)
                        end
                        button._lastColorKey = colorKey
                    end
                end)
                
                -- Check range (can also be secret)
                pcall(function()
                    local inRange = IsActionInRange(actionSlot)
                    if inRange == false and button._lastColorKey ~= "range" then
                        button.icon:SetVertexColor(1, 0, 0)
                        button._lastColorKey = "range"
                    end
                end)
                
                -- Check if ability is currently active (green border)
                local isActive = IsCurrentAction(actionSlot)
                if isActive and not button.border:IsShown() then
                    button.border:Show()
                elseif not isActive and button.border:IsShown() then
                    button.border:Hide()
                end
                
                if not button:IsShown() then
                    button:Show()
                end
            else
                if button:IsShown() then
                    button:Hide()
                end
            end
        else
            if button:IsShown() then
                button:Hide()
            end
        end
    end
end

-- Create configuration window
local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "JMAB_ConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(520, 480)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Jar's Mouse Action Bars Configuration")
    
    -- Profile indicator
    frame.profileLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.profileLabel:SetPoint("TOP", 0, -22)
    frame.profileLabel:SetTextColor(0.7, 0.7, 0.7)
    
    -- Update profile label text
    local function UpdateProfileLabel()
        local specIndex = GetSpecialization()
        if specIndex then
            local _, specName = GetSpecializationInfo(specIndex)
            local talentText = ""
            if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
                local configID = C_ClassTalents.GetActiveConfigID()
                if configID then
                    talentText = " (Loadout " .. configID .. ")"
                end
            end
            frame.profileLabel:SetText("Profile: " .. (specName or "Unknown") .. talentText)
        else
            frame.profileLabel:SetText("Profile: Default")
        end
    end
    UpdateProfileLabel()
    
    -- Update profile label when frame is shown
    frame:HookScript("OnShow", UpdateProfileLabel)
    
    -- Icon Size slider
    local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 20, -35)
    sizeLabel:SetText("Icon Size: " .. (JarsMouseActionBarsDB.global.iconSize or 36))
    
    local sizeSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 20, -55)
    sizeSlider:SetMinMaxValues(20, 64)
    sizeSlider:SetValue(JarsMouseActionBarsDB.global.iconSize or 36)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(150)
    sizeSlider.Low:SetText("20")
    sizeSlider.High:SetText("64")
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseActionBarsDB.global.iconSize = value
        sizeLabel:SetText("Icon Size: " .. math.floor(value))
        RecreateTrackerFrame()
    end)
    
    -- Cursor Offset X slider
    local offsetXLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetXLabel:SetPoint("TOPLEFT", 220, -35)
    offsetXLabel:SetText("Cursor Offset X: " .. (JarsMouseActionBarsDB.global.cursorOffsetX or 5))
    
    local offsetXSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    offsetXSlider:SetPoint("TOPLEFT", 220, -55)
    offsetXSlider:SetMinMaxValues(-200, 200)
    offsetXSlider:SetValue(JarsMouseActionBarsDB.global.cursorOffsetX or 5)
    offsetXSlider:SetValueStep(1)
    offsetXSlider:SetObeyStepOnDrag(true)
    offsetXSlider:SetWidth(200)
    offsetXSlider.Low:SetText("-200")
    offsetXSlider.High:SetText("200")
    offsetXSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseActionBarsDB.global.cursorOffsetX = value
        offsetXLabel:SetText("Cursor Offset X: " .. math.floor(value))
    end)
    
    -- Cursor Offset Y slider
    local offsetYLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetYLabel:SetPoint("TOPLEFT", 20, -100)
    offsetYLabel:SetText("Cursor Offset Y: " .. (JarsMouseActionBarsDB.global.cursorOffsetY or 5))
    
    local offsetYSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    offsetYSlider:SetPoint("TOPLEFT", 20, -120)
    offsetYSlider:SetMinMaxValues(-200, 200)
    offsetYSlider:SetValue(JarsMouseActionBarsDB.global.cursorOffsetY or 5)
    offsetYSlider:SetValueStep(1)
    offsetYSlider:SetObeyStepOnDrag(true)
    offsetYSlider:SetWidth(150)
    offsetYSlider.Low:SetText("-200")
    offsetYSlider.High:SetText("200")
    offsetYSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseActionBarsDB.global.cursorOffsetY = value
        offsetYLabel:SetText("Cursor Offset Y: " .. math.floor(value))
    end)
    
    -- Buttons Per Row slider
    local rowLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowLabel:SetPoint("TOPLEFT", 220, -100)
    rowLabel:SetText("Buttons Per Row: " .. (JarsMouseActionBarsDB.global.buttonsPerRow or 6))
    
    local rowSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    rowSlider:SetPoint("TOPLEFT", 220, -120)
    rowSlider:SetMinMaxValues(3, 12)
    rowSlider:SetValue(JarsMouseActionBarsDB.global.buttonsPerRow or 6)
    rowSlider:SetValueStep(1)
    rowSlider:SetObeyStepOnDrag(true)
    rowSlider:SetWidth(200)
    rowSlider.Low:SetText("3")
    rowSlider.High:SetText("12")
    rowSlider:SetScript("OnValueChanged", function(self, value)
        JarsMouseActionBarsDB.global.buttonsPerRow = value
        rowLabel:SetText("Buttons Per Row: " .. math.floor(value))
        RecreateTrackerFrame()
    end)
    
    -- Action Button Slots Section
    local slotsHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotsHeader:SetPoint("TOPLEFT", 20, -165)
    slotsHeader:SetText("|cffffd700Action Bar Slots to Mirror|r")
    
    local slotsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotsLabel:SetPoint("TOPLEFT", 20, -185)
    slotsLabel:SetText("Enter action slot numbers (1-120):")
    
    local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", 20, -200)
    infoLabel:SetText("Bar 1: 1-12 | Bar 2: 13-24 | Bar 3: 25-36 | Bar 4: 37-48 | Bar 5: 49-60 | Bar 6: 61-72")
    
    -- Action slot inputs in grid
    local inputBoxes = {}
    for i = 1, MAX_BUTTONS do
        local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        box:SetSize(50, 25)
        
        local row = math.floor((i - 1) / 6)
        local col = (i - 1) % 6
        box:SetPoint("TOPLEFT", 20 + (col * 70), -225 - (row * 30))
        
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(3)
        
        local slotNum = activeProfile.actionSlots[i] or 0
        box:SetText(slotNum > 0 and tostring(slotNum) or "")
        
        box:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText()) or 0
            if value > 120 then value = 120 end
            activeProfile.actionSlots[i] = value
            self:ClearFocus()
            UpdateButtons()
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(activeProfile.actionSlots[i] or "")
            self:ClearFocus()
        end)
        
        inputBoxes[i] = box
    end
    
    -- Save button
    local saveBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    saveBtn:SetSize(120, 25)
    saveBtn:SetPoint("BOTTOMLEFT", 20, 20)
    saveBtn:SetText("Save & Update")
    saveBtn:SetScript("OnClick", function()
        for i = 1, MAX_BUTTONS do
            local value = tonumber(inputBoxes[i]:GetText()) or 0
            if value > 120 then value = 120 end
            activeProfile.actionSlots[i] = value
        end
        UpdateButtons()
        print("|cff00ff00Jar's Mouse Action Bars|r Configuration saved")
    end)
    
    -- Clear button
    local clearBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    clearBtn:SetSize(100, 25)
    clearBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        for i = 1, MAX_BUTTONS do
            inputBoxes[i]:SetText("")
            activeProfile.actionSlots[i] = 0
        end
        UpdateButtons()
    end)
    
    -- Default button
    local defaultBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    defaultBtn:SetSize(100, 25)
    defaultBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    defaultBtn:SetText("Load Default")
    defaultBtn:SetScript("OnClick", function()
        local defaults = {1, 2, 3, 4, 5, 6, 13, 14, 15, 16, 17, 18}
        for i = 1, MAX_BUTTONS do
            inputBoxes[i]:SetText(tostring(defaults[i]))
            activeProfile.actionSlots[i] = defaults[i]
        end
        UpdateButtons()
        print("|cff00ff00Jar's Mouse Action Bars|r Loaded default slots")
    end)
    
    -- Add Reload method to refresh UI with current profile data
    frame.Reload = function()
        for i = 1, MAX_BUTTONS do
            local slotNum = activeProfile.actionSlots[i] or 0
            inputBoxes[i]:SetText(slotNum > 0 and tostring(slotNum) or "")
        end
    end
    
    return frame
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
eventFrame:RegisterEvent("CONFIG_COMMIT_FAILED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "JarsMouseActionBars" then
            -- Profile system doesn't need InitDB anymore
        end
    elseif event == "PLAYER_LOGIN" then
        -- Initialize saved variables
        InitializeGlobalSettings()
        LoadProfile()
        
        print("|cff00ff00Jar's Mouse Action Bars|r loaded. Type /jmab for options.")
        
        -- Create frames
        trackerFrame = CreateTrackerFrame()
        configFrame = CreateConfigFrame()
        
        -- Initial update
        C_Timer.After(1, UpdateButtons)
    
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "TRAIT_CONFIG_LIST_UPDATED" or event == "CONFIG_COMMIT_FAILED" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        -- Load the appropriate profile for the new spec/talent configuration
        local newProfileKey = GetCurrentProfileKey()
        if newProfileKey ~= currentProfile then
            print(string.format("|cff00ff00Jar's Mouse Action Bars|r Switching profile: %s -> %s (Event: %s)", currentProfile or "none", newProfileKey, event))
            LoadProfile(newProfileKey)
        end
        
    elseif event == "ACTIONBAR_SLOT_CHANGED" or 
           event == "SPELL_UPDATE_COOLDOWN" or
           event == "SPELL_UPDATE_CHARGES" or
           event == "ACTIONBAR_UPDATE_STATE" or
           event == "ACTIONBAR_UPDATE_USABLE" or
           event == "SPELL_UPDATE_USABLE" or
           event == "PLAYER_TARGET_CHANGED" or
           event == "UNIT_AURA" or
           event == "PLAYER_ENTER_COMBAT" or
           event == "PLAYER_LEAVE_COMBAT" or
           event == "ACTIONBAR_UPDATE_COOLDOWN" then
        UpdateButtons(true)  -- Force update, skip throttle
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellID = ...
        if trackerFrame and spellID then
            for i = 1, MAX_BUTTONS do
                local button = trackerFrame.buttons[i]
                local actionSlot = activeProfile.actionSlots[i]
                if actionSlot and HasAction(actionSlot) then
                    local actionType, id = GetActionInfo(actionSlot)
                    if actionType == "spell" and id == spellID then
                        if button.overlay then
                            button.overlay:Show()
                        end
                    end
                end
            end
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellID = ...
        if trackerFrame and spellID then
            for i = 1, MAX_BUTTONS do
                local button = trackerFrame.buttons[i]
                local actionSlot = activeProfile.actionSlots[i]
                if actionSlot and HasAction(actionSlot) then
                    local actionType, id = GetActionInfo(actionSlot)
                    if actionType == "spell" and id == spellID then
                        if button.overlay then
                            button.overlay:Hide()
                        end
                    end
                end
            end
        end
    end
end)

-- Update loop for continuous updates
local updateTimer = 0
local UPDATE_INTERVAL = 0.1

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer >= UPDATE_INTERVAL then
        updateTimer = 0
        if trackerFrame then
            UpdateButtons()
        end
    end
end)

-- Slash commands
SLASH_JARSMOUSEACTIONBARS1 = "/jmab"
SLASH_JARSMOUSEACTIONBARS2 = "/jarsmouseactionbars"
SlashCmdList["JARSMOUSEACTIONBARS"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "config" or msg == "" then
        if configFrame then
            configFrame:SetShown(not configFrame:IsShown())
        end
    elseif msg == "scan" then
        -- Scan all slots 1-120 to find which have actions
        print("|cff00ff00Scanning all action slots...|r")
        for i = 1, 120 do
            if HasAction(i) then
                local texture = GetActionTexture(i)
                local actionType, actionID = GetActionInfo(i)
                local name = actionType == "spell" and C_Spell.GetSpellName(actionID) or "Unknown"
                print(string.format("Slot %d: %s (%s)", i, name or "?", actionType or "?"))
            end
        end
        print("|cff00ff00Scan complete!|r")
    elseif msg == "profile" or msg == "debug" then
        local profileKey = GetCurrentProfileKey()
        local specIndex = GetSpecialization()
        local specID, specName = GetSpecializationInfo(specIndex or 0)
        local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or "nil"
        
        print("|cff00ff00Jar's Mouse Action Bars|r Profile Debug:")
        print("  Current Profile Key: " .. (currentProfile or "none"))
        print("  Calculated Profile Key: " .. profileKey)
        print("  Spec Index: " .. (specIndex or "nil"))
        print("  Spec ID: " .. (specID or "nil"))
        print("  Spec Name: " .. (specName or "nil"))
        print("  Talent Config ID: " .. tostring(configID))
        if JarsMouseActionBarsDB.profiles then
            print("  Available Profiles:")
            for key, _ in pairs(JarsMouseActionBarsDB.profiles) do
                print("    - " .. key .. (key == currentProfile and " (active)" or ""))
            end
        end
    else
        print("|cff00ff00Jar's Mouse Action Bars|r Commands:")
        print("  /jmab - Open configuration window")
        print("  /jmab config - Open configuration window")
        print("  /jmab scan - Scan all slots to find your actions")
        print("  /jmab profile - Show current profile information")
    end
end
