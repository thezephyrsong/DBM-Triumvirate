local mod	= DBM:NewMod("ZulJin", "DBM-ZulAman")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260808000000")
mod:SetCreatureID(23863)

mod:SetZone()

mod:RegisterCombat("combat_yell", L.YellPull)

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 43093 43150 43213",
	"SPELL_CAST_SUCCESS 43095 17207",
	"CHAT_MSG_MONSTER_YELL"
)

local warnThrow			= mod:NewTargetNoFilterAnnounce(43093, 3, nil, "Tank|Healer")
local warnParalyze		= mod:NewSpellAnnounce(43095, 4)
local warnParalyzeSoon	= mod:NewPreWarnAnnounce(43095, 5, 3)
local warnClaw			= mod:NewTargetNoFilterAnnounce(43150, 3)
local warnFlame			= mod:NewSpellAnnounce(43213, 3)
local warnPhase			= mod:NewPhaseChangeAnnounce(2, nil, nil, nil, nil, nil, 2)

local specWarnParalyze	= mod:NewSpecialWarningDispel(43095, "RemoveMagic", nil, nil, 1, 2)
local specWarnWW		= mod:NewSpecialWarningRun(17207, "Melee", nil, nil, 4, 2)

local timerParalyzeCD	= mod:NewCDTimer(26, 43095, nil, nil, nil, 3, nil, DBM_COMMON_L.MAGIC_ICON)
local timerWWCD			= mod:NewCDTimer(18, 17207, nil, nil, nil, 3)

local berserkTimer		= mod:NewBerserkTimer(600)

function mod:OnCombatStart(delay)
	self:SetStage(1)
	timerWWCD:Start(18 - delay)
	berserkTimer:Start(-delay)
end

local function restartPhaseTimers(self)
	timerWWCD:Start(18)
	timerParalyzeCD:Start(8)
	warnParalyzeSoon:Cancel()
	warnParalyzeSoon:Schedule(3)
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 43093 then
		warnThrow:Show(args.destName)
	elseif spellId == 43150 then
		warnClaw:Show(args.destName)
	elseif spellId == 43213 then
		warnFlame:Show()
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 43095 then
		warnParalyzeSoon:Schedule(21)
		if self.Options.SpecWarn43095dispel and self:CheckDispelFilter("magic") then
			specWarnParalyze:Show(DBM_COMMON_L.ALLIES)
			specWarnParalyze:Play("helpdispel")
		else
			warnParalyze:Show()
		end
		timerParalyzeCD:Start()
	elseif spellId == 17207 then
		specWarnWW:Show()
		specWarnWW:Play("justrun")
		timerWWCD:Start()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellPhase2 or msg:find(L.YellPhase2) then
		warnPhase:Show(DBM_CORE_L.AUTO_ANNOUNCE_TEXTS.stage:format(2))
		warnPhase:Play("ptwo")
		self:SetStage(2)
		restartPhaseTimers(self)
	elseif msg == L.YellPhase3 or msg:find(L.YellPhase3) then
		warnPhase:Show(DBM_CORE_L.AUTO_ANNOUNCE_TEXTS.stage:format(3))
		warnPhase:Play("pthree")
		self:SetStage(3)
		restartPhaseTimers(self)
	elseif msg == L.YellPhase4 or msg:find(L.YellPhase4) then
		warnPhase:Show(DBM_CORE_L.AUTO_ANNOUNCE_TEXTS.stage:format(4))
		warnPhase:Play("pfour")
		self:SetStage(4)
		restartPhaseTimers(self)
	elseif msg == L.YellPhase5 or msg:find(L.YellPhase5) then
		warnPhase:Show(DBM_CORE_L.AUTO_ANNOUNCE_TEXTS.stage:format(5))
		warnPhase:Play("pfive")
		self:SetStage(5)
		restartPhaseTimers(self)
	end
end