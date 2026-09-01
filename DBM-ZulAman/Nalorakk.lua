local mod	= DBM:NewMod("Nalorakk", "DBM-ZulAman")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260808000000")
mod:SetCreatureID(23576)

mod:SetZone()

mod:RegisterCombat("combat_yell", L.YellPull)

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 42398",
	"SPELL_CAST_SUCCESS 42402",
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_HEALTH"
)

local warnBear			= mod:NewAnnounce("WarnBear", 4, 39414)
local warnBearSoon		= mod:NewAnnounce("WarnBearSoon", 3, 39414)
local warnNormal		= mod:NewAnnounce("WarnNormal", 4, 39414)
local warnNormalSoon	= mod:NewAnnounce("WarnNormalSoon", 3, 39414)
local warnSilence		= mod:NewSpellAnnounce(42398, 3)
local warnSurge			= mod:NewTargetNoFilterAnnounce(42402, 3)

local timerBear			= mod:NewTimer(40, "TimerBear", 39414, nil, nil, 6)
local timerNormal		= mod:NewTimer(40, "TimerNormal", 39414, nil, nil, 6)

local berserkTimer		= mod:NewBerserkTimer(600)

function mod:OnCombatStart(delay)
	self.vb.bearLocked = false
	timerBear:Start(40 - delay)
	warnBearSoon:Schedule(35 - delay)
	berserkTimer:Start(-delay)
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 42398 and self:AntiSpam(4, 1) then
		warnSilence:Show()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 42402 then
		warnSurge:Show(args.destName)
	end
end

function mod:UNIT_HEALTH(uId)
	if self.vb.bearLocked or self:GetUnitCreatureId(uId) ~= 23576 then return end
	if UnitHealth(uId) / UnitHealthMax(uId) <= 0.35 then
		self.vb.bearLocked = true
		timerBear:Cancel()
		timerNormal:Cancel()
		warnBearSoon:Cancel()
		warnNormalSoon:Cancel()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellBear or msg:find(L.YellBear) then
		timerBear:Cancel()
		warnBearSoon:Cancel()
		warnBear:Show()
		if not self.vb.bearLocked then
			timerNormal:Start()
			warnNormalSoon:Schedule(35)
		end
	elseif msg == L.YellNormal or msg:find(L.YellNormal) then
		timerNormal:Cancel()
		warnNormalSoon:Cancel()
		warnNormal:Show()
		if not self.vb.bearLocked then
			timerBear:Start()
			warnBearSoon:Schedule(35)
		end
	end
end