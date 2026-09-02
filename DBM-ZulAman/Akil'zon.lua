local mod	= DBM:NewMod("Akilzon", "DBM-ZulAman")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260808000000")
mod:SetCreatureID(23574)

mod:SetZone()
mod:SetUsedIcons(1)

mod:RegisterCombat("combat_yell", L.YellPull)

mod:RegisterEventsInCombat(
	"SPELL_CAST_SUCCESS 43622 43621 43661 500279",
	"SPELL_AURA_APPLIED 43648 500280 500281"
)

local warnStorm			= mod:NewTargetNoFilterAnnounce(43648, 4)
local warnStormSoon		= mod:NewSoonAnnounce(43648, 5, 3)
local warnDisruption	= mod:NewTargetNoFilterAnnounce(43622, 3)
local warnGust			= mod:NewTargetNoFilterAnnounce(43621, 2)
local warnCorrupted		= mod:NewTargetNoFilterAnnounce(500280, 3)
local warnCorroded		= mod:NewTargetNoFilterAnnounce(500281, 3)

local specWarnStorm		= mod:NewSpecialWarningSpell(43648, nil, nil, nil, 2, 2)

local timerStorm		= mod:NewCastTimer(8, 43648, nil, nil, nil, 2, nil, DBM_COMMON_L.HEALER_ICON)
local timerStormCD		= mod:NewCDTimer(60, 43648, nil, nil, nil, 3, nil, nil, true)
local timerDisruptionCD	= mod:NewCDTimer(10, 43622, nil, nil, nil, 3)
local timerGustCD		= mod:NewCDTimer(20, 43621, nil, nil, nil, 3)
local timerLightningCD	= mod:NewCDTimer(12, 43661, nil, nil, nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerChainCD		= mod:NewCDTimer(10, 500279, nil, nil, nil, 3)

local berserkTimer		= mod:NewBerserkTimer(600)

mod:AddRangeFrameOption("10")
mod:AddSetIconOption("StormIcon", 43648, true, false, {1})

function mod:OnCombatStart(delay)
	warnStormSoon:Schedule(55)
	timerStormCD:Start(60)
	timerDisruptionCD:Start(10 - delay)
	timerGustCD:Start(20 - delay)
	timerLightningCD:Start(10 - delay)
	timerChainCD:Start(10 - delay)
	berserkTimer:Start(-delay)
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show()
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 43622 then
		warnDisruption:Show(args.destName)
		if self:AntiSpam(3, 2) then
			timerDisruptionCD:Start()
		end
	elseif spellId == 43621 then
		warnGust:Show(args.destName)
		timerGustCD:Start()
	elseif spellId == 43661 then
		timerLightningCD:Start()
	elseif spellId == 500279 then
		timerChainCD:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 43648 then
		warnStorm:Show(args.destName)
		specWarnStorm:Show()
		specWarnStorm:Play("specialsoon")
		timerStorm:Start()
		warnStormSoon:Schedule(55)
		timerStormCD:Start()
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
			self:Schedule(10, function()
				DBM.RangeCheck:Show()
			end)
		end
		if self.Options.StormIcon then
			self:SetIcon(args.destName, 1, 1)
		end
	elseif spellId == 500280 then
		warnCorrupted:Show(args.destName)
	elseif spellId == 500281 then
		warnCorroded:Show(args.destName)
	end
end