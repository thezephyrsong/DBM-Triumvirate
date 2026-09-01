local mod	= DBM:NewMod("Sulfuron", "DBM-MC", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260804000000")
mod:SetCreatureID(12098)--, 11662

mod:SetModelID(13030)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 19779 19780 19776 20294 500296",
	"SPELL_CAST_START 19775 500292",
	"SPELL_CAST_SUCCESS 500295 500292",
	"UNIT_HEALTH boss1"
)

--TODO, nameplate aura if classic API supports it enough
local warnInspire		= mod:NewTargetNoFilterAnnounce(19779, 2, nil, "Tank|Healer", 2)
local warnHandRagnaros	= mod:NewTargetAnnounce(19780, 2, nil, false, 2)
local warnShadowPain	= mod:NewTargetAnnounce(19776, 2, nil, false, 2)
local warnImmolate		= mod:NewTargetAnnounce(20294, 2, nil, false, 2)
local warnRunAway		= mod:NewSpellAnnounce(500292, 2)
local warnShadowForm	= mod:NewSpellAnnounce(500296, 2)
local warnPhase2		= mod:NewPhaseAnnounce(2)
local warnShadowNova	= mod:NewSpellAnnounce(500295, 2)

local specWarnHeal		= mod:NewSpecialWarningInterrupt(19775, "HasInterrupt", nil, nil, 1, 2)
local specWarnRunAway	= mod:NewSpecialWarningRun(500292, nil, nil, nil, 4, 2)

local timerInspire		= mod:NewTargetTimer(10, 19779, nil, "Tank|Healer", 2, 5, nil, DBM_COMMON_L.TANK_ICON..DBM_COMMON_L.HEALER_ICON)
local timerHeal			= mod:NewCastTimer(2, 19775, nil, nil, 2, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timerShadowNovaCD	= mod:NewCDTimer(6, 500295, nil, nil, nil, 2)--6.08-11.5, parsed log
local timerRunAway	= mod:NewBuffActiveTimer(10, 500292, nil, nil, nil, 2)--10s bar started at 15% HP, stopped once the cast actually starts

function mod:OnCombatStart()
	self:SetStage(1)
	self.vb.shadowFormApplied = false
	self.vb.warnedRunAwaySoon = false
	self.vb.startedRunAwayTimer = false
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 19779 then
		warnInspire:Show(args.destName)
		timerInspire:Start(args.destName)
	elseif args.spellId == 19780 and args:IsDestTypePlayer() then
		warnHandRagnaros:CombinedShow(0.3, args.destName)
	elseif args.spellId == 19776 and args:IsDestTypePlayer() then
		warnShadowPain:CombinedShow(0.3, args.destName)
	elseif args.spellId == 20294 and args:IsDestTypePlayer() then
		warnImmolate:CombinedShow(0.3, args.destName)
	elseif args.spellId == 500296 and not self.vb.shadowFormApplied then
		self.vb.shadowFormApplied = true
		warnShadowForm:Show()
		self:SetStage(2)
		warnPhase2:Show()
		timerShadowNovaCD:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 19779 then
		timerInspire:Stop(args.destName)
	end
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 19775 and args:IsSrcTypeHostile() and self:CheckInterruptFilter(args.sourceGUID, false, true) then--Only show warning/timer for your own target.
		timerHeal:Start()
		specWarnHeal:Show(args.sourceName)
		specWarnHeal:Play("kickcast")
	elseif args.spellId == 500292 then
		specWarnRunAway:Show()
		specWarnRunAway:Play("runaway")
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 500295 then
		warnShadowNova:Show()
		timerShadowNovaCD:Start()
	elseif args.spellId == 500292 then
		timerRunAway:Stop()
	end
end

function mod:UNIT_HEALTH(uId)
	if self:GetUnitCreatureId(uId) == 12098 then
		if not self.vb.warnedRunAwaySoon and UnitHealth(uId) / UnitHealthMax(uId) <= 0.2 then
			self.vb.warnedRunAwaySoon = true
			warnRunAway:Show()
		elseif not self.vb.startedRunAwayTimer and UnitHealth(uId) / UnitHealthMax(uId) <= 0.15 then
			self.vb.startedRunAwayTimer = true
			timerRunAway:Start()
		end
	end
end
