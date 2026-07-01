-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	ActionsManager.registerModHandler("heal", modHeal);
	ActionsManager.registerResultHandler("heal", onHeal);
end

function getRoll(rActor, rAction)
	local rRoll = {
		sType = "heal",
		sDesc = ActionHealCore.encodeActionText(rAction),
		sLabel = StringManager.capitalizeAll(rAction.label),
		nOrder = rAction.order,
		aDice = {},
		nMod = 0,
		clauses = rAction.clauses or {},
		bOngoing = rAction.bOngoing,
		bNonlethal = rAction.bNonlethal,
		sRange = rAction.range,
		bSelfTarget = ((rAction and rAction.sTargeting or "") == "self"),
		bSecret = rAction.bSecret,
	};
	-- KEL adding tags
	if rAction.tags and next(rAction.tags) then
		rRoll.tags = table.concat(rAction.tags, ";");
	end
	-- END
	-- Handle various heal types
	if (rAction.subtype or "") == "temp" then
		rRoll.healtype = "temp";
		rRoll.sDesc = rRoll.sDesc .. " [TEMP]";
	elseif (rAction.subtype or "") == "sp" then
		rRoll.healtype = "stamina";
		rRoll.sDesc = rRoll.sDesc .. " [STAMINA]";
	elseif (rAction.subtype or "") == "fheal" then
		rRoll.sDesc = string.format("[FHEAL] %s", rAction.label);
	elseif (rAction.subtype or "") == "regen" then
		rRoll.sDesc = string.format("[REGEN] %s", rAction.label);
	else
		rRoll.healtype = rAction.subtype or "";
	end

	-- Add the dice and modifiers
	if rAction.dice or rAction.modifier then
		table.insert(rRoll.clauses, { dice = rAction.dice or {}, modifier = rAction.modifier or 0, });
	end
	rRoll.nHealCost = 0;
	rRoll.nHSMult = 0;
	for _,tClause in pairs(rRoll.clauses) do
		DiceRollManager.addHealDice(rRoll.aDice, tClause.dice, { healtype = rRoll.healtype });
		rRoll.nMod = rRoll.nMod + (tClause.modifier or 0);
		local sAbility = DataCommon.ability_ltos[tClause.stat];
		if sAbility then
			rRoll.sDesc = rRoll.sDesc .. string.format(" [MOD: %s (%s)]", sAbility, tClause.statmult or 1);
		end
		if GameManager.hasOption("healsurge") then
			rRoll.nHealCost = rRoll.nHealCost + (tClause.cost or 0);
			rRoll.nHSMult = rRoll.nHSMult + (tClause.basemult or 0);
		end
	end
	if rRoll.nHealCost ~= 0 then
		rRoll.sDesc = string.format("%s\r[COST %d]", rRoll.sDesc, rRoll.nHealCost);
	end
	if rRoll.nHSMult ~= 0 then
		rRoll.sDesc = string.format("%s\r[HSV %d]", rRoll.sDesc, rRoll.nHSMult);
	end

-- KEL and bmos adding nonlethal healing
	-- Handle nonlethal hit points
	if rAction.subtype == "nl" then
		rRoll.sDesc = rRoll.sDesc .. " [NL]";
	end
-- END

	-- Encode metamagic
	if GameManager.hasOption("metamagic") then
		if rAction.meta then
			if rAction.meta == "empower" then
				rRoll.sDesc = string.format("%s [EMPOWER]", rRoll.sDesc);
			elseif rAction.meta == "maximize" then
				rRoll.sDesc = string.format("%s [MAXIMIZE]", rRoll.sDesc);
			end
		end
	end

	-- Extra display text
	if #(rAction.tAddText or {}) > 0 then
		rRoll.sDesc = rRoll.sDesc .. "\r" .. table.concat(rAction.tAddText, "\r");
	end

	GameManager.callMultiKeyFunctionPostLayered("onActionPostGetRoll", rRoll.sType, rActor, rAction, rRoll);

	-- Encode the damage types
	ActionCore.encodeRollClauses(rRoll);

	return rRoll;
end

function modHeal(rSource, rTarget, rRoll)
	ActionHeal.decodeHealClauses(rRoll);
	CombatManager2.addRightClickDiceToClauses(rRoll);

	-- Set up
	local aAddDesc = {};
	
	-- If source actor, then get modifiers
	if rSource then
		local bEffects = false;
		local aEffectDice = {};
		local nEffectMod = 0;

		-- Apply ability modifiers
		for kClause,vClause in ipairs(rRoll.clauses) do
			-- Get original stat modifier
			local nStatMod = ActorManager35E.getAbilityBonus(rSource, vClause.stat);
			
			-- Get any stat effects bonus
			-- KEL add tags
			local nBonusStat, nBonusEffects = ActorManager35E.getAbilityEffectsBonus(rSource, vClause.stat, rRoll.tags);
			-- END
			if nBonusEffects > 0 then
				bEffects = true;
				
				-- Calc total stat mod
				local nTotalStatMod = nStatMod + nBonusStat;
				
				-- Handle maximum stat mod setting
				local nStatModMax = vClause.statmax or 0;
				if nStatModMax > 0 then
					nStatMod = math.max(math.min(nStatMod, nStatModMax), 0);
					nTotalStatMod = math.max(math.min(nTotalStatMod, nStatModMax), 0);
				end

				-- Calculate bonus difference (and handle decimal multiples)
				local nMult = math.max(vClause.statmult or 1, 1);
				local nMultOrigStatMod = math.floor(nStatMod * nMult);
				local nMultNewStatMod = math.floor(nTotalStatMod * nMult);
				local nMultDiffStatMod = nMultNewStatMod - nMultOrigStatMod;
				
				-- Apply bonus difference
				nEffectMod = nEffectMod + nMultDiffStatMod;
				vClause.modifier = vClause.modifier + nMultDiffStatMod;
				rRoll.nMod = rRoll.nMod + nMultDiffStatMod;
			end
		end
		
		-- Apply general heal modifiers
		local nEffectCount;
		-- KEL
		local aAddDice, nAddMod, nEffectCount = EffectManager35E.getEffectsBonus(rSource, {"HEAL"}, false, nil, rTarget, false, rRoll.tags);
		-- END
		if (nEffectCount > 0) then
			bEffects = true;
			
			DiceRollManager.addHealDice(rRoll.aDice, aAddDice, { iconcolor = "FF00FF", healtype = rRoll.healtype });
			nEffectMod = nEffectMod + nAddMod;
			rRoll.nMod = rRoll.nMod + nAddMod;
		end
		
		-- Add note about effects
		if bEffects then
			local sMod = StringManager.convertDiceToString(aEffectDice, nEffectMod, true);
			table.insert(aAddDesc, EffectManager.buildEffectOutput(sMod));
		end
	end
	
	-- Add notes to roll description
	if #aAddDesc > 0 then
		rRoll.sDesc = rRoll.sDesc .. " " .. table.concat(aAddDesc, " ");
	end
end

function onHeal(rSource, rTarget, rRoll)
	-- Meta spell processing
	local bMaximize = rRoll.sDesc:match(" %[MAXIMIZE%]");
	local bEmpower = rRoll.sDesc:match(" %[EMPOWER%]");
	if bMaximize then
		for _, v in ipairs(rRoll.aDice) do
			local nDieSides = tonumber(v.type:match("d(%d+)")) or 0;
			if nDieSides > 0 then
				v.result = nDieSides;
				v.value = v.result;
			end
		end
	end
	if bEmpower then
		local nEmpowerTotal = ActionsManager.total(rRoll);
		nEmpowerMod = math.floor(nEmpowerTotal / 2);
		
		local sReplace = string.format(" [EMPOWER %+d]", nEmpowerMod);
		rRoll.sDesc = rRoll.sDesc:gsub(" %[EMPOWER%]", sReplace);
		rRoll.nMod = rRoll.nMod + nEmpowerMod;
	end
	
	-- Deliver chat message
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	local bShowMsg = true;
	if rTarget and rTarget.nOrder and rTarget.nOrder ~= 1 then
		bShowMsg = false;
	end
	if bShowMsg then
		Comm.deliverChatMessage(rMessage);
	end
	
	-- Apply heal to target
	local nTotal = ActionsManager.total(rRoll);
	-- KEL add tags
	ActionDamage.notifyApplyDamage(rSource, rTarget, rRoll, rMessage.secret, rRoll.sType, rMessage.text, nTotal, nil, rRoll.tags);
	-- END
end

--
-- UTILITY FUNCTIONS
--

function encodeHealClauses(rRoll)
	for _,vClause in ipairs(rRoll.clauses) do
		local sDice = StringManager.convertDiceToString(vClause.dice, vClause.modifier);
		rRoll.sDesc = rRoll.sDesc .. string.format(" [CLAUSE: (%s) (%s) (%s) (%s)]", sDice, vClause.stat or "", vClause.statmax or 0, vClause.statmult or 1);
	end
end

function decodeHealClauses(rRoll)
	-- Process each type clause in the damage description
	rRoll.clauses = {};
	for sDice, sStat, sStatMax, sStatMult in rRoll.sDesc:gmatch("%[CLAUSE: %(([^)]*)%) %(([^)]*)%) %(([^)]*)%) %(([^)]*)%)]") do
		local rClause = {};
		rClause.dice, rClause.modifier = StringManager.convertStringToDice(sDice);
		rClause.stat = sStat;
		rClause.statmax = tonumber(sStatMax) or 0;
		rClause.statmult = tonumber(sStatMult) or 1;
		
		table.insert(rRoll.clauses, rClause);
	end
	
	-- Remove heal clause information from roll description
	rRoll.sDesc = rRoll.sDesc:gsub(" %[CLAUSE:[^]]*%]", "");
end

