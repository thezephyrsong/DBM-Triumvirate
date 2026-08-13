local mod	= DBM:NewMod("Halazzi", "DBM-ZulAman")
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260808000000")
mod:SetCreatureID(23577)

mod:SetZone()

mod:RegisterCombat("combat_yell", L.YellPull)

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 43303 43139 43290",
	"SPELL_AURA_REMOVED 43303",
	"SPELL_SUMMON 43302",
	"CHAT_MSG_MONSTER_YELL",
	"UNIT_HEALTH"
)

local warnShock			= mod:NewTargetNoFilterAnnounce(43303, 3, "RemoveMagic")
local warnEnrage		= mod:NewSpellAnnounce(43139, 3, nil, "Tank|Healer|RemoveEnrage")
local warnFrenzy		= mod:NewSpellAnnounce(43290, 3)
local warnSpirit		= mod:NewAnnounce("WarnSpirit", 4, 39414)
local warnNormal		= mod:NewAnnounce("WarnNormal", 4, 39414)

local warnCatSoon1		= mod:NewAnnounce("WarnCatSoon1", 2, "Interface\\Icons\\Ability_Hunter_Pet_Cat")
local warnCrocSoon1		= mod:NewAnnounce("WarnCrocSoon1", 2, "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk")
local warnCatSoon2		= mod:NewAnnounce("WarnCatSoon2", 2, "Interface\\Icons\\Ability_Hunter_Pet_Cat")
local warnCrocSoon2		= mod:NewAnnounce("WarnCrocSoon2", 2, "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk")
local warnCatSoon3		= mod:NewAnnounce("WarnCatSoon3", 2, "Interface\\Icons\\Ability_Hunter_Pet_Cat")
local warnCrocSoon3		= mod:NewAnnounce("WarnCrocSoon3", 2, "Interface\\Icons\\Ability_Hunter_Pet_Crocolisk")

local catWarnings		= {warnCatSoon1, warnCatSoon2, warnCatSoon3}
local crocWarnings		= {warnCrocSoon1, warnCrocSoon2, warnCrocSoon3}

local specWarnTotem		= mod:NewSpecialWarningSpell(43302, "Dps", nil, nil, 1, 2)
local specWarnEnrage	= mod:NewSpecialWarningDispel(43139, "RemoveEnrage", nil, nil, 1, 6)

local timerShock		= mod:NewTargetTimer(12, 43303, nil, "RemoveMagic", nil, 5, nil, DBM_COMMON_L.MAGIC_ICON)
local timerFrenzyCD		= mod:NewCDTimer(20, 43139, nil, nil, nil, 5, nil, DBM_COMMON_L.ENRAGE_ICON)
local timerTotemCD		= mod:NewCDTimer(20, 43302, nil, "Dps", nil, 1)

local berserkTimer		= mod:NewBerserkTimer(600)

function mod:OnCombatStart(delay)
	berserkTimer:Start(-delay)
	self:SetStage(1)
	self.vb.phaseBaseline = 1
	self.vb.warnedCatSoon = false
	self.vb.warnedCrocSoon = false
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 43303 then
		warnShock:Show(args.destName)
		timerShock:Show(args.destName)
	elseif spellId == 43139 then
		if self.Options.SpecWarn43139dispel then
			specWarnEnrage:Show(args.destName)
			specWarnEnrage:Play("enrage")
		else
			warnEnrage:Show()
		end
		timerFrenzyCD:Start()
	elseif spellId == 43290 then
		warnFrenzy:Show()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 43303 then
		timerShock:Stop(args.destName)
	end
end

function mod:SPELL_SUMMON(args)
	if args.spellId == 43302 then
		specWarnTotem:Show()
		specWarnTotem:Play("attacktotem")
		timerTotemCD:Start()
	end
end

function mod:UNIT_HEALTH(uId)
	if self.vb.phase >= 4 or self:GetUnitCreatureId(uId) ~= 23577 then return end
	local relative = (UnitHealth(uId) / UnitHealthMax(uId))
	if not self.vb.warnedCatSoon then
		if self.vb.phase == 1 and relative <= 0.8 then
			self.vb.warnedCatSoon = true
			catWarnings[self.vb.phase]:Show()
		elseif self.vb.phase == 2 and relative <= 0.55 then
			self.vb.warnedCatSoon = true
			catWarnings[self.vb.phase]:Show()
		elseif self.vb.phase == 3 and relative <= 0.3 then
			self.vb.warnedCatSoon = true
			catWarnings[self.vb.phase]:Show()
		end
	end
	if not self.vb.warnedCrocSoon and relative <= 0.25 then
		self.vb.warnedCrocSoon = true
		crocWarnings[self.vb.phase]:Show()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.YellSpirit or msg:find(L.YellSpirit) then
		warnSpirit:Show()
		timerTotemCD:Start(12)
	elseif msg == L.YellNormal or msg:find(L.YellNormal) then
		warnNormal:Show()
		self.vb.warnedCatSoon = false
		self.vb.warnedCrocSoon = false
		self:SetStage(0)
	end
end