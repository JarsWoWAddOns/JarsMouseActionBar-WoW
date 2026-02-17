-- Jar's Mouse Action Bars
-- Mirrors action bar buttons next to mouse cursor

-- Configuration
local MAX_BUTTONS = 12  -- Default number of buttons to show
local MAX_LAYOUTS = 100

-- Saved variables (per-character)
JarsMouseActionBarsDB = JarsMouseActionBarsDB or {}

-- Active layout state
local currentLayoutName = nil  -- Name of the currently loaded layout (nil = empty/no layout)
local activeProfile = {}       -- The actual layout data being used

-- Forward declarations
local trackerFrame
local configFrame
local RecreateTrackerFrame
local UpdateButtons

-- Get current spec ID (simple helper, no talent hashing)
local function GetCurrentSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local specID = GetSpecializationInfo(specIndex)
    return specID
end

-- Get current spec name for display
local function GetCurrentSpecName()
    local specIndex = GetSpecialization()
    if not specIndex then return "Unknown" end
    local _, specName = GetSpecializationInfo(specIndex)
    return specName or "Unknown"
end

-- Initialize saved variables structure
local function InitDB()
    if not JarsMouseActionBarsDB.layouts then
        JarsMouseActionBarsDB.layouts = {}
    end
    if not JarsMouseActionBarsDB.specAssociations then
        JarsMouseActionBarsDB.specAssociations = {}
    end
end

-- Create an empty layout (all slots cleared)
local function CreateEmptyLayout()
    local layout = {
        actionSlots = {},
        iconSize = 20,
        cursorOffsetX = 40,
        cursorOffsetY = -30,
        buttonsPerRow = 6,
    }
    for i = 1, MAX_BUTTONS do
        layout.actionSlots[i] = 0
    end
    return layout
end

-- Deep copy a layout table
local function CopyLayout(src)
    local copy = {
        actionSlots = {},
        iconSize = src.iconSize or 20,
        cursorOffsetX = src.cursorOffsetX or 40,
        cursorOffsetY = src.cursorOffsetY or -30,
        buttonsPerRow = src.buttonsPerRow or 6,
    }
    for i = 1, MAX_BUTTONS do
        copy.actionSlots[i] = src.actionSlots and src.actionSlots[i] or 0
    end
    return copy
end

-- Count total saved layouts
local function CountLayouts()
    local count = 0
    for _ in pairs(JarsMouseActionBarsDB.layouts) do
        count = count + 1
    end
    return count
end

-- Save current settings as a named layout and associate with current spec
local function SaveLayout(name)
    if not name or name == "" then
        print("|cff00ff00Jar's Mouse Action Bars|r: Please enter a layout name.")
        return false
    end

    -- Check limit (only for new layouts)
    if not JarsMouseActionBarsDB.layouts[name] and CountLayouts() >= MAX_LAYOUTS then
        print("|cff00ff00Jar's Mouse Action Bars|r: Cannot save. Maximum of " .. MAX_LAYOUTS .. " layouts reached.")
        return false
    end

    -- Save the layout
    JarsMouseActionBarsDB.layouts[name] = CopyLayout(activeProfile)
    currentLayoutName = name

    -- Associate with current spec
    local specID = GetCurrentSpecID()
    if specID then
        JarsMouseActionBarsDB.specAssociations[specID] = name
    end

    print("|cff00ff00Jar's Mouse Action Bars|r: Layout '" .. name .. "' saved" ..
        (specID and (" and associated with " .. GetCurrentSpecName()) or "") .. ".")
    return true
end

-- Load a named layout and associate with current spec
local function LoadLayout(name)
    if not name or not JarsMouseActionBarsDB.layouts[name] then
        print("|cff00ff00Jar's Mouse Action Bars|r: Layout '" .. (name or "nil") .. "' not found.")
        return false
    end

    -- Load the layout data into activeProfile
    activeProfile = CopyLayout(JarsMouseActionBarsDB.layouts[name])
    currentLayoutName = name

    -- Associate with current spec
    local specID = GetCurrentSpecID()
    if specID then
        JarsMouseActionBarsDB.specAssociations[specID] = name
    end

    print("|cff00ff00Jar's Mouse Action Bars|r: Layout '" .. name .. "' loaded" ..
        (specID and (" for " .. GetCurrentSpecName()) or "") .. ".")

    -- Recreate tracker frame to apply new settings
    if trackerFrame then
        RecreateTrackerFrame()
    end

    -- Update config frame if visible
    if configFrame and configFrame:IsShown() and configFrame.Reload then
        configFrame:Reload()
    end

    return true
end

-- Load layout for the current spec based on saved association, or use empty
local function LoadSpecLayout()
    local specID = GetCurrentSpecID()
    if specID then
        local layoutName = JarsMouseActionBarsDB.specAssociations[specID]
        if layoutName and JarsMouseActionBarsDB.layouts[layoutName] then
            activeProfile = CopyLayout(JarsMouseActionBarsDB.layouts[layoutName])
            currentLayoutName = layoutName
            print("|cff00ff00Jar's Mouse Action Bars|r: Loaded layout '" .. layoutName .. "' for " .. GetCurrentSpecName() .. ".")
            return
        end
    end

    -- No association found - start with empty layout
    activeProfile = CreateEmptyLayout()
    currentLayoutName = nil
    if specID then
        print("|cff00ff00Jar's Mouse Action Bars|r: No layout set for " .. GetCurrentSpecName() .. ". Use /jmab to configure.")
    end
end

-- Delete a named layout
local function DeleteLayout(name)
    if not name or not JarsMouseActionBarsDB.layouts[name] then
        return false
    end

    JarsMouseActionBarsDB.layouts[name] = nil

    -- Remove any spec associations pointing to this layout
    for specID, layoutName in pairs(JarsMouseActionBarsDB.specAssociations) do
        if layoutName == name then
            JarsMouseActionBarsDB.specAssociations[specID] = nil
        end
    end

    -- If we just deleted the active layout, clear the active name
    if currentLayoutName == name then
        currentLayoutName = nil
    end

    print("|cff00ff00Jar's Mouse Action Bars|r: Layout '" .. name .. "' deleted.")
    return true
end

-- Create tracker frame with action button mirrors
local function CreateTrackerFrame()
    local frame = CreateFrame("Frame", "JMAB_Tracker", UIParent)

    local iconSize = activeProfile.iconSize or 20
    local spacing = 2
    local buttonsPerRow = activeProfile.buttonsPerRow or 6
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
        local offsetX = activeProfile.cursorOffsetX or 5
        local offsetY = activeProfile.cursorOffsetY or 5

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
        if now - updateThrottle < 5 then
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

                -- Update cooldown
                if C_ActionBar and C_ActionBar.GetActionCooldown then
                    local cooldownInfo = C_ActionBar.GetActionCooldown(actionSlot)
                    if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
                        button.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration)
                    end
                else
                    local start, duration, enable = GetActionCooldown(actionSlot)
                    if start and duration then
                        button.cooldown:SetCooldown(start, duration)
                    end
                end
                if not button.cooldown:IsShown() then
                    button.cooldown:Show()
                end

                -- Update count
                if C_ActionBar and C_ActionBar.GetActionDisplayCount then
                    local displayCount = C_ActionBar.GetActionDisplayCount(actionSlot, 9999)
                    button.count:SetText(displayCount)
                else
                    local count = GetActionCount(actionSlot)
                    if count and count > 0 then
                        button.count:SetText(count)
                    else
                        button.count:SetText("")
                    end
                end

                -- Check usability (can be secret)
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

                -- Check range (can be secret)
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

-- Get sorted list of layout names for dropdown
local function GetSortedLayoutNames()
    local names = {}
    for name in pairs(JarsMouseActionBarsDB.layouts) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Create configuration window
local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "JMAB_ConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(520, 560)
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

    -- Current spec and layout indicator
    frame.specLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.specLabel:SetPoint("TOP", 0, -22)
    frame.specLabel:SetTextColor(0.7, 0.7, 0.7)

    local function UpdateSpecLabel()
        local specName = GetCurrentSpecName()
        local layoutText = currentLayoutName and (": " .. currentLayoutName) or ": (none)"
        frame.specLabel:SetText("Spec: " .. specName .. " | Layout" .. layoutText)
    end
    UpdateSpecLabel()
    frame:HookScript("OnShow", UpdateSpecLabel)

    -- ===== Layout Save/Load Section =====
    local layoutHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutHeader:SetPoint("TOPLEFT", 20, -40)
    layoutHeader:SetText("|cffffd700Layout Management|r")

    -- Layout name input
    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", 20, -58)
    nameLabel:SetText("Layout Name:")

    local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    nameBox:SetSize(200, 22)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(50)
    if currentLayoutName then
        nameBox:SetText(currentLayoutName)
    end
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Save button
    local layoutSaveBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    layoutSaveBtn:SetSize(70, 22)
    layoutSaveBtn:SetPoint("LEFT", nameBox, "RIGHT", 5, 0)
    layoutSaveBtn:SetText("Save")
    layoutSaveBtn:SetScript("OnClick", function()
        local name = nameBox:GetText():trim()
        if SaveLayout(name) then
            UpdateSpecLabel()
            -- Refresh dropdown if it exists
            if frame.layoutDropdown then
                frame.layoutDropdown:SetDefaultText(name)
            end
        end
    end)

    -- Load dropdown
    local loadLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    loadLabel:SetPoint("TOPLEFT", 20, -85)
    loadLabel:SetText("Load Layout:")

    local layoutDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    layoutDropdown:SetPoint("LEFT", loadLabel, "RIGHT", 5, 0)
    layoutDropdown:SetWidth(200)
    layoutDropdown:SetDefaultText(currentLayoutName or "Select a layout...")
    frame.layoutDropdown = layoutDropdown

    layoutDropdown:SetupMenu(function(_, rootDescription)
        local names = GetSortedLayoutNames()
        if #names == 0 then
            rootDescription:CreateTitle("No saved layouts")
            return
        end
        for _, name in ipairs(names) do
            rootDescription:CreateButton(name, function()
                if LoadLayout(name) then
                    nameBox:SetText(name)
                    layoutDropdown:SetDefaultText(name)
                    UpdateSpecLabel()
                    -- Reload UI to reflect new layout data
                    if frame.Reload then
                        frame:Reload()
                    end
                end
            end)
        end
    end)

    -- Delete button
    local deleteBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    deleteBtn:SetSize(70, 22)
    deleteBtn:SetPoint("LEFT", layoutDropdown, "RIGHT", 5, 0)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        local name = nameBox:GetText():trim()
        if name ~= "" and JarsMouseActionBarsDB.layouts[name] then
            DeleteLayout(name)
            nameBox:SetText("")
            layoutDropdown:SetDefaultText("Select a layout...")
            UpdateSpecLabel()
        else
            print("|cff00ff00Jar's Mouse Action Bars|r: Enter the name of a layout to delete.")
        end
    end)

    -- ===== Settings Section =====
    local settingsHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsHeader:SetPoint("TOPLEFT", 20, -115)
    settingsHeader:SetText("|cffffd700Display Settings|r")

    -- Icon Size slider
    local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 20, -135)
    sizeLabel:SetText("Icon Size: " .. (activeProfile.iconSize or 20))

    local sizeSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 20, -155)
    sizeSlider:SetMinMaxValues(20, 64)
    sizeSlider:SetValue(activeProfile.iconSize or 20)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(150)
    sizeSlider.Low:SetText("20")
    sizeSlider.High:SetText("64")
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        activeProfile.iconSize = value
        sizeLabel:SetText("Icon Size: " .. math.floor(value))
        RecreateTrackerFrame()
    end)

    -- Cursor Offset X slider
    local offsetXLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetXLabel:SetPoint("TOPLEFT", 220, -135)
    offsetXLabel:SetText("Cursor Offset X: " .. (activeProfile.cursorOffsetX or 40))

    local offsetXSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    offsetXSlider:SetPoint("TOPLEFT", 220, -155)
    offsetXSlider:SetMinMaxValues(-200, 200)
    offsetXSlider:SetValue(activeProfile.cursorOffsetX or 40)
    offsetXSlider:SetValueStep(1)
    offsetXSlider:SetObeyStepOnDrag(true)
    offsetXSlider:SetWidth(200)
    offsetXSlider.Low:SetText("-200")
    offsetXSlider.High:SetText("200")
    offsetXSlider:SetScript("OnValueChanged", function(self, value)
        activeProfile.cursorOffsetX = value
        offsetXLabel:SetText("Cursor Offset X: " .. math.floor(value))
    end)

    -- Cursor Offset Y slider
    local offsetYLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    offsetYLabel:SetPoint("TOPLEFT", 20, -200)
    offsetYLabel:SetText("Cursor Offset Y: " .. (activeProfile.cursorOffsetY or -30))

    local offsetYSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    offsetYSlider:SetPoint("TOPLEFT", 20, -220)
    offsetYSlider:SetMinMaxValues(-200, 200)
    offsetYSlider:SetValue(activeProfile.cursorOffsetY or -30)
    offsetYSlider:SetValueStep(1)
    offsetYSlider:SetObeyStepOnDrag(true)
    offsetYSlider:SetWidth(150)
    offsetYSlider.Low:SetText("-200")
    offsetYSlider.High:SetText("200")
    offsetYSlider:SetScript("OnValueChanged", function(self, value)
        activeProfile.cursorOffsetY = value
        offsetYLabel:SetText("Cursor Offset Y: " .. math.floor(value))
    end)

    -- Buttons Per Row slider
    local rowLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rowLabel:SetPoint("TOPLEFT", 220, -200)
    rowLabel:SetText("Buttons Per Row: " .. (activeProfile.buttonsPerRow or 6))

    local rowSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    rowSlider:SetPoint("TOPLEFT", 220, -220)
    rowSlider:SetMinMaxValues(3, 12)
    rowSlider:SetValue(activeProfile.buttonsPerRow or 6)
    rowSlider:SetValueStep(1)
    rowSlider:SetObeyStepOnDrag(true)
    rowSlider:SetWidth(200)
    rowSlider.Low:SetText("3")
    rowSlider.High:SetText("12")
    rowSlider:SetScript("OnValueChanged", function(self, value)
        activeProfile.buttonsPerRow = value
        rowLabel:SetText("Buttons Per Row: " .. math.floor(value))
        RecreateTrackerFrame()
    end)

    -- ===== Action Slots Section =====
    local slotsHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slotsHeader:SetPoint("TOPLEFT", 20, -265)
    slotsHeader:SetText("|cffffd700Action Bar Slots to Mirror|r")

    local slotsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotsLabel:SetPoint("TOPLEFT", 20, -285)
    slotsLabel:SetText("Enter action slot numbers (1-120):")

    local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoLabel:SetPoint("TOPLEFT", 20, -300)
    infoLabel:SetText("Bar 1: 1-12 | Bar 2: 13-24 | Bar 3: 25-36 | Bar 4: 37-48 | Bar 5: 49-60 | Bar 6: 61-72")

    -- Action slot inputs in grid
    local inputBoxes = {}
    for i = 1, MAX_BUTTONS do
        local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        box:SetSize(50, 25)

        local row = math.floor((i - 1) / 6)
        local col = (i - 1) % 6
        box:SetPoint("TOPLEFT", 20 + (col * 70), -325 - (row * 30))

        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(3)

        box.slotIndex = i

        local slotNum = activeProfile.actionSlots[i] or 0
        box:SetText(slotNum > 0 and tostring(slotNum) or "")

        box:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText()) or 0
            if value > 120 then value = 120 end
            activeProfile.actionSlots[self.slotIndex] = value
            self:ClearFocus()
            UpdateButtons(true)
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(activeProfile.actionSlots[self.slotIndex] or "")
            self:ClearFocus()
        end)

        inputBoxes[i] = box
    end

    -- Bottom buttons
    local applyBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    applyBtn:SetSize(120, 25)
    applyBtn:SetPoint("BOTTOMLEFT", 20, 20)
    applyBtn:SetText("Apply Changes")
    applyBtn:SetScript("OnClick", function()
        for i = 1, MAX_BUTTONS do
            local value = tonumber(inputBoxes[i]:GetText()) or 0
            if value > 120 then value = 120 end
            activeProfile.actionSlots[i] = value
        end
        UpdateButtons(true)
        print("|cff00ff00Jar's Mouse Action Bars|r: Changes applied. Save a layout to persist them.")
    end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    clearBtn:SetSize(100, 25)
    clearBtn:SetPoint("LEFT", applyBtn, "RIGHT", 10, 0)
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
        print("|cff00ff00Jar's Mouse Action Bars|r: Default slots loaded. Save a layout to persist.")
    end)

    -- Reload method to refresh UI with current profile data
    frame.Reload = function()
        -- Update action slot inputs
        for i = 1, MAX_BUTTONS do
            local slotNum = activeProfile.actionSlots[i] or 0
            inputBoxes[i]:SetText(slotNum > 0 and tostring(slotNum) or "")
        end

        -- Update sliders
        sizeSlider:SetValue(activeProfile.iconSize or 20)
        sizeLabel:SetText("Icon Size: " .. (activeProfile.iconSize or 20))

        offsetXSlider:SetValue(activeProfile.cursorOffsetX or 40)
        offsetXLabel:SetText("Cursor Offset X: " .. (activeProfile.cursorOffsetX or 40))

        offsetYSlider:SetValue(activeProfile.cursorOffsetY or -30)
        offsetYLabel:SetText("Cursor Offset Y: " .. (activeProfile.cursorOffsetY or -30))

        rowSlider:SetValue(activeProfile.buttonsPerRow or 6)
        rowLabel:SetText("Buttons Per Row: " .. (activeProfile.buttonsPerRow or 6))

        -- Update layout name and labels
        nameBox:SetText(currentLayoutName or "")
        layoutDropdown:SetDefaultText(currentLayoutName or "Select a layout...")
        UpdateSpecLabel()
    end

    return frame
end

-- Event handler
local lastSpecID = nil
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

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "JarsMouseActionBars" then
            InitDB()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Load the layout associated with current spec (or empty)
        LoadSpecLayout()
        lastSpecID = GetCurrentSpecID()

        print("|cff00ff00Jar's Mouse Action Bars|r loaded. Type /jmab for options.")

        -- Create frames
        trackerFrame = CreateTrackerFrame()
        configFrame = CreateConfigFrame()

        -- Initial update
        C_Timer.After(1, UpdateButtons)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Only react if spec actually changed
        local newSpecID = GetCurrentSpecID()
        if newSpecID and newSpecID ~= lastSpecID then
            lastSpecID = newSpecID
            LoadSpecLayout()

            -- Recreate tracker frame for new layout
            if trackerFrame then
                RecreateTrackerFrame()
            end

            -- Update config frame if visible
            if configFrame and configFrame:IsShown() and configFrame.Reload then
                configFrame:Reload()
            end
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
        UpdateButtons(true)
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
    elseif msg == "debug" then
        local specID = GetCurrentSpecID()
        print("|cff00ff00Jar's Mouse Action Bars|r Debug:")
        print("  Current Spec: " .. GetCurrentSpecName() .. " (ID: " .. tostring(specID) .. ")")
        print("  Current Layout: " .. (currentLayoutName or "(none)"))
        print("  Saved Layouts (" .. CountLayouts() .. "/" .. MAX_LAYOUTS .. "):")
        for _, name in ipairs(GetSortedLayoutNames()) do
            print("    - " .. name)
        end
        print("  Spec Associations:")
        for sid, layoutName in pairs(JarsMouseActionBarsDB.specAssociations) do
            print("    - Spec " .. sid .. " -> " .. layoutName)
        end
    else
        print("|cff00ff00Jar's Mouse Action Bars|r Commands:")
        print("  /jmab - Open configuration window")
        print("  /jmab config - Open configuration window")
        print("  /jmab scan - Scan all slots to find your actions")
        print("  /jmab debug - Show layout and spec association info")
    end
end
