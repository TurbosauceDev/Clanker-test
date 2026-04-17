-- UI: Battle frame and team select using WoW frame API

PB.UI = {}

local FRAME_W, FRAME_H = 700, 480
local LOG_LINES = 8

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function MakeFrame(ftype, name, parent, template)
    return CreateFrame(ftype or "Frame", name, parent or UIParent, template)
end

local function AddText(parent, x, y, text, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text or "")
    return fs
end

local function MakeButton(parent, w, h, label, onClick)
    local btn = MakeFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, h)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function MakeStatusBar(parent, w, h, r, g, b)
    local bar = MakeFrame("StatusBar", nil, parent)
    bar:SetSize(w, h)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(r, g, b, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    return bar
end

-- ─── Type color for move buttons ─────────────────────────────────────────────
local function HexToRGB(hex)
    return tonumber(hex:sub(1,2),16)/255,
           tonumber(hex:sub(3,4),16)/255,
           tonumber(hex:sub(5,6),16)/255
end

-- ─── Team Select Frame ───────────────────────────────────────────────────────
local teamSelectFrame
local selectedPetIDs = {}

function PB.UI.OpenTeamSelect()
    if not teamSelectFrame then PB.UI.BuildTeamSelectFrame() end
    PB.UI.RefreshTeamSelect()
    teamSelectFrame:Show()
end

function PB.UI.ToggleTeamSelect()
    if not teamSelectFrame then PB.UI.BuildTeamSelectFrame() end
    if teamSelectFrame:IsShown() then
        teamSelectFrame:Hide()
    else
        PB.UI.RefreshTeamSelect()
        teamSelectFrame:Show()
    end
end

function PB.UI.BuildTeamSelectFrame()
    local f = MakeFrame("Frame", "PBTeamSelectFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(620, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -6)
    title:SetText("PetBattle — Select Your Team (3)")

    -- Team slot display (top row)
    local slotLabels = {}
    local slotFrames = {}
    for i = 1, 3 do
        local sf = MakeFrame("Frame", nil, f)
        sf:SetSize(80, 80)
        sf:SetPoint("TOPLEFT", 20 + (i-1)*95, -40)
        local bg = sf:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
        local icon = sf:CreateTexture(nil, "ARTWORK")
        icon:SetSize(64, 64)
        icon:SetPoint("CENTER", 0, 8)
        icon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
        local lbl = sf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("BOTTOM", 0, 2)
        lbl:SetText("Empty")
        slotFrames[i] = { frame=sf, icon=icon, label=lbl }
    end

    -- Confirm button
    local confirmBtn = MakeButton(f, 120, 30, "Confirm Team", function()
        if #selectedPetIDs < 3 then
            PB.Print("Select 3 pets first!")
            return
        end
        PB.Network.SendTeam(selectedPetIDs)
        f:Hide()
    end)
    confirmBtn:SetPoint("BOTTOMRIGHT", -20, 20)

    local clearBtn = MakeButton(f, 80, 30, "Clear", function()
        selectedPetIDs = {}
        PB.UI.RefreshTeamSlots(slotFrames)
        PB.UI.RefreshPetList()
    end)
    clearBtn:SetPoint("BOTTOMRIGHT", confirmBtn, "BOTTOMLEFT", -10, 0)

    -- Scroll frame for pet list
    local scroll = MakeFrame("ScrollFrame", "PBTeamPetScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -130)
    scroll:SetPoint("BOTTOMRIGHT", -30, 60)

    local content = MakeFrame("Frame", nil, scroll)
    content:SetSize(560, 1)
    scroll:SetScrollChild(content)

    f.slotFrames = slotFrames
    f.content    = content
    teamSelectFrame = f
    selectedPetIDs = {}
end

function PB.UI.RefreshTeamSlots(slotFrames)
    local frames = slotFrames or (teamSelectFrame and teamSelectFrame.slotFrames)
    if not frames then return end
    for i = 1, 3 do
        local sf = frames[i]
        local petID = selectedPetIDs[i]
        if petID then
            local _, customName, _, _, _, _, _, name, icon = C_PetJournal.GetPetInfoByPetID(petID)
            sf.icon:SetTexture(icon or "Interface\\Icons\\inv_misc_questionmark")
            sf.label:SetText((customName and customName ~= "") and customName or name or "Pet")
        else
            sf.icon:SetTexture("Interface\\Icons\\inv_misc_questionmark")
            sf.label:SetText("Empty")
        end
    end
end

function PB.UI.RefreshPetList()
    if not teamSelectFrame then return end
    local content = teamSelectFrame.content
    -- Clear existing rows
    for _, child in ipairs({content:GetChildren()}) do child:Hide() end

    local total = C_PetJournal.GetNumPets()
    local y = 0
    local rowH = 44

    for i = 1, total do
        local petID, _, _, _, _, _, _, name, icon, petType, _, _, _, _, canBattle = C_PetJournal.GetPetInfoByIndex(i)
        if petID and canBattle then
            local row = MakeFrame("Button", nil, content)
            row:SetSize(550, rowH)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

            local ic = row:CreateTexture(nil, "ARTWORK")
            ic:SetSize(36, 36)
            ic:SetPoint("LEFT", 4, 0)
            ic:SetTexture(icon or "Interface\\Icons\\inv_misc_questionmark")

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameFS:SetPoint("LEFT", 46, 6)
            nameFS:SetText(name or "Unknown")

            local typeID = PB.FamilyType[petType] or PB.Types.NORMAL
            local typeName = PB.TypeNames[typeID] or "Normal"
            local typeColor = PB.TypeColors[typeID] or "ffffff"
            local typeFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            typeFS:SetPoint("LEFT", 46, -8)
            typeFS:SetText("|cff" .. typeColor .. typeName .. "|r")

            local wowTypeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            wowTypeLabel:SetPoint("RIGHT", -10, 0)
            wowTypeLabel:SetTextColor(0.7, 0.7, 0.7)
            -- WoW pet family names
            local familyNames = {"Humanoid","Dragonkin","Flying","Undead","Critter","Magic","Elemental","Beast","Aquatic","Mechanical"}
            wowTypeLabel:SetText(familyNames[petType] or "Unknown")

            local capturedPetID = petID
            row:SetScript("OnClick", function()
                -- Toggle selection
                local found = false
                for j, id in ipairs(selectedPetIDs) do
                    if id == capturedPetID then
                        table.remove(selectedPetIDs, j)
                        found = true
                        break
                    end
                end
                if not found then
                    if #selectedPetIDs >= 3 then
                        PB.Print("Team is full! Remove a pet first.")
                        return
                    end
                    selectedPetIDs[#selectedPetIDs+1] = capturedPetID
                end
                PB.UI.RefreshTeamSlots(nil)
            end)

            y = y + rowH
        end
    end
    content:SetHeight(math.max(y, 10))
end

function PB.UI.RefreshTeamSelect()
    selectedPetIDs = {}
    PB.UI.RefreshPetList()
    PB.UI.RefreshTeamSlots()
end

-- ─── Battle Frame ────────────────────────────────────────────────────────────
local battleFrame

function PB.UI.OpenBattleFrame()
    if not battleFrame then PB.UI.BuildBattleFrame() end
    PB.UI.Refresh()
    battleFrame:Show()
end

function PB.UI.ToggleBattleFrame()
    if not battleFrame then PB.UI.BuildBattleFrame() end
    if battleFrame:IsShown() then battleFrame:Hide() else battleFrame:Show() end
end

function PB.UI.BuildBattleFrame()
    local f = MakeFrame("Frame", "PBBattleFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(10)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -6)
    title:SetText("PetBattle")

    -- ── Opponent area (top) ─────────────────────────────────────────────────
    local oppArea = MakeFrame("Frame", nil, f)
    oppArea:SetSize(FRAME_W - 40, 80)
    oppArea:SetPoint("TOPLEFT", 20, -34)

    local oppBg = oppArea:CreateTexture(nil, "BACKGROUND")
    oppBg:SetAllPoints()
    oppBg:SetColorTexture(0.15, 0.05, 0.05, 0.9)

    local oppName = oppArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    oppName:SetPoint("TOPLEFT", 8, -6)
    oppName:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    oppName:SetText("Opponent's Pet")

    local oppType = oppArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oppType:SetPoint("TOPLEFT", 8, -22)
    oppType:SetText("Type: ???")

    local oppHPLabel = oppArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oppHPLabel:SetPoint("TOPRIGHT", -8, -6)
    oppHPLabel:SetJustifyH("RIGHT")
    oppHPLabel:SetText("HP: ???")

    local oppHPBar = MakeStatusBar(oppArea, FRAME_W - 120, 14, 0.2, 0.8, 0.2)
    oppHPBar:SetPoint("TOPLEFT", 8, -40)

    local oppStatus = oppArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    oppStatus:SetPoint("TOPLEFT", 8, -58)
    oppStatus:SetTextColor(1, 0.8, 0.2)
    oppStatus:SetText("")

    -- Opponent team balls (top right)
    local oppBalls = {}
    for i = 1, 3 do
        local ball = MakeFrame("Frame", nil, f)
        ball:SetSize(18, 18)
        ball:SetPoint("TOPRIGHT", -20 - (i-1)*22, -34)
        local tex = ball:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\PetBattles\\PetBattle-PassButton")  -- fallback circle
        tex:SetVertexColor(0.3, 0.9, 0.3)
        ball.tex = tex
        oppBalls[i] = ball
    end

    -- ── Player area (bottom) ────────────────────────────────────────────────
    local myArea = MakeFrame("Frame", nil, f)
    myArea:SetSize(FRAME_W - 40, 80)
    myArea:SetPoint("BOTTOMLEFT", 20, 110)

    local myBg = myArea:CreateTexture(nil, "BACKGROUND")
    myBg:SetAllPoints()
    myBg:SetColorTexture(0.05, 0.05, 0.20, 0.9)

    local myName = myArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    myName:SetPoint("BOTTOMLEFT", 8, 6)
    myName:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    myName:SetText("Your Pet")

    local myType = myArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    myType:SetPoint("BOTTOMLEFT", 8, 22)
    myType:SetText("Type: ???")

    local myHPLabel = myArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    myHPLabel:SetPoint("BOTTOMRIGHT", -8, 6)
    myHPLabel:SetJustifyH("RIGHT")
    myHPLabel:SetText("HP: ???")

    local myHPBar = MakeStatusBar(myArea, FRAME_W - 120, 14, 0.2, 0.8, 0.2)
    myHPBar:SetPoint("BOTTOMLEFT", 8, 40)

    local myStatus = myArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    myStatus:SetPoint("BOTTOMLEFT", 8, 58)
    myStatus:SetTextColor(1, 0.8, 0.2)
    myStatus:SetText("")

    -- My team balls (bottom left)
    local myBalls = {}
    for i = 1, 3 do
        local ball = MakeFrame("Frame", nil, f)
        ball:SetSize(18, 18)
        ball:SetPoint("BOTTOMLEFT", 20 + (i-1)*22, 110)
        local tex = ball:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetVertexColor(0.3, 0.9, 0.3)
        ball.tex = tex
        myBalls[i] = ball
    end

    -- ── Battle Log ──────────────────────────────────────────────────────────
    local logBg = MakeFrame("Frame", nil, f)
    logBg:SetPoint("TOPLEFT", 20, -120)
    logBg:SetPoint("BOTTOMRIGHT", -20, 110)
    local logBgTex = logBg:CreateTexture(nil, "BACKGROUND")
    logBgTex:SetAllPoints()
    logBgTex:SetColorTexture(0.05, 0.05, 0.05, 0.85)

    local logLines = {}
    for i = 1, LOG_LINES do
        local ls = logBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ls:SetPoint("TOPLEFT", 6, -(i-1)*18 - 6)
        ls:SetWidth(FRAME_W - 50)
        ls:SetJustifyH("LEFT")
        ls:SetText("")
        logLines[i] = ls
    end

    -- ── Move Buttons ─────────────────────────────────────────────────────────
    local moveButtons = {}
    local btnW, btnH = 155, 40
    local positions = {
        { "BOTTOMLEFT",  20,  75 },
        { "BOTTOMLEFT", 185,  75 },
        { "BOTTOMLEFT",  20,  32 },
        { "BOTTOMLEFT", 185,  32 },
    }

    for i = 1, 4 do
        local btn = MakeFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(btnW, btnH)
        btn:SetPoint(positions[i][1], f, positions[i][1], positions[i][2], positions[i][3])
        local moveLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        moveLbl:SetPoint("TOP", 0, -6)
        moveLbl:SetText("---")
        local typeLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        typeLbl:SetPoint("BOTTOM", 0, 6)
        typeLbl:SetText("")
        btn.moveLbl = moveLbl
        btn.typeLbl = typeLbl
        local capturedI = i
        btn:SetScript("OnClick", function()
            local battle = PB.Battle
            if battle.state ~= PB.State.CHOOSING then return end
            local myPet = battle.myTeam[battle.myActiveIndex]
            if not myPet then return end
            local moveName = myPet.moves[capturedI]
            if moveName then
                PB.Network.SendMove(moveName)
                PB.UI.SetMovesEnabled(false)
            end
        end)
        moveButtons[i] = btn
    end

    -- ── Switch Button ────────────────────────────────────────────────────────
    local switchBtn = MakeButton(f, 100, 30, "Switch", function()
        PB.UI.ShowSwitchMenu()
    end)
    switchBtn:SetPoint("BOTTOMLEFT", 360, 75)

    -- ── Forfeit Button ───────────────────────────────────────────────────────
    local forfeitBtn = MakeButton(f, 100, 30, "Forfeit", function()
        PB.Engine.Forfeit()
    end)
    forfeitBtn:SetPoint("BOTTOMRIGHT", -20, 32)

    -- Store refs
    f.oppName     = oppName
    f.oppType     = oppType
    f.oppHPLabel  = oppHPLabel
    f.oppHPBar    = oppHPBar
    f.oppStatus   = oppStatus
    f.oppBalls    = oppBalls
    f.myName      = myName
    f.myType      = myType
    f.myHPLabel   = myHPLabel
    f.myHPBar     = myHPBar
    f.myStatus    = myStatus
    f.myBalls     = myBalls
    f.moveButtons = moveButtons
    f.logLines    = logLines
    f.switchBtn   = switchBtn
    f.logBuffer   = {}

    battleFrame = f
end

-- ─── Refresh Battle Frame ────────────────────────────────────────────────────
function PB.UI.Refresh()
    if not battleFrame or not battleFrame:IsShown() then return end
    local f = battleFrame
    local battle = PB.Battle

    local function petTypeLabel(pet)
        if not pet then return "Type: ???" end
        local typeID = pet.pokeType
        local name = PB.TypeNames[typeID] or "Normal"
        local color = PB.TypeColors[typeID] or "ffffff"
        return "Type: |cff" .. color .. name .. "|r"
    end

    local function statusLabel(pet)
        if not pet or not pet.status then return "" end
        local statusColors = {
            burn="ff4400", poison="aa44ff", toxic="aa44ff",
            paralysis="ffff00", sleep="8888ff", freeze="88ffff",
            confusion="ff88ff", leech_seed="44ff44",
        }
        local col = statusColors[pet.status] or "ffffff"
        return "|cff" .. col .. pet.status:upper() .. "|r"
    end

    -- Opponent pet
    local oppPet = battle.oppTeam and battle.oppTeam[battle.oppActiveIndex]
    if oppPet then
        f.oppName:SetText(oppPet.name)
        f.oppType:SetText(petTypeLabel(oppPet))
        f.oppHPLabel:SetText("HP: " .. oppPet.currentHP .. "/" .. oppPet.baseStats.hp)
        local pct = oppPet.currentHP / oppPet.baseStats.hp
        f.oppHPBar:SetValue(pct)
        local r, g = 0.2, 0.8
        if pct < 0.5 then r, g = 0.9, 0.7 end
        if pct < 0.2 then r, g = 0.9, 0.1 end
        f.oppHPBar:SetStatusBarColor(r, g, 0.1, 1)
        f.oppStatus:SetText(statusLabel(oppPet))
    end

    -- My pet
    local myPet = battle.myTeam and battle.myTeam[battle.myActiveIndex]
    if myPet then
        f.myName:SetText(myPet.name)
        f.myType:SetText(petTypeLabel(myPet))
        f.myHPLabel:SetText("HP: " .. myPet.currentHP .. "/" .. myPet.baseStats.hp)
        local pct = myPet.currentHP / myPet.baseStats.hp
        f.myHPBar:SetValue(pct)
        local r, g = 0.2, 0.8
        if pct < 0.5 then r, g = 0.9, 0.7 end
        if pct < 0.2 then r, g = 0.9, 0.1 end
        f.myHPBar:SetStatusBarColor(r, g, 0.1, 1)
        f.myStatus:SetText(statusLabel(myPet))

        -- Move buttons
        for i, btn in ipairs(f.moveButtons) do
            local moveName = myPet.moves[i]
            local move     = moveName and PB.Moves[moveName]
            if move then
                local typeColor = PB.TypeColors[move.type] or "ffffff"
                local typeName  = PB.TypeNames[move.type] or "???"
                local pp = myPet.pp[moveName] or 0
                btn.moveLbl:SetText(moveName .. " (" .. pp .. "/" .. (move.pp or 0) .. ")")
                btn.typeLbl:SetText("|cff" .. typeColor .. typeName .. "|r  " .. move.category)
                local r, g, b = HexToRGB(typeColor)
                btn:GetNormalTexture():SetVertexColor(r*0.6+0.2, g*0.6+0.2, b*0.6+0.2, 1)
                btn:SetEnabled(true)
            else
                btn.moveLbl:SetText("---")
                btn.typeLbl:SetText("")
                btn:SetEnabled(false)
            end
        end
    end

    -- Team balls
    for i = 1, 3 do
        if f.myBalls[i] then
            local pet = battle.myTeam and battle.myTeam[i]
            local col = pet and (pet.isFainted and {0.5,0.1,0.1} or {0.3,0.9,0.3}) or {0.4,0.4,0.4}
            f.myBalls[i].tex:SetVertexColor(col[1], col[2], col[3])
        end
        if f.oppBalls[i] then
            local pet = battle.oppTeam and battle.oppTeam[i]
            local col = pet and (pet.isFainted and {0.5,0.1,0.1} or {0.3,0.9,0.3}) or {0.4,0.4,0.4}
            f.oppBalls[i].tex:SetVertexColor(col[1], col[2], col[3])
        end
    end

    -- Enable/disable move buttons based on state
    local canAct = (battle.state == PB.State.CHOOSING)
    PB.UI.SetMovesEnabled(canAct)
    f.switchBtn:SetEnabled(canAct)
end

function PB.UI.SetMovesEnabled(enabled)
    if not battleFrame then return end
    for _, btn in ipairs(battleFrame.moveButtons) do
        btn:SetEnabled(enabled)
    end
end

-- ─── Battle Log ──────────────────────────────────────────────────────────────
function PB.UI.LogLine(msg)
    if not battleFrame then return end
    local buf = battleFrame.logBuffer
    buf[#buf+1] = msg
    -- Keep only last LOG_LINES entries
    while #buf > LOG_LINES do table.remove(buf, 1) end
    for i, ls in ipairs(battleFrame.logLines) do
        ls:SetText(buf[i] or "")
    end
end

-- ─── Challenge Prompt ────────────────────────────────────────────────────────
function PB.UI.ShowChallengePrompt(challenger)
    StaticPopupDialogs["PB_CHALLENGE"] = {
        text = challenger .. " challenges you to a PetBattle!\nAccept?",
        button1 = "Accept",
        button2 = "Decline",
        OnAccept = function() PB.Network.AcceptChallenge() end,
        OnCancel = function() PB.Network.DeclineChallenge() end,
        timeout = 30,
        whileDead = false,
        hideOnEscape = true,
    }
    StaticPopup_Show("PB_CHALLENGE")
end

-- ─── Switch Menu ─────────────────────────────────────────────────────────────
local switchMenuFrame

function PB.UI.ShowSwitchPrompt()
    PB.UI.ShowSwitchMenu()
end

function PB.UI.ShowSwitchMenu()
    if not switchMenuFrame then
        local sf = MakeFrame("Frame", "PBSwitchFrame", UIParent, "BasicFrameTemplateWithInset")
        sf:SetSize(280, 180)
        sf:SetPoint("CENTER")
        sf:SetFrameStrata("DIALOG")
        local title = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -8)
        title:SetText("Choose a pet to send out")
        local btns = {}
        for i = 1, 3 do
            local btn = MakeFrame("Button", nil, sf, "UIPanelButtonTemplate")
            btn:SetSize(240, 36)
            btn:SetPoint("TOP", 0, -32 - (i-1)*42)
            local capturedI = i
            btn:SetScript("OnClick", function()
                sf:Hide()
                PB.Network.SendSwitch(capturedI)
            end)
            btns[i] = btn
        end
        sf.btns = btns
        switchMenuFrame = sf
    end

    local battle = PB.Battle
    for i = 1, 3 do
        local pet = battle.myTeam and battle.myTeam[i]
        local btn = switchMenuFrame.btns[i]
        if pet then
            local hpPct = math.floor((pet.currentHP / pet.baseStats.hp) * 100)
            local label = pet.name .. " — " .. hpPct .. "% HP"
            if pet.isFainted then label = pet.name .. " [FAINTED]" end
            if i == battle.myActiveIndex then label = label .. " (Active)" end
            btn:SetText(label)
            btn:SetEnabled(not pet.isFainted and i ~= battle.myActiveIndex)
        else
            btn:SetText("—")
            btn:SetEnabled(false)
        end
    end
    switchMenuFrame:Show()
end

-- ─── On Battle End ───────────────────────────────────────────────────────────
function PB.UI.OnBattleEnd(winner)
    PB.UI.SetMovesEnabled(false)
    if battleFrame then
        battleFrame.switchBtn:SetEnabled(false)
    end
end
