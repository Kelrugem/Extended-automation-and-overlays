-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

-- NOTE: Effect damage dice are not multiplied on critical, though numerical modifiers are multiplied
-- https://rpg.stackexchange.com/questions/4465/is-smite-evil-damage-multiplied-by-a-critical-hit

-- Kel
OOB_MSGTYPE_APPLYTDMG = "applytdmg";
-- END

function onInit()
	ActionDamage.handleApplyDamage = handleApplyDamage
	OOBManager.registerOOBMsgHandler(ActionDamage.OOB_MSGTYPE_APPLYDMG, handleApplyDamage)

	ActionDamage.notifyApplyDamage = notifyApplyDamage

	ActionDamage.onDamage = onDamage
	ActionsManager.registerResultHandler("damage", onDamage)
	ActionsManager.registerResultHandler("spdamage", onDamage)

	ActionDamage.applyAbilityEffectsToModRoll = applyAbilityEffectsToModRoll
	ActionDamage.applyDmgEffectsToModRoll = applyDmgEffectsToModRoll
	ActionDamage.applyConditionsToModRoll = applyConditionsToModRoll
	ActionDamage.applyDmgTypeEffectsToModRoll = applyDmgTypeEffectsToModRoll

	ActionDamage.getDamageAdjust = getDamageAdjust

	ActionDamage.applyDamage = applyDamage
	
	--KEL Fortif roll etc.
	ActionsManager.registerResultHandler("fortification", onFortification);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYTDMG, notifyTDMGRollOnClient);
	--END
end

function handleApplyDamage(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	local bImmune = {};
	local bFortif = {};
	if rTarget then
		rTarget.nOrder = msgOOB.nTargetOrder;
	end
	-- Debug.console(msgOOB);
	local nTotal = tonumber(msgOOB.nTotal) or 0;
	
	-- KEL Apply first Fortification roll if avalaible
	local bDice = {};
	local isFortif = false;
	-- local bImmune = {};
	local bSImmune = {};
	-- local bFortif = {};
	local bSFortif = {};
	local MaxFortifMod = {};
	local bPFMode = DataCommon.isPFRPG();

	-- if string.match(rMessage.text, "%[DAMAGE") then
	local rDamageOutput = ActionDamage.decodeDamageText(nTotal, msgOOB.sDamage);
	if rTarget and rDamageOutput.aDamageTypes then
		local aImmune = EffectManager35E.getEffectsBonusByType(rTarget, "IMMUNE", false, {}, rSource, false, msgOOB.tags);
		local aFortif = EffectManager35E.getEffectsBonusByType(rTarget, "FORTIF", false, {}, rSource, false, msgOOB.tags);
		local bApplyIncorporeal = false;
		local bSourceIncorporeal = false;
		if string.match(rDamageOutput.sOriginal, "%[INCORPOREAL%]") then
			bSourceIncorporeal = true;
		end
		local bTargetIncorporeal = EffectManager35E.hasEffect(rTarget, "Incorporeal", nil, false, false, msgOOB.tags);
		if bTargetIncorporeal and not bSourceIncorporeal then
			bApplyIncorporeal = true;
			if bPFMode then
				aImmune["critical"] = true;
			end
		end
		for k, v in pairs(rDamageOutput.aDamageTypes) do
			MaxFortifMod[k] = 0;
		end
		for k, v in pairs(rDamageOutput.aDamageTypes) do
			-- GET THE INDIVIDUAL DAMAGE TYPES FOR THIS ENTRY (EXCLUDING UNTYPED DAMAGE TYPE)
			local aSrcDmgClauseTypes = {};
			local aTemp = StringManager.split(k, ",", true);
			for i = 1, #aTemp do
				if aTemp[i] ~= "untyped" and aTemp[i] ~= "" then
					table.insert(aSrcDmgClauseTypes, aTemp[i]);
				end
			end
			if #aSrcDmgClauseTypes > 0 then
				local nBasicDmgTypeMatchesFortif = 0;
				local nBasicDmgTypeMatches = 0;
				local nSpecialDmgTypes = 0;
				local nSpecialDmgTypeMatches = 0;
				local nSpecialDmgTypeMatchesFortif = 0;
				local bypass = false;
				-- bImmune["all"] = false;
				bSImmune["all"] = false;
				-- bFortif["all"] = false;
				bSFortif["all"] = false;
				if aImmune["all"] then
					-- bImmune["all"] = true;
					bSImmune["all"] = true;
				end
				if aFortif["all"] then
					-- bFortif["all"] = true;
					bSFortif["all"] = true;
				end
				-- bImmune[k] = false;
				bSImmune[k] = false;
				-- bFortif[k] = false;
				bSFortif[k] = false;
				for _,sDmgType in pairs(aSrcDmgClauseTypes) do
					if StringManager.contains(DataCommon.basicdmgtypes, sDmgType) then
						if aImmune[sDmgType] then nBasicDmgTypeMatches = nBasicDmgTypeMatches + 1; end
						if aFortif[sDmgType] then nBasicDmgTypeMatchesFortif = nBasicDmgTypeMatchesFortif + 1; end
					else
						nSpecialDmgTypes = nSpecialDmgTypes + 1;
						if aImmune[sDmgType] then nSpecialDmgTypeMatches = nSpecialDmgTypeMatches + 1; end
						if aFortif[sDmgType] then nSpecialDmgTypeMatchesFortif = nSpecialDmgTypeMatchesFortif + 1; end
					end
					if (sDmgType == "bypass") or (sDmgType == "immunebypass") then
						bypass = true;
						bSImmune["all"] = false;
					end
				end
				if (nSpecialDmgTypeMatches > 0) and not bypass then
					-- bImmune[k] = true;
					bSImmune[k] = true;
				elseif (nBasicDmgTypeMatches > 0) and not bypass and (nBasicDmgTypeMatches + nSpecialDmgTypes) == #aSrcDmgClauseTypes then
					-- bImmune[k] = true;
					bSImmune[k] = true;
				end
				if (nSpecialDmgTypeMatchesFortif > 0) then
					-- bFortif[k] = true;
					bSFortif[k] = true;
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if not StringManager.contains(DataCommon.basicdmgtypes, sDmgType) and aFortif[sDmgType] then
							MaxFortifMod[k] = math.max(MaxFortifMod[k], aFortif[sDmgType].mod);
						end
					end
				end
				if (nBasicDmgTypeMatchesFortif > 0) and (nBasicDmgTypeMatchesFortif + nSpecialDmgTypes) == #aSrcDmgClauseTypes then
					-- bFortif[k] = true;
					bSFortif[k] = true;
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if StringManager.contains(DataCommon.basicdmgtypes, sDmgType) and aFortif[sDmgType] then
							MaxFortifMod[k] = math.max(MaxFortifMod[k], aFortif[sDmgType].mod);
						end
					end
				end
				-- local FortifApplied = false;
				if bSFortif[k] and not aFortif["all"] and not bSImmune[k] and not aImmune["all"] then
					table.insert(bDice, "d100");
					if not UtilityManager.isClientFGU() then
						table.insert(bDice, "d10");
					end
					isFortif = true;
					-- FortifApplied = true;
				end
				if aFortif["all"] and not aImmune["all"] and not bSImmune[k] then
					table.insert(bDice, "d100");
					if not UtilityManager.isClientFGU() then
						table.insert(bDice, "d10");
					end
					isFortif = true;
					MaxFortifMod[k] = math.max(MaxFortifMod[k], aFortif["all"].mod);
				end
			end
		end
	end
	-- END
	--KEL Add immune and fortif information, even when there is no additional roll (for immunity information)
	if not isFortif then 
		applyDamage(rSource, rTarget, (tonumber(msgOOB.nSecret) == 1), msgOOB.sRollType, msgOOB.sDamage, nTotal, bSImmune, bSFortif, msgOOB.tags);
	else
		local aRollFortif = { sType = "fortification", aDice = bDice, nMod = 0, aType = msgOOB.sRollType, aMessagetext = msgOOB.sDamage, aTotal = nTotal, aTags = msgOOB.tags};
		local rDamageOutput = ActionDamage.decodeDamageText(nTotal, msgOOB.sDamage);
		if tonumber(msgOOB.nSecret) == 1 then
			aRollFortif.bTower = "true";
		else
			aRollFortif.bTower = "false";
		end
		if rTarget then
			for k, v in pairs(rDamageOutput.aDamageTypes) do
				local l = "KELFORTIF " .. k;
				local m = "KELFORTIFMOD " .. k;
				local aSrcDmgClauseTypes = {};
				local aTemp = StringManager.split(k, ",", true);
				for i = 1, #aTemp do
					if aTemp[i] ~= "untyped" and aTemp[i] ~= "" then
						table.insert(aSrcDmgClauseTypes, aTemp[i]);
					end
				end
				if #aSrcDmgClauseTypes > 0 then
					aRollFortif.ImmuneAll = tostring(bSImmune["all"]);
					aRollFortif.FortifAll = tostring(bSFortif["all"]);
					aRollFortif[k] = tostring(bSImmune[k]);
					aRollFortif[l] = tostring(bSFortif[k]);
					aRollFortif[m] = MaxFortifMod[k];
				end
			end
		end
		ActionsManager.roll(rSource, rTarget, aRollFortif);
	end
	
	-- KEL TDMG
	if rTarget then
		if string.match(msgOOB.sDamage, "%[DAMAGE") then
			local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
			if nodeTarget and (sTargetNodeType == "pc") then
				local sOwner = DB.getOwner(nodeTarget);
				if sOwner ~= "" then
					for _,vUser in ipairs(User.getActiveUsers()) do
						if vUser == sOwner then
							for _,vIdentity in ipairs(User.getActiveIdentities(vUser)) do
								if nodeTarget.getName() == vIdentity then
									msgOOB.type = OOB_MSGTYPE_APPLYTDMG;
									Comm.deliverOOBMessage(msgOOB, sOwner);
									return;
								end
							end
						end
					end
				end
			end
			local aAttackFilter = {msgOOB.sFilter};
			getTargetDamageRoll(rTarget, rSource, aAttackFilter, msgOOB.tags);
		end
	end
	-- END
end

-- KEL add attackfilter etc
function notifyApplyDamage(rSource, rTarget, bSecret, sRollType, sDesc, nTotal, sAttackFilter, tag)
	if not rTarget then
		return;
	end

	local msgOOB = {};
	msgOOB.type = ActionDamage.OOB_MSGTYPE_APPLYDMG;
	-- KEL tdmg and tags
	msgOOB.sFilter = sAttackFilter;
	msgOOB.tags = tag;
	-- END
	
	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end
	msgOOB.sRollType = sRollType;
	msgOOB.nTotal = nTotal;
	msgOOB.sDamage = sDesc;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);
	msgOOB.nTargetOrder = rTarget.nOrder;

	Comm.deliverOOBMessage(msgOOB, "");
end

-- KEL TDMG
function notifyTDMGRollOnClient(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	local aAttackFilter = {msgOOB.sFilter};
	getTargetDamageRoll(rTarget, rSource, aAttackFilter, msgOOB.tags);
end

function getTargetDamageRoll(rTarget, rSource, aAttackFilter, tags)
	-- KEL Add Target Damage (see getRoll and "DMG" for example of structure of rRoll then ActionsManager.roll)
	-- Definition of this new rRoll better in a separate function due to encodeDamageTypes
	if rTarget then
		local aEffects, nEffectCount = EffectManager35E.getEffectsBonusByType(rTarget, "TDMG", true, aAttackFilter, rSource, false, tags);
		if nEffectCount > 0 then
			local rRoll = {};
			rRoll.sType = "damage";
			rRoll.aDice = {};
			rRoll.nMod = 0;
			rRoll.clauses = {};
			
			-- rRoll.sDesc = "[DAMAGE";
			-- if rAction.range then
				-- rRoll.sDesc = rRoll.sDesc .. " (" .. rAction.range ..")";
				-- rRoll.range = rAction.range;
			-- end
			rRoll.sDesc = "[TARGET DAMAGE] ";

			-- For each effect, add a damage clause
			for _,v in pairs(aEffects) do
				-- Process effect damage types
				-- local bEffectPrecision = false;
				-- local bEffectCritical = false;
				local aEffectDmgType = {};
				-- local aEffectSpecialDmgType = {};
				for _,sWord in ipairs(v.remainder) do
					if StringManager.contains(DataCommon.specialdmgtypes, sWord) then
						table.insert(aEffectDmgType, sWord);
					elseif StringManager.contains(DataCommon.dmgtypes, sWord) then
						table.insert(aEffectDmgType, sWord);
					end
				end
				
				local rClause = {};
				
				-- Add effect dice
				rClause.dice = {};
				for _,vDie in ipairs(v.dice) do
					table.insert(rRoll.aDice, vDie);
					table.insert(rClause.dice, vDie);
					-- if vDie:sub(1,1) == "-" then
						-- table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
					-- else
						-- table.insert(rRoll.aDice, "p" .. vDie:sub(2));
					-- end
				end
				
				-- for _,vSpecialDmgType in ipairs(aEffectSpecialDmgType) do
					-- table.insert(aEffectDmgType, vSpecialDmgType);
				-- end
				rClause.dmgtype = table.concat(aEffectDmgType, ",");

				local nCurrentMod = v.mod;
				rClause.modifier = nCurrentMod;
				rRoll.nMod = rRoll.nMod + nCurrentMod;

				table.insert(rRoll.clauses, rClause);
			end
			
			-- Encode the damage types
			encodeDamageTypes(rRoll);
			
			ActionsManager.roll(rTarget, rSource, rRoll);
		end
	end
end
-- END

function onDamage(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	rMessage.text = string.gsub(rMessage.text, " %[MOD:[^]]*%]", "");
	rMessage.text = string.gsub(rMessage.text, " %[MULT:[^]]*%]", "");

	local nTotal = ActionsManager.total(rRoll);
	
	-- Send the chat message
	local bShowMsg = true;
	if rTarget and rTarget.nOrder and rTarget.nOrder ~= 1 then
		bShowMsg = false;
	end
	if bShowMsg then
		Comm.deliverChatMessage(rMessage);
	end
	
	-- KEL for TDMG and tags
	local aAttackFilter = "";
	if rRoll.range == "R" then
		aAttackFilter = "ranged"
	elseif rRoll.range == "M" then
		aAttackFilter = "melee";
	end
	local tag = nil;
	if rRoll.tags then
		tag = rRoll.tags;
	end
	
	-- Apply damage to the PC or CT entry referenced
	notifyApplyDamage(rSource, rTarget, rRoll.bTower, rRoll.sType, rMessage.text, nTotal, aAttackFilter, tag);
	-- END
end

--
-- MOD ROLL HELPERS
--

function applyAbilityEffectsToModRoll(rRoll, rSource, rTarget)
	for _,vClause in ipairs(rRoll.clauses) do
		-- Get original stat modifier
		local nStatMod = ActorManager35E.getAbilityBonus(rSource, vClause.stat);
		
		-- Get any stat effects bonus
		-- KEL Add tags
		local nAbilityEffectMod, nAbilityEffects = ActorManager35E.getAbilityEffectsBonus(rSource, vClause.stat, rRoll.tags);
		-- END
		if nAbilityEffects > 0 then
			rRoll.bEffects = true;
			
			-- Calc total stat mod
			local nTotalStatMod = nStatMod + nAbilityEffectMod;
			
			-- Handle maximum stat mod setting
			-- WORKAROUND: If max limited, then assume no penalty allowed (i.e. bows)
			local nStatModMax = vClause.statmax or 0;
			if nStatModMax > 0 then
				nStatMod = math.max(math.min(nStatMod, nStatModMax), 0);
				nTotalStatMod = math.max(math.min(nTotalStatMod, nStatModMax), 0);
			end

			-- Handle multipliers correctly
			-- NOTE: Negative values are not multiplied, but positive values are.
			local nMult = vClause.statmult or 1;
			local nMultOrigStatMod, nMultNewStatMod;
			if nStatMod <= 0 then
				nMultOrigStatMod = nStatMod;
			else
				nMultOrigStatMod = math.floor(nStatMod * nMult);
			end
			if nTotalStatMod <= 0 then
				nMultNewStatMod = nTotalStatMod;
			else
				nMultNewStatMod = math.floor(nTotalStatMod * nMult);
			end
			
			-- Calculate bonus difference
			local nMultDiffStatMod = nMultNewStatMod - nMultOrigStatMod;
			
			-- Apply bonus difference
			rRoll.nEffectMod = rRoll.nEffectMod + nMultDiffStatMod;
			vClause.modifier = vClause.modifier + nMultDiffStatMod;
			rRoll.nMod = rRoll.nMod + nMultDiffStatMod;
		end
	end
end

function applyDmgEffectsToModRoll(rRoll, rSource, rTarget)
	local tEffects, nEffectCount;
	if rRoll.sType == "spdamage" then
		tEffects, nEffectCount = EffectManager35E.getEffectsBonusByType(rSource, "DMGS", true, rRoll.tAttackFilter, rTarget, false, rRoll.tags);
	else
		tEffects, nEffectCount = EffectManager35E.getEffectsBonusByType(rSource, "DMG", true, rRoll.tAttackFilter, rTarget, false, rRoll.tags);
	end
	if nEffectCount > 0 then
		-- Use the first damage clause to determine damage type and crit multiplier for effect damage
		local nEffectCritMult = 2;
		local sEffectBaseType = "";
		if #(rRoll.clauses) > 0 then
			nEffectCritMult = rRoll.clauses[1].mult or 2;
			sEffectBaseType = rRoll.clauses[1].dmgtype or "";
		end

		-- For each effect, add a damage clause
		for _,v in pairs(tEffects) do
			-- Process effect damage types
			local bEffectPrecision = false;
			local bEffectCritical = false;
			local tEffectDmgType = {};
			local tEffectSpecialDmgType = {};
			for _,sWord in ipairs(v.remainder) do
				if StringManager.contains(DataCommon.specialdmgtypes, sWord) then
					table.insert(tEffectSpecialDmgType, sWord);
					if sWord == "critical" then
						bEffectCritical = true;
					elseif sWord == "precision" then
						bEffectPrecision = true;
					end
				elseif StringManager.contains(DataCommon.dmgtypes, sWord) then
					table.insert(tEffectDmgType, sWord);
				end
			end
			
			if not bEffectCritical or rRoll.bCritical then
				rRoll.bEffects = true;
				
				local rClause = {};
				
				-- Add effect dice
				rClause.dice = {};
				for _,vDie in ipairs(v.dice) do
					table.insert(rRoll.tEffectDice, vDie);
					table.insert(rClause.dice, vDie);
					if vDie:sub(1,1) == "-" then
						table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
					else
						table.insert(rRoll.aDice, "p" .. vDie:sub(2));
					end
				end

				if #tEffectDmgType == 0 then
					table.insert(tEffectDmgType, sEffectBaseType);
				end
				for _,vSpecialDmgType in ipairs(tEffectSpecialDmgType) do
					table.insert(tEffectDmgType, vSpecialDmgType);
				end
				rClause.dmgtype = table.concat(tEffectDmgType, ",");

				local nCurrentMod = v.mod;
				rRoll.nEffectMod = rRoll.nEffectMod + nCurrentMod;
				rClause.modifier = nCurrentMod;
				rRoll.nMod = rRoll.nMod + nCurrentMod;

				table.insert(rRoll.clauses, rClause);
				
				-- Add critical effect modifier
				if rRoll.bCritical and not bEffectPrecision and not bEffectCritical and nEffectCritMult > 1 then
					local rClauseCritical = {};
					local nCurrentMod = (v.mod * (nEffectCritMult - 1));
					rClauseCritical.modifier = nCurrentMod;
					if rClause.dmgtype == "" then
						rClauseCritical.dmgtype = "critical";
					else
						rClauseCritical.dmgtype = rClause.dmgtype .. ",critical";
					end
					table.insert(rRoll.clauses, rClauseCritical);

					rRoll.nEffectMod = rRoll.nEffectMod + nCurrentMod;
					rRoll.nMod = rRoll.nMod + nCurrentMod;
				end
			end
		end
	end
end

function applyConditionsToModRoll(rRoll, rSource, rTarget)
	if rRoll.sType ~= "spdamage" then
		if EffectManager35E.hasEffectCondition(rSource, "Sickened", rRoll.tags) then
			rRoll.nMod = rRoll.nMod - 2;
			rRoll.nEffectMod = rRoll.nEffectMod - 2;
			rRoll.bEffects = true;
		end
		if EffectManager35E.hasEffect(rSource, "Incorporeal", nil, false, false, rRoll.tags) and (rRoll.range == "M") 
				and not rRoll.sDesc:lower():match("incorporeal touch") then
			rRoll.bEffects = true;
			table.insert(rRoll.tNotifications, "[INCORPOREAL]");
		end
	end
end

function applyDmgTypeEffectsToModRoll(rRoll, rSource, rTarget)
	local tAddDmgTypes = {};
	local tDmgTypeEffects;
	if rRoll.sType == "spdamage" then
		tDmgTypeEffects = EffectManager35E.getEffectsByType(rSource, "DMGSTYPE", nil, rTarget, false, rRoll.tags);
	else
		tDmgTypeEffects = EffectManager35E.getEffectsByType(rSource, "DMGTYPE", nil, rTarget, false, rRoll.tags);
	end
	for _,rEffectComp in ipairs(tDmgTypeEffects) do
		for _,v2 in ipairs(rEffectComp.remainder) do
			if StringManager.contains(DataCommon.dmgtypes, v2) then
				table.insert(tAddDmgTypes, v2);
			end
		end
	end
	if #tAddDmgTypes > 0 then
		for _,vClause in ipairs(rRoll.clauses) do
			local tSplitTypes = StringManager.split(vClause.dmgtype, ",", true);
			for _,v2 in ipairs(tAddDmgTypes) do
				if not StringManager.contains(tSplitTypes, v2) then
					if vClause.dmgtype ~= "" then
						vClause.dmgtype = vClause.dmgtype .. "," .. v2;
					else
						vClause.dmgtype = v2;
					end
				end
			end
		end

		local sNotification = "[" .. Interface.getString("effects_tag") .. " " .. table.concat(tAddDmgTypes, ",") .. "]";
		table.insert(rRoll.tNotifications, sNotification);
	end
end

--
-- DAMAGE APPLICATION
--

-- KEL bImmune, bFortif
function getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput, bImmune, bFortif, tags)
	-- SETUP
	local nDamageAdjust = 0;
	local nNonlethal = 0;
	local bVulnerable = false;
	local bResist = false;
	local aWords;
	local bPFMode = DataCommon.isPFRPG();
	-- KEL Removing IMMUNE here since called earlier
	-- GET THE DAMAGE ADJUSTMENT EFFECTS
	local aVuln = EffectManager35E.getEffectsBonusByType(rTarget, "VULN", false, {}, rSource, false, tags);
	local aResist = EffectManager35E.getEffectsBonusByType(rTarget, "RESIST", false, {}, rSource, false, tags);
	-- KEL Adding HRESIST
	local aHResist = EffectManager35E.getEffectsBonusByType(rTarget, "HRESIST", false, {}, rSource, false, tags);
	local aDR = EffectManager35E.getEffectsByType(rTarget, "DR", {}, rSource, false, tags);
	-- KEL critical immunity (PFMode) for incorporeal already checked earlier
	local bApplyIncorporeal = false;
	local bSourceIncorporeal = false;
	if string.match(rDamageOutput.sOriginal, "%[INCORPOREAL%]") then
		bSourceIncorporeal = true;
	end
	local bTargetIncorporeal = EffectManager35E.hasEffect(rTarget, "Incorporeal", nil, false, false, tags);
	if bTargetIncorporeal and not bSourceIncorporeal then
		bApplyIncorporeal = true;
	end
	
	-- IF IMMUNE ALL, THEN JUST HANDLE IT NOW
	if bImmune["all"] then
		return (0 - nDamage), 0, false, true;
	end
	
	-- HANDLE REGENERATION
	if not bPFMode then
		local aRegen = EffectManager35E.getEffectsBonusByType(rTarget, "REGEN", false, {});
		local nRegen = 0;
		for _, _ in pairs(aRegen) do
			nRegen = nRegen + 1;
		end
		if nRegen > 0 then
			local aRemap = {};
			for k,v in pairs(rDamageOutput.aDamageTypes) do
				local bCheckRegen = true;
				
				local aSrcDmgClauseTypes = {};
				local aTemp = StringManager.split(k, ",", true);
				for i = 1, #aTemp do
					if aTemp[i] == "nonlethal" then
						bCheckRegen = false;
						break;
					elseif aTemp[i] ~= "untyped" and aTemp[i] ~= "" then
						table.insert(aSrcDmgClauseTypes, aTemp[i]);
					end
				end

				if bCheckRegen then
					local bMatchAND, nMatchAND, bMatchDMG, aClausesOR;
					local bApplyRegen;
					for _,vRegen in pairs(aRegen) do
						bApplyRegen = true;
						
						local sRegen = table.concat(vRegen.remainder, " ");
						
						aClausesOR = decodeAndOrClauses(sRegen);
						if matchAndOrClauses(aClausesOR, aSrcDmgClauseTypes) then
							bApplyRegen = false;
						end
						
						if bApplyRegen then
							local kNew = table.concat(aSrcDmgClauseTypes, ",");
							if kNew ~= "" then
								kNew = kNew .. ",nonlethal";
							else
								kNew = "nonlethal";
							end
							aRemap[k] = kNew;
						end
					end
				end
			end
			for k,v in pairs(aRemap) do
				rDamageOutput.aDamageTypes[v] = rDamageOutput.aDamageTypes[k];
				rDamageOutput.aDamageTypes[k] = nil;
			end
		end
	end
	-- NKEL Define total damager per damage type (e.g. for rounding corrections in VULN and HRESIST) Therefore following for loop outside the big loop,
	-- NKEL Collect damage per type and make sure to avoid double counting (in very very rare situations using DMG effect with special damage type; when one is not careful one might have a damage type twice)
	-- KEL Variables for rounding corrections of VULN and HRESIST when multiple dice are affected (and incorp). Handle each damage type separately (?) for minimizing damage and according to the definition of vulnerability which is specific to the damage type
	local roundingvariableVulnCeil = {};
	roundingvariableVulnCeil["all"] = false;
	local roundingvariableHResistFloor = {};
	roundingvariableHResistFloor["all"] = false;
	local roundingvariableIncorpFloor = false;
	for k, v in pairs(rDamageOutput.aDamageTypes) do
		-- GET THE INDIVIDUAL DAMAGE TYPES FOR THIS ENTRY (EXCLUDING UNTYPED DAMAGE TYPE)
		local aSrcDmgClauseTypes = {};
		local aTemp = StringManager.split(k, ",", true);
		for i = 1, #aTemp do
			if aTemp[i] ~= "untyped" and aTemp[i] ~= "" then
				table.insert(aSrcDmgClauseTypes, aTemp[i]);
			end
		end
		if #aSrcDmgClauseTypes > 0 then
			local DMGAccounted = {};
			for _,sDmgType in pairs(aSrcDmgClauseTypes) do
				roundingvariableVulnCeil[sDmgType] = false;
				roundingvariableHResistFloor[sDmgType] = false;
			end
		end
	end
	-- ITERATE THROUGH EACH DAMAGE TYPE ENTRY
	local nVulnApplied = 0;
	for k, v in pairs(rDamageOutput.aDamageTypes) do
		-- KEL bypass stuff
		local bypass = false; 
		local drbypass = false;
		local resisthalved = false;
		-- GET THE INDIVIDUAL DAMAGE TYPES FOR THIS ENTRY (EXCLUDING UNTYPED DAMAGE TYPE)
		local aSrcDmgClauseTypes = {};
		local bHasEnergyType = false;
		local aTemp = StringManager.split(k, ",", true);
		for i = 1, #aTemp do
			if aTemp[i] ~= "untyped" and aTemp[i] ~= "" then
				table.insert(aSrcDmgClauseTypes, aTemp[i]);
				if not bHasEnergyType and (StringManager.contains(DataCommon.energytypes, aTemp[i]) or (aTemp[i] == "spell")) then
					bHasEnergyType = true;
				end
			end
		end

		-- HANDLE IMMUNITY, VULNERABILITY AND RESISTANCE
		-- KEL Order change; added FORTIF, HRESIST
		local nLocalDamageAdjust = 0;
		if #aSrcDmgClauseTypes > 0 then
			-- CHECK FOR IMMUNITY (Must be immune to all damage types in damage source)
			-- KEL FORTIF, HRESIST, RESIST now work like IMMUNE w.r.t. to damage types (see 3.3.7 patch notes)
			-- KEL IMMUNE and FORTIF handled earlier; removing its part
			local nBasicDmgTypeMatchesHResist = 0;
			
			local nSpecialDmgTypes = 0;
			local nSpecialDmgTypeMatchesHResist = 0;
			for _,sDmgType in pairs(aSrcDmgClauseTypes) do
				if StringManager.contains(DataCommon.basicdmgtypes, sDmgType) then
					if aHResist[sDmgType] then nBasicDmgTypeMatchesHResist = nBasicDmgTypeMatchesHResist + 1; end
				else
					nSpecialDmgTypes = nSpecialDmgTypes + 1;
					if aHResist[sDmgType] then nSpecialDmgTypeMatchesHResist = nSpecialDmgTypeMatchesHResist + 1; end
				end
				if (sDmgType == "bypass") then
					bypass = true;
					drbypass = true;
				elseif (sDmgType == "resistbypass") then
					bypass = true;
				elseif (sDmgType == "drbypass") then
					drbypass = true;
				elseif (sDmgType == "resisthalved") then
					resisthalved = true;
				end
			end
			if resisthalved then
				for _,sResist in pairs(aResist) do
					sResist.mod = math.floor(sResist.mod / 2);
				end
			end
			local bHResist = false;
			if (nSpecialDmgTypeMatchesHResist > 0) and not bypass then
				bHResist = true;
			elseif (nBasicDmgTypeMatchesHResist > 0) and not bypass and (nBasicDmgTypeMatchesHResist + nSpecialDmgTypes) == #aSrcDmgClauseTypes then
				bHResist = true;
			end
			if bImmune[k] then
				nLocalDamageAdjust = nLocalDamageAdjust - v;
				bResist = true;
			elseif bFortif[k] then
				nLocalDamageAdjust = nLocalDamageAdjust - v;
				bResist = true;	
			else
			-- KEL For PF VULN before resistances; 3.5e: VULN at the very end
				if bPFMode then
					local FiniteMaxMod = 0;
					local VulnMaxType = "";
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if aVuln[sDmgType] then
							if FiniteMaxMod < aVuln[sDmgType].mod then
								VulnMaxType = sDmgType;
							end
							FiniteMaxMod = math.max(FiniteMaxMod, aVuln[sDmgType].mod);
						end
					end
					if aVuln["all"] then
						if FiniteMaxMod < aVuln["all"].mod then
							VulnMaxType = "all";
						end
						FiniteMaxMod = math.max(FiniteMaxMod, aVuln["all"].mod);
					end
					if aVuln["all"] then
						local nVulnAmount = 0;
						if aVuln["all"].mod == 0 and not roundingvariableVulnCeil["all"] then
							nVulnAmount = math.floor((v + nLocalDamageAdjust) / 2);
							aVuln["all"].nApplied = nVulnAmount;
							if (v + nLocalDamageAdjust) % 2 ~= 0 then
								roundingvariableVulnCeil["all"] = true;
							end
						elseif aVuln["all"].mod == 0 and roundingvariableVulnCeil["all"] then
							nVulnAmount = math.ceil((v + nLocalDamageAdjust) / 2);
							aVuln["all"].nApplied = nVulnAmount;
							if (v + nLocalDamageAdjust) % 2 ~= 0 then
								roundingvariableVulnCeil["all"] = false;
							end
						elseif aVuln["all"].mod ~= 0 and not aVuln["all"].nApplied then
							nVulnAmount = FiniteMaxMod;
							aVuln[VulnMaxType].nApplied = nVulnAmount;
						end
						nLocalDamageAdjust = nLocalDamageAdjust + nVulnAmount;
						bVulnerable = true;
					end
					local VulnApplied = false;
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if aVuln[sDmgType] and not VulnApplied and not aVuln["all"] then
							local nVulnAmount = 0;
							if aVuln[sDmgType].mod == 0 and not roundingvariableVulnCeil[sDmgType] then
								nVulnAmount = math.floor((v + nLocalDamageAdjust) / 2);
								aVuln[sDmgType].nApplied = nVulnAmount;
								VulnApplied = true;
								if (v + nLocalDamageAdjust) % 2 ~= 0 then
									roundingvariableVulnCeil[sDmgType] = true;
								end
							elseif aVuln[sDmgType].mod == 0 and roundingvariableVulnCeil[sDmgType] then
								nVulnAmount = math.ceil((v + nLocalDamageAdjust) / 2);
								aVuln[sDmgType].nApplied = nVulnAmount;	
								VulnApplied = true;
								if (v + nLocalDamageAdjust) % 2 ~= 0 then
									roundingvariableVulnCeil[sDmgType] = false;
								end
							elseif aVuln[sDmgType].mod ~= 0 and not aVuln[sDmgType].nApplied then
								nVulnAmount = FiniteMaxMod;
								aVuln[VulnMaxType].nApplied = nVulnAmount;
								VulnApplied = true;
							end
							nLocalDamageAdjust = nLocalDamageAdjust + nVulnAmount;
							bVulnerable = true;
						end
					end
				end
				if aHResist["all"] and not bypass then
					local nHresistAmount = 0;
					if not roundingvariableHResistFloor["all"] then
						nHresistAmount = math.ceil((v + nLocalDamageAdjust) / 2);
						if (v + nLocalDamageAdjust) % 2 ~= 0 then
							roundingvariableHResistFloor["all"] = true;
						end
					else
						nHresistAmount = math.floor((v + nLocalDamageAdjust) / 2);
						if (v + nLocalDamageAdjust) % 2 ~= 0 then
							roundingvariableHResistFloor["all"] = false;
						end
					end
					nLocalDamageAdjust = nLocalDamageAdjust - nHresistAmount;
					bResist = true;
				end
				-- KEL HResist vs DMGTYPE; beware corrections for rounding over multiple affected dice (change rounding of odd number involved)
				local HResistApplied = false;
				for _,sDmgType in pairs(aSrcDmgClauseTypes) do
					if aHResist[sDmgType] and bHResist and not aHResist["all"] and not HResistApplied then
						HResistApplied = true;
						local nHresistAmount = 0;
						if not roundingvariableHResistFloor[sDmgType] then
							nHresistAmount = math.ceil((v + nLocalDamageAdjust) / 2);
							if (v + nLocalDamageAdjust) % 2 ~= 0 then
								roundingvariableHResistFloor[sDmgType] = true;
							end
						else
							nHresistAmount = math.floor((v + nLocalDamageAdjust) / 2);
							if (v + nLocalDamageAdjust) % 2 ~= 0 then
								roundingvariableHResistFloor[sDmgType] = false;
							end
						end
						nLocalDamageAdjust = nLocalDamageAdjust - nHresistAmount;
						bResist = true;	
					end
				end
			end
		end
		-- KEL breaking the if clause here to correct the order of DR and Incorp (always minimizing damage as rule)
		-- Thus, be careful with local variables
		
		-- HANDLE INCORPOREAL (PF MODE)
		-- KEL Also here rounding errors; also adding ghost touch
		if bApplyIncorporeal and (v + nLocalDamageAdjust) > 0 then
			local bIgnoreDamage = true;
			local bApplyIncorporeal2 = true;
			for keyDmgType, sDmgType in pairs(aSrcDmgClauseTypes) do
				if sDmgType == "force" then
					bApplyIncorporeal2 = false;
				elseif sDmgType == "ghost touch" then
					bApplyIncorporeal2 = false;
				elseif sDmgType == "spell" or sDmgType == "magic" then
					bIgnoreDamage = false;
				end
			end
			if bApplyIncorporeal2 then
				if bIgnoreDamage then
					nLocalDamageAdjust = -v;
					bResist = true;
				elseif bPFMode then
					if not roundingvariableIncorpFloor then
						if (v + nLocalDamageAdjust) % 2 ~= 0 then
							roundingvariableIncorpFloor = true;
						end
						nLocalDamageAdjust = nLocalDamageAdjust - math.ceil((v + nLocalDamageAdjust) / 2);
					else
						if (v + nLocalDamageAdjust) % 2 ~= 0 then
							roundingvariableIncorpFloor = false;
						end
						nLocalDamageAdjust = nLocalDamageAdjust - math.floor((v + nLocalDamageAdjust) / 2);
					end
					bResist = true;
				end
			end
		end
		
		-- HANDLE DR  (FORM: <type> and <type> or <type> and <type>)
		-- KEL fixing DR stacking. Take biggest modifier and assign reduced dmg to that biggest DR (for that damage die; or should it be w.r.t. to total? However, should not matter since DR normally just affects weapon damage die)
		if not bHasEnergyType and (v + nLocalDamageAdjust) > 0 then
			local bMatchAND, nMatchAND, bMatchDMG, aClausesOR;
			local MaxMod = 0;
			local bApplyDR = {};
			local MaxDRMod = 0;
			local MaxDRType;
			for _,vDR in pairs(aDR) do
				local kDR = table.concat(vDR.remainder, " ");
				if kDR == "" or kDR == "-" or kDR == "all" then
					bApplyDR[vDR] = true;
					if MaxDRMod < vDR.mod then
						MaxDRType = vDR;
						MaxDRMod = vDR.mod;
					end
				else
					bApplyDR[vDR] = true;
					aClausesOR = decodeAndOrClauses(kDR);
					if matchAndOrClauses(aClausesOR, aSrcDmgClauseTypes) then
						bApplyDR[vDR] = false;
					end
					if bApplyDR[vDR] and MaxDRMod < vDR.mod then
						MaxDRType = vDR;
						MaxDRMod = vDR.mod;
					end
				end
			end
			for _,vDR in pairs(aDR) do
				if bApplyDR[vDR] and vDR == MaxDRType and not drbypass then
					local nApplied = vDR.nApplied or 0;
					if nApplied < vDR.mod then
						local nChange = math.min((vDR.mod - nApplied), v + nLocalDamageAdjust);
						vDR.nApplied = nApplied + nChange;
						nLocalDamageAdjust = nLocalDamageAdjust - nChange;
						bResist = true;
					end
				end
			end
		end
		-- KEL going back to the initial if clause
		if #aSrcDmgClauseTypes > 0 then
			if not bImmune[k] and not bFortif[k] then
				local MaxResistMod = 0;
				local MaxDmgType = "";
				local nSpecialDmgTypes = 0;
				local nBasicDmgTypeMatchesResist = 0;
				local nSpecialDmgTypeMatchesResist = 0;
				for _,sDmgType in pairs(aSrcDmgClauseTypes) do
					if StringManager.contains(DataCommon.basicdmgtypes, sDmgType) then
						if aResist[sDmgType] then nBasicDmgTypeMatchesResist = nBasicDmgTypeMatchesResist + 1; end
					else
						nSpecialDmgTypes = nSpecialDmgTypes + 1;
						if aResist[sDmgType] then nSpecialDmgTypeMatchesResist = nSpecialDmgTypeMatchesResist + 1; end
					end
				end
				local cResist = false;
				if (nSpecialDmgTypeMatchesResist > 0) and not bypass then
					cResist = true;
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if not StringManager.contains(DataCommon.basicdmgtypes, sDmgType) and aResist[sDmgType] then
							if MaxResistMod < aResist[sDmgType].mod then
								MaxDmgType = sDmgType;
							end
							MaxResistMod = math.max(MaxResistMod, aResist[sDmgType].mod);
						end
					end
				end
				if (nBasicDmgTypeMatchesResist > 0) and not bypass and (nBasicDmgTypeMatchesResist + nSpecialDmgTypes) == #aSrcDmgClauseTypes then
					cResist = true;
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if StringManager.contains(DataCommon.basicdmgtypes, sDmgType) and aResist[sDmgType] then
							if MaxResistMod < aResist[sDmgType].mod then
								MaxDmgType = sDmgType;
							end
							MaxResistMod = math.max(MaxResistMod, aResist[sDmgType].mod);
						end
					end
				end
				-- CHECK RESISTANCE TO DAMAGE TYPE
				-- KEL Rewriting that such that Resist- all etc. is not ignored for fire damage when Resist fire is there, too. Beware stacking.
				-- KEL Also avoid stacking of Resist slashing and piercing against daggers and so on
				local ResistApplied = false;
				for _,sDmgType in pairs(aSrcDmgClauseTypes) do
					if aResist[sDmgType] and cResist and not ResistApplied then
						local nApplied = aResist[sDmgType].nApplied or 0;
						if nApplied < MaxResistMod then
							local nChange = math.min((MaxResistMod - nApplied), v + nLocalDamageAdjust);
							aResist[sDmgType].nApplied = nApplied + nChange;
							nLocalDamageAdjust = nLocalDamageAdjust - nChange;
							bResist = true;
							ResistApplied = true;
						end
					end
					-- CHECK RESIST ALL
					local HandleAll = true;
					if aResist["all"] and aResist[""] then						
						if aResist["all"].mod < aResist[""].mod then
							HandleAll = false;
						end
					elseif not aResist["all"] and aResist[""] then
						HandleAll = false;
					end
					if aResist["all"] and HandleAll and not bypass then
						local nApplied = aResist["all"].nApplied or 0;
						local HandleStacking = true;
						if aResist[sDmgType] and cResist then
							if aResist["all"].mod < MaxResistMod then
								HandleStacking = false;
							end
							local AlreadyApplied = aResist[sDmgType].nApplied or 0;
							nApplied = nApplied + AlreadyApplied;
						end
						if nApplied < aResist["all"].mod and HandleStacking then
							local nChange = math.min((aResist["all"].mod - nApplied), v + nLocalDamageAdjust);
							aResist["all"].nApplied = nApplied + nChange;
							nLocalDamageAdjust = nLocalDamageAdjust - nChange;
							ResistApplied = true;
							bResist = true;
						end
					end
					if aResist[""] and not HandleAll and not bypass then
						local nApplied = aResist[""].nApplied or 0;
						local HandleStacking = true;
						if aResist[sDmgType] and cResist then
							if aResist[""].mod < MaxResistMod then
								HandleStacking = false;
							end
							local AlreadyApplied = aResist[sDmgType].nApplied or 0;
							nApplied = nApplied + AlreadyApplied;
						end
						if nApplied < aResist[""].mod and HandleStacking then
							local nChange = math.min((aResist[""].mod - nApplied), v + nLocalDamageAdjust);
							aResist[""].nApplied = nApplied + nChange;
							nLocalDamageAdjust = nLocalDamageAdjust - nChange;
							ResistApplied = true;
							bResist = true;
						end
					end
				end
				
				-- CHECK VULN TO DAMAGE TYPES
				-- KEL nLocalDamageAdjust in nVulnAmount and VULN fix, stacking and blah fix
				-- KEL Note/Beware: VULN: (N) overwrites VULN with no number; added VULN: all which overwrites all
				if not bPFMode then
					local FiniteMaxMod = 0;
					local VulnMaxType = "";
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if aVuln[sDmgType] then
							if FiniteMaxMod < aVuln[sDmgType].mod then
								VulnMaxType = sDmgType;
							end
							FiniteMaxMod = math.max(FiniteMaxMod, aVuln[sDmgType].mod);
						end
					end
					if aVuln["all"] then
						if FiniteMaxMod < aVuln["all"].mod then
							VulnMaxType = "all";
						end
						FiniteMaxMod = math.max(FiniteMaxMod, aVuln["all"].mod);
					end
					if aVuln["all"] then
						local nVulnAmount = 0;
						if aVuln["all"].mod == 0 and not roundingvariableVulnCeil["all"] then
							nVulnAmount = math.floor((v + nLocalDamageAdjust) / 2);
							aVuln["all"].nApplied = nVulnAmount;
							if (v + nLocalDamageAdjust) % 2 ~= 0 then
								roundingvariableVulnCeil["all"] = true;
							end
						elseif aVuln["all"].mod == 0 and roundingvariableVulnCeil["all"] then
							nVulnAmount = math.ceil((v + nLocalDamageAdjust) / 2);
							aVuln["all"].nApplied = nVulnAmount;
							if (v + nLocalDamageAdjust) % 2 ~= 0 then
								roundingvariableVulnCeil["all"] = false;
							end
						elseif aVuln["all"].mod ~= 0 and not aVuln["all"].nApplied then
							nVulnAmount = FiniteMaxMod;
							aVuln[VulnMaxType].nApplied = nVulnAmount;
						end
						nLocalDamageAdjust = nLocalDamageAdjust + nVulnAmount;
						bVulnerable = true;
					end
					local VulnApplied = false;
					for _,sDmgType in pairs(aSrcDmgClauseTypes) do
						if aVuln[sDmgType] and not VulnApplied and not aVuln["all"] then
							local nVulnAmount = 0;
							if aVuln[sDmgType].mod == 0 and not roundingvariableVulnCeil[sDmgType] then
								nVulnAmount = math.floor((v + nLocalDamageAdjust) / 2);
								aVuln[sDmgType].nApplied = nVulnAmount;
								VulnApplied = true;
								if (v + nLocalDamageAdjust) % 2 ~= 0 then
									roundingvariableVulnCeil[sDmgType] = true;
								end
							elseif aVuln[sDmgType].mod == 0 and roundingvariableVulnCeil[sDmgType] then
								nVulnAmount = math.ceil((v + nLocalDamageAdjust) / 2);
								aVuln[sDmgType].nApplied = nVulnAmount;	
								VulnApplied = true;
								if (v + nLocalDamageAdjust) % 2 ~= 0 then
									roundingvariableVulnCeil[sDmgType] = false;
								end
							elseif aVuln[sDmgType].mod ~= 0 and not aVuln[sDmgType].nApplied then
								nVulnAmount = FiniteMaxMod;
								aVuln[VulnMaxType].nApplied = nVulnAmount;
								VulnApplied = true;
							end
							nLocalDamageAdjust = nLocalDamageAdjust + nVulnAmount;
							bVulnerable = true;
						end
					end
				end
			end
			
			-- CALCULATE NONLETHAL DAMAGE
			local nNonlethalAdjust = 0;
			if (v + nLocalDamageAdjust) > 0 then
				local bNonlethal = false;
				for keyDmgType, sDmgType in pairs(aSrcDmgClauseTypes) do
					if sDmgType == "nonlethal" then
						bNonlethal = true;
						break;
					end
				end
				if bNonlethal then
					nNonlethalAdjust = v + nLocalDamageAdjust;
				end
			end

			-- APPLY DAMAGE ADJUSTMENT FROM THIS DAMAGE CLAUSE TO OVERALL DAMAGE ADJUSTMENT
			nDamageAdjust = nDamageAdjust + nLocalDamageAdjust - nNonlethalAdjust;
			nNonlethal = nNonlethal + nNonlethalAdjust;
		end
	end

	-- RESULTS
	return nDamageAdjust, nNonlethal, bVulnerable, bResist;
end

-- KEL Too lazy to make strings manually to boolean variables :P
function toboolean(sName)
	local bName = false;
	if sName == "true" then
		bName = true;
	end
	return bName;
end

-- KEL Fortification roll
function onFortification(rSource, rTarget, rRoll)
	local rDamageOutput = ActionDamage.decodeDamageText(tonumber(rRoll.aTotal), rRoll.aMessagetext);
	local FortifSuccess = {};
	local m = 1;
	local bImmune = {};
	local bFortif = {};
	local MaxFortifMod = {};
	local bSecrets = toboolean(rRoll.bTower);
	if rTarget then
		for k, v in pairs(rDamageOutput.aDamageTypes) do
			local l = "KELFORTIF " .. k;
			local q = "KELFORTIFMOD " .. k;
			local aSrcDmgClauseTypes = {};
			local aTemp = StringManager.split(k, ",", true);
			for i = 1, #aTemp do
				if aTemp[i] ~= "untyped" and aTemp[i] ~= "" then
					table.insert(aSrcDmgClauseTypes, aTemp[i]);
				end
			end
			if #aSrcDmgClauseTypes > 0 then
				bImmune["all"] = toboolean(rRoll.ImmuneAll);
				bFortif["all"] = toboolean(rRoll.FortifAll);
				bImmune[k] = toboolean(rRoll[k]);
				bFortif[k] = toboolean(rRoll[l]);
				MaxFortifMod[k] = tonumber(rRoll[q]);
			end
		end
		for k, v in pairs(rDamageOutput.aDamageTypes) do
			local aSrcDmgClauseTypes = {};
			local aTemp = StringManager.split(k, ",", true);
			for i = 1, #aTemp do
				if aTemp[i] ~= "untyped" and aTemp[i] ~= "" then
					table.insert(aSrcDmgClauseTypes, aTemp[i]);
				end
			end
			if #aSrcDmgClauseTypes > 0 then
				-- local FortifApplied = false;
				-- for _,sDmgType in pairs(aSrcDmgClauseTypes) do
				if bFortif[k] and not bFortif["all"] and not bImmune[k] and not bImmune["all"] then
					-- FortifApplied = true;
					local index = {};
					local o = 1;
					for _,n in ipairs(rRoll.aDice) do
						index[n] = o;
						o = o + 1;
					end
					for _,n in ipairs(rRoll.aDice) do
						if index[n] == m then
							local aRoll ={};
							aRoll.sType = rRoll.sType;
							aRoll.aDice = {n};
							aRoll.nMod = rRoll.nMod;
							aRoll.sDesc = "[FORTIFICATION CHANCE " .. MaxFortifMod[k] .. "]" .. "[vs. " .. k .. "]" .. "[to " .. ActorManager.getDisplayName(rTarget) .. "]";
							-- aRoll.bSecret = rRoll.bSecret;
							local rMessage = ActionsManager.createActionMessage(rSource, aRoll);
							-- rMessage.secret = aRoll.bSecret;
							if ActorManager.isPC(rTarget) then
								rMessage.secret = false;
							end
							if n.result <= MaxFortifMod[k] then
								FortifSuccess[k] = true;
								rMessage.text = rMessage.text .. "[ZERO DMG]";
								rMessage.icon = "roll_attack_miss";
							else
								FortifSuccess[k] = false;
								rMessage.text = rMessage.text .. "[FULL DMG]";
								rMessage.icon = "roll_attack_hit";
							end
							Comm.deliverChatMessage(rMessage);
						end
					end
					m = m + 1;
				end
				-- end
				if bFortif["all"] and not bImmune["all"] and not bImmune[k] then
					local index = {};
					local o = 1;
					for _,n in ipairs(rRoll.aDice) do
						index[n] = o;
						o = o + 1;
					end
					for _,n in ipairs(rRoll.aDice) do
						if index[n] == m then
							local aRoll ={};
							aRoll.sType = rRoll.sType;
							aRoll.aDice = {n};
							aRoll.nMod = rRoll.nMod;
							aRoll.sDesc = "[FORTIFICATION CHANCE " .. MaxFortifMod[k] .. "]" .. "[vs. " .. k .. "]" .. "[to " .. ActorManager.getDisplayName(rTarget) .. "]";
							-- aRoll.bSecret = rRoll.bSecret;
							local rMessage = ActionsManager.createActionMessage(rSource, aRoll);
							-- KEL overwrite secret info, for PCs this should be visible. This roll is done on the host side and therefore you have to overwrite this again (especially when GM rolls are hidden)
							-- rMessage.secret = aRoll.bSecret;
							if ActorManager.isPC(rTarget) then
								rMessage.secret = false;
							end
							if n.result <= MaxFortifMod[k] then
								FortifSuccess[k] = true;
								rMessage.text = rMessage.text .. "[ZERO DMG]";
								rMessage.icon = "roll_attack_miss";
							else
								FortifSuccess[k] = false;
								rMessage.text = rMessage.text .. "[FULL DMG]";
								rMessage.icon = "roll_attack_hit";
							end
							Comm.deliverChatMessage(rMessage);
						end
					end
					m = m + 1;
				end
			end
		end
	end
	applyDamage(rSource, rTarget, bSecrets, rRoll.aType, rRoll.aMessagetext, tonumber(rRoll.aTotal), bImmune, FortifSuccess, rRoll.aTags);
end
-- END


-- KEL bImmune, bFortif, tags
function applyDamage(rSource, rTarget, bSecret, sRollType, sDamage, nTotal, bImmune, bFortif, tags)
	local nTotalHP = 0;
	local nTempHP = 0;
	local nNonLethal = 0;
	local nWounds = 0;
	local bPFMode = DataCommon.isPFRPG();

	local aNotifications = {};
	local bRemoveTarget = false;
	
	-- Get health fields
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if not nodeTarget then
		return;
	end
	if sTargetNodeType == "pc" then
		nTotalHP = DB.getValue(nodeTarget, "hp.total", 0);
		nTempHP = DB.getValue(nodeTarget, "hp.temporary", 0);
		nNonlethal = DB.getValue(nodeTarget, "hp.nonlethal", 0);
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0);
	elseif sTargetNodeType == "ct" then
		nTotalHP = DB.getValue(nodeTarget, "hp", 0);
		nTempHP = DB.getValue(nodeTarget, "hptemp", 0);
		nNonlethal = DB.getValue(nodeTarget, "nonlethal", 0);
		nWounds = DB.getValue(nodeTarget, "wounds", 0);
	else
		return;
	end
	
	-- Remember current health status
	local sOriginalStatus = ActorHealthManager.getHealthStatus(rTarget);

	-- Decode damage/heal description
	local rDamageOutput = ActionDamage.decodeDamageText(nTotal, sDamage);
	local aRegenEffectsToDisable = {};

	-- Healing
	if rDamageOutput.sType == "heal" or rDamageOutput.sType == "fheal" then
		-- CHECK COST
		if nWounds <= 0 and nNonlethal <= 0 then
			table.insert(aNotifications, "[NOT WOUNDED]");
		else
			local nHealAmount = rDamageOutput.nVal;
			
			-- CALCULATE HEAL AMOUNTS
			local nNonlethalHealAmount = math.min(nHealAmount, nNonlethal);
			nNonlethal = nNonlethal - nNonlethalHealAmount;
			if (not bPFMode) and (rDamageOutput.sType == "fheal") then
				nHealAmount = nHealAmount - nNonlethalHealAmount;
			end

			local nOriginalWounds = nWounds;
			
			local nWoundHealAmount = math.min(nHealAmount, nWounds);
			nWounds = nWounds - nWoundHealAmount;
			
			-- SET THE ACTUAL HEAL AMOUNT FOR DISPLAY
			rDamageOutput.nVal = nNonlethalHealAmount + nWoundHealAmount;
			if nWoundHealAmount > 0 then
				rDamageOutput.sVal = "" .. nWoundHealAmount;
				if nNonlethalHealAmount > 0 then
					rDamageOutput.sVal = rDamageOutput.sVal .. " (+" .. nNonlethalHealAmount .. " NL)";
				end
			elseif nNonlethalHealAmount > 0 then
				rDamageOutput.sVal = "" .. nNonlethalHealAmount .. " NL";
			else
				rDamageOutput.sVal = "0";
			end
		end

	-- Regeneration
	elseif rDamageOutput.sType == "regen" then
		if nNonlethal <= 0 then
			table.insert(aNotifications, "[NO NONLETHAL DAMAGE]");
		else
			local nNonlethalHealAmount = math.min(rDamageOutput.nVal, nNonlethal);
			nNonlethal = nNonlethal - nNonlethalHealAmount;
			
			rDamageOutput.nVal = nNonlethalHealAmount;
			rDamageOutput.sVal = "" .. nNonlethalHealAmount .. " NL";
		end

	-- Temporary hit points
	elseif rDamageOutput.sType == "temphp" then
		nTempHP = nTempHP + nTotal;

	-- Damage
	else
		-- Apply any targeted damage effects 
		-- NOTE: Dice determined randomly, instead of rolled
		-- KEL Here TDMG is not needed, the following only for: Multiple targets while dmg only rolled once (as for spells), thence, random table only. That is not a problem of DMG
		if rSource and rTarget and rTarget.nOrder then
			local aTargetedDamage;
			if sRollType == "spdamage" then
				aTargetedDamage = EffectManager35E.getEffectsBonusByType(rSource, {"DMGS"}, true, rDamageOutput.aDamageFilter, rTarget, true, tags);
			else
				aTargetedDamage = EffectManager35E.getEffectsBonusByType(rSource, {"DMG"}, true, rDamageOutput.aDamageFilter, rTarget, true, tags);
			end

			local nDamageEffectTotal = 0;
			local nDamageEffectCount = 0;
			for k, v in pairs(aTargetedDamage) do
				local nSubTotal = 0;
				if rDamageOutput.bCritical then
					local nMult = rDamageOutput.nFirstDamageMult or 2;
					nSubTotal = StringManager.evalDice(v.dice, (nMult * v.mod));
				else
					nSubTotal = StringManager.evalDice(v.dice, v.mod);
				end
				
				local sDamageType = rDamageOutput.sFirstDamageType;
				if sDamageType then
					sDamageType = sDamageType .. "," .. k;
				else
					sDamageType = k;
				end

				rDamageOutput.aDamageTypes[sDamageType] = (rDamageOutput.aDamageTypes[sDamageType] or 0) + nSubTotal;
				
				nDamageEffectTotal = nDamageEffectTotal + nSubTotal;
				nDamageEffectCount = nDamageEffectCount + 1;
			end
			nTotal = nTotal + nDamageEffectTotal;

			if nDamageEffectCount > 0 then
				if nDamageEffectTotal ~= 0 then
					local sFormat = "[" .. Interface.getString("effects_tag") .. " %+d]";
					table.insert(aNotifications, string.format(sFormat, nDamageEffectTotal));
				else
					table.insert(aNotifications, "[" .. Interface.getString("effects_tag") .. "]");
				end
			end
		end
		
		-- Handle evasion and half damage
		local isAvoided = false;
		local isHalf = string.match(sDamage, "%[HALF%]");
		local sAttack = string.match(sDamage, "%[DAMAGE[^]]*%] ([^[]+)");
		if sAttack then
			local sDamageState = ActionDamage.getDamageState(rSource, rTarget, StringManager.trim(sAttack));
			if sDamageState == "none" then
				isAvoided = true;
				bRemoveTarget = true;
			elseif sDamageState == "half_success" then
				isHalf = true;
				bRemoveTarget = true;
			elseif sDamageState == "half_failure" then
				isHalf = true;
			end
		end
		if isAvoided then
			table.insert(aNotifications, "[EVADED]");
			for kType, nType in pairs(rDamageOutput.aDamageTypes) do
				rDamageOutput.aDamageTypes[kType] = 0;
			end
			nTotal = 0;
		elseif isHalf then
			table.insert(aNotifications, "[HALF]");
			local bCarry = false;
			for kType, nType in pairs(rDamageOutput.aDamageTypes) do
				local nOddCheck = nType % 2;
				rDamageOutput.aDamageTypes[kType] = math.floor(nType / 2);
				if nOddCheck == 1 then
					if bCarry then
						rDamageOutput.aDamageTypes[kType] = rDamageOutput.aDamageTypes[kType] + 1;
						bCarry = false;
					else
						bCarry = true;
					end
				end
			end
			nTotal = math.max(math.floor(nTotal / 2), 1);
		end
		
		-- Apply damage type adjustments
		-- KEL bImmune, bFortif, tags
		local nDamageAdjust, nNonlethalDmgAmount, bVulnerable, bResist = ActionDamage.getDamageAdjust(rSource, rTarget, nTotal, rDamageOutput, bImmune, bFortif, tags);
		local nAdjustedDamage = nTotal + nDamageAdjust;
		if nAdjustedDamage < 0 then
			nAdjustedDamage = 0;
		end
		if bResist then
			if nAdjustedDamage <= 0 then
				table.insert(aNotifications, "[RESISTED]");
			else
				table.insert(aNotifications, "[PARTIALLY RESISTED]");
			end
		end
		if bVulnerable then
			table.insert(aNotifications, "[VULNERABLE]");
		end
		
		-- Reduce damage by temporary hit points
		if nTempHP > 0 and nAdjustedDamage > 0 then
			if nAdjustedDamage > nTempHP then
				nAdjustedDamage = nAdjustedDamage - nTempHP;
				nTempHP = 0;
				table.insert(aNotifications, "[PARTIALLY ABSORBED]");
			else
				nTempHP = nTempHP - nAdjustedDamage;
				nAdjustedDamage = 0;
				table.insert(aNotifications, "[ABSORBED]");
			end
		end

		-- Apply remaining damage
		if nNonlethalDmgAmount > 0 then
			if bPFMode and (nNonlethal + nNonlethalDmgAmount > nTotalHP) then
				local aRegen = EffectManager35E.getEffectsByType(rTarget, "REGEN");
				if #aRegen == 0 then
					local nOver = nNonlethal + nNonlethalDmgAmount - nTotalHP;
					if nOver > nNonlethalDmgAmount then
						nOver = nNonlethalDmgAmount;
					end
					nAdjustedDamage = nAdjustedDamage + nOver;
					nNonlethalDmgAmount = nNonlethalDmgAmount - nOver;
				end
			end
			nNonlethal = math.max(nNonlethal + nNonlethalDmgAmount, 0);
		end
		if nAdjustedDamage > 0 then
			nWounds = math.max(nWounds + nAdjustedDamage, 0);
			
			-- For Pathfinder, disable regeneration next round on correct damage type
			if bPFMode then
				local nodeTargetCT = ActorManager.getCTNode(rTarget);
				if nodeTargetCT then
					-- Calculate which damage types actually did damage
					local aTempDamageTypes = {};
					local aActualDamageTypes = {};
					for k,v in pairs(rDamageOutput.aDamageTypes) do
						if v > 0 then
							table.insert(aTempDamageTypes, k);
						end
					end
					local aActualDamageTypes = StringManager.split(table.concat(aTempDamageTypes, ","), ",", true);
					
					-- Check target's effects for regeneration effects that match
					for _,v in pairs(DB.getChildren(nodeTargetCT, "effects")) do
						local nActive = DB.getValue(v, "isactive", 0);
						if (nActive == 1) then
							local bMatch = false;
							local sLabel = DB.getValue(v, "label", "");
							local aEffectComps = EffectManager.parseEffect(sLabel);
							for i = 1, #aEffectComps do
								local rEffectComp = EffectManager35E.parseEffectComp(aEffectComps[i]);
								if rEffectComp.type == "REGEN" then
									local sRegen = table.concat(rEffectComp.remainder, " ");
									aClausesOR = decodeAndOrClauses(sRegen);
									if matchAndOrClauses(aClausesOR, aActualDamageTypes) then
										bMatch = true;
									end
								end
								
								if bMatch then
									table.insert(aRegenEffectsToDisable, v);
								end
							end
						end
					end
				end
			end
		end
		
		-- Update the damage output variable to reflect adjustments
		rDamageOutput.nVal = nAdjustedDamage;
		if nAdjustedDamage > 0 then
			rDamageOutput.sVal = string.format("%01d", nAdjustedDamage);
			if nNonlethalDmgAmount > 0 then
				rDamageOutput.sVal = rDamageOutput.sVal .. string.format(" (+%01d NL)", nNonlethalDmgAmount);
			end
		elseif nNonlethalDmgAmount > 0 then
			rDamageOutput.sVal = string.format("%01d NL", nNonlethalDmgAmount);
		else
			rDamageOutput.sVal = "0";
		end
	end

	-- Set health fields
	if sTargetNodeType == "pc" then
		DB.setValue(nodeTarget, "hp.temporary", "number", nTempHP);
		DB.setValue(nodeTarget, "hp.wounds", "number", nWounds);
		DB.setValue(nodeTarget, "hp.nonlethal", "number", nNonlethal);
	else
		DB.setValue(nodeTarget, "hptemp", "number", nTempHP);
		DB.setValue(nodeTarget, "wounds", "number", nWounds);
		DB.setValue(nodeTarget, "nonlethal", "number", nNonlethal);
	end

	-- Check for status change
	local sNewStatus = ActorHealthManager.getHealthStatus(rTarget);
	local bShowStatus = false;
	if ActorManager.getFaction(rTarget) == "friend" then
		bShowStatus = not OptionsManager.isOption("SHPC", "off");
	else
		bShowStatus = not OptionsManager.isOption("SHNPC", "off");
	end
	if bShowStatus then
		if sOriginalStatus ~= sNewStatus then
			table.insert(aNotifications, "[" .. Interface.getString("combat_tag_status") .. ": " .. sNewStatus .. "]");
		end
	end
	
	-- Manage Regeneration effect state when hit with disabling damage
	if #aRegenEffectsToDisable > 0 then
		local nodeTargetCT = ActorManager.getCTNode(rTarget);
		if nodeTargetCT then
			for _,v in ipairs(aRegenEffectsToDisable) do
				if sNewStatus == ActorHealthManager.STATUS_DEAD then
					EffectManager.deactivateEffect(nodeTargetCT, v);
				else
					EffectManager.disableEffect(nodeTargetCT, v);
				end
			end
		end
	end
	
	-- Manage Stable effect add/remove when healed
	if (sOriginalStatus == ActorHealthManager.STATUS_DYING) or (sOriginalStatus == ActorHealthManager.STATUS_DEAD) then
		if (sNewStatus ~= ActorHealthManager.STATUS_DYING) and (sNewStatus ~= ActorHealthManager.STATUS_DEAD) then
			ActorManager35E.removeStableEffect(rTarget);
		else
			-- KEL Remove it after new incoming (lethal) damage
			if ((rDamageOutput.sType == "heal") or (rDamageOutput.sType == "fheal") or (rDamageOutput.sType == "regen")) and (rDamageOutput.nVal > 0) then
				ActorManager35E.applyStableEffect(rTarget);
			elseif (rDamageOutput.sType == "damage") and (rDamageOutput.nVal > 0) then
				ActorManager35E.removeStableEffect(rTarget);
			end
		end
	end
	
	-- Output results
	ActionDamage.messageDamage(rSource, rTarget, bSecret, rDamageOutput.sTypeOutput, sDamage, rDamageOutput.sVal, table.concat(aNotifications, " "));

	-- Remove target after applying damage
	if bRemoveTarget and rSource and rTarget then
		TargetingManager.removeTarget(ActorManager.getCTNodeName(rSource), ActorManager.getCTNodeName(rTarget));
	end
end
