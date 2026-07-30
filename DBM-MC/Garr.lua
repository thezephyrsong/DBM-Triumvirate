local mod	= DBM:NewMod("Garr-Classic", "DBM-MC", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260728220000")
mod:SetCreatureID(12057)--, 12099

mod:SetModelID(12110)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 15732 500298",
	"SPELL_CAST_SUCCESS 19492 500251 19496"
)

--[[
ability.id = 19492 and type = "cast"
--]]
local warnAntiMagicPulse	= mod:NewSpellAnnounce(19492, 2)
local warnImmolate			= mod:NewTargetNoFilterAnnounce(15732, 2, nil, false, 3)--Still feels spammy, they can opt into this if they want it
local warnVolcanicPunch		= mod:NewSpellAnnounce(500251, 2)
local warnMagmaShackles		= mod:NewSpellAnnounce(19496, 2)

local specWarnGarrsCave		= mod:NewSpecialWarningGTFO(500298, nil, nil, nil, 1, 6)

local timerAntiMagicPulseCD	= mod:NewCDTimer(15.7+4.3, 19492, nil, nil, nil, 2)--15.7-20 variation
local timerVolcanicPunchCD	= mod:NewCDTimer(25, 500251, nil, nil, nil, 2)--~25s recast
local timerMagmaShacklesCD	= mod:NewCDTimer(15, 19496, nil, nil, nil, 2)--~15s recast

function mod:OnCombatStart(delay)
	timerVolcanicPunchCD:Start(25-delay)
	timerAntiMagicPulseCD:Start(10+5-delay)
	timerMagmaShacklesCD:Start(9.2-delay)
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 15732 and args:IsDestTypePlayer() then
		warnImmolate:CombinedShow(1, args.destName)
	elseif args.spellId == 500298 and args:IsPlayer() and not self:IsTrivial() then--Garr's Cave
		specWarnGarrsCave:Show(args.spellName)
		specWarnGarrsCave:Play("watchfeet")
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 19492 then
		warnAntiMagicPulse:Show()
		timerAntiMagicPulseCD:Start()
	elseif args.spellId == 500251 then
		warnVolcanicPunch:Show()
		timerVolcanicPunchCD:Start()
	elseif args.spellId == 19496 then
		warnMagmaShackles:Show()
		timerMagmaShacklesCD:Start()
	end
end
