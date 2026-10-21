--[[ EnhaPrio Rebuffed: display and options. Based on EnhaPrio by Stormcast; the decision logic is in
Engine.lua. ]]

local ADDON, ns = ...
local E = ns.Engine

local function orderedProfiles(db)
	local rank, t = {}, {}
	for i, p in ipairs(E.PROFILES) do rank[p] = 1000 + i; t[i] = p end
	for i, id in ipairs(db.order or {}) do if E.PROFILE_BY_ID[id] then rank[E.PROFILE_BY_ID[id]] = i end end
	table.sort(t, function(a, b) return rank[a] < rank[b] end)
	return t
end
local function buildProfiles(db)
	local b = db.build == "WINDFURY" and "WINDFURY" or "SPELL"
	local t = {}
	for _, p in ipairs(orderedProfiles(db)) do if p.build == b then t[#t + 1] = p end end
	return t
end
local function neighbour(db, p, dir)
	local all = orderedProfiles(db)
	for i, x in ipairs(all) do
		if x == p then
			local k = i + dir
			while all[k] and all[k].build ~= p.build do k = k + dir end
			return all, i, all[k] and k
		end
	end
	return all
end
local function currentProfile(db)
	local p = E.PROFILE_BY_ID[db.profile]
	local list = buildProfiles(db)
	for _, q in ipairs(list) do if q == p then return p end end
	return list[1]
end
local function prioFor(db)
	return currentProfile(db).list
end
local function profileLabel(db)
	return currentProfile(db).label
end

local EP = LibStub("AceAddon-3.0"):NewAddon("EnhaPrioRebuffed", "AceConsole-3.0", "AceEvent-3.0")
ns.addon = EP
local LBF = LibStub("LibButtonFacade", true)
local skinGroup = LBF and LBF:Group("EnhaPrio Rebuffed") or nil

local MAX_QUEUE = 8
local mainFrame, queueFrames
local timeLeft = 0

local defaults = {
	char = {
		x = 0, y = -150, relativePoint = "CENTER",
		size = 50, spacing = 2, locked = false,
		updateFrequency = 0.1,
		manaThreshold = 20,
		srManaPercent = 20,
		maxQueue = 5,
		queueDirection = "UP",
		displayMW = true,
		displayGCD = true,
		aoe = false,
		enableLongCD = true,
		longCdBossOnly = true,
		showInterrupt = true,
		showPurge = true,
		showGloves = true,
		showRacial = true,
		alwaysShow = false,
		order = {},
		alwaysShowProfile = false,
		showSelector = false,
		selX = -250, selY = -150, selPoint = "CENTER",
		resize = false,
		selScale = 1,
		build ="SPELL",
		lavaBurst = true,
		profile = "ST",
		cycle = { ST = true, ST_NOFN = true, ST_NOLVB = true, ST_MW4 = true, ST_MW5 = true, AOE = true, WF = true, WF_AOE = true },
		settingsRev = 0,
		bf = { SkinID = "Blizzard", Gloss = 0, Backdrop = true, Colors = {} },
	},
}

local function chat(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhaPrio Rebuffed:|r " .. tostring(msg)) end

local function spellTexture(key)
	local id = E.ID[key]
	return id and select(3, GetSpellInfo(id)) or nil
end

local SP_PROC_TRINKETS = {
  [28034] = { 33649, 10, 0, 99 },   -- 28034 = Hourglass of the Unraveller
  [28789] = { 34747, 10, 0, 170 },   -- 28789 = Eye of Magtheridon
  [30626] = { 38348, 15, 0, 190 },   -- 30626 = Sextant of Unstable Currents
  [32770] = { 41261, 30, 0, 46 },   -- 32770 = Skyguard Silver Cross
  [32771] = { 41263, 30, 0, 80 },   -- 32771 = Airman's Ribbon of Gallantry
  [34472] = { 45053, 20, 0, 76 },   -- 34472 = Shard of Contempt
  [37660] = { 60479, 10, 45, 512 },   -- 37660 = Forge Ember
  [40255] = { 60494, 10, 45, 765 },   -- 40255 = Dying Curse
  [40682] = { 60064, 10, 45, 590 },   -- 40682 = Sundial of the Exiled
  [40684] = { 60065, 10, 0, 330 },   -- 40684 = Mirror of Truth
  [40767] = { 55018, 10, 0, 142 },   -- 40767 = Sonic Booster
  [44912] = { 60064, 10, 50, 590 },   -- 44912 = Flow of Knowledge
  [44914] = { 60065, 10, 0, 330 },   -- 44914 = Anvil of Titans
  [45286] = { 65014, 10, 0, 407 },   -- 45286 = Pyrite Infuser
  [45490] = { 64741, 10, 45, 751 },   -- 45490 = Pandora's Plea
  [45518] = { 64713, 10, 45, 850 },   -- 45518 = Flare of the Heavens
  [45522] = { 64790, 10, 0, 424 },   -- 45522 = Blood of the Old God
  [47213] = { 67669, 10, 45, 590 },   -- 47213 = Abyssal Rune
  [49076] = { 60064, 10, 45, 590 },   -- 49076 = Mithril Pocketwatch
  [50360] = { 71605, 20, 100, 1074 },   -- 50360 = Phylactery of the Nameless Lich
  [50365] = { 71636, 20, 100, 1207 },   -- 50365 = Phylactery of the Nameless Lich (heroic)
  [50397] = { 72416, 10, 60, 285 },   -- 50397 = Frostforged Sage
  [50398] = { 72416, 10, 60, 285 },   -- 50398 = Frostforged Sage
  [54572] = { 75466, 15, 50, 763 },   -- 54572 = Charred Twilight Scale
  [54588] = { 75473, 15, 50, 861 },   -- 54588 = Charred Twilight Scale (heroic)
  [440255] = { 60494, 10, 45, 765 },   -- 440255 = Dying Curse
  [445518] = { 64713, 10, 45, 850 },   -- 445518 = Flare of the Heavens
  [1207053] = { 9250482, 10, 45, 586 },   -- 1207053 = Forge Ember
  [1208379] = { 9250535, 10, 0, 163 },   -- 1208379 = Sonic Booster
  [1209269] = { 9250856, 10, 0, 288 },   -- 1209269 = Coren's Chromium Coaster
  [1209270] = { 9250858, 10, 45, 515 },   -- 1209270 = Mithril Pocketwatch
}
ns.resetSundialTracking = function() end
local function buffExpires(spellId)
	for i = 1, 40 do
		local name, _, _, _, _, _, expires, _, _, _, id = UnitBuff("player", i)
		if not name then return nil end
		if id == spellId then return expires end
	end
	return nil
end
local function spTrinketProc()
	local strongest
	for _, slot in ipairs({ 13, 14 }) do
		local t = SP_PROC_TRINKETS[GetInventoryItemID("player", slot) or 0]
		if t and (not strongest or t[4] > strongest[4]) then strongest = t end
	end
	if not strongest then return nil, false end
	return buffExpires(strongest[1]), true
end
local function playerBuff(spellId)
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, id = UnitBuff("player", i)
		if not name then return false end
		if id == spellId then return true end
	end
	return false
end

local function isBoss()
	return UnitLevel("target") == -1
end

local function hostileTarget()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

local function colorFor(f, key)
	local name = key and GetSpellInfo(E.ID[key])
	if not name then
		f.spellTexture:SetVertexColor(1, 1, 1)
		return
	end
	local _, _, _, cost = GetSpellInfo(name)
	if IsSpellInRange(name, "target") == 0 then
		f.spellTexture:SetVertexColor(1, 0, 0)
		return
	elseif cost and cost > 0 and UnitPower("player") < cost then
		f.spellTexture:SetVertexColor(0.4, 0.4, 0.4)
		return
	end
	f.spellTexture:SetVertexColor(1, 1, 1)
end

local T10_IDS = {}
for _, id in ipairs({ 50830, 50831, 50832, 50833, 50834, 51195, 51196, 51197, 51198, 51199,
		51240, 51241, 51242, 51243, 51244 }) do T10_IDS[id] = true end
local function t10Pieces()
	local n = 0
	for _, slot in ipairs({ 1, 3, 5, 7, 10 }) do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local id = tonumber(link:match("item:(%d+)"))
			if T10_IDS[id] or link:find("Frost Witch's", 1, true) then n = n + 1 end
		end
	end
	return n
end

local function preActions()
	local list = {}
	local hasMH, _, _, hasOH = GetWeaponEnchantInfo()
	local mhKey = EP.db.char.build == "WINDFURY" and "WF_IMBUE" or "FT_IMBUE"
	if not hasMH then list[#list + 1] = mhKey end
	if not hasOH and OffhandHasWeapon and OffhandHasWeapon() then list[#list + 1] = "FT_IMBUE" end
	local mana, maxMana = UnitPower("player", 0), UnitPowerMax("player", 0)
	local srStart, srDur = E.spellCooldown("SR")
	if srStart and maxMana and maxMana > 0 and (srStart == 0 or (srDur or 0) <= 1.6)
		and IsSpellInRange(GetSpellInfo(E.ID.SS), "target") == 1
		and (mana / maxMana * 100 < EP.db.char.srManaPercent or t10Pieces() >= 2) then
		list[#list + 1] = "SR"
	end
	return list
end

local IMBUE_ID = { FT_IMBUE = 58790, WF_IMBUE = 58804 }

local function textureFor(key)
	if IMBUE_ID[key] then return select(3, GetSpellInfo(IMBUE_ID[key])) end
	if key == "CL" then return select(3, GetSpellInfo(E.ID.CL)) end
	return spellTexture(key)
end

local LABEL_SECONDS = 3
local function labelText(hidden)
	local db = EP.db.char
	return (((db.alwaysShowProfile and not hidden) or EP.hovering or GetTime() < (EP.labelUntil or 0)) and profileLabel(db) or "")
end

local SWIRL_MIN, SWIRL_MOVE = 0.05, 0.1
local function setWaitSwirl(f, now, wait)
	if not wait or wait <= SWIRL_MIN then
		if f.swirlEnd then
			f.swirlEnd = nil
			CooldownFrame_SetTimer(f.cooldown, 0, 0, 0)
		end
		return
	end
	local stop = now + wait
	if not f.swirlEnd or math.abs(stop - f.swirlEnd) > SWIRL_MOVE then
		f.swirlEnd = stop
		CooldownFrame_SetTimer(f.cooldown, now, wait, 1)
	end
end

local cooldownLook, readyLook

function EP:Recalculate()
	local db = self.db.char
	local maxQueue = math.min(db.maxQueue, MAX_QUEUE)
	local hidden = not db.alwaysShow and not (hostileTarget() and not UnitIsDeadOrGhost("player"))
	self.displayHidden = hidden
	self:UpdateSelector()
	self:UpdateGrips(hidden)
	if hidden then
		for i = 1, MAX_QUEUE do queueFrames[i]:Hide() end
		mainFrame.text:SetText("")
		mainFrame.aoeText:SetText(labelText(true))
		for _, k in ipairs({ "wolf", "elemental", "interrupt", "purge", "gloves", "racial" }) do mainFrame[k]:Hide() end
		return
	end
	local now = GetTime()
	local st = E.snapshot(now)
	local prio = prioFor(db)
	local fc = E.forecast(st, prio, maxQueue)
	local entries = {}
	for _, k in ipairs(preActions()) do entries[#entries + 1] = { key = k, at = now } end
	for _, e in ipairs(fc) do
		if #entries >= maxQueue then break end
		entries[#entries + 1] = { key = e.key, at = e.at, tok = e.tok }
	end
	if self.debugOn then self:DebugRecord(now, st, entries, currentProfile(db).id) end

	if db.displayMW and st.mw > 0 then
		mainFrame.text:SetText(st.mw)
		local c = ({ { 1, 1, 1 }, { 1, 1, 0 }, { 1, 1, 0 }, { 1, 0.5, 0 }, { 1, 0, 0 } })[math.min(st.mw, 5)]
		mainFrame.text:SetTextColor(c[1], c[2], c[3], 1)
	else
		mainFrame.text:SetText("")
	end
	local label = labelText()
	mainFrame.aoeText:SetText(label)

	for i = 1, MAX_QUEUE do
		local f, e = queueFrames[i], entries[i]
		if e and i <= maxQueue then
			f.spellTexture:SetTexture(textureFor(e.key))
			colorFor(f, E.ID[e.key] and e.key or nil)
			local wait = (e.at or now) - now
			local swirl = db.displayGCD and e.tok and E.readyIn(st, e.tok) or nil
			if i == 1 and wait > 0.15 then
				f.cooldownText:SetText(wait >= 1 and ("%d"):format(wait + 0.5) or ("%.1f"):format(wait))
			else
				f.cooldownText:SetText("")
			end
			setWaitSwirl(f, now, swirl)
			f:SetAlpha(i == 1 and 1 or 0.85)
			f:Show()
		else
			f.spellTexture:SetTexture(nil)
			f.cooldownText:SetText("")
			setWaitSwirl(f, now, nil)
			f:Hide()
		end
	end

	local longOk = db.enableLongCD and (isBoss() or not db.longCdBossOnly)
	for frameKey, key in pairs({ wolf = "FSP", elemental = "FE" }) do
		local fr = mainFrame[frameKey]
		local s, d = E.spellCooldown(key)
		local isReady = s ~= nil and (s == 0 or (d or 0) <= 1.6)
		if key == "FE" then
			local procExp, worn = spTrinketProc()
			if isReady and worn and not (procExp and procExp > now) then isReady = false end
		end
		local onCd = s ~= nil and s > 0 and (d or 0) > 1.6
		if longOk and isReady then
			fr.texture:SetTexture(spellTexture(key))
			readyLook(fr)
			fr:Show()
		elseif longOk and onCd then
			fr.texture:SetTexture(spellTexture(key))
			cooldownLook(fr, now, s, d)
			fr:Show()
		else
			fr:Hide()
		end
		if key == "FE" then
			local procExp = spTrinketProc()
			if longOk and isReady and procExp and procExp > now then
				fr.glow:SetAlpha(0.55 + 0.45 * math.abs(math.sin(now * 4)))
				fr.glow:Show()
				fr.timerText:SetText(("%d"):format(math.ceil(procExp - now)))
			else
				if not (longOk and onCd) then fr.glow:Hide() end
				fr.timerText:SetText("")
			end
		end
	end

	self:UpdateInterruptPurge()
	self:UpdateGloves(now)
	self:UpdateRacial(now)
end

local GLOVE_SLOT, GLOVE_GLOW_SECONDS = 10, 3
local GLOVE_GLOW_SOON, GLOVE_GLOW_READY = 0.10, 1
local GLOVE_BUFFS = { [54758] = true }
local gloveTip = CreateFrame("GameTooltip", "EnhaPrioRebuffedScanTip", nil, "GameTooltipTemplate")
local gloveUse = { link = false, has = false, at = 0 }

local function gloveHasUse(now)
	local link = GetInventoryItemLink("player", GLOVE_SLOT)
	if link == gloveUse.link and (gloveUse.has or now - gloveUse.at < 5) then return gloveUse.has end
	gloveUse.link, gloveUse.at, gloveUse.has = link, now, false
	if not link then return false end
	local use = ITEM_SPELL_TRIGGER_ONUSE or "Use:"
	gloveTip:SetOwner(UIParent, "ANCHOR_NONE")
	gloveTip:ClearLines()
	gloveTip:SetInventoryItem("player", GLOVE_SLOT)
	for i = 1, gloveTip:NumLines() or 0 do
		local fs = _G["EnhaPrioRebuffedScanTipTextLeft" .. i]
		local text = fs and fs:GetText()
		if text and text:sub(1, #use) == use then gloveUse.has = true break end
	end
	gloveTip:Hide()
	return gloveUse.has
end

local function gloveEffect()
	for i = 1, 40 do
		local n, _, _, _, _, duration, expires, _, _, _, id = UnitBuff("player", i)
		if not n then break end
		if GLOVE_BUFFS[id] then return expires, duration end
	end
end

local function setSwirl(fr, start, duration)
	if fr.cdStart ~= start or fr.cdDuration ~= duration then
		fr.cdStart, fr.cdDuration = start, duration
		CooldownFrame_SetTimer(fr.cooldown, start, duration, duration > 0 and 1 or 0)
	end
end

local CD_ALPHA = 0.9
local function timeLeftText(left)
	if left >= 60 then return ("%dm"):format(math.ceil(left / 60)) end
	return ("%d"):format(math.ceil(left))
end
function cooldownLook(fr, now, s, d)
	fr.texture:SetDesaturated(true)
	fr.texture:SetAlpha(CD_ALPHA)
	setSwirl(fr, s, d)
	fr.countText:SetText(timeLeftText(s + d - now))
	fr.glow:SetAlpha(GLOVE_GLOW_SOON)
	fr.glow:Show()
end
function readyLook(fr)
	fr.texture:SetDesaturated(false)
	fr.texture:SetAlpha(1)
	setSwirl(fr, 0, 0)
	fr.countText:SetText("")
	fr.glow:Hide()
end

local showUseIcon

function EP:UpdateGloves(now)
	local fr = mainFrame.gloves
	if not (self.db.char.showGloves and gloveHasUse(now)) then
		fr.phase, fr.readyAt = nil, nil
		fr:Hide()
		return
	end
	local s, d = GetInventoryItemCooldown("player", GLOVE_SLOT)
	local effExp, effDur = gloveEffect()
	showUseIcon(fr, now, GetInventoryItemTexture("player", GLOVE_SLOT), s, d, effExp, effDur)
end

local RACIALS = { 33697, 20572, 33702, 26297 }

local function racialKnown()
	for _, id in ipairs(RACIALS) do
		local name = GetSpellInfo(id)
		if name and GetSpellCooldown(name) then return id, name end
	end
end

local function buffById(id)
	for i = 1, 40 do
		local n, _, _, _, _, duration, expires, _, _, _, sid = UnitBuff("player", i)
		if not n then break end
		if sid == id then return expires, duration end
	end
end

function EP:UpdateRacial(now)
	local fr = mainFrame.racial
	local id, name = racialKnown()
	if not (self.db.char.showRacial and id) then
		fr.phase, fr.readyAt = nil, nil
		fr:Hide()
		return
	end
	local s, d = GetSpellCooldown(name)
	local effExp, effDur = buffById(id)
	showUseIcon(fr, now, select(3, GetSpellInfo(id)), s, d, effExp, effDur)
end

function showUseIcon(fr, now, texture, s, d, effExp, effDur)
	local left = (s and s > 0 and d and d > 1.6) and (s + d - now) or 0
	local phase
	if effExp and effExp > now then
		phase = "effect"
	elseif left > 0 then
		phase = "cooldown"
	else
		phase = "ready"
	end
	if phase ~= "ready" then
		fr.readyAt = nil
	elseif fr.phase and fr.phase ~= "ready" then
		fr.readyAt = now
	end
	fr.phase = phase
	fr.texture:SetTexture(texture)
	if phase == "cooldown" then
		cooldownLook(fr, now, s, d)
	elseif phase == "effect" then
		fr.texture:SetDesaturated(false)
		fr.texture:SetAlpha(1)
		setSwirl(fr, effExp - (effDur or 0), effDur or 0)
		fr.countText:SetText(("%d"):format(math.ceil(effExp - now)))
		fr.glow:Hide()
	else
		readyLook(fr)
		if fr.readyAt and now - fr.readyAt < GLOVE_GLOW_SECONDS then
			fr.glow:SetAlpha(GLOVE_GLOW_READY)
			fr.glow:Show()
		else
			fr.glow:Hide()
		end
	end
	fr:Show()
end

local function setBorder(fr, red)
	if red then fr:SetBackdropBorderColor(1, 0, 0, 1) else fr:SetBackdropBorderColor(1, 1, 1, 1) end
end

local function spellUsable(id)
	local name = GetSpellInfo(id)
	if not name then return false end
	local s, d = GetSpellCooldown(name)
	local offCd = not s or s == 0 or (d or 0) <= 1.6
	local usable, noMana = IsUsableSpell(name)
	return offCd and usable and not noMana and IsSpellInRange(name, "target") == 1
end

function EP:UpdateInterruptPurge()
	local db = self.db.char
	local hostile = hostileTarget()
	local fr = mainFrame.interrupt
	local name, _, _, icon, _, _, _, _, notInterruptible = UnitCastingInfo("target")
	if not name then
		name, _, _, icon, _, _, _, notInterruptible = UnitChannelInfo("target")
	end
	if db.showInterrupt and hostile and name then
		fr.texture:SetTexture(icon)
		setBorder(fr, notInterruptible or not spellUsable(E.ID.SHEAR))
		fr:Show()
	else
		fr:Hide()
	end
	fr = mainFrame.purge
	local purgeIcon
	if db.showPurge and hostile then
		for i = 1, 40 do
			local bName, _, bIcon, _, bType = UnitBuff("target", i)
			if not bName then break end
			if bType == "Magic" then purgeIcon = bIcon; break end
		end
	end
	if purgeIcon then
		fr.texture:SetTexture(purgeIcon)
		setBorder(fr, not spellUsable(E.ID.PURGE))
		fr:Show()
	else
		fr:Hide()
	end
end

local BORDER = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 } }

local function newSmallFrame(name)
	local fr = CreateFrame("Button", name, mainFrame)
	fr.texture = fr:CreateTexture(nil, "BACKGROUND")
	fr.texture:SetPoint("TOPLEFT", 2, -2)
	fr.texture:SetPoint("BOTTOMRIGHT", -2, 2)
	fr:SetBackdrop(BORDER)
	fr:SetBackdropBorderColor(1, 1, 1, 1)
	fr.glow = fr:CreateTexture(nil, "OVERLAY")
	fr.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	fr.glow:SetBlendMode("ADD")
	fr.glow:SetVertexColor(1, 0.85, 0.2, 1)
	fr.glow:SetPoint("TOPLEFT", -8, 8)
	fr.glow:SetPoint("BOTTOMRIGHT", 8, -8)
	fr.glow:Hide()
	fr.timerText = fr:CreateFontString(nil, "OVERLAY")
	fr.timerText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	fr.timerText:SetPoint("BOTTOM", fr, "TOP", 0, 1)
	fr.timerText:SetTextColor(1, 0.85, 0.2, 1)
	fr:EnableMouse(false)
	fr:Hide()
	return fr
end

function EP:SaveLocation()
	local _, _, relativePoint, x, y = mainFrame:GetPoint()
	self.db.char.x, self.db.char.y, self.db.char.relativePoint = x, y, relativePoint
end

function EP:CycleProfile()
	local db = self.db.char
	local list = buildProfiles(db)
	local curId = currentProfile(db).id
	local n, cur = #list, 0
	for i, p in ipairs(list) do if p.id == curId then cur = i end end
	for step = 1, n do
		local p = list[(cur + step - 1) % n + 1]
		if db.cycle[p.id] and p.id ~= curId then
			db.profile = p.id
			self.labelUntil = GetTime() + LABEL_SECONDS
			timeLeft = 0
			return
		end
	end
end

local SEL_W, SEL_H, SEL_GAP, SEL_PAD = 76, 22, 4, 5
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local function selectorStyle()
	local E = type(ElvUI) == "table" and ElvUI[1]
	local m = type(E) == "table" and E.media or {}
	return m.backdropfadecolor or { 0.06, 0.06, 0.06, 0.8 }, m.bordercolor or { 0, 0, 0 }, m.normFont or "Fonts\\FRIZQT__.TTF"
end

local function anchorTopLeft(f)
	local l, t = f:GetLeft(), f:GetTop()
	if not (l and t) then return end
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", l, t - UIParent:GetHeight())
end
local function makeGrip(parent, get, set, stop)
	local g = CreateFrame("Button", nil, parent)
	g:SetWidth(16)
	g:SetHeight(16)
	g:SetPoint("TOPLEFT", parent, "BOTTOMRIGHT", -4, 4)
	g:SetFrameLevel(parent:GetFrameLevel() + 10)
	g:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	g:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	g:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	local function finish(self)
		if not self:GetScript("OnUpdate") then return end
		self:SetScript("OnUpdate", nil)
		stop()
	end
	g:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		anchorTopLeft(parent)
		self.x0, self.y0 = GetCursorPosition()
		self.v0, self.span = get(), parent:GetWidth() + parent:GetHeight()
		self:SetScript("OnUpdate", function(self)
			if not IsMouseButtonDown("LeftButton") then finish(self) return end
			local x, y = GetCursorPosition()
			set(self.v0, ((x - self.x0) + (self.y0 - y)) / UIParent:GetEffectiveScale(), self.span)
		end)
	end)
	g:SetScript("OnMouseUp", finish)
	g:Hide()
	return g
end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function EP:UpdateGrips(hidden)
	local db = self.db.char
	local on = db.resize and not db.locked
	local g = mainFrame.grip
	if g then if (on and not hidden) or g:GetScript("OnUpdate") then g:Show() else g:Hide() end end
	local sg = ns.selector and ns.selector.grip
	if sg then if on then sg:Show() else sg:Hide() end end
end

function EP:SelectProfile(id)
	if not E.PROFILE_BY_ID[id] then return end
	self.db.char.profile = id
	self.labelUntil = GetTime() + LABEL_SECONDS
	timeLeft = 0
	self:UpdateSelector()
end
function EP:UpdateSelector()
	local db = self.db.char
	local frame = ns.selector
	local dragging = frame and (frame.moving or (frame.grip and frame.grip:GetScript("OnUpdate")))
	if not db.showSelector or (self.displayHidden and not dragging) then
		if frame then frame:Hide() end
		return
	end
	if not frame then
		frame = CreateFrame("Frame", "EnhaPrioRebuffedSelector", UIParent)
		frame:SetFrameStrata("MEDIUM")
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
		frame:SetBackdrop(FLAT)
		frame:SetScript("OnMouseDown", function(f)
			if not EP.db.char.locked then
				f.moving = true
				f:StartMoving()
			end
		end)
		frame:SetScript("OnMouseUp", function(f)
			f.moving = nil
			f:StopMovingOrSizing()
			local point, _, _, x, y = f:GetPoint()
			EP.db.char.selPoint, EP.db.char.selX, EP.db.char.selY = point, x, y
		end)
		frame:ClearAllPoints()
		frame:SetPoint(db.selPoint, UIParent, db.selPoint, db.selX, db.selY)
		frame.boxes = {}
		frame.grip = makeGrip(frame, function() return EP.db.char.selScale or 1 end, function(v0, d, span)
			EP.db.char.selScale = clamp(v0 * (span + d) / math.max(span, 1), 0.5, 3)
			EP:UpdateSelector()
		end, function()
			local point, _, _, x, y = frame:GetPoint()
			EP.db.char.selPoint, EP.db.char.selX, EP.db.char.selY = point, x, y
		end)
		ns.selector = frame
	end
	local s = db.selScale or 1
	local bg, border, font = selectorStyle()
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], 1)
	local cur = currentProfile(db).id
	local sel = {}
	for _, p in ipairs(buildProfiles(db)) do
		if db.cycle[p.id] then sel[#sel + 1] = p end
	end
	for i, p in ipairs(sel) do
		local b = frame.boxes[i]
		if not b then
			b = CreateFrame("Button", nil, frame)
			b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
			b.fill = b:CreateTexture(nil, "BACKGROUND")
			b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
			b.fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
			b.fill:SetTexture(1, 1, 1, 1)
			b.text = b:CreateFontString(nil, "OVERLAY")
			b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
			b.text:SetTextColor(1, 1, 1, 1)
			b:RegisterForClicks("LeftButtonUp")
			b:SetScript("OnClick", function(self) EP:SelectProfile(self.profileId) end)
			frame.boxes[i] = b
		end
		b:SetWidth(SEL_W * s)
		b:SetHeight(SEL_H * s)
		b:ClearAllPoints()
		b:SetPoint("TOP", frame, "TOP", 0, -(SEL_PAD + (i - 1) * (SEL_H + SEL_GAP)) * s)
		b:SetBackdropBorderColor(border[1], border[2], border[3], 1)
		b.text:SetFont(font, 12 * s, "")
		b.profileId = p.id
		b.text:SetText(p.label)
		local on = p.id == cur
		if on then b.fill:SetVertexColor(0.05, 0.45, 0.15, 1) else b.fill:SetVertexColor(0.18, 0.18, 0.18, 1) end
		b:Show()
	end
	for i = #sel + 1, #frame.boxes do frame.boxes[i]:Hide() end
	frame:SetWidth((SEL_W + 2 * SEL_PAD) * s)
	frame:SetHeight(math.max(1, (#sel * (SEL_H + SEL_GAP) - SEL_GAP + 2 * SEL_PAD) * s))
	frame:Show()
end

function EP:GetProfileValues()
	local v = {}
	for i, p in ipairs(buildProfiles(self.db.char)) do v[tostring(i)] = p.name end
	return v
end
function EP:GetProfileChoice()
	local cur = currentProfile(self.db.char)
	for i, p in ipairs(buildProfiles(self.db.char)) do if p == cur then return tostring(i) end end
	return "1"
end
function EP:SetProfileChoice(info, value)
	local p = buildProfiles(self.db.char)[tonumber(value) or 0]
	if not p then return end
	self.db.char.profile = p.id
	self.labelUntil = GetTime() + LABEL_SECONDS
	timeLeft = 0
end

function EP:GetCycle(info) return self.db.char.cycle[info[#info]] and true or false end
function EP:SetCycle(info, value) self.db.char.cycle[info[#info]] = value end

function EP:MoveProfile(id, dir)
	local all, i, k = neighbour(self.db.char, E.PROFILE_BY_ID[id], dir)
	if not k then return end
	all[i], all[k] = all[k], all[i]
	local ids = {}
	for n, x in ipairs(all) do ids[n] = x.id end
	self.db.char.order = ids
	LibStub("AceConfigRegistry-3.0"):NotifyChange("EnhaPrio Rebuffed")
	timeLeft = 0
end
function EP:ProfileEdge(id, dir) return select(3, neighbour(self.db.char, E.PROFILE_BY_ID[id], dir)) == nil end
function EP:ProfilePos(id)
	for i, p in ipairs(orderedProfiles(self.db.char)) do if p.id == id then return i * 10 end end
	return 0
end

function EP:Reposition()
	local db = self.db.char
	local size, spacing = db.size, db.spacing
	mainFrame:SetWidth(size)
	mainFrame:SetHeight(size)
	mainFrame.text:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, size / 2), "THICKOUTLINE")
	mainFrame.text:ClearAllPoints()
	if db.queueDirection == "LEFT" then
		mainFrame.text:SetPoint("LEFT", mainFrame, "RIGHT", spacing, 0)
	else
		mainFrame.text:SetPoint("RIGHT", mainFrame, "LEFT", -spacing, 0)
	end
	mainFrame.aoeText:SetFont("Fonts\\FRIZQT__.TTF", math.max(6, size * 0.25), "OUTLINE")
	mainFrame.aoeText:ClearAllPoints()
	if db.queueDirection == "UP" then
		mainFrame.aoeText:SetPoint("TOP", mainFrame, "BOTTOM", 0, -spacing)
	else
		mainFrame.aoeText:SetPoint("BOTTOM", mainFrame, "TOP", 0, spacing)
	end
	local half = size / 2
	for _, k in ipairs({ "wolf", "elemental", "interrupt", "purge", "gloves", "racial" }) do
		local fr = mainFrame[k]
		fr:SetWidth(half)
		fr:SetHeight(half)
		fr:ClearAllPoints()
	end
	for _, k in ipairs({ "gloves", "racial", "wolf", "elemental" }) do
		mainFrame[k].countText:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, half / 2), "OUTLINE")
	end
	mainFrame.racial:SetPoint("BOTTOMLEFT", mainFrame.wolf, "TOPLEFT", 0, spacing)
	mainFrame.gloves:SetPoint("BOTTOMLEFT", mainFrame.racial, "TOPLEFT", 0, spacing)
	mainFrame.wolf:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", spacing, 0)
	mainFrame.elemental:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", spacing, 0)
	mainFrame.interrupt:SetPoint("TOPLEFT", mainFrame.wolf, "TOPRIGHT", spacing, 0)
	mainFrame.purge:SetPoint("BOTTOMLEFT", mainFrame.elemental, "BOTTOMRIGHT", spacing, 0)
	for i = 1, MAX_QUEUE do
		local f = queueFrames[i]
		local s = i == 1 and size or size * 0.8
		f:SetWidth(s)
		f:SetHeight(s)
		f.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", math.max(8, size / 3), "OUTLINE")
		f:ClearAllPoints()
		if i == 1 then
			f:SetPoint("CENTER", mainFrame, "CENTER")
		elseif db.queueDirection == "RIGHT" then
			f:SetPoint("LEFT", queueFrames[i - 1], "RIGHT", spacing, 0)
		elseif db.queueDirection == "UP" then
			f:SetPoint("BOTTOM", queueFrames[i - 1], "TOP", 0, spacing)
		elseif db.queueDirection == "LEFT" then
			f:SetPoint("RIGHT", queueFrames[i - 1], "LEFT", -spacing, 0)
		else
			f:SetPoint("TOP", queueFrames[i - 1], "BOTTOM", 0, -spacing)
		end
	end
	if skinGroup then
		skinGroup:Skin(db.bf.SkinID or "Blizzard", db.bf.Gloss, db.bf.Backdrop, db.bf.Colors)
	end
	timeLeft = 0
end

function EP:SkinCallback(skinID, gloss, backdrop, _, _, colors)
	self.db.char.bf.SkinID, self.db.char.bf.Gloss, self.db.char.bf.Backdrop, self.db.char.bf.Colors =
		skinID, gloss, backdrop, colors
end

function EP:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("EnhaPrioDB", defaults, "char")
	if (self.db.char.settingsRev or 0) < 1 then
		self.db.char.lavaBurst = true
		self.db.char.srManaPercent = 20
		self.db.char.settingsRev = 1
	end
	if (self.db.char.settingsRev or 0) < 2 then
		self.db.char.profile = self.db.char.aoe and "AOE" or (self.db.char.lavaBurst and "ST" or "ST_NOLVB")
		self.db.char.settingsRev = 2
	end
	LibStub("AceConfig-3.0"):RegisterOptionsTable("EnhaPrio Rebuffed", self:GetOptions())
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("EnhaPrio Rebuffed", "EnhaPrio Rebuffed")

	mainFrame = CreateFrame("Frame", "EnhaPrioRebuffedFrame", UIParent)
	mainFrame:SetFrameStrata("BACKGROUND")
	mainFrame:EnableMouse(true)
	mainFrame:SetMovable(true)
	mainFrame:SetClampedToScreen(true)
	mainFrame:SetScript("OnMouseDown", function(frame, button)
		if button == "RightButton" then
			EP:CycleProfile()
		elseif not EP.db.char.locked then
			frame:StartMoving()
		end
	end)
	mainFrame:SetScript("OnMouseUp", function(frame)
		frame:StopMovingOrSizing()
		EP:SaveLocation()
	end)
	mainFrame:SetScript("OnEnter", function()
		EP.hovering = true
	end)
	mainFrame:SetScript("OnLeave", function()
		EP.hovering = nil
	end)
	mainFrame:ClearAllPoints()
	mainFrame:SetPoint(self.db.char.relativePoint, self.db.char.x, self.db.char.y)
	mainFrame.grip = makeGrip(mainFrame, function() return EP.db.char.size end, function(v0, d)
		local size = clamp(math.floor(v0 + d / 2 + 0.5), 16, 200)
		if size ~= EP.db.char.size then
			EP.db.char.size = size
			EP:Reposition()
		end
	end, function() EP:SaveLocation() end)

	queueFrames = {}
	for i = MAX_QUEUE, 1, -1 do
		local f = CreateFrame("Button", "EnhaPrioRebuffedButton" .. i, mainFrame)
		f:SetFrameStrata("BACKGROUND")
		f:EnableMouse(false)
		f.spellTexture = f:CreateTexture(nil, "BACKGROUND")
		f.spellTexture:SetAllPoints(f)
		f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
		f.cooldown:SetAllPoints(f)
		f.cooldownText = f:CreateFontString(nil, "OVERLAY")
		f.cooldownText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
		f.cooldownText:SetAllPoints()
		f.cooldownText:SetTextColor(1, 1, 1, 1)
		queueFrames[i] = f
		if skinGroup then skinGroup:AddButton(f, { Icon = f.spellTexture, Cooldown = f.cooldown }) end
	end
	local function useFrame(name)
		local u = newSmallFrame(name)
		u.cooldown = CreateFrame("Cooldown", nil, u, "CooldownFrameTemplate")
		u.cooldown:SetAllPoints(u.texture)
		u.cooldown.noCooldownCount = true
		u.countText = u:CreateFontString(nil, "OVERLAY")
		u.countText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
		u.countText:SetPoint("CENTER", u, "CENTER", 0, 0)
		u.countText:SetTextColor(1, 1, 1, 1)
		return u
	end
	mainFrame.wolf = useFrame("EnhaPrioRebuffedFeralSpirit")
	mainFrame.elemental = useFrame("EnhaPrioRebuffedFireElemental")
	mainFrame.interrupt = newSmallFrame("EnhaPrioRebuffedInterrupt")
	mainFrame.purge = newSmallFrame("EnhaPrioRebuffedPurge")
	mainFrame.gloves = useFrame("EnhaPrioRebuffedGloves")
	mainFrame.racial = useFrame("EnhaPrioRebuffedRacial")
	if skinGroup then
		for _, k in ipairs({ "interrupt", "purge" }) do
			skinGroup:AddButton(mainFrame[k], { Icon = mainFrame[k].texture })
		end
		for _, k in ipairs({ "wolf", "elemental", "gloves", "racial" }) do
			skinGroup:AddButton(mainFrame[k], { Icon = mainFrame[k].texture, Cooldown = mainFrame[k].cooldown })
		end
	end
	mainFrame.text = mainFrame:CreateFontString(nil, "OVERLAY")
	mainFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 24, "THICKOUTLINE")
	mainFrame.aoeText = mainFrame:CreateFontString(nil, "OVERLAY")
	mainFrame.aoeText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	mainFrame.aoeText:SetTextColor(1, 0, 0, 1)
	ns.mainFrame, ns.queueFrames = mainFrame, queueFrames
end

function EP:OnEnable()
	local _, class = UnitClass("player")
	if class ~= "SHAMAN" then
		mainFrame:Hide()
		return
	end
	self:RegisterEvent("PLAYER_TARGET_CHANGED", function() timeLeft = 0 end)
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "OnCooldownUpdate")
	mainFrame:SetScript("OnUpdate", function(_, elapsed)
		timeLeft = timeLeft - elapsed
		if timeLeft <= 0 then
			timeLeft = EP.db.char.updateFrequency
			EP:Recalculate()
		end
	end)
	if LBF then LBF:RegisterSkinCallback("EnhaPrio Rebuffed", self.SkinCallback, self) end
	self:RegisterChatCommand("epr", "SlashCommand")
	self:RegisterChatCommand("enhaprio-rebuffed", "SlashCommand")
	self:Reposition()
end

function EP:OnCooldownUpdate()
	timeLeft = 0
end

function EP:SlashCommand(input)
	if (input or ""):lower():match("^%s*debug") then
		self.debugOn = not self.debugOn
		self.debugLast = nil
		if self.debugOn then
			self.db.char.debugLog = self.db.char.debugLog or {}
			local log = self.db.char.debugLog
			log[#log + 1] = ("%.2f;START;%s"):format(GetTime(), date and date("%Y-%m-%d %H:%M:%S") or "")
		end
		DEFAULT_CHAT_FRAME:AddMessage(("EnhaPrio debug %s (%d lines saved; they reach the file at /reload)"):format(
			self.debugOn and "ON" or "OFF", #(self.db.char.debugLog or {})))
		return
	end
	self:OpenOptions()
end

local DEBUG_MAX = 3000
local function left(t, now) return math.max(0, (t or 0) - now) end
function EP:DebugRecord(now, st, entries, prof)
	local q = {}
	for i = 1, 4 do
		local e = entries[i]
		q[#q + 1] = ("q%d=%s"):format(i, e and (e.key .. "@" .. ("%.1f"):format(left(e.at, now))) or "-")
	end
	local cd = {}
	for _, k in ipairs({ "SS", "SHOCK", "FN", "LVB", "LL", "CL" }) do cd[#cd + 1] = ("%s%.1f"):format(k, left(st.cdReady[k], now)) end
	local body = ("prof=%s;%s;mw=%d;ls=%d/%d;fs=%.1f;ss=%.1f/%d;fire=%.1f;fe=%.1f;gcd=%.1f;cd=%s;totems=%s;surge=%.1f;cast=%s"):format(
		prof, table.concat(q, ","), st.mw, st.lsCharges, st.lsMax, left(st.fsExp, now), left(st.ssExp, now), st.ssCharges or 0,
		left(st.fireTotemExp, now), left(st.feExp, now), left(st.gcdEnd, now), table.concat(cd, ","),
		tostring(st.totemsMissing), left(st.surgeExp, now), tostring(UnitCastingInfo("player") or UnitChannelInfo("player") or "-"))
	local sig = body:gsub("(%d+)%.(%d)", function(a, b) return a .. (tonumber(b) >= 5 and "5" or "0") end)
	if sig == self.debugLast then return end
	self.debugLast = sig
	local log = self.db.char.debugLog
	log[#log + 1] = ("%.2f;%s"):format(now, body)
	while #log > DEBUG_MAX do table.remove(log, 1) end
end

function EP:OpenOptions()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

function EP:GetProperty(info) return self.db.char[info[#info]] end

function EP:SetProperty(info, value)
	self.db.char[info[#info]] = value
	if info[#info] == "profile" then self.labelUntil = GetTime() + LABEL_SECONDS end
	if info[#info] == "build" then
		self.db.char.profile = currentProfile(self.db.char).id
		self.labelUntil = GetTime() + LABEL_SECONDS
		timeLeft = 0
	end
	self:Reposition()
end

function EP:GetOptions()
	local function opt(t) t.get, t.set = "GetProperty", "SetProperty"; return t end
	return {
		name = "EnhaPrio Rebuffed",
		handler = EP,
		type = "group",
		args = {
			build = opt({ type = "select", order = 1, name = "Weapon imbues",
				desc = "Which imbues the reminder asks for, and which profiles exist: Spell -> +LB, NoFN, -LB, 4MSW, 5MSW, AOE; "
					.. "Windfury -> WF and WF AOE (searched for the Windfury build). Changing it switches to that build's "
					.. "first profile.",
				values = { SPELL = "Spell: Flametongue on both weapons", WINDFURY = "Windfury main hand, Flametongue off hand" },
				style = "dropdown" }),
			profile = { type = "select", order = 2, name = "Profile", style = "dropdown", width = "double",
				get = "GetProfileChoice", set = "SetProfileChoice",
				desc = "The priority list in use. A right-click on the main icon switches to the next profile ticked "
					.. "below; the label under the icon names it. +LB: single target with hardcast Lava Burst. NoFN: as +LB, but no Fire Nova while the Fire Elemental "
					.. "Totem stands (for a boss out of its range). -LB: "
					.. "without hardcast Lava Burst (instant Lava Burst from Lava Surge stays). 4MSW: as -LB, but Lightning "
					.. "Bolt hardcast only from 4 Maelstrom on. 5MSW: as -LB, but Lightning Bolt only at 5 Maelstrom, so no cast at all; for fights with a strong cast-time slow. AOE: the list searched for 3 targets, without hardcast Lava Burst. "
					.. "WF / WF AOE (Windfury build only): the lists searched for Windfury main hand, Flametongue off hand.",
				values = "GetProfileValues",
			},
			locked = opt({ type = "toggle", order = 3, name = "Locked" }),
			alwaysShow = opt({ type = "toggle", order = 3.2, name = "Always show",
				desc = "Shows the queue and the profile selector also without a hostile target and out of combat, to place "
					.. "and size them. Off: only with a hostile target." }),
			alwaysShowProfile = opt({ type = "toggle", order = 3.5, name = "Always show profile name",
				desc = "Shows the profile name under the main icon while the display is shown (hostile target, or "
					.. "'Always show'). Off, or with the display hidden: only while the mouse is over the main icon and "
					.. "for 3 s after a switch." }),
			showSelector = opt({ type = "toggle", order = 3.6, name = "Profile selector",
				desc = "A small window with one box per profile ticked below; the current one is green. Left-click a box "
					.. "to switch to it. Drag it by its edge while not locked. Shown together with the display (hostile "
					.. "target, or 'Always show')." }),
			resize = opt({ type = "toggle", order = 3.7, name = "Resize",
				desc = "Shows a size grip in the bottom right corner of the display and of the profile selector while not "
					.. "locked. Drag it to make the window bigger or smaller. The display's size is also 'Icon size' "
					.. "under Layout." }),
			cycle = { type = "group", inline = true, order = 4, name = "Right-click cycles through",
				get = "GetCycle", set = "SetCycle", args = (function()
					local a = {}
					for _, p in ipairs(E.PROFILES) do
						local build, id = p.build, p.id
						local function hidden() return (EP.db.char.build == "WINDFURY" and "WINDFURY" or "SPELL") ~= build end
						a[id] = { type = "toggle", order = function() return EP:ProfilePos(id) end, name = p.name,
							width = "double", get = "GetCycle", set = "SetCycle", hidden = hidden }
						a[id .. "_up"] = { type = "execute", order = function() return EP:ProfilePos(id) + 1 end, name = "Up",
							width = "half", desc = "Earlier in the cycle, the Profile list and the selector.", hidden = hidden,
							func = function() EP:MoveProfile(id, -1) end,
							disabled = function() return EP:ProfileEdge(id, -1) end }
						a[id .. "_down"] = { type = "execute", order = function() return EP:ProfilePos(id) + 2 end,
							name = "Down", width = "half", desc = "Later in the cycle, the Profile list and the selector.",
							hidden = hidden, func = function() EP:MoveProfile(id, 1) end,
							disabled = function() return EP:ProfileEdge(id, 1) end }
					end
					return a
				end)() },
			layout = { type = "group", inline = true, order = 10, name = "Layout", args = {
				size = opt({ type = "range", order = 1, name = "Icon size", min = 16, max = 200, step = 1 }),
				spacing = opt({ type = "range", order = 2, name = "Icon spacing", min = 0, max = 40, step = 1 }),
				queueDirection = opt({ type = "select", order = 3, name = "Queue direction", style = "dropdown",
					values = { UP = "Up", DOWN = "Down", LEFT = "Left", RIGHT = "Right" } }),
				maxQueue = opt({ type = "range", order = 4, name = "Icons shown", min = 1, max = MAX_QUEUE, step = 1 }),
			} },
			extras = { type = "group", inline = true, order = 20, name = "Extras", args = {
				displayMW = opt({ type = "toggle", order = 1, name = "Maelstrom counter" }),
				displayGCD = opt({ type = "toggle", order = 2, name = "Cooldown swirl on every icon",
					desc = "Each icon's swirl runs until its spell can be pressed: the global cooldown, the spell's own "
						.. "cooldown, or a rule such as Magma Totem waiting for the Fire Elemental to end." }),
				enableLongCD = opt({ type = "toggle", order = 3, name = "Feral Spirit / Fire Elemental icons" }),
				longCdBossOnly = opt({ type = "toggle", order = 4, name = "... only on bosses" }),
				showInterrupt = opt({ type = "toggle", order = 5, name = "Interrupt window",
					desc = "Shows the target's cast; red border when Wind Shear cannot interrupt it right now." }),
				showPurge = opt({ type = "toggle", order = 6, name = "Purge window",
					desc = "Shows a magic buff on the target; red border when Purge cannot be cast right now." }),
				showGloves = opt({ type = "toggle", order = 6.5, name = "Glove use icon",
					desc = "Above the racial icon: grey with a timer for the whole cooldown, a bright glow for 3 s when "
						.. "they are ready, a timer while their effect lasts. Only for gloves with a Use effect." }),
				showRacial = opt({ type = "toggle", order = 6.6, name = "Racial icon",
					desc = "Blood Fury or Berserking, between Feral Spirit and the gloves, shown like the glove icon." }),
				srManaPercent = opt({ type = "range", order = 7, name = "Shamanistic Rage below mana %", min = 5, max = 100, step = 5,
					desc = "Shown when mana drops below this. With 2 or more pieces of Frost Witch's Battlegear (T10: "
						.. "Shamanistic Rage also adds damage) it is shown whenever it is ready." }),
				updateFrequency = opt({ type = "range", order = 8, name = "Update interval (s)", min = 0.05, max = 0.5, step = 0.05 }),
			} },
		},
	}
end
