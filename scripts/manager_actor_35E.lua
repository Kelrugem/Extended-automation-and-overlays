-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	initActorHealth();

	-- Add Extended AC Bonuses (https://github.com/FG-Unofficial-Developers-Guild/FG-PFRPG-ExtendedACBonusTypes)
	DataCommon.actypes["naturalsize"] = "naturalsize";
	DataCommon.actypes["armorenhancement"] = "armorenhancement";
	DataCommon.actypes["shieldenhancement"] = "shieldenhancement";
	DataCommon.actypes["naturalenhancement"] = "naturalenhancement";

	-- Add Extended AC Bonuses (https://github.com/FG-Unofficial-Developers-Guild/FG-PFRPG-ExtendedACBonusTypes)
	table.insert(DataCommon.bonustypes, "naturalsize");
	table.insert(DataCommon.bonustypes, "armorenhancement");
	table.insert(DataCommon.bonustypes, "shieldenhancement");
	table.insert(DataCommon.bonustypes, "naturalenhancement");
end

--
--	HEALTH
-- 

function initActorHealth()
	ActorHealthManager.registerStatusHealthColor(ActorHealthManager.STATUS_UNCONSCIOUS, ColorManager.getUIColor("health_dyingordead"));
	ActorHealthManager.registerStatusHealthColor(ActorHealthManager.STATUS_DISABLED, ColorManager.getUIColor("health_simple_bloodied"));
	ActorHealthManager.registerStatusHealthColor(ActorHealthManager.STATUS_STAGGERED, ColorManager.getUIColor("health_simple_bloodied"));

	ActorHealthManager.getWoundPercent = getWoundPercent;
end

-- NOTE: Always default to using CT node as primary to make sure 
--		that all bars and statuses are synchronized in combat tracker
--		(Cross-link network updates between PC and CT fields can occur in either order, 
--		depending on where the scripts or end user updates.)
-- NOTE 2: We can not use default effect checking in this function; 
-- 		as it will cause endless loop with conditionals that check health

function getWoundPercent(v)
	local rActor = ActorManager.resolveActor(v);

	local nHP = 0;
	local nTemp = 0;
	local nWounds = 0;
	local nNonlethal = 0;

	local nodeCT = ActorManager.getCTNode(rActor);
	if nodeCT then
		nHP = math.max(DB.getValue(nodeCT, "hp", 0), 0);
		nTemp = math.max(DB.getValue(nodeCT, "hptemp", 0), 0);
		nWounds = math.max(DB.getValue(nodeCT, "wounds", 0), 0);
		nNonlethal = math.max(DB.getValue(nodeCT, "nonlethal", 0), 0);
	elseif ActorManager.isPC(rActor) then
		local nodePC = ActorManager.getCreatureNode(rActor);
		if nodePC then
			nHP = math.max(DB.getValue(nodePC, "hp.total", 0), 0);
			nTemp = math.max(DB.getValue(nodePC, "hp.temporary", 0), 0);
			nWounds = math.max(DB.getValue(nodePC, "hp.wounds", 0), 0);
			nNonlethal = math.max(DB.getValue(nodePC, "hp.nonlethal", 0), 0);
		end
	end
	
	local nPercentLethal = 0;
	local nPercentNonlethal = 0;
	if nHP > 0 then
		nPercentLethal = nWounds / nHP;
		nPercentNonlethal = (nWounds + nNonlethal) / (nHP + nTemp);
	end
	
	-- KEL Adding overlays
	local sStatus;
	local bDiesAtZero = false;
	if ActorCommonManager.isCreatureTypeDnD(rActor, "construct,undead,swarm") then
		bDiesAtZero = true;
	end
	if bDiesAtZero and nPercentLethal >= 1 then
		sStatus = ActorHealthManager.STATUS_DEAD;
		TokenManager3.setDeathOverlay(nodeCT, 1);
	elseif nPercentLethal > 1 then
		local nDying = GameSystem.getDeathThreshold(rActor);
		
		if (nWounds - nHP) < nDying then
			sStatus = ActorHealthManager.STATUS_DYING;
			-- KEL adding a boolean to treat NOTE 2
			if EffectManager35E.hasEffectCondition(rActor, "Stable", "", true) then
				TokenManager3.setDeathOverlay(nodeCT, 3);
			else
				TokenManager3.setDeathOverlay(nodeCT, 2);
			end
		else
			sStatus = ActorHealthManager.STATUS_DEAD;
			TokenManager3.setDeathOverlay(nodeCT, 1);
		end
	elseif nPercentNonlethal > 1 then
		sStatus = ActorHealthManager.STATUS_UNCONSCIOUS;
		TokenManager3.setDeathOverlay(nodeCT, 9);
	elseif nPercentLethal == 1 then
		sStatus = ActorHealthManager.STATUS_DISABLED;
		TokenManager3.setDeathOverlay(nodeCT, 8);
	elseif nPercentNonlethal == 1 then
		sStatus = ActorHealthManager.STATUS_STAGGERED;
		TokenManager3.setDeathOverlay(nodeCT, 10);
	-- KEL we keep the following structure instead of replacing with ActorHealthManager.getDefaultStatusFromWoundPercent (see this function as reference); maybe replace the value of the deathNode with the status string, then this code could be more elegant. Our approach however is a biiiiit better since it has one less if-clause (and a number for deathNode may be better in sense of bytes)
	elseif nPercentNonlethal > 0 then
		local bDetailedStatus = OptionsManager.isOption("WNDC", "detailed");
	
		if bDetailedStatus then
			if nPercentNonlethal >= .75 then
				sStatus = ActorHealthManager.STATUS_CRITICAL;
				TokenManager3.setDeathOverlay(nodeCT, 4);
			elseif nPercentNonlethal >= .5 then
				sStatus = ActorHealthManager.STATUS_HEAVY;
				TokenManager3.setDeathOverlay(nodeCT, 5);
			elseif nPercentNonlethal >= .25 then
				sStatus = ActorHealthManager.STATUS_MODERATE;
				TokenManager3.setDeathOverlay(nodeCT, 6);
			else
				sStatus = ActorHealthManager.STATUS_LIGHT;
				TokenManager3.setDeathOverlay(nodeCT, 7);
			end
		else
			if nPercentNonlethal >= .5 then
				sStatus = ActorHealthManager.STATUS_SIMPLE_HEAVY;
				TokenManager3.setDeathOverlay(nodeCT, 5);
			else
				sStatus = ActorHealthManager.STATUS_SIMPLE_WOUNDED;
				TokenManager3.setDeathOverlay(nodeCT, 7);
			end
		end
	else
		sStatus = ActorHealthManager.STATUS_HEALTHY;
		TokenManager3.setDeathOverlay(nodeCT, 0);
	end
	
	return nPercentNonlethal, sStatus, nPercentLethal;
end

function getPCSheetWoundColor(nodePC)
	local nHP = 0;
	local nTemp = 0;
	local nWounds = 0;
	local nNonlethal = 0;
	if nodePC then
		nHP = math.max(DB.getValue(nodePC, "hp.total", 0), 0);
		nTemp = math.max(DB.getValue(nodePC, "hp.temporary", 0), 0);
		nWounds = math.max(DB.getValue(nodePC, "hp.wounds", 0), 0);
		nNonlethal = math.max(DB.getValue(nodePC, "hp.nonlethal", 0), 0);
	end

	local nPercentLethal = 0;
	local nPercentNonlethal = 0;
	if nHP > 0 then
		nPercentLethal = nWounds / nHP;
		nPercentNonlethal = (nWounds + nNonlethal) / (nHP + nTemp);
	end
	
	if nPercentLethal > 1 then
		return ColorManager.getUIColor("health_dyingordead");
	elseif nPercentNonlethal > 1 then
		return ColorManager.getUIColor("health_unconscious");
	elseif nPercentLethal == 1 then
		return ColorManager.getUIColor("health_simple_bloodied");
	elseif nPercentNonlethal == 1 then
		return ColorManager.getUIColor("health_simple_bloodied");
	end

	local sColor = ColorManager.getHealthColor(nPercentNonlethal, false);
	return sColor;
end

--
--	ABILITY SCORES
--
-- KEL tags
function getAbilityEffectsBonus(rActor, sAbility, tags)
	if not rActor or not sAbility then
		return 0, 0;
	end
	
	local sAbilityEffect = DataCommon.ability_ltos[sAbility];
	if not sAbilityEffect then
		return 0, 0;
	end
	
	local nEffectMod, nAbilityEffects = EffectManager35E.getEffectsBonus(rActor, sAbilityEffect, true, nil, nil, false, tags);
	
	if sAbility == "dexterity" then
		if EffectManager35E.hasEffectCondition(rActor, "Entangled", tags) then
			nEffectMod = nEffectMod - 4;
			nAbilityEffects = nAbilityEffects + 1;
		end
		if DataCommon.isPFRPG() and EffectManager35E.hasEffectCondition(rActor, "Grappled", tags) then
			nEffectMod = nEffectMod - 4;
			nAbilityEffects = nAbilityEffects + 1;
		end
	end
	if sAbility == "dexterity" or sAbility == "strength" then
		if EffectManager35E.hasEffectCondition(rActor, "Exhausted", tags) then
			nEffectMod = nEffectMod - 6;
			nAbilityEffects = nAbilityEffects + 1;
		elseif EffectManager35E.hasEffectCondition(rActor, "Fatigued", tags) then
			nEffectMod = nEffectMod - 2;
			nAbilityEffects = nAbilityEffects + 1;
		end
	end
	
	local nEffectBonusMod = 0;
	if nEffectMod > 0 then
		nEffectBonusMod = math.floor(nEffectMod / 2);
	else
		nEffectBonusMod = math.ceil(nEffectMod / 2);
	end

	local nAbilityMod = 0;
	local nAbilityScore = getAbilityScore(rActor, sAbility);
	if nAbilityScore > 0 and not DataCommon.isPFRPG() then
		local nAbilityDamage = getAbilityDamage(rActor, sAbility);
		
		local nCurrentBonus = math.floor((nAbilityScore - nAbilityDamage - 10) / 2);
		local nAffectedBonus = math.floor((nAbilityScore - nAbilityDamage + nEffectMod - 10) / 2);
		
		nAbilityMod = nAffectedBonus - nCurrentBonus;
	else
		nAbilityMod = nEffectBonusMod;
	end

	return nAbilityMod, nAbilityEffects;
end
-- END
function getAbilityDamage(rActor, sAbility)
	if not sAbility then
		return 0;
	end
	if not ActorManager.isPC(rActor) then
		return 0;
	end
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return 0;
	end
	
	local sShort = sAbility:sub(1,3):lower();
	if sShort == "str" then
		return DB.getValue(nodeActor, "abilities.strength.damage", 0);
	elseif sShort == "dex" then
		return DB.getValue(nodeActor, "abilities.dexterity.damage", 0);
	elseif sShort == "con" then
		return DB.getValue(nodeActor, "abilities.constitution.damage", 0);
	elseif sShort == "int" then
		return DB.getValue(nodeActor, "abilities.intelligence.damage", 0);
	elseif sShort == "wis" then
		return DB.getValue(nodeActor, "abilities.wisdom.damage", 0);
	elseif sShort == "cha" then
		return DB.getValue(nodeActor, "abilities.charisma.damage", 0);
	end

	return 0;
end

function getAbilityScore(rActor, sAbility)
	if not sAbility then
		return -1;
	end
	local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if not nodeActor then
		return 0;
	end
	
	local nStatScore = -1;
	
	local sShort = string.sub(string.lower(sAbility), 1, 3);
	if sNodeType == "pc" then
		if sShort == "lev" then
			nStatScore = DB.getValue(nodeActor, "level", 0);
		elseif sShort == "bab" then
			nStatScore = DB.getValue(nodeActor, "attackbonus.base", 0);
		elseif sShort == "cmb" then
			nStatScore = DB.getValue(nodeActor, "attackbonus.base", 0);
		elseif sShort == "str" then
			nStatScore = DB.getValue(nodeActor, "abilities.strength.score", 0);
		elseif sShort == "dex" then
			nStatScore = DB.getValue(nodeActor, "abilities.dexterity.score", 0);
		elseif sShort == "con" then
			nStatScore = DB.getValue(nodeActor, "abilities.constitution.score", 0);
		elseif sShort == "int" then
			nStatScore = DB.getValue(nodeActor, "abilities.intelligence.score", 0);
		elseif sShort == "wis" then
			nStatScore = DB.getValue(nodeActor, "abilities.wisdom.score", 0);
		elseif sShort == "cha" then
			nStatScore = DB.getValue(nodeActor, "abilities.charisma.score", 0);
		end
	elseif ActorManager.isRecordType(rActor, "npc") then
		if sShort == "lev" then
			nStatScore = tonumber(string.match(DB.getValue(nodeActor, "hd", ""), "^(%d+)")) or 0;
		elseif sShort == "bab" then
			nStatScore = 0;

			local sBABGrp = DB.getValue(nodeActor, "babgrp", "");
			local sBAB = sBABGrp:match("[+-]?%d+");
			if sBAB then
				nStatScore = tonumber(sBAB) or 0;
			end
		elseif sShort == "cmb" then
			nStatScore = 0;

			local sBABGrp = DB.getValue(nodeActor, "babgrp", "");
			local sBAB = sBABGrp:match("CMB ([+-]?%d+)");
			if not sBAB then
				sBAB = sBABGrp:match("[+-]?%d+");
			end
			if sBAB then
				nStatScore = tonumber(sBAB) or 0;
			end
		elseif sShort == "str" then
			nStatScore = DB.getValue(nodeActor, "strength", 0);
		elseif sShort == "dex" then
			nStatScore = DB.getValue(nodeActor, "dexterity", 0);
		elseif sShort == "con" then
			nStatScore = DB.getValue(nodeActor, "constitution", 0);
		elseif sShort == "int" then
			nStatScore = DB.getValue(nodeActor, "intelligence", 0);
		elseif sShort == "wis" then
			nStatScore = DB.getValue(nodeActor, "wisdom", 0);
		elseif sShort == "cha" then
			nStatScore = DB.getValue(nodeActor, "charisma", 0);
		end
	end
	
	return nStatScore;
end

function getAbilityBonus(rActor, sAbility)
	if not sAbility then
		return 0;
	end
	if not rActor then
		return 0;
	end
	
	-- SETUP
	local sStat = sAbility;
	local bHalf = false;
	local bDouble = false;
	local nStatVal = 0;
	
	-- HANDLE HALF/DOUBLE MODIFIERS
	if string.match(sStat, "^half") then
		bHalf = true;
		sStat = string.sub(sStat, 5);
	end
	if string.match(sStat, "^double") then
		bDouble = true;
		sStat = string.sub(sStat, 7);
	end

	-- GET ABILITY VALUE
	local nStatScore = getAbilityScore(rActor, sStat);
	if nStatScore < 0 then
		return 0;
	end
	
	if StringManager.contains(DataCommon.abilities, sStat) then
		local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
		if nodeActor and (sNodeType == "pc") then
			nStatVal = nStatVal + DB.getValue(nodeActor, "abilities." .. sStat .. ".bonusmodifier", 0);
			
			local nAbilityDamage = DB.getValue(nodeActor, "abilities." .. sStat .. ".damage", 0);
			if DataCommon.isPFRPG() then
				if nAbilityDamage >= 0 then
					nAbilityDamage = math.floor(nAbilityDamage / 2) * 2;
				else
					nAbilityDamage = math.ceil(nAbilityDamage / 2) * 2;
				end
			end
			nStatScore = nStatScore - nAbilityDamage;
		end
		nStatVal = nStatVal + math.floor((nStatScore - 10) / 2);
	else
		nStatVal = nStatScore;
	end
	
	-- APPLY HALF/DOUBLE MODIFIERS
	if bDouble then
		nStatVal = nStatVal * 2;
	end
	if bHalf then
		nStatVal = math.floor(nStatVal / 2);
	end

	-- RESULTS
	return nStatVal;
end

--
--	DEFENSES
--

function getSpellDefense(rActor)
	if ActorManager.isPC(rActor) then
		local nodeActor = ActorManager.getCreatureNode(rActor);
		if nodeActor then
			return DB.getValue(nodeActor, "defenses.sr.total", 0);
		end
	elseif ActorManager.isRecordType(rActor, "npc") then
		local nodeCT = ActorManager.getCTNode(rActor);
		if nodeCT then
			return DB.getValue(nodeCT, "sr", 0);
		end
		local nodeActor = ActorManager.getCreatureNode(rActor);
		if nodeActor then
			local sSpecialQualities = DB.getValue(nodeActor, "specialqualities", ""):lower();
			local sSpellResist = sSpecialQualities:match("spell resistance (%d+)");
			if not sSpellResist then
				sSpellResist = sSpecialQualities:match("sr (%d+)");
			end
			if sSpellResist then
				return tonumber(sSpellResist) or 0;
			end
		end
	end
	return 0;
end

function getArmorComps(rActor)
	local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if not nodeActor then
		return {};
	end

	local aComps = {};
	
	if sNodeType == "pc" then
		local nACBonusComp = DB.getValue(nodeActor, "ac.sources.armor", 0);
		if nACBonusComp ~= 0 then
			aComps["armor"] = nACBonusComp;
		end
		nACBonusComp = DB.getValue(nodeActor, "ac.sources.shield", 0);
		if nACBonusComp ~= 0 then
			aComps["shield"] = nACBonusComp;
		end
		local sAbility = DB.getValue(nodeActor, "ac.sources.ability", "");
		if DataCommon.ability_ltos[sAbility] then
			aComps[DataCommon.ability_ltos[sAbility]] = getAbilityBonus(rActor, sAbility);
		end
		local sAbility2 = DB.getValue(nodeActor, "ac.sources.ability2", "");
		if DataCommon.ability_ltos[sAbility2] then
			aComps[DataCommon.ability_ltos[sAbility2]] = getAbilityBonus(rActor, sAbility2);
		end
		nACBonusComp = DB.getValue(nodeActor, "ac.sources.size", 0);
		if nACBonusComp ~= 0 then
			aComps["size"] = nACBonusComp;
		end
		nACBonusComp = DB.getValue(nodeActor, "ac.sources.naturalarmor", 0);
		if nACBonusComp ~= 0 then
			aComps["natural"] = nACBonusComp;
		end
		nACBonusComp = DB.getValue(nodeActor, "ac.sources.deflection", 0);
		if nACBonusComp ~= 0 then
			aComps["deflection"] = nACBonusComp;
		end
		nACBonusComp = DB.getValue(nodeActor, "ac.sources.dodge", 0);
		if nACBonusComp ~= 0 then
			aComps["dodge"] = nACBonusComp;
		end
		nACBonusComp = DB.getValue(nodeActor, "ac.sources.misc", 0);
		if nACBonusComp ~= 0 then
			aComps["misc"] = nACBonusComp;
		end
	elseif ActorManager.isRecordType(rActor, "npc") then
		local sAC = DB.getValue(nodeActor, "ac", ""):lower();
		local nAC = tonumber(sAC:match("^(%d+)")) or 10;
		local sACComps = sAC:match("%(([^)]+)%)");
		local nCompTotal = 10;
		if sACComps then
			local aACSplit = StringManager.split(sACComps, ",", true);
			for _,vACComp in ipairs(aACSplit) do
				local sACCompBonus, sACCompType = vACComp:match("^([+-]%d+)%s+(.*)$");
				if not sACCompType then
					sACCompType, sACCompBonus = vACComp:match("^(.*)%s+([+-]%d+)$");
				end
				local nACCompBonus = tonumber(sACCompBonus) or 0;
				if sACCompType and nACCompBonus ~= 0 then
					sACCompType = sACCompType:gsub("[+-]%d+", "");
					sACCompType = StringManager.trim(sACCompType);
					
					if DataCommon.actypes[sACCompType] then
						aComps[DataCommon.actypes[sACCompType]] = nACCompBonus;
						nCompTotal = nCompTotal + nACCompBonus;
					elseif StringManager.contains (DataCommon.acarmormatch, sACCompType) then
						aComps["armor"] = nACCompBonus;
						nCompTotal = nCompTotal + nACCompBonus;
					elseif StringManager.contains (DataCommon.acshieldmatch, sACCompType) then
						aComps["shield"] = nACCompBonus;
						nCompTotal = nCompTotal + nACCompBonus;
					elseif StringManager.contains (DataCommon.acdeflectionmatch, sACCompType) then
						aComps["deflection"] = nACCompBonus;
						nCompTotal = nCompTotal + nACCompBonus;
					end
				end
			end
		end
		if nCompTotal ~= nAC then
			aComps["misc"] = nAC - nCompTotal;
		end
	end

	return aComps;
end

function getDefenseValue(rAttacker, rDefender, rRoll)
	-- VALIDATE
	if not rDefender or not rRoll then
		return nil, 0, 0, 0;
	end
	
	local sAttack = rRoll.sDesc;
	
	-- DETERMINE ATTACK TYPE AND DEFENSE
	local sAttackType = "M";
	if rRoll.sType == "attack" then
		sAttackType = ActionAttackCore.decodeRangeText(sAttack);
	end
	local bOpportunity = string.match(sAttack, "%[OPPORTUNITY%]");
	local bTouch = true;
	if rRoll.sType == "attack" then
		bTouch = string.match(sAttack, "%[TOUCH%]");
	end
	-- KEL Putting this definition already here, was for implementing ghost armor but maybe I do not need this anymore
	local bIncorporealAttack = sAttack:match("%[INCORPOREAL%]");
	-- if string.match(sAttack, "%[INCORPOREAL%]") then
		-- bIncorporealAttack = true;
	-- end
	-- KEL check for uncanny dodge here not needed, but maybe a security check?
	local bFlatFooted = sAttack:match("%[FF%]");
	local nCover = tonumber(sAttack:match("%[COVER %-(%d)%]")) or 0;
	local bConceal = sAttack:match("%[CONCEAL%]");
	local bTotalConceal = sAttack:match("%[TOTAL CONC%]");
	local bAttackerBlinded = sAttack:match("%[BLINDED%]");

	-- Determine the defense database node name
	local nDefense = 10;
	local nFlatFootedMod = 0;
	local nTouchMod = 0;
	local sDefenseStat = "dexterity";
	local sDefenseStat2 = "";
	local sDefenseStat3 = "";
	if rRoll.sType == "grapple" then
		sDefenseStat3 = "strength";
	end

	local sDefenderNodeType, nodeDefender = ActorManager.getTypeAndNode(rDefender);
	if not nodeDefender then
		return nil, 0, 0, 0;
	end

	if sDefenderNodeType == "pc" then
		if rRoll.sType == "attack" then
			nDefense = DB.getValue(nodeDefender, "ac.totals.general", 10);
			nFlatFootedMod = nDefense - DB.getValue(nodeDefender, "ac.totals.flatfooted", 10);
			nTouchMod = nDefense - DB.getValue(nodeDefender, "ac.totals.touch", 10);
		else
			nDefense = DB.getValue(nodeDefender, "ac.totals.cmd", 10);
			nFlatFootedMod = DB.getValue(nodeDefender, "ac.totals.general", 10) - DB.getValue(nodeDefender, "ac.totals.flatfooted", 10);
		end
		sDefenseStat = DB.getValue(nodeDefender, "ac.sources.ability", "");
		if sDefenseStat == "" then
			sDefenseStat = "dexterity";
		end
		sDefenseStat2 = DB.getValue(nodeDefender, "ac.sources.ability2", "");
		if rRoll.sType == "grapple" then
			sDefenseStat3 = DB.getValue(nodeDefender, "ac.sources.cmdability", "");
			if sDefenseStat3 == "" then
				sDefenseStat3 = "strength";
			end
		end
	elseif sDefenderNodeType == "ct" then
		if rRoll.sType == "attack" then
			nDefense = DB.getValue(nodeDefender, "ac_final", 10);
			nFlatFootedMod = nDefense - DB.getValue(nodeDefender, "ac_flatfooted", 10);
			nTouchMod = nDefense - DB.getValue(nodeDefender, "ac_touch", 10);
		else
			nDefense = DB.getValue(nodeDefender, "cmd", 10);
			nFlatFootedMod = DB.getValue(nodeDefender, "ac_final", 10) - DB.getValue(nodeDefender, "ac_flatfooted", 10);
		end
	elseif sDefenderNodeType == "npc" then
		if rRoll.sType == "attack" then
			local sAC = DB.getValue(nodeDefender, "ac", "");
			nDefense = tonumber(string.match(sAC, "^%s*(%d+)")) or 10;

			local sFlatFootedAC = string.match(sAC, "flat-footed (%d+)");
			if sFlatFootedAC then
				nFlatFootedMod = nDefense - tonumber(sFlatFootedAC);
			else
				nFlatFootedMod = getAbilityBonus(rDefender, sDefenseStat);
			end
			
			local sTouchAC = string.match(sAC, "touch (%d+)");
			if sTouchAC then
				nTouchMod = nDefense - tonumber(sTouchAC);
			end
		else
			local sBABGrp = DB.getValue(nodeDefender, "babgrp", "");
			local sMatch = string.match(sBABGrp, "CMD ([+-]?[0-9]+)");
			if sMatch then
				nDefense = tonumber(sMatch) or 10;
			else
				nDefense = 10;
			end
			
			local sAC = DB.getValue(nodeDefender, "ac", "");
			local nAC = tonumber(string.match(sAC, "^%s*(%d+)")) or 10;

			local sFlatFootedAC = string.match(sAC, "flat-footed (%d+)");
			if sFlatFootedAC then
				nFlatFootedMod = nAC - (tonumber(sFlatFootedAC) or 10);
			else
				nFlatFootedMod = getAbilityBonus(rDefender, sDefenseStat);
			end
		end
	end

	nDefenseStatMod = getAbilityBonus(rDefender, sDefenseStat) + getAbilityBonus(rDefender, sDefenseStat2);
	
	-- MAKE SURE FLAT-FOOTED AND TOUCH ADJUSTMENTS ARE POSITIVE
	if nTouchMod < 0 then
		nTouchMod = 0;
	end
	if nFlatFootedMod < 0 then
		nFlatFootedMod = 0;
	end
	
	-- APPLY FLAT-FOOTED AND TOUCH ADJUSTMENTS
	if bTouch then
		nDefense = nDefense - nTouchMod;
	end
	if bFlatFooted then
		nDefense = nDefense - nFlatFootedMod;
	end
	
	-- EFFECT MODIFIERS
	local nDefenseEffectMod = 0;
	-- KEL ACCC stuff
	local nAdditionalDefenseForCC = 0;
	local nMissChance = 0;
	if ActorManager.hasCT(rDefender) then
		-- SETUP
		local bCombatAdvantage = false;
		local bZeroAbility = false;
		local nBonusAC = 0;
		-- KEL ACCC
		local nBonusACCC = 0;
		local nBonusStat = 0;
		local nBonusSituational = 0;
		
		local bPFMode = DataCommon.isPFRPG();
		
		-- BUILD ATTACK FILTER 
		local aAttackFilter = {};
		if sAttackType == "M" then
			table.insert(aAttackFilter, "melee");
		elseif sAttackType == "R" then
			table.insert(aAttackFilter, "ranged");
		end
		if bOpportunity then
			table.insert(aAttackFilter, "opportunity");
		end
					
		-- CHECK IF COMBAT ADVANTAGE ALREADY SET BY ATTACKER EFFECT
		if sAttack:match("%[CA%]") then
			bCombatAdvantage = true;
		end
		
		-- GET DEFENDER SITUATIONAL MODIFIERS - GENERAL
		-- KEL adding uncanny dodge, blind-fight and ethereal; also improving performance a little bit
		if EffectManager35E.hasEffect(rAttacker, "Ethereal", rDefender, true, false, rRoll.tags) then
			nBonusSituational = nBonusSituational - 2;
			if not ActorManager35E.hasSpecialAbility(rDefender, "Uncanny Dodge", false, false, true) then
				bCombatAdvantage = true;
			end
		elseif EffectManager35E.hasEffect(rAttacker, "Invisible", rDefender, true, false, rRoll.tags) then
			local bBlindFight = ActorManager35E.hasSpecialAbility(rDefender, "Blind-Fight", true, false, false);
			if sAttackType == "R" or not bBlindFight then
				nBonusSituational = nBonusSituational - 2;
				if not ActorManager35E.hasSpecialAbility(rDefender, "Uncanny Dodge", false, false, true) then
					bCombatAdvantage = true;
				end
			end
		end
		if EffectManager35E.hasEffect(rAttacker, "CA", rDefender, true, false, rRoll.tags) then
			bCombatAdvantage = true;
		elseif EffectManager35E.hasEffect(rDefender, "GRANTCA", rAttacker, false, false, rRoll.tags) then
			bCombatAdvantage = true;
		end
		-- END
		if EffectManager35E.hasEffect(rDefender, "Blinded", nil, false, false, rRoll.tags) then
			nBonusSituational = nBonusSituational - 2;
			bCombatAdvantage = true;
		end
		if EffectManager35E.hasEffect(rDefender, "Cowering", nil, false, false, rRoll.tags) or
				EffectManager35E.hasEffect(rDefender, "Rebuked", nil, false, false, rRoll.tags) then
			nBonusSituational = nBonusSituational - 2;
			bCombatAdvantage = true;
		end
		if EffectManager35E.hasEffect(rDefender, "Slowed", nil, false, false, rRoll.tags) then
			nBonusSituational = nBonusSituational - 1;
		end
		-- KEL adding uncanny dodge
		if ( ( EffectManager35E.hasEffect(rDefender, "Flat-footed", nil, false, false, rRoll.tags) or 
				EffectManager35E.hasEffect(rDefender, "Flatfooted", nil, false, false, rRoll.tags) ) and not
				ActorManager35E.hasSpecialAbility(rDefender, "Uncanny Dodge", false, false, true) ) or 
				EffectManager35E.hasEffect(rDefender, "Climbing", nil, false, false, rRoll.tags) or 
				EffectManager35E.hasEffect(rDefender, "Running", nil, false, false, rRoll.tags) then
			bCombatAdvantage = true;
		end
		if EffectManager35E.hasEffect(rDefender, "Pinned", nil, false, false, rRoll.tags) then
			bCombatAdvantage = true;
			if bPFMode then
				nBonusSituational = nBonusSituational - 4;
			else
				if not EffectManager35E.hasEffect(rAttacker, "Grappled", nil, false, false, rRoll.tags) then
					nBonusSituational = nBonusSituational - 4;
				end
			end
		elseif not bPFMode and EffectManager35E.hasEffect(rDefender, "Grappled", nil, false, false, rRoll.tags) then
			if not EffectManager35E.hasEffect(rAttacker, "Grappled", nil, false, false, rRoll.tags) then
				bCombatAdvantage = true;
			end
		end
		if EffectManager35E.hasEffect(rDefender, "Helpless", nil, false, false, rRoll.tags) or 
				EffectManager35E.hasEffect(rDefender, "Paralyzed", nil, false, false, rRoll.tags) or 
				EffectManager35E.hasEffect(rDefender, "Petrified", nil, false, false, rRoll.tags) or
				EffectManager35E.hasEffect(rDefender, "Unconscious", nil, false, false, rRoll.tags) then
			if sAttackType == "M" then
				nBonusSituational = nBonusSituational - 4;
			end
			bZeroAbility = true;
		end
		if EffectManager35E.hasEffect(rDefender, "Kneeling", nil, false, false, rRoll.tags) or 
				EffectManager35E.hasEffect(rDefender, "Sitting", nil, false, false, rRoll.tags) then
			if sAttackType == "M" then
				nBonusSituational = nBonusSituational - 2;
			elseif sAttackType == "R" then
				nBonusSituational = nBonusSituational + 2;
			end
		elseif EffectManager.hasCondition(rDefender, "Prone") then
			if sAttackType == "M" then
				nBonusSituational = nBonusSituational - 4;
			elseif sAttackType == "R" then
				nBonusSituational = nBonusSituational + 4;
			end
		end
		if EffectManager35E.hasEffect(rDefender, "Squeezing", nil, false, false, rRoll.tags) then
			nBonusSituational = nBonusSituational - 4;
		end
		if EffectManager35E.hasEffect(rDefender, "Stunned", nil, false, false, rRoll.tags) then
			nBonusSituational = nBonusSituational - 2;
			if rRoll.sType == "grapple" then
				nBonusSituational = nBonusSituational - 4;
			end
			bCombatAdvantage = true;
		end
		-- KEL Ethereal
		if EffectManager35E.hasEffect(rDefender, "Invisible", rAttacker, false, false, rRoll.tags) or EffectManager35E.hasEffect(rDefender, "Ethereal", rAttacker, false, false, rRoll.tags) then
			bTotalConceal = true;
		end
		-- END
		-- DETERMINE EXISTING AC MODIFIER TYPES
		local aExistingBonusByType = getArmorComps (rDefender);
		
		-- GET DEFENDER ALL DEFENSE MODIFIERS
		local aIgnoreEffects = {};
		if bTouch then
			table.insert(aIgnoreEffects, "armor");
			table.insert(aIgnoreEffects, "shield");
			table.insert(aIgnoreEffects, "natural");

			-- Add Extended AC Bonuses (https://github.com/FG-Unofficial-Developers-Guild/FG-PFRPG-ExtendedACBonusTypes)
			table.insert(aIgnoreEffects, "naturalsize");
			table.insert(aIgnoreEffects, "armorenhancement");
			table.insert(aIgnoreEffects, "shieldenhancement");
			table.insert(aIgnoreEffects, "naturalenhancement");
		end
		if bFlatFooted or bCombatAdvantage then
			table.insert(aIgnoreEffects, "dodge");
		end
		if rRoll.sType == "grapple" then
			table.insert(aIgnoreEffects, "size");
		end
		local aACEffects = EffectManager35E.getEffectsBonusByType(rDefender, {"AC"}, true, aAttackFilter, rAttacker, false, rRoll.tags);
		for k,v in pairs(aACEffects) do
			if not StringManager.contains(aIgnoreEffects, k) then
				local sBonusType = DataCommon.actypes[k];
				if sBonusType then
					-- Dodge bonuses stack (by rules)
					if sBonusType == "dodge" then
						nBonusAC = nBonusAC + v.mod;
					-- elseif sBonusType == "ghost" then; KEL Deprecated at the moment
						-- nBonusAC = nBonusAC + v.mod;
					-- Size bonuses stack (by usage expectation)
					elseif sBonusType == "size" then
						nBonusAC = nBonusAC + v.mod;
					elseif aExistingBonusByType[sBonusType] then
						if v.mod < 0 then
							nBonusAC = nBonusAC + v.mod;
						elseif v.mod > aExistingBonusByType[sBonusType] then
							nBonusAC = nBonusAC + v.mod - aExistingBonusByType[sBonusType];
							-- KEL change aExistingBonusByType for the ACCC stacking check
							aExistingBonusByType[sBonusType] = v.mod;
						end
					else
						nBonusAC = nBonusAC + v.mod;
						-- KEL Create aExistingBonusByType for ACCC stacking check
						aExistingBonusByType[sBonusType] = v.mod;
					end
				else
					nBonusAC = nBonusAC + v.mod;
				end
			end
		end
		-- KEL rmilmine ACCC requested, beware stacking stuff
		local aACCCEffects = EffectManager35E.getEffectsBonusByType(rDefender, {"ACCC"}, true, aAttackFilter, rAttacker, false, rRoll.tags);
		for k,v in pairs(aACCCEffects) do
			if not StringManager.contains(aIgnoreEffects, k) then
				local sBonusType = DataCommon.actypes[k];
				if sBonusType then
					-- Dodge bonuses stack (by rules)
					if sBonusType == "dodge" then
						nBonusACCC = nBonusACCC + v.mod;
					-- Size bonuses stack (by usage expectation)
					elseif sBonusType == "size" then
						nBonusACCC = nBonusACCC + v.mod;
					elseif aExistingBonusByType[sBonusType] then
						if v.mod < 0 then
							nBonusACCC = nBonusACCC + v.mod;
						elseif v.mod > aExistingBonusByType[sBonusType] then
							nBonusACCC = nBonusACCC + v.mod - aExistingBonusByType[sBonusType];
							aExistingBonusByType[sBonusType] = v.mod;
						end
					else
						nBonusACCC = nBonusACCC + v.mod;
						aExistingBonusByType[sBonusType] = v.mod;
					end
				else
					nBonusACCC = nBonusACCC + v.mod;
				end
			end
		end
		-- END
		if rRoll.sType == "grapple" then
			local nPFMod, nPFCount = EffectManager35E.getEffectsBonus(rDefender, {"CMD"}, true, aAttackFilter, rAttacker, false, rRoll.tags);
			if nPFCount > 0 then
				nBonusAC = nBonusAC + nPFMod;
			end
		end
		
		-- GET DEFENDER DEFENSE STAT MODIFIERS
		local nBonusStat = 0;
		-- Kel Also here tags, everywhere :D
		local nBonusStat1 = getAbilityEffectsBonus(rDefender, sDefenseStat, rRoll.tags);
		if (sDefenderNodeType == "pc") and (nBonusStat1 > 0) then
			if DB.getValue(nodeDefender, "encumbrance.armormaxstatbonusactive", 0) == 1 then
				local nCurrentStatBonus = getAbilityBonus(rDefender, sDefenseStat);
				local nMaxStatBonus = math.max(DB.getValue(nodeDefender, "encumbrance.armormaxstatbonus", 0), 0);
				local nMaxEffectStatModBonus = math.max(nMaxStatBonus - nCurrentStatBonus, 0);
				if nBonusStat1 > nMaxEffectStatModBonus then 
					nBonusStat1 = nMaxEffectStatModBonus; 
				end
			end
		end
		if not bFlatFooted and not bCombatAdvantage and sDefenseStat == "dexterity" then
			nFlatFootedMod = nFlatFootedMod + nBonusStat1;
		end
		nBonusStat = nBonusStat + nBonusStat1;
		local nBonusStat2 = getAbilityEffectsBonus(rDefender, sDefenseStat2, rRoll.tags);
		if not bFlatFooted and not bCombatAdvantage and sDefenseStat2 == "dexterity" then
			nFlatFootedMod = nFlatFootedMod + nBonusStat2;
		end
		nBonusStat = nBonusStat + nBonusStat2;
		local nBonusStat3 = getAbilityEffectsBonus(rDefender, sDefenseStat3, rRoll.tags);
		if not bFlatFooted and not bCombatAdvantage and sDefenseStat3 == "dexterity" then
			nFlatFootedMod = nFlatFootedMod + nBonusStat3;
		end
		nBonusStat = nBonusStat + nBonusStat3;
		if bFlatFooted or bCombatAdvantage then
			-- IF NEGATIVE AND AC STAT BONUSES, THEN ONLY APPLY THE AMOUNT THAT EXCEEDS AC STAT BONUSES
			if nBonusStat < 0 then
				if nDefenseStatMod > 0 then
					nBonusStat = math.min(nDefenseStatMod + nBonusStat, 0);
				end
				
			-- IF POSITIVE AND AC STAT PENALTIES, THEN ONLY APPLY UP TO AC STAT PENALTIES
			else
				if nDefenseStatMod < 0 then
					nBonusStat = math.min(nBonusStat, -nDefenseStatMod);
				else
					nBonusStat = 0;
				end
			end
		end
		
		-- HANDLE NEGATIVE LEVELS
		if rRoll.sType == "grapple" then
			local nNegLevelMod, nNegLevelCount = EffectManager35E.getEffectsBonus(rDefender, {"NLVL"}, true, nil, nil, false, rRoll.tags);
			if nNegLevelCount > 0 then
				nBonusSituational = nBonusSituational - nNegLevelMod;
			end
		end
		
		-- HANDLE DEXTERITY MODIFIER REMOVAL
		if bZeroAbility then
			if bFlatFooted then
				nBonusSituational = nBonusSituational - 5;
			else
				nBonusSituational = nBonusSituational - nFlatFootedMod - 5;
			end
		elseif bCombatAdvantage and not bFlatFooted then
			nBonusSituational = nBonusSituational - nFlatFootedMod;
		end

		-- GET DEFENDER SITUATIONAL MODIFIERS - COVER
		if nCover < 8 then
			local aCover = EffectManager35E.getEffectsByType(rDefender, "SCOVER", aAttackFilter, rAttacker, false, rRoll.tags);
			if #aCover > 0 or EffectManager35E.hasEffect(rDefender, "SCOVER", rAttacker, false, false, rRoll.tags) then
				nBonusSituational = nBonusSituational + 8 - nCover;
			elseif nCover < 4 then
				aCover = EffectManager35E.getEffectsByType(rDefender, "COVER", aAttackFilter, rAttacker, false, rRoll.tags);
				if #aCover > 0 or EffectManager35E.hasEffect(rDefender, "COVER", rAttacker, false, false, rRoll.tags) then
					nBonusSituational = nBonusSituational + 4 - nCover;
				elseif nCover < 2 then
					aCover = EffectManager35E.getEffectsByType(rDefender, "PCOVER", aAttackFilter, rAttacker, false, rRoll.tags);
					if #aCover > 0 or EffectManager35E.hasEffect(rDefender, "PCOVER", rAttacker, false, false, rRoll.tags) then
						nBonusSituational = nBonusSituational + 2 - nCover;
					end
				end
			end
		end
		
		-- GET DEFENDER SITUATIONAL MODIFIERS - CONCEALMENT
		-- KEL Variable concealment; do not use getEffectsBonus because we do not want that untyped boni are stacking
		local aVConcealEffect, aVConcealCount = EffectManager35E.getEffectsBonusByType(rDefender, "VCONC", true, aAttackFilter, rAttacker, false, rRoll.tags);
		
		if aVConcealCount > 0 then
			for _,v in  pairs(aVConcealEffect) do
				nMissChance = math.max(v.mod,nMissChance);
			end
		end
		-- END variable concealment but check that CONC and TCONC etc. do not overwrite VCONC and only maximum value is taken
		if not (nMissChance >= 50) then
			local aConceal = EffectManager35E.getEffectsByType(rDefender, "TCONC", aAttackFilter, rAttacker, false, rRoll.tags);
			if #aConceal > 0 or EffectManager35E.hasEffect(rDefender, "TCONC", rAttacker, false, false, rRoll.tags) or bTotalConceal or bAttackerBlinded then
				nMissChance = 50;
			elseif not (nMissChance >= 20) then
				aConceal = EffectManager35E.getEffectsByType(rDefender, "CONC", aAttackFilter, rAttacker, false, rRoll.tags);
				if #aConceal > 0 or EffectManager35E.hasEffect(rDefender, "CONC", rAttacker, false, false, rRoll.tags) or bConceal then
					nMissChance = 20;
				end
			end
		end
		
		-- CHECK INCORPOREALITY
		if not bPFMode and (nMissChance < 50) then
			local bIncorporealDefender = EffectManager35E.hasEffect(rDefender, "Incorporeal", rAttacker, false, false, rRoll.tags);
			local bGhostTouchAttacker = EffectManager35E.hasEffect(rAttacker, "ghost touch", rDefender, false, false, rRoll.tags);

			if bIncorporealDefender and not bGhostTouchAttacker and not bIncorporealAttack then
				nMissChance = 50;
			end
		end
		
		-- ADD IN EFFECT MODIFIERS
		nDefenseEffectMod = nBonusAC + nBonusStat + nBonusSituational;
		-- KEL ACCC
		nAdditionalDefenseForCC = nBonusACCC;
	
	-- NO DEFENDER SPECIFIED, SO JUST LOOK AT THE ATTACK ROLL MODIFIERS, here no math.max needed but to be sure...
	else
		if bTotalConceal or bAttackerBlinded then
			nMissChance = math.max(50,nMissChance);
		elseif bConceal then
			nMissChance = math.max(20,nMissChance);
		end
		-- KEL the following is useless :)
		local bPFMode = DataCommon.isPFRPG();
		if bIncorporealAttack and not bPFMode then
			nMissChance = math.max(50,nMissChance);
		end
	end
	
	-- Return the final defense value
	-- KEL ACCC output
	return nDefense, 0, nDefenseEffectMod, nMissChance, nAdditionalDefenseForCC;
end

-- BMOS's feat search etc., see also CharManager hasFeat and hasTrait
function hasSpecialAbility(rActor, sSearchStringIni, bFeat, bTrait, bSpecialAbility)
	if not rActor or not sSearchStringIni then
		return false;
	end
	local nodeActor = rActor.sCreatureNode;

	local sSearchString = string.lower(sSearchStringIni);
	local sSearchString = string.gsub(sSearchString, '%-', '%%%-');
	-- local sSearchString = StringManager.trim(sSearchStringIni:lower());
	if ActorManager.isPC(nodeActor) then
		if bFeat then
			for _,vNode in ipairs(DB.getChildList(nodeActor .. '.featlist')) do
				local sFeatName = StringManager.trim(DB.getValue(vNode, 'name', ''):lower());
				if sFeatName and string.match(sFeatName, sSearchString) then
					return true;
				end
			end
		end
		if bTrait then
			for _,vNode in ipairs(DB.getChildList(nodeActor .. '.traitlist')) do
				local sTraitName = StringManager.trim(DB.getValue(vNode, 'name', ''):lower());
				if sTraitName and string.match(sTraitName, sSearchString) then
					return true;
				end
			end
		end
		if bSpecialAbility then
			for _,vNode in ipairs(DB.getChildList(nodeActor .. '.specialabilitylist')) do
				local sSpecialAbilityName = StringManager.trim(DB.getValue(vNode, 'name', ''):lower());
				if sSpecialAbilityName and string.match(sSpecialAbilityName, sSearchString) then
					return true;
				end
			end
		end
	else
		local sSpecialQualities = string.lower(DB.getValue(nodeActor .. '.specialqualities', ''));
		local sSpecAtks = string.lower(DB.getValue(nodeActor .. '.specialattacks', ''));
		local sFeats = string.lower(DB.getValue(nodeActor .. '.feats', ''));

		if bFeat and string.find(sFeats, sSearchString) then
			return true;
		elseif bSpecialAbility and (string.find(sSpecAtks, sSearchString) or string.find(sSpecialQualities, sSearchString)) then
			return true;
		end
	end
	
	return false;
end
-- END
