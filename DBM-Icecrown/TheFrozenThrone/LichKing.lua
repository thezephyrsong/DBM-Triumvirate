local mod	= DBM:NewMod("LichKing", "DBM-Icecrown", 5)
local L		= mod:GetLocalizedStrings()

local UnitGUID, UnitName, GetSpellInfo = UnitGUID, UnitName, GetSpellInfo
local UnitInRange, UnitIsUnit, UnitInVehicle, IsInRaid = UnitInRange, UnitIsUnit, UnitInVehicle, DBM.IsInRaid

mod:SetRevision("20260830100000")
mod:SetCreatureID(36597)
mod:SetUsedIcons(1, 2, 3, 4, 5, 6, 7)
mod:SetHotfixNoticeRev(20240220000000)
mod:SetMinSyncRevision(20220921000000)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)

mod:RegisterEventsInCombat(

	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_DISPEL",
	"SPELL_AURA_APPLIED 28747 72754 73708 73709 73710 73650",
	"SPELL_AURA_APPLIED_DOSE 70338 73785 73786 73787",

	"SPELL_SUMMON 69037 70372",
	"SPELL_DAMAGE 68983 73791 73792 73793",
	"SPELL_MISSED 68983 73791 73792 73793",
	"UNIT_HEALTH target focus",
	"UNIT_AURA_UNFILTERED",
	"UNIT_DIED",
	"UNIT_SPELLCAST_START boss1",
	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

local timerCombatStart		= mod:NewCombatTimer(55)
local berserkTimer			= mod:NewBerserkTimer(900)

mod:AddBoolOption("RemoveImmunes")
mod:AddMiscLine(L.FrameGUIDesc)
mod:AddBoolOption("ShowFrame", true)
mod:AddBoolOption("FrameLocked", false)
mod:AddBoolOption("FrameClassColor", true, nil, function()
	mod:UpdateColors()
end)
mod:AddBoolOption("FrameUpwards", false, nil, function()
	mod:ChangeFrameOrientation()
end)
mod:AddButton(L.FrameGUIMoveMe, function() mod:CreateFrame() end, nil, 130, 20)

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(1))
local warnShamblingSoon				= mod:NewSoonAnnounce(70372, 2)
local warnShamblingHorror			= mod:NewSpellAnnounce(70372, 3)
local warnDrudgeGhouls				= mod:NewSpellAnnounce(70358, 2)
local warnShamblingEnrage			= mod:NewTargetNoFilterAnnounce(72143, 3, nil, "Tank|Healer|RemoveEnrage")
local warnNecroticPlague			= mod:NewTargetNoFilterAnnounce(70337, 3)
local warnNecroticPlagueJump		= mod:NewAnnounce("WarnNecroticPlagueJump", 4, 70337, nil, nil, nil, 70337)
local warnInfest					= mod:NewCountAnnounce(70541, 3, nil, "Healer|RaidCooldown")
local warnTrapCast					= mod:NewTargetDistanceAnnounce(73539, 4, nil, nil, nil, nil, nil, nil, true)

local specWarnNecroticPlague		= mod:NewSpecialWarningMoveAway(70337, nil, nil, nil, 1, 2)
local specWarnInfest				= mod:NewSpecialWarningCount(70541, nil, nil, nil, 1)
local specWarnTrap					= mod:NewSpecialWarningYou(73539, nil, nil, nil, 3, 2, 3)
local yellTrap						= mod:NewYellMe(73539)
local specWarnTrapNear				= mod:NewSpecialWarningClose(73539, nil, nil, nil, 3, 2, 3)
local specWarnEnrage				= mod:NewSpecialWarningSpell(72143, "Tank")
local specWarnEnrageLow				= mod:NewSpecialWarningSpell(28747, false)

local timerInfestCD					= mod:NewCDCountTimer(22.5, 70541, nil, "Healer|RaidCooldown", nil, 5, nil, DBM_COMMON_L.HEALER_ICON)
local timerNecroticPlagueCleanse	= mod:NewTimer(5, "TimerNecroticPlagueCleanse", 70337, "Healer", nil, 5, DBM_COMMON_L.HEALER_ICON, nil, nil, nil, nil, nil, nil, 70337)
local timerNecroticPlagueCD			= mod:NewCDTimer(30, 70337, nil, nil, nil, 3, nil, DBM_COMMON_L.DISEASE_ICON)
local timerEnrageCD					= mod:NewCDCountTimer("d20", 72143, nil, "Tank|RemoveEnrage", nil, 5, nil, DBM_COMMON_L.ENRAGE_ICON)
local timerShamblingHorror			= mod:NewNextTimer(60, 70372, nil, nil, nil, 1)
local timerDrudgeGhouls				= mod:NewNextTimer(30, 70358, nil, nil, nil, 1)
local timerTrapCD					= mod:NewNextTimer(15.5, 73539, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON, nil, 1, 4)

local soundInfestSoon				= mod:NewSoundSoon(70541, nil, "Healer|RaidCooldown")
local soundNecroticOnYou			= mod:NewSoundYou(70337)

mod:AddSetIconOption("NecroticPlagueIcon", 70337, true, 0, {1})
mod:AddSetIconOption("TrapIcon", 73539, true, 0, {7})
mod:AddArrowOption("TrapArrow", 73539, true)
mod:AddBoolOption("AnnouncePlagueStack", false, nil, nil, nil, nil, 70337)

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(2))
local warnPhase2					= mod:NewPhaseAnnounce(2, 2, nil, nil, nil, nil, nil, 2)
local valkyrGrabWarning				= mod:NewAnnounce("ValkyrWarning", 3, 71844, nil, nil, nil, 69037)
local warnDefileSoon				= mod:NewSoonCountAnnounce(72762, 3)
local warnSoulreaper				= mod:NewTargetCountAnnounce(69409, 4)
local warnDefileCast				= mod:NewTargetCountDistanceAnnounce(72762, 4, nil, nil, nil, nil, nil, nil, true)
local warnSummonValkyr				= mod:NewCountAnnounce(69037, 3, 71844)

local specWarnYouAreValkd			= mod:NewSpecialWarning("SpecWarnYouAreValkd", nil, nil, nil, 1, 2, nil, 71844, 69037)
local specWarnDefileCast			= mod:NewSpecialWarningMoveAway(72762, nil, nil, nil, 3, 2)
local yellDefile					= mod:NewYellMe(72762)
local specWarnDefileNear			= mod:NewSpecialWarningClose(72762, nil, nil, nil, 1, 2)
local specWarnSoulreaper			= mod:NewSpecialWarningDefensive(69409, nil, nil, nil, 1, 2)
local specwarnSoulreaper			= mod:NewSpecialWarningTarget(69409, true)
local specWarnSoulreaperOtr			= mod:NewSpecialWarningTaunt(69409, false, nil, nil, 1, 2)
local specWarnValkyrLow				= mod:NewSpecialWarning("SpecWarnValkyrLow", nil, nil, nil, 1, 2, nil, 71844, 69037)

local timerSoulreaper				= mod:NewTargetTimer(5.1, 69409, nil, "Tank|Healer|TargetedCooldown")
local timerSoulreaperCD				= mod:NewCDCountTimer(30.5, 69409, nil, "Tank|Healer|TargetedCooldown", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerDefileCD					= mod:NewCDCountTimer(32.5, 72762, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON, nil, 1, 4)
local timerSummonValkyr				= mod:NewCDCountTimer(45, 69037, nil, nil, nil, 1, 71844, DBM_COMMON_L.DAMAGE_ICON, nil, 2, 3)

local soundDefileOnYou				= mod:NewSoundYou(72762)
local soundSoulReaperSoon			= mod:NewSoundSoon(69409, nil, "Tank|Healer|TargetedCooldown")

mod:AddSetIconOption("DefileIcon", 72762, true, 0, {7})
mod:AddSetIconOption("ValkyrIcon", 69037, true, 5, {2, 3, 4})
mod:AddArrowOption("DefileArrow", 72762, true)
mod:AddBoolOption("AnnounceValkGrabs", false, nil, nil, nil, nil, 69037)

mod:AddTimerLine(DBM_CORE_L.SCENARIO_STAGE:format(3))
local warnPhase3					= mod:NewPhaseAnnounce(3, 2, nil, nil, nil, nil, nil, 2)
local warnSummonVileSpirit			= mod:NewSpellAnnounce(70498, 2)
local warnHarvestSoul				= mod:NewTargetNoFilterAnnounce(68980, 3)
local warnRestoreSoul				= mod:NewCastAnnounce(73650, 2)

local specWarnHarvestSoul			= mod:NewSpecialWarningYou(68980, nil, nil, nil, 1, 2)
local specWarnHarvestSouls			= mod:NewSpecialWarningSpell(73654, nil, nil, nil, 1, 2, 3)

local timerHarvestSoul				= mod:NewTargetTimer(6, 68980)
local timerHarvestSoulCD			= mod:NewNextTimer(75, 68980, nil, nil, nil, 6)
local timerVileSpirit				= mod:NewNextTimer(30, 70498, nil, nil, nil, 1)
local timerRestoreSoul				= mod:NewCastTimer(40, 73650, nil, nil, nil, 6)
local timerRoleplay					= mod:NewTimer(162, "TimerRoleplay", 72350, nil, nil, 6)

mod:AddSetIconOption("HarvestSoulIcon", 68980, false, 0, {5})

mod:AddTimerLine(DBM_COMMON_L.INTERMISSION)
local warnRemorselessWinter			= mod:NewSpellAnnounce(68981, 3)
local warnQuake						= mod:NewSpellAnnounce(72262, 4)
local warnRagingSpirit				= mod:NewTargetNoFilterAnnounce(69200, 3)
local warnIceSpheresTarget			= mod:NewTargetAnnounce(69103, 3, 69712, nil, 69090)
local warnPhase2Soon				= mod:NewPrePhaseAnnounce(2)
local warnPhase3Soon				= mod:NewPrePhaseAnnounce(3)

local specWarnRagingSpirit			= mod:NewSpecialWarningYou(69200, nil, nil, nil, 1, 2)
local specWarnIceSpheresYou			= mod:NewSpecialWarningMoveAway(69103, nil, 69090, nil, 1, 2)
local specWarnGTFO					= mod:NewSpecialWarningGTFO(68983, nil, nil, nil, 1, 8)

local timerPhaseTransition			= mod:NewTimer(62.5, "PhaseTransition", 72262, nil, nil, 6)
local timerRagingSpiritCD			= mod:NewNextCountTimer(20, 69200, nil, nil, nil, 1)
local timerHarvestSoulsCD			= mod:NewNextTimer(100, 73654, nil, nil, nil, 6, nil, DBM_COMMON_L.HEROIC_ICON)
local timerSoulShriekCD				= mod:NewCDTimer(12, 69242, nil, nil, nil, 1)

mod:AddRangeFrameOption(8, 72133)
mod:AddSetIconOption("RagingSpiritIcon", 69200, false, 0, {6})

mod.vb.warned_preP2 = false
mod.vb.infestCount = 0

mod.vb.ragingSpiritCount = 0

mod.vb.warned_preP3 = false
mod.vb.defileCount = 0
mod.vb.soulReaperCount = 0
mod.vb.valkyrWaveCount = 0
mod.vb.valkIcon = 2
local shamblingHorrorsGUIDs = {}
local iceSpheresGUIDs = {}
local warnedValkyrGUIDs = {}
local valkyrTargets = {}
local plagueHop = DBM:GetSpellInfo(70338)

local plagueExpires = {}
local grabIcon = 2

local warnedAchievement = false
local lastPlague
local defileCastTime = 0

local function RemoveImmunes(self)
	if self.Options.RemoveImmunes then
		CancelUnitBuff("player", (GetSpellInfo(10278)))
		CancelUnitBuff("player", (GetSpellInfo(642)))
		CancelUnitBuff("player", (GetSpellInfo(45438)))
		CancelUnitBuff("player", (GetSpellInfo(19752)))
	end
end

local function NextPhase(self, delay)
	self.vb.infestCount = 0
	self.vb.defileCount = 0
	self.vb.valkyrWaveCount = 0
	self.vb.soulReaperCount = 0
	if self.vb.phase == 1 then
		berserkTimer:Start(-delay)
		warnShamblingSoon:Schedule(10-delay)
		timerShamblingHorror:Start(15-delay)
		timerDrudgeGhouls:Start(10-delay)
		if self:IsHeroic() then
			timerTrapCD:Start(-delay)
		end
		timerNecroticPlagueCD:Start(-delay)
		timerInfestCD:Start(5.0-delay, self.vb.infestCount+1)
	elseif self.vb.phase == 2 then
		warnPhase2:Show()
		warnPhase2:Play("ptwo")
		timerNecroticPlagueCD:Cancel()
		timerTrapCD:Cancel()
		timerShamblingHorror:Cancel()
		timerDrudgeGhouls:Cancel()
		warnShamblingSoon:Cancel()
		if self.Options.ShowFrame then
			self:CreateFrame()
		end
		timerSummonValkyr:Start(20, self.vb.valkyrWaveCount+1)
		timerSoulreaperCD:Start(40, self.vb.soulReaperCount+1)
		soundSoulReaperSoon:Schedule(40-2.5, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\soulreaperSoon.mp3")
		timerDefileCD:Start(38, self.vb.defileCount+1)
		timerInfestCD:Start(14, self.vb.infestCount+1)
		soundInfestSoon:Schedule(14-2, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\infestSoon.mp3")
		warnDefileSoon:Schedule(33, self.vb.defileCount+1)
		warnDefileSoon:ScheduleVoice(33, "scatter")
		self:RegisterShortTermEvents(
			"UNIT_ENTERING_VEHICLE",
			"UNIT_EXITING_VEHICLE"
		)
	elseif self.vb.phase == 3 then
		warnPhase3:Show()
		warnPhase3:Play("pthree")
		timerVileSpirit:Start(20)
		timerSoulreaperCD:Start(40, self.vb.soulReaperCount+1)
		soundSoulReaperSoon:Schedule(40-2.5, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\soulreaperSoon.mp3")
		timerDefileCD:Start(38, self.vb.defileCount+1)
		if self:IsHeroic() then
			timerHarvestSoulsCD:Start(14)
		else
			timerHarvestSoulCD:Start(14)
		end
		warnDefileSoon:Schedule(33, self.vb.defileCount+1)
		warnDefileSoon:ScheduleVoice(33, "scatter")

	end
end

local bossCastStart, valkyrWave
local bossCastNames = {}
for _, id in ipairs({68981, 72262, 70358, 70498, 70541, 72762, 73539, 73654, 72350}) do
	local name = GetSpellInfo(id)
	if name then
		bossCastNames[name] = true
	end
end

local function RestoreWipeTime(self)
	self:SetWipeTime(5)
end

function mod:OnCombatStart(delay)
	self:DestroyFrame()
	self:SetStage(1)
	self.vb.valkIcon = 2
	self.vb.warned_preP2 = false
	self.vb.warned_preP3 = false
	self.vb.ragingSpiritCount = 0
	NextPhase(self, delay)
	table.wipe(shamblingHorrorsGUIDs)
	table.wipe(iceSpheresGUIDs)
	table.wipe(warnedValkyrGUIDs)
	table.wipe(plagueExpires)
end

function mod:OnCombatEnd()
	self:UnregisterShortTermEvents()
	self:DestroyFrame()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:DefileTarget(targetname, uId)
	if not targetname and not uId then return end
	if not self:AntiSpam(5, "defiletarget") then return end
	if self.Options.DefileIcon then
		self:SetIcon(targetname, 7, 4)
	end
	if targetname == UnitName("player") then
		specWarnDefileCast:Show()
		specWarnDefileCast:Play("runout")
		soundDefileOnYou:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\defileOnYou.mp3")
		yellDefile:Yell()
	elseif self:CheckNearby(11, targetname) then
		specWarnDefileNear:Show(targetname)
	end
	warnDefileCast:Show(self.vb.defileCount, targetname, uId and DBM.RangeCheck:GetDistance(uId) or 0)
	if self.Options.DefileArrow and uId then
		local x, y = GetPlayerMapPosition(uId)
			if x == 0 and y == 0 then
				SetMapToCurrentZone()
				x, y = GetPlayerMapPosition(uId)
			end
		DBM.Arrow:ShowRunAway(x, y, 10, 5)
	end
end

function mod:TrapTarget(targetname, uId)
	if not targetname and not uId then return end
	if not self:AntiSpam(5, "traptarget") then return end
	if self.Options.TrapIcon then
		self:SetIcon(targetname, 7, 4)
	end
	if targetname == UnitName("player") then
		specWarnTrap:Show()
		specWarnTrap:Play("watchstep")
		yellTrap:Yell()
	elseif self:CheckNearby(15, targetname) then
		specWarnTrapNear:Show(targetname)
		specWarnTrapNear:Play("watchstep")
	end
	warnTrapCast:Show(targetname, uId and DBM.RangeCheck:GetDistance(uId) or 0)
	if self.Options.TrapArrow and uId then
		local x, y = GetPlayerMapPosition(uId)
			if x == 0 and y == 0 then
				SetMapToCurrentZone()
				x, y = GetPlayerMapPosition(uId)
			end
		DBM.Arrow:ShowRunAway(x, y, 10, 5)
	end
end

local function scanBossTarget(self, method, tries)
	for uId in DBM:GetGroupMembers() do
		local bossUnit = uId.."target"
		if self:GetUnitCreatureId(bossUnit) == 36597 then
			local victim = bossUnit.."target"
			if UnitExists(victim) and UnitIsPlayer(victim) then
				local isTanking = UnitDetailedThreatSituation(victim, bossUnit)
				if not isTanking then
					local name = DBM:GetUnitFullName(victim)
					self[method](self, name, DBM:GetRaidUnitId(name))
					return
				end
			end
			break
		end
	end
	if tries > 1 then
		self:Schedule(0.1, scanBossTarget, self, method, tries - 1)
	end
end

function mod:ValkyrGrab(unitName, uId)
	if not unitName or valkyrTargets[unitName] then return end
	valkyrTargets[unitName] = true
	valkyrGrabWarning:Show(uId and DBM:GetUnitRoleIcon(uId) or "", unitName, DBM:IconNumToTexture(grabIcon))
	if uId then
		local raidIndex = UnitInRaid(uId)
		if raidIndex then
			local name, _, subgroup, _, _, fileName = GetRaidRosterInfo(raidIndex + 1)
			if name == unitName then
				self:AddEntry(name, subgroup or 0, fileName, grabIcon)
			end
		end
	end
	if unitName == UnitName("player") then
		specWarnYouAreValkd:Show()
		specWarnYouAreValkd:Play("targetyou")
	end
	if DBM:IsInGroup() and self.Options.AnnounceValkGrabs and DBM:GetRaidRank() > 1 then
		local channel = (IsInRaid() and "RAID") or "PARTY"
		if self.Options.ValkyrIcon then
			SendChatMessage(L.ValkGrabbedIcon:format(grabIcon, unitName), channel)
		else
			SendChatMessage(L.ValkGrabbed:format(unitName), channel)
		end
	end
	grabIcon = grabIcon + 1
end

function mod:SPELL_CAST_START(args)
	local spellId = args.spellId

	if args:IsSpellID(72143, 72146, 72147, 72148) then
		local shamblingCount = DBM:tIndexOf(shamblingHorrorsGUIDs, args.sourceGUID)
		warnShamblingEnrage:Show(args.sourceName)
		specWarnEnrage:Show()
		timerEnrageCD:Stop(shamblingCount, args.sourceGUID)
		timerEnrageCD:Unschedule(nil, shamblingCount, args.sourceGUID)
		timerEnrageCD:Start(nil, shamblingCount, args.sourceGUID)
		timerEnrageCD:Schedule(25, nil, shamblingCount, args.sourceGUID)

	elseif spellId == 73650 then
		warnRestoreSoul:Show()
		timerRestoreSoul:Start()
		if self.Options.RemoveImmunes then
			self:Schedule(39.99, RemoveImmunes, self)
		end

	elseif args:IsSpellID(69242, 73800, 73801, 73802) then
		timerSoulShriekCD:Start(args.sourceGUID)
	elseif args:IsSpellID(68980, 74325, 74326, 74327) then
		timerHarvestSoul:Start(args.destName)
		timerHarvestSoulCD:Start()
		if args:IsPlayer() then
			specWarnHarvestSoul:Show()
			specWarnHarvestSoul:Play("targetyou")
		else
			warnHarvestSoul:Show(args.destName)
		end
		if self.Options.HarvestSoulIcon then
			self:SetIcon(args.destName, 5, 5)
		end
	end
	if bossCastNames[args.spellName] then
		bossCastStart(self, args.spellName)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if args:IsSpellID(70337, 73912, 73913, 73914) then
		lastPlague = args.destName
		warnNecroticPlague:Show(lastPlague)
		timerNecroticPlagueCD:Start()
		timerNecroticPlagueCleanse:Start()
		if args:IsPlayer() then
			specWarnNecroticPlague:Show()
			soundNecroticOnYou:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\necroticOnYou.mp3")
		end
		if self.Options.NecroticPlagueIcon then
			self:SetIcon(lastPlague, 4, 5)
		end
	elseif args:IsSpellID(69409, 73797, 73798, 73799) then
		self.vb.soulReaperCount = self.vb.soulReaperCount + 1
		timerSoulreaperCD:Cancel()
		warnSoulreaper:Show(self.vb.soulReaperCount, args.destName)
		specwarnSoulreaper:Show(args.destName)
		timerSoulreaper:Start(args.destName)
		timerSoulreaperCD:Start(nil, self.vb.soulReaperCount+1)
		soundSoulReaperSoon:Schedule(30.5-2.5, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\soulreaperSoon.mp3")
		if args:IsPlayer() then
			specWarnSoulreaper:Show()
			specWarnSoulreaper:Play("defensive")
		else
			specWarnSoulreaperOtr:Show(args.destName)
			specWarnSoulreaperOtr:Play("tauntboss")
		end
	elseif spellId == 69200 then
		self.vb.ragingSpiritCount = self.vb.ragingSpiritCount + 1
		timerSoulShriekCD:Start(20, args.destName)
		if args:IsPlayer() then
			specWarnRagingSpirit:Show()
			specWarnRagingSpirit:Play("targetyou")
		else
			warnRagingSpirit:Show(args.destName)
		end
		if self.vb.phase == 1.5 then
			timerRagingSpiritCD:Start(nil, self.vb.ragingSpiritCount)
		else
			timerRagingSpiritCD:Start(15.0, self.vb.ragingSpiritCount)
		end
		if self.Options.RagingSpiritIcon then
			self:SetIcon(args.destName, 6, 5)
		end
	elseif spellId == 72762 and args.destName then
		self:DefileTarget(args.destName, DBM:GetRaidUnitId(args.destName))
	elseif spellId == 73539 and args.destName then
		self:TrapTarget(args.destName, DBM:GetRaidUnitId(args.destName))
	elseif spellId == 74445 and args.destName then
		self:ValkyrGrab(args.destName, DBM:GetRaidUnitId(args.destName))
	end
	if bossCastNames[args.spellName] then
		bossCastStart(self, args.spellName)
	end
end

function mod:SPELL_DISPEL(args)
	local extraSpellId = args.extraSpellId
	if type(extraSpellId) == "number" and (extraSpellId == 70337 or extraSpellId == 73912 or extraSpellId == 73913 or extraSpellId == 73914 or extraSpellId == 70338 or extraSpellId == 73785 or extraSpellId == 73786 or extraSpellId == 73787) then
		if self.Options.NecroticPlagueIcon then
			self:SetIcon(args.destName, 0)
		end
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId

	if spellId == 28747 then
		specWarnEnrageLow:Show()
	elseif args:IsSpellID(72754, 73708, 73709, 73710) and args:IsPlayer() and self:AntiSpam(2, 1) then
		specWarnGTFO:Show(args.spellName)
		specWarnGTFO:Play("watchfeet")
		soundDefileOnYou:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\defileOnYou.mp3")
	end
	if args:IsSpellID(72754, 73708, 73709, 73710) and args.destName and GetTime() - defileCastTime < 4 then
		self:DefileTarget(args.destName, DBM:GetRaidUnitId(args.destName))
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args:IsSpellID(70338, 73785, 73786, 73787) then
		if self.Options.AnnouncePlagueStack and DBM:GetRaidRank() > 0 then
			if args.amount % 10 == 0 or (args.amount >= 10 and args.amount % 5 == 0) then
				SendChatMessage(L.PlagueStackWarning:format(args.destName, (args.amount or 1)), "RAID")
			elseif (args.amount or 1) >= 30 and not warnedAchievement then
				SendChatMessage(L.AchievementCompleted:format(args.destName, (args.amount or 1)), "RAID_WARNING")
				warnedAchievement = true
			end
		end
	end
end

function mod:SPELL_SUMMON(args)
	local spellId = args.spellId
	if spellId == 69037 then
		valkyrWave(self)
		if self.Options.ShowFrame then
			self:CreateFrame()
		end
		if self.Options.ValkyrIcon then
			self:ScanForMobs(args.destGUID, 2, self.vb.valkIcon, 1, nil, 12, "ValkyrIcon")
		end
		self.vb.valkIcon = self.vb.valkIcon + 1

	elseif spellId == 70372 then
		tinsert(shamblingHorrorsGUIDs, args.destGUID)
		local shamblingCount = DBM:tIndexOf(shamblingHorrorsGUIDs, args.destGUID)
		warnShamblingSoon:Cancel()
		warnShamblingHorror:Show()
		warnShamblingSoon:Schedule(55)
		timerShamblingHorror:Start()
		timerEnrageCD:Start(11, shamblingCount, args.destGUID)
		timerEnrageCD:Schedule(14, nil, shamblingCount, args.destGUID)
	end
end

function mod:SPELL_DAMAGE(_, _, _, destGUID, _, _, spellId, spellName)
	if (spellId == 68983 or spellId == 73791 or spellId == 73792 or spellId == 73793) and destGUID == UnitGUID("player") and self:AntiSpam(2, 3) then
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:UNIT_HEALTH(uId)
	if self:IsHeroic() and self:GetUnitCreatureId(uId) == 36609 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.55 and not warnedValkyrGUIDs[UnitGUID(uId)] then
		warnedValkyrGUIDs[UnitGUID(uId)] = true
		specWarnValkyrLow:Show()
		specWarnValkyrLow:Play("stopattack")
	end
	if self.vb.phase == 1 and not self.vb.warned_preP2 and self:GetUnitCreatureId(uId) == 36597 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.73 then
		self.vb.warned_preP2 = true
		warnPhase2Soon:Show()
	elseif self.vb.phase == 2 and not self.vb.warned_preP3 and self:GetUnitCreatureId(uId) == 36597 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.43 then
		self.vb.warned_preP3 = true
		warnPhase3Soon:Show()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg == L.LKPull or msg:find(L.LKPull) then
		self:SendSync("CombatStart")
		if self.Options.ShowFrame then
			self:CreateFrame()
		end
	elseif msg == L.YellValkyr or msg:find(L.YellValkyr, 1, true) then
		valkyrWave(self)
	elseif msg == L.YellWinter or msg:find(L.YellWinter, 1, true) then
		bossCastStart(self, GetSpellInfo(68981))
	elseif msg == L.YellQuake or msg:find(L.YellQuake, 1, true) then
		bossCastStart(self, GetSpellInfo(72262))
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 37698 then
		local shamblingCount = DBM:tIndexOf(shamblingHorrorsGUIDs, args.sourceGUID)
		timerEnrageCD:Stop(shamblingCount, args.sourceGUID)
		timerEnrageCD:Unschedule(nil, shamblingCount, args.sourceGUID)
	elseif cid == 36701 then
		timerSoulShriekCD:Cancel(args.sourceGUID)
	end
end

function mod:UNIT_AURA_UNFILTERED(uId)
	local name = DBM:GetUnitFullName(uId)
	if (not name) or (name == lastPlague) then return end
	local _, _, _, _, _, _, expires, _, _, _, spellId = DBM:UnitDebuff(uId, plagueHop)
	if not spellId or not expires then return end
	if (spellId == 73787 or spellId == 70338 or spellId == 73785 or spellId == 73786) and expires > 0 and not plagueExpires[expires] then
		plagueExpires[expires] = true
		warnNecroticPlagueJump:Show(name)
		timerNecroticPlagueCleanse:Restart()
		if name == UnitName("player") and not mod:IsTank() then
			specWarnNecroticPlague:Show()
			soundNecroticOnYou:Play("Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\necroticOnYou.mp3")
		end
		if self.Options.NecroticPlagueIcon then
			self:SetIcon(uId, 4, 5)
		end
	end
end

function mod:UNIT_ENTERING_VEHICLE(uId)
	local unitName = UnitName(uId)
	DBM:Debug("UNIT_ENTERING_VEHICLE Val'kyr check for "..  unitName .. " (" .. uId .. "): UnitInVehicle is returning " .. (UnitInVehicle(uId) or "nil") .. " and UnitInRange is returning " .. (UnitInRange(uId) or "nil") .. " with distance: " .. DBM.RangeCheck:GetDistance(uId) .."yd. Checking if it is already cached: " .. (valkyrTargets[unitName] and "true" or "nil."), 3)

	if UnitInVehicle(uId) then
		self:ValkyrGrab(unitName, uId)
	end
end

function mod:UNIT_EXITING_VEHICLE(uId)
	local unitName = UnitName(uId)
	DBM:Debug(unitName .. " (" .. uId .. ") has exited a vehicle. Confirming API: " .. (UnitInVehicle(uId) or "nil"))
	if valkyrTargets[unitName] then
		valkyrTargets[unitName] = nil
		self:RemoveEntry(unitName)
	end
end

bossCastStart = function(self, spellName)
	if not self:AntiSpam(3, spellName) then return end
	if spellName == GetSpellInfo(68981) then
		self:SetStage(self.vb.phase + 0.5)
		self.vb.ragingSpiritCount = 1
		warnRemorselessWinter:Show()
		timerPhaseTransition:Start()
		timerRagingSpiritCD:Start(4, self.vb.ragingSpiritCount)
		warnShamblingSoon:Cancel()
		timerShamblingHorror:Cancel()
		timerDrudgeGhouls:Cancel()
		timerSummonValkyr:Cancel()
		timerInfestCD:Cancel()
		soundInfestSoon:Cancel()
		timerNecroticPlagueCD:Cancel()
		timerTrapCD:Cancel()
		timerHarvestSoulCD:Cancel()
		timerHarvestSoulsCD:Cancel()
		timerDefileCD:Cancel()
		warnDefileSoon:Cancel()
		warnDefileSoon:CancelVoice()
		timerSoulreaperCD:Cancel()
		soundSoulReaperSoon:Cancel()
		self:RegisterShortTermEvents(
			"UPDATE_MOUSEOVER_UNIT",
			"UNIT_TARGET_UNFILTERED"
		)
		self:DestroyFrame()
		if self.Options.RangeFrame then
			DBM.RangeCheck:Show(8)
		end
	elseif spellName == GetSpellInfo(72262) then
		self.vb.ragingSpiritCount = 0
		warnQuake:Show()
		timerRagingSpiritCD:Cancel()
		self:SetStage(self.vb.phase + 0.5)
		self:UnregisterShortTermEvents()
		NextPhase(self)
		if self.Options.RangeFrame then
			DBM.RangeCheck:Hide()
		end
	elseif spellName == GetSpellInfo(70358) then
		warnDrudgeGhouls:Show()
		timerDrudgeGhouls:Start()
	elseif spellName == GetSpellInfo(70498) then
		warnSummonVileSpirit:Show()
		timerVileSpirit:Start()
	elseif spellName == GetSpellInfo(70541) then
		self.vb.infestCount = self.vb.infestCount + 1
		warnInfest:Show(self.vb.infestCount)
		specWarnInfest:Show(self.vb.infestCount)
		timerInfestCD:Start(nil, self.vb.infestCount+1)
		soundInfestSoon:Cancel()
		soundInfestSoon:Schedule(22.5-2, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\infestSoon.mp3")
	elseif spellName == GetSpellInfo(72762) then
		self.vb.defileCount = self.vb.defileCount + 1
		defileCastTime = GetTime()
		self:Unschedule(scanBossTarget)
		scanBossTarget(self, "DefileTarget", 18)
		warnDefileSoon:Cancel()
		warnDefileSoon:CancelVoice()
		warnDefileSoon:Schedule(27, self.vb.defileCount+1)
		warnDefileSoon:ScheduleVoice(27, "scatter")
		timerDefileCD:Start(nil, self.vb.defileCount+1)
	elseif spellName == GetSpellInfo(73539) then
		self:Unschedule(scanBossTarget)
		scanBossTarget(self, "TrapTarget", 10)
		timerTrapCD:Start()
	elseif spellName == GetSpellInfo(73654) then
		specWarnHarvestSouls:Show()
		timerHarvestSoulsCD:Start()
		timerDefileCD:Cancel()
		warnDefileSoon:Cancel()
		warnDefileSoon:CancelVoice()
		timerDefileCD:Start(55, self.vb.defileCount+1)
		warnDefileSoon:Schedule(50, self.vb.defileCount+1)
		warnDefileSoon:ScheduleVoice(50, "scatter")
		timerSoulreaperCD:Cancel()
		soundSoulReaperSoon:Cancel()
		timerSoulreaperCD:Start(62, self.vb.soulReaperCount+1)
		soundSoulReaperSoon:Schedule(62-2.5, "Interface\\AddOns\\DBM-Core\\sounds\\RaidAbilities\\soulreaperSoon.mp3")
		if timerVileSpirit:IsStarted() then
			timerVileSpirit:AddTime(52.5)
		else
			timerVileSpirit:Start(52.5)
		end
		self:SetWipeTime(60)
		self:Schedule(60, RestoreWipeTime, self)
	elseif spellName == GetSpellInfo(72350) then
		self:SetWipeTime(190)
		self:Stop()
		self:ClearIcons()
		timerRoleplay:Start()
	end
end

function mod:UNIT_SPELLCAST_START(_, spellName)
	if bossCastNames[spellName] then
		bossCastStart(self, spellName)
	end
end

valkyrWave = function(self)
	if not self:AntiSpam(5, "valkyr") then return end
	table.wipe(valkyrTargets)
	grabIcon = 2
	self.vb.valkIcon = 2
	self.vb.valkyrWaveCount = self.vb.valkyrWaveCount + 1
	warnSummonValkyr:Show(self.vb.valkyrWaveCount)
	timerSummonValkyr:Start(nil, self.vb.valkyrWaveCount+1)
	if timerDefileCD:GetRemaining(self.vb.defileCount+1) < (self:IsDifficulty("normal25", "heroic25") and 5 or 4) then
		timerDefileCD:Start(self:IsDifficulty("normal25", "heroic25") and 5 or 4, self.vb.defileCount+1)
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == GetSpellInfo(74361) or spellName == GetSpellInfo(69037) then
		valkyrWave(self)
	end
end

function mod:UPDATE_MOUSEOVER_UNIT()
	if DBM:GetUnitCreatureId("mouseover") == 36633 then
		local sphereGUID = UnitGUID("mouseover")
		local sphereTarget = UnitName("mouseovertarget")
		if sphereGUID and sphereTarget and not iceSpheresGUIDs[sphereGUID] then
			local sphereString = ("%s\t%s"):format(sphereTarget, sphereGUID)
			self:SendSync("SphereTarget", sphereString)
		end
	end
end

function mod:UNIT_TARGET_UNFILTERED(uId)
	if DBM:GetUnitCreatureId(uId.."target") == 36633 then
		local sphereGUID = UnitGUID(uId.."target")
		local sphereTarget = UnitName(uId.."targettarget")
		if sphereGUID and sphereTarget and not iceSpheresGUIDs[sphereGUID] then
			iceSpheresGUIDs[sphereGUID] = sphereTarget
			warnIceSpheresTarget:Show(sphereTarget)
			if sphereTarget == UnitName("player") then
				specWarnIceSpheresYou:Show()
				specWarnIceSpheresYou:Play("iceorbmove")
			end
		end
	end
end

function mod:OnSync(msg, target)
	if msg == "CombatStart" then
		timerCombatStart:Start()

	elseif msg == "SphereTarget" then
		local sphereTarget, sphereGUID = strsplit("\t", target)
		if sphereTarget and sphereGUID and not iceSpheresGUIDs[sphereGUID] then
			iceSpheresGUIDs[sphereGUID] = sphereTarget
			warnIceSpheresTarget:Show(sphereTarget)
			if sphereTarget == UnitName("player") then
				specWarnIceSpheresYou:Show()
				specWarnIceSpheresYou:Play("iceorbmove")
			end
		end
	end
end