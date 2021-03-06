﻿
local debuffnumber = 3

DebuffFilter = CreateFrame("Frame")
DebuffFilter.cache = {}

local DEFAULT_BUFF = 3
local DEFAULT_DEBUFF = 3

local strfind = string.find
local strmatch = string.match
local tblinsert = table.insert
local tblremove= table.remove
local mathfloor = math.floor
local mathabs = math.abs
local bit_band = bit.band
local tblsort = table.sort
local Ctimer = C_Timer.After
local substring = string.sub

function DebuffFilter:OnLoad()

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	CompactRaidFrameContainer:HookScript("OnEvent", DebuffFilter.OnRosterUpdate)
	CompactRaidFrameContainer:HookScript("OnHide", DebuffFilter.ResetStyle)
	CompactRaidFrameContainer:HookScript("OnShow", DebuffFilter.OnRosterUpdate)
end

-- When roster updated, auto apply arena style or reset style
function DebuffFilter:OnRosterUpdate()
	local _,areaType = IsInInstance()
	if not CompactRaidFrameContainer:IsVisible() then return end
	local n = GetNumGroupMembers()
	if n <= 40 then DebuffFilter:ApplyStyle() else DebuffFilter:ResetStyle() end
end

-- If in raid reset style
function DebuffFilter:OnZoneChanged()
	local _,areaType = IsInInstance()
	self:ResetStyle()
	--if areaType ~= "raid" then self:ApplyStyle() end
end

hooksecurefunc("CompactRaidFrameContainer_SetFlowSortFunction", function(_,_)
	DebuffFilter:ResetStyle()
	DebuffFilter:OnRosterUpdate()
end)

function DebuffFilter:ApplyStyle() ----- Find A Way to Always Show Debuffs
	if CompactRaidFrameManager.container.groupMode == "flush" then
		for i = 1,80 do
			local f = _G["CompactRaidFrame"..i]
			if f and not self.cache[f] and f.inUse and f.maxBuffs ~= 0 and #f.buffFrames == DEFAULT_BUFF and f.unit and not strfind(f.unit,"pet") and not strfind(f.unit,"target") then
				self:ApplyFrame(f)
				self:UpdateAura(f.unit)
			end
			if f and not f.inUse and self.cache[f] then
				self:ResetFrame(f)
			end
		end
	elseif CompactRaidFrameManager.container.groupMode == "discrete" then
		for i = 1,8 do
			for j = 1,5 do
				local f = _G["CompactRaidGroup"..i.."Member"..j]
				if f and not self.cache[f] and f.maxBuffs ~= 0 and #f.buffFrames == DEFAULT_BUFF and f.unit and not strfind(f.unit,"pet") and not strfind(f.unit,"target") then
					self:ApplyFrame(f)
					self:UpdateAura(f.unit)
				end
				if f and not f.unit and self.cache[f] then
					self:ResetFrame(f)
				end
				local f = _G["CompactPartyFrameMember"..j] --- Does
				if f and not self.cache[f] and f.maxBuffs ~= 0 and #f.buffFrames == DEFAULT_BUFF and f.unit and not strfind(f.unit,"pet") and not strfind(f.unit,"target") then
					self:ApplyFrame(f)
					self:UpdateAura(f.unit)
				end
				if f and not f.unit and self.cache[f] then
					self:ResetFrame(f)
				end
			end
		end
	end
end

-- data from LoseControl
local spellIds = {

--DONT SHOW
	[57723] = "Hide", --Exhaustion
	[57724] = "Hide", --Sated
	[264689] = "Hide", --Fatigued
	[80354] = "Hide", --Temporal Displacement
	[287825] = "Hide", --Lethargy
	[206151] = "Hide", --Challenger's Burden
	[295339] = "Hide", --Will to Survive
	[306474] = "Hide", --Recharging
	[313471] = "Hide", --Faceless Masks
	[110310] = "Hide", --Dampening
	[338906] = "Hide", -- The Jailer's Chains
---Priority--
	[317265] = "Priority", --Infinite Stars
	[318187] = "Priority", --Gushing Wounds
---WARNINGS---
  --DEATH KNIGHT
  [123981] = "Warning", --Perdition
  --Mage
	[87024] = "Warning", --Cauterized
	[41425] = "Warning", --Hypothermia
  --ROGUE
	[45181] = "Warning", --Cheated Death
  --PALLY
	[25771] = "Warning", --Forbearance
	--DH
	[209261] = "Warning", --Uncontained Fel
	--GENERAL WARNINGS
	[46392] = "Warning", --Focused Assault (flag carrier, increasing damage taken by 10%)
	[195901]= "Warning", --Adapted
	[288756]= "Warning", --Gladiator's Safeguard

	[315179]= "Biggest", --Inevitable Doom
	[315161]= "Warning", --Eye of Corruption
	[319695]= "Warning", --Grand Delusions
---GENERAL DANGER---
  --HUNTER
	--[209967] = "Biggest", -- Dire Beast: Basilisk
	--[202797] = "Bigger", -- Viper Sting
	--[202914] = "Bigger", -- Spider Sting
	--[202900] = "Big", -- Scorpid Sting
	--[203268] = "Big", -- Sticky Tar
	--[131894] = "Big", -- A Murder of Crows
  --SHAMAN
	[188389] =  "Warning", --Flame Shock
	--[208997] = "Big", -- Counterstrike Totem
	--[206647] = "Big", -- Electrocute
	--DEATH KNIGHT
	--[77606] = "Biggest", -- Dark Simulacrum
	--[130736] = "Big", -- Soul Reaper
	--[48743] = "Big", -- Death Pact
	[233397] = "Warning", -- Delirium
	[214975] = "Warning", -- Heartstop Aura
	[199719] = "Warning", -- Heartstop Aura
	--DRUID
	--[232559] = "Big", -- Thorns
	--[236021] = "Big", -- Ferocious Wound
	--[200947] = "Big", -- Encroaching Vines
	--MONK
	[115080] = "Biggest", -- Touch of Death
	[122470] = "Bigger", -- Touch of Karma
	[124280] = "Big", -- Touch of Karma Dot
  --PALLY
	--[206891] = "Big", -- Focused Assault
  --PRIEST
	--[322461] = "Big" --Thoughtstolen
	--[205369] = "Bigger", -- Mind Bomb
	--[199845] = "Bigger", --Psyflay
	--[247777] = "Big", --Mind Trauma
	--[214621] = "Big", --Schism
	[335467] = "Big", --Devouring Plague
	--ROGUE
	[79140] = "Biggest", -- Vendetta
	[198259] ="Biggest", --Plunder Armor
	[207736] = "Big", -- Shadowy Duel
	[212183] = "Big", -- Smoke Bomb
	--[197091] ="Biggest", --Neurotoxin
	[197051] = "Warning", --Mind-Numbing Poison
	--LOCK
	--[80240] = "Bigger", -- Havoc
	--[200587] = "Bigger", -- Fel Fissure
	--[199954] = "Big", -- Curse of Fragility
	--[199890] = "Big", -- Curse of Tongues
	--[199892] = "Big", -- Curse of Weakness
	--[48181] = "Big", -- Haunt
	--[234877] = "Big", -- Curse of Shadows
	--[196414] = "Big", -- Eradication
	--[233582] = "Warning", --Entrenched Flame
		[205179] =  "Warning", --Phantom Singularity
  --WARRIOR
  --[198819] = "Bigger", -- Sharpen
  --[236273] = "Big", -- Duel
  --[208086] = "Big", -- Colossus Smash
	--DEMON HUNTER
	[206649] = "Bigger", -- Eye of Leotheras
	--[206491] = "Big", -- Nemesis
	--[207744] = "Big", -- Fiery Brand

	--COVENANTS
	[323673] = "Big", -- Priest Mindgames (Venthyr)
	[314793] = "Big", -- Mage Mirrors of Torment (Venthyr)
	[328305] = "Big", -- Rogue Sepsis (NightFae)
	[325640] = "Big", --Soulrot (Nightfae)
	[320224] = "Biggest", --Potender (Nightfae)

	--TRINKETS
	--[293491] = "Biggest", -- Cyclotronic Blast
	[302144] = "Bigger", -- Gladiator’s Maledict S2
	[294127] = "Bigger", -- Gladiator’s Maledict S2
	[305249] = "Bigger", -- Gladiator’s Maledict S3 (Absorb)
	[305252] = "Bigger", -- Gladiator’s Maledict S3 (On Hit Dot)
	[271465] = "Big", -- Rotcrusted Voodoo Doll
	[313148] = "Big", -- Obsidian Claw
	[318476] = "Big", -- Obsidian Claw

---PVE---
--RAID
--  [240559] = "Bigger", -- Incubation Fluid

--MYTHICS AFFIX'S
	[240559] = "Bigger", -- Grievous Wound
	[209858] = "Bigger", -- Necrotic Wound
	--Voidweaver Mal'thir
	[314411] = "Bigger", --Lingering Doubt
	[314406] = "Bigger", -- Crippling Pestilence
	--Samh'rek, Beckoner of Chaos
	[314478] = "Bigger", --Cascading Terror
	[314531] = "Bigger", --Tear Flesh
	--Urg'roth, Breaker of Heroes
	[314308] = "Bigger", --Spirit Breaker

--TORGHAST
	[296839] = "Bigger", -- Sledgehammer
	[294526] = "Bigger", -- Curse of Frailty

--VISIONS OF ORG
	[297315] = "Bigger", -- Void Buffet
	[298510] = "Bigger", -- Aqiri Mind Toxin

--FREEHOLD
	[257436] = "Bigger", -- Poisoning Strike
	[257437] = "Bigger", -- Poisoning Strike
	[258323] = "Bigger", -- Infected Wound
	[257775] = "Bigger", -- Plague Step
	[274555] = "Bigger", -- Scabrous Bite
	[278467] = "Bigger", -- Caustic Freehold Brew
	[257739] = "Bigger", -- Blind Rage
	[256363] = "Bigger", -- Ripper Punch
	[257908] = "Bigger", -- Oiled Blade

--KING'S REST
	[265773] = "Bigger", -- Spit Gold (265773)
	[265914] = "Bigger", -- Molten Gold (265914)
	[270084] = "Bigger", -- Axe Barrage (270084)
	[270865] = "Bigger", -- Hidden Blade (270865)
	[271564] = "Bigger", -- Embalming Fluid (271564)
	[267763] = "Bigger", -- Wretched Discharge
	[267618] = "Bigger", -- Drain Fluids (267618)
	[267626] = "Bigger", -- Dessication (267626)
	[270487] = "Bigger", -- Severing Blade (270487)
	[270507] = "Bigger", -- Poison Barrage (270507) (WA for Fixated)
	[266238] = "Bigger", -- Shattered Defenses (266238)
	[266231] = "Bigger", -- Severing Axe (266231)
	[267273] = "Bigger", -- Pioson Nova ???
	[272388] = "Bigger", -- Shadow Barrage (272388)
	--[] = "Bigger", -- Pool of Darkness ???
	[271640] = "Bigger", -- Dark Revelation (271640)

--WAYCREST MANOR
	[260703] = "Bigger", -- Unstable Runic Mark (260703)
	[268088] = "Bigger", --Aura of Dread (268088)[Doesnt Work!]
	[260741] = "Bigger", --Jagged Nettles (260741)
	------- Right Room 1
	[263943] = "Biggest", --Etch
	[263905] = "Bigger", --Marking Cleave
	[264520] = "Big", --Serving Serpent
	--------Right Hall Way 1
	[271178] = "Bigger", --Ravaging Leap
	--------Court Yard
	[265761] = "Biggest", --Thorned Barrage
	[264556] = "Bigger", --Tearing Strike
	[264050] = "Big", --Infected Thorn
	--------Left Room (sisters)
	[266036] = "Biggest", --Drain Essence
	[266035] = "Bigger", --Bone Splinter
	--------Downstairs Hall
	[265881] = "Biggest", --Decaying Touch
	[265880] = "Bigger", --Dread Mark
	[265882] = "Warning", --Lingering Dread
	--------Downstairs
	[264378] = "Biggest", --Fragment Souls
	[264105] = "Bigger", --Runic Mark

--UNDERROT
	[265019] = "Bigger", -- Savage Cleave
	[265568] = "Bigger", -- Dark Omen
	[266107] = "Bigger", -- Thirst For Blood
	[273226] = "Bigger", -- Decaying Spores
	[269301] = "Bigger", -- Putrid Blood

--TOL DAGOR
	[258079] = "Bigger", -- Massive Chomp
	[258128] = "Biggest", -- Debilitating Shout
	[257028] = "Bigger", -- Fuselighter
	[256038] = "Bigger", -- Deadeye
	[256105] = "Bigger", -- Explosive Burst
	[265889] = "Bigger", -- Torch Strike

--TEMPLE OF SETHRALISS
	[266923] = "Bigger", -- Galvanize
	[263371] = "Bigger", -- Conduction
	[267027] = "Bigger", -- Cytotoxin
	[272699] = "Bigger", -- Venomous Spit
	[268007] = "Biggest", -- Heart Attack

--ATAL'DAZAR
	[255558] = "Bigger", -- Tainted Blood
	[255582] = "Bigger", -- Molten Gold
	[252687] = "Bigger", -- Venomfang Strike
	[250096] = "Bigger", -- Wracking Pain (Yazma)
	[257407] = "Biggest", -- Pursuit (Rezan)
	[250372] = "Big", -- Lingering Nausea [Vol'kaal]
	[258723] = "Biggest", -- Grotesque Pool [Add Pool]
	[250585] = "Biggest", -- Toxic Pool [Vol'kaal]
	[260668] = "Biggest", -- Transfusion (Add)
	[255835] = "Biggest", -- Transfusion (Boss Priestess)
	[256577] = "Biggest", -- Soulfest (Yazma)
--SIEGE OF BORULAS
	[279893] = "Bigger", -- Blood in the Water
	[273470] = "Bigger", -- Gut Shot
	[257168] = "Bigger", -- Cursed Slash
	[257036] = "Bigger", -- Feral Charge
	[260954] = "Bigger", -- Iron Gaze
	[257459] = "Bigger", -- On the Hook
	[272588] = "Bigger", -- Rotting Wounds
	[275836] = "Bigger", -- Stinging Venom
	[272421] = "Warning", -- Sighted Artiller

--SHRINE OF THE STORM
	[264166] = "Bigger", -- Undertow
	[279893] = "Bigger", -- Blood in the Water
	[268322] = "Bigger", -- Touch of the Drowned
	[268214] = "Bigger", -- Carve Flash
	[267818] = "Bigger", -- Slicing Blast
	[267034] = "Bigger", -- Whispers of Power
	[274633] = "Bigger", -- Sundering Blow
	[268317] = "Bigger", -- Rip Mind
	[268315] = "Bigger", -- Rip Mind
	[140038] = "Bigger", -- Abyssal Strike

--MOTHERLODE
	[270882] = "Bigger", -- Blazing Azerite (Boss 1)
	[257544] = "Bigger", -- Jagged Cut (Boss 2)
	[257582] = "Priority", -- Raging Gaze (Boss 2)
	[259853] = "Bigger", -- Chemical Burn (Boss 3)
	[269298] = "Bigger", -- Widowmaker
	[263202] = "Bigger", -- Rocklance

--Operation - Junkyard
	[299438] = "Bigger", -- Sledgehammer

--Operation - Workshop
	[294929] = "Biggest", -- Death Blast
	[303678] = "Biggest", -- Shrapnel 20% Stacking Increased Dmg Taken
	[329326] = "Biggest", -- Dark Binding



}

local bgBiggerspellIds = {
}

local bgBigspellIds = {
--CC--
	[3355] = "True",		-- Freezing Trap
	[203337] = "True",		-- Freezing Trap (Diamond Ice - pvp honor talent)
	[24394] = "True",		-- Intimidation
	[213691] = "True",		-- Scatter Shot (pvp honor talent)

	[51514] = "True",		-- Hex
	[210873] = "True",		-- Hex (compy)
	[211010] = "True",		-- Hex (snake)
	[211015] = "True",		-- Hex (cockroach)
	[211004] = "True",		-- Hex (spider)
	[196942] = "True",		-- Hex (Voodoo Totem)
	[269352] = "True",		-- Hex (skeletal hatchling)
	[277778] = "True",		-- Hex (zandalari Tendonripper)
	[277784] = "True",		-- Hex (wicker mongrel)
	[77505] = "True",		-- Earthquake
	[118905] = "True",		-- Static Charge (Capacitor Totem)
	[305485] = "True",		-- Lightning Lasso
	[197214] = "True",		-- Sundering
	[118345] = "True",		-- Pulverize (Shaman Primal Earth Elemental)

	[108194] = "True",		-- Asphyxiate
	[221562] = "True",		-- Asphyxiate
	[207167] = "True",		-- Blinding Sleet
	[287254] = "True",		-- Dead of Winter (pvp talent)
	[210141] = "True",		-- Zombie Explosion (Reanimation PvP Talent)
	[91800] = "True",		-- Gnaw
	[91797] = "True",		-- Monstrous Blow (Dark Transformation)
	[334693] = "True",    -- Absolute Zero (Shadowlands Legendary Stun)

	[33786] = "True",		-- Cyclone
	[5211] = "True",		-- Mighty Bash
	[163505] = "True",		-- Rake
	[203123] = "True",		-- Maim
	[202244] = "True",		-- Overrun (pvp honor talent)
	[99] = "True",	-- Incapacitating Roar
	[2637] = "True",		-- Hibernate

	[118] = "True",		-- Polymorph
	[61305] = "True",		-- Polymorph: Black Cat
	[28272] = "True",		-- Polymorph: Pig
	[61721] = "True",		-- Polymorph: Rabbit
	[61780] = "True",		-- Polymorph: Turkey
	[28271] = "True",		-- Polymorph: Turtle
	[161353] = "True",		-- Polymorph: Polar bear cub
	[126819] = "True",		-- Polymorph: Porcupine
	[161354] = "True",		-- Polymorph: Monkey
	[61025] = "True",		-- Polymorph: Serpent
	[161355] = "True",		-- Polymorph: Penguin
	[277787] = "True",		-- Polymorph: Direhorn
	[277792] = "True",		-- Polymorph: Bumblebee
	[161372] = "True",		-- Polymorph: Peacock
	[82691] = "True",		-- Ring of Frost
	[140376] = "True",		-- Ring of Frost
	[31661] = "True",		-- Dragon's Breath

	[119381] = "True",		-- Leg Sweep
	[115078] = "True",		-- Paralysis
	[198909] = "True",		-- Song of Chi-Ji
	[202274] = "True",		-- Incendiary Brew (honor talent)
	[202346] = "True",		-- Double Barrel (honor talent)

	[853] = "True",		-- Hammer of Justice
	[105421] = "True",		-- Blinding Light
	[20066] = "True",		-- Repentance

	[605] = "True",		-- Dominate Mind
	[8122] = "True",		-- Psychic Scream
	[9484] = "True",		-- Shackle Undead
	[64044] = "True",		-- Psychic Horror
	[87204] = "True",		-- Sin and Punishment
	[226943] = "True",		-- Mind Bomb
	[205369] = "True",		-- Mind Bomb
	[200196] = "True",		-- Holy Word: Chastise
	[200200] = "True",		-- Holy Word: Chastise (talent)

	[2094] = "True",		-- Blind
	[1833] = "True",		-- Cheap Shot
	[1776] = "True",		-- Gouge
	[408] = "True",		-- Kidney Shot
	[6770] = "True",		-- Sap
	[199804] = "True",		-- Between the eyes

	[118699] = "True",		-- Fear
	[5484] = "True",    -- Howl of Terror
	[6789] = "True",		-- Mortal Coil
	[30283] = "True",		-- Shadowfury
	[710] = "True",		-- Banish
	[22703] = "True",		-- Infernal Awakening
	[213688] = "True",  	-- Fel Cleave (Fel Lord - PvP Talent)
	[89766] = "True",  	-- Axe Toss (Felguard/Wrathguard)
	[115268] = "True",	  -- Mesmerize (Shivarra)
	[6358] = "True",  	-- Seduction (Succubus)
	[261589] = "True",	  -- Seduction (Succubus)
	[171017] = "True",	  -- Meteor Strike (infernal)
	[171018] = "True",	  -- Meteor Strike (abisal)

	[5246] = "True",		-- Intimidating Shout (aoe)
	[132169] = "True",		-- Storm Bolt
	[132168] = "True",		-- Shockwave
	[199085] = "True",		-- Warpath

	[179057] = "True",		-- Chaos Nova
	[211881] = "True",		-- Fel Eruption
	[217832] = "True",		-- Imprison
	[221527] = "True",		-- Imprison (pvp talent)
	[200166] = "True",		-- Metamorfosis stun
	[207685] = "True",		-- Sigil of Misery
	[205630] = "True",		-- Illidan's Grasp
	[208618] = "True",		-- Illidan's Grasp (throw stun)
	[213491] = "True",		-- Demonic Trample Stun

	[331866] = "True",    -- Door of Shadows Fear (Venthyr)
	[332423] = "True",    -- Sparkling Driftglobe Core 35% Stun (Kyrian)
	[20549] = "True",		-- War Stomp (tauren racial)
	[107079] = "True",		-- Quaking Palm (pandaren racial)
	[255723] = "True",		-- Bull Rush (highmountain tauren racial)
	[287712] = "True",		-- Haymaker (kul tiran racial)

--Silence--
	[202914] = "True",  -- Spider Sting (pvp honor talent) --no silence}] = "True", this its the previous effect
	[202933] = "True",  -- Spider Sting	(pvp honor talent) --this its the silence effect
	[47476] = "True",  -- Strangulate
	[317589] = "True",  -- Tormenting Backlash (Venthyr Mage)
	[81261] = "True",  -- Solar Beam
	[217824] = "True",  -- Shield of Virtue (pvp honor talent)
	[15487] = "True",  -- Silence
	[1330] = "True",  -- Garrote - Silence
	[196364] = "True",  -- Unstable Affliction
	[204490] = "True",  -- Sigil of Silence

--Roots--
	[212638] = "True", 	-- Tracker's Net (pvp honor talent) -- Also -80% hit chance melee & range physical (CC and Root category)
	[307871] = "True", 	-- Spear of Bastion

	[117526] = "True",  -- Binding Shot
	[190927] = "True",  -- Harpoon
	[190925] = "True",  -- Harpoon
	[162480] = "True",  -- Steel Trap
	[53148] = "True",  -- Charge (tenacity ability)
	[64695] = "True",  -- Earthgrab (Earthgrab Totem)
	[285515] = "True",  -- Surge of Power
	[233395] = "True",  -- Deathchill (pvp talent)
	[204085] = "True",  -- Deathchill (pvp talent)
	[91807] = "True",  -- Shambling Rush (Dark Transformation)
	[339] = "True",  -- Entangling Roots
	[170855] = "True",  -- Entangling Roots (Nature's Grasp)
	[45334 ] = "True",  -- Immobilized (Wild Charge - Bear)
	[102359] = "True",  -- Mass Entanglement
	[122] = "True",  -- Frost Nova
	[198121] = "True",  -- Frostbite (pvp talent)
	[157997] = "True",  -- Ice Nova
	[228600] = "True",  -- Glacial Spike
	[33395] = "True",  -- Freeze
	[116706] = "True",  -- Disable
	[105771] = "True",  -- Charge (root)
	[199042] = "True", -- Thunderstruck
	[323996] = "True", -- The Hunt
}

local bgWarningspellIds = {

	[233490] = "True", -- UA
	[233497] = "True", -- UA
	[233496] = "True", -- UA
	[233498] = "True", -- UA
	[233499] = "True", -- UA
	[316099] = "True", -- UA
	[342938] = "True", -- UA Shadowlands
	[316099] = "True", -- UA
	[43522] = "True", -- UA
	[34438] = "True", -- UA
	[34439] = "True", -- UA
	[251502] = "True", -- UA
	[65812] = "True", -- UA
	[35183] = "True", -- UA
	[211513] = "True", -- UA
	[285142] = "True", -- UA
	[285143] = "True", -- UA
	[285144] = "True", -- UA
	[285145] = "True", -- UA
	[285146] = "True", -- UA
	[34914] = "True", -- VT

}

local SmokeBombAuras = {}
local DuelAura = {}

function DebuffFilter:CLEU()
		local _, event, _, sourceGUID, sourceName, sourceFlags, _, destGUID, _, _, _, spellId, _, _, _, _, spellSchool = CombatLogGetCurrentEventInfo()
	-----------------------------------------------------------------------------------------------------------------
	--SmokeBomb Check
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_CAST_SUCCESS") and (spellId == 212182)) then
		if (sourceGUID ~= nil) then
		local duration = 5
		local expirationTime = GetTime() + duration
			if (SmokeBombAuras[sourceGUID] == nil) then
				SmokeBombAuras[sourceGUID] = {}
			end
			SmokeBombAuras[sourceGUID] = { ["duration"] = duration, ["expirationTime"] = expirationTime }
			Ctimer(duration + 1, function()	-- execute in some close next frame to accurate use of UnitAura function
			SmokeBombAuras[sourceGUID] = nil
			end)
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--Shaodwy Duel Enemy Check
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_CAST_SUCCESS") and (spellId == 207736)) then
		if sourceGUID and (bit_band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) then
			if (DuelAura[sourceGUID] == nil) then
				DuelAura[sourceGUID] = {}
			end
			if (DuelAura[destGUID] == nil) then
				DuelAura[destGUID] = {}
			end
			duration = 6
			Ctimer(duration + 1, function()
			DuelAura[sourceGUID] = nil
			DuelAura[destGUID] = nil
			end)
		end
	end
end

local function isBiggestDebuff(unit, index, filter)
  local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, index, "HARMFUL");
	if spellIds[spellId] == "Biggest"  then
		return true
	else
		return false
	end
end

local function isBiggerDebuff(unit, index, filter)
  local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, index, "HARMFUL");
	local inInstance, instanceType = IsInInstance()
	if instanceType=="pvp" and bgBiggerspellIds[spellId] then
		return true
	elseif spellIds[spellId] == "Bigger"  then
		return true
	else
		return false
	end
end

local function isBigDebuff(unit, index, filter)
  local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, index, "HARMFUL");
	local inInstance, instanceType = IsInInstance()
	if instanceType=="pvp" and bgBigspellIds[spellId] then
		return true
	elseif spellIds[spellId] == "Big"  then
		return true
	else
		return false
	end
end

local function CompactUnitFrame_UtilIsBossDebuff(unit, index, filter)
  local name, icon, _, _, duration, expirationTime, _, _, _, spellId, _, isBossDeBuff = UnitAura(unit, index, "HARMFUL");
	if isBossDeBuff then
		return true
	else
		return false
	end
end

local function CompactUnitFrame_UtilIsBossAura(unit, index, filter)
  local name, icon, _, _, duration, expirationTime, _, _, _, spellId, _, isBossDeBuff = UnitAura(unit, index, "HELPFUL");
	if isBossDeBuff then
		return true
	else
		return false
	end
end

local function isWarning(unit, index, filter)
    local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, index, "HARMFUL");
		local inInstance, instanceType = IsInInstance()
		if instanceType=="pvp" and bgWarningspellIds[spellId] then
			return true
		elseif spellIds[spellId] == "Warning"  then
			return true
		else
			return false
		end
	end

local function isPriority(unit, index, filter)
    local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, index, "HARMFUL");
		if spellIds[spellId] == "Priority" then
		return true
	else
		return false
	end
end

local function isDebuff(unit, index, filter)
    local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, index, "HARMFUL");
		if spellIds[spellId] == "Hide" then
		return false
	else
--print("isDebuff")
	  return true
	end
end
-- Update aura for each unit
function DebuffFilter:UpdateAura(uid)
	for f,v in pairs(self.cache) do
			if f.unit == uid then
			local filter = nil
			local debuffNum = 1
			local index = 1
			local hidedebuffs=0
			if ( f.optionTable.displayOnlyDispellableDebuffs ) then
				filter = "RAID"
			end
			--Biggest Debuffs
				while debuffNum <= debuffnumber do
					local debuffName = UnitDebuff(uid, index, nil)
					if ( debuffName ) then
							if isBiggestDebuff(uid, index, nil) then
							local debuffFrame = v.debuffFrames[debuffNum]
							local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
							name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(uid, index, filter);
							debuffFrame.filter = filter;
							debuffFrame.icon:SetTexture(icon);
							debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
							debuffFrame.icon:SetVertexColor(1, 1, 1);
							debuffFrame.SpellId = spellId
							debuffFrame:SetScript("OnEnter", function(self)
								GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
								GameTooltip:SetSpellByID(self.SpellId)
								GameTooltip:Show()
							end)
							debuffFrame:SetScript("OnLeave", function(self)
								GameTooltip:Hide()
							end)
							if count then
							if ( count > 1 ) then
							local countText = count;
							if ( count >= 100 ) then
							 countText = BUFF_STACKS_OVERFLOW;
							end
							debuffFrame.count:Show();
							debuffFrame.count:SetText(countText);
							else
							debuffFrame.count:Hide();
							end
							end
							debuffFrame:SetID(index);
							local enabled = expirationTime and expirationTime ~= 0;
							if enabled then
							local startTime = expirationTime - duration;
							CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
							else
							CooldownFrame_Clear(debuffFrame.cooldown);
							end
							local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
							debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
							debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1.6,f.buffFrames[3]:GetSize()*1.6);
							debuffFrame:Show();
							debuffNum = debuffNum + 1
							hidedebuffs=1
						end
					else
						break
					end
					index = index + 1
				end
				index = 1
				--Bigger Debuff
				while debuffNum <= debuffnumber do
					local debuffName = UnitDebuff(uid, index, filter);
					if ( debuffName ) then
							if isBiggerDebuff(uid, index, nil) and not isBiggestDebuff(uid, index, nil) then
								local debuffFrame = v.debuffFrames[debuffNum]
								local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
								name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(uid, index, filter);
								debuffFrame.filter = filter;
								debuffFrame.icon:SetTexture(icon);
								debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
								debuffFrame.icon:SetVertexColor(1, 1, 1);
								debuffFrame.SpellId = spellId
								debuffFrame:SetScript("OnEnter", function(self)
									GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
									GameTooltip:SetSpellByID(self.SpellId)
									GameTooltip:Show()
								end)
								debuffFrame:SetScript("OnLeave", function(self)
									GameTooltip:Hide()
								end)
								if count then
								if ( count > 1 ) then
								local countText = count;
								if ( count >= 100 ) then
								 countText = BUFF_STACKS_OVERFLOW;
								end
								debuffFrame.count:Show();
								debuffFrame.count:SetText(countText);
								else
								debuffFrame.count:Hide();
								end
								end
								debuffFrame:SetID(index);
								local enabled = expirationTime and expirationTime ~= 0;
								if enabled then
								local startTime = expirationTime - duration;
								CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
								else
								CooldownFrame_Clear(debuffFrame.cooldown);
								end
								local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
								debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
								debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1.4,f.buffFrames[3]:GetSize()*1.4);
								debuffFrame:Show();
								debuffNum = debuffNum + 1
						end
					else
						break
					end
					index = index + 1
				end
				index = 1
				--Big Debuff
				while debuffNum <= debuffnumber do
					local debuffName = UnitDebuff(uid, index, filter);
					if ( debuffName ) then
							if isBigDebuff(uid, index, nil) and not isBiggestDebuff(uid, index, nil) and not isBiggerDebuff(uid, index, nil) then
								local debuffFrame = v.debuffFrames[debuffNum]
								local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
								name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(uid, index, filter);
								debuffFrame.filter = filter;
								debuffFrame.icon:SetTexture(icon);
								debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
								debuffFrame.icon:SetVertexColor(1, 1, 1);
								debuffFrame.SpellId = spellId
								debuffFrame:SetScript("OnEnter", function(self)
									GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
									GameTooltip:SetSpellByID(self.SpellId)
									GameTooltip:Show()
								end)
								debuffFrame:SetScript("OnLeave", function(self)
									GameTooltip:Hide()
								end)


								----------------------------------------------------------------------------------------------------------------------------------------------
								--SmokeBomb
								----------------------------------------------------------------------------------------------------------------------------------------------
								if spellId == 212183 then -- Smoke Bomb
									if unitCaster and SmokeBombAuras[UnitGUID(unitCaster)] then
										if UnitIsEnemy("player", unitCaster) then --still returns true for an enemy currently under mindcontrol I can add your fix.
											duration = SmokeBombAuras[UnitGUID(unitCaster)].duration --Add a check, i rogue bombs in stealth there is a unitCaster but the cleu doesnt regester a time
											expirationTime = SmokeBombAuras[UnitGUID(unitCaster)].expirationTime
											debuffFrame.icon:SetDesaturated(1) --Destaurate Icon
											debuffFrame.icon:SetVertexColor(1, .25, 0); --Red Hue Set For Icon
										elseif not UnitIsEnemy("player", unitCaster) then --Add a check, i rogue bombs in stealth there is a unitCaster but the cleu doesnt regester a time
											duration = SmokeBombAuras[UnitGUID(unitCaster)].duration --Add a check, i rogue bombs in stealth there is a unitCaster but the cleu doesnt regester a time
											expirationTime = SmokeBombAuras[UnitGUID(unitCaster)].expirationTime
										end
									end
								end

								-----------------------------------------------------------------------------------------------------------------
								--Enemy Duel
								-----------------------------------------------------------------------------------------------------------------
								if spellId == 207736 then --Shodowey Duel enemy on friendly, friendly frame (red)
									if DuelAura[UnitGUID(uid)] then --enemyDuel
										debuffFrame.icon:SetDesaturated(1) --Destaurate Icon
										debuffFrame.icon:SetVertexColor(1, .25, 0); --Red Hue Set For Icon
									else
									end
								end


								if count then
								if ( count > 1 ) then
								local countText = count;
								if ( count >= 100 ) then
								 countText = BUFF_STACKS_OVERFLOW;
								end
								debuffFrame.count:Show();
								debuffFrame.count:SetText(countText);
								else
								debuffFrame.count:Hide();
								end
								end
								debuffFrame:SetID(index);
								local enabled = expirationTime and expirationTime ~= 0;
								if enabled then
								local startTime = expirationTime - duration;
								CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
								else
								CooldownFrame_Clear(debuffFrame.cooldown);
								end
								local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
								debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
								debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1.4,f.buffFrames[3]:GetSize()*1.4);
								debuffFrame:Show();
								debuffNum = debuffNum + 1
						end
					else
						break
					end
					index = index + 1
				end
				index = 1
			--isBossDeBuff
				while debuffNum <= debuffnumber do
					local debuffName = UnitDebuff(uid, index, filter);
					if ( debuffName ) then
							if CompactUnitFrame_UtilIsBossDebuff(uid, index, filter) and not isBiggestDebuff(uid, index, nil) and not isBiggerDebuff(uid, index, nil) and not isBigDebuff(uid, index, nil) then
								local debuffFrame = v.debuffFrames[debuffNum]
								local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
								name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(uid, index, filter);
								debuffFrame.filter = filter;
								debuffFrame.icon:SetTexture(icon);
								debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
								debuffFrame.icon:SetVertexColor(1, 1, 1);
								debuffFrame.SpellId = spellId
								debuffFrame:SetScript("OnEnter", function(self)
									GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
									GameTooltip:SetSpellByID(self.SpellId)
									GameTooltip:Show()
								end)
								debuffFrame:SetScript("OnLeave", function(self)
									GameTooltip:Hide()
								end)
								if count then
								if ( count > 1 ) then
								local countText = count;
								if ( count >= 100 ) then
								 countText = BUFF_STACKS_OVERFLOW;
								end
								debuffFrame.count:Show();
								debuffFrame.count:SetText(countText);
								else
								debuffFrame.count:Hide();
								end
								end
								debuffFrame:SetID(index);
								local enabled = expirationTime and expirationTime ~= 0;
								if enabled then
								local startTime = expirationTime - duration;
								CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
								else
								CooldownFrame_Clear(debuffFrame.cooldown);
								end
								local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
								debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
									--debuffFrame.border:Hide()
									debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1.4,f.buffFrames[3]:GetSize()*1.4);
								debuffFrame:Show();
								debuffNum = debuffNum + 1
						end
					else
						break
					end
					index = index + 1
				end
				index = 1
				--isBossBuff
				while debuffNum <= debuffnumber do
					local debuffName = UnitBuff(uid, index, filter);
					if ( debuffName ) then
							if CompactUnitFrame_UtilIsBossAura(uid, index, filter) and not isBiggestDebuff(uid, index, nil) and not isBiggerDebuff(uid, index, nil) and not isBigDebuff(uid, index, nil) and not CompactUnitFrame_UtilIsBossDebuff(uid, index, nil) then
								local debuffFrame = v.debuffFrames[debuffNum]
								local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
								name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitBuff(uid, index, filter);
								debuffFrame.filter = filter;
								debuffFrame.icon:SetTexture(icon);
								debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
								debuffFrame.icon:SetVertexColor(1, 1, 1);
								debuffFrame.SpellId = spellId
								debuffFrame:SetScript("OnEnter", function(self)
									GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
									GameTooltip:SetSpellByID(self.SpellId)
									GameTooltip:Show()
								end)
								debuffFrame:SetScript("OnLeave", function(self)
									GameTooltip:Hide()
								end)
								if count then
								if ( count > 1 ) then
								local countText = count;
								if ( count >= 100 ) then
								 countText = BUFF_STACKS_OVERFLOW;
								end
								debuffFrame.count:Show();
								debuffFrame.count:SetText(countText);
								else
								debuffFrame.count:Hide();
								end
								end
								debuffFrame:SetID(index);
								local enabled = expirationTime and expirationTime ~= 0;
								if enabled then
								local startTime = expirationTime - duration;
								CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
								else
								CooldownFrame_Clear(debuffFrame.cooldown);
								end
								local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
								debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
								debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1.4,f.buffFrames[3]:GetSize()*1.4);
								debuffFrame:Show();
								debuffNum = debuffNum + 1
						end
					else
						break
					end
					index = index + 1
				end
				index = 1
				--isWarning
				while debuffNum <= debuffnumber do
					local debuffName = UnitDebuff(uid, index, nil)
					if ( debuffName ) then
							if  isWarning(uid, index, nil) and not isBiggestDebuff(uid, index, nil) and not isBiggerDebuff(uid, index, nil) and not isBigDebuff(uid, index, nil) and not CompactUnitFrame_UtilIsBossDebuff(uid, index, nil) and not CompactUnitFrame_UtilIsBossAura(uid, index, nil) then
								local debuffFrame = v.debuffFrames[debuffNum]
								local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
								name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(uid, index, filter);
								debuffFrame.filter = filter;
								debuffFrame.icon:SetTexture(icon);
								debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
								debuffFrame.icon:SetVertexColor(1, 1, 1);
								debuffFrame.SpellId = spellId
								debuffFrame:SetScript("OnEnter", function(self)
									GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
									GameTooltip:SetSpellByID(self.SpellId)
									GameTooltip:Show()
								end)
								debuffFrame:SetScript("OnLeave", function(self)
									GameTooltip:Hide()
								end)
								if count then
								if ( count > 1 ) then
								local countText = count;
								if ( count >= 100 ) then
								 countText = BUFF_STACKS_OVERFLOW;
								end
								debuffFrame.count:Show();
								debuffFrame.count:SetText(countText);
								else
								debuffFrame.count:Hide();
								end
								end
								debuffFrame:SetID(index);
								local enabled = expirationTime and expirationTime ~= 0;
								if enabled then
								local startTime = expirationTime - duration;
								CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
								else
								CooldownFrame_Clear(debuffFrame.cooldown);
								end
								local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
								debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
								debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1.15,f.buffFrames[3]:GetSize()*1.15);
								debuffFrame:Show();
								debuffNum = debuffNum + 1
						end
					else
						break
					end
					index = index + 1
				end
				index = 1
				--Prio
				while debuffNum <= debuffnumber do
					local debuffName = UnitDebuff(uid, index, nil)
					if ( debuffName ) then
							if isPriority(uid, index, nil) and not isBiggestDebuff(uid, index, nil) and not isBiggerDebuff(uid, index, nil) and not isBigDebuff(uid, index, nil) and not CompactUnitFrame_UtilIsBossDebuff(uid, index, nil) and not CompactUnitFrame_UtilIsBossAura(uid, index, nil) and not isWarning(uid, index, nil) then
								local debuffFrame = v.debuffFrames[debuffNum]
								local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
								name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(uid, index, filter);
								debuffFrame.filter = filter;
								debuffFrame.icon:SetTexture(icon);
								debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
								debuffFrame.icon:SetVertexColor(1, 1, 1);
								debuffFrame.SpellId = spellId
								debuffFrame:SetScript("OnEnter", function(self)
									GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
									GameTooltip:SetSpellByID(self.SpellId)
									GameTooltip:Show()
								end)
								debuffFrame:SetScript("OnLeave", function(self)
									GameTooltip:Hide()
								end)
								if count then
								if ( count > 1 ) then
								local countText = count;
								if ( count >= 100 ) then
								 countText = BUFF_STACKS_OVERFLOW;
								end
								debuffFrame.count:Show();
								debuffFrame.count:SetText(countText);
								else
								debuffFrame.count:Hide();
								end
								end
								debuffFrame:SetID(index);
								local enabled = expirationTime and expirationTime ~= 0;
								if enabled then
								local startTime = expirationTime - duration;
								CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
								else
								CooldownFrame_Clear(debuffFrame.cooldown);
								end
								local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
								debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
								debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1,f.buffFrames[3]:GetSize()*1);
								debuffFrame:Show();
								debuffNum = debuffNum + 1
						end
					else
						break
					end
					index = index + 1
				end
				index = 1
				while debuffNum <= debuffnumber and hidedebuffs==0 do
					local debuffName = UnitDebuff(uid, index, filter)
					if ( debuffName ) then
						if ( isDebuff(uid, index, nil) and not isBiggestDebuff(uid, index, nil) and not isBiggerDebuff(uid, index, nil) and not isBigDebuff(uid, index, nil) and not CompactUnitFrame_UtilIsBossDebuff(uid, index, nil) and not CompactUnitFrame_UtilIsBossAura(uid, index, nil) and not isWarning(uid, index, nil) and not isPriority(uid, index, nil)) then
							local debuffFrame = v.debuffFrames[debuffNum]
							local debuffFrame = v.debuffFrames[debuffNum]
							local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId;
							name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(uid, index, filter);
							debuffFrame.filter = filter;
							debuffFrame.icon:SetTexture(icon);
							debuffFrame.icon:SetDesaturated(nil) --Destaurate Icon
							debuffFrame.icon:SetVertexColor(1, 1, 1);
							debuffFrame.SpellId = spellId
							debuffFrame:SetScript("OnEnter", function(self)
								GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
								GameTooltip:SetSpellByID(self.SpellId)
								GameTooltip:Show()
							end)
							debuffFrame:SetScript("OnLeave", function(self)
								GameTooltip:Hide()
							end)
							if count then
							if ( count > 1 ) then
							local countText = count;
							if ( count >= 100 ) then
							 countText = BUFF_STACKS_OVERFLOW;
							end
							debuffFrame.count:Show();
							debuffFrame.count:SetText(countText);
							else
							debuffFrame.count:Hide();
							end
							end
							debuffFrame:SetID(index);
							local enabled = expirationTime and expirationTime ~= 0;
							if enabled then
							local startTime = expirationTime - duration;
							CooldownFrame_Set(debuffFrame.cooldown, startTime, duration, true);
							else
							CooldownFrame_Clear(debuffFrame.cooldown);
							end
							local color = DebuffTypeColor[debuffType] or DebuffTypeColor["none"];
							debuffFrame.border:SetVertexColor(color.r, color.g, color.b);
							debuffFrame:SetSize(f.buffFrames[3]:GetSize()*1,f.buffFrames[3]:GetSize()*1);
							debuffFrame:Show();
							debuffNum = debuffNum + 1
						end
					else
						break
					end
					index = index + 1
				end
				for i=debuffNum, debuffnumber do
				local debuffFrame = v.debuffFrames[i];
				if debuffFrame then
					debuffFrame:Hide()
				end
			end
			break
		end
	end
end
-- Apply style for each frame
function DebuffFilter:ApplyFrame(f)
	self.cache[f] = {}
	local scf = self.cache[f]
	f:SetScript("OnSizeChanged",function() DebuffFilter:ResetFrame(f) DebuffFilter:ApplyFrame(f) end)
	if not scf.debuffFrames then scf.debuffFrames = {} end
	for j = 1, debuffnumber do
		if not scf.debuffFrames[j] then
			scf.debuffFrames[j] = CreateFrame("Button",nil,UIParent,"CompactDebuffTemplate")
			scf.debuffFrames[j].unit = f.unit
			scf.debuffFrames[j].baseSize = f.buffFrames[3]:GetSize()
			--scf.debuffFrames[j]:EnableMouse(false)
			if j == 1 then
				scf.debuffFrames[j]:ClearAllPoints()
				scf.debuffFrames[j]:SetParent(f)
				scf.debuffFrames[j]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT",3,10)
			else
				scf.debuffFrames[j]:SetParent(f)
				scf.debuffFrames[j]:SetPoint("BOTTOMLEFT",scf.debuffFrames[j-1],"BOTTOMRIGHT",0,0)
			end
			--f.debuffFrames[j]:SetSize(f.buffFrames[3]:GetSize())
			scf.debuffFrames[j]:SetSize(f.buffFrames[3]:GetSize())
			scf.debuffFrames[j]:Hide()
		end
	end
	for j = 1,#f.debuffFrames do
		f.debuffFrames[j]:Hide()
		f.debuffFrames[j]:SetScript("OnShow",f.debuffFrames[j].Hide)
	end
end
-- Reset to the original style
function DebuffFilter:ResetStyle()
	for f,_ in pairs(DebuffFilter.cache) do
		DebuffFilter:ResetFrame(f)
	end
end
-- Reset style to each cached frame
function DebuffFilter:ResetFrame(f)
		for k,v in pairs(self.cache[f].debuffFrames) do
		if v then
				v:Hide()
		end
		end
	f:SetScript("OnSizeChanged",nil)
	for j = 1,#f.debuffFrames do
		f.debuffFrames[j]:SetScript("OnShow",nil)
	end
	self.cache[f] = nil
end

-- Event handling
local function OnEvent(self,event,...)
	if event == "VARIABLES_LOADED" then self:OnLoad()
	elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then self:OnRosterUpdate()
	elseif event == "PLAYER_ENTERING_WORLD" then self:OnRosterUpdate()
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then self:CLEU()
elseif event == "UNIT_AURA" then self:UpdateAura(...) end
end

DebuffFilter:SetScript("OnEvent",OnEvent)
DebuffFilter:RegisterEvent("VARIABLES_LOADED")
_G.DebuffFilter = DebuffFilter
