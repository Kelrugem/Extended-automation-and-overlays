-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

OOB_MSGTYPE_APPLYSAVEVS = "applysavevs";

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYSAVEVS, handleApplySave);

	ActionsManager.registerTargetingHandler("cast", onSpellTargeting);
	ActionsManager.registerTargetingHandler("clc", onSpellTargeting);
	ActionsManager.registerTargetingHandler("spellsave", onSpellTargeting);
	ActionsManager.registerTargetingHandler("spdamage", onSpellTargeting);
	local spDmgHandler = GameSystem.actions["spdamage"];
	spDmgHandler.sTargeting = "all";

	ActionsManager.registerModHandler("castsave", modCastSave);
	ActionsManager.registerModHandler("spellsave", modCastSave);
	ActionsManager.registerModHandler("clc", modCLC);
	ActionsManager.registerModHandler("concentration", modConcentration);
	
	ActionsManager.registerResultHandler("cast", onSpellCast);
	ActionsManager.registerResultHandler("castclc", onCastCLC);
	ActionsManager.registerResultHandler("castsave", onCastSave);
	ActionsManager.registerResultHandler("clc", onCLC);
	ActionsManager.registerResultHandler("spellsave", onSpellSave);
	ActionsManager.registerResultHandler("spellfailure", onSpellFailure);
end

function handleApplySave(msgOOB)
	-- GET THE TARGET ACTOR
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	
	local sSaveShort, sSaveDC = string.match(msgOOB.sDesc, "%[(%w+) DC (%d+)%]")
	if sSaveShort then
		local sSave = DataCommon.save_stol[sSaveShort];
		if sSave then
			-- KEL add tags
			ActionSave.performVsRoll(nil, rTarget, sSave, msgOOB.nDC, (tonumber(msgOOB.nSecret) == 1), rSource, (tonumber(msgOOB.nRemoveOnMiss) == 1), msgOOB.sDesc, msgOOB.tags);
			-- END
		end
	end
end
-- KEL Add tags
function notifyApplySave(rSource, rTarget, bSecret, sDesc, nDC, bRemoveOnMiss, tags)
	if not rTarget then
		return;
	end

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYSAVEVS;
	
	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	msgOOB.sDesc = sDesc;
	msgOOB.nDC = nDC;
	-- msgOOB.stype = stype;
	-- KEL
	msgOOB.tags = tags;
	-- END

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);

	msgOOB.nRemoveOnMiss = bRemoveOnMiss and 1 or 0;

	if ActorManager.isPC(rTarget) then
		local nodeTarget = ActorManager.getCreatureNode(rTarget);
		if Session.IsHost then
			local sOwner = DB.getOwner(nodeTarget);
			if (sOwner or "") then
				for _,vUser in ipairs(User.getActiveUsers()) do
					if vUser == sOwner then
						for _,vIdentity in ipairs(User.getActiveIdentities(vUser)) do
							if DB.getName(nodeTarget) == vIdentity then
								Comm.deliverOOBMessage(msgOOB, sOwner);
								return;
							end
						end
					end
				end
			end
		else
			if DB.isOwner(nodeTarget) then
				handleApplySave(msgOOB);
				return;
			end
		end
	end

	Comm.deliverOOBMessage(msgOOB, "");
end

function onSpellTargeting(rSource, aTargeting, rRolls)
	local bRemoveOnMiss = false;
	local sOptRMMT = OptionsManager.getOption("RMMT");
	if sOptRMMT == "on" then
		bRemoveOnMiss = true;
	elseif sOptRMMT == "multi" then
		local aTargets = {};
		for _,vTargetGroup in ipairs(aTargeting) do
			for _,vTarget in ipairs(vTargetGroup) do
				table.insert(aTargets, vTarget);
			end
		end
		bRemoveOnMiss = (#aTargets > 1);
	end
	
	if bRemoveOnMiss then
		for _,vRoll in ipairs(rRolls) do
			vRoll.bRemoveOnMiss = true;
		end
	end

	return aTargeting;
end

function getSpellCastRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "cast";
	rRoll.aDice = {};
	rRoll.nMod = 0;
	rRoll.sSpellPath = DB.getPath(rAction.nodeSpell);
	
	rRoll.sDesc = ActionCore.encodeActionText(rAction, "action_cast_tag");
	
	-- KEL adding tags to chat message
	if rAction.tags and next(rAction.tags) then
		rRoll.tags = table.concat(rAction.tags, ";");
		rRoll.sDesc = rRoll.sDesc .. " [TAGS: " .. rRoll.tags .. "]";
	end
	-- END
	
	return rRoll;
end

function getCLCRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "clc";
	rRoll.aDice = DiceRollManager.getActorDice({ "d20" }, rActor);
	rRoll.nMod = rAction.clc or 0;
	
	rRoll.sDesc = "[CL CHECK";
	if rAction.order and rAction.order > 1 then
		rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
	end
	rRoll.sDesc = rRoll.sDesc .. "] " .. StringManager.capitalizeAll(rAction.label);
	if rAction.sr == "no" then
		rRoll.sDesc = rRoll.sDesc .. " [SR NOT ALLOWED]";
	end
	-- KEl
	if rAction.tags and next(rAction.tags) then
		rRoll.tags = table.concat(rAction.tags, ";");
	end
	-- END
	return rRoll;
end

function getSaveVsRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "spellsave";
	rRoll.aDice = {};
	-- KEL Save the new tags information (of the bottom line)
	if rAction.tags and next(rAction.tags) then
		rRoll.tags = table.concat(rAction.tags, ";");
	end
	-- KEL DC effect
	local nDCMod, nDCCount = EffectManager35E.getEffectsBonus(rActor, {"DC"}, true, nil, nil, false, rRoll.tags);
	rAction.savemod = rAction.savemod + nDCMod;
	-- END
	rRoll.nMod = rAction.savemod or 0;
	
	rRoll.sDesc = ActionCore.encodeActionText(rAction, "action_savevs_tag");
	
	if rAction.save == "fortitude" then
		rRoll.sDesc = rRoll.sDesc .. " [FORT DC " .. rAction.savemod .. "]";
	elseif rAction.save == "reflex" then
		rRoll.sDesc = rRoll.sDesc .. " [REF DC " .. rAction.savemod .. "]";
	elseif rAction.save == "will" then
		rRoll.sDesc = rRoll.sDesc .. " [WILL DC " .. rAction.savemod .. "]";
	end

	if rAction.dcstat then
		local sAbilityEffect = DataCommon.ability_ltos[rAction.dcstat];
		if sAbilityEffect then
			rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
		end
	end
	if rAction.onmissdamage == "half" then
		rRoll.sDesc = rRoll.sDesc .. " [HALF ON SAVE]";
	end
	
	return rRoll;
end
-- END


function performSpellFailureRoll(rActor, nTarget)
	local rRoll = {
		sType = "spellfailure",
		sDesc = "[SPELL FAILURE CHECK]",
		aDice = { "d100" },
		nTarget = nTarget,
	};
	ActionsManager.roll(rActor, nil, rRoll);
end
function modCastSave(rSource, rTarget, rRoll)
	if rSource then
		local sActionStat = nil;
		local sModStat = string.match(rRoll.sDesc, "%[MOD:(%w+)%]");
		if sModStat then
			sActionStat = DataCommon.ability_stol[sModStat];
		end
		if sActionStat then
			-- KEL adding tags
			local nBonusStat, nBonusEffects = ActorManager35E.getAbilityEffectsBonus(rSource, sActionStat, rRoll.tags);
			-- END
			if nBonusEffects > 0 then
				rRoll.sDesc = string.format("%s %s", rRoll.sDesc, EffectManager.buildEffectOutput(nBonusStat));
				rRoll.nMod = rRoll.nMod + nBonusStat;
			end
		end
	end
end

function modCLC(rSource, rTarget, rRoll)
	if rSource then
		local aAddDice = {};
		local nAddMod = 0;
		
		-- Get CLC modifier effects
		-- KEL adding tags
		local tCLCDice, nCLCMod, nCLCCount = EffectManager35E.getEffectsBonus(rSource, {"CLC"}, false, nil, rTarget, false, rRoll.tags);
		-- END
		if nCLCCount > 0 then
			bEffects = true;
			for _,v in ipairs(tCLCDice) do
				table.insert(aAddDice, v);
			end
			nAddMod = nAddMod + nCLCMod;
		end
		
		-- Get negative levels
		-- KEL add tags
		local nNegLevelMod, nNegLevelCount = EffectManager35E.getEffectsBonus(rSource, {"NLVL"}, true, nil, nil, false, rRoll.tags);
		-- END
		if nNegLevelCount > 0 then
			bEffects = true;
			nAddMod = nAddMod - nNegLevelMod;
		end

		if bEffects then
			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
			rRoll.sDesc = string.format("%s %s", rRoll.sDesc, EffectManager.buildEffectOutput(sMod));
			for _,vDie in ipairs(aAddDice) do
				if vDie:sub(1,1) == "-" then
					table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
				else
					table.insert(rRoll.aDice, "p" .. vDie:sub(2));
				end
			end
			rRoll.nMod = rRoll.nMod + nAddMod;
		end
	end
end

function modConcentration(rSource, rTarget, rRoll)
	if rSource then
		local sActionStat = nil;
		local sModStat = string.match(rRoll.sDesc, "%[MOD:(%w+)%]");
		if sModStat then
			sActionStat = DataCommon.ability_stol[sModStat];
		end

		local nBonusStat, nBonusEffects = ActorManager35E.getAbilityEffectsBonus(rSource, sActionStat);
		if nBonusEffects > 0 then
			rRoll.sDesc = string.format("%s %s", rRoll.sDesc, EffectManager.buildEffectOutput(nBonusStat));
			rRoll.nMod = rRoll.nMod + nBonusStat;
		end
	end
end

function onSpellCast(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	rMessage.dice = nil;
	rMessage.icon = "action_cast";

	if rTarget then
		rMessage.text = rMessage.text .. " [at " .. ActorManager.getDisplayName(rTarget) .. "]";
		-- KEL Adding immunity against tags and overlays
		local spellImmunity = EffectManager35E.hasEffect(rTarget, "SIMMUNE", rSource, false, false, rRoll.tags);
		-- END
		if spellImmunity then
			rMessage.text = rMessage.text .. " [IMMUNE]";
			rMessage.icon = "spell_fail";
			TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -3);
			if rSource then
				local bRemoveTargetanders = false;
				if OptionsManager.isOption("RMMT", "on") then
					bRemoveTargetanders = true;
				elseif rRoll.bRemoveOnMiss then
					bRemoveTargetanders = true;
				end
						
				if bRemoveTargetanders then
					TargetingManager.removeTarget(ActorManager.getCTNode(rSource), ActorManager.getCTNode(rTarget));
				end
			end
		else
			TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -1);
		end
		-- END
	end
	
	Comm.deliverChatMessage(rMessage);

	ActionSpell.handleSpellFailure(rSource, rTarget, rRoll);
end
function handleSpellFailure(rSource, rTarget, rRoll)
	local nodeSpell = DB.findNode(rRoll.sSpellPath);
	local rActor = ActorManager.resolveActor(DB.getChild(nodeSpell, "......."));
	handleSpellFailureConditions(rActor, nodeSpell);
	handleSpellFailureComponents(rActor, nodeSpell);
end
function handleSpellFailureConditions(rActor, nodeSpell)
	if not rActor or not nodeSpell then
		return;
	end

	local tComponents = StringManager.splitByPattern( DB.getValue(nodeSpell, "components", ""):lower(), ",", true);

	if EffectManager.hasCondition(rActor, "Silenced") and StringManager.contains(tComponents, "v") then
		ChatManager.sendMessage(Interface.getString("cast_message_verbalwhilesilenced"), { sIcon = "action_error", rActor = rActor, });
		return;
	end

	local sConcCond;
	if EffectManager.hasCondition(rActor, "Pinned") then
		if StringManager.contains(tComponents, "s") then
			ChatManager.sendMessage(Interface.getString("cast_message_somaticwhilepinned"), { sIcon = "action_error", rActor = rActor, });
			return;
		end
		sConcCond = "Pinned";
	end
	if not sConcCond and EffectManager.hasCondition(rActor, "Entangled") then
		sConcCond = "Entangled";
	end
	if not sConcCond and EffectManager.hasCondition(rActor, "Grappled") then
		sConcCond = "Grappled";
	end
	if sConcCond then
		local sMsg = string.format(Interface.getString("cast_message_needconcentrationcheck"), sConcCond);
		ChatManager.sendMessage(sMsg, { sIcon = "action_warning", rActor = rActor, });
	end
end
function handleSpellFailureComponents(rActor, nodeSpell)
	if not rActor or not nodeSpell then
		return;
	end

	local sComponents = DB.getValue(nodeSpell, "components", "");
	local tComponents = StringManager.splitByPattern(sComponents:lower(), ",", true);
	if StringManager.contains(tComponents, "v") then
		handleSpellFailureVerbal(rActor, nodeSpell);
	end
	if StringManager.contains(tComponents, "s") then
		handleSpellFailureSomatic(rActor, nodeSpell);
	end
end
function handleSpellFailureVerbal(rActor, nodeSpell)
	local nVerbalSpellFailureChance = 0;
	if EffectManager.hasCondition(rActor, "Deafened") then
		nVerbalSpellFailureChance = 20;
		ChatManager.Message(Interface.getString("cast_message_verbalwhiledeafened"), true, rActor);
	end

	if nVerbalSpellFailureChance > 0 then
		if OptionsManager.isOption("AUTO_SPELL_FAILURE", "auto") then
			ActionSpell.performSpellFailureRoll(rActor, nVerbalSpellFailureChance);
		elseif OptionsManager.isOption("AUTO_SPELL_FAILURE", "prompt") then
			local sMsg = string.format(Interface.getString("cast_message_verbal_prompt"), nVerbalSpellFailureChance);
			ChatManager.sendMessage(sMsg, { sIcon = "action_warning", rActor = rActor, });
		end
	end
end
function handleSpellFailureSomatic(rActor, nodeSpell)
	if EffectManager.hasCondition(rActor, "NSF") then
		return;
	end

	local nSomaticSpellFailureChance = 0;
	if ActorManager.isPC(rActor) then
		nSomaticSpellFailureChance = DB.getValue(ActorManager.getCreatureNode(rActor), "encumbrance.spellfailure", 0);
	end
	nSomaticSpellFailureChance = nSomaticSpellFailureChance + EffectManager.getBonusMod(rActor, "SF");

	if nSomaticSpellFailureChance > 0 then
		if OptionsManager.isOption("AUTO_SPELL_FAILURE", "auto") then
			ActionSpell.performSpellFailureRoll(rActor, nSomaticSpellFailureChance);
		elseif OptionsManager.isOption("AUTO_SPELL_FAILURE", "prompt") then
			local sMsg = string.format(Interface.getString("cast_message_somatic_prompt"), nSomaticSpellFailureChance);
			ChatManager.sendMessage(sMsg, { sIcon = "action_warning", rActor = rActor, });
		end
	end
end

function onCastCLC(rSource, rTarget, rRoll)
	if rTarget then
		-- KEL adding SR and tags
		local nSRMod, nSRCount = EffectManager35E.getEffectsBonus(rTarget, {"SR"}, true, nil, rSource, false, rRoll.tags);
		
		local nSR = math.max(ActorManager35E.getSpellDefense(rTarget), nSRMod);
		if nSR > 0 then
			if not string.match(rRoll.sDesc, "%[SR NOT ALLOWED%]") then
				local rRoll = { 
				sType = "clc", 
				sDesc = rRoll.sDesc, 
				aDice = DiceRollManager.getActorDice({ "d20" }, rSource), 
				nMod = rRoll.nMod, 
				bRemoveOnMiss = rRoll.bRemoveOnMiss, 
				tags = rRoll.tags 
				};
		-- END
				ActionsManager.actionDirect(rSource, "clc", { rRoll }, { { rTarget } });
				return true;
			end
		end
	end
end

function onCastSave(rSource, rTarget, rRoll)
	if rTarget then
		local sSaveShort, sSaveDC = string.match(rRoll.sDesc, "%[(%w+) DC (%d+)%]")
		
		if sSaveShort then
			local sSave = DataCommon.save_stol[sSaveShort];
			if sSave then
				-- KEL add tags
				notifyApplySave(rSource, rTarget, rRoll.bSecret, rRoll.sDesc, rRoll.nMod, rRoll.bRemoveOnMiss, rRoll.tags);
				-- END
				return true;
			end
		end
	end

	return false;
end

function onCLC(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);

	local nTotal = ActionsManager.total(rRoll);
	local bSRAllowed = not string.match(rRoll.sDesc, "%[SR NOT ALLOWED%]");
	
	if rTarget then
		-- KEL adding SR and overlays etc
		-- Effect called again, but no problem for [ROLL] etc. because of bSRAllowed check. Maybe change later for performance and aesthetics?
		local nSRMod, nSRCount = EffectManager35E.getEffectsBonus(rTarget, {"SR"}, true, nil, rSource, false, rRoll.tags);
		rMessage.text = rMessage.text .. " [at " .. ActorManager.getDisplayName(rTarget) .. "]";
		
		if bSRAllowed then
			local nSR = math.max(ActorManager35E.getSpellDefense(rTarget),nSRMod);
			if nSR > 0 then
				if nTotal >= nSR then
					rMessage.text = rMessage.text .. " [SUCCESS]";
					TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -1);
				else
					rMessage.text = rMessage.text .. " [FAILURE]";
					TokenManager3.setSaveOverlay(ActorManager.getCTNode(rTarget), -3);
					if rSource then
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
			else
				rMessage.text = rMessage.text .. " [TARGET HAS NO SR]";
			end
		end
	end
	
	Comm.deliverChatMessage(rMessage);
end

function onSpellSave(rSource, rTarget, rRoll)
	if onCastSave(rSource, rTarget, rRoll) then
		return;
	end

	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	Comm.deliverChatMessage(rMessage);
end

function onSpellFailure(rSource, _, rRoll)
	local msg = ActionsManager.createActionMessage(rSource, rRoll);
	if rRoll.nTarget then
		msg.text = StringManager.append(msg.text, string.format("[%d%%]", rRoll.nTarget), " ");
		if rRoll.nTotal > rRoll.nTarget then
			msg.icon = "action_save_success";
			msg.text = StringManager.append(msg.text, "[SUCCEEDED]", "\r");
		else
			msg.icon = "action_save_failure";
			msg.text = StringManager.append(msg.text, "[FAILED]", "\r");
		end
	end
	Comm.deliverChatMessage(msg);
end