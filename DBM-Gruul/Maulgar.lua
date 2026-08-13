local mod	= DBM:NewMod("Maulgar", "DBM-Gruul")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260806000000")
mod:SetCreatureID(18831, 18832, 18834, 18835, 18836)

mod:SetModelID(18831)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 33238 33054 33147 41924",
	"SPELL_CAST_START 33152 33144 500335",
	"SPELL_CAST_SUCCESS 33131 16508 26561 500338",
	"SPELL_SUMMON 33131"
)

local warningWhirlwind		= mod:NewSpellAnnounce(33238, 4)
local warningFelHunter		= mod:NewSpellAnnounce(33131, 3, nil, mod:IsTank() or mod:UnitClass() == "WARLOCK")
local warningShield			= mod:NewTargetNoFilterAnnounce(33054, 3, nil, "MagicDispeller")
local warningPWS			= mod:NewTargetNoFilterAnnounce(33147, 3, nil, false)
local warningPoH			= mod:NewCastAnnounce(33152, 4)
local warningHeal			= mod:NewCastAnnounce(33144, 4)
local warningRevive			= mod:NewSpellAnnounce(500338, 3)

local specWarnWhirlwind		= mod:NewSpecialWarningRun(33238, "Melee", nil, nil, 4, 2)
local specWarnPoH			= mod:NewSpecialWarningInterrupt(33152, "HasInterrupt", nil, nil, 1, 2)
local specWarnHeal			= mod:NewSpecialWarningInterrupt(33144, "HasInterrupt", nil, nil, 1, 2)
local specWarnReincarnation	= mod:NewSpecialWarningSpell(500335, nil, nil, nil, 3, 2)
local specWarnBerserk		= mod:NewSpecialWarningSpell(41924, nil, nil, nil, 2, 2)

local timerWhirlwindCD		= mod:NewCDTimer(40, 33238, nil, nil, nil, 2)
local timerWhirlwind		= mod:NewBuffActiveTimer(15, 33238, nil, nil, nil, 2)
local timerChargeCD			= mod:NewCDTimer(30, 26561, nil, nil, nil, 2)
local timerFelhunter		= mod:NewCDTimer(36, 33131, nil, nil, nil, 1)
local timerPoH				= mod:NewCastTimer(4, 33152, nil, nil, nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timerPoHCD			= mod:NewCDTimer(50, 33152, nil, nil, nil, 4)
local timerHeal				= mod:NewCastTimer(2, 33144, nil, nil, nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timerHealCD			= mod:NewCDTimer(6, 33144, nil, nil, nil, 4)
local timerPWSCD			= mod:NewCDTimer(10, 33147, nil, nil, nil, 5)
local timerSpellShieldCD	= mod:NewCDTimer(30.3, 33054, nil, nil, nil, 5)
local timerRoarCD			= mod:NewCDTimer(20.6, 16508, nil, nil, nil, 2)
local timerReincarnation	= mod:NewCastTimer(15, 500335, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON)

function mod:OnCombatStart(delay)
	timerWhirlwindCD:Start(40-delay)
	timerChargeCD:Start(30-delay)
	timerFelhunter:Start(36-delay)
	timerHealCD:Start(6-delay)
	timerPWSCD:Start(10-delay)
	timerPoHCD:Start(50-delay)
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 33152 then
		timerPoHCD:Start()
		if self:CheckInterruptFilter(args.sourceGUID, nil, true) then
			specWarnPoH:Show(args.sourceName)
			specWarnPoH:Play("kickcast")
			timerPoH:Start()
		else
			warningPoH:Show()
		end
	elseif args.spellId == 33144 then
		timerHealCD:Start()
		if self:CheckInterruptFilter(args.sourceGUID, nil, true) then
			specWarnHeal:Show(args.sourceName)
			specWarnHeal:Play("kickcast")
			timerHeal:Start()
		else
			warningHeal:Show()
		end
	elseif args.spellId == 500335 then
		specWarnReincarnation:Show()
		timerReincarnation:Start()
		timerWhirlwindCD:Stop()
		timerChargeCD:Stop()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 33238 then
		if self.Options.SpecWarn33238run then
			specWarnWhirlwind:Show()
			specWarnWhirlwind:Play("justrun")
		else
			warningWhirlwind:Show()
		end
		timerWhirlwind:Start()
		timerWhirlwindCD:Start()
		timerChargeCD:AddTime(15)
	elseif args.spellId == 33054 and not args:IsDestTypePlayer() then
		warningShield:Show(args.destName)
		timerSpellShieldCD:Start()
	elseif args.spellId == 33147 and not args:IsDestTypePlayer() then
		warningPWS:Show(args.destName)
		timerPWSCD:Start()
	elseif args.spellId == 41924 then
		specWarnBerserk:Show()
		timerReincarnation:Stop()
		timerWhirlwindCD:Start(40)
		timerChargeCD:Start(30)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 33131 then
		warningFelHunter:Show()
		timerFelhunter:Start()
	elseif args.spellId == 16508 then
		timerRoarCD:Start()
	elseif args.spellId == 26561 then
		timerChargeCD:Start()
	elseif args.spellId == 500338 then
		warningRevive:Show()
	end
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 33131 then
		warningFelHunter:Show()
		timerFelhunter:Start()
	end
end