local mod	= DBM:NewMod("Gruul", "DBM-Gruul")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260809000000")
mod:SetCreatureID(19044)

mod:SetModelID(19044)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 33525 33654",
	"SPELL_CAST_SUCCESS 36297",
	"SPELL_AURA_APPLIED 36300 36240 500304",
	"SPELL_AURA_APPLIED_DOSE 36300",
	"SPELL_AURA_REMOVED 500304"
)

local warnGrowth			= mod:NewStackAnnounce(36300, 2)
local warnGroundSlam		= mod:NewSpellAnnounce(33525, 3)
local warnShatter			= mod:NewSpellAnnounce(33654, 4)
local warnSilence			= mod:NewSpellAnnounce(36297, 4)
local warnPhase2			= mod:NewPhaseAnnounce(2)
local warnPhase3			= mod:NewPhaseAnnounce(3)
local warnPhase4			= mod:NewPhaseAnnounce(4)
local warnProtectionGone	= mod:NewFadesAnnounce(500304, 2)

local specWarnCaveIn		= mod:NewSpecialWarningGTFO(36240, nil, nil, nil, 1, 6)
local specWarnShatterSpread	= mod:NewSpecialWarningMoveAway(33654, nil, nil, nil, 1, 6)

local timerGrowthCD		= mod:NewNextTimer(25, 36300, nil, nil, nil, 6)
local timerCaveInCD		= mod:NewNextTimer(30, 36240, nil, nil, nil, 3)
local timerSlamCD		= mod:NewNextTimer(60, 33525, nil, nil, nil, 2)
local timerShatter		= mod:NewCastTimer(9.7, 33654, nil, nil, nil, 2, nil, DBM_COMMON_L.DEADLY_ICON, nil, 1, 4)
local timerSilenceCD	= mod:NewCDTimer(39.9, 36297, nil, nil, nil, 5, nil, DBM_COMMON_L.HEALER_ICON)

mod:AddRangeFrameOption(mod.Options.RangeDistance == "Smaller" and 11+3 or 18+2, 33654)
mod:AddDropdownOption("RangeDistance", {"Smaller", "Safe"}, "Safe", "misc")

local phase = 1

function mod:OnCombatStart(delay)
	phase = 1
	timerGrowthCD:Start(10-delay)
	timerCaveInCD:Start(15-delay)
	timerSlamCD:Start(35-delay)
	timerSilenceCD:Start(39.9-delay)
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(self.Options.RangeDistance == "Smaller" and 11+3 or 18+2)
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 33525 then
		warnGroundSlam:Show()
		timerShatter:Start()
		timerSlamCD:Start(phase == 1 and 60 or 45)
		specWarnShatterSpread:Schedule(6.7)
		specWarnShatterSpread:ScheduleVoice(6.7, "scatter")
		timerGrowthCD:AddTime(9.7)
		timerCaveInCD:AddTime(9.7)
		timerSilenceCD:AddTime(9.7)
	elseif args.spellId == 33654 then
		warnShatter:Show()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 36297 then
		warnSilence:Show()
		timerSilenceCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 36300 then
		if args:GetDestCreatureID() == 19044 then
			local amount = args.amount or 1
			warnGrowth:Show(args.spellName, amount)
			timerGrowthCD:Start(phase == 4 and 20 or 25)
		end
	elseif args.spellId == 36240 then
		timerCaveInCD:Start()
		if args:IsPlayer() and not self:IsTrivial() then
			specWarnCaveIn:Show(args.spellName)
			specWarnCaveIn:Play("watchfeet")
		end
	elseif args.spellId == 500304 and args:GetDestCreatureID() == 19044 then
		phase = phase + 1
		if phase == 2 then
			warnPhase2:Show()
		elseif phase == 3 then
			warnPhase3:Show()
		else
			warnPhase4:Show()
		end
		specWarnShatterSpread:Cancel()
		specWarnShatterSpread:CancelVoice()
		timerShatter:Stop()
		timerGrowthCD:Start(phase == 4 and 20 or 25)
		timerCaveInCD:Start(30)
		timerSilenceCD:Start(39.9)
		timerSlamCD:Start(45)
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 500304 and args:GetDestCreatureID() == 19044 then
		warnProtectionGone:Show()
	end
end