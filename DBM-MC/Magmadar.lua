local mod	= DBM:NewMod("Magmadar", "DBM-MC", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260804000000")
mod:SetCreatureID(11982)

mod:SetModelID(10193)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 19451 19428",
	"SPELL_AURA_APPLIED_DOSE 19428 58666",
	"SPELL_AURA_REMOVED 19451",
	"SPELL_CAST_SUCCESS 19408 58666"
)

--[[
(ability.id = 19408 or ability.id = 19451) and type = "cast"
 or ability.id = 19428 and type = "applydebuff"
--]]
local warnPanic			= mod:NewSpellAnnounce(19408, 2)
local warnEnrage		= mod:NewTargetNoFilterAnnounce(19451, 3, nil , "Healer|Tank|RemoveEnrage", 2)
local warnConflagration	= mod:NewTargetNoFilterAnnounce(19428, 2, nil , false)
local warnImpale		= mod:NewSpellAnnounce(25646, 4)
local warnImpaleStack	= mod:NewStackAnnounce(19428, 3, nil, "Tank", 3)

local specWarnEnrage	= mod:NewSpecialWarningDispel(19451, "RemoveEnrage", nil, nil, 1, 6)
local specWarnImpaleStack	= mod:NewSpecialWarningStack(25646, nil, 2, nil, nil, 1, 6)
local specWarnImpaleTaunt	= mod:NewSpecialWarningTaunt(25646, nil, nil, nil, 1, 2)
local specWarnConflagrationOut	= mod:NewSpecialWarningMoveAway(19428, nil, nil, nil, 1, 2)

local timerPanicCD		= mod:NewCDTimer(30, 19408, nil, nil, nil, 2, nil, nil, true)--30-40
local timerEnrage		= mod:NewBuffActiveTimer(8, 19451, nil, nil, nil, 5, nil, DBM_COMMON_L.ENRAGE_ICON)
local timerImpaleCD		= mod:NewCDTimer(35, 58666, nil, nil, nil, 2)--39.998-40.099, parsed log, rounded down to nearest 5

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 19451 and args:IsDestTypeHostile() then
		if self.Options.SpecWarn19451dispel then
			specWarnEnrage:Show(args.destName)
			specWarnEnrage:Play("enrage")
		else
			warnEnrage:Show(args.destName)
		end
		timerEnrage:Start()
	elseif args.spellId == 19428 and args:IsDestTypePlayer() then
		warnConflagration:CombinedShow(0.5, args.destName)
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args.spellId == 25646 then
		local amount = args.amount or 1
		if amount >= 2 then
			if args:IsPlayer() then
				specWarnImpaleStack:Show(amount)
				specWarnImpaleStack:Play("stackhigh")
			elseif not DBM:UnitDebuff("player", args.spellName) and not UnitIsDeadOrGhost("player") then
				specWarnImpaleTaunt:Show(args.destName)
				specWarnImpaleTaunt:Play("tauntboss")
			else
				warnImpaleStack:Show(args.destName, amount)
			end
		else
			warnImpaleStack:Show(args.destName, amount)
		end
	elseif args.spellId == 19428 then
		local amount = args.amount or 1
		if amount >= 2 and args:IsPlayer() then
			specWarnConflagrationOut:Show()
			specWarnConflagrationOut:Play("moveaway")
		end
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 19451 and args:IsDestTypeHostile() then
		timerEnrage:Stop()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 19408 then
		warnPanic:Show()
		timerPanicCD:Start()
	elseif args.spellId == 58666 then
		warnImpale:Show()
		timerImpaleCD:Start()
	end
end
