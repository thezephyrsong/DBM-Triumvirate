local mod	= DBM:NewMod("Putricide", "DBM-Icecrown", 2)
local L		= mod:GetLocalizedStrings()

local GetTime = GetTime

mod:SetRevision("20260911000000")
mod:SetCreatureID(36678)
mod:SetEncounterID(851)
mod:SetUsedIcons(1, 2, 3, 4)
mod:SetHotfixNoticeRev(20260911000000)
mod:SetMinSyncRevision(20220908000000)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 70351 71966 71967 71968 71617 72851 72852 71621 72850 70672 72455 72832 72833 73121 73122 73120 71893 71255",
	"SPELL_CAST_SUCCESS 70341 71255 72855 72856 70911 72615 72295 74280 74281 70852 70351 71966 71967 71968",
	"SPELL_AURA_APPLIED 70447 72836 72837 72838 70672 72455 72832 72833 72451 72463 72671 72672 70542 70539 72457 72875 72876 70352 74118 70353 74119 72855 72856 70911",
	"SPELL_AURA_APPLIED_DOSE 72451 72463 72671 72672 70542",
	"SPELL_AURA_REFRESH 70539 72457 72875 72876 70542",
	"SPELL_AURA_REMOVED 70447 72836 72837 72838 70672 72455 72832 72833 72855 72856 70911 71615 70539 72457 72875 72876 70542",
	"UNIT_HEALTH boss1",
	"CHAT_MSG_MONSTER_YELL"
)

local berserkTimer					= mod:NewBerserkTimer(600)

local timerMutatedSlash				= mod:NewTargetTimer(20, 70542, nil, false, nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerRegurgitatedOoze			= mod:NewTargetTimer(20, 70539, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1)..": 100% – 80%")
local warnSlimePuddle				= mod:NewSpellAnnounce(70341, 2)
local warnUnstableExperimentSoon	= mod:NewSoonAnnounce(70351, 3)
local warnUnstableExperiment		= mod:NewSpellAnnounce(70351, 4)
local warnVolatileOozeAdhesive		= mod:NewTargetNoFilterAnnounce(70447, 3)
local warnGaseousBloat				= mod:NewTargetNoFilterAnnounce(70672, 3)
local warnUnboundPlague				= mod:NewTargetNoFilterAnnounce(70911, 3, nil, false, nil, nil, nil, true)

local specWarnVolatileOozeAdhesive	= mod:NewSpecialWarningYou(70447, nil, nil, nil, 1, 2)
local specWarnVolatileOozeAdhesiveT	= mod:NewSpecialWarningMoveTo(70447, nil, nil, nil, 1, 2)
local specWarnGaseousBloat			= mod:NewSpecialWarningRun(70672, nil, nil, nil, 4, 2)
local specWarnGaseousBloatCast		= mod:NewSpecialWarningMove(72833, nil, nil, nil, 1, 2)
local specWarnUnboundPlague			= mod:NewSpecialWarningYou(70911, nil, nil, nil, 1, 2, 3)
local yellUnboundPlague				= mod:NewYellMe(70911, false)

local timerGaseousBloat				= mod:NewTargetTimer(20, 70672, nil, nil, nil, 3)
local timerGaseousBloatCast			= mod:NewCastTimer(3, 70672, nil, nil, nil, 3)
local timerSlimePuddleCD			= mod:NewCDTimer(35, 70341, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerUnstableExperimentCD		= mod:NewCDTimer("v35-40", 70351, nil, nil, nil, 1, nil, DBM_COMMON_L.DEADLY_ICON, true)
local timerUnboundPlagueCD			= mod:NewNextTimer(90, 70911, nil, nil, nil, 3, nil, DBM_COMMON_L.HEROIC_ICON)
local timerUnboundPlague			= mod:NewBuffActiveTimer(12, 70911, nil, nil, nil, 3)

local soundSlimePuddle				= mod:NewSound(70341)

mod:AddSetIconOption("OozeAdhesiveIcon", 70447, true, 0, {4})
mod:AddSetIconOption("GaseousBloatIcon", 70672, true, 0, {2})
mod:AddSetIconOption("UnboundPlagueIcon", 70911, true, 0, {3})

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2)..": 80% – 35%")
local warnPhase2					= mod:NewPhaseAnnounce(2, 2, nil, nil, nil, nil, nil, 2)
local warnChokingGasBombSoon		= mod:NewPreWarnAnnounce(71255, 5, 3, nil, "Melee")
local warnChokingGasBomb			= mod:NewSpellAnnounce(71255, 3, nil, "Melee")

local specWarnChokingGasBomb		= mod:NewSpecialWarningMove(71255, "Melee", nil, nil, 1, 2)
local specWarnMalleableGooCast		= mod:NewSpecialWarningSpell(72295, "Ranged", nil, nil, 2, 2)

local timerChokingGasBombCD			= mod:NewCDTimer("v35-40", 71255, nil, nil, nil, 3, nil, nil, true)
local timerChokingGasBombExplosion	= mod:NewCastTimer(12, 71255, nil, nil, nil, 2)
local timerMalleableGooCD			= mod:NewCDTimer(25, 72295, nil, nil, nil, 3)

local soundSpecWarnMalleableGoo		= mod:NewSound(72295, nil, "Ranged")
local soundMalleableGooSoon			= mod:NewSoundSoon(72295, nil, "Ranged")
local soundSpecWarnChokingGasBomb	= mod:NewSound(71255, nil, "Melee")
local soundChokingGasSoon			= mod:NewSoundSoon(71255, nil, "Melee")

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(3)..": 35% – 0%")
local warnPhase3					= mod:NewPhaseAnnounce(3, 2, nil, nil, nil, nil, nil, 2)
local warnMutatedPlague				= mod:NewStackAnnounce(72451, 3, nil, "Tank|Healer|RemoveEnrage")

local timerMutatedPlagueCD			= mod:NewCDTimer(10, 72451, nil, "Tank|Healer|RemoveEnrage", nil, 5, nil, DBM_COMMON_L.TANK_ICON)

mod:AddTimerLine(DBM_COMMON_L.INTERMISSION)
local warnPhase2Soon				= mod:NewPrePhaseAnnounce(2)
local warnPhase3Soon				= mod:NewPrePhaseAnnounce(3)
local warnTearGas					= mod:NewSpellAnnounce(71617, 2)
local warnVolatileExperiment		= mod:NewSpellAnnounce(72843, 4)

local specWarnOozeVariable			= mod:NewSpecialWarningYou(70352, nil, nil, nil, nil, nil, 3)
local specWarnGasVariable			= mod:NewSpecialWarningYou(70353, nil, nil, nil, nil, nil, 3)

local timerNextPhase				= mod:NewPhaseTimer(12.5)

local redOozeGUIDsCasts = {}
local unstableCastStart = 0
local chokingCastStart = 0
mod.vb.warned_preP2 = false
mod.vb.warned_preP3 = false

local function NextPhase(self)
	self:SetStage(self.vb.phase + 0.5)
	if self.vb.phase == 2 then
		warnPhase2:Show()
		warnPhase2:Play("ptwo")
		self:UnregisterShortTermEvents()
	elseif self.vb.phase == 3 then
		warnPhase3:Show()
		warnPhase3:Play("pthree")
		self:UnregisterShortTermEvents()
	end
end

function mod:OnCombatStart(delay)
	self:SetStage(1)
	berserkTimer:Start(-delay)
	timerSlimePuddleCD:Start(10-delay)
	timerUnstableExperimentCD:Start(("v%s-%s"):format(30-delay, 35-delay))
	warnUnstableExperimentSoon:Schedule(25-delay)
	table.wipe(redOozeGUIDsCasts)
	unstableCastStart = 0
	chokingCastStart = 0
	self.vb.warned_preP2 = false
	self.vb.warned_preP3 = false
	if self:IsHeroic() then
		timerUnboundPlagueCD:Start(20-delay)
	end
end

function mod:OnCombatEnd()
	self:UnregisterShortTermEvents()
end

local function extendTimer(timer, delay)
	local bar = DBT:GetBar(timer.id)
	if not bar then return 0 end
	local variance = bar.hasVariance and bar.varianceDuration or 0
	if variance <= 0 then
		local remaining = bar.timer
		timer:AddTime(delay)
		return remaining + delay
	end
	local maxLeft = DBT.Options.VarianceEnabled and bar.timer or bar.timer + variance
	local minLeft = maxLeft - variance
	timer:Start(("v%.1f-%.1f"):format(minLeft + delay, maxLeft + delay))
	return minLeft + delay
end

local function ChokingGasBomb(self)
	warnChokingGasBomb:Show()
	specWarnChokingGasBomb:Show()
	soundSpecWarnChokingGasBomb:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking.mp3")
	soundChokingGasSoon:Cancel()
	soundChokingGasSoon:Schedule(35-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
	timerChokingGasBombCD:Start()
	warnChokingGasBombSoon:Cancel()
	warnChokingGasBombSoon:Schedule(30)
end

local function StartTransition(self)
	if self.vb.phase ~= 1 and self.vb.phase ~= 2 then return end
	local heroicDelay = self:IsHeroic() and 25 or 0
	local delay = 24 + heroicDelay
	local toPhase3 = self.vb.phase == 2
	self:SetStage(self.vb.phase + 0.5)
	warnUnstableExperimentSoon:Cancel()
	warnChokingGasBombSoon:Cancel()
	soundMalleableGooSoon:Cancel()
	soundChokingGasSoon:Cancel()
	extendTimer(timerSlimePuddleCD, delay)
	extendTimer(timerUnboundPlagueCD, delay)
	if toPhase3 then
		timerUnstableExperimentCD:Cancel()
		timerMutatedPlagueCD:Start(10)
		local gooRemaining = extendTimer(timerMalleableGooCD, delay)
		local chokingRemaining = extendTimer(timerChokingGasBombCD, delay)
		if gooRemaining > 3 then
			soundMalleableGooSoon:Schedule(gooRemaining-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
		end
		if chokingRemaining > 5 then
			soundChokingGasSoon:Schedule(chokingRemaining-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
			warnChokingGasBombSoon:Schedule(chokingRemaining-5)
		end
	else
		local unstableRemaining = extendTimer(timerUnstableExperimentCD, delay)
		if unstableRemaining > 5 then
			warnUnstableExperimentSoon:Schedule(unstableRemaining-5)
		end
		timerMalleableGooCD:Start(25+heroicDelay)
		soundMalleableGooSoon:Schedule(25+heroicDelay-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
		timerChokingGasBombCD:Start(("v%s-%s"):format(35+heroicDelay, 40+heroicDelay))
		soundChokingGasSoon:Schedule(35+heroicDelay-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\choking_soon.mp3")
		warnChokingGasBombSoon:Schedule(35+heroicDelay-5)
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.YellTransitionHeroic or msg:find(L.YellTransitionHeroic, 1, true)) and self:IsHeroic() then
		warnVolatileExperiment:Show()
		StartTransition(self)
	end
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if args:IsSpellID(70351, 71966, 71967, 71968) then
		unstableCastStart = GetTime()
		warnUnstableExperimentSoon:Cancel()
		warnUnstableExperiment:Show()
		timerUnstableExperimentCD:Start()
		warnUnstableExperimentSoon:Schedule(30)
	elseif spellId == 71617 then
		warnTearGas:Show()
		StartTransition(self)
	elseif args:IsSpellID(72851, 72852, 71621, 72850) then
		timerNextPhase:Start(9.5)
		if self:IsHeroic() then
			self:Schedule(9.6, NextPhase, self)
			self:RegisterShortTermEvents(
				"UNIT_TARGET boss1"
			)
		end
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then
		timerGaseousBloatCast:Start(args.sourceGUID)
		if not redOozeGUIDsCasts[args.sourceGUID] then
			redOozeGUIDsCasts[args.sourceGUID] = 1
		else
			redOozeGUIDsCasts[args.sourceGUID] = redOozeGUIDsCasts[args.sourceGUID] + 1
		end
		if redOozeGUIDsCasts[args.sourceGUID] > 1 then
			specWarnGaseousBloatCast:Show()
			specWarnGaseousBloatCast:Play("targetchange")
		end
	elseif spellId == 71255 then
		chokingCastStart = GetTime()
		ChokingGasBomb(self)
	elseif args:IsSpellID(73121, 73122, 73120, 71893) then
		timerNextPhase:Start(12.5)
		if self:IsHeroic() then
			self:Schedule(12.6, NextPhase, self)
			self:RegisterShortTermEvents(
				"UNIT_TARGET boss1"
			)
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 70341 and self:AntiSpam(5, 1) then
		warnSlimePuddle:Show()
		soundSlimePuddle:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\puddle_cast.mp3")
		timerSlimePuddleCD:Start()
	elseif spellId == 71255 then
		timerChokingGasBombExplosion:Start()
		if GetTime() - chokingCastStart > 5 then
			ChokingGasBomb(self)
		end
	elseif args:IsSpellID(72855, 72856, 70911) then
		timerUnboundPlagueCD:Start()
	elseif args:IsSpellID(72615, 72295, 74280, 74281) or spellId == 70852 then
		if self:AntiSpam(3, 5) then
			specWarnMalleableGooCast:Show()
			timerMalleableGooCD:Start()
			soundSpecWarnMalleableGoo:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable.mp3")
			soundMalleableGooSoon:Cancel()
			soundMalleableGooSoon:Schedule(25-3, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\malleable_soon.mp3")
		end
	elseif args:IsSpellID(70351, 71966, 71967, 71968) then
		if self:IsHeroic() and GetTime() - unstableCastStart > 5 and self:AntiSpam(5, 6) then
			warnVolatileExperiment:Show()
			StartTransition(self)
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if args:IsSpellID(70447, 72836, 72837, 72838) then
		if args:IsPlayer() then
			specWarnVolatileOozeAdhesive:Show()
		elseif not self:IsTank() then
			specWarnVolatileOozeAdhesiveT:Show(args.destName)
			specWarnVolatileOozeAdhesiveT:Play("helpsoak")
		else
			warnVolatileOozeAdhesive:Show(args.destName)
		end
		if self.Options.OozeAdhesiveIcon then
			self:SetIcon(args.destName, 1)
		end
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then
		timerGaseousBloat:Start(args.destName)
		if args:IsPlayer() then
			specWarnGaseousBloat:Show()
			specWarnGaseousBloat:Play("justrun")
			specWarnGaseousBloat:ScheduleVoice(1.5, "keepmove")
		else
			warnGaseousBloat:Show(args.destName)
		end
		if self.Options.GaseousBloatIcon then
			self:SetIcon(args.destName, 2)
		end

	elseif args:IsSpellID(72451, 72463, 72671, 72672) then
		warnMutatedPlague:Show(args.destName, args.amount or 1)
		timerMutatedPlagueCD:Start()
	elseif spellId == 70542 then
		timerMutatedSlash:Show(args.destName)
	elseif args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Show(args.destName)
	elseif args:IsSpellID(70352, 74118) then
		if args:IsPlayer() then
			specWarnOozeVariable:Show()
		end
	elseif args:IsSpellID(70353, 74119) then
		if args:IsPlayer() then
			specWarnGasVariable:Show()
		end
	elseif args:IsSpellID(72855, 72856, 70911) then
		if self.Options.UnboundPlagueIcon then
			self:SetIcon(args.destName, 3)
		end
		if args:IsPlayer() then
			specWarnUnboundPlague:Show()
			specWarnUnboundPlague:Play("targetyou")
			timerUnboundPlague:Start()
			yellUnboundPlague:Yell()
		else
			warnUnboundPlague:Show(args.destName)
		end
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args:IsSpellID(72451, 72463, 72671, 72672) then
		warnMutatedPlague:Show(args.destName, args.amount or 1)
		timerMutatedPlagueCD:Start()
	elseif args.spellId == 70542 then
		timerMutatedSlash:Show(args.destName)
	end
end

function mod:SPELL_AURA_REFRESH(args)
	if args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Show(args.destName)
	elseif args.spellId == 70542 then
		timerMutatedSlash:Show(args.destName)
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if args:IsSpellID(70447, 72836, 72837, 72838) then
		if self.Options.OozeAdhesiveIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70672, 72455, 72832, 72833) then
		timerGaseousBloat:Cancel(args.destName)
		if self.Options.GaseousBloatIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(72855, 72856, 70911) then
		timerUnboundPlague:Stop(args.destName)
		if self.Options.UnboundPlagueIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif spellId == 71615 and (self.vb.phase == 1.5 or self.vb.phase == 2.5) and not self:IsHeroic() then
		NextPhase(self)
	elseif args:IsSpellID(70539, 72457, 72875, 72876) then
		timerRegurgitatedOoze:Cancel(args.destName)
	elseif spellId == 70542 then
		timerMutatedSlash:Cancel(args.destName)
	elseif (args:IsSpellID(70352, 74118) or args:IsSpellID(70353, 74119)) and (self.vb.phase == 1.5 or self.vb.phase == 2.5) then
		DBM:Debug("Variable phasing time marker")

	end
end

function mod:UNIT_HEALTH(uId)
	if self.vb.phase == 1 and not self.vb.warned_preP2 and self:GetUnitCreatureId(uId) == 36678 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.83 then
		self.vb.warned_preP2 = true
		warnPhase2Soon:Show()
		warnPhase2Soon:Play("nextphasesoon")
	elseif self.vb.phase == 2 and not self.vb.warned_preP3 and self:GetUnitCreatureId(uId) == 36678 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.38 then
		self.vb.warned_preP3 = true
		warnPhase3Soon:Show()
		warnPhase3Soon:Play("nextphasesoon")
	end
end

function mod:UNIT_TARGET(uId)
	if self:GetUnitCreatureId(uId) ~= 36678 then return end

	if UnitExists(uId.."target") then
		if self.vb.phase == 1.5 then
			self:SendSync("ProfessorPhase2")
		elseif self.vb.phase == 2.5 then
			self:SendSync("ProfessorPhase3")
		else
			self:UnregisterShortTermEvents()
			DBM:Debug("UNIT_TARGET phasing did not work since phase was wrongly set: " .. self.vb.phase)
		end
	end
end

function mod:OnSync(msg)
	if not self:IsInCombat() then return end
	if msg == "ProfessorPhase2" and self.vb.phase == 1.5 then
		self:Unschedule(NextPhase)
		NextPhase(self)
		DBM:Debug("Putricide phase 2 via UNIT_TARGET sync")
	elseif msg == "ProfessorPhase3" and self.vb.phase == 2.5 then
		self:Unschedule(NextPhase)
		NextPhase(self)
		DBM:Debug("Putricide phase 3 via UNIT_TARGET sync")
	end
end