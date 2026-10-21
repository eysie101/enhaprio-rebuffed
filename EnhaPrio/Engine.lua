--[[ EnhaPrio Rebuffed: decision engine (no frames, testable outside the game).

The priority is a list of rule tokens (EnhaPrioRebuffed.Engine.RULES). nextAction() walks the list at every moment
the global cooldown allows an action and returns the first rule whose condition holds and whose spell is ready;
when nothing is ready it lets time pass (cooldowns and timers are absolute times) until something is. apply()
changes the state the way the cast would, so repeated nextAction/apply calls give the forecast. The forecast assumes
no procs (no new Maelstrom stacks, no crits). ]]

local ADDON, ns = ...
local E = {}
ns.Engine = E

E.ID = {
	LB = 49238, CL = 49271, SS = 17364, LL = 60103, FS = 49233, ES = 49231, FN = 61657, LS = 49281,
	MAG = 58734, SR = 30823, FE = 2894, FSP = 51533, LVB = 60043, MW = 53817, SHEAR = 57994, PURGE = 8012,
	CALL = 66842,
	SPIRITS = 66844,
	SURGE = 8251314,
}

E.DEFAULT_CD = { SS = 8, LL = 6, SHOCK = 6, FN = 10, LVB = 8, CL = 6, FSP = 180, FE = 600, SR = 60 }
E.DEFAULT = { gcd = 1.5, lbCast = 2.5, clCast = 2.0, lvbCast = 2.0, fsDuration = 18, ssDuration = 12, magmaDuration = 20,
	lsMax = 9 }

local function stacksAtLeast(n) return function(st) return st.mw >= n end end

E.RULES = {
	MW5 = { key = "LB", ok = stacksAtLeast(5) },
	MW4 = { key = "LB", ok = stacksAtLeast(4) },
	MW3 = { key = "LB", ok = stacksAtLeast(3) },
	MW2 = { key = "LB", ok = stacksAtLeast(2) },
	FN = { key = "FN", ok = function(st) return st.fireTotemExp > st.now end },
	FNNE = { key = "FN", ok = function(st) return st.fireTotemExp > st.now and st.feExp <= st.now end },
	FS0 = { key = "FS", ok = function(st) return st.fsExp <= st.now end },
	FS1 = { key = "FS", ok = function(st) return st.fsExp - st.now <= 1.5 end },
	SSb = { key = "SS", ok = function(st) return st.ssExp <= st.now end },
	SS = { key = "SS", ok = function() return true end },
	LS0 = { key = "LS", ok = function(st) return st.lsCharges <= 0 end },
	LS2 = { key = "LS", ok = function(st) return st.lsCharges <= 2 end },
	MAG = { key = "MAG", ok = function(st) return st.fireTotemExp <= st.now and st.feExp <= st.now end },
	ES = { key = "ES", ok = function() return true end },
	LL = { key = "LL", ok = function() return true end },
	LVB = { key = "LVB", ok = function(st) return st.fsExp - st.now >= math.max(2, st.lvbCast) end },
	LVBS = { key = "LVB", ok = function(st) return (st.surgeExp or 0) > st.now end, ignoreCd = true },
	MW5CL = { key = "CL", ok = stacksAtLeast(5) },
	MW1CL = { key = "CL", ok = stacksAtLeast(1) },
	CALL = { key = "CALL", ok = function(st) return st.totemsMissing and st.feExp <= st.now end },
	SPIRITS = { key = "SPIRITS", ok = function(st) return st.totemsMissing and st.feExp > st.now end },
}

E.PRIORITY_ST = { "MW5", "MAG", "FS0", "MW4", "LS0", "LVBS", "SSb", "FN", "FS1", "ES", "SS", "LVB", "MW3", "LS2", "MW2", "CALL" }
E.PRIORITY_ST_NO_LVB = { "MW5", "MAG", "FS0", "MW4", "LS0", "LVBS", "FN", "FS1", "ES", "SS", "MW3", "LS2", "MW2", "CALL" }
E.PRIORITY_AOE = { "FN", "MAG", "MW5CL", "FS1", "LS0", "FS0", "SSb", "ES", "SS", "LVB", "LS2", "CALL" }
E.PRIORITY_AOE_NO_LVB = { "FN", "MAG", "MW5CL", "FS1", "LS0", "FS0", "SSb", "ES", "SS", "LS2", "CALL" }

E.PRIORITY_ST_MW4 = {}
for _, t in ipairs(E.PRIORITY_ST_NO_LVB) do
	if t ~= "MW3" and t ~= "MW2" then E.PRIORITY_ST_MW4[#E.PRIORITY_ST_MW4 + 1] = t end
end
E.PRIORITY_ST_MW5 = {}
for _, t in ipairs(E.PRIORITY_ST_NO_LVB) do
	if t ~= "MW4" and t ~= "MW3" and t ~= "MW2" then E.PRIORITY_ST_MW5[#E.PRIORITY_ST_MW5 + 1] = t end
end
E.PRIORITY_WF = { "MW5", "MAG", "FS0", "MW4", "LS0", "FN", "FS1", "ES", "SS", "LVB", "MW2", "LS2", "CALL" }
E.PRIORITY_WF_AOE = { "FN", "MAG", "MW1CL", "MW5CL", "FS1", "LS0", "FS0", "SSb", "MW4", "ES", "SS", "LS2", "MW3", "CALL" }
local function totemsFirst(list)
	local rest = {}
	for _, t in ipairs(list) do if t ~= "CALL" and t ~= "SPIRITS" then rest[#rest + 1] = t end end
	for i = #list, 1, -1 do list[i] = nil end
	list[1], list[2] = "CALL", "SPIRITS"
	for _, t in ipairs(rest) do list[#list + 1] = t end
end
for _, l in ipairs({ E.PRIORITY_ST, E.PRIORITY_ST_NO_LVB, E.PRIORITY_ST_MW4, E.PRIORITY_ST_MW5, E.PRIORITY_AOE,
		E.PRIORITY_AOE_NO_LVB, E.PRIORITY_WF, E.PRIORITY_WF_AOE }) do
	totemsFirst(l)
end
E.PRIORITY_ST_NOFN = {}
for _, t in ipairs(E.PRIORITY_ST) do E.PRIORITY_ST_NOFN[#E.PRIORITY_ST_NOFN + 1] = t == "FN" and "FNNE" or t end
E.PROFILES = {
	{ id = "ST", label = "+LB", name = "+LB", list = E.PRIORITY_ST, build = "SPELL" },
	{ id = "ST_NOFN", label = "NoFN", name = "NoFN", list = E.PRIORITY_ST_NOFN, build = "SPELL" },
	{ id = "ST_NOLVB", label = "-LB", name = "-LB", list = E.PRIORITY_ST_NO_LVB, build = "SPELL" },
	{ id = "ST_MW4", label = "4MSW", name = "4MSW", list = E.PRIORITY_ST_MW4, build = "SPELL" },
	{ id = "ST_MW5", label = "5MSW", name = "5MSW", list = E.PRIORITY_ST_MW5, build = "SPELL" },
	{ id = "AOE", label = "AOE", name = "AOE", list = E.PRIORITY_AOE_NO_LVB, build = "SPELL" },
	{ id = "WF", label = "WF", name = "WF", list = E.PRIORITY_WF, build = "WINDFURY" },
	{ id = "WF_AOE", label = "WF AOE", name = "WF AOE", list = E.PRIORITY_WF_AOE, build = "WINDFURY" },
}
E.PROFILE_BY_ID = {}
for _, p in ipairs(E.PROFILES) do E.PROFILE_BY_ID[p.id] = p end
for _, p in ipairs(E.PROFILES) do
	local has, copy = false, {}
	for i, t in ipairs(p.list) do has = has or t == "LL"; copy[i] = t end
	if p.build == "SPELL" and not has then
		copy[#copy + 1] = "LL"
		p.list = copy
	end
end

local CD_OF = { SS = "SS", LL = "LL", FS = "SHOCK", ES = "SHOCK", FN = "FN", LVB = "LVB", CL = "CL" }

local function ready(st, key)
	local cd = CD_OF[key]
	return not cd or (st.cdReady[cd] or 0) <= st.now + 0.001
end

local function castTime(st, key)
	if key == "CL" then
		if st.mw >= 5 then return 0 end
		return (st.clCast or st.lbCast) * (1 - 0.2 * st.mw)
	elseif key == "LB" then
		if st.mw >= 5 then return 0 end
		return st.lbCast * (1 - 0.2 * st.mw)
	elseif key == "LVB" then
		if (st.surgeExp or 0) > st.now then return 0 end
		return st.lvbCast
	end
	return 0
end
E.castTime = castTime

function E.nextAction(st, prio, limit)
	local start = st.now
	limit = limit or 10
	for _ = 1, 400 do
		if st.now >= st.gcdEnd then
			for _, tok in ipairs(prio) do
				local r = E.RULES[tok]
				if r and r.ok(st) and (r.ignoreCd or ready(st, r.key)) then
					return tok, r.key, st.now - start
				end
			end
		end
		if st.now - start >= limit then return nil end
		local nextT = start + limit
		local function consider(t) if t > st.now + 0.0005 and t < nextT then nextT = t end end
		consider(st.gcdEnd)
		for _, t in pairs(st.cdReady) do consider(t) end
		consider(st.fsExp); consider(st.fsExp - 1.5); consider(st.ssExp); consider(st.fireTotemExp); consider(st.feExp)
		consider(st.surgeExp or 0)
		st.now = math.max(nextT, st.now + 0.01)
	end
	return nil
end

function E.apply(st, tok)
	local r = E.RULES[tok]
	local key = r.key
	local ct = castTime(st, key)
	if key == "LB" or key == "CL" then
		st.mw = 0
		if st.ssExp > st.now then st.ssCharges = st.ssCharges - 1; if st.ssCharges <= 0 then st.ssExp = st.now end end
		if key == "CL" then st.cdReady.CL = st.now + st.cd.CL end
	elseif key == "CALL" then
		st.totemsMissing = false
		st.fireTotemExp = st.now + st.magmaDuration
	elseif key == "SPIRITS" then
		st.totemsMissing = false
	elseif key == "FS" then
		st.fsExp = st.now + ct + st.fsDuration
		st.cdReady.SHOCK = st.now + st.cd.SHOCK
	elseif key == "ES" then
		st.cdReady.SHOCK = st.now + st.cd.SHOCK
		if st.ssExp > st.now then st.ssCharges = st.ssCharges - 1; if st.ssCharges <= 0 then st.ssExp = st.now end end
	elseif key == "SS" then
		st.ssExp = st.now + st.ssDuration
		st.ssCharges = 4
		st.cdReady.SS = st.now + st.cd.SS
	elseif key == "LL" then
		st.cdReady.LL = st.now + st.cd.LL
	elseif key == "FN" then
		st.cdReady.FN = st.now + st.cd.FN
	elseif key == "LS" then
		st.lsCharges = st.lsMax
	elseif key == "MAG" then
		st.fireTotemExp = st.now + st.magmaDuration
	elseif key == "LVB" then
		st.cdReady.LVB = st.now + st.cd.LVB
		st.surgeExp = 0
	end
	st.gcdEnd = st.now + math.max(st.gcd, ct)
	st.casts = (st.casts or 0) + 1
end

function E.copy(st)
	local c = {}
	for k, v in pairs(st) do
		if type(v) == "table" then
			local t = {}
			for k2, v2 in pairs(v) do t[k2] = v2 end
			c[k] = t
		else
			c[k] = v
		end
	end
	return c
end

function E.forecast(st, prio, n)
	local s = E.copy(st)
	local out = {}
	for i = 1, n do
		local tok, key, wait = E.nextAction(s, prio)
		if not tok then break end
		out[i] = { tok = tok, key = key, wait = wait, at = s.now }
		E.apply(s, tok)
	end
	return out
end

function E.readyIn(st, tok, limit)
	local s = E.copy(st)
	local found, _, wait = E.nextAction(s, { tok }, limit or 130)
	if found then return wait end
	return nil
end

local learnedCd, learnedGcd, maxLs, lastLvbCast = {}, nil, nil, nil

local function spellName(key) return (GetSpellInfo(E.ID[key])) end

local function auraById(unit, filter, ids)
	for i = 1, 40 do
		local name, _, _, count, _, _, expires, caster, _, _, spellId
		if filter == "HELPFUL" then
			name, _, _, count, _, _, expires, caster, _, _, spellId = UnitBuff(unit, i)
		else
			name, _, _, count, _, _, expires, caster, _, _, spellId = UnitDebuff(unit, i)
		end
		if not name then break end
		if ids[spellId] and (caster == "player" or caster == nil) then
			return expires or 0, count or 0
		end
	end
	return 0, 0
end

local MW_IDS = { [53817] = true }
local LS_IDS = { [49281] = true, [49280] = true, [25472] = true, [25469] = true }
local FS_IDS = { [49233] = true, [49232] = true, [29228] = true, [25457] = true }
local SS_IDS = { [17364] = true }
local FE_IDS = { [2894] = true }
local SURGE_IDS = { [E.ID.SURGE] = true }

local function spellCooldown(key)
	local name = GetSpellInfo(E.ID[key])
	if not name then return nil end
	return GetSpellCooldown(name)
end
E.spellCooldown = spellCooldown

local function cdReadyAt(key, now, gcdEnd)
	local start, duration = spellCooldown(key)
	if not start then return math.huge end
	if start == 0 or not duration then return now end
	local t = start + duration
	if duration > 1.6 then learnedCd[key] = duration end
	if t <= gcdEnd + 0.01 then return now end
	return t
end

function E.snapshot(now)
	now = now or GetTime()
	local st = { now = now, cdReady = {}, cd = {} }
	local gStart, gDur = spellCooldown("LS")
	st.gcdEnd = (gStart and gStart > 0 and gDur and gDur <= 1.6) and (gStart + gDur) or now
	if gDur and gDur > 0.5 and gDur <= 1.6 then learnedGcd = gDur end
	st.gcd = learnedGcd or E.DEFAULT.gcd
	local mwExp, mw = auraById("player", "HELPFUL", MW_IDS)
	st.mw = mwExp > now and mw or 0
	local _, _, _, _, _, _, lbMs = GetSpellInfo(E.ID.LB)
	local base = (lbMs and lbMs > 0) and lbMs / 1000 / (1 - 0.2 * math.min(st.mw, 4)) or E.DEFAULT.lbCast
	st.lbCast = st.mw >= 5 and E.DEFAULT.lbCast * (st.gcd / 1.5) or base
	local _, _, _, _, _, _, clMs = GetSpellInfo(E.ID.CL)
	local clBase = (clMs and clMs > 0) and clMs / 1000 / (1 - 0.2 * math.min(st.mw, 4)) or E.DEFAULT.clCast
	st.clCast = st.mw >= 5 and E.DEFAULT.clCast * (st.gcd / 1.5) or clBase
	st.surgeExp = auraById("player", "HELPFUL", SURGE_IDS)
	local _, _, _, _, _, _, lvbMs = GetSpellInfo(E.ID.LVB)
	if lvbMs and lvbMs > 0 then lastLvbCast = lvbMs / 1000 end
	st.lvbCast = lastLvbCast or E.DEFAULT.lvbCast * (st.gcd / 1.5)
	local lsExp, ls = auraById("player", "HELPFUL", LS_IDS)
	st.lsCharges = lsExp > now and ls or 0
	if st.lsCharges > (maxLs or 0) then maxLs = st.lsCharges end
	st.lsMax = maxLs or E.DEFAULT.lsMax
	st.fsExp = auraById("target", "HARMFUL", FS_IDS)
	st.ssExp, st.ssCharges = auraById("target", "HARMFUL", SS_IDS)
	if st.ssCharges == 0 and st.ssExp > now then st.ssCharges = 4 end
	st.fireTotemExp, st.feExp = 0, 0
	local have, tName, tStart, tDur, icon = GetTotemInfo(1)
	if have and tName and tName ~= "" and tDur and tDur > 0 and tStart + tDur > now then
		local feIcon = select(3, GetSpellInfo(E.ID.FE))
		if icon == feIcon then st.feExp = tStart + tDur end
		st.fireTotemExp = tStart + tDur
	end
	for _, key in ipairs({ "SS", "LL", "FN", "LVB", "CL", "FSP", "FE", "SR" }) do
		st.cdReady[key] = cdReadyAt(key, now, st.gcdEnd)
	end
	local function slotUp(slot)
		local h, n, s, d = GetTotemInfo(slot)
		return h and n and n ~= "" and d and d > 0 and s + d > now and true or false
	end
	st.totemsMissing = not (slotUp(2) and slotUp(4))
	st.cdReady.SHOCK = cdReadyAt("ES", now, st.gcdEnd)
	for k, v in pairs(E.DEFAULT_CD) do st.cd[k] = learnedCd[k] or v end
	st.cd.SHOCK = learnedCd.ES or E.DEFAULT_CD.SHOCK
	st.fsDuration, st.ssDuration, st.magmaDuration = E.DEFAULT.fsDuration, E.DEFAULT.ssDuration, E.DEFAULT.magmaDuration
	return st
end

function E.resetLearned() learnedCd, learnedGcd, maxLs, lastLvbCast = {}, nil, nil, nil end
