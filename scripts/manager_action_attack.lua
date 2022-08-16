--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--
-- luacheck: globals excessAoOMessage onAttack MirrorImageHandler onAttackResolve onMissChance

function excessAoOMessage(nodeCT)
	local nAOO = DB.getValue(nodeCT, "aoo", 0);
	local nMaxAOO = DB.getValue(nodeCT, "aoomax", 0);
	local messagedata = { text = '', sender = ActorManager.resolveActor(nodeCT).sName, font = "emotefont" }
	if nAOO == nMaxAOO then
		messagedata.text = "Maximum Attacks of Opportunity Reached"
		Comm.deliverChatMessage(messagedata)
	elseif nAOO > nMaxAOO then
		messagedata.text = "Maximum Attacks of Opportunity Exceeded"
		Comm.deliverChatMessage(messagedata)
	end
end

-- KEL AoO
OOB_MSGTYPE_APPLYAOO = "applyaoo";
function handleApplyAoO(msgOOB)
	local nodeCT = ActorManager.getCTNode(msgOOB.sSourceNode);

	local nAOO = DB.getValue(nodeCT, "aoo", 0) + 1;
	DB.setValue(nodeCT, "aoo", "number", nAOO);

	excessAoOMessage(nodeCT)
end
-- END

-- KEL add tag argument
local getRoll_old;
local function getRoll(rActor, rAction, tag, ...)
	local rRoll = getRoll_old(rActor, rAction, ...);

	-- Add other modifiers
	-- KEL compatibility with KEEN and iftag stuff; EDIT: Moving KEEN stuff such that it is targetable. Hence, saving crit value
	rRoll.tags = tag;
	rRoll.crit = rAction.crit;
	-- END

	-- KEL Save overlay only for spell actions
	if rAction.spell then
		rRoll.sDesc = rRoll.sDesc .. " [ACTION]";
	end
	-- END

	return rRoll;
end

local modAttack_old;
local function modAttack(rSource, rTarget, rRoll, ...)
	if rSource and rRoll then rSource.tags = rRoll.tags; end
	modAttack_old(rSource, rTarget, rRoll, ...)

	local aAddDesc = {};
	local aAddDice = {};
	local nAddMod = 0;

	-- Check for opportunity attack
	local bOpportunity = rRoll.sDesc:match('%s*%[OPPORTUNITY%]') ~= nil;

	-- Check defense modifiers
	local bFlatFooted = rRoll.sDesc:match('%s*%[FF%]') ~= nil;

	-- KEL add CA button
	local bCAKel = ModifierManager.getKey("ATT_CA");
	--END

	if bOpportunity then
		-- KEL AoO
		if Session.IsHost then
			local msgOOB = {};
			msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
			msgOOB.type = OOB_MSGTYPE_APPLYAOO;
			handleApplyAoO(msgOOB)
		else
			local msgOOB = {};
			msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
			msgOOB.type = OOB_MSGTYPE_APPLYAOO;
			Comm.deliverOOBMessage(msgOOB, "");
		end
		--END
	end
	-- KEL adding uncanny dodge
	if bFlatFooted and ActorManager35E.hasSpecialAbility(rTarget, "Uncanny Dodge", false, false, true) then
		rRoll.sDesc = rRoll.sDesc:gsub('%s*%[FF%]', '');
	end

	if rSource then
		-- Determine attack type
		local sAttackType = nil;
		if rRoll.sType == "attack" then
			sAttackType = rRoll.sDesc:match("%[ATTACK.*%((%w+)%)%]");
			if not sAttackType then
				sAttackType = "M";
			end
		elseif rRoll.sType == "grapple" then
			sAttackType = "M";
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

		-- Get condition modifiers; KEL moved it here for nodex automation later (not yet done) such that
		-- following effects can profit from it; similar for bEffects; adding ethereal
		local bEffects = false;

		local function addCA() -- otherwise redundant code to add [CA] description and increase modifier
			bEffects = true;
			nAddMod = nAddMod + 2;
			if not ActorManager35E.hasSpecialAbility(rTarget, "Uncanny Dodge", false, false, true) then
				table.insert(aAddDesc, "[CA]");
			else
				rRoll.sDesc:gsub('%s*%[CA%]', '');
			end
		end

		if EffectManager35E.hasEffect(rSource, "Ethereal", nil, false, false) then
			addCA()
		elseif EffectManager35E.hasEffect(rSource, "Invisible", nil, false, false) then
			-- KEL blind fight, skipping checking effects for now (for performance and to avoid problems with On Skip etc.)
			if sAttackType == "R" or not ActorManager35E.hasSpecialAbility(rTarget, "Blind-Fight", true) then
				addCA()
			end
			-- END
		end
		-- KEL add CA button
		if (bCAKel or EffectManager35E.hasEffect(rSource, "CA", nil, false, false)) and not rRoll.sDesc:match('%[CA%]') then
			table.insert(aAddDesc, "[CA]");
		end
		-- END
		-- Get attack effect modifiers
		-- KEL New KEEN code for allowing several new configurations
		local rActionCrit = tonumber(rRoll.crit) or 20;
		local aKEEN = EffectManager35E.getEffectsByType(rSource, "KEEN", aAttackFilter, rTarget, false);
		if (#aKEEN > 0) or EffectManager35E.hasEffect(rSource, "KEEN", rTarget, false, false) then
			rActionCrit = 20 - ((20 - rActionCrit + 1) * 2) + 1;
			bEffects = true;
		end
		if rActionCrit < 20 and not rRoll.sDesc:match('%[CRIT %d+%]')then
			table.insert(aAddDesc, "[CRIT " .. rActionCrit .. "]");
		end
		-- END
		-- KEL add tags, and relabel nAddMod to nAddModi to avoid overwriting the previous nAddMod
		local nEffectCount, nAddModi;
		aAddDice, nAddModi, nEffectCount = EffectManager35E.getEffectsBonus(rSource, {"ATK"}, false, aAttackFilter, rTarget, false);
		nAddMod = nAddMod + nAddModi;
		-- END
		if (nEffectCount > 0) then
			bEffects = true;
		end

		-- If effects, then add them
		if bEffects then
			local sEffects = "[" .. Interface.getString("effects_tag") .. "]";
			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
			if sMod ~= "" then
				sEffects = "[" .. Interface.getString("effects_tag") .. " " .. sMod .. "]";
			end
			table.insert(aAddDesc, sEffects);
		end
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
	if rSource and rRoll then rSource.tags = rRoll.tags; end
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
		local aVConcealEffect, aVConcealCount = EffectManager35E.getEffectsBonusByType(rSource, "TVCONC", true, AttackFilter, rTarget, false);

		if aVConcealCount > 0 then
			rMessage.text = rMessage.text .. " [VCONC]";
			for _,v in  pairs(aVConcealEffect) do
				rRoll.nMissChance = math.max(v.mod,rRoll.nMissChance);
			end
		end
		-- END
		if rRoll.nAtkEffectsBonus ~= 0 then
			rRoll.nTotal = rRoll.nTotal + rRoll.nAtkEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]";
			table.insert(rRoll.aMessages, string.format(sFormat, rRoll.nAtkEffectsBonus));
		end
		if rRoll.nDefEffectsBonus ~= 0 then
			rRoll.nDefenseVal = rRoll.nDefenseVal + rRoll.nDefEffectsBonus;
			local sFormat = "[" .. Interface.getString("effects_def_tag") .. " %+d]";
			table.insert(rRoll.aMessages, string.format(sFormat, rRoll.nDefEffectsBonus));
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
				table.insert(rRoll.aMessages, "[AUTOMATIC HIT]");
			else
				rRoll.sResult = "crit";
				table.insert(rRoll.aMessages, "[CRITICAL HIT]");
			end
		else
			rRoll.sResult = "hit";
			table.insert(rRoll.aMessages, "[AUTOMATIC HIT]");
		end
	elseif rRoll.nFirstDie == 1 then
		if rRoll.sType == "critconfirm" then
			table.insert(rRoll.aMessages, "[CRIT NOT CONFIRMED]");
			rRoll.sResult = "miss";
		else
			-- KEL compatibility with mirrorimage (I should not need the check for MirrorImageHandler
			-- because nMisfire always nil without Darrenan's extension, but I am paranoid :D)
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

function onAttackResolve(rSource, rTarget, rRoll, rMessage)
	if rSource and rRoll then rSource.tags = rRoll.tags; end
	Comm.deliverChatMessage(rMessage);

	if rRoll.sResult == "crit" then
		ActionAttack.setCritState(rSource, rTarget);
	end

	local bRollMissChance = false;
	if rRoll.sType == "critconfirm" then
		bRollMissChance = true;
	else
		if rRoll.bCritThreat then
			local rCritConfirmRoll = { sType = "critconfirm", aDice = {"d20"}, bTower = rRoll.bTower, bSecret = rRoll.bSecret };

			local nCCMod = EffectManager35E.getEffectsBonus(rSource, {"CC"}, true, nil, rTarget, false);
			if nCCMod ~= 0 then
				rCritConfirmRoll.sDesc = string.format("%s [CONFIRM %+d]", rRoll.sDesc, nCCMod);
			else
				rCritConfirmRoll.sDesc = rRoll.sDesc .. " [CONFIRM]";
			end
			if rRoll.nMissChance > 0 then
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " [MISS CHANCE " .. rRoll.nMissChance .. "%]";
			end
			rCritConfirmRoll.nMod = rRoll.nMod + nCCMod;
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
				local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]";
				rCritConfirmRoll.sDesc = rCritConfirmRoll.sDesc .. " " .. string.format(sFormat, rRoll.nAtkEffectsBonus);
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
	local FullAttack = "false";
	local ActionStuffForOverlay = "false";
	if string.match(rRoll.sDesc, "%[FULL%]") then
		FullAttack = "true";
	end
	local bAction = string.match(rRoll.sDesc, "%[ACTION%]");
	if bAction then
		ActionStuffForOverlay = "true";
	end
	-- END
	if bRollMissChance and (rRoll.nMissChance > 0) then
		local aMissChanceDice = { "d100" };
		local sMissChanceText = rMessage.text:gsub(" %[CRIT %d+%]", ""):gsub(" %[CONFIRM%]", "");
		-- KEL overlay stuff
		local rMissChanceRoll = {
				sType = "misschance",
				sDesc = sMissChanceText .. " [MISS CHANCE " .. rRoll.nMissChance .. "%]",
				aDice = aMissChanceDice,
				nMod = 0,
				fullattack = FullAttack,
				actionStuffForOverlay = ActionStuffForOverlay
			};
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
		ActionAttack.notifyApplyAttack(rSource, rTarget, rRoll.bTower, rRoll.sType, rRoll.sDesc, rRoll.nTotal, table.concat(rRoll.aMessages, " "));

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
-- END

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYAOO, handleApplyAoO);

	getRoll_old = ActionAttack.getRoll
	ActionAttack.getRoll = getRoll

	ActionsManager.registerModHandler("attack", modAttack);
	ActionsManager.registerModHandler("grapple", modAttack);
	modAttack_old = ActionAttack.modAttack
	ActionAttack.modAttack = modAttack

	ActionAttack.onAttackResolve = onAttackResolve


	ActionsManager.registerResultHandler("attack", onAttack);
	ActionsManager.registerResultHandler("critconfirm", onAttack);

	ActionsManager.registerResultHandler("misschance", onMissChance);
	ActionAttack.onMissChance = onMissChance
end