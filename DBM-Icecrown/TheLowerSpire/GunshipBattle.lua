local mod	= DBM:NewMod("GunshipBattle", "DBM-Icecrown", 1)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("20260830000000")
local addsIcon
local bossID
local enemyShipID
mod:RegisterCombat("combat")
if UnitFactionGroup("player") == "Alliance" then

	mod:RegisterKill("yell", L.KillAlliance)
	mod:SetCreatureID(36939, 37215)
mod:SetEncounterID(847)--No ES fires this combat
	addsIcon = 23334
	bossID = 36939
	enemyShipID = 37215
else

	mod:RegisterKill("yell", L.KillHorde)
	mod:SetCreatureID(36948, 37540)
	addsIcon = 23336
	bossID = 36948
	enemyShipID = 37540
end
mod:SetHotfixNoticeRev(20220921000000)
mod:SetMinSyncRevision(20220921000000)

mod:RegisterEvents(
	"CHAT_MSG_MONSTER_YELL"
)

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 71195 71193 71188 69652 69651 72306 69638 69705",
	"SPELL_AURA_APPLIED_DOSE 72306 69638",
	"SPELL_CAST_START 69705",
	"UNIT_DIED",
	"UNIT_HEALTH boss1 boss2",
	"UNIT_SPELLCAST_SUCCEEDED boss1 boss2"
)

local warnBelowZero			= mod:NewSpellAnnounce(69705, 4)
local warnMageSoon			= mod:NewSoonAnnounce(69705, 2)
local warnExperienced		= mod:NewTargetNoFilterAnnounce(71188, 1, nil, false)
local warnVeteran			= mod:NewTargetNoFilterAnnounce(71193, 2, nil, false)
local warnElite				= mod:NewTargetNoFilterAnnounce(71195, 3, nil, false)
local warnBattleFury		= mod:NewStackAnnounce(69638, 2, nil, "Tank|Healer", 2)
local warnBladestorm		= mod:NewSpellAnnounce(69652, 3, nil, "Melee")
local warnWoundingStrike	= mod:NewTargetNoFilterAnnounce(69651, 2)
local warnAddsSoon			= mod:NewAnnounce("WarnAddsSoon", 2, addsIcon)

local timerCombatStart		= mod:NewCombatTimer(47.5)
local timerBelowZeroCD		= mod:NewNextTimer(30, 69705, nil, nil, nil, 5, nil, DBM_COMMON_L.DAMAGE_ICON, nil, 1)
local timerBelowZeroCast	= mod:NewCastTimer(5, 69705, nil, nil, nil, 5)
local timerBattleFuryActive	= mod:NewBuffActiveTimer(17, 69638, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerAdds				= mod:NewTimer(60, "TimerAdds", addsIcon, nil, nil, 1)
local timerBladestormCD		= mod:NewCDTimer(25, 69652, nil, "Melee", nil, 3)
local timerWoundingStrikeCD	= mod:NewCDTimer(7, 69651, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON)

local soundFreeze			= mod:NewSound(69705)

mod:RemoveOption("HealthFrame")

mod.vb.firstMage = false
mod.vb.mageSoon = false

local function Adds(self)

	timerAdds:Start()
	warnAddsSoon:Cancel()
	warnAddsSoon:Schedule(55)

end

function mod:OnCombatStart(delay)
	DBM.BossHealth:Clear()
	timerAdds:Start(12-delay)
	warnAddsSoon:Schedule(7-delay)

	self.vb.firstMage = false
	self.vb.mageSoon = false
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 71195 then
		warnElite:Show(args.destName)
	elseif spellId == 71193 then
		warnVeteran:Show(args.destName)
	elseif spellId == 71188 then
		warnExperienced:Show(args.destName)
	elseif spellId == 69652 then
		warnBladestorm:Show()
		timerBladestormCD:Start()
	elseif spellId == 69651 then
		warnWoundingStrike:Show(args.destName)
		timerWoundingStrikeCD:Start()
	elseif args:IsSpellID(72306, 69638) and self:GetCIDFromGUID(args.destGUID) == bossID then
		timerBattleFuryActive:Start()
	elseif spellId == 69705 and self:AntiSpam(1, 1) then
		soundFreeze:Play("Interface\\AddOns\\DBM-Core\\sounds\\Alert.mp3")
	end
end

function mod:SPELL_AURA_APPLIED_DOSE(args)
	if args:IsSpellID(72306, 69638) and self:GetCIDFromGUID(args.destGUID) == bossID then
		if args.amount % 5 == 0 then
			warnBattleFury:Show(args.destName, args.amount or 1)
		end
		timerBattleFuryActive:Start()
	end
end

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 37116 or cid == 37117 then
		timerBelowZeroCast:Cancel()
		timerBelowZeroCD:Start()
	end
end

function mod:UNIT_HEALTH(uId)
	if self.vb.firstMage or self.vb.mageSoon then return end
	if self:GetUnitCreatureId(uId) ~= enemyShipID then return end
	local hp = UnitHealth(uId) / UnitHealthMax(uId)
	if hp <= 0.93 then
		self.vb.mageSoon = true
		warnMageSoon:Show()
	end
end

function mod:SPELL_CAST_START(args)
	if args.spellId == 69705 then
		warnBelowZero:Show()
		timerBelowZeroCast:Cancel()
		timerBelowZeroCD:Cancel()
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, spellName)
	if spellName == GetSpellInfo(72340) then
		DBM:EndCombat(self)
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if msg:find(L.PullAlliance) then
		timerCombatStart:Start()
	elseif msg:find(L.PullHorde) then
		timerCombatStart:Start(45)
	elseif (msg:find(L.AddsAlliance) or msg:find(L.AddsHorde)) and self:IsInCombat() then

		Adds(self)
	elseif (msg:find(L.MageAlliance) or msg == L.MageAlliance or msg:find(L.MageHorde) or msg == L.MageHorde) and self:IsInCombat() then
		self.vb.firstMage = true
		timerBelowZeroCD:Cancel()
		timerBelowZeroCast:Start()
	end
end