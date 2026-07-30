local mod	= DBM:NewMod("Golemagg", "DBM-MC", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260728220000")
mod:SetCreatureID(11988)--, 11672

mod:SetModelID(11986)
mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 20553 20228",
	"SPELL_AURA_APPLIED 500263 20228",
	"SPELL_AURA_REFRESH 20228"
)

--TODO, quake not in combat log on classic?
local warnQuake		= mod:NewSpellAnnounce(20553)

local specWarnRofGTFO		= mod:NewSpecialWarningGTFO(500263, nil, nil, nil, 1, 8)

local warnPyroblastDebuff		= mod:NewTargetNoFilterAnnounce(20228, 4)
local specWarnPyroblastDebuff	= mod:NewSpecialWarningYou(20228, nil, nil, nil, 3, 2)
local yellPyroblastDebuff		= mod:NewYell(20228)

local timerPyroblastCD	= mod:NewCDTimer(7, 20228, nil, nil, nil, 2)--6.99-7.07, parsed log

function mod:OnCombatStart(delay)
	timerPyroblastCD:Start(3.5-delay)
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 20553 then
		warnQuake:Show()
	elseif args.spellId == 500263 and args:IsPlayer() and self:AntiSpam() then
		specWarnRofGTFO:Show(args.spellName)
		specWarnRofGTFO:Play("watchfeet")
	elseif args.spellId == 20228 then
		if args:IsPlayer() then
			specWarnPyroblastDebuff:Show()
			yellPyroblastDebuff:Yell()
		else
			warnPyroblastDebuff:Show(args.destName)
		end
	end
end
mod.SPELL_AURA_REFRESH = mod.SPELL_AURA_APPLIED

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 20228 then
		timerPyroblastCD:Start()
	end
end
