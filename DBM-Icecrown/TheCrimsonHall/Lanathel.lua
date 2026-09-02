local mod	= DBM:NewMod("Lanathel", "DBM-Icecrown", 3)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260829000000")
mod:SetCreatureID(37955)
mod:SetEncounterID(853)
mod:SetModelID("creature/bloodqueen/bloodqueen.m2")
mod:SetUsedIcons(1, 2, 3, 4, 7)
mod:SetMinSyncRevision(20220630221430)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 71340 71510 70838 70877 71474 70867 70879 71473 71525 71530 71531 71532 71533 70923 71772 71623",
	"SPELL_AURA_REMOVED 71340 71510 70838 70877 71474",
	"SPELL_CAST_SUCCESS 73070",
	"SPELL_DAMAGE 71726 71727 71728 71729 71277 72638 72639 72640 72637",
	"SPELL_MISSED 71726 71727 71728 71729 71277 72638 72639 72640 72637",

	"CHAT_MSG_RAID_BOSS_EMOTE"
)

local warnPactDarkfallen			= mod:NewTargetAnnounce(71340, 4)
local warnPactDarkfallenSoon		= mod:NewSoonAnnounce(71340, 4, nil, nil, nil, nil, nil, 2)
local warnBloodMirror				= mod:NewTargetNoFilterAnnounce(71510, 3, nil, "Tank|Healer")
local warnDeliriousSlash			= mod:NewTargetNoFilterAnnounce(71623, 2, nil, "Tank|Healer")
local warnSwarmingShadows			= mod:NewTargetAnnounce(71266, 4)
local warnSwarmingShadowsSoon		= mod:NewSoonAnnounce(71266, 4, nil, nil, nil, nil, nil, 2)
local warnInciteTerror				= mod:NewSpellAnnounce(73070, 3, nil, nil, nil, nil, nil, 2)
local warnInciteTerrorSoon			= mod:NewSoonAnnounce(73070, 3, nil, nil, nil, nil, nil, 2)
local warnVampiricBite				= mod:NewTargetNoFilterAnnounce(70946, 2)
local warnBloodthirstSoon			= mod:NewSoonAnnounce(70877, 2)
local warnBloodthirst				= mod:NewTargetNoFilterAnnounce(70877, 3, nil, false)
local warnEssenceoftheBloodQueen	= mod:NewTargetNoFilterAnnounce(70867, 3, nil, false)

local specWarnBloodBolt				= mod:NewSpecialWarningSpell(71772, nil, nil, nil, 2, 2)
local specWarnPactDarkfallen		= mod:NewSpecialWarningYou(71340, nil, nil, nil, 1, 2)
local specWarnEssenceoftheBloodQueen= mod:NewSpecialWarningYou(70867, nil, nil, nil, 1, 2)
local specWarnBloodthirst			= mod:NewSpecialWarningYou(70877, nil, nil, nil, 3, 2)
local yellBloodthirst				= mod:NewYellMe(70877, L.YellFrenzy)
local specWarnSwarmingShadows		= mod:NewSpecialWarningYou(71266, nil, nil, nil, 4, 2)
local specWarnMindConrolled			= mod:NewSpecialWarningTarget(70923, "-Healer", nil, nil, 1, 2)
local specWarnGTFO					= mod:NewSpecialWarningGTFO(71266, nil, nil, nil, 1, 8)

local timerNextInciteTerror			= mod:NewNextTimer(100, 73070, nil, nil, nil, 6)
local timerFirstBite				= mod:NewNextTimer(15, 70946, nil, "Dps", nil, 5)
local timerNextPactDarkfallen		= mod:NewNextTimer(30, 71340, nil, nil, nil, 3)
local timerNextSwarmingShadows		= mod:NewNextTimer(30.5, 71266, nil, nil, nil, 3)
local timerInciteTerror				= mod:NewBuffActiveTimer(4, 73070)
local timerBloodBolt				= mod:NewBuffActiveTimer(6, 71772, nil, nil, nil, 2, nil, DBM_COMMON_L.HEALER_ICON)
local timerBloodThirst				= mod:NewBuffFadesTimer(10, 70877, nil, nil, nil, 5)
local timerEssenceoftheBloodQueen	= mod:NewBuffFadesTimer(60, 70867, nil, nil, nil, 5, nil, DBM_COMMON_L.DAMAGE_ICON)
local timerDeliriousSlashCD			= mod:NewCDTimer(20, 71623, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON)

local berserkTimer					= mod:NewBerserkTimer(330)

mod:AddRangeFrameOption(8, 71446)
mod:AddInfoFrameOption(70867, true)
mod:AddSetIconOption("BloodMirrorIcon", 71510, false, 0, {7})
mod:AddSetIconOption("SwarmingShadowsIcon", 71266, true, 0, {4})
mod:AddSetIconOption("SetIconOnDarkFallen", 71340, true, 0, {1, 2, 3})

local essence = DBM:GetSpellInfoNew(70867)
local pactTargets = {}
mod.vb.pactIcons = 1

local function warnPactTargets(self)
	warnPactDarkfallen:Show(table.concat(pactTargets, "<, >"))
	table.wipe(pactTargets)
	timerNextPactDarkfallen:Start(30)
	warnPactDarkfallenSoon:Schedule(25)
	warnPactDarkfallenSoon:ScheduleVoice(25, "linesoon")
	self.vb.pactIcons = 1
end

function mod:OnCombatStart(delay)
	berserkTimer:Start(-delay)
	timerFirstBite:Start(-delay)
	timerNextPactDarkfallen:Start(20-delay)
	warnPactDarkfallenSoon:Schedule(15-delay)
	warnPactDarkfallenSoon:ScheduleVoice(15-delay, "linesoon")
	timerDeliriousSlashCD:Start(10-delay)
	timerNextSwarmingShadows:Start(-delay)
	warnSwarmingShadowsSoon:Schedule(25.5-delay)
	warnSwarmingShadowsSoon:ScheduleVoice(25.5-delay, "flamessoon")
	table.wipe(pactTargets)
	self.vb.pactIcons = 1
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(8)
	end
	if self:IsDifficulty("normal10", "heroic10") then
		timerNextInciteTerror:Start(124-delay)
		warnInciteTerrorSoon:Schedule(119-delay)
		warnInciteTerrorSoon:ScheduleVoice(119-delay, "fearsoon")
	else
		timerNextInciteTerror:Start(127-delay)
		warnInciteTerrorSoon:Schedule(122-delay)
		warnInciteTerrorSoon:ScheduleVoice(122-delay, "fearsoon")
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
	if self.Options.InfoFrame then
		DBM.InfoFrame:Hide()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 71340 then
		pactTargets[#pactTargets + 1] = args.destName
		if args:IsPlayer() then
			specWarnPactDarkfallen:Show()
			specWarnPactDarkfallen:Play("linegather")
		end
		if self.Options.SetIconOnDarkFallen then
			self:SetIcon(args.destName, self.vb.pactIcons)
		end
		self.vb.pactIcons = self.vb.pactIcons + 1
		self:Unschedule(warnPactTargets)
		if #pactTargets >= 3 then
			warnPactTargets(self)
		else
			self:Schedule(0.3, warnPactTargets, self)
		end
	elseif spellId == 71623 then
		warnDeliriousSlash:Show(args.destName)
		timerDeliriousSlashCD:Start()
	elseif args:IsSpellID(71510, 70838) then
		warnBloodMirror:Show(args.destName)
		if self.Options.BloodMirrorIcon then
			self:SetIcon(args.destName, 7)
		end
	elseif args:IsSpellID(70877, 71474) then
		warnBloodthirst:Show(args.destName)
		if args:IsPlayer() then
			specWarnBloodthirst:Show()
			specWarnBloodthirst:Play("frenzy")
			yellBloodthirst:Yell()
			if self:IsDifficulty("normal10", "heroic10") then
				timerBloodThirst:Start(15)
			else
				timerBloodThirst:Start()
			end
		end
	elseif args:IsSpellID(70867, 70879, 71473, 71525) or args:IsSpellID(71530, 71531, 71532, 71533) then
		warnEssenceoftheBloodQueen:Show(args.destName)
		if self.Options.InfoFrame then
			DBM.InfoFrame:SetHeader(essence)
			DBM.InfoFrame:Show(16, "playerdebuffremaining", essence, 3)
		end
		if args:IsPlayer() then
			specWarnEssenceoftheBloodQueen:Show()
			specWarnEssenceoftheBloodQueen:Play("targetyou")
			if self:IsDifficulty("normal10", "heroic10") then
				timerEssenceoftheBloodQueen:Start(75)
				warnBloodthirstSoon:Schedule(70)
			else
				timerEssenceoftheBloodQueen:Start()
				warnBloodthirstSoon:Schedule(55)
			end
		end
	elseif spellId == 70923 then
		specWarnMindConrolled:Show(args.destName)
		specWarnMindConrolled:Play("findmc")
	elseif spellId == 71772 then
		specWarnBloodBolt:Show()
		specWarnBloodBolt:Play("scatter")
		timerBloodBolt:Start()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 71340 then
		if self.Options.SetIconOnDarkFallen then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(71510, 70838) then
		if self.Options.BloodMirrorIcon then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70877, 71474) then
		if args:IsPlayer() then
			timerBloodThirst:Cancel()
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args.spellId == 73070 then
		warnInciteTerror:Show()
		timerInciteTerror:Start()
		timerNextSwarmingShadows:Restart(39)
		warnSwarmingShadowsSoon:Schedule(34)
		warnSwarmingShadowsSoon:ScheduleVoice(34, "flamessoon")
		timerNextPactDarkfallen:Restart(24)
		warnPactDarkfallenSoon:Schedule(19)
		warnPactDarkfallenSoon:ScheduleVoice(19, "linesoon")
		timerDeliriousSlashCD:Cancel()
		timerDeliriousSlashCD:Start(24)
		if self:IsDifficulty("normal10", "heroic10") then
			timerNextInciteTerror:Start(120)
			warnInciteTerrorSoon:Schedule(115)
			warnInciteTerrorSoon:ScheduleVoice(115, "fearsoon")
		else
			timerNextInciteTerror:Start()
			warnInciteTerrorSoon:Schedule(95)
			warnInciteTerrorSoon:ScheduleVoice(95, "fearsoon")
		end
	end
end

function mod:SPELL_DAMAGE(sourceGUID, _, _, destGUID, destName, _, spellId, spellName)
	if (spellId == 71726 or spellId == 71727 or spellId == 71728 or spellId == 71729) and self:GetCIDFromGUID(sourceGUID) == 37955 then
		warnVampiricBite:Show(destName)
	elseif (spellId == 71277 or spellId == 72638 or spellId == 72639 or spellId == 72640 or spellId == 72637) and destGUID == UnitGUID("player") and self:AntiSpam() then
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg, _, _, _, target)
	if msg:match(L.SwarmingShadows) and target then
		target = DBM:GetUnitFullName(target)
		timerNextSwarmingShadows:Start()
		warnSwarmingShadowsSoon:Schedule(25.5)
		warnSwarmingShadowsSoon:ScheduleVoice(25.5, "flamessoon")
		if target == UnitName("player") then
			specWarnSwarmingShadows:Show()
			specWarnSwarmingShadows:Play("runout")
			specWarnSwarmingShadows:ScheduleVoice(1.5, "keepmove")
		else
			warnSwarmingShadows:Show(target)
		end
		if self.Options.SwarmingShadowsIcon then
			self:SetIcon(target, 4, 6)
		end
	end
end
