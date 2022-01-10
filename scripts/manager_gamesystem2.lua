-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

-- Ruleset action types

function onInit()
	-- GameSystem.actions = GameSystem2.actions;
	GameSystem.actions["fortification"] = { };
	GameSystem.performConcentrationCheck = GameSystem2.performConcentrationCheck;
end

function performConcentrationCheck(draginfo, rActor, nodeSpellClass)
	if DataCommon.isPFRPG() then
		local rRoll = { sType = "concentration", sDesc = "[CONCENTRATION]", aDice = { "d20" } };
	
		local sAbility = DB.getValue(nodeSpellClass, "dc.ability", "");
		local sAbilityEffect = DataCommon.ability_ltos[sAbility];
		if sAbilityEffect then
			rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
		end

		local nCL = DB.getValue(nodeSpellClass, "cl", 0);
		rRoll.nMod = nCL + ActorManager35E.getAbilityBonus(rActor, sAbility);
		
		local nCCMisc = DB.getValue(nodeSpellClass, "cc.misc", 0);
		if nCCMisc ~= 0 then
			rRoll.nMod = rRoll.nMod + nCCMisc;
			rRoll.sDesc = string.format("%s (Spell Class %+d)", rRoll.sDesc, nCCMisc);
		end
		-- KEL Concentration effects
		local aAddDice, nDCMod, nDCCount = EffectManager35E.getEffectsBonus(rActor, {"COC"}, false, nil, nil, false);
		if nDCCount > 0 then
			rRoll.nMod = rRoll.nMod + nDCMod;
			-- table.insert(aAddDice, aDice);
			for _,vDie in ipairs(aAddDice) do
				if vDie:sub(1,1) == "-" then
					table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
				else
					table.insert(rRoll.aDice, "p" .. vDie:sub(2));
				end
			end
			local aAddDesc = {};
			-- rRoll.sDesc = rRoll.sDesc .. " [EFFECTS" .. nDCMod .. "]";
			local sEffects = "";
			local sMod = StringManager.convertDiceToString(aAddDice, nDCMod, true);
			if sMod ~= "" then
				sEffects = "[" .. Interface.getString("effects_tag") .. " " .. sMod .. "]";
			else
				sEffects = "[" .. Interface.getString("effects_tag") .. "]";
			end
			table.insert(aAddDesc, sEffects);
			if #aAddDesc > 0 then
				rRoll.sDesc = rRoll.sDesc .. " " .. table.concat(aAddDesc, " ");
			end
		end
		-- END
		ActionsManager.performAction(draginfo, rActor, rRoll);
	else
		local sSkill = "Concentration";
		local nValue = 0;

		local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
		if not nodeActor then
			return;
		end
		if sNodeType == "pc" then
			nValue = CharManager.getSkillValue(rActor, sSkill);
		elseif ActorManager.isRecordType(rActor, "npc") then
			local sSkills = DB.getValue(nodeActor, "skills", "");
			local aSkillClauses = StringManager.split(sSkills, ",;\r", true);
			for i = 1, #aSkillClauses do
				local nStarts, nEnds, sLabel, sSign, sMod = string.find(aSkillClauses[i], "([%w%s\(\)]*[%w\(\)]+)%s*([%+%-–]?)(%d*)");
				if nStarts and string.lower(sSkill) == string.lower(sLabel) and sMod ~= "" then
					nValue = tonumber(sMod) or 0;
					if sSign == "-" or sSign == "–" then
						nValue = 0 - nValue;
					end
					break;
				end
			end
		end
		
		local sExtra = nil;
		local nCCMisc = DB.getValue(nodeSpellClass, "cc.misc", 0);
		if nCCMisc ~= 0 then
			nValue = nValue + nCCMisc;
			sExtra = string.format("(Spell Class %+d)", nCCMisc);
		end
		
		ActionSkill.performRoll(draginfo, rActor, sSkill, nValue, nil, sExtra);
	end
end