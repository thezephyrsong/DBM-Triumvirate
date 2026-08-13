local mod	= DBM:NewMod("Janalai", "DBM-ZulAman")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260808000000")
mod:SetCreatureID(23578)

mod:SetZone()
mod:SetUsedIcons(1)

mod:RegisterCombat("combat_yell", L.YellPull)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 43140",
	"SPELL_AURA_APPLIED 44779",
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_HEALTH"
)

local warnFlame			= mod:NewTargetNoFilterAnnounce(43140, 3)
local warnAddsSoon		= mod:NewSoonAnnounce(43962, 3)

local specWarnAdds		= mod:NewSpecialWarningSpell(43962, "dps", nil, nil, 1, 2)
local specWarnBomb		= mod:NewSpecialWarningDodge(42630, nil, nil, nil, 2, 2)
local specWarnBreath	= mod:NewSpecialWarningYou(43140, nil, nil, nil, 1, 2)
local specWarnEnrage	= mod:NewSpecialWarningSpell(44779, nil, nil, nil, 1, 2)
local yellFlamebreath	= mod:NewYell(43140)

local timerBomb			= mod:NewCastTimer(11, 42630, nil, nil, nil, 3)
local timerBombCD		= mod:NewCDTimer(20, 42630, nil, nil, nil, 3)
local timerBreathCD		= mod:NewCDTimer(8, 43140, nil, nil, nil, 3)
local timerAddsSpawn	= mod:NewNextTimer(12, 43962, nil, nil, nil, 1, nil, DBM_COMMON_L.DAMAGE_ICON)
local timerEnrage		= mod:NewNextTimer(300, 44779, nil, nil, nil, 2)

local berserkTimer		= mod:NewBerserkTimer(600)

mod:AddSetIconOption("FlameIcon", 43140, true, false, {1})

function mod:FlameTarget(targetname)
	if not targetname then return end
	if targetname == UnitName("player") then
		specWarnBreath:Show()
		specWarnBreath:Play("targetyou")
		yellFlamebreath:Yell()
	else
		warnFlame:Show(targetname)
	end
	if self.Options.FlameIcon then
		self:SetIcon(targetname, 1, 1)
	end
end

function mod:OnCombatStart(delay)
	self.vb.warnedAddsSoon80 = false
	self.vb.warnedAddsSoon55 = false
	self.vb.warnedAddsSoon40 = false
	self.vb.warnedAddsSoon30 = false
	self.vb.warnedAdds75 = false
	self.vb.warnedAdds50 = false
	self.vb.warnedAdds35 = false
	self.vb.warnedAdds25 = false
	self.vb.warnedEnrage20 = false
	timerBreathCD:Start(8 - delay)
	timerBombCD:Start(30 - delay)
	timerEnrage:Start(300 - delay)
	berserkTimer:Start(-delay)
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 43140 then
		timerBreathCD:Start()
		self:BossTargetScanner(args.sourceGUID, "FlameTarget", 0.1, 8)
	end
end

function mod:UNIT_HEALTH(uId)
	if self:GetUnitCreatureId(uId) ~= 23578 then return end
	local relative = UnitHealth(uId) / UnitHealthMax(uId)
	if not self.vb.warnedAddsSoon80 and relative <= 0.8 then
		self.vb.warnedAddsSoon80 = true
		warnAddsSoon:Show()
	end
	if not self.vb.warnedAddsSoon55 and relative <= 0.55 then
		self.vb.warnedAddsSoon55 = true
		warnAddsSoon:Show()
	end
	if not self.vb.warnedAddsSoon40 and relative <= 0.4 then
		self.vb.warnedAddsSoon40 = true
		warnAddsSoon:Show()
	end
	if not self.vb.warnedAddsSoon30 and relative <= 0.3 then
		self.vb.warnedAddsSoon30 = true
		warnAddsSoon:Show()
	end
	if not self.vb.warnedAdds75 and relative <= 0.75 then
		self.vb.warnedAdds75 = true
		specWarnAdds:Show()
		timerAddsSpawn:Start()
	end
	if not self.vb.warnedAdds50 and relative <= 0.5 then
		self.vb.warnedAdds50 = true
		specWarnAdds:Show()
		timerAddsSpawn:Start()
	end
	if not self.vb.warnedAdds35 and relative <= 0.35 then
		self.vb.warnedAdds35 = true
		specWarnAdds:Show()
	end
	if not self.vb.warnedAdds25 and relative <= 0.25 then
		self.vb.warnedAdds25 = true
		specWarnAdds:Show()
		timerAddsSpawn:Start()
	end
	if not self.vb.warnedEnrage20 and relative <= 0.2 then
		self.vb.warnedEnrage20 = true
		timerEnrage:Cancel()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 44779 then
		timerEnrage:Cancel()
		specWarnEnrage:Show()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellBomb or msg:find(L.YellBomb) then
		specWarnBomb:Show()
		specWarnBomb:Play("watchstep")
		timerBomb:Start()
		timerBombCD:Start()
	end
end