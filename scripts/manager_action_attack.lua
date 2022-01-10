-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

OOB_MSGTYPE_APPLYATK = "applyatk";
OOB_MSGTYPE_APPLYHRFC = "applyhrfc";
-- KEL AoO
OOB_MSGTYPE_APPLYAOO = "applyaoo";
-- END
function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYATK, handleApplyAttack);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYHRFC, handleApplyHRFC);
	-- KEL AoO
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYAOO, handleApplyAoO);
	-- END
	ActionsManager.registerTargetingHandler("attack", onTargeting);

	ActionsManager.registerModHandler("attack", modAttack);
	ActionsManager.registerModHandler("grapple", modAttack);
	
	ActionsManager.registerResultHandler("attack", onAttack);
	ActionsManager.registerResultHandler("critconfirm", onAttack);
	ActionsManager.registerResultHandler("misschance", onMissChance);
	ActionsManager.registerResultHandler("grapple", onGrapple);
end

function handleApplyAttack(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	
	local nTotal = tonumber(msgOOB.nTotal) or 0;
	applyAttack(rSource, rTarget, (tonumber(msgOOB.nSecret) == 1), msgOOB.sAttackType, msgOOB.sDesc, nTotal, msgOOB.sResults);
end

function notifyApplyAttack(rSource, rTarget, bSecret, sAttackType, sDesc, nTotal, sResults)
	if not rTarget then
		return;
	end

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYATK;
	
	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	msgOOB.sAttackType = sAttackType;
	msgOOB.nTotal = nTotal;
	msgOOB.sDesc = sDesc;
	msgOOB.sResults = sResults;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);

	Comm.deliverOOBMessage(msgOOB, "");
end

function handleApplyHRFC(msgOOB)
	TableManager.processTableRoll("", msgOOB.sTable);
end

function notifyApplyHRFC(sTable)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYHRFC;
	
	msgOOB.sTable = sTable;

	Comm.deliverOOBMessage(msgOOB, "");
end

function onTargeting(rSource, aTargeting, rRolls)
	if OptionsManager.isOption("RMMT", "multi") then
		local aTargets = {};
		for _,vTargetGroup in ipairs(aTargeting) do
			for _,vTarget in ipairs(vTargetGroup) do
				table.insert(aTargets, vTarget);
			end
		end
		if #aTargets > 1 then
			for _,vRoll in ipairs(rRolls) do
				if not string.match(vRoll.sDesc, "%[FULL%]") then
					vRoll.bRemoveOnMiss = "true";
				end
			end
		end
	end
	return aTargeting;
end

function performPartySheetVsRoll(draginfo, rActor, rAction)
	local rRoll = getRoll(nil, rAction);
	
	if DB.getValue("partysheet.hiderollresults", 0) == 1 then
		rRoll.bSecret = true;
		rRoll.bTower = true;
	end
	
	ActionsManager.actionDirect(nil, "attack", { rRoll }, { { rActor } });
end

function performRoll(draginfo, rActor, rAction)
	local rRoll = getRoll(rActor, rAction);
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end
-- KEL add tag argument
function getRoll(rActor, rAction, tag)
	local rRoll = {};
	if rAction.cm then
		rRoll.sType = "grapple";
	else
		rRoll.sType = "attack";
	end
	rRoll.aDice = { "d20" };
	rRoll.nMod = rAction.modifier or 0;
	
	if rAction.cm then
		rRoll.sDesc = "[CMB";
		if rAction.order and rAction.order > 1 then
			rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
		end
		rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;
	else
		rRoll.sDesc = "[ATTACK";
		if rAction.order and rAction.order > 1 then
			rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
		end
		if rAction.range then
			rRoll.sDesc = rRoll.sDesc .. " (" .. rAction.range .. ")";
		end
		rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;
	end
	
	-- Add ability modifiers
	if rAction.stat then
		if (rAction.range == "M" and rAction.stat ~= "strength") or (rAction.range == "R" and rAction.stat ~= "dexterity") then
			local sAbilityEffect = DataCommon.ability_ltos[rAction.stat];
			if sAbilityEffect then
				rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
			end
		end
	end
	
	-- Add other modifiers
	-- KEL compatibility with KEEN and iftag stuff; EDIT: Moving KEEN stuff such that it is targetable. Hence, saving crit value
	rRoll.tags = tag;
	rRoll.crit = rAction.crit;
	-- END
	
	if rAction.touch then
		rRoll.sDesc = rRoll.sDesc .. " [TOUCH]";
	end
	
	-- KEL Compatibility with mirrorimage
	if MirrorImageHandler and rAction.misfire then
		rRoll.sDesc = rRoll.sDesc .. " [MISFIRE " .. rAction.misfire .. "]";
	end
	-- END
	
	-- KEL Save overlay only for spell actions
	if rAction.spell then
		rRoll.sDesc = rRoll.sDesc .. " [ACTION]";
	end
	-- END
	
	return rRoll;
end

function performGrappleRoll(draginfo, rActor, rAction)
	local rRoll = getGrappleRoll(rActor, rAction);
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function getGrappleRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "grapple";
	rRoll.aDice = { "d20" };
	rRoll.nMod = rAction.modifier or 0;
	
	if DataCommon.isPFRPG() then
		rRoll.sDesc = "[CMB]";
	else
		rRoll.sDesc = "[GRAPPLE]";
	end
	if rAction.label and rAction.label ~= "" then
		rRoll.sDesc = rRoll.sDesc .. " " .. rAction.label;
	end
	
	-- Add ability modifiers
	if rAction.stat then
		if rAction.stat ~= "strength" then
			local sAbilityEffect = DataCommon.ability_ltos[rAction.stat];
			if sAbilityEffect then
				rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
			end
		end
	end
	
	return rRoll;
end

-- KEL AoO
function handleApplyAoO(msgOOB)
	-- local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rSourceCTNode = ActorManager.getCTNode(msgOOB.sSourceNode);
	local aoo = DB.getValue(rSourceCTNode, "aoo", 0) + 1;
	DB.setValue(rSourceCTNode, "aoo", "number", aoo);
end
-- END

function modAttack(rSource, rTarget, rRoll)
	clearCritState(rSource);
	local aAddDesc = {};
	local aAddDice = {};
	local nAddMod = 0;
	
	-- Check for opportunity attack
	local bOpportunity = ModifierManager.getKey("ATT_OPP") or Input.isShiftPressed();

	-- Check defense modifiers
	local bTouch = ModifierManager.getKey("ATT_TCH");
	local bFlatFooted = ModifierManager.getKey("ATT_FF");
	local bCover = ModifierManager.getKey("DEF_COVER");
	local bPartialCover = ModifierManager.getKey("DEF_PCOVER");
	local bSuperiorCover = ModifierManager.getKey("DEF_SCOVER");
	local bConceal = ModifierManager.getKey("DEF_CONC");
	local bTotalConceal = ModifierManager.getKey("DEF_TCONC");
	
	if bOpportunity then
		table.insert(aAddDesc, "[OPPORTUNITY]");
		-- KEL AoO
		if Session.IsHost then
			local rSourceCTNode = ActorManager.getCTNode(rSource);
			local aoo = DB.getValue(rSourceCTNode, "aoo", 0) + 1;
			DB.setValue(rSourceCTNode, "aoo", "number", aoo);
		else
			local msgOOB = {};
			msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
			msgOOB.type = OOB_MSGTYPE_APPLYAOO;
			Comm.deliverOOBMessage(msgOOB, "");
		end
		--END
	end
	if bTouch then
		if not string.match(rRoll.sDesc, "%[TOUCH%]") then
			table.insert(aAddDesc, "[TOUCH]");
		end
	end
	-- KEL adding uncanny dodge
	if bFlatFooted and not ActorManager35E.hasSpecialAbility(rTarget, "Uncanny Dodge", false, false, true) then
		table.insert(aAddDesc, "[FF]");
	end
	if bSuperiorCover then
		table.insert(aAddDesc, "[COVER -8]");
	elseif bCover then
		table.insert(aAddDesc, "[COVER -4]");
	elseif bPartialCover then
		table.insert(aAddDesc, "[COVER -2]");
	end
	if bConceal then
		table.insert(aAddDesc, "[CONCEAL]");
	end
	if bTotalConceal then
		table.insert(aAddDesc, "[TOTAL CONC]");
	end
	
	if rSource then
		-- Determine attack type
		local sAttackType = nil;
		if rRoll.sType == "attack" then
			sAttackType = string.match(rRoll.sDesc, "%[ATTACK.*%((%w+)%)%]");
			if not sAttackType then
				sAttackType = "M";
			end
		elseif rRoll.sType == "grapple" then
			sAttackType = "M";
		end

		-- Determine ability used
		local sActionStat = nil;
		local sModStat = string.match(rRoll.sDesc, "%[MOD:(%w+)%]");
		if sModStat then
			sActionStat = DataCommon.ability_stol[sModStat];
		end
		if not sActionStat then
			if sAttackType == "M" then
				sActionStat = "strength";
			elseif sAttackType == "R" then
				sActionStat = "dexterity";
			end
		end

		-- Build attack filter
		local aAttackFilter = {};
		if sAttackType == "M" then
			table.insert(aAttackFilter, "melee");
		elseif sAttackType == "R" then
			table.insert(aAttackFilter, "ranged");
		end
		if bOpportunity then
			table.insert(aAttackFilter, "opportunity");
		end
		
		-- Get condition modifiers; KEL moved it here for nodex automation later (not yet done) such that following effects can profit from it; similar for bEffects; adding ethereal
		local bEffects = false;
		if EffectManager35E.hasEffect(rSource, "Ethereal", nil, false, false, rRoll.tags) then
			bEffects = true;
			nAddMod = nAddMod + 2;
			if not ActorManager35E.hasSpecialAbility(rTarget, "Uncanny Dodge", false, false, true) then
				table.insert(aAddDesc, "[CA]");
			end
		elseif EffectManager35E.hasEffect(rSource, "Invisible", nil, false, false, rRoll.tags) then
			-- KEL blind fight, skipping checking effects for now (for performance and to avoid problems with On Skip etc.)
			local bBlindFight = ActorManager35E.hasSpecialAbility(rTarget, "Blind-Fight", true, false, false);
			if sAttackType == "R" or not bBlindFight then
				bEffects = true;
				nAddMod = nAddMod + 2;
				if not ActorManager35E.hasSpecialAbility(rTarget, "Uncanny Dodge", false, false, true) then
					table.insert(aAddDesc, "[CA]");
				end
			end
			-- END
		elseif EffectManager35E.hasEffect(rSource, "CA", nil, false, false, rRoll.tags) then
			bEffects = true;
			table.insert(aAddDesc, "[CA]");
		end
		-- END
		-- Get attack effect modifiers
		-- KEL New KEEN code for allowing several new configurations
		local rActionCrit = tonumber(rRoll.crit) or 20;
		local aKEEN = EffectManager35E.getEffectsByType(rSource, "KEEN", aAttackFilter, rTarget, false, rRoll.tags);
		if (#aKEEN > 0) or EffectManager35E.hasEffect(rSource, "KEEN", rTarget, false, false, rRoll.tags) then
			rActionCrit = 20 - ((20 - rActionCrit + 1) * 2) + 1;
			bEffects = true;
		end
		if rActionCrit < 20 then
			table.insert(aAddDesc, "[CRIT " .. rActionCrit .. "]");
		end
		-- END
		-- KEL add tags, and relabel nAddMod to nAddModi to avoid overwriting the previous nAddMod
		local nEffectCount;
		aAddDice, nAddModi, nEffectCount = EffectManager35E.getEffectsBonus(rSource, {"ATK"}, false, aAttackFilter, rTarget, false, rRoll.tags);
		nAddMod = nAddMod + nAddModi;
		-- END
		if (nEffectCount > 0) then
			bEffects = true;
		end
		-- KEL (DIS)ADV; also add total amount of all dis/adv effects which are then compared with kel(dis)advantage numbers
		local aADVATK = EffectManager35E.getEffectsByType(rSource, "ADVATK", aAttackFilter, rTarget, false, rRoll.tags);
		local aDISATK = EffectManager35E.getEffectsByType(rSource, "DISATK", aAttackFilter, rTarget, false, rRoll.tags);
		local aGRANTADVATK = EffectManager35E.getEffectsByType(rTarget, "GRANTADVATK", aAttackFilter, rSource, false, rRoll.tags);
		local aGRANTDISATK = EffectManager35E.getEffectsByType(rTarget, "GRANTDISATK", aAttackFilter, rSource, false, rRoll.tags);
		local _, nADVATK = EffectManager35E.hasEffect(rSource, "ADVATK", rTarget, false, false, rRoll.tags);
		local _, nDISATK = EffectManager35E.hasEffect(rSource, "DISATK", rTarget, false, false, rRoll.tags);
		local _, nGRANTADVATK = EffectManager35E.hasEffect(rTarget, "GRANTADVATK", rSource, false, false, rRoll.tags);
		local _, nGRANTDISATK = EffectManager35E.hasEffect(rTarget, "GRANTDISATK", rSource, false, false, rRoll.tags);
		
		rRoll.adv = #aADVATK + #aGRANTADVATK + nADVATK + nGRANTADVATK - (#aDISATK + #aGRANTDISATK + nDISATK + nGRANTDISATK);
		-- END
		if rRoll.sType == "grapple" then
			local aPFDice, nPFMod, nPFCount = EffectManager35E.getEffectsBonus(rSource, {"CMB"}, false, aAttackFilter, rTarget, false, rRoll.tags);
			if nPFCount > 0 then
				bEffects = true;
				for k, v in ipairs(aPFDice) do
					table.insert(aAddDice, v);
				end
				nAddMod = nAddMod + nPFMod;
			end
		end
		
		if EffectManager35E.hasEffect(rSource, "Blinded", nil, false, false, rRoll.tags) then
			bEffects = true;
			table.insert(aAddDesc, "[BLINDED]");
		end
		if not DataCommon.isPFRPG() then
			if EffectManager35E.hasEffect(rSource, "Incorporeal", nil, false, false, rRoll.tags) and sAttackType == "M" and not string.match(string.lower(rRoll.sDesc), "incorporeal touch") then
				bEffects = true;
				table.insert(aAddDesc, "[INCORPOREAL]");
			end
		end
		if EffectManager35E.hasEffectCondition(rSource, "Dazzled", rRoll.tags) then
			bEffects = true;
			nAddMod = nAddMod - 1;
		end
		if EffectManager35E.hasEffectCondition(rSource, "Slowed", rRoll.tags) then
			bEffects = true;
			nAddMod = nAddMod - 1;
		end
		if EffectManager35E.hasEffectCondition(rSource, "Entangled", rRoll.tags) then
			bEffects = true;
			nAddMod = nAddMod - 2;
		end
		if rRoll.sType == "attack" and 
				(EffectManager35E.hasEffectCondition(rSource, "Pinned", rRoll.tags) or
				EffectManager35E.hasEffectCondition(rSource, "Grappled", rRoll.tags)) then
			bEffects = true;
			nAddMod = nAddMod - 2;
		end
		if EffectManager35E.hasEffectCondition(rSource, "Frightened", rRoll.tags) or 
				EffectManager35E.hasEffectCondition(rSource, "Panicked", rRoll.tags) or
				EffectManager35E.hasEffectCondition(rSource, "Shaken", rRoll.tags) then
			bEffects = true;
			nAddMod = nAddMod - 2;
		end
		if EffectManager35E.hasEffectCondition(rSource, "Sickened", rRoll.tags) then
			bEffects = true;
			nAddMod = nAddMod - 2;
		end

		-- Get other effect modifiers
		if EffectManager35E.hasEffectCondition(rSource, "Squeezing", rRoll.tags) then
			bEffects = true;
			nAddMod = nAddMod - 4;
		end
		if EffectManager35E.hasEffectCondition(rSource, "Prone", rRoll.tags) then
			if sAttackType == "M" then
				bEffects = true;
				nAddMod = nAddMod - 4;
			end
		end
		
		-- Get ability modifiers
		local nBonusStat, nBonusEffects = ActorManager35E.getAbilityEffectsBonus(rSource, sActionStat, rRoll.tags);
		if nBonusEffects > 0 then
			bEffects = true;
			nAddMod = nAddMod + nBonusStat;
		end
		
		-- Get negative levels
		local nNegLevelMod, nNegLevelCount = EffectManager35E.getEffectsBonus(rSource, {"NLVL"}, true, nil, nil, false, rRoll.tags);
		if nNegLevelCount > 0 then
			bEffects = true;
			nAddMod = nAddMod - nNegLevelMod;
		end

		-- If effects, then add them
		if bEffects then
			local sEffects = "";
			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
			if sMod ~= "" then
				sEffects = "[" .. Interface.getString("effects_tag") .. " " .. sMod .. "]";
			else
				sEffects = "[" .. Interface.getString("effects_tag") .. "]";
			end
			table.insert(aAddDesc, sEffects);
		end
	end
	
	if bSuperiorCover then
		nAddMod = nAddMod - 8;
	elseif bCover then
		nAddMod = nAddMod - 4;
	elseif bPartialCover then
		nAddMod = nAddMod - 2;
	end
	
	if #aAddDesc > 0 then
		rRoll.sDesc = rRoll.sDesc .. " " .. table.concat(aAddDesc, " ");
	end
	for _,vDie in ipairs(aAddDice) do
		if vDie:sub(1,1) == "-" then
			table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
		else
			table.insert(rRoll.aDice, "p" .. vDie:sub(2));
		end
	end
	rRoll.nMod = rRoll.nMod + nAddMod;
end

function onAttack(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);

	local bIsSourcePC = ActorManager.isPC(rSource);
	local bAllowCC = OptionsManager.isOption("HRCC", "on") or (not bIsSourcePC and OptionsManager.isOption("HRCC", "npc"));
	
	if rRoll.sDesc:match("%[CMB") then
		rRoll.sType = "grapple";
	end
	
	-- KEL We need the attack filter here 
	-- DETERMINE ATTACK TYPE AND DEFENSE
	local AttackType = "M";
	if rRoll.sType == "attack" then
		AttackType = string.match(rRoll.sDesc, "%[ATTACK.*%((%w+)%)%]");
	end
	local Opportunity = string.match(rRoll.sDesc, "%[OPPORTUNITY%]");
	-- BUILD ATTACK FILTER 
	local AttackFilter = {};
	if AttackType == "M" then
		table.insert(AttackFilter, "melee");
	elseif AttackType == "R" then
		table.insert(AttackFilter, "ranged");
	end
	if Opportunity then
		table.insert(AttackFilter, "opportunity");
	end
	-- END
	local rAction = {};
	rAction.nTotal = ActionsManager.total(rRoll);
	rAction.aMessages = {};
	
	-- If we have a target, then calculate the defense we need to exceed
	-- KEL Add nAdditionalDefenseForCC and allow negative AC stuff for CC etc
	local nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance, nAdditionalDefenseForCC;
	if rRoll.sType == "critconfirm" then
		local sDefenseVal = rRoll.sDesc:match(" %[AC ([%-%+]?%d+)%]");
		if sDefenseVal then
			nDefenseVal = tonumber(sDefenseVal);
		end
		nMissChance = tonumber(rRoll.sDesc:match("%[MISS CHANCE (%d+)%%%]")) or 0;
		rMessage.text = rMessage.text:gsub(" %[AC ([%-%+]?%d+)%]", "");
		rMessage.text = rMessage.text:gsub(" %[MISS CHANCE %d+%%%]", "");
	-- END
	else
		-- KEL blind fight, skipping checking effects for now (for performance and to avoid problems with On Skip etc.)
		nDefenseVal, nAtkEffectsBonus, nDefEffectsBonus, nMissChance, nAdditionalDefenseForCC = ActorManager35E.getDefenseValue(rSource, rTarget, rRoll);
		-- KEL CONC on Attacker
		local aVConcealEffect, aVConcealCount = EffectManager35E.getEffectsBonusByType(rSource, "TVCONC", true, AttackFilter, rTarget, false, rRoll.tags);
		
		if aVConcealCount > 0 then
			rMessage.text = rMessage.text .. " [VCONC]";
			for _,v in  pairs(aVConcealEffect) do
				nMissChance = math.max(v.mod,nMissChance);
			end
		end
		-- END
		if nAtkEffectsBonus ~= 0 then
			rAction.nTotal = rAction.nTotal + nAtkEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]";
			table.insert(rAction.aMessages, string.format(sFormat, nAtkEffectsBonus));
		end
		if nDefEffectsBonus ~= 0 then
			nDefenseVal = nDefenseVal + nDefEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_def_tag") .. " %+d]";
			table.insert(rAction.aMessages, string.format(sFormat, nDefEffectsBonus));
		end
	end
	
	-- KEL Compatibility with mirrorimage
	-- Get the misfire threshold
	if MirrorImageHandler then
		local sMisfireRange = string.match(rRoll.sDesc, "%[MISFIRE (%d+)%]");
		if sMisfireRange then
			rAction.nMisfire = tonumber(sMisfireRange) or 0;
		end
	end
	-- END
	
	-- Get the crit threshold
	rAction.nCrit = 20;	
	local sAltCritRange = string.match(rRoll.sDesc, "%[CRIT (%d+)%]");
	if sAltCritRange then
		rAction.nCrit = tonumber(sAltCritRange) or 20;
		if (rAction.nCrit <= 1) or (rAction.nCrit > 20) then
			rAction.nCrit = 20;
		end
	end
	
	rAction.nFirstDie = 0;
	if #(rRoll.aDice) > 0 then
		rAction.nFirstDie = rRoll.aDice[1].result or 0;
	end
	rAction.bCritThreat = false;
	if rAction.nFirstDie >= 20 then
		rAction.bSpecial = true;
		if rRoll.sType == "critconfirm" then
			rAction.sResult = "crit";
			table.insert(rAction.aMessages, "[CRITICAL HIT]");
		elseif rRoll.sType == "attack" then
			if bAllowCC then
				rAction.sResult = "hit";
				rAction.bCritThreat = true;
				table.insert(rAction.aMessages, "[AUTOMATIC HIT]");
			else
				rAction.sResult = "crit";
				table.insert(rAction.aMessages, "[CRITICAL HIT]");
			end
		else
			rAction.sResult = "hit";
			table.insert(rAction.aMessages, "[AUTOMATIC HIT]");
		end
	elseif rAction.nFirstDie == 1 then
		if rRoll.sType == "critconfirm" then
			table.insert(rAction.aMessages, "[CRIT NOT CONFIRMED]");
			rAction.sResult = "miss";
		else
			-- KEL compatibility with mirrorimage (I should not need the check for MirrorImageHandler because nMisfire always nil without Darrenan's extension, but I am paranoid :D)
			if MirrorImageHandler and rAction.nMisfire and rRoll.sType == "attack" then
				table.insert(rAction.aMessages, "[MISFIRE]");
				rAction.sResult = "miss";
			else
				table.insert(rAction.aMessages, "[AUTOMATIC MISS]");
				rAction.sResult = "fumble";
			end
			-- END
		end
	-- KEL comp with mirrorimage
	elseif MirrorImageHandler and rAction.nMisfire and rAction.nFirstDie <= rAction.nMisfire and rRoll.sType == "attack" then
		table.insert(rAction.aMessages, "[MISFIRE]");
		rAction.sResult = "miss";
	-- END
	elseif nDefenseVal then
		if rAction.nTotal >= nDefenseVal then
			if rRoll.sType == "critconfirm" then
				rAction.sResult = "crit";
				table.insert(rAction.aMessages, "[CRITICAL HIT]");
			elseif rRoll.sType == "attack" and rAction.nFirstDie >= rAction.nCrit then
				if bAllowCC then
					rAction.sResult = "hit";
					rAction.bCritThreat = true;
					table.insert(rAction.aMessages, "[CRITICAL THREAT]");
				else
					rAction.sResult = "crit";
					table.insert(rAction.aMessages, "[CRITICAL HIT]");
				end
			else
				rAction.sResult = "hit";
				table.insert(rAction.aMessages, "[HIT]");
			end
		else
			rAction.sResult = "miss";
			if rRoll.sType == "critconfirm" then
				table.insert(rAction.aMessages, "[CRIT NOT CONFIRMED]");
			else
				table.insert(rAction.aMessages, "[MISS]");
			end
		end
	elseif rRoll.sType == "critconfirm" then
		rAction.sResult = "crit";
		table.insert(rAction.aMessages, "[CHECK FOR CRITICAL]");
	elseif rRoll.sType == "attack" and rAction.nFirstDie >= rAction.nCrit then
		if bAllowCC then
			rAction.sResult = "hit";
			rAction.bCritThreat = true;
		else
			rAction.sResult = "crit";
		end
		table.insert(rAction.aMessages, "[CHECK FOR CRITICAL]");
	end
	
	if ((rRoll.sType == "critconfirm") or not rAction.bCritThreat) and (nMissChance > 0) then
		table.insert(rAction.aMessages, "[MISS CHANCE " .. nMissChance .. "%]");
	end
	
	--	bmos adding hit margin tracking
	--	for compatibility with ammunition tracker, add this here in your onAttack function
	if AmmunitionManager then
		local nHitMargin = AmmunitionManager.calculateMargin(nDefenseVal, rAction.nTotal)
		if nHitMargin then table.insert(rAction.aMessages, "[BY " .. nHitMargin .. "+]") end
	end
	--	end bmos adding hit margin tracking

	Comm.deliverChatMessage(rMessage);

	if rAction.sResult == "crit" then
		setCritState(rSource, rTarget);
	end
	
	local bRollMissChance = false;
	if rRoll.sType == "critconfirm" then
		bRollMissChance = true;
	else
		if rAction.bCritThreat then
			local rCritConfirmRoll = { sType = "critconfirm", aDice = {"d20"}, bTower = rRoll.bTower, bSecret = rRoll.bSecret };
			
			local nCCMod = EffectManager35E.getEffectsBonus(rSource, {"CC"}, true, nil, rTarget, false, rRoll.tags);
			if nCCMod ~= 0 then
				rCritConfirmRoll.sDesc = string.format("%s [CONFIRM %+d]", rRoll.sDesc, nCCMod);
			else
				rCritConfirmRoll.sDesc = rRoll.sDesc .. " [CONFIRM]";
			end
			if nMissChance > 0 then
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " [MISS CHANCE " .. nMissChance .. "%]";
			end
			rCritConfirmRoll.nMod = rRoll.nMod + nCCMod;
			-- KEL ACCC stuff
			local nNewDefenseVal = 0;
			if nAdditionalDefenseForCC ~= 0 and nDefenseVal then
				nNewDefenseVal = nAdditionalDefenseForCC;
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " [CC DEF EFFECTS " .. nAdditionalDefenseForCC .. "]";
			end
			-- END
			if nDefenseVal then
				--KEL
				nNewDefenseVal = nNewDefenseVal + nDefenseVal;
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " [AC " .. nNewDefenseVal .. "]";
				--END
			end
			
			if nAtkEffectsBonus and nAtkEffectsBonus ~= 0 then
				local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]";
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " " .. string.format(sFormat, nAtkEffectsBonus);
			end
			
			ActionsManager.roll(rSource, { rTarget }, rCritConfirmRoll, true);
		elseif (rAction.sResult ~= "miss") and (rAction.sResult ~= "fumble") then
			bRollMissChance = true;
		-- KEL compatibility test with mirror image handler
		elseif MirrorImageHandler and (rAction.sResult == "miss") and (nDefenseVal - rAction.nTotal <= 5) then
			bRollMissChance = true;
			nMissChance = 0;
		end
	end
	-- KEL Adding informations about Full attack to avoid loosing target on misschance, similar for action type
	local FullAttack = "";
	local ActionStuffForOverlay = "";
	if string.match(rRoll.sDesc, "%[FULL%]") then
		FullAttack = "true";
	else
		FullAttack = "false";
	end
	local bAction = string.match(rRoll.sDesc, "%[ACTION%]");
	if bAction then
		ActionStuffForOverlay = "true";
	else
		ActionStuffForOverlay = "false";
	end
	-- END
	if bRollMissChance and (nMissChance > 0) then
		local aMissChanceDice = { "d100" };
		local sMissChanceText;
		sMissChanceText = string.gsub(rMessage.text, " %[CRIT %d+%]", "");
		sMissChanceText = string.gsub(sMissChanceText, " %[CONFIRM%]", "");
		local rMissChanceRoll = { sType = "misschance", sDesc = sMissChanceText .. " [MISS CHANCE " .. nMissChance .. "%]", aDice = aMissChanceDice, nMod = 0, fullattack = FullAttack, actionStuffForOverlay = ActionStuffForOverlay };
		-- KEL Blind fight
		if ActorManager35E.hasSpecialAbility(rSource, "Blind-Fight", true, false, false) and AttackType == "M" then
			rMissChanceRoll.adv = ( rMissChanceRoll.adv or 0 ) + 1;
			rMissChanceRoll.sDesc = rMissChanceRoll.sDesc .. " [BLIND-FIGHT]";
		end
		-- END
		ActionsManager.roll(rSource, rTarget, rMissChanceRoll);
	-- KEL compatibility test with mirror image handler
	elseif MirrorImageHandler and bRollMissChance then
		local nMirrorImageCount = MirrorImageHandler.getMirrorImageCount(rTarget);
		if nMirrorImageCount > 0 then
			if rAction.sResult == "hit" or rAction.sResult == "crit" then
				local rMirrorImageRoll = MirrorImageHandler.getMirrorImageRoll(nMirrorImageCount, rRoll.sDesc);
				ActionsManager.roll(rSource, rTarget, rMirrorImageRoll);
			elseif rRoll.sType ~= "critconfirm" then
				MirrorImageHandler.removeImage(rSource, rTarget);
				table.insert(rAction.aMessages, "[MIRROR IMAGE REMOVED BY NEAR MISS]");
			end
		end
	end
	
	-- KEL Save overlay
	if (rAction.sResult == "miss" or rAction.sResult == "fumble") and bAction and rRoll.sType ~= "critconfirm" then
		TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -3);
	elseif (rAction.sResult == "hit" or rAction.sResult == "crit") and bAction and rRoll.sType ~= "critconfirm" then
		TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -1);
	end
	-- END
	
	--	bmos adding automatic ammunition ticker and chat messaging
	--	for compatibility with ammunition tracker, add this here in your onAttack function
	if AmmunitionManager and bIsSourcePC then AmmunitionManager.ammoTracker(rSource, rRoll.sDesc, rAction.sResult) end
	--	end bmos adding automatic ammunition ticker and chat messaging

	if rTarget then
		notifyApplyAttack(rSource, rTarget, rRoll.bTower, rRoll.sType, rRoll.sDesc, rAction.nTotal, table.concat(rAction.aMessages, " "));
		
		-- REMOVE TARGET ON MISS OPTION
		if (rAction.sResult == "miss" or rAction.sResult == "fumble") and rRoll.sType ~= "critconfirm" and not string.match(rRoll.sDesc, "%[FULL%]") then
			local bRemoveTarget = false;
			if OptionsManager.isOption("RMMT", "on") then
				bRemoveTarget = true;
			elseif rRoll.bRemoveOnMiss then
				bRemoveTarget = true;
			end
			
			if bRemoveTarget then
				TargetingManager.removeTarget(ActorManager.getCTNodeName(rSource), ActorManager.getCTNodeName(rTarget));
			end
		end
	end
	
	-- HANDLE FUMBLE/CRIT HOUSE RULES
	local sOptionHRFC = OptionsManager.getOption("HRFC");
	if rAction.sResult == "fumble" and ((sOptionHRFC == "both") or (sOptionHRFC == "fumble")) then
		notifyApplyHRFC("Fumble");
	end
	if rAction.sResult == "crit" and ((sOptionHRFC == "both") or (sOptionHRFC == "criticalhit")) then
		notifyApplyHRFC("Critical Hit");
	end
end

function onGrapple(rSource, rTarget, rRoll)
	if DataCommon.isPFRPG() then
		onAttack(rSource, rTarget, rRoll);
	else
		local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
		
		if rTarget then
			rMessage.text = rMessage.text .. " [at " .. ActorManager.getDisplayName(rTarget) .. "]";
		end
		
		if not rSource then
			rMessage.sender = nil;
		end
		Comm.deliverChatMessage(rMessage);
	end
end

function onMissChance(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	-- KEL adding variable for automated targeting removal
	local removeVar = false;
	--END
	local nTotal = ActionsManager.total(rRoll);
	local nMissChance = tonumber(string.match(rMessage.text, "%[MISS CHANCE (%d+)%%%]")) or 0;
	-- KEL Mirror image handler variable
	local bHit = false;
	-- END
	if nTotal <= nMissChance then
		rMessage.text = rMessage.text .. " [MISS]";
		removeVar = true;
		if rTarget then
			rMessage.icon = "roll_attack_miss";
			clearCritState(rSource, rTarget);
			-- KEL Adding Save Overlay
			if rRoll.actionStuffForOverlay == "true" then
				TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -3);
			end
			-- END
		else
			rMessage.icon = "roll_attack";
		end
	else
		bHit = true;
		rMessage.text = rMessage.text .. " [HIT]";
		removeVar = false;
		if rTarget then
			rMessage.icon = "roll_attack_hit";
			-- KEL Adding Save Overlay
			if rRoll.actionStuffForOverlay == "true" then
				TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -1);
			end
			-- END
		else
			rMessage.icon = "roll_attack";
		end
	end
	-- KEL Remove TARGET
	if rTarget and rRoll.fullattack == "false" then		
		-- REMOVE TARGET ON MISS OPTION
		if removeVar then
			local bRemoveTarget = false;
			if OptionsManager.isOption("RMMT", "on") then
				bRemoveTarget = true;
			elseif rRoll.bRemoveOnMiss then
				bRemoveTarget = true;
			end
			
			if bRemoveTarget then
				TargetingManager.removeTarget(ActorManager.getCTNodeName(rSource), ActorManager.getCTNodeName(rTarget));
			end
		end
	end
	
	Comm.deliverChatMessage(rMessage);
	
	-- KEL Compatibility to mirror image handler
	if MirrorImageHandler and bHit then
		local nMirrorImageCount = MirrorImageHandler.getMirrorImageCount(rTarget);
		if nMirrorImageCount > 0 then
			local rMirrorImageRoll = MirrorImageHandler.getMirrorImageRoll(nMirrorImageCount, rRoll.sDesc);
			ActionsManager.roll(rSource, rTarget, rMirrorImageRoll);
		end
	end
	-- END
end

function applyAttack(rSource, rTarget, bSecret, sAttackType, sDesc, nTotal, sResults)
	local msgShort = {font = "msgfont"};
	local msgLong = {font = "msgfont"};
	
	if sAttackType == "grapple" then
		msgShort.text = "Combat Man. ->";
		msgLong.text = "Combat Man. [" .. nTotal .. "] ->";
	else
		msgShort.text = "Attack ->";
		msgLong.text = "Attack [" .. nTotal .. "] ->";
	end
	if rTarget then
		local sName = ActorManager.getDisplayName(rTarget);
		msgShort.text = msgShort.text .. " [at " .. sName .. "]";
		msgLong.text = msgLong.text .. " [at " .. sName .. "]";
	end
	if sResults ~= "" then
		msgLong.text = msgLong.text .. " " .. sResults;
	end
	
	msgShort.icon = "roll_attack";
	if string.match(sResults, "%[CRITICAL HIT%]") then
		msgLong.icon = "roll_attack_crit";
	elseif string.match(sResults, "HIT%]") then
		msgLong.icon = "roll_attack_hit";
	elseif string.match(sResults, "MISS%]") then
		msgLong.icon = "roll_attack_miss";
	elseif string.match(sResults, "CRITICAL THREAT%]") then
		msgLong.icon = "roll_attack_hit";
	else
		msgLong.icon = "roll_attack";
	end
		
	ActionsManager.outputResult(bSecret, rSource, rTarget, msgLong, msgShort);
end

aCritState = {};

function setCritState(rSource, rTarget)
	local sSourceCT = ActorManager.getCreatureNodeName(rSource);
	if sSourceCT == "" then
		return;
	end
	local sTargetCT = "";
	if rTarget then
		sTargetCT = ActorManager.getCTNodeName(rTarget);
	end
	
	if not aCritState[sSourceCT] then
		aCritState[sSourceCT] = {};
	end
	table.insert(aCritState[sSourceCT], sTargetCT);
end

function clearCritState(rSource, rTarget)
	if rTarget then
		isCrit(rSource, rTarget);
		return;
	end
	
	local sSourceCT = ActorManager.getCreatureNodeName(rSource);
	if sSourceCT ~= "" then
		aCritState[sSourceCT] = nil;
	end
end

function isCrit(rSource, rTarget)
	local sSourceCT = ActorManager.getCreatureNodeName(rSource);
	if sSourceCT == "" then
		return;
	end
	local sTargetCT = "";
	if rTarget then
		sTargetCT = ActorManager.getCTNodeName(rTarget);
	end

	if not aCritState[sSourceCT] then
		return false;
	end
	
	for k,v in ipairs(aCritState[sSourceCT]) do
		if v == sTargetCT then
			table.remove(aCritState[sSourceCT], k);
			return true;
		end
	end
	
	return false;
end
