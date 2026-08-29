local mod	= DBM:NewMod("Rotface", "DBM-Icecrown", 2)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260829000000")
mod:SetCreatureID(36627)
mod:SetUsedIcons(1, 2)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 69508 69774 69839",
	"SPELL_AURA_APPLIED 71208 69760 69558 69674 71224 73022 73023 72272 72273 69240 71218 73019 73020",
	"SPELL_AURA_APPLIED_DOSE 69558",
	"SPELL_CAST_SUCCESS 72272 72273 69240 71218 73019 73020 69674 71224 73022 73023",
	"SPELL_AURA_REMOVED 69674 71224 73022 73023",
	"CHAT_MSG_MONSTER_YELL"
)

local warnSlimeSpray			= mod:NewSpellAnnounce(69508, 2)
local warnMutatedInfection		= mod:NewTargetNoFilterAnnounce(69674, 4)
local warnRadiatingOoze			= mod:NewSpellAnnounce(69760, 3)
local warnOozeSpawn				= mod:NewAnnounce("WarnOozeSpawn", 1)
local warnStickyOoze			= mod:NewSpellAnnounce(69774, 1)
local warnUnstableOoze			= mod:NewStackAnnounce(69558, 2)
local warnVileGas				= mod:NewTargetAnnounce(72272, 3)

local specWarnMutatedInfection	= mod:NewSpecialWarningYou(69674, nil, nil, nil, 1, 2)
local specWarnStickyOoze		= mod:NewSpecialWarningMove(69774, nil, nil, nil, 1, 2)
local specWarnOozeExplosion		= mod:NewSpecialWarningDodge(69839, nil, nil, nil, 1, 2)
local specWarnSlimeSpray		= mod:NewSpecialWarningSpell(69508, false, nil, nil, 1, 2)
local specWarnRadiatingOoze		= mod:NewSpecialWarningSpell(69760, "-Tank", nil, nil, 1, 2)
local specWarnLittleOoze		= mod:NewSpecialWarning("SpecWarnLittleOoze", false, nil, nil, 1, 2)
local specWarnVileGas			= mod:NewSpecialWarningYou(72272, nil, nil, nil, 1, 2, 3)

local timerStickyOoze			= mod:NewNextTimer(15, 69774, nil, "Tank", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerWallSlime			= mod:NewNextTimer(25, 69789)
local timerSlimeSpray			= mod:NewNextTimer(20, 69508, nil, nil, nil, 3)
local timerMutatedInfection		= mod:NewTargetTimer(12, 69674, nil, nil, nil, 5)
local timerMutatedInfectionCD	= mod:NewCDTimer(14, 69674, nil, nil, nil, 3)
local timerOozeExplosion		= mod:NewCastTimer(4, 69839, nil, nil, nil, 2, nil, DBM_COMMON_L.MYTHIC_ICON, nil, 3)
local timerVileGasCD			= mod:NewCDTimer(15, 72272, nil, nil, nil, 3)

mod:AddRangeFrameOption(10, 72272, "Ranged")
mod:AddSetIconOption("InfectionIcon", 69674, true, 0, {1, 2})
mod:AddBoolOption("TankArrow", true, nil, nil, nil, nil, 69674)

local spamOoze = 0
mod.vb.InfectionIcon = 1
mod.vb.infectionCD = 14

local function HastenInfections(self)
	if self.vb.infectionCD >= 8 then
		self.vb.infectionCD = self.vb.infectionCD - 2
		self:Schedule(90, HastenInfections, self)
	end
end

function mod:OnCombatStart(delay)
	timerWallSlime:Start(8-delay)
	timerSlimeSpray:Start(20-delay)
	timerMutatedInfectionCD:Start(14-delay)
	self.vb.infectionCD = 14
	self:Schedule(90-delay, HastenInfections, self)
	if self:IsHeroic() then
		timerVileGasCD:Start(15-delay)
	end

	self.vb.InfectionIcon = 1
	spamOoze = 0
	if self.Options.RangeFrame and self:IsHeroic() then
		DBM.RangeCheck:Show(10)
	end
	self:RegisterShortTermEvents(
		"SPELL_DAMAGE",
		"SPELL_MISSED",
		"SWING_DAMAGE",
		"SWING_MISSED"
	)
end

function mod:OnCombatEnd()
	self:Unschedule(HastenInfections)
	self:UnregisterShortTermEvents()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 69508 then
		timerSlimeSpray:Start()
		specWarnSlimeSpray:Show()
		warnSlimeSpray:Show()
	elseif spellId == 69774 then
		timerStickyOoze:Start(args.sourceGUID)
		warnStickyOoze:Show()
	elseif spellId == 69839 then
		if GetTime() - spamOoze < 4 then
			specWarnOozeExplosion:Cancel()
			specWarnOozeExplosion:CancelVoice()
		end
		if GetTime() - spamOoze < 4 or GetTime() - spamOoze > 5 then
			timerOozeExplosion:Start()
			specWarnOozeExplosion:Schedule(4)
			specWarnOozeExplosion:ScheduleVoice(4, "watchstep")
		end
		spamOoze = GetTime()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 71208 and args:IsPlayer() then
		specWarnStickyOoze:Show()
		specWarnStickyOoze:Play("runaway")
	elseif spellId == 69760 then
		warnRadiatingOoze:Show()
	elseif spellId == 69558 then
		warnUnstableOoze:Show(args.destName, args.amount or 1)
	elseif args:IsSpellID(69674, 71224, 73022, 73023) then
		timerMutatedInfection:Start(args.destName)
		if args:IsPlayer() then
			specWarnMutatedInfection:Show()
			specWarnMutatedInfection:Play("movetotank")
		else
			warnMutatedInfection:Show(args.destName)
		end
		if self.Options.InfectionIcon then
			self:SetIcon(args.destName, self.vb.InfectionIcon, 12)
		end
		if self.vb.InfectionIcon == 1 then
			self.vb.InfectionIcon = 2
		else
			self.vb.InfectionIcon = 1
		end
	elseif (args:IsSpellID(72272, 72273) or args:IsSpellID(69240, 71218, 73019, 73020)) and args:IsDestTypePlayer() then
		if args:IsPlayer() then
			specWarnVileGas:Show()
			specWarnVileGas:Play("scatter")
		end
		warnVileGas:CombinedShow(2.5, args.destName)
		if self:AntiSpam(5, 3) then
			timerVileGasCD:Start()
		end
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(72272, 72273) or args:IsSpellID(69240, 71218, 73019, 73020) then
		timerVileGasCD:Start()
	elseif args:IsSpellID(69674, 71224, 73022, 73023) and self:AntiSpam(2, 4) then
		timerMutatedInfectionCD:Start(self.vb.infectionCD)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(69674, 71224, 73022, 73023) then
		timerMutatedInfection:Cancel(args.destName)
		warnOozeSpawn:Show()
		if self.Options.InfectionIcon then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_DAMAGE(sourceGUID, sourceName, sourceFlags, destGUID, _, _, spellId)
	if (spellId == 69761 or spellId == 71212 or spellId == 73026 or spellId == 73027) and destGUID == UnitGUID("player") and self:AntiSpam(3, 1) then
		specWarnRadiatingOoze:Show()
		specWarnRadiatingOoze:Play("runaway")
	elseif (spellId ~= 53189 or spellId ~= 53190 or spellId ~= 53194 or spellId ~= 53195) and self:GetCIDFromGUID(destGUID) == 36899 and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 and self:IsInCombat() then
		if sourceGUID ~= UnitGUID("player") then
			if self.Options.TankArrow then
				DBM.Arrow:ShowRunTo(sourceName, 0, 0)
			end
		end
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:SWING_DAMAGE(sourceGUID, sourceName, sourceFlags, destGUID)
	if self:GetCIDFromGUID(sourceGUID) == 36897 and destGUID == UnitGUID("player") and self:AntiSpam(3, 2) then
		specWarnLittleOoze:Show()
		specWarnLittleOoze:Play("keepmove")
	elseif self:GetCIDFromGUID(destGUID) == 36899 and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 and self:IsInCombat() then
		if sourceGUID ~= UnitGUID("player") then
			if self.Options.TankArrow then
				DBM.Arrow:ShowRunTo(sourceName, 0, 0)
			end
		end
	end
end
mod.SWING_MISSED = mod.SWING_DAMAGE

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.YellSlimePipes1 or msg:find(L.YellSlimePipes1)) or (msg == L.YellSlimePipes2 or msg:find(L.YellSlimePipes2)) then

		timerWallSlime:Start()
	end
end
