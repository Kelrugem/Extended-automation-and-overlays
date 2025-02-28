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
	
	local rRoll = UtilityManager.decodeRollFromOOB(msgOOB);
	ActionAttack.applyAttack(rSource, rTarget, rRoll);
end

function notifyApplyAttack(rSource, rTarget, rRoll)
	if not rTarget then
		return;
	end

	rRoll.bSecret = rRoll.bTower;
	rRoll.sResults = table.concat(rRoll.aMessages, " ");

	local msgOOB = UtilityManager.encodeRollToOOB(rRoll);
	msgOOB.type = ActionAttack.OOB_MSGTYPE_APPLYATK;
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
	local rRoll = ActionAttack.getRoll(nil, rAction);
	
	if DB.getValue("partysheet.hiderollresults", 0) == 1 then
		rRoll.bSecret = true;
		rRoll.bTower = true;
	end
	
	ActionsManager.actionDirect(nil, "attack", { rRoll }, { { rActor } });
end

function performRoll(draginfo, rActor, rAction)
	local rRoll = ActionAttack.getRoll(rActor, rAction);
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end
-- KEL add tag argument
function getRoll(rActor, rAction)
	local rRoll = {};
	if rAction.cm then
		rRoll.sType = "grapple";
	else
		rRoll.sType = "attack";
	end
	rRoll.aDice = DiceRollManager.getActorDice({ "d20" }, rActor);
	rRoll.nMod = rAction.modifier or 0;
	
	if rAction.cm then
		rRoll.sDesc = "[CMB";
		if rAction.order and rAction.order > 1 then
			rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
		end
		rRoll.sDesc = rRoll.sDesc .. "] " .. StringManager.capitalizeAll(rAction.label);
	else
		rRoll.sDesc = "[ATTACK";
		if rAction.order and rAction.order > 1 then
			rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
		end
		if rAction.range then
			rRoll.sDesc = rRoll.sDesc .. " (" .. rAction.range .. ")";
		end
		rRoll.sDesc = rRoll.sDesc .. "] " .. StringManager.capitalizeAll(rAction.label);
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
	if rAction.tags and next(rAction.tags) then
		rRoll.tags = table.concat(rAction.tags, ";");
	end
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
	local rRoll = ActionAttack.getGrappleRoll(rActor, rAction);
	
	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function getGrappleRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "grapple";
	rRoll.aDice = DiceRollManager.getActorDice({ "d20" }, rActor);
	rRoll.nMod = rAction.modifier or 0;
	
	if DataCommon.isPFRPG() then
		rRoll.sDesc = "[CMB]";
	else
		rRoll.sDesc = "[GRAPPLE]";
	end
	if rAction.label and rAction.label ~= "" then
		rRoll.sDesc = rRoll.sDesc .. " " .. StringManager.capitalizeAll(rAction.label);
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
	excessAoOMessage(rSourceCTNode)
end
--By Bmos, thanks :)
function excessAoOMessage(nodeCT)
	local nAOO = DB.getValue(nodeCT, "aoo", 0);
	local nMaxAOO = DB.getValue(nodeCT, "aoomax", 0);
	local messagedata = { text = '', sender = ActorManager.resolveActor(nodeCT).sName, font = "emotefont" }
	
	if Session.IsHost and OptionsManager.isOption("REVL", "off") then
		messagedata.secret = true;
	end
	
	if nAOO == nMaxAOO then
		messagedata.text = "Maximum Attacks of Opportunity Reached"
		Comm.deliverChatMessage(messagedata)
	elseif nAOO > nMaxAOO then
		messagedata.text = "Maximum Attacks of Opportunity Exceeded"
		Comm.deliverChatMessage(messagedata)
	end
end
-- END

function modAttack(rSource, rTarget, rRoll)
	ActionAttack.clearCritState(rSource);
	local aAddDesc = {};
	local aAddDice = {};
	local nAddMod = 0;
	
	-- Check for opportunity attack
	local bOpportunity = ModifierManager.getKey("ATT_OPP") or Input.isShiftPressed();

	-- Check defense modifiers
	local bTouch = ModifierManager.getKey("ATT_TCH");
	local bFlatFooted = ModifierManager.getKey("ATT_FF");
	-- KEL add CA button
	local bCAKel = ModifierManager.getKey("ATT_CA");
	--END
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
			excessAoOMessage(rSourceCTNode);
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
		end
		if EffectManager35E.hasEffect(rSource, "CA", nil, false, false, rRoll.tags) then
			bEffects = true;
			table.insert(aAddDesc, "[CA]");
		-- KEL add CA button
		elseif bCAKel then
			table.insert(aAddDesc, "[CA]");
		end
		-- END
		-- Get attack effect modifiers
		-- KEL New KEEN code for allowing several new configurations
		local rActionCrit = tonumber(rRoll.crit) or 20;
		local aKEEN = EffectManager35E.getEffectsByType(rSource, "KEEN", aAttackFilter, rTarget, false, rRoll.tags);
		if (#aKEEN > 0) or EffectManager35E.hasEffect(rSource, "KEEN", rTarget, false, false, rRoll.tags) then
			rActionCrit = rActionCrit * 2 - 21;
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
				for _,v in ipairs(aPFDice) do
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
		-- KEL see https://www.fantasygrounds.com/forums/showthread.php?74770-EffectManager-for-condition-in-3-5E
		if EffectManager.hasCondition(rSource, "Prone") then
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
			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
			table.insert(aAddDesc, EffectManager.buildEffectOutput(sMod));
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
	ActionAttack.decodeAttackRoll(rRoll);
	
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
	rRoll.nTotal = ActionsManager.total(rRoll);
	rRoll.aMessages = {};
	
	-- If we have a target, then calculate the defense we need to exceed
	if rRoll.sType == "critconfirm" then
		local sDefenseVal = rRoll.sDesc:match(" %[AC ([%-%+]?%d+)%]");
		if sDefenseVal then
			rRoll.nDefenseVal = tonumber(sDefenseVal);
		end
		rRoll.nMissChance = tonumber(rRoll.sDesc:match("%[MISS CHANCE (%d+)%%%]")) or 0;
		rMessage.text = rMessage.text:gsub(" %[AC ([%-%+]?%d+)%]", "");
		rMessage.text = rMessage.text:gsub(" %[MISS CHANCE %d+%%%]", "");
		-- Getting rid of possible (dis)adv message parts
		rMessage.text = rMessage.text:gsub(" %[DROPPED %d+%]", "");
		rMessage.text = rMessage.text:gsub(" %[ADV%]", "");
		rMessage.text = rMessage.text:gsub(" %[DISADV%]", "");
	-- END
	else
		-- KEL Add nAdditionalDefenseForCC and allow negative AC stuff for CC etc
		-- KEL blind fight, skipping checking effects for now (for performance and to avoid problems with On Skip etc.)
		rRoll.nDefenseVal, rRoll.nAtkEffectsBonus, rRoll.nDefEffectsBonus, rRoll.nMissChance, rRoll.nAdditionalDefenseForCC = ActorManager35E.getDefenseValue(rSource, rTarget, rRoll);
		-- KEL CONC on Attacker
		local aVConcealEffect, aVConcealCount = EffectManager35E.getEffectsBonusByType(rSource, "TVCONC", true, AttackFilter, rTarget, false, rRoll.tags);
		
		if aVConcealCount > 0 then
			rMessage.text = rMessage.text .. " [VCONC]";
			for _,v in  pairs(aVConcealEffect) do
				rRoll.nMissChance = math.max(v.mod,rRoll.nMissChance);
			end
		end
		-- END
		if rRoll.nAtkEffectsBonus ~= 0 then
			rRoll.nTotal = rRoll.nTotal + rRoll.nAtkEffectsBonus;
			table.insert(rRoll.aMessages, EffectManager.buildEffectOutput(rRoll.nAtkEffectsBonus));
		end
		if rRoll.nDefEffectsBonus ~= 0 then
			rRoll.nDefenseVal = rRoll.nDefenseVal + rRoll.nDefEffectsBonus;
			table.insert(rRoll.aMessages, string.format("[%s %+d]", Interface.getString("effects_def_tag"), rRoll.nDefEffectsBonus));
		end
	end
	
	-- KEL Compatibility with mirrorimage
	-- Get the misfire threshold
	if MirrorImageHandler then
		local sMisfireRange = string.match(rRoll.sDesc, "%[MISFIRE (%d+)%]");
		if sMisfireRange then
			rRoll.nMisfire = tonumber(sMisfireRange) or 0;
		end
	end
	-- END
	
	-- Get the crit threshold
	rRoll.nCrit = 20;	
	local sAltCritRange = string.match(rRoll.sDesc, "%[CRIT (%d+)%]");
	if sAltCritRange then
		rRoll.nCrit = tonumber(sAltCritRange) or 20;
		if (rRoll.nCrit <= 1) or (rRoll.nCrit > 20) then
			rRoll.nCrit = 20;
		end
	end
	
	rRoll.nFirstDie = 0;
	if #(rRoll.aDice) > 0 then
		rRoll.nFirstDie = rRoll.aDice[1].result or 0;
	end
	rRoll.bCritThreat = false;
	if rRoll.nFirstDie >= 20 then
		rRoll.bSpecial = true;
		if rRoll.sType == "critconfirm" then
			rRoll.sResult = "crit";
			table.insert(rRoll.aMessages, "[CRITICAL HIT]");
		elseif rRoll.sType == "attack" then
			if bAllowCC then
				rRoll.sResult = "hit";
				rRoll.bCritThreat = true;
				table.insert(rRoll.aMessages, "[CRITICAL THREAT]");
			else
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			end
		else
			rRoll.sResult = "hit";
			table.insert(rRoll.aMessages, "[HIT]");
		end
	elseif rRoll.nFirstDie == 1 then
		if rRoll.sType == "critconfirm" then
			table.insert(rRoll.aMessages, "[HIT]");
			table.insert(rRoll.aMessages, "[CRIT NOT CONFIRMED]");
			rRoll.sResult = "miss";
		else
			-- KEL compatibility with mirrorimage (I should not need the check for MirrorImageHandler because nMisfire always nil without Darrenan's extension, but I am paranoid :D)
			if MirrorImageHandler and rRoll.nMisfire and rRoll.sType == "attack" then
				table.insert(rRoll.aMessages, "[MISFIRE]");
				rRoll.sResult = "miss";
			else
				table.insert(rRoll.aMessages, "[AUTOMATIC MISS]");
				rRoll.sResult = "fumble";
			end
			-- END
		end
	-- KEL comp with mirrorimage
	elseif MirrorImageHandler and rRoll.nMisfire and rRoll.nFirstDie <= rRoll.nMisfire and rRoll.sType == "attack" then
		table.insert(rRoll.aMessages, "[MISFIRE]");
		rRoll.sResult = "miss";
	-- END
	elseif rRoll.nDefenseVal then
		if rRoll.nTotal >= rRoll.nDefenseVal then
			if rRoll.sType == "critconfirm" then
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			elseif rRoll.sType == "attack" and rRoll.nFirstDie >= rRoll.nCrit then
				if bAllowCC then
					rRoll.sResult = "hit";
					rRoll.bCritThreat = true;
					table.insert(rRoll.aMessages, "[CRITICAL THREAT]");
				else
					rRoll.sResult = "crit";
					table.insert(rRoll.aMessages, "[CRITICAL HIT]");
				end
			else
				rRoll.sResult = "hit";
				table.insert(rRoll.aMessages, "[HIT]");
			end
		else
			rRoll.sResult = "miss";
			if rRoll.sType == "critconfirm" then
				table.insert(rRoll.aMessages, "[HIT]");
				table.insert(rRoll.aMessages, "[CRIT NOT CONFIRMED]");
			else
				table.insert(rRoll.aMessages, "[MISS]");
			end
		end
	elseif rRoll.sType == "critconfirm" then
		rRoll.sResult = "crit";
		table.insert(rRoll.aMessages, "[CHECK FOR CRITICAL]");
	elseif rRoll.sType == "attack" and rRoll.nFirstDie >= rRoll.nCrit then
		if bAllowCC then
			rRoll.sResult = "hit";
			rRoll.bCritThreat = true;
		else
			rRoll.sResult = "crit";
		end
		table.insert(rRoll.aMessages, "[CHECK FOR CRITICAL]");
	end
	
	if ((rRoll.sType == "critconfirm") or not rRoll.bCritThreat) and (rRoll.nMissChance > 0) then
		table.insert(rRoll.aMessages, "[MISS CHANCE " .. rRoll.nMissChance .. "%]");
	end
	
	ActionAttack.onPreAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onAttackResolve(rSource, rTarget, rRoll, rMessage);
	ActionAttack.onPostAttackResolve(rSource, rTarget, rRoll, rMessage);
end

function onPreAttackResolve(rSource, rTarget, rRoll, rMessage)
	-- Do nothing; location to override
end

function onAttackResolve(rSource, rTarget, rRoll, rMessage)
	Comm.deliverChatMessage(rMessage);

	if rRoll.sResult == "crit" then
		ActionAttack.setCritState(rSource, rTarget);
	end
	
	local bRollMissChance = false;
	if rRoll.sType == "critconfirm" then
		bRollMissChance = true;
	else
		if rRoll.bCritThreat then
			local rCritConfirmRoll = {
				sType = "critconfirm",
				aDice = DiceRollManager.getActorDice({ "d20" }, rActor),
				bTower = rRoll.bTower,
				bSecret = rRoll.bSecret,
			};
			
			local tCCDice, nCCMod, nCCEffects = EffectManager35E.getEffectsBonus(rSource, {"CC"}, false, nil, rTarget, false, rRoll.tags);
			if (nCCEffects > 0) then
				local sMod = StringManager.convertDiceToString(tCCDice, nCCMod, true);
				rCritConfirmRoll.sDesc = string.format("%s [CONFIRM %s]", rRoll.sDesc, sMod);
			else
				rCritConfirmRoll.sDesc = rRoll.sDesc .. " [CONFIRM]";
			end
			
			for _,vDie in ipairs(tCCDice) do
				if vDie:sub(1,1) == "-" then
					table.insert(rCritConfirmRoll.aDice, "-p" .. vDie:sub(3));
				else
					table.insert(rCritConfirmRoll.aDice, "p" .. vDie:sub(2));
				end
			end
			rCritConfirmRoll.nMod = rRoll.nMod + nCCMod;
			
			if rRoll.nMissChance > 0 then
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " [MISS CHANCE " .. rRoll.nMissChance .. "%]";
			end
			-- KEL ACCC stuff
			local nNewDefenseVal = 0;
			if rRoll.nAdditionalDefenseForCC ~= 0 and rRoll.nDefenseVal then
				nNewDefenseVal = rRoll.nAdditionalDefenseForCC;
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " [CC DEF EFFECTS " .. rRoll.nAdditionalDefenseForCC .. "]";
			end
			-- END
			if rRoll.nDefenseVal then
				--KEL
				rRoll.nDefenseVal = nNewDefenseVal + rRoll.nDefenseVal;
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " [AC " .. rRoll.nDefenseVal .. "]";
				--END
			end
			
			if (rRoll.nAtkEffectsBonus or 0) ~= 0 then
				rCritConfirmRoll.sDesc = string.format("%s %s", rCritConfirmRoll.sDesc, EffectManager.buildEffectOutput(rRoll.nAtkEffectsBonus));
			end
			
			ActionsManager.roll(rSource, { rTarget }, rCritConfirmRoll, true);
		elseif (rRoll.sResult ~= "miss") and (rRoll.sResult ~= "fumble") then
			bRollMissChance = true;
		-- KEL compatibility test with mirror image handler
		elseif MirrorImageHandler and (rRoll.sResult == "miss") and (rRoll.nDefenseVal - rRoll.nTotal <= 5) then
			bRollMissChance = true;
			rRoll.nMissChance = 0;
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
	if bRollMissChance and (rRoll.nMissChance > 0) then
		local aMissChanceDice = {};
		local sMissChanceText = rMessage.text:gsub(" %[CRIT %d+%]", ""):gsub(" %[CONFIRM%]", "");
		-- KEL overlay stuff
		local rMissChanceRoll = { sType = "misschance", sDesc = sMissChanceText .. " [MISS CHANCE " .. rRoll.nMissChance .. "%]", aDice = DiceRollManager.getActorDice({ "d100" }, rSource), nMod = 0, fullattack = FullAttack, actionStuffForOverlay = ActionStuffForOverlay };
		-- KEL Blind fight
		local AttackType = "M";
		if rRoll.sType == "attack" then
			AttackType = string.match(rRoll.sDesc, "%[ATTACK.*%((%w+)%)%]");
		end
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
			if rRoll.sResult == "hit" or rRoll.sResult == "crit" or rRoll.sType == "critconfirm" then
				local rMirrorImageRoll = MirrorImageHandler.getMirrorImageRoll(nMirrorImageCount, rRoll.sDesc);
				ActionsManager.roll(rSource, rTarget, rMirrorImageRoll);
			elseif rRoll.sType ~= "critconfirm" then
				MirrorImageHandler.removeImage(rSource, rTarget);
				table.insert(rRoll.aMessages, "[MIRROR IMAGE REMOVED BY NEAR MISS]");
			end
		end
	end
	
	-- KEL Save overlay
	if (rRoll.sResult == "miss" or rRoll.sResult == "fumble") and bAction and rRoll.sType ~= "critconfirm" then
		TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -3);
	elseif (rRoll.sResult == "hit" or rRoll.sResult == "crit") and bAction and rRoll.sType ~= "critconfirm" then
		TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -1);
	end
	-- END

	if rTarget then
		ActionAttack.notifyApplyAttack(rSource, rTarget, rRoll);
		
		-- REMOVE TARGET ON MISS OPTION
		if (rRoll.sResult == "miss" or rRoll.sResult == "fumble") and rRoll.sType ~= "critconfirm" and not string.match(rRoll.sDesc, "%[FULL%]") then
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
end

function onPostAttackResolve(rSource, rTarget, rRoll, rMessage)
	-- HANDLE FUMBLE/CRIT HOUSE RULES
	local sOptionHRFC = OptionsManager.getOption("HRFC");
	if rRoll.sResult == "fumble" and ((sOptionHRFC == "both") or (sOptionHRFC == "fumble")) then
		ActionAttack.notifyApplyHRFC("Fumble");
	end
	if rRoll.sResult == "crit" and ((sOptionHRFC == "both") or (sOptionHRFC == "criticalhit")) then
		ActionAttack.notifyApplyHRFC("Critical Hit");
	end
end

function onGrapple(rSource, rTarget, rRoll)
	ActionAttack.decodeAttackRoll(rRoll);

	if DataCommon.isPFRPG() then
		ActionAttack.onAttack(rSource, rTarget, rRoll);
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
			ActionAttack.clearCritState(rSource, rTarget);
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

function decodeAttackRoll(rRoll)
	-- Rebuild detail fields if dragging from chat window
	if not rRoll.nOrder then
		rRoll.nOrder = tonumber(rRoll.sDesc:match("%[ATTACK.-#(%d+)")) or nil;
	end
	if not rRoll.sRange then
		rRoll.sRange = rRoll.sDesc:match("%[ATTACK.-%((%w+)%)%]");
	end
	if not rRoll.sLabel then
		rRoll.sLabel = StringManager.trim(rRoll.sDesc:match("%[ATTACK.-%]([^%[]+)"));
	end
end

function applyAttack(rSource, rTarget, rRoll)
	local msgShort = {font = "msgfont"};
	local msgLong = {font = "msgfont"};
	
	if rRoll.sType == "grapple" then
		msgShort.text = "Combat Man.";
		msgLong.text = "Combat Man.";
	else
		msgShort.text = "Attack";
		msgLong.text = "Attack";
	end
	if rRoll.nOrder then
		msgShort.text = string.format("%s #%d", msgShort.text, rRoll.nOrder);
		msgLong.text = string.format("%s #%d", msgLong.text, rRoll.nOrder);
	end
	if (rRoll.sRange or "") ~= "" then
		msgShort.text = string.format("%s (%s)", msgShort.text, rRoll.sRange);
		msgLong.text = string.format("%s (%s)", msgLong.text, rRoll.sRange);
	end
	if (rRoll.sLabel or "") ~= "" then
		msgShort.text = string.format("%s (%s)", msgShort.text, rRoll.sLabel or "");
		msgLong.text = string.format("%s (%s)", msgLong.text, rRoll.sLabel or "");
	end
	msgLong.text = string.format("%s [%d]", msgLong.text, rRoll.nTotal or 0);

	-- Targeting information
	msgShort.text = string.format("%s ->", msgShort.text);
	msgLong.text = string.format("%s ->", msgLong.text);
	if rTarget then
		local sTargetName = ActorManager.getDisplayName(rTarget);
		msgShort.text = string.format("%s [at %s]", msgShort.text, sTargetName);
		msgLong.text = string.format("%s [at %s]", msgLong.text, sTargetName);
	end

	-- Extra roll information
	msgShort.icon = "roll_attack";
	if (rRoll.sResults or "") ~= "" then
		msgLong.text = string.format("%s %s", msgLong.text, rRoll.sResults);
		if rRoll.sResults:match("%[CRITICAL HIT%]") then
			msgLong.icon = "roll_attack_crit";
		elseif rRoll.sResults:match("HIT%]") then
			msgLong.icon = "roll_attack_hit";
		elseif rRoll.sResults:match("MISS%]") then
			msgLong.icon = "roll_attack_miss";
		-- KEL MirrorImageHandler compatibility
		elseif rRoll.sResults:match("%[MISFIRE%]") then
			msgLong.icon = "roll_attack_miss";
		-- END
		elseif rRoll.sResults:match("CRITICAL THREAT%]") then
			msgLong.icon = "roll_attack_hit";
		else
			msgLong.icon = "roll_attack";
		end
	else
		msgLong.icon = "roll_attack";
	end
		
	ActionsManager.outputResult(rRoll.bSecret, rSource, rTarget, msgLong, msgShort);
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
		ActionAttack.isCrit(rSource, rTarget);
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
