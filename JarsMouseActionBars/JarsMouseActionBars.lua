-- Jar's Mouse Action Bars
-- Mirrors action bar buttons next to mouse cursor

-- Configuration
local MAX_BUTTONS = 12  -- Default number of buttons to show
local MAX_LAYOUTS = 100

-- Saved variables (per-character)
JarsMouseActionBarsDB = JarsMouseActionBarsDB or {}

-- Modern dark UI color palette
local UI = {
    bg        = { 0.10, 0.10, 0.12, 0.95 },
    header    = { 0.13, 0.13, 0.16, 1 },
    accent    = { 0.30, 0.75, 0.75, 1 },
    accentDim = { 0.20, 0.50, 0.50, 1 },
    text      = { 0.90, 0.90, 0.90, 1 },
    textDim   = { 0.55, 0.55, 0.58, 1 },
    border    = { 0.22, 0.22, 0.26, 1 },
    sliderBg  = { 0.18, 0.18, 0.22, 1 },
    sliderFill= { 0.30, 0.75, 0.75, 0.6 },
    btnNormal = { 0.18, 0.18, 0.22, 1 },
    btnHover  = { 0.24, 0.24, 0.28, 1 },
    btnPress  = { 0.14, 0.14, 0.17, 1 },
    checkOn   = { 0.30, 0.75, 0.75, 1 },
    checkOff  = { 0.22, 0.22, 0.26, 1 },
}

local modernBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

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
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(128)

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

-- Helper: Modern slider
local function CreateModernSlider(parent, name, labelText, minVal, maxVal, curVal, step, width, formatFunc, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 40)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(unpack(UI.text))
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)

    local valueText = container:CreateFontString(nil, "OVERLAY")
    valueText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    valueText:SetTextColor(unpack(UI.accent))
    valueText:SetPoint("TOPRIGHT", 0, 0)
    valueText:SetText(formatFunc(curVal))

    local slider = CreateFrame("Slider", name, container, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetSize(width, 14)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(curVal)

    -- Track background
    local trackBg = slider:CreateTexture(nil, "BACKGROUND")
    trackBg:SetPoint("LEFT", 0, 0)
    trackBg:SetPoint("RIGHT", 0, 0)
    trackBg:SetHeight(4)
    trackBg:SetColorTexture(unpack(UI.sliderBg))

    -- Fill texture
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", trackBg, "LEFT", 0, 0)
    fill:SetHeight(4)
    fill:SetColorTexture(unpack(UI.sliderFill))

    -- Thumb
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(14, 14)
        thumb:SetColorTexture(unpack(UI.accent))
    end

    local function UpdateFill()
        local min, max = slider:GetMinMaxValues()
        local val = slider:GetValue()
        local pct = (val - min) / (max - min)
        fill:SetWidth(math.max(1, pct * width))
    end
    UpdateFill()

    slider:SetScript("OnValueChanged", function(self, value)
        valueText:SetText(formatFunc(value))
        UpdateFill()
        onChange(value)
    end)

    container.slider = slider
    container.valueText = valueText
    container.label = label
    return container
end

-- Helper: Modern button
local function CreateModernButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(modernBackdrop)
    btn:SetBackdropColor(unpack(UI.btnNormal))
    btn:SetBackdropBorderColor(unpack(UI.border))

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    btn.label:SetTextColor(unpack(UI.text))
    btn.label:SetPoint("CENTER", 0, 0)
    btn.label:SetText(text)

    btn.SetText = function(_, t) btn.label:SetText(t) end

    btn:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(UI.btnHover)) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(UI.btnNormal)) end)
    btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(unpack(UI.btnPress)) end)
    btn:SetScript("OnMouseUp", function(self) self:SetBackdropColor(unpack(UI.btnHover)) end)
    btn:SetScript("OnClick", onClick)

    return btn
end

-- Helper: Section header
local function CreateSectionHeader(parent, text)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(parent:GetWidth() or 380, 20)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    label:SetTextColor(unpack(UI.textDim))
    label:SetPoint("LEFT", 0, 0)
    label:SetText(string.upper(text))

    local line = container:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    line:SetColorTexture(unpack(UI.border))

    return container
end

-- Create configuration window
local function CreateConfigFrame()
    local frame = CreateFrame("Frame", "JMAB_ConfigFrame", UIParent, "BackdropTemplate")
    frame:SetSize(560, 660)
    frame:SetPoint("CENTER")
    frame:SetBackdrop(modernBackdrop)
    frame:SetBackdropColor(unpack(UI.bg))
    frame:SetBackdropBorderColor(unpack(UI.border))
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    tinsert(UISpecialFrames, "JMAB_ConfigFrame")

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop(modernBackdrop)
    titleBar:SetBackdropColor(unpack(UI.header))
    titleBar:SetBackdropBorderColor(unpack(UI.border))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    titleText:SetTextColor(unpack(UI.accent))
    titleText:SetPoint("LEFT", 14, 0)
    titleText:SetText("Jar's Mouse Action Bars")

    -- Close  button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(32, 32)
    closeBtn:SetPoint("RIGHT", -2, 0)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    closeTxt:SetTextColor(unpack(UI.textDim))
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.4, 0.4, 1) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(unpack(UI.textDim)) end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Current spec and layout indicator
    frame.specLabel = frame:CreateFontString(nil, "OVERLAY")
    frame.specLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    frame.specLabel:SetTextColor(unpack(UI.textDim))
    frame.specLabel:SetPoint("TOP", titleBar, "BOTTOM", 0, -4)

    local function UpdateSpecLabel()
        local specName = GetCurrentSpecName()
        local layoutText = currentLayoutName and (": " .. currentLayoutName) or ": (none)"
        frame.specLabel:SetText("Spec: " .. specName .. " | Layout" .. layoutText)
    end
    UpdateSpecLabel()
    frame:HookScript("OnShow", UpdateSpecLabel)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -54)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(490, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local contentWidth = 480
    local yOff = 0
    local function nextY(h) yOff = yOff - h; return yOff end

    -- =====================
    -- LAYOUT MANAGEMENT
    -- =====================
    local sec1 = CreateSectionHeader(scrollChild, "Layout Management")
    sec1:SetSize(contentWidth, 20)
    sec1:SetPoint("TOPLEFT", 0, nextY(0))

    -- Layout name input
    local nameLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    nameLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    nameLabel:SetTextColor(unpack(UI.text))
    nameLabel:SetPoint("TOPLEFT", 0, nextY(28))
    nameLabel:SetText("Layout Name")

    local nameBox = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
    nameBox:SetSize(200, 25)
    nameBox:SetPoint("TOPLEFT", 0, nextY(24))
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(50)
    if currentLayoutName then
        nameBox:SetText(currentLayoutName)
    end
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Save button
    local layoutSaveBtn = CreateModernButton(scrollChild, "Save", 100, 25, function()
        local name = nameBox:GetText():trim()
        if SaveLayout(name) then
            UpdateSpecLabel()
            if frame.layoutDropdown then
                frame.layoutDropdown:GenerateMenu()
                frame.layoutDropdown:SetDefaultText(name)
            end
        end
    end)
    layoutSaveBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)

    -- Load dropdown
    local loadLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    loadLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    loadLabel:SetTextColor(unpack(UI.text))
    loadLabel:SetPoint("TOPLEFT", 0, nextY(34))
    loadLabel:SetText("Load Layout")

    local layoutDropdown = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    layoutDropdown:SetPoint("TOPLEFT", 0, nextY(20))
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
                    if frame.Reload then
                        frame:Reload()
                    end
                end
            end)
        end
    end)

    -- Delete button
    local deleteBtn = CreateModernButton(scrollChild, "Delete", 100, 25, function()
        local name = nameBox:GetText():trim()
        if name ~= "" and JarsMouseActionBarsDB.layouts[name] then
            DeleteLayout(name)
            nameBox:SetText("")
            layoutDropdown:GenerateMenu()
            layoutDropdown:SetDefaultText("Select a layout...")
            UpdateSpecLabel()
        else
            print("|cff00ff00Jar's Mouse Action Bars|r: Enter the name of a layout to delete.")
        end
    end)
    deleteBtn:SetPoint("LEFT", layoutDropdown, "RIGHT", 8, 0)

    -- =====================
    -- DISPLAY SETTINGS
    -- =====================
    local sec2 = CreateSectionHeader(scrollChild, "Display Settings")
    sec2:SetSize(contentWidth, 20)
    sec2:SetPoint("TOPLEFT", 0, nextY(36))

    -- Icon Size slider
    local sizeSlider = CreateModernSlider(scrollChild, "JMAB_SizeSlider", "Icon Size",
        20, 64, activeProfile.iconSize or 20, 2, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            activeProfile.iconSize = value
            RecreateTrackerFrame()
        end)
    sizeSlider:SetPoint("TOPLEFT", 0, nextY(28))

    -- Buttons Per Row slider
    local rowSlider = CreateModernSlider(scrollChild, "JMAB_RowSlider", "Buttons Per Row",
        3, 12, activeProfile.buttonsPerRow or 6, 1, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            activeProfile.buttonsPerRow = value
            RecreateTrackerFrame()
        end)
    rowSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- Cursor Offset X slider
    local offsetXSlider = CreateModernSlider(scrollChild, "JMAB_OffsetXSlider", "Cursor Offset X",
        -200, 200, activeProfile.cursorOffsetX or 40, 1, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            activeProfile.cursorOffsetX = value
        end)
    offsetXSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- Cursor Offset Y slider
    local offsetYSlider = CreateModernSlider(scrollChild, "JMAB_OffsetYSlider", "Cursor Offset Y",
        -200, 200, activeProfile.cursorOffsetY or -30, 1, contentWidth,
        function(v) return tostring(math.floor(v)) end,
        function(value)
            activeProfile.cursorOffsetY = value
        end)
    offsetYSlider:SetPoint("TOPLEFT", 0, nextY(48))

    -- =====================
    -- ACTION SLOTS
    -- =====================
    local sec3 = CreateSectionHeader(scrollChild, "Action Bar Slots to Mirror")
    sec3:SetSize(contentWidth, 20)
    sec3:SetPoint("TOPLEFT", 0, nextY(52))

    local slotsLabel = scrollChild:CreateFontString(nil, "OVERLAY")
    slotsLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    slotsLabel:SetTextColor(unpack(UI.textDim))
    slotsLabel:SetPoint("TOPLEFT", 0, nextY(24))
    slotsLabel:SetText("Enter action slot numbers (1-120). Bar 1: 1-12 | Bar 2: 13-24 | Bar 3: 25-36 | Bar 4: 37-48")

    -- Action slot inputs in grid
    local inputBoxes = {}
    nextY(24)
    local gridStartY = yOff
    for i = 1, MAX_BUTTONS do
        local box = CreateFrame("EditBox", nil, scrollChild, "InputBoxTemplate")
        box:SetSize(50, 25)

        local row = math.floor((i - 1) / 6)
        local col = (i - 1) % 6
        box:SetPoint("TOPLEFT", col * 70, gridStartY - (row * 32))

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

    yOff = gridStartY - (2 * 32) - 16  -- Account for 2 rows of inputs
    nextY(0)

    -- =====================
    -- ACTIONS
    -- =====================
    local sec4 = CreateSectionHeader(scrollChild, "Actions")
    sec4:SetSize(contentWidth, 20)
    sec4:SetPoint("TOPLEFT", 0, nextY(28))

    local applyBtn = CreateModernButton(scrollChild, "Apply Changes", 140, 28, function()
        for i = 1, MAX_BUTTONS do
            local value = tonumber(inputBoxes[i]:GetText()) or 0
            if value > 120 then value = 120 end
            activeProfile.actionSlots[i] = value
        end
        UpdateButtons(true)
        print("|cff00ff00Jar's Mouse Action Bars|r: Changes applied. Save a layout to persist them.")
    end)
    applyBtn:SetPoint("TOPLEFT", 0, nextY(28))

    local clearBtn = CreateModernButton(scrollChild, "Clear All", 120, 28, function()
        for i = 1, MAX_BUTTONS do
            inputBoxes[i]:SetText("")
            activeProfile.actionSlots[i] = 0
        end
        UpdateButtons()
    end)
    clearBtn:SetPoint("LEFT", applyBtn, "RIGHT", 8, 0)

    local defaultBtn = CreateModernButton(scrollChild, "Load Default", 120, 28, function()
        local defaults = {1, 2, 3, 4, 5, 6, 13, 14, 15, 16, 17, 18}
        for i = 1, MAX_BUTTONS do
            inputBoxes[i]:SetText(tostring(defaults[i]))
            activeProfile.actionSlots[i] = defaults[i]
        end
        UpdateButtons()
        print("|cff00ff00Jar's Mouse Action Bars|r: Default slots loaded. Save a layout to persist.")
    end)
    defaultBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)

    -- Set scroll child height
    scrollChild:SetHeight(math.abs(yOff) + 40)

-- Reload method to refresh UI with current profile data
    frame.Reload = function()
        -- Update action slot inputs
        for i = 1, MAX_BUTTONS do
            local slotNum = activeProfile.actionSlots[i] or 0
            inputBoxes[i]:SetText(slotNum > 0 and tostring(slotNum) or "")
        end

        -- Update sliders
        sizeSlider.slider:SetValue(activeProfile.iconSize or 20)
        sizeSlider.valueText:SetText(tostring(activeProfile.iconSize or 20))

        offsetXSlider.slider:SetValue(activeProfile.cursorOffsetX or 40)
        offsetXSlider.valueText:SetText(tostring(activeProfile.cursorOffsetX or 40))

        offsetYSlider.slider:SetValue(activeProfile.cursorOffsetY or -30)
        offsetYSlider.valueText:SetText(tostring(activeProfile.cursorOffsetY or -30))

        rowSlider.slider:SetValue(activeProfile.buttonsPerRow or 6)
        rowSlider.valueText:SetText(tostring(activeProfile.buttonsPerRow or 6))

        -- Update layout name and labels
        nameBox:SetText(currentLayoutName or "")
        layoutDropdown:GenerateMenu()
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
