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

	ActionsManager.registerModHandler("castsave", modCastSave);
	ActionsManager.registerModHandler("spellsave", modCastSave);
	ActionsManager.registerModHandler("clc", modCLC);
	ActionsManager.registerModHandler("concentration", modConcentration);
	
	ActionsManager.registerResultHandler("cast", onSpellCast);
	ActionsManager.registerResultHandler("castclc", onCastCLC);
	ActionsManager.registerResultHandler("castsave", onCastSave);
	ActionsManager.registerResultHandler("clc", onCLC);
	ActionsManager.registerResultHandler("spellsave", onSpellSave);
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
			ActionSave.performVsRoll(nil, rTarget, sSave, msgOOB.nDC, (tonumber(msgOOB.nSecret) == 1), rSource, msgOOB.bRemoveOnMiss, msgOOB.sDesc, msgOOB.tags);
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

	if bRemoveOnMiss then
		msgOOB.bRemoveOnMiss = 1;
	end

	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if nodeTarget and (sTargetNodeType == "pc") then
		if Session.IsHost then
			local sOwner = DB.getOwner(nodeTarget);
			if sOwner ~= "" then
				for _,vUser in ipairs(User.getActiveUsers()) do
					if vUser == sOwner then
						for _,vIdentity in ipairs(User.getActiveIdentities(vUser)) do
							if nodeTarget.getName() == vIdentity then
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
			vRoll.bRemoveOnMiss = "true";
		end
	end

	return aTargeting;
end

function getSpellCastRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "cast";
	rRoll.aDice = {};
	rRoll.nMod = 0;
	
	rRoll.sDesc = "[CAST";
	if rAction.order and rAction.order > 1 then
		rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
	end
	rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;
	-- Adding new information
	rRoll.school = rAction.school;
	rRoll.spelltype = rAction.stype;
	rRoll.tags = rAction.tags;
	
	return rRoll;
end

function getCLCRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "clc";
	rRoll.aDice = { "d20" };
	rRoll.nMod = rAction.clc or 0;
	
	rRoll.sDesc = "[CL CHECK";
	if rAction.order and rAction.order > 1 then
		rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
	end
	rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;
	if rAction.sr == "no" then
		rRoll.sDesc = rRoll.sDesc .. " [SR NOT ALLOWED]";
	end
	-- Adding new information
	rRoll.school = rAction.school;
	rRoll.spelltype = rAction.stype;
	rRoll.tags = rAction.tags;
	
	return rRoll;
end

function getSaveVsRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "spellsave";
	rRoll.aDice = {};
	-- KEL DC effect
	local rEffectSpell = "";
	local semicolon = ";";
	rEffectSpell = rAction.stype .. semicolon .. rAction.school .. semicolon .. rAction.tags;
	local tagshelp = StringManager.parseWords(rEffectSpell);	
	if not tagshelp[1] then
		rEffectSpell = nil;
	end
	local nDCMod, nDCCount = EffectManager35E.getEffectsBonus(rActor, {"DC"}, true, nil, nil, false, rEffectSpell);
	rAction.savemod = rAction.savemod + nDCMod;
	-- END
	rRoll.nMod = rAction.savemod or 0;
	
	rRoll.sDesc = "[SAVE VS";
	if rAction.order and rAction.order > 1 then
		rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
	end
	rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;
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
	-- KEL Save versus tags new descriptions
	if rAction.stype == "spell" then
		rRoll.sDesc = rRoll.sDesc .. " [SPELL]";
	end
	if rAction.stype == "spelllike" then
		rRoll.sDesc = rRoll.sDesc .. " [SPELLLIKE]";
	end
	if rAction.school == "abjuration" then
		rRoll.sDesc = rRoll.sDesc .. " [ABJURATION]";
	end
	if rAction.school == "conjuration" then
		rRoll.sDesc = rRoll.sDesc .. " [CONJURATION]";
	end
	if rAction.school == "divination" then
		rRoll.sDesc = rRoll.sDesc .. " [DIVINATION]";
	end
	if rAction.school == "enchantment" then
		rRoll.sDesc = rRoll.sDesc .. " [ENCHANTMENT]";
	end
	if rAction.school == "evocation" then
		rRoll.sDesc = rRoll.sDesc .. " [EVOCATION]";
	end
	if rAction.school == "illusion" then
		rRoll.sDesc = rRoll.sDesc .. " [ILLUSION]";
	end
	if rAction.school == "necromancy" then
		rRoll.sDesc = rRoll.sDesc .. " [NECROMANCY]";
	end
	if rAction.school == "transmutation" then
		rRoll.sDesc = rRoll.sDesc .. " [TRANSMUTATION]";
	end
	if rAction.school == "universal" then
		rRoll.sDesc = rRoll.sDesc .. " [UNIVERSAL]";
	end
	if rAction.tags ~= "" then
		rRoll.sDesc = rRoll.sDesc .. " [Other tags: " .. rAction.tags .. "]";
	end
	-- END new descriptions
	
	-- Save the new tags information (of the bottom line)
	rRoll.tags = rAction.tags;
	
	return rRoll;
end

function modCastSave(rSource, rTarget, rRoll)
	if rSource then
		local sActionStat = nil;
		local sModStat = string.match(rRoll.sDesc, "%[MOD:(%w+)%]");
		if sModStat then
			sActionStat = DataCommon.ability_stol[sModStat];
		end
		if sActionStat then
			local nBonusStat, nBonusEffects = ActorManager35E.getAbilityEffectsBonus(rSource, sActionStat);
			if nBonusEffects > 0 then
				local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]";
				rRoll.sDesc = rRoll.sDesc .. " " .. string.format(sFormat, nBonusStat);
				rRoll.nMod = rRoll.nMod + nBonusStat;
			end
		end
	end
end

function modCLC(rSource, rTarget, rRoll)
	if rSource then
		local aAddDice = {};
		local nAddMod = 0;
		
		-- KEL Adding immunity against tags
		local rEffectSpell = "";
		local semicolon = ";";
		rEffectSpell = rRoll.spelltype .. semicolon .. rRoll.school .. semicolon .. rRoll.tags;
		local tagshelp = StringManager.parseWords(rEffectSpell);
		if not tagshelp[1] then
			rEffectSpell = nil;
		end
		
		-- Get CLC modifier effects
		local nCLCMod, nCLCCount = EffectManager35E.getEffectsBonus(rSource, {"CLC"}, true, nil, rTarget, false, rEffectSpell);
		-- END
		if nCLCCount > 0 then
			bEffects = true;
			nAddMod = nAddMod + nCLCMod;
		end
		
		-- Get negative levels
		-- KEL add tags
		local nNegLevelMod, nNegLevelCount = EffectManager35E.getEffectsBonus(rSource, {"NLVL"}, true, nil, nil, false, rEffectSpell);
		-- END
		if nNegLevelCount > 0 then
			bEffects = true;
			nAddMod = nAddMod - nNegLevelMod;
		end

		if bEffects then
			local sEffects = "[" .. Interface.getString("effects_tag");
			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
			if sMod ~= "" then
				sEffects = sEffects .. " " .. sMod;
			end
			sEffects = sEffects .. "]";
			rRoll.sDesc = rRoll.sDesc .. " " .. sEffects;
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
			rRoll.nMod = rRoll.nMod + nBonusStat;

			if nBonusStat ~= 0 then
				local sFormat = "%s [" .. Interface.getString("effects_tag") .. " %+d]";
				rRoll.sDesc = string.format(sFormat, rRoll.sDesc, nBonusStat);
			else
				rRoll.sDesc = rRoll.sDesc .. " [" .. Interface.getString("effects_tag") .. "]";
			end
		end
	end
end

function onSpellCast(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	rMessage.dice = nil;
	rMessage.icon = "spell_cast";

	if rTarget then
		rMessage.text = rMessage.text .. " [at " .. ActorManager.getDisplayName(rTarget) .. "]";
		-- KEL Adding immunity against tags and overlays
		local rEffectSpell = "";
		local semicolon = ";";
		rEffectSpell = rRoll.spelltype .. semicolon .. rRoll.school .. semicolon .. rRoll.tags;
		local tagshelp = StringManager.parseWords(rEffectSpell);
		if not tagshelp[1] then
			rEffectSpell = nil;
		end
		
		local spellImmunity = EffectManager35E.hasEffect(rTarget, "SIMMUNE", rSource, false, false, rEffectSpell);
		
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
end

function onCastCLC(rSource, rTarget, rRoll)
	if rTarget then
		-- KEL adding SR and tags
		local rEffectSpell = "";
		local semicolon = ";";
		rEffectSpell = rRoll.spelltype .. semicolon .. rRoll.school .. semicolon .. rRoll.tags;
		local tagshelp = StringManager.parseWords(rEffectSpell);
		if not tagshelp[1] then
			rEffectSpell = nil;
		end
		
		local nSRMod, nSRCount = EffectManager35E.getEffectsBonus(rTarget, {"SR"}, true, nil, rSource, false, rEffectSpell);
		
		local nSR = math.max(ActorManager35E.getSpellDefense(rTarget), nSRMod);
		if nSR > 0 then
			if not string.match(rRoll.sDesc, "%[SR NOT ALLOWED%]") then
				local rRoll = { sType = "clc", sDesc = rRoll.sDesc, aDice = {"d20"}, nMod = rRoll.nMod, bRemoveOnMiss = rRoll.bRemoveOnMiss, spelltype = rRoll.spelltype, school = rRoll.school, tags = rRoll.tags };
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
		local rEffectSpell = "";
		local semicolon = ";";
		rEffectSpell = rRoll.spelltype .. semicolon .. rRoll.school .. semicolon .. rRoll.tags;
		local tagshelp = StringManager.parseWords(rEffectSpell);
		if not tagshelp[1] then
			rEffectSpell = nil;
		end
		
		-- Effect called again, but no problem for [ROLL] etc. because of bSRAllowed check. Maybe change later for performance and aesthetics?
		local nSRMod, nSRCount = EffectManager35E.getEffectsBonus(rTarget, {"SR"}, true, nil, rSource, false, rEffectSpell);
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
