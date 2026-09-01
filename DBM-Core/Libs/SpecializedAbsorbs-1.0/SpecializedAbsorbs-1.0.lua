local MAJOR, MINOR = "SpecializedAbsorbs-1.0", 5
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end
local Core

local error = error
local pairs, select = pairs, select
local min, max, floor = math.min, math.max, math.floor
local setmetatable, getmetatable = setmetatable, getmetatable
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local UnitBuff, UnitHealthMax, UnitAttackPower = UnitBuff, UnitHealthMax, UnitAttackPower
local UnitExists, UnitGUID, UnitClass, UnitLevel = UnitExists, UnitGUID, UnitClass, UnitLevel
local UnitFactionGroup, UnitInBattleground, GetTalentInfo = UnitFactionGroup, UnitInBattleground, GetTalentInfo
local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers

lib.CheckFlags = lib.CheckFlags or true
lib.NoErrors = lib.NoErrors or true

if oldminor then
	Core = lib.Core
	if lib.Enabled then
		Core.Disable()
	end
else
	lib.Core = {callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(lib), Events = {}}
	Core = lib.Core

	local frame = CreateFrame("Frame", "SpecializedAbsorbs_Events")
	local events = Core.Events
	frame:SetScript("OnEvent", function(self, event, ...) events[event](...) end)
	Core.Frame = frame
	LibStub("AceComm-3.0"):Embed(Core)
	LibStub("AceTimer-3.0"):Embed(Core)
	LibStub("AceSerializer-3.0"):Embed(Core)
end

local callbacks = Core.callbacks
local Events = Core.Events

local playerid, playerclass

local curChatChannel = nil

local groupCount = 0

local lastCombatLogEvent = 0.0

local activeEffectsBySpell

local activeEffectsByPriority

local activeAreaEffects

local activeCharges

local Effects

local AreaTriggers

local CombatTriggersOnHeal
local CombatTriggersOnHealCrit
local CombatTriggersOnAuraApplied
local CombatTriggersOnAuraRemoved

local UnitStatsTable

local Scaling
local privateScaling
local playerScaling

local GUIDtoAbsorbHealSpells

local OnEnableClass = {}
local OnScalingDecode = setmetatable({}, {__index = function(table, class) return table.DEFAULT end})

local ApplySingularEffect
local ApplyAreaEffect
local CreateAreaTrigger
local HitUnit
local RemoveActiveEffect

local LOW_VALUE_TOLERANCE = 50
local ZONE_MODIFIER = 1

local COMM_UNITSTATS = "SpecializedAbsorbs_UnitStats"
local COMM_SCALING = "SpecializedAbsorbs_Scaling"

local COMM_UNITSTATS_ALT = "Absorbs_UnitStats"
local COMM_SCALING_ALT = "Absorbs_Scaling"

local CommStatsCooldown = false
local function ClearCommStatsCooldown()
	CommStatsCooldown = false
end

local CommScalingCooldown = false
local function ClearCommScalingCooldown()
	CommScalingCooldown = false
end

local function DeepTableCopy(src)
	local res = {}

	for k, v in pairs(src) do
		if type(k) == "table" then
			k = DeepTableCopy(k)
		end
		if type(v) == "table" then
			v = DeepTableCopy(v)
		end
		res[k] = v
	end
	setmetatable(res, getmetatable(src))
	return res
end

local function NoOp() end

local SortEffects
do
	local mage_fire_ward = {543, 8457, 8458, 10223, 10225, 27128, 43010}
	local mage_frost_ward = {6143, 8461, 8462, 10177, 28609, 32796, 43012}
	local mage_ice_barrier = {11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039}
	local warlock_shadow_ward = {6229, 11739, 11740, 28610, 47890, 47891}
	local warlock_sacrifice = {7812, 19438, 19440, 19441, 19442, 19443, 27273, 47985, 47986}

	function SortEffects(a, b)

		if a[1] == b[1] then
			if a[8] == nil then
				return true
			elseif b[8] == nil then
				return false
			else
				return (a[8] < b[8])
			end
		end

		if a[1] == 65686 then
			return true
		end
		if b[1] == 65686 then
			return false
		end
		if a[1] == 65684 then
			return true
		end
		if b[1] == 65684 then
			return false
		end

		if tContains(mage_frost_ward, a[1]) then
			return true
		end
		if tContains(mage_frost_ward, b[1]) then
			return false
		end

		if tContains(mage_fire_ward, a[1]) then
			return true
		end
		if tContains(mage_fire_ward, b[1]) then
			return false
		end

		if tContains(warlock_shadow_ward, a[1]) then
			return true
		end
		if tContains(warlock_shadow_ward, b[1]) then
			return false
		end

		if a[1] == 58597 then
			return true
		end
		if b[1] == 58597 then
			return false
		end

		if a[1] == 58597 then
			return true
		end
		if b[1] == 58597 then
			return false
		end

		if a[1] == 47753 then
			return true
		end
		if b[1] == 47753 then
			return false
		end

		if tContains(mage_ice_barrier, a[1]) then
			return true
		end
		if tContains(mage_ice_barrier, b[1]) then
			return false
		end

		if tContains(warlock_sacrifice, a[1]) then
			return true
		end
		if tContains(warlock_sacrifice, b[1]) then
			return false
		end

		return (a[7] < b[7])
	end
end

local function GetUnitId(guid, name)
	if name and UnitGUID(name) then
		return name
	end
	if UnitGUID("target") == guid then
		return "target"
	end
	if UnitGUID("focus") == guid then
		return "focus"
	end

	local prefix
	if curChatChannel == "BATTLEGROUND" or curChatChannel == "RAID" then
		prefix = "raid"
	elseif curChatChannel == "PARTY" then
		prefix = "party"
	end

	if prefix then
		for i = 1, groupCount do
			local unit = (i == 0) and "player" or prefix .. i
			if UnitExists(unit) then
				if UnitGUID(unit) == guid then
					return unit
				end
				if UnitExists(unit .. "pet") and UnitGUID(unit .. "pet") == guid then
					return unit .. "pet"
				end
			end
		end
	end

	if UnitGUID("player") == guid then
		return "player"
	end
	if UnitExists("playerpet") and UnitGUID("playerpet") == guid then
		return "playerpet"
	end
end

local function UnitDispatch(func, guid, name)
	local result = func(name)
	if not result then
		local unit = GetUnitId(guid, name)
		if unit then
			result = func(unit)
		end
	end
	return result
end

function Core.Error(...)
	if lib.NoErrors then return end
	error(...)
end

function Core.Enable()
	playerclass = select(2, UnitClass("player"))
	playerid = UnitGUID("player")

	Core.activeEffects = {bySpell = {}, byPriority = {}, Area = {}}

	activeEffectsBySpell = Core.activeEffects.bySpell
	activeEffectsByPriority = Core.activeEffects.byPriority
	activeAreaEffects = Core.activeEffects.Area

	Core.activeCharges = {}
	activeCharges = Core.activeCharges

	Effects = Core.Effects
	AreaTriggers = Core.AreaTriggers

	CombatTriggersOnHeal = Core.CombatTriggers.OnHeal
	CombatTriggersOnHealCrit = Core.CombatTriggers.OnHealCrit
	CombatTriggersOnAuraApplied = Core.CombatTriggers.OnAuraApplied
	CombatTriggersOnAuraRemoved = Core.CombatTriggers.OnAuraRemoved

	Core.UnitStatsTable = {[playerid] = {playerclass, 0, 0, 1.0}}
	UnitStatsTable = Core.UnitStatsTable

	Core.Scaling = {[-1] = {}, [playerid] = {}}
	Scaling = Core.Scaling

	playerScaling = Scaling[playerid]
	privateScaling = Scaling[-1]

	Core.GUIDtoAbsorbHealSpells = {}
	GUIDtoAbsorbHealSpells = Core.GUIDtoAbsorbHealSpells

	Core.RegisterEvent("ZONE_CHANGED_NEW_AREA")
	Events.ZONE_CHANGED_NEW_AREA()

	if playerclass == "DEATHKNIGHT" then
		Core.RegisterEvent("UNIT_ATTACK_POWER")
	elseif playerclass == "DRUID" then
		Core.RegisterEvent("UNIT_ATTACK_POWER")
	elseif playerclass == "MAGE" then
		Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
	elseif playerclass == "PALADIN" then
		Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
	elseif playerclass == "PRIEST" then
		Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
	elseif playerclass == "WARLOCK" then
		Core.RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
	end

	Events.STATS_CHANGED()

	if not Core.Silent then
		Core.SetVerbose()
	end

	if OnEnableClass[playerclass] then
		OnEnableClass[playerclass]()
	end

	if Events.PLAYER_LEVEL_UP then
		Core.RegisterEvent("PLAYER_LEVEL_UP")
	end

	if Events.PLAYER_TALENT_UPDATE then
		Core.RegisterEvent("PLAYER_TALENT_UPDATE")
	end

	if Events.GLYPH_UPDATED then
		Core.RegisterEvent("GLYPH_UPDATED")
	end

	if Events.PLAYER_EQUIPMENT_CHANGED then
		Core.RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	end

	Core:ScheduleRepeatingTimer(Events.OnPeriodicBroadcast, 300)

	Core:RegisterComm(COMM_UNITSTATS, Events.OnUnitStatsReceived)
	Core:RegisterComm(COMM_UNITSTATS_ALT, Events.OnUnitStatsReceived)

	Core:RegisterComm(COMM_SCALING, Events.OnScalingReceived)
	Core:RegisterComm(COMM_SCALING_ALT, Events.OnScalingReceived)

	if not lib.Passive then
		Core:SetActive()
	end

	lib.Enabled = true
end

function Core.Disable()
	for guid, effects in pairs(activeEffectsBySpell) do
		callbacks:Fire("UnitCleared", guid)
	end

	wipe(Core.activeEffects)
	wipe(Core.activeCharges)

	wipe(Core.Effects)
	wipe(Core.CombatTriggers)
	wipe(Core.AreaTriggers)

	wipe(Core.UnitStatsTable)
	wipe(Core.Scaling)

	wipe(Core.GUIDtoAbsorbHealSpells)

	wipe(Core.Events)
	Core.Frame:UnregisterAllEvents()

	Core:UnregisterAllComm()
	Core:CancelAllTimers()

	lib.Enabled = false

	collectgarbage("collect")
end

function Core.RegisterEvent(name)
	Core.Frame:RegisterEvent(name)
end

function Core.UnregisterEvent(name)
	Core.Frame:UnregisterEvent(name)
end

local Debug = false
function Core.Debug(str)
	if not Debug then return end
	Core.Print(str)
end

function Core.Print(str)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AbsMon|r: " .. str)
end

function Core.ApplySingularEffect(timestamp, srcGUID, srcName, dstGUID, dstName, spellid, spellschool)
	local destEffects = activeEffectsBySpell[dstGUID]
	local effectInfo = Effects[spellid]
	local effectEntry

	local value, quality = effectInfo[3](srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	if value == nil then return end

	if not destEffects then

		effectEntry = {spellid, effectInfo[1], value, value, quality, 0, timestamp}
		destEffects = {[-1] = 0, [-2] = 1.0, [spellid] = effectEntry}
		activeEffectsBySpell[dstGUID] = destEffects
		activeEffectsByPriority[dstGUID] = {effectEntry}
		callbacks:Fire("EffectApplied", srcGUID, srcName, dstGUID, dstName, spellid, spellschool, value, quality, effectInfo[2])
	elseif not destEffects[spellid] then

		effectEntry = {spellid, effectInfo[1], value, value, quality, 0, timestamp}
		destEffects[spellid] = effectEntry
		tinsert(activeEffectsByPriority[dstGUID], effectEntry)
		tsort(activeEffectsByPriority[dstGUID], SortEffects)
		callbacks:Fire("EffectApplied", srcGUID, srcName, dstGUID, dstName, spellid, spellschool, value, quality, effectInfo[2])
	else
		effectEntry = destEffects[spellid]
		local prevAmount = effectEntry[3]

		effectEntry[3] = value
		effectEntry[4] = value
		effectEntry[5] = quality
		effectEntry[7] = timestamp

		tsort(activeEffectsByPriority[dstGUID], SortEffects)
		callbacks:Fire("EffectUpdated", dstGUID, spellid, value, quality, effectInfo[2])

		value = value - prevAmount

		Core:CancelTimer(effectEntry[6], true)
	end

	if quality < destEffects[-2] then
		destEffects[-2] = quality
	end

	if effectInfo[1] < 2 then
		destEffects[-1] = destEffects[-1] + value
		callbacks:Fire("UnitUpdated", dstGUID, destEffects[-1], destEffects[-2])
	end

	if effectInfo[2] then

		effectEntry[6] = Core:ScheduleTimer(Events.OnSingularTimeout, effectInfo[2] + 5, {dstGUID, spellid})
	else
		effectEntry[6] = Core:ScheduleRepeatingTimer(Events.OnSingularActivityCheck, 8, {dstGUID, spellid})
	end
end

function Core.ApplyAreaEffect(timestamp, triggerGUID, triggerName, dstGUID, dstName, spellid, spellschool)
	if not activeAreaEffects[triggerGUID] then
		return ApplySingularEffect(timestamp, triggerGUID, triggerName, dstGUID, dstName, 0, spellschool)
	end

	local effectEntry = activeAreaEffects[triggerGUID]
	local destEffects = activeEffectsBySpell[dstGUID]

	if not destEffects then

		destEffects = {[-1] = 0, [-2] = 1.1}

		activeEffectsBySpell[dstGUID] = destEffects
		activeEffectsByPriority[dstGUID] = {}
	elseif destEffects[spellid] then
		Core.Error("Called ApplyAreaEffect on refreshed aura")
		return
	end

	destEffects[spellid] = effectEntry
	effectEntry[9] = effectEntry[9] + 1

	if triggerGUID ~= dstGUID then
		tinsert(activeEffectsByPriority[dstGUID], effectEntry)
		tsort(activeEffectsByPriority[dstGUID], SortEffects)

		callbacks:Fire("EffectApplied", triggerGUID, triggerName, dstGUID, dstName, spellid, spellschool, -1, effectEntry[5], nil)

		if effectEntry[5] < destEffects[-2] then
			destEffects[-2] = effectEntry[5]
			callbacks:Fire("UnitUpdated", dstGUID, destEffects[-1], destEffects[-2])
		end
	end
end

function Core.CreateAreaTrigger(timestamp, srcGUID, srcName, triggerGUID, triggerName, spellid, spellschool)
	if activeAreaEffects[triggerGUID] then
		Core.Error("Trying to create new area trigger on existing one, triggerGUID: " .. triggerGUID .. ", existing spellid: " .. activeAreaEffects[triggerGUID][1])
		return
	end

	local effectInfo = Effects[spellid]
	local value, quality = effectInfo[3](srcGUID, srcName, triggerGUID, triggerName, spellid, nil)
	if value == nil then return end

	local effectEntry = {spellid, -1 * effectInfo[1], value, value, quality, 0, timestamp, triggerGUID, 0}
	effectEntry[6] = Core:ScheduleTimer(Events.OnAreaTimeout, effectInfo[2] + 5, effectEntry)
	activeAreaEffects[triggerGUID] = effectEntry
	callbacks:Fire("AreaCreated", srcGUID, srcName, triggerGUID, spellid, spellschool, value, quality)
end

local Fire = callbacks.Fire
function Core.HitUnit(guid, absorbedTotal, overkill, spellschool)
	local guidEffects = activeEffectsBySpell[guid]
	if not guidEffects then return end

	local absorbedRemaining = absorbedTotal

	local absorbed = 0
	local keepEffect, visibleAbsorb = false, false
	local i = 1
	local effectEntry

	while absorbedRemaining > 0 do
		effectEntry = activeEffectsByPriority[guid][i]

		if effectEntry == nil then break end

		if effectEntry[3] ~= 0 then

			absorbed, keepEffect = Effects[effectEntry[1]][4](effectEntry, absorbedRemaining, overkill, spellschool)

			if absorbed > 0 then

				effectEntry[3] = effectEntry[3] - absorbed
				absorbedRemaining = absorbedRemaining - absorbed

				if effectEntry[8] then
					Fire(callbacks, "AreaUpdated", effectEntry[8], effectEntry[3])
				else

					if effectEntry[2] < 2 then
						guidEffects[-1] = guidEffects[-1] - absorbed

						visibleAbsorb = true
					end

					Fire(callbacks, "EffectUpdated", guid, effectEntry[1], effectEntry[3])
				end
			end

			if not keepEffect then
				effectEntry[3] = 0
			end
		end

		i = i + 1
	end

	if absorbedRemaining > LOW_VALUE_TOLERANCE then
		guidEffects[-1] = guidEffects[-1] - absorbedRemaining
		guidEffects[-2] = 0.0
		visibleAbsorb = true
	end

	if visibleAbsorb then
		Fire(Core, "UnitUpdated", guid, guidEffects[-1], guidEffects[-2])
		Fire(Core, "UnitAbsorbed", guid, absorbedTotal)
	end
end

function Core.RemoveActiveEffect(guid, spellid)
	local guidEffects = activeEffectsBySpell and activeEffectsBySpell[guid]
	if not guidEffects then return end

	local effectEntry = guidEffects[spellid]

	if effectEntry[8] then
		effectEntry[9] = effectEntry[9] - 1

		if guid ~= effectEntry[8] then
			callbacks:Fire("EffectRemoved", guid, spellid)
		end

		if effectEntry[9] == 0 then
			if effectEntry[6] then
				Core:CancelTimer(effectEntry[6], true)
			end
			callbacks:Fire("AreaCleared", effectEntry[8])
		end
	else
		if effectEntry[2] < 2 then
			guidEffects[-1] = guidEffects[-1] - effectEntry[3]
			callbacks:Fire("UnitUpdated", guid, guidEffects[-1], guidEffects[-2])
		end

		Core:CancelTimer(effectEntry[6], true)
		callbacks:Fire("EffectRemoved", guid, spellid)
	end

	if #(activeEffectsByPriority[guid]) == 1 then
		activeEffectsBySpell[guid] = nil
		activeEffectsByPriority[guid] = nil
		callbacks:Fire("UnitCleared", guid)
	else
		guidEffects[spellid] = nil
		for k, v in pairs(activeEffectsByPriority[guid]) do
			if v[1] == spellid then
				tremove(activeEffectsByPriority[guid], k)
				break
			end
		end
		tsort(activeEffectsByPriority[guid], SortEffects)
	end
end

function Core.PushCharge(guid, spellid, amount, lifetime)
	local guidCharges = activeCharges[guid]

	if not guidCharges then
		activeCharges[guid] = {[spellid] = {lastCombatLogEvent + lifetime, amount}}
	elseif not guidCharges[spellid] then
		guidCharges[spellid] = {lastCombatLogEvent + lifetime, amount}
	else
		tinsert(guidCharges[spellid], lastCombatLogEvent + lifetime)
		tinsert(guidCharges[spellid], amount)
	end
end

function Core.PopCharge(guid, spellid)
	local guidCharges = activeCharges[guid]

	if guidCharges then
		local queue = guidCharges[spellid]

		if queue and queue[2] then
			local chargeAmount
			local chargeExpire

			while true do

				chargeAmount = tremove(queue, 2)
				if not chargeAmount then return 0 end

				chargeExpire = tremove(queue, 1)
				if chargeExpire > lastCombatLogEvent then
					return chargeAmount
				end
			end
		end
	end
	return 0
end

function Core.AddCombatTrigger(target, event, func)
	local eventTriggers = Core.CombatTriggers[event]
	local oldTrigger = eventTriggers[target]

	if not oldTrigger then
		eventTriggers[target] = func
	else
		local listIndex = target .. "_list"
		local funcList = eventTriggers[listIndex]

		if funcList then

			for k, v in pairs(funcList) do
				if v == func then
					return
				end
			end
			tinsert(funcList, func)
		else
			if oldTrigger == func then
				return
			end

			funcList = {oldTrigger, func}
			eventTriggers[listIndex] = funcList

			local handler = function(...)
				for k, v in pairs(funcList) do
					v(...)
				end
			end

			eventTriggers[target] = handler
		end
	end
end

function Core.RemoveCombatTrigger(target, event, func)
	local eventTriggers = Core.CombatTriggers[event]

	local listIndex = target .. "_list"
	local funcList = eventTriggers[listIndex]

	if (funcList) then

		if (#funcList == 2) then
			eventTriggers[target] = (funcList[1] == func) and funcList[2] or funcList[1]
			eventTriggers[listIndex] = nil
		else

			local old_funcList = DeepTableCopy(funcList)
			wipe(funcList)

			for k, v in pairs(old_funcList) do
				if v ~= func then
					tinsert(funcList, v)
				end
			end
		end
	else
		eventTriggers[target] = nil
	end
end

local lastAP, lastSP = 0, 0
function Core.SendUnitStats()
	if curChatChannel then
		local curAP, curSP = UnitStatsTable[playerid][2], UnitStatsTable[playerid][3]
		if (curAP ~= lastAP) or (curSP ~= lastSP) then
			Core:SendCommMessage(COMM_UNITSTATS, Core:Serialize(playerid, playerclass, curAP, curSP), curChatChannel)
			Core:SendCommMessage(COMM_UNITSTATS_ALT, Core:Serialize(playerid, playerclass, curAP, curSP), curChatChannel)

			lastAP, lastSP = curAP, curSP
			CommStatsCooldown = true
			Core:ScheduleTimer(ClearCommStatsCooldown, 15)
		end
	end
end

function Core.SendScaling()
	if curChatChannel then
		Core:SendCommMessage(COMM_SCALING, Core:Serialize(playerid, playerclass, Events.OnScalingEncode()), curChatChannel)
		Core:SendCommMessage(COMM_SCALING_ALT, Core:Serialize(playerid, playerclass, Events.OnScalingEncode()), curChatChannel)

		CommScalingCooldown = true
		Core:ScheduleTimer(ClearCommStatsCooldown, 30)
	end
end

local activeTimers = {}
function Core:ScheduleUniqueTimer(id, callback, delay, arg)
	if not activeTimers[id] then
		self:ScheduleTimer(function()
			callback(arg)
			activeTimers[id] = nil
		end, delay)
		activeTimers[id] = 1
	end
end

function Core.SetActive()
	Core.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	lib.Passive = false
end

function Core.SetPassive()
	Core.UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	lib.Passive = true
end

function Core.SetVerbose()
	Core.RegisterEvent("PARTY_MEMBERS_CHANGED")
	Core.RegisterEvent("RAID_ROSTER_UPDATE")
	lib.Silent = false
	Events.GROUPING_CHANGED()
end

function Core.SetSilent()
	Core.UnregisterEvent("PARTY_MEMBERS_CHANGED")
	Core.UnregisterEvent("RAID_ROSTER_UPDATE")
	lib.Silent = true
	curChatChannel = nil
end

ApplySingularEffect = Core.ApplySingularEffect
ApplyAreaEffect = Core.ApplyAreaEffect
CreateAreaTrigger = Core.CreateAreaTrigger
HitUnit = Core.HitUnit
RemoveActiveEffect = Core.RemoveActiveEffect

function Events.PLAYER_ENTERING_WORLD()
	if not GetTalentInfo(1, 1) then
		Core.RegisterEvent("PLAYER_ALIVE")
	else
		Core.Available = true
		Core.Enable()
		Core:ScheduleTimer(Events.STATS_CHANGED, 5)
	end
	Core.UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function Events.PLAYER_ALIVE()
	Core.Available = true
	Core.Enable()
	Core.UnregisterEvent("PLAYER_ALIVE")
end

local BITMASK_GROUP = COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID
local function CheckFlags(srcFlags, dstFlags)
	return (srcFlags and bit.band(srcFlags, BITMASK_GROUP) ~= 0) or (dstFlags and bit.band(dstFlags, BITMASK_GROUP) ~= 0)
end

local absorbHealSpells = {
	[66237] = 30000,
	[67049] = 60000,
	[67050] = 40000,
	[67051] = 85000,
	[66236] = 30000,
	[70659] = 9000,
	[71951] = 15000,
	[72490] = 14000,
	[72491] = 14000,
	[72492] = 20000,
}

local environmentSchools = {
	FALLING = SCHOOL_MASK_PHYSICAL,
	DROWNING = SCHOOL_MASK_PHYSICAL,
	FATIGUE = SCHOOL_MASK_PHYSICAL,
	FIRE = SCHOOL_MASK_FIRE,
	LAVA = SCHOOL_MASK_FIRE,
	SLIME = SCHOOL_MASK_NATURE
}

function Events.COMBAT_LOG_EVENT_UNFILTERED(timestamp, etype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	if lib.CheckFlags and not CheckFlags(srcFlags, dstFlags) then return end

	lastCombatLogEvent = timestamp
	if etype == "SWING_DAMAGE" then
		local amount, _, _, _, _, absorbed = ...
		if not absorbed then return end
		HitUnit(dstGUID, absorbed, amount, SCHOOL_MASK_PHYSICAL)
	elseif etype == "RANGE_DAMAGE" or etype == "SPELL_DAMAGE" or etype == "SPELL_PERIODIC_DAMAGE" then
		local _, _, spellschool, amount, _, _, _, _, absorbed = ...
		if not absorbed then return end
		HitUnit(dstGUID, absorbed, amount, spellschool)
	elseif etype == "ENVIRONMENTAL_DAMAGE" then
		local envtype, amount, _, _, _, _, absorbed = ...
		if not absorbed then return end
		HitUnit(dstGUID, absorbed, amount, environmentSchools[envtype] or SCHOOL_MASK_PHYSICAL)
	elseif etype == "SWING_MISSED" then
		local misstype, amount = ...
		if misstype ~= "ABSORB" then return end
		HitUnit(dstGUID, amount, 0, SCHOOL_MASK_PHYSICAL)
	elseif etype == "RANGE_MISSED" or etype == "SPELL_MISSED" or etype == "SPELL_PERIODIC_MISSED" then
		local _, _, spellschool, misstype, amount = ...
		if misstype ~= "ABSORB" then return end
		HitUnit(dstGUID, amount, 0, spellschool)
	elseif etype == "SPELL_HEAL" or etype == "SPELL_PERIODIC_HEAL" then
		local spellid, _, _, amount, overheal, absorbed, critical = ...
		if CombatTriggersOnHeal[srcGUID] then
			CombatTriggersOnHeal[srcGUID](srcGUID, srcName, dstGUID, dstName, spellid, amount, overheal)
		end
		if absorbed and Core.GUIDtoAbsorbHealSpells[dstGUID] then
			Core.GUIDtoAbsorbHealSpells[dstGUID] = Core.GUIDtoAbsorbHealSpells[dstGUID] - absorbed
		end
		if critical and CombatTriggersOnHealCrit[srcGUID] then
			CombatTriggersOnHealCrit[srcGUID](srcGUID, srcName, dstGUID, dstName, spellid, amount, overheal)
		end
	elseif etype == "SPELL_AURA_APPLIED" or etype == "SPELL_AURA_REFRESH" then
		local spellid, _, spellschool = ...
		if Effects[spellid] then
			if Effects[spellid][1] > 0 then
				ApplySingularEffect(timestamp, srcGUID, srcName, dstGUID, dstName, spellid, spellschool)
			else
				ApplyAreaEffect(timestamp, srcGUID, srcName, dstGUID, dstName, spellid, spellschool)
			end
		end
		if CombatTriggersOnAuraApplied[spellid] then
			CombatTriggersOnAuraApplied[spellid](srcGUID, srcName, dstGUID, dstName, spellid)
		end
		if absorbHealSpells[spellid] then
			Core.GUIDtoAbsorbHealSpells[dstGUID] = absorbHealSpells[spellid]
		end
	elseif etype == "SPELL_AURA_REMOVED" then
		local spellid, _, spellschool = ...
		if Effects[spellid] then
			if activeEffectsBySpell[dstGUID] and activeEffectsBySpell[dstGUID][spellid] then
				RemoveActiveEffect(dstGUID, spellid)
			end
		end
		if CombatTriggersOnAuraRemoved[spellid] then
			CombatTriggersOnAuraRemoved[spellid](srcGUID, srcName, dstGUID, dstName, spellid, spellschool)
		end
		if absorbHealSpells[spellid] then
			Core.GUIDtoAbsorbHealSpells[dstGUID] = nil
		end
	elseif etype == "SPELL_SUMMON" then
		local spellid, _, spellschool = ...
		if AreaTriggers[spellid] then
			CreateAreaTrigger(timestamp, srcGUID, srcName, dstGUID, dstName, AreaTriggers[spellid], spellschool)
		end
	end
end

function Events.GROUPING_CHANGED()

	if UnitInBattleground("player") then
		curChatChannel = "BATTLEGROUND"
		groupCount = GetNumRaidMembers()
	elseif GetNumRaidMembers() > 0 then
		curChatChannel = "RAID"
		groupCount = GetNumRaidMembers()
	elseif GetNumPartyMembers() > 0 then
		curChatChannel = "PARTY"
		groupCount = GetNumPartyMembers()
	else
		curChatChannel = nil
		groupCount = 0
	end

	Core:ScheduleTimer(Events.STATS_CHANGED, 5)
	Events.STATS_CHANGED()
end

function Events.ZONE_CHANGED_NEW_AREA()
	if UnitInBattleground("player") then
		ZONE_MODIFIER = 1.17
	elseif IsActiveBattlefieldArena() then
		ZONE_MODIFIER = 0.9
	elseif GetCurrentMapAreaID() == 502 then
		ZONE_MODIFIER = 1.17
	elseif GetCurrentMapAreaID() == 605 then
		ZONE_MODIFIER = (UnitBuff("player", GetSpellInfo(73822)) or UnitBuff("player", GetSpellInfo(73828))) and 1.3 or 1
	else
		ZONE_MODIFIER = 1
	end

	Core:ScheduleTimer(Events.STATS_CHANGED, 5)
end

function Events.STATS_CHANGED()
	local baseAP, plusAP, minusAP = UnitAttackPower("player")

	UnitStatsTable[playerid][2] = baseAP + plusAP - minusAP

	UnitStatsTable[playerid][3] = GetSpellBonusHealing()
	if curChatChannel then
		Core:ScheduleUniqueTimer("comm_stats", Core.SendUnitStats, CommStatsCooldown and 15 or 5)
		Core:ScheduleUniqueTimer("comm_scaling", Core.SendScaling, CommScalingCooldown and 30 or 5)
	end
end

function Events.OnUnitStatsReceived(prefix, text, distribution, target)
	if not text then return end

	local success, guid, class, ap, sp = Core:Deserialize(text)
	if not (success and type(guid) == "string" and type(class) == "string" and type(ap) == "number" and type(sp) == "number") then return end
	if guid == playerid then return end

	if not UnitStatsTable[guid] then
		UnitStatsTable[guid] = {class, ap, sp, 1.0}
	else
		UnitStatsTable[guid][2] = ap
		UnitStatsTable[guid][3] = sp
		UnitStatsTable[guid][4] = 1.0
	end
end

function Events.OnScalingEncode()
	return Scaling[playerid]
end

function OnScalingDecode.DEFAULT(guid, guidScaling)
	Scaling[guid] = guidScaling
end

function Events.OnScalingReceived(prefix, text, distribution, target)
	if not text then return end

	local success, guid, class, inScaling = Core:Deserialize(text)
	if not (success and type(guid) == "string" and type(class) == "string" and type(inScaling) == "table") then return end
	if guid == playerid then return end
	(OnScalingDecode[class])(guid, inScaling)
end

function Events.OnPeriodicBroadcast()
	if not curChatChannel then return end

	local playerStats = UnitStatsTable[playerid]
	local playerScaling = Scaling[playerid]

	if not CommStatsCooldown then
		Core:ScheduleUniqueTimer("comm_stats", Core.SendUnitStats, 5)
	end

	if not CommScalingCooldown then
		Core:ScheduleUniqueTimer("comm_scaling", Core.SendScaling, 5)
	end
end

function Events.OnSingularTimeout(args)
	local guid, spellid = args[1], args[2]
	if activeEffectsBySpell[guid] and activeEffectsBySpell[guid][spellid] then
		RemoveActiveEffect(guid, spellid)
	end
end

function Events.OnSingularActivityCheck(args)
	local guid, spellid = args[1], args[2]

	if activeEffectsBySpell[guid] and activeEffectsBySpell[guid][spellid] then
		local name = select(6, GetPlayerInfoByGUID(guid))

		if not name then
			Core:CancelTimer(activeEffectsBySpell[guid][spellid][6])
			RemoveActiveEffect(guid, spellid)
		end

		local stillActive = false

		for i = 1, 40 do
			local buffId = select(11, UnitBuff(name, i))
			if not buffId then break end
			if buffId == spellid then
				stillActive = true
				break
			end
		end

		if not stillActive then
			Core:CancelTimer(activeEffectsBySpell[guid][spellid][6])
			RemoveActiveEffect(guid, spellid)
		end
	else

		Core:CancelTimer(activeEffectsBySpell[guid][spellid][6])
	end
end

function Events.OnAreaTimeout(areaEntry)

	areaEntry[6] = nil

	for guid, guidEffects in pairs(activeEffectsBySpell) do
		if areaEntry[9] == 0 then return end
		for spellid, effectEntry in pairs(guidEffects) do
			if effectEntry == areaEntry then
				RemoveActiveEffect(guid, spellid)
			end
		end
	end

	Core.Error("Positive refcount " .. areaEntry[9] .. " remained for area effect " .. areaEntry[1] .. " by trigger " .. areaEntry[8])
end

Events.PARTY_MEMBERS_CHANGED = Events.GROUPING_CHANGED
Events.RAID_ROSTER_UPDATE = Events.GROUPING_CHANGED
Events.PLAYER_DAMAGE_DONE_MODS = Events.STATS_CHANGED
Events.UNIT_ATTACK_POWER = Events.STATS_CHANGED

function lib.RegisterEffectCallbacks(self, funcApplied, funcUpdated, funcRemoved)
	lib.RegisterCallback(self, "EffectApplied", funcApplied)
	lib.RegisterCallback(self, "EffectUpdated", funcUpdated or funcApplied)
	lib.RegisterCallback(self, "EffectRemoved", funcRemoved or funcApplied)
end

function lib.RegisterUnitCallbacks(self, funcUpdated, funcCleared)
	lib.RegisterCallback(self, "UnitUpdated", funcUpdated)
	lib.RegisterCallback(self, "UnitCleared", funcCleared or funcUpdated)
end

function lib.RegisterAreaCallbacks(self, funcCreated, funcUpdated, funcCleared)
	lib.RegisterCallback(self, "AreaCreated", funcCreated)
	lib.RegisterCallback(self, "AreaUpdated", funcUpdated or funcCreated)
	lib.RegisterCallback(self, "AreaCleared", funcCleared or funcCreated)
end

function lib.GetLowValueTolerance()
	return LOW_VALUE_TOLERANE
end

function lib.SetLowValueTolerance(value)
	LOW_VALUE_TOLERANCE = tonumber(value)
end

function lib.PrintProfiling()
	if GetCVar("scriptProfile") ~= "1" then
		Core.Print("CPU profiling disabled")
		return
	end

	UpdateAddOnCPUUsage()
	UpdateAddOnMemoryUsage()

	Core.Print("Mem: " .. format("%.3f", GetAddOnMemoryUsage("SpecializedAbsorbs")) .. " kB")
	Core.Print("Time: " .. format("%.3f", GetAddOnCPUUsage("SpecializedAbsorbs")) .. " ms")
	Core.Print("--- critical code paths (all times in ms) ---")

	local funcTable

	funcTable = {
		["ApplySingularEffect"] = ApplySingularEffect,
		["HitUnit"] = HitUnit,
		["RemoveActiveEffect"] = RemoveActiveEffect,
		["OnCombatLogEvent"] = COMBAT_LOG_EVENT_UNFILTERED,
		["SortEffects"] = SortEffects
	}

	local v_type
	local time_self, time_combined, count

	for k, v in pairs(funcTable) do
		v_type = type(v)

		if v_type == "function" then
			time_self, count = GetFunctionCPUUsage(v, false)
			time_combined = GetFunctionCPUUsage(v, true)
			Core.Print(k .. " (#" .. count .. "): " .. format("%.4f", time_self) .. " / " .. format("%.4f", time_combined))
		end
	end
end

function lib.UnitTotal(guid)
	local total = 0
	if activeEffectsBySpell and activeEffectsBySpell[guid] then
		total = activeEffectsBySpell[guid][-1]
	end
	return total
end

function lib.UnitEffect(guid, spellid)
	local guidEffects = activeEffectsBySpell and activeEffectsBySpell[guid]
	if guidEffects and guidEffects[spellid] then
		return guidEffects[spellid][3]
	end
	return 0
end

function lib.UnitStats(guid, missingQuality)
	local guidStats = UnitStatsTable and UnitStatsTable[guid]
	if guidStats then
		return guidStats[2], guidStats[3], guidStats[4]
	end
	return 0, 0, missingQuality
end

function lib.UnitScaling(guid, defaultScaling, defaultQuality)
	local guidScaling = Scaling and Scaling[guid]
	if guidScaling then
		return guidScaling, 1.0
	end
	return defaultScaling, defaultQuality
end

function lib.UnitStatsAndScaling(guid, missingQuality, defaultScaling, defaultQuality)
	local guidStats = UnitStatsTable and UnitStatsTable[guid]
	local guidScaling = Scaling and Scaling[guid]
	if guidStats then
		if guidScaling then
			return guidStats[2], guidStats[3], guidStats[4], guidScaling, 1.0
		end
		return guidStats[2], guidStats[3], guidStats[4], defaultScaling, defaultQuality
	else
		if guidScaling then
			return 0, 0, missingQuality, guidScaling, 1.0
		end
		return 0, 0, missingQuality, defaultScaling, defaultQuality
	end
end

function lib.UnitEffectsMap(guid)
	return activeEffectsBySpell and activeEffectsBySpell[guid]
end

function lib.UnitEffectsList(guid)
	return activeEffectsByPriority and activeEffectsByPriority[guid]
end

function lib.UnitActiveEffect(guid)
	local guidEffects = lib.UnitEffectsList(guid)
	return guidEffects and guidEffects[1]
end

function lib.ScheduleScalingBroadcast()
	if curChatChannel then
		Core:ScheduleUniqueTimer("comm_scaling", Core.SendScaling, CommScalingCooldown and 30 or 5)
	end
end

function lib.UnitTotalHealAbsorbs(guid)
	if GUIDtoAbsorbHealSpells then
		local guidHealAbsorbs = guid and GUIDtoAbsorbHealSpells[guid]
		return guidHealAbsorbs
	end
end

local PushCharge = Core.PushCharge
local PopCharge = Core.PopCharge
local UnitStats = lib.UnitStats
local UnitScaling = lib.UnitScaling
local UnitStatsAndScaling = lib.UnitStatsAndScaling

local function generic_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
end

local function generic_ConstantByTable_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	return Effects[spellid][5][spellid], 1.0
end

local function generic_SpellScalingByTable_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local effectInfo = Effects[spellid]
	local _, sp, quality = UnitStats(srcGUID, 0.1)
	return floor(effectInfo[5][spellid] + (sp * effectInfo[6])), quality
end

local function generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if absorbedRemaining > effectEntry[3] then

		absorbedRemaining = effectEntry[3]
		overkill = 1
	end
	return absorbedRemaining, (overkill == 0)
end

local function Physical_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_PHYSICAL then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function Holy_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_HOLY then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function Fire_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_FIRE then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function Nature_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_NATURE then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function Frost_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_FROST then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function FrostFire_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= (SCHOOL_MASK_FIRE + SCHOOL_MASK_FROST) then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function Shadow_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_SHADOW then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function Arcane_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_ARCANE then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local deathknight_MS_Ranks = {[0] = 0, [1] = 0.08, [2] = 0.16, [3] = 0.25}

local deathknight_defaultScaling = {0}

local function deathknight_AntiMagicShell_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local maxHealth = UnitDispatch(UnitHealthMax, dstGUID, dstName)
	if maxHealth == 0 then
		return 0, 0.0
	end

	local sourceScaling, quality = UnitScaling(srcGUID, deathknight_defaultScaling, 0.5)
	return floor(maxHealth * 0.5), quality, (0.75 + sourceScaling[1])
end

local function deathknight_AntiMagicShell_Hit(effectEntry, absorbedRemaining, overkill, spellschool)

	if spellschool == SCHOOL_MASK_PHYSICAL then
		return 0, true
	end

	local maxAbsorb = floor((absorbedRemaining + overkill) * effectEntry[7])
	if effectEntry[3] < maxAbsorb then
		return effectEntry[3], false
	end
	return maxAbsorb, true
end

local function deathknight_AntiMagicZone_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local ap, _, quality = UnitStats(srcGUID, 0.3)
	return (10000 + 2 * ap), quality
end

local function deathknight_AntiMagicZone_Hit(effectEntry, absorbedRemaining, overkill, spellschool)

	if spellschool == SCHOOL_MASK_PHYSICAL then
		return 0, true
	end

	local maxAbsorb = floor((absorbedRemaining + overkill) * 0.75)

	if effectEntry[3] < maxAbsorb then
		return effectEntry[3], false
	end
	return maxAbsorb, true
end

local function deathknight_WoN_Hit1(effectEntry, absorbedRemaining, overkill, spellschool)
	local maxAbsorb = floor((absorbedRemaining + overkill) * 0.05)
	if effectEntry[3] < maxAbsorb then
		return effectEntry[3], false
	end
	return maxAbsorb, true
end

local function deathknight_WoN_Hit2(effectEntry, absorbedRemaining, overkill, spellschool)
	local maxAbsorb = floor((absorbedRemaining + overkill) * 0.1)
	if effectEntry[3] < maxAbsorb then
		return effectEntry[3], false
	end
	return maxAbsorb, true
end

local function deathknight_WoN_Hit3(effectEntry, absorbedRemaining, overkill, spellschool)
	local maxAbsorb = floor((absorbedRemaining + overkill) * 0.15)
	if effectEntry[3] < maxAbsorb then
		return effectEntry[3], false
	end
	return maxAbsorb, true
end

local function deathknight_OnTalentUpdate()

	local t = select(5, GetTalentInfo(3, 18))
	playerScaling[1] = deathknight_MS_Ranks[t]
	lib.ScheduleScalingBroadcast()
end

function OnEnableClass.DEATHKNIGHT()
	Events.PLAYER_TALENT_UPDATE = deathknight_OnTalentUpdate
	deathknight_OnTalentUpdate()
end

local function druid_SavageDefense_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local ap, _, quality = UnitStats(srcGUID, 0.0)
	return floor(ap * 0.25), quality
end

local function druid_SavageDefense_Hit(effectEntry, absorbedRemaining, overkill, spellschool)

	if spellschool == SCHOOL_MASK_PHYSICAL then
		return min(effectEntry[3], absorbedRemaining), false
	end
	return 0, true
end

local mage_Absorb_Spells = {

	[543] = 165,
	[8457] = 290,
	[8458] = 470,
	[10223] = 675,
	[10225] = 875,
	[27218] = 1125,
	[43010] = 1950,

	[6143] = 165,
	[8461] = 290,
	[8462] = 470,
	[10177] = 675,
	[28609] = 875,
	[32796] = 1125,
	[43012] = 1950,

	[11426] = 438,
	[13031] = 549,
	[13032] = 678,
	[13033] = 818,
	[27134] = 925,
	[33405] = 1075,
	[43038] = 2800,
	[43039] = 3300,

	[1463] = 120,
	[8494] = 210,
	[8495] = 300,
	[10191] = 390,
	[10192] = 480,
	[10193] = 570,
	[27131] = 715,
	[43019] = 1080,
	[43020] = 1330
}

local mage_defaultScaling = {1.0}

local function mage_IceBarrier_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local _, sp, quality1, sourceScaling, quality2 = UnitStatsAndScaling(srcGUID, 0.3, mage_defaultScaling, 0.4)
	return floor((mage_Absorb_Spells[spellid] + (sp * 0.8053)) * sourceScaling[1]), min(quality1, quality2)
end

local function mage_FireWard_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_FIRE then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function mage_FrostWard_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_FROST then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function mage_OnGlyphUpdated()
	local glyphSpellId

	playerScaling[1] = 1.0

	for i = 1, 6 do
		glyphSpellId = select(3, GetGlyphSocketInfo(i))

		if glyphSpellId and glyphSpellId == 63095 then
			playerScaling[1] = 1.3
			break
		end
	end
	lib.ScheduleScalingBroadcast()
end

function OnEnableClass.MAGE()
	Events.GLYPH_UPDATED = mage_OnGlyphUpdated
	mage_OnGlyphUpdated()
end

local paladin_defaultScaling = {1.0}

local function paladin_SacredShield_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local _, sp, quality1, sourceScaling, quality2 = UnitStatsAndScaling(srcGUID, 0.1, paladin_defaultScaling, 0.2)
	return floor((500 + (sp * 0.75)) * (sourceScaling[1] or paladin_defaultScaling[1]) * ZONE_MODIFIER), min(quality1, quality2)
end

local function paladin_OnTalentUpdate()

	if UnitLevel("player") < 80 then return end

	local t = select(5, GetTalentInfo(2, 9))
	playerScaling[1] = 1 + (t * 0.1)
	lib.ScheduleScalingBroadcast()
end

function OnEnableClass.PALADIN()
	Events.PLAYER_TALENT_UPDATE = paladin_OnTalentUpdate
	paladin_OnTalentUpdate()
end

PRIEST_DIVINEAEGIS_SPELLID = 47753

local priest_PWS_Ranks = {
	[1] = {17, 6, 44, 4},
	[2] = {592, 12, 88, 6},
	[3] = {600, 18, 158, 8},
	[4] = {3747, 24, 234, 10},
	[5] = {6065, 30, 301, 11},
	[6] = {6066, 36, 381, 13},
	[7] = {10898, 42, 484, 15},
	[8] = {10899, 48, 605, 17},
	[9] = {10900, 54, 763, 19},
	[10] = {10901, 60, 942, 21},
	[11] = {25217, 65, 1125, 18},
	[12] = {25218, 70, 1265, 20},
	[13] = {48065, 75, 1920, 30},
	[14] = {48066, 80, 2230, 0}
}

local priest_defaultScaling = {[PRIEST_DIVINEAEGIS_SPELLID] = 0}
do
	for k, v in pairs(priest_PWS_Ranks) do
		priest_defaultScaling[v[1]] = {v[3], 0.809}
	end
end

local function priest_PowerWordShield_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local _, sp, quality1, sourceScaling, quality2 = UnitStatsAndScaling(srcGUID, 0.1, priest_defaultScaling, 0.1)
	sourceScaling[spellid] = sourceScaling[spellid] or priest_defaultScaling[spellid]
	if sourceScaling[spellid] then
		return floor((sourceScaling[spellid][1] + sp * sourceScaling[spellid][2]) * ZONE_MODIFIER), min(quality1, quality2)
	end
end

local function priest_DivineAegis_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local existing = 0

	if destEffects and destEffects[spellid] then
		existing = destEffects[spellid][3]
	end

	local charge = PopCharge(dstGUID, spellid)

	if charge == 0 then
		return existing, 0.0
	end

	local destLevel = UnitDispatch(UnitLevel, dstGUID, dstName)
	local quality = 1.0

	if destLevel == 0 then
		destLevel = 80
		quality = 0.4
	end

	return min(destLevel * 125, existing + charge), quality
end

local function priest_DivineAegis_OnHealCrit(srcGUID, srcName, dstGUID, dstName, spellid, amount)

	PushCharge(dstGUID, PRIEST_DIVINEAEGIS_SPELLID, floor(amount * Scaling[srcGUID][PRIEST_DIVINEAEGIS_SPELLID]), 5.0)
end

local function priest_ApplyScaling(guid, level, baseFactor, spFactor, daFactor)
	local guidScaling

	if not Scaling[guid] then
		guidScaling = {}
		Scaling[guid] = guidScaling
	else
		guidScaling = Scaling[guid]
	end

	guidScaling[PRIEST_DIVINEAEGIS_SPELLID] = daFactor

	if daFactor > 0 then
		Core.AddCombatTrigger(guid, "OnHealCrit", priest_DivineAegis_OnHealCrit)
	else
		Core.RemoveCombatTrigger(guid, "OnHealCrit", priest_DivineAegis_OnHealCrit)
	end

	local rankValue, rankSP

	for k, v in pairs(priest_PWS_Ranks) do
		if v[2] <= level then
			if level == 80 then
				rankValue = v[3] + v[4]
			else

				rankValue = v[3]
			end

			if v[2] < (level - 5) then
				if level == 80 then
					rankSP = max(spFactor * ((v[2] * 0.045228921) - 2.381389768), 0)
				else
					rankSP = 0
				end
			else
				rankSP = spFactor
			end

			guidScaling[v[1]] = {rankValue * baseFactor, rankSP}
		end
	end
end

local function priest_UpdatePlayerScaling()
	privateScaling.base = ((1.0 + (privateScaling["TwinDisc"] * 0.01) + (privateScaling["FocusedPower"] * 0.02) + (privateScaling["SpiritualHealing"] * 0.02)) * (1.0 + ((privateScaling["ImpPWS"] + privateScaling["4pcRaid10"]) * 0.05)))

	local spFactor = 0.807
	spFactor = spFactor + (privateScaling["BorrowedTime"] * 0.08)
	spFactor = spFactor * (1.0 + (privateScaling["TwinDisc"] * 0.01) + (privateScaling["FocusedPower"] * 0.02) + (privateScaling["SpiritualHealing"] * 0.02)) * (1.0 + ((privateScaling["ImpPWS"] + privateScaling["4pcRaid10"]) * 0.05))
	privateScaling.sp = spFactor
	privateScaling.DA = (privateScaling["DivineAegis"] * 0.1) * (1 + (privateScaling["4pcRaid9"] * 0.03))
	priest_ApplyScaling(playerid, UnitLevel("player"), privateScaling.base, privateScaling.sp, privateScaling.DA)
	lib.ScheduleScalingBroadcast()
end

local function priest_ScanTalents()

	local t = select(5, GetTalentInfo(1, 2))
	privateScaling["TwinDisc"] = t

	t = select(5, GetTalentInfo(1, 9))
	privateScaling["ImpPWS"] = t

	t = select(5, GetTalentInfo(1, 16))
	privateScaling["FocusedPower"] = t

	t = select(5, GetTalentInfo(1, 24))
	privateScaling["DivineAegis"] = t

	t = select(5, GetTalentInfo(1, 27))
	privateScaling["BorrowedTime"] = t

	t = select(5, GetTalentInfo(2, 16))
	privateScaling["SpiritualHealing"] = t
end

local function priest_ScanEquipment()
	local n = 0

	if IsEquippedItem(50765) or IsEquippedItem(51178) or IsEquippedItem(51261) then
		n = 1
	end
	if IsEquippedItem(50767) or IsEquippedItem(51175) or IsEquippedItem(51264) then
		n = n + 1
	end
	if IsEquippedItem(50768) or IsEquippedItem(51176) or IsEquippedItem(51263) then
		n = n + 1
	end
	if IsEquippedItem(50766) or IsEquippedItem(51179) or IsEquippedItem(51260) then
		n = n + 1
	end
	if IsEquippedItem(50769) or IsEquippedItem(51177) or IsEquippedItem(51262) then
		n = n + 1
	end

	if n >= 4 then
		privateScaling["4pcRaid10"] = 1

		privateScaling["4pcRaid9"] = 0
		return
	else
		privateScaling["4pcRaid10"] = 0
	end

	n = 0

	if UnitFactionGroup("player") == "Alliance" then
		if IsEquippedItem(47914) or IsEquippedItem(47984) or IsEquippedItem(48035) then
			n = 1
		end
		if IsEquippedItem(47981) or IsEquippedItem(47987) or IsEquippedItem(48029) then
			n = n + 1
		end
		if IsEquippedItem(47936) or IsEquippedItem(47986) or IsEquippedItem(48031) then
			n = n + 1
		end
		if IsEquippedItem(47982) or IsEquippedItem(47983) or IsEquippedItem(48037) then
			n = n + 1
		end
		if IsEquippedItem(47980) or IsEquippedItem(47985) or IsEquippedItem(48033) then
			n = n + 1
		end
	else
		if IsEquippedItem(48068) or IsEquippedItem(48065) or IsEquippedItem(48058) then
			n = 1
		end
		if IsEquippedItem(48071) or IsEquippedItem(48062) or IsEquippedItem(48061) then
			n = n + 1
		end
		if IsEquippedItem(48070) or IsEquippedItem(48063) or IsEquippedItem(48060) then
			n = n + 1
		end
		if IsEquippedItem(48067) or IsEquippedItem(48066) or IsEquippedItem(48057) then
			n = n + 1
		end
		if IsEquippedItem(48069) or IsEquippedItem(48064) or IsEquippedItem(48059) then
			n = n + 1
		end
	end

	if n >= 4 then
		privateScaling["4pcRaid9"] = 1
	else
		privateScaling["4pcRaid9"] = 0
	end
end

local function priest_OnLevelUp()
	priest_UpdatePlayerScaling()
end

local function priest_OnTalentUpdate()
	priest_ScanTalents()
	priest_UpdatePlayerScaling()
end

local function priest_OnEquipmentChangedDelayed()
	priest_ScanEquipment()
	priest_UpdatePlayerScaling()
end

local function priest_OnEquipmentChanged()
	Core:ScheduleUniqueTimer("priest_equip", priest_OnEquipmentChangedDelayed, 0.7)
end

local function priest_OnScalingEncode()
	return {UnitLevel("player"), privateScaling.base, privateScaling.sp, privateScaling.DA}
end

function OnScalingDecode.PRIEST(guid, in_guidScaling)
	if type(in_guidScaling) ~= "table" or #in_guidScaling ~= 4 then return end
	for i = 1, 4 do
		if type(in_guidScaling[i]) ~= "number" then return end
	end
	priest_ApplyScaling(guid, unpack(in_guidScaling))
end

function OnEnableClass.PRIEST()
	Events.PLAYER_LEVEL_UP = priest_OnLevelUp
	Events.PLAYER_TALENT_UPDATE = priest_OnTalentUpdate
	Events.PLAYER_EQUIPMENT_CHANGED = priest_OnEquipmentChanged
	Events.OnScalingEncode = priest_OnScalingEncode

	priest_ScanTalents()
	priest_ScanEquipment()
	priest_UpdatePlayerScaling()
end

local shaman_defaultScaling = {0.3}

local function shaman_AstralShift_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local sourceScaling, quality = UnitScaling(srcGUID, shaman_defaultScaling, 0.7)
	return -1, quality, sourceScaling[1]
end

local function shaman_AstralShift_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	local total = absorbedRemaining + overkill

	return floor(total * effectEntry[7]), true
end

local function shaman_OnTalentUpdate()

	local t = select(5, GetTalentInfo(1, 21))
	playerScaling[1] = t * 0.1
	lib.ScheduleScalingBroadcast()
end

function OnEnableClass.SHAMAN()
	Events.PLAYER_TALENT_UPDATE = shaman_OnTalentUpdate
	shaman_OnTalentUpdate()
end

local warlock_Sacrifice_Spells = {
	[7812] = 305,
	[19438] = 510,
	[19440] = 770,
	[19441] = 1095,
	[19442] = 1470,
	[19443] = 1905,
	[27273] = 2855,
	[47985] = 6750,
	[47986] = 8365
}

local warlock_ShadowWard_Spells = {
	[6229] = 290,
	[11739] = 470,
	[11740] = 675,
	[28610] = 875,
	[47890] = 2750,
	[47891] = 3300
}

local warlock_defaultScaling = {1.0}

local function warlock_Sacrifice_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)

	local sourceScaling, quality = UnitScaling(dstGUID, warlock_defaultScaling, 0.4)
	return floor(warlock_Sacrifice_Spells[spellid] * sourceScaling[1]), quality
end

local function warlock_ShadowWard_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
	if spellschool ~= SCHOOL_MASK_SHADOW then
		return 0, true
	end
	return generic_Hit(effectEntry, absorbedRemaining, overkill, spellschool)
end

local function warlock_OnTalentUpdate()

	local t = select(5, GetTalentInfo(2, 6))
	playerScaling[1] = 1 + (t * 0.1)
	lib.ScheduleScalingBroadcast()
end

function OnEnableClass.WARLOCK()
	Events.PLAYER_TALENT_UPDATE = warlock_OnTalentUpdate
	warlock_OnTalentUpdate()
end

local function items_EssenceOfGossamer_Hit(effectEntry)
	if effectEntry[3] < 140 then
		return effectEntry[3], false
	end
	return 140, true
end

local function items_ArgussianCompass_Hit(effectEntry)
	if effectEntry[3] < 68 then
		return effectEntry[3], false
	end
	return 68, true
end

local function items_Valanyr_OnHeal(srcGUID, srcName, dstGUID, dstName, spellid, amount)
	PushCharge(dstGUID, 64413, floor(amount * 0.15), 5.0)
end

local function items_Valanyr_OnAuraApplied(srcGUID, srcName, dstGUID, dstName, spellid)
	Core.AddCombatTrigger(srcGUID, "OnHeal", items_Valanyr_OnHeal)
end

local function items_Valanyr_OnAuraRemoved(srcGUID, srcName, dstGUID, dstName, spellid)
	Core.RemoveCombatTrigger(srcGUID, "OnHeal", items_Valanyr_OnHeal)
end

local function items_Valanyr_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local existing = 0

	if destEffects and destEffects[spellid] then
		existing = destEffects[spellid][3]
	end

	local charge = PopCharge(dstGUID, spellid)
	if charge == 0 then
		return existing, 0.0
	end

	return min(20000, existing + charge), 1.0
end

local function items_Stoicism_Create(srcGUID, srcName, dstGUID, dstName, spellid, destEffects)
	local maxHealth = UnitDispatch(UnitHealthMax, dstGUID, dstName)
	if maxHealth == 0 then
		return 0, 0.0
	end
	return floor(maxHealth * 0.2), 1.0
end

local mage_FireWard_Entry = {2.0, 30, generic_SpellScalingByTable_Create, mage_FireWard_Hit, mage_Absorb_Spells, 0.8053}
local mage_FrostWard_Entry = {2.0, 30, generic_SpellScalingByTable_Create, mage_FrostWard_Hit, mage_Absorb_Spells, 0.8053}
local mage_IceBarrier_Entry = {1.0, 60, mage_IceBarrier_Create, generic_Hit}
local mage_ManaShield_Entry = {1.0, 60, generic_SpellScalingByTable_Create, generic_Hit, mage_Absorb_Spells, 0.8053}
local priest_PWS_Entry = {1.0, 30, priest_PowerWordShield_Create, generic_Hit}
local warlock_Sacrifice_Entry = {1.0, 30, generic_ConstantByTable_Create, generic_Hit, warlock_Sacrifice_Spells}
local warlock_ShadowWard_Entry = {2.0, 30, generic_SpellScalingByTable_Create, warlock_ShadowWard_Hit, warlock_ShadowWard_Spells, 0.8053}

Core.Effects = {

	[0] = {1.0, 0, function() return 0, 0.0 end, nil},
	[48707] = {3.0, 5, deathknight_AntiMagicShell_Create, deathknight_AntiMagicShell_Hit},
	[50461] = {-3.0, 10, deathknight_AntiMagicZone_Create, deathknight_AntiMagicZone_Hit},

	[52284] = {1.0, nil, function() return 0, 0.0 end, deathknight_WoN_Hit1},
	[52285] = {1.0, nil, function() return 0, 0.0 end, deathknight_WoN_Hit2},
	[52286] = {1.0, nil, function() return 0, 0.0 end, deathknight_WoN_Hit3},

	[62606] = {1.1, 10, druid_SavageDefense_Create, druid_SavageDefense_Hit},
	[543] = mage_FireWard_Entry,
	[8457] = mage_FireWard_Entry,
	[8458] = mage_FireWard_Entry,
	[10223] = mage_FireWard_Entry,
	[10225] = mage_FireWard_Entry,
	[27218] = mage_FireWard_Entry,
	[43010] = mage_FireWard_Entry,
	[6143] = mage_FrostWard_Entry,
	[8461] = mage_FrostWard_Entry,
	[8462] = mage_FrostWard_Entry,
	[10177] = mage_FrostWard_Entry,
	[28609] = mage_FrostWard_Entry,
	[32796] = mage_FrostWard_Entry,
	[43012] = mage_FrostWard_Entry,
	[11426] = mage_IceBarrier_Entry,
	[13031] = mage_IceBarrier_Entry,
	[13032] = mage_IceBarrier_Entry,
	[13033] = mage_IceBarrier_Entry,
	[27134] = mage_IceBarrier_Entry,
	[33405] = mage_IceBarrier_Entry,
	[43038] = mage_IceBarrier_Entry,
	[43039] = mage_IceBarrier_Entry,
	[1463] = mage_ManaShield_Entry,
	[8494] = mage_ManaShield_Entry,
	[8495] = mage_ManaShield_Entry,
	[10191] = mage_ManaShield_Entry,
	[10192] = mage_ManaShield_Entry,
	[10193] = mage_ManaShield_Entry,
	[27131] = mage_ManaShield_Entry,
	[43019] = mage_ManaShield_Entry,
	[43020] = mage_ManaShield_Entry,
	[58597] = {1.0, 6, paladin_SacredShield_Create, generic_Hit},
	[17] = priest_PWS_Entry,
	[592] = priest_PWS_Entry,
	[600] = priest_PWS_Entry,
	[3747] = priest_PWS_Entry,
	[6065] = priest_PWS_Entry,
	[6066] = priest_PWS_Entry,
	[10898] = priest_PWS_Entry,
	[10899] = priest_PWS_Entry,
	[10900] = priest_PWS_Entry,
	[10901] = priest_PWS_Entry,
	[25217] = priest_PWS_Entry,
	[25218] = priest_PWS_Entry,
	[48065] = priest_PWS_Entry,
	[48066] = priest_PWS_Entry,
	[47753] = {1.0, 12, priest_DivineAegis_Create, generic_Hit},
	[52179] = {2.5, nil, shaman_AstralShift_Create, shaman_AstralShift_Hit},
	[7812] = warlock_Sacrifice_Entry,
	[19438] = warlock_Sacrifice_Entry,
	[19440] = warlock_Sacrifice_Entry,
	[19441] = warlock_Sacrifice_Entry,
	[19442] = warlock_Sacrifice_Entry,
	[19443] = warlock_Sacrifice_Entry,
	[27273] = warlock_Sacrifice_Entry,
	[47985] = warlock_Sacrifice_Entry,
	[47986] = warlock_Sacrifice_Entry,
	[6229] = warlock_ShadowWard_Entry,
	[11739] = warlock_ShadowWard_Entry,
	[11740] = warlock_ShadowWard_Entry,
	[28610] = warlock_ShadowWard_Entry,
	[47890] = warlock_ShadowWard_Entry,
	[47891] = warlock_ShadowWard_Entry,
	[64413] = {1.0, 8, items_Valanyr_Create, generic_Hit},
	[60218] = {5.0, 10, function() return 4000, 1.0 end, items_EssenceOfGossamer_Hit},
	[71586] = {1.0, 10, function() return 6400, 1.0 end, generic_Hit},
	[36481] = {1.0, 4, function() return 100000, 1.0 end, generic_Hit},
	[57350] = {1.0, 6, function() return 1500, 1.0 end, generic_Hit},
	[17252] = {1.0, 1800, function() return 500, 1.0 end, generic_Hit},
	[29506] = {1.0, 20, function() return 900, 1.0 end, generic_Hit},
	[31771] = {1.0, 20, function() return 440, 1.0 end, generic_Hit},
	[9800] = {1.0, 60, function() return 175, 1.0 end, generic_Hit},
	[13234] = {1.0, 600, function() return 500, 1.0 end, generic_Hit},
	[30458] = {1.0, 8, function() return 4000, 1.0 end, generic_Hit},
	[27779] = {1.0, 30, function() return 350, 1.0 end, generic_Hit},
	[28810] = {1.0, 30, function() return 500, 1.0 end, generic_Hit},
	[29674] = {1.0, nil, function() return 1000, 1.0 end, generic_Hit},
	[29719] = {1.0, nil, function() return 4000, 1.0 end, generic_Hit},
	[29701] = {1.0, nil, function() return 4000, 1.0 end, generic_Hit},
	[28538] = {1.0, 120, function() return 3400, 1.0 end, Holy_Hit},
	[28537] = {1.0, 120, function() return 3400, 1.0 end, Shadow_Hit},
	[28536] = {1.0, 120, function() return 3400, 1.0 end, Arcane_Hit},
	[28513] = {1.0, 120, function() return 3400, 1.0 end, Nature_Hit},
	[28512] = {1.0, 120, function() return 3400, 1.0 end, Frost_Hit},
	[28511] = {1.0, 120, function() return 3400, 1.0 end, Fire_Hit},
	[7233] = {1.0, 120, function() return 1300, 1.0 end, Fire_Hit},
	[7239] = {1.0, 120, function() return 1300, 1.0 end, Frost_Hit},
	[7242] = {1.0, 120, function() return 1300, 1.0 end, Shadow_Hit},
	[7245] = {1.0, 120, function() return 1300, 1.0 end, Holy_Hit},
	[7254] = {1.0, 120, function() return 1300, 1.0 end, Nature_Hit},
	[53915] = {1.0, 120, function() return 3100, 1.0 end, Shadow_Hit},
	[53914] = {1.0, 120, function() return 3100, 1.0 end, Nature_Hit},
	[53913] = {1.0, 120, function() return 3100, 1.0 end, Frost_Hit},
	[53911] = {1.0, 120, function() return 3100, 1.0 end, Fire_Hit},
	[53910] = {1.0, 120, function() return 3100, 1.0 end, Arcane_Hit},
	[17548] = {1.0, 120, function() return 2600, 1.0 end, Shadow_Hit},
	[17546] = {1.0, 120, function() return 2600, 1.0 end, Shadow_Hit},
	[17545] = {1.0, 120, function() return 2600, 1.0 end, Shadow_Hit},
	[17544] = {1.0, 120, function() return 2600, 1.0 end, Shadow_Hit},
	[17543] = {1.0, 120, function() return 2600, 1.0 end, Shadow_Hit},
	[17549] = {1.0, 120, function() return 2600, 1.0 end, Shadow_Hit},
	[28527] = {1.0, 15, function() return 1000, 1.0 end, generic_Hit},
	[29432] = {1.0, 3600, function() return 2000, 1.0 end, Fire_Hit},
	[25750] = {1.0, 15, function() return 151, 1.0 end, Physical_Hit},
	[25747] = {1.0, 15, function() return 344, 1.0 end, Physical_Hit},
	[25746] = {1.0, 15, function() return 394, 1.0 end, Physical_Hit},
	[23991] = {1.0, 15, function() return 550, 1.0 end, Physical_Hit},
	[30997] = {1.0, 300, function() return 1800, 1.0 end, Fire_Hit},
	[31002] = {1.0, 300, function() return 1800, 1.0 end, Arcane_Hit},
	[30999] = {1.0, 300, function() return 1800, 1.0 end, Nature_Hit},
	[30994] = {1.0, 300, function() return 1800, 1.0 end, Frost_Hit},
	[31000] = {1.0, 300, function() return 1800, 1.0 end, Shadow_Hit},
	[23506] = {1.0, 20, function() return 1000, 1.0 end, generic_Hit},
	[12561] = {1.0, 60, function() return 400, 1.0 end, Fire_Hit},
	[21956] = {1.0, 15, function() return 250, 1.0 end, Physical_Hit},
	[4057] = {1.0, 60, function() return 250, 1.0 end, Fire_Hit},
	[4077] = {1.0, 60, function() return 300, 1.0 end, generic_Hit},
	[39228] = {1.0, 20, function() return 609, 1.0 end, generic_Hit},
	[11657] = {1.0, 20, function() return 70, 1.0 end, generic_Hit},
	[10368] = {1.0, 15, function() return 1000, 1.0 end, generic_Hit},
	[37515] = {1.0, 15, function() return 1000, 1.0 end, generic_Hit},
	[42137] = {1.0, 86400, function() return 1000, 1.0 end, generic_Hit},
	[26467] = {1.0, 30, function() return 1000, 1.0 end, generic_Hit},
	[26470] = {1.0, 8, function() return 1000, 1.0 end, generic_Hit},
	[27539] = {1.0, 6, function() return 1000, 1.0 end, generic_Hit},
	[54808] = {1.0, 12, function() return 1000, 1.0 end, generic_Hit},
	[55019] = {1.0, 12, function() return 1000, 1.0 end, generic_Hit},
	[70845] = {1.0, 10, items_Stoicism_Create, generic_Hit},
	[65686] = {1.0, 0, function() return 0, 0.0 end, nil},
	[65684] = {1.0, 0, function() return 0, 0.0 end, nil}
}

Core.AreaTriggers = {
	[51052] = 50461,
	[62618] = 81781
}

Core.CombatTriggers = {
	OnAuraApplied = {
		[64411] = items_Valanyr_OnAuraApplied
	},
	OnAuraRemoved = {
		[64411] = items_Valanyr_OnAuraRemoved
	},
	OnHeal = {},
	OnHealCrit = {}
}

if not Core.Available then
	Core.RegisterEvent("PLAYER_ENTERING_WORLD")
else
	Core.Enable()
end