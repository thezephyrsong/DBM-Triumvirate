local mod	= DBM:NewMod("Deathwhisper", "DBM-Icecrown", 1)
local L		= mod:GetLocalizedStrings()

local CancelUnitBuff, GetSpellInfo = CancelUnitBuff, GetSpellInfo
local UnitGUID = UnitGUID

mod:SetRevision("20260829000000")
mod:SetCreatureID(36855)
mod:SetUsedIcons(1, 2, 3, 7, 8)
mod:SetMinSyncRevision(20220905000000)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 71420 72007 72501 72502 70900 70901 72499 72500 72497 72496",
	"SPELL_CAST_SUCCESS 71289 71204 72905 72906 72907 72908 71001 72108 72109 72110",
	"SPELL_AURA_APPLIED 71289 71001 72108 72109 72110 71237 70674 71204",
	"SPELL_AURA_APPLIED_DOSE 71204",
	"SPELL_AURA_REMOVED 70842 71289",
	"SPELL_INTERRUPT",

	"SWING_DAMAGE",
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

local canShadowmeld = select(2, UnitRace("player")) == "NightElf"
local canVanish = select(2, UnitClass("player")) == "ROGUE"

local specWarnWeapons				= mod:NewSpecialWarning("WeaponsStatus", false)

local berserkTimer					= mod:NewBerserkTimer(600)

mod:RemoveOption("HealthFrame")
mod:AddBoolOption("ShieldHealthFrame", false, "misc")

mod:AddTimerLine(DBM_COMMON_L.ADDS)
local warnAddsSoon					= mod:NewAnnounce("WarnAddsSoon", 2, 61131)
local warnReanimating				= mod:NewAnnounce("WarnReanimating", 3, 34018)
local warnDarkTransformation		= mod:NewSpellAnnounce(70900, 4)
local warnDarkEmpowerment			= mod:NewSpellAnnounce(70901, 4)

local specWarnVampricMight			= mod:NewSpecialWarningDispel(70674, "MagicDispeller", nil, nil, 1, 2)
local specWarnDarkMartyrdom			= mod:NewSpecialWarningRun(71236, "Melee", nil, nil, 4, 2)

local timerAdds						= mod:NewTimer(60, "TimerAdds", 61131, nil, nil, 1, DBM_COMMON_L.TANK_ICON..DBM_COMMON_L.DAMAGE_ICON)

mod:AddTimerLine(L.name)

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1))
local warnDominateMind				= mod:NewTargetNoFilterAnnounce(71289, 3)

local specWarnDeathDecay			= mod:NewSpecialWarningGTFO(71001, nil, nil, nil, 1, 8)

local timerDominateMind				= mod:NewBuffActiveTimer(12, 71289, nil, nil, nil, 5)
local timerDeathDecayCD				= mod:NewCDTimer(22, 71001, nil, nil, nil, 3)
local timerDominateMindCD			= mod:NewCDTimer(40, 71289, nil, nil, nil, 3, nil, nil, true)

local soundSpecWarnDominateMind		= mod:NewSound(71289, nil, canShadowmeld or canVanish)

mod:AddInfoFrameOption(70842, false)
mod:AddSetIconOption("SetIconOnDeformedFanatic", 70900, true, 5, {8})
mod:AddSetIconOption("SetIconOnEmpoweredAdherent", 70901, true, 5, {7})
mod:AddSetIconOption("SetIconOnDominateMind", 71289, true, 0, {1, 2, 3})
mod:AddDropdownOption("RemoveBuffsOnMC", {"Never", "Gift", "CCFree", "ShortOffensiveProcs", "MostOffensiveBuffs"}, "Never", "misc", nil, 71289)

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2))
local warnSummonSpirit				= mod:NewSpellAnnounce(71426, 2)
local warnPhase2					= mod:NewPhaseAnnounce(2, 1, nil, nil, nil, nil, nil, 2)
local warnTouchInsignificance		= mod:NewStackAnnounce(71204, 2, nil, "Tank|Healer")

local specWarnCurseTorpor			= mod:NewSpecialWarningYou(71237, nil, nil, nil, 1, 2)
local specWarnTouchInsignificance	= mod:NewSpecialWarningStack(71204, nil, 3, nil, nil, 1, 6)
local specWarnFrostbolt				= mod:NewSpecialWarningInterrupt(72007, "HasInterrupt", nil, 2, 1, 2)
local specWarnVengefulShade			= mod:NewSpecialWarning("SpecWarnVengefulShade", true, nil, nil, nil, 1, 2, nil, 71426, 71426)
local specWarnVengefulShadeOnYou	= mod:NewSpecialWarningRun(71426, nil, nil, nil, 4, 2)

local timerSummonSpiritCD			= mod:NewCDTimer(12, 71426, nil, true, nil, 3, nil, nil, true)
local timerFrostboltCast			= mod:NewCastTimer(2, 72007, nil, "HasInterrupt")
local timerFrostboltCD				= mod:NewCDTimer(12, 72007, nil, nil, nil, 3)
local timerFrostboltVolleyCD		= mod:NewCDTimer(13, 72905, nil, nil, nil, 2)
local timerTouchInsignificance		= mod:NewTargetTimer(30, 71204, nil, "Tank|Healer", nil, 5)
local timerTouchInsignificanceCD	= mod:NewCDTimer(6, 71204, nil, "Tank|Healer", nil, 5, nil, nil, true)

local soundWarnSpirit				= mod:NewSound(71426)

local dominateMindTargets = {}
mod.vb.dominateMindIcon = 1
local shieldName = DBM:GetSpellInfo(70842)
local summonSpiritName = DBM:GetSpellInfo(71426)
local playerHadTarget = false

local playerClass = select(2, UnitClass("player"))
local isHunter = playerClass == "HUNTER"

local RaidWarningFrame = RaidWarningFrame
local GetFramesRegisteredForEvent, RaidNotice_AddMessage = GetFramesRegisteredForEvent, RaidNotice_AddMessage
local function selfWarnMissingSet()
	if mod.Options.EqUneqWeapons and mod:IsHeroic() and not mod:IsEquipmentSetAvailable("pve") then
		for i = 1, select("#", GetFramesRegisteredForEvent("CHAT_MSG_RAID_WARNING")) do
			local frame = select(i, GetFramesRegisteredForEvent("CHAT_MSG_RAID_WARNING"))
			if frame.AddMessage then
				frame.AddMessage(frame, L.setMissing)
			end
		end
		RaidNotice_AddMessage(RaidWarningFrame, L.setMissing, ChatTypeInfo["RAID_WARNING"])
	end
end

mod:AddMiscLine(L.EqUneqLineDescription)
mod:AddBoolOption("EqUneqWeapons", mod:IsDps(), nil, selfWarnMissingSet)
mod:AddBoolOption("EqUneqTimer", false)
mod:AddDropdownOption("EqUneqFilter", {"OnlyDPS", "DPSTank", "NoFilter"}, "OnlyDPS", "misc")

local function selfSchedWarnMissingSet(self)
	if self.Options.EqUneqWeapons and self:IsHeroic() and not self:IsEquipmentSetAvailable("pve") then
		for i = 1, select("#", GetFramesRegisteredForEvent("CHAT_MSG_RAID_WARNING")) do
			local frame = select(i, GetFramesRegisteredForEvent("CHAT_MSG_RAID_WARNING"))
			if frame.AddMessage then
				self:Schedule(10, frame.AddMessage, frame, L.setMissing)
			end
		end
		self:Schedule(10, RaidNotice_AddMessage, RaidWarningFrame, L.setMissing, ChatTypeInfo["RAID_WARNING"])
	end
end
mod:Schedule(0.5, selfSchedWarnMissingSet, mod)

local function checkWeaponRemovalSetting(self)
	if not self.Options.EqUneqWeapons then return false end

	local removalOption = self.Options.EqUneqFilter
	if removalOption == "OnlyDPS" and self:IsDps() then return true
	elseif removalOption == "DPSTank" and not self:IsHealer() then return true
	elseif removalOption == "NoFilter" then return true
	end
	return false
end

local function UnW(self)
	if self:IsEquipmentSetAvailable("pve") then
		PickupInventoryItem(16)
		PutItemInBackpack()
		PickupInventoryItem(17)
		PutItemInBackpack()
		DBM:Debug("MH and OH unequipped", 2)
		if isHunter then
			PickupInventoryItem(18)
			PutItemInBackpack()
			DBM:Debug("Ranged unequipped", 2)
		end
	end
end

local function EqW(self)
	if self:IsEquipmentSetAvailable("pve") then
		DBM:Debug("trying to equip pve")
		UseEquipmentSet("pve")
		if not self:IsTank() then
			CancelUnitBuff("player", (GetSpellInfo(25780)))
		end
	end
end

local aurastoRemove = {

	[48469] = {1, nil},
	[48470] = {1, nil},
	[69381] = {1, nil},

	[48169] = {2, nil},
	[48170] = {2, nil},

	[13877] = {3, "ROGUE"},
	[70721] = {3, "DRUID"},
	[48393] = {3, "DRUID"},
	[53201] = {3, "DRUID"},
	[50213] = {3, "DRUID"},
	[31572] = {3, "MAGE"},
	[54490] = {3, "MAGE"},
	[48108] = {3, "MAGE"},
	[71165] = {3, "WARLOCK"},
	[63167] = {3, "WARLOCK"},
	[70840] = {3, "WARLOCK"},
	[17941] = {3, "WARLOCK"},
	[47197] = {3, "WARLOCK"},
	[34939] = {3, "WARLOCK"},
	[47260] = {3, "WARLOCK"},
	[16246] = {3, "SHAMAN"},
	[64701] = {3, "SHAMAN"},
	[26297] = {3, nil},
	[54758] = {3, nil},
	[59626] = {3, nil},
	[72416] = {3, nil},
	[64713] = {3, nil},
	[67669] = {3, nil},
	[60064] = {3, nil},

	[48168] = {4, "PRIEST"},
	[15258] = {4, "PRIEST"},
	[48420] = {4, "DRUID"},
	[24932] = {4, "DRUID"},
	[67355] = {4, "DRUID"},
	[52610] = {4, "DRUID"},
	[24907] = {4, "DRUID"},
	[71199] = {4, "DRUID"},
	[67360] = {4, "DRUID"},
	[48943] = {4, "PALADIN"},
	[43046] = {4, "MAGE"},
	[47893] = {4, "WARLOCK"},
	[63321] = {4, "WARLOCK"},
	[55637] = {4, nil},
	[71572] = {4, nil},
	[60235] = {4, nil},
	[71644] = {4, nil},
	[75473] = {4, nil},
	[71636] = {4, nil},
}
local optionToDegree = {
	["Gift"] = 1,
	["CCFree"] = 2,
	["ShortOffensiveProcs"] = 3,
	["MostOffensiveBuffs"] = 4,
}

local function RemoveBuffs(option)
	if not option then return end
	local degreeOption = optionToDegree[option]
	for aura, infoTable in pairs(aurastoRemove) do
		local degree, classFilter = unpack(infoTable)
		if degree <= degreeOption then
			if not classFilter or classFilter == playerClass then
				CancelUnitBuff("player", (GetSpellInfo(aura)))
			end
		end
	end
	DBM:Debug("Buffs removed, using option \"" .. option .. "\" and degree: " .. tostring(degreeOption), 2)
end

local function showDominateMindWarning(self)
	warnDominateMind:Show(table.concat(dominateMindTargets, "<, >"))
	timerDominateMind:Start()
	if checkWeaponRemovalSetting(self) then
		if not tContains(dominateMindTargets, UnitName("player")) then
			DBM:Debug("Equipping scheduled")
			self:Schedule(0.1, EqW, self)
			self:Schedule(1.7, EqW, self)
			self:Schedule(3.3, EqW, self)
			self:Schedule(5.5, EqW, self)
			self:Schedule(7.5, EqW, self)
			self:Schedule(9.9, EqW, self)
		end
		if self.Options.EqUneqTimer then
			self:Schedule(39, UnW, self)
		end
	end
	table.wipe(dominateMindTargets)
	self.vb.dominateMindIcon = 1
end

local function addsTimer(self)
	timerAdds:Cancel()
	warnAddsSoon:Cancel()
	if self:IsHeroic() then
		warnAddsSoon:Schedule(40)
		self:Schedule(45, addsTimer, self)
		timerAdds:Start(45)
	else
		warnAddsSoon:Schedule(55)
		self:Schedule(60, addsTimer, self)
		timerAdds:Start()
	end
end

do
	local last = 100
	local function getShieldPercent()

		local unitId = "boss1"
		local guid = UnitGUID(unitId)
		if mod:GetCIDFromGUID(guid) == 36855 then
			last = math.floor(UnitMana(unitId)/UnitManaMax(unitId) * 100)
			return last
		end

		unitId = "boss1"
		guid = UnitGUID(unitId)
		if mod:GetCIDFromGUID(guid) == 36855 then
			last = math.floor(UnitMana(unitId)/UnitManaMax(unitId) * 100)
			return last
		end

		for i = 0, GetNumRaidMembers(), 1 do
			unitId = ((i == 0) and "target") or ("raid"..i.."target")
			guid = UnitGUID(unitId)
			if mod:GetCIDFromGUID(guid) == 36855 then
				last = math.floor(UnitMana(unitId)/UnitManaMax(unitId) * 100)
				return last
			end
		end

		return last
	end
	function mod:CreateShildHPFrame()
		DBM.BossHealth:AddBoss(getShieldPercent, L.ShieldPercent)
	end
end

local function unregisterShortTermEvents(self)
	self:UnregisterShortTermEvents()
end

function mod:OnCombatStart(delay)
	self:SetStage(1)
	if self.Options.ShieldHealthFrame then
		DBM.BossHealth:Show(L.name)
		DBM.BossHealth:AddBoss(36855, L.name)
		self:ScheduleMethod(0.5, "CreateShildHPFrame")
	end
	berserkTimer:Start(-delay)
	timerAdds:Start(5-delay)
	warnAddsSoon:Schedule(2-delay)
	self:Schedule(5-delay, addsTimer, self)
	timerDeathDecayCD:Start(10-delay)
	if not self:IsDifficulty("normal10") then
		timerDominateMindCD:Start(30-delay)
		if checkWeaponRemovalSetting(self) and self.Options.EqUneqTimer then
			specWarnWeapons:Show()
			self:Schedule(29.5-delay, UnW, self)
		end
	end
	table.wipe(dominateMindTargets)
	self.vb.dominateMindIcon = 6
	playerHadTarget = false
	if self.Options.InfoFrame then
		DBM.InfoFrame:SetHeader(shieldName)
		DBM.InfoFrame:Show(1, "enemypower", 2)
	end
end

function mod:OnCombatEnd()
	DBM.BossHealth:Clear()
	self:Unschedule(UnW)
	self:Unschedule(EqW)
	if self.Options.InfoFrame then
		DBM.InfoFrame:Hide()
	end
	self:UnregisterShortTermEvents()
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if args:IsSpellID(71420, 72007, 72501, 72502) then
		timerFrostboltCD:Start()
		if self:CheckInterruptFilter(args.sourceGUID) then
			specWarnFrostbolt:Show(args.sourceName)
			specWarnFrostbolt:Play("kickcast")
			timerFrostboltCast:Start()
		end
	elseif spellId == 70900 then
		warnDarkTransformation:Show()
		if self.Options.SetIconOnDeformedFanatic then
			self:ScanForMobs(args.sourceGUID, 2, 8, 1, nil, 12, "SetIconOnDeformedFanatic")
		end
	elseif spellId == 70901 then
		warnDarkEmpowerment:Show()
		if self.Options.SetIconOnEmpoweredAdherent then
			self:ScanForMobs(args.sourceGUID, 2, 7, 1, nil, 12, "SetIconOnEmpoweredAdherent")
		end
	elseif args:IsSpellID(72499, 72500, 72497, 72496) then
		specWarnDarkMartyrdom:Show()
		specWarnDarkMartyrdom:Play("justrun")
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 71289 then
		timerDominateMindCD:Restart()
		DBM:Debug("MC on "..args.destName, 2)
		if args.destName == UnitName("player") then
			if self.Options.RemoveBuffsOnMC ~= "Never" then
				RemoveBuffs(self.Options.RemoveBuffsOnMC)
			end
			if canShadowmeld then
				soundSpecWarnDominateMind:Play("Interface\\AddOns\\DBM-Core\\sounds\\PlayerAbilities\\Shadowmeld.ogg")
			elseif canVanish then
				soundSpecWarnDominateMind:Play("Interface\\AddOns\\DBM-Core\\sounds\\PlayerAbilities\\Vanish.ogg")
			end
			if checkWeaponRemovalSetting(self) then
				UnW(self)
				UnW(self)
				self:Schedule(0.01, UnW, self)
				DBM:Debug("Unequipping", 2)
			end
		end
	elseif args:IsSpellID(72905, 72906, 72907, 72908) then
		timerFrostboltVolleyCD:Start()
	elseif spellId == 71204 then
		timerTouchInsignificanceCD:Start()
	elseif args:IsSpellID(71001, 72108, 72109, 72110) and self:AntiSpam(3, 4) then
		timerDeathDecayCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 71289 then
		dominateMindTargets[#dominateMindTargets + 1] = args.destName
		if self.Options.SetIconOnDominateMind then
			self:SetIcon(args.destName, self.vb.dominateMindIcon, 12)
		end
		self.vb.dominateMindIcon = self.vb.dominateMindIcon + 1
		self:Unschedule(showDominateMindWarning)
		if self:IsDifficulty("heroic10", "normal25") or (self:IsDifficulty("heroic25") and #dominateMindTargets >= 3) then
			showDominateMindWarning(self)
		else
			self:Schedule(0.9, showDominateMindWarning, self)
		end
	elseif args:IsSpellID(71001, 72108, 72109, 72110) then
		if args:IsPlayer() then
			specWarnDeathDecay:Show()
			specWarnDeathDecay:Play("watchfeet")
		end
	elseif spellId == 71237 and args:IsPlayer() then
		specWarnCurseTorpor:Show()
		specWarnCurseTorpor:Play("targetyou")
	elseif spellId == 70674 and not args:IsDestTypePlayer() and UnitGUID("target") == args.destGUID then
		specWarnVampricMight:Show(args.destName)
		specWarnVampricMight:Play("helpdispel")
	elseif spellId == 71204 then
		timerTouchInsignificance:Start(args.destName)
		local amount = args.amount or 1
		if args:IsPlayer() and amount >= 3 then
			specWarnTouchInsignificance:Show(amount)
			specWarnTouchInsignificance:Play("stackhigh")
		else
			warnTouchInsignificance:Show(args.destName, amount)
		end
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 70842 then
		self:SetStage(2)
		warnPhase2:Show()
		warnPhase2:Play("ptwo")
		timerSummonSpiritCD:Start()
		timerFrostboltCD:Start(10)
		timerTouchInsignificanceCD:Start(6)
		timerAdds:Cancel()
		timerFrostboltVolleyCD:Start(19)
		warnAddsSoon:Cancel()
		self:Unschedule(addsTimer)
		if self:IsHeroic() then
			timerAdds:Start(45)
			warnAddsSoon:Schedule(40)
			self:Schedule(45, addsTimer, self)
		end
		if self.Options.InfoFrame then
			DBM.InfoFrame:Hide()
		end
	elseif spellId == 71289 then
		if (args.destName == UnitName("player") or args:IsPlayer()) and checkWeaponRemovalSetting(self) then
			self:Schedule(0.1, EqW, self)
			self:Schedule(1.7, EqW, self)
			self:Schedule(3.3, EqW, self)
			self:Schedule(5.0, EqW, self)
			self:Schedule(8.0, EqW, self)
			self:Schedule(9.9, EqW, self)
		end
	end
end

function mod:SPELL_INTERRUPT(args)
	local extraSpellId = args.extraSpellId
	if type(extraSpellId) == "number" and (extraSpellId == 71420 or extraSpellId == 72007 or extraSpellId == 72501 or extraSpellId == 72502) then
		timerFrostboltCast:Cancel()
	end
end

function mod:SWING_DAMAGE(sourceGUID, _, _, destGUID)
	if destGUID == UnitGUID("player") and self:GetCIDFromGUID(sourceGUID) == 38222 then
		specWarnVengefulShade:Show()
		specWarnVengefulShade:Play("targetyou")
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellReanimatedFanatic or msg:find(L.YellReanimatedFanatic) then
		warnReanimating:Show()
	end
end

function mod:PLAYER_TARGET_CHANGED()
	if not playerHadTarget and self:GetCIDFromGUID(UnitGUID("target")) == 36855 then
		specWarnVengefulShadeOnYou:Show()
		specWarnVengefulShadeOnYou:Play("runaway")

	end
	self:Unschedule(unregisterShortTermEvents)
	self:UnregisterShortTermEvents()
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == summonSpiritName and self:AntiSpam(5, 1) then
		playerHadTarget = UnitGUID("target") and true
		warnSummonSpirit:Show()
		timerSummonSpiritCD:Start()
		soundWarnSpirit:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\spirits.mp3")
		if not playerHadTarget then
			self:RegisterShortTermEvents(
				"PLAYER_TARGET_CHANGED"
			)
			self:Schedule(0.1, unregisterShortTermEvents, self)
		end
	end
end
