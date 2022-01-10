-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

OOB_MSGTYPE_APPLYSAVE = "applysave";

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYSAVE, handleApplySave);

	ActionsManager.registerModHandler("save", modSave);
	ActionsManager.registerResultHandler("save", onSave);
end

function handleApplySave(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rOrigin = ActorManager.resolveActor(msgOOB.sTargetNode);
	
	local rAction = {};
	rAction.bSecret = (tonumber(msgOOB.nSecret) == 1);
	rAction.sDesc = msgOOB.sDesc;
	rAction.nTotal = tonumber(msgOOB.nTotal) or 0;
	rAction.sSaveDesc = msgOOB.sSaveDesc;
	rAction.nTarget = tonumber(msgOOB.nTarget) or 0;
	rAction.bRemoveOnMiss = (tonumber(msgOOB.nRemoveOnMiss) == 1);
	rAction.sSaveResult = msgOOB.sSaveResult;
	-- KEL adding tags
	rAction.tags = msgOOB.tags;
	
	applySave(rSource, rOrigin, rAction);
end

function notifyApplySave(rSource, rRoll)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYSAVE;
	
	if rRoll.bTower then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	msgOOB.sDesc = rRoll.sDesc;
	msgOOB.nTotal = ActionsManager.total(rRoll);
	msgOOB.sSaveDesc = rRoll.sSaveDesc;
	msgOOB.nTarget = rRoll.nTarget;
	msgOOB.sSaveResult = rRoll.sSaveResult;
	-- KEL adding tags
	msgOOB.tags = rRoll.tags;
	if rRoll.bRemoveOnMiss then msgOOB.nRemoveOnMiss = 1; end

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	if rRoll.sSource ~= "" then
		msgOOB.sTargetNode = rRoll.sSource;
	end
	
	Comm.deliverOOBMessage(msgOOB, "");
end

function performPartySheetRoll(draginfo, rActor, sSave)
	local rRoll = getRoll(rActor, sSave);
	
	local nTargetDC = DB.getValue("partysheet.savedc", 0);
	if nTargetDC == 0 then
		nTargetDC = nil;
	end
	rRoll.nTarget = nTargetDC;
	if DB.getValue("partysheet.hiderollresults", 0) == 1 then
		rRoll.bSecret = true;
		rRoll.bTower = true;
	end

	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function performVsRoll(draginfo, rActor, sSave, nTargetDC, bSecretRoll, rSource, bRemoveOnMiss, sSaveDesc, tags)
	local rRoll = getVsRoll(rActor, sSave, sSaveDesc, tags);

	if bSecretRoll then
		rRoll.bSecret = true;
	end
	rRoll.nTarget = nTargetDC;
	if bRemoveOnMiss then
		rRoll.bRemoveOnMiss = "true";
	end
	if sSaveDesc then
		rRoll.sSaveDesc = sSaveDesc;
	end
	if rSource then
		rRoll.sSource = ActorManager.getCTNodeName(rSource);
	end
	rRoll.bVsSave = true;

	ActionsManager.performAction(draginfo, rActor, rRoll);
end

-- ROLL VS SCHOOL ETC

function getVsRoll(rActor, sSave, sSaveDesc, tags)
	local rRoll = {};
	local VSData = {};
	rRoll.sType = "save";
	rRoll.aDice = { "d20" };
	rRoll.nMod = 0;
	
	-- Look up actor specific information
	local sAbility = nil;
	local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if nodeActor then
		if sNodeType == "pc" then
			rRoll.nMod = DB.getValue(nodeActor, "saves." .. sSave .. ".total", 0);
			sAbility = DB.getValue(nodeActor, "saves." .. sSave .. ".ability", "");
		else
			rRoll.nMod = DB.getValue(nodeActor, sSave .. "save", 0);
		end
	end

	rRoll.sDesc = "[SAVE] " .. StringManager.capitalize(sSave);
	
	if sAbility and sAbility ~= "" then
		if (sSave == "fortitude" and sAbility ~= "constitution") or
				(sSave == "reflex" and sAbility ~= "dexterity") or
				(sSave == "will" and sAbility ~= "wisdom") then
			local sAbilityEffect = DataCommon.ability_ltos[sAbility];
			if sAbilityEffect then
				rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
			end
		end
	end
	-- KEL Add tags
	rRoll.tags = tags;
	
	return rRoll;
end

-- END ROLL VS SCHOOL ETC

function performRoll(draginfo, rActor, sSave)
	local rRoll = getRoll(rActor, sSave);
	
	if Session.IsHost and CombatManager.isCTHidden(ActorManager.getCTNode(rActor)) then
		rRoll.bSecret = true;
	end

	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function getRoll(rActor, sSave)
	local rRoll = {};
	rRoll.sType = "save";
	rRoll.aDice = { "d20" };
	rRoll.nMod = 0;
	
	-- Look up actor specific information
	local sAbility = nil;
	local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if nodeActor then
		if sNodeType == "pc" then
			rRoll.nMod = DB.getValue(nodeActor, "saves." .. sSave .. ".total", 0);
			sAbility = DB.getValue(nodeActor, "saves." .. sSave .. ".ability", "");
		else
			rRoll.nMod = DB.getValue(nodeActor, sSave .. "save", 0);
		end
	end

	rRoll.sDesc = "[SAVE] " .. StringManager.capitalize(sSave);
	if sAbility and sAbility ~= "" then
		if (sSave == "fortitude" and sAbility ~= "constitution") or
				(sSave == "reflex" and sAbility ~= "dexterity") or
				(sSave == "will" and sAbility ~= "wisdom") then
			local sAbilityEffect = DataCommon.ability_ltos[sAbility];
			if sAbilityEffect then
				rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
			end
		end
	end
	
	return rRoll;
end

function modSave(rSource, rTarget, rRoll)
	local aAddDesc = {};
	local aAddDice = {};
	local nAddMod = 0;
	
	-- Determine save type
	local sSave = nil;
	local sSaveMatch = rRoll.sDesc:match("%[SAVE%] ([^[]+)");
	if sSaveMatch then
		sSave = StringManager.trim(sSaveMatch):lower();
	end
	
	if rSource then
		local bEffects = false;

		-- Determine ability used
		local sActionStat = nil;
		local sModStat = string.match(rRoll.sDesc, "%[MOD:(%w+)%]");
		if sModStat then
			sActionStat = DataCommon.ability_stol[sModStat];
		end
		if not sActionStat then
			if sSave == "fortitude" then
				sActionStat = "constitution";
			elseif sSave == "reflex" then
				sActionStat = "dexterity";
			elseif sSave == "will" then
				sActionStat = "wisdom";
			end
		end
		
		-- Build save filter
		local aSaveFilter = {};
		if sSave then
			table.insert(aSaveFilter, sSave);
		end
		
		-- Determine flatfooted status
		local bFlatfooted = false;
		if not rRoll.bVsSave and ModifierManager.getKey("ATT_FF") then
			bFlatfooted = true;
		elseif EffectManager35E.hasEffect(rSource, "Flat-footed", nil, false, false, rRoll.tags) or EffectManager35E.hasEffect(rSource, "Flatfooted", nil, false, false, rRoll.tags) then
			bFlatfooted = true;
		end
		
		-- Get effect modifiers
		local rSaveSource = nil;
		if rRoll.sSource then
			rSaveSource = ActorManager.resolveActor(rRoll.sSource);
		end
		local aExistingBonusByType = {};
		-- KEL Adding tag information and (dis)adv
		local aADVSAV = EffectManager35E.getEffectsByType(rSource, "ADVSAV", aSaveFilter, rSaveSource, false, rRoll.tags);
		local aDISSAV = EffectManager35E.getEffectsByType(rSource, "DISSAV", aSaveFilter, rSaveSource, false, rRoll.tags);
		local _, nADVSAV = EffectManager35E.hasEffect(rSource, "ADVSAV", rSaveSource, false, false, rRoll.tags);
		local _, nDISSAV = EffectManager35E.hasEffect(rSource, "DISSAV", rSaveSource, false, false, rRoll.tags);
		
		rRoll.adv = #aADVSAV + nADVSAV - (#aDISSAV + nDISSAV);
		
		local aSaveEffects = EffectManager35E.getEffectsByType(rSource, "SAVE", aSaveFilter, rSaveSource, false, rRoll.tags);
		-- END
		for _,v in pairs(aSaveEffects) do
			-- Determine bonus type if any
			local sBonusType = nil;
			for _,v2 in pairs(v.remainder) do
				if StringManager.contains(DataCommon.bonustypes, v2) then
					sBonusType = v2;
					break;
				end
			end
			-- Dodge bonuses stack (by rules)
			if sBonusType then
				if sBonusType == "dodge" then
					if not bFlatfooted then
						nAddMod = nAddMod + v.mod;
						bEffects = true;
					end
				elseif aExistingBonusByType[sBonusType] then
					if v.mod < 0 then
						nAddMod = nAddMod + v.mod;
					elseif v.mod > aExistingBonusByType[sBonusType] then
						nAddMod = nAddMod + v.mod - aExistingBonusByType[sBonusType];
						aExistingBonusByType[sBonusType] = v.mod;
					end
					bEffects = true;
				else
					nAddMod = nAddMod + v.mod;
					aExistingBonusByType[sBonusType] = v.mod;
					bEffects = true;
				end
			else
				nAddMod = nAddMod + v.mod;
				bEffects = true;
			end
		end
		
		-- Get condition modifiers
		if EffectManager35E.hasEffectCondition(rSource, "Frightened", rRoll.tags) or 
				EffectManager35E.hasEffectCondition(rSource, "Panicked", rRoll.tags) or
				EffectManager35E.hasEffectCondition(rSource, "Shaken", rRoll.tags) then
			nAddMod = nAddMod - 2;
			bEffects = true;
		end
		
		if EffectManager35E.hasEffectCondition(rSource, "Sickened", rRoll.tags) then
			nAddMod = nAddMod - 2;
			bEffects = true;
		end
		if sSave == "reflex" then
			if EffectManager35E.hasEffectCondition(rSource, "Slowed", rRoll.tags) then
				nAddMod = nAddMod - 1;
				bEffects = true;
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
		
		-- If flatfooted, then add a note
		if bFlatfooted then
			table.insert(aAddDesc, "[FF]");
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

function onSave(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	Comm.deliverChatMessage(rMessage);
	
	if rRoll.nTarget then
		rRoll.nTotal = ActionsManager.total(rRoll);
		if #(rRoll.aDice) > 0 then
			local nFirstDie = rRoll.aDice[1].result or 0;
			if nFirstDie == 20 then
				rRoll.sSaveResult = "autosuccess";
			elseif nFirstDie == 1 then
				rRoll.sSaveResult = "autofailure";
			end
		end
		if (rRoll.sSaveResult or "") == "" then
			local nTarget = tonumber(rRoll.nTarget) or 0;
			if rRoll.nTotal >= nTarget then
				rRoll.sSaveResult = "success";
			else
				rRoll.sSaveResult = "failure";
			end
		end
		notifyApplySave(rSource, rRoll);
	end
end
-- KEL here Evasion versus tags and adding checks when evasion is allowed to be applied
function applySave(rSource, rOrigin, rAction, sUser)
	local msgShort = {font = "msgfont"};
	local msgLong = {font = "msgfont"};
	-- KEL tags
	local sEffectSpell = rAction.tags;
	msgShort.text = "Save";
	msgLong.text = "Save [" .. rAction.nTotal ..  "]";
	if rAction.nTarget then
		msgLong.text = msgLong.text .. "[vs. DC " .. rAction.nTarget .. "]";
	end
	msgShort.text = msgShort.text .. " ->";
	msgLong.text = msgLong.text .. " ->";
	if rSource then
		msgShort.text = msgShort.text .. " [for " .. ActorManager.getDisplayName(rSource) .. "]";
		msgLong.text = msgLong.text .. " [for " .. ActorManager.getDisplayName(rSource) .. "]";
	end
	if rOrigin then
		msgShort.text = msgShort.text .. " [vs " .. ActorManager.getDisplayName(rOrigin) .. "]";
		msgLong.text = msgLong.text .. " [vs " .. ActorManager.getDisplayName(rOrigin) .. "]";
	end
	
	msgShort.icon = "roll_cast";
		
	local sAttack = "";
	local bHalfMatch = false;
	if rAction.sSaveDesc then
		sAttack = rAction.sSaveDesc:match("%[SAVE VS[^]]*%] ([^[]+)") or "";
		bHalfMatch = (rAction.sSaveDesc:match("%[HALF ON SAVE%]") ~= nil);
	end
	rAction.sResult = "";
	
	if rAction.sSaveResult == "autosuccess" or rAction.sSaveResult == "success" then
		if rAction.sSaveResult == "autosuccess" then
			msgLong.text = msgLong.text .. " [AUTOMATIC SUCCESS]";
		else
			msgLong.text = msgLong.text .. " [SUCCESS]";
		end
		
		if rSource then
			local bHalfDamage = bHalfMatch;
			local bAvoidDamage = false;
			if bHalfDamage then
				local sSave = rAction.sDesc:match("%[SAVE%] (%w+)");
				if sSave then
					sSave = sSave:lower();
				end
				if sSave == "reflex" then
					-- KEL taking conditions into account for (improved) evasion and tags
					if EffectManager35E.hasEffect(rSource, "Improved Evasion", nil, false, true, sEffectSpell) then 
						local condEvasion = true;
						if EffectManager35E.hasEffectCondition(rSource, "helpless", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "paralyzed", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "sleeping", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "unconscious", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "petrified", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "bound", sEffectSpell) then
							condEvasion = false;
						end
						if condEvasion then
							bAvoidDamage = true;
							msgLong.text = msgLong.text .. " [IMPROVED EVASION]";
						end
					elseif EffectManager35E.hasEffect(rSource, "Evasion", nil, false, true, sEffectSpell) then
						local condEvasion = true;
						if EffectManager35E.hasEffectCondition(rSource, "helpless", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "paralyzed", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "sleeping", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "unconscious", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "petrified", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "bound", sEffectSpell) then
							condEvasion = false;
						end
						if condEvasion then
							bAvoidDamage = true;
							msgLong.text = msgLong.text .. " [EVASION]";
						end
					end
				end
			end
			
			if bAvoidDamage then
				rAction.sResult = "none";
				rAction.bRemoveOnMiss = false;
			elseif bHalfDamage then
				rAction.sResult = "half_success";
				rAction.bRemoveOnMiss = false;
			end
			
			-- KEL Add partial image and success overlay
			if bHalfMatch and not bAvoidDamage then
				TokenManager3.setSaveOverlay(ActorManager.getCTNode(rSource), -2);
			else
				TokenManager3.setSaveOverlay(ActorManager.getCTNode(rSource), -3);
			end
			-- END
			
			if rOrigin and rAction.bRemoveOnMiss then
				TargetingManager.removeTarget(ActorManager.getCTNodeName(rOrigin), ActorManager.getCTNodeName(rSource));
			end
		end
	else
		if rAction.sSaveResult == "autofailure" then
			msgLong.text = msgLong.text .. " [AUTOMATIC FAILURE]";
		else
			msgLong.text = msgLong.text .. " [FAILURE]";
		end

		if rSource then
			local bHalfDamage = false;
			if bHalfMatch then
				local sSave = rAction.sDesc:match("%[SAVE%] (%w+)");
				if sSave then
					sSave = sSave:lower();
				end
				if sSave == "reflex" then
					-- KEL taking conditions into account for improved evasion and tags
					if EffectManager35E.hasEffect(rSource, "Improved Evasion", nil, false, true, sEffectSpell) then
						local condEvasion = true;
						if EffectManager35E.hasEffectCondition(rSource, "helpless", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "paralyzed", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "sleeping", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "unconscious", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "petrified", sEffectSpell) or EffectManager35E.hasEffectCondition(rSource, "bound", sEffectSpell) then
							condEvasion = false;
						end
						if condEvasion then
							bHalfDamage = true;
							msgLong.text = msgLong.text .. " [IMPROVED EVASION]";
						end
					end
				end
			end
			
			-- KEL adding overlays
			if bHalfDamage then
				rAction.sResult = "half_failure";
				TokenManager3.setSaveOverlay(ActorManager.getCTNode(rSource), -2);
			else
				rAction.sResult = "failure";
				TokenManager3.setSaveOverlay(ActorManager.getCTNode(rSource), -1);
			end
			-- END
		end
	end
	
	ActionsManager.outputResult(rAction.bSecret, rSource, rOrigin, msgLong, msgShort);
	
	if rSource and rOrigin then
		ActionDamage.setDamageState(rOrigin, rSource, StringManager.trim(sAttack), rAction.sResult);
	end
end
