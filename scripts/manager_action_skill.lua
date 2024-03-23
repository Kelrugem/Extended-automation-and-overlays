function onInit()
    ActionsManager.registerModHandler("skill", modSkill);
end

function modSkill(rSource, rTarget, rRoll)
	local bAssist = Input.isShiftPressed();
	if bAssist then
		rRoll.sDesc = rRoll.sDesc .. " [ASSIST]";
	end

	if rSource then
		local bEffects = false;

		-- Determine skill used
		local sSkillLower = "";
		local sSkill = string.match(rRoll.sDesc, "%[SKILL%] ([^[]+)");
		if sSkill then
			sSkillLower = string.lower(StringManager.trim(sSkill));
		end

		-- Determine ability used with this skill
		local sActionStat = nil;
		local sModStat = string.match(rRoll.sDesc, "%[MOD:(%w+)%]");
		if sModStat then
			sActionStat = DataCommon.ability_stol[sModStat];
		else
			for k, v in pairs(DataCommon.skilldata) do
				if string.lower(k) == sSkillLower then
					sActionStat = v.stat;
				end
			end
		end

		-- Build effect filter for this skill
		local aSkillFilter = {};
		if sActionStat then
			table.insert(aSkillFilter, sActionStat);
		end
		local aSkillNameFilter = {};
		local aSkillWordsLower = StringManager.parseWords(sSkillLower);
		if #aSkillWordsLower > 0 then
			if #aSkillWordsLower == 1 then
				table.insert(aSkillFilter, aSkillWordsLower[1]);
			else
				table.insert(aSkillFilter, table.concat(aSkillWordsLower, " "));
				if aSkillWordsLower[1] == "knowledge" or aSkillWordsLower[1] == "perform" or aSkillWordsLower[1] == "craft" then
					table.insert(aSkillFilter, aSkillWordsLower[1]);
				end
			end
		end
		
		-- KEL: By Soxmax, adv/dis effects; thanks! Tags only there for future features (forced skill rolls etc)
        local aAdvSkill = EffectManager35E.getEffectsByType(rSource, "ADVSKILL", aSkillFilter, rTarget, false, rRoll.tags);
		local aDisSkill = EffectManager35E.getEffectsByType(rSource, "DISSKILL", aSkillFilter, rTarget, false, rRoll.tags);
		local _, nAdvSkill = EffectManager35E.hasEffect(rSource, "ADVSKILL", rTarget, false, false, rRoll.tags);
		local _, nDisSkill = EffectManager35E.hasEffect(rSource, "DISSKILL", rTarget, false, false, rRoll.tags);
		rRoll.adv = #aAdvSkill + nAdvSkill - #aDisSkill - nDisSkill;
		-- END
		
		-- Get effects
		local aAddDice, nAddMod, nEffectCount = EffectManager35E.getEffectsBonus(rSource, {"SKILL"}, false, aSkillFilter);
		if (nEffectCount > 0) then
			bEffects = true;
		end
		
		-- Get condition modifiers
		if EffectManager35E.hasEffectCondition(rSource, "Frightened") or 
				EffectManager35E.hasEffectCondition(rSource, "Panicked") or
				EffectManager35E.hasEffectCondition(rSource, "Shaken") then
			bEffects = true;
			nAddMod = nAddMod - 2;
		end
		if EffectManager35E.hasEffectCondition(rSource, "Sickened") then
			bEffects = true;
			nAddMod = nAddMod - 2;
		end
		if EffectManager35E.hasEffectCondition(rSource, "Blinded") then
			if sActionStat == "strength" or sActionStat == "dexterity" then
				bEffects = true;
				nAddMod = nAddMod - 4;
			elseif sSkillLower == "search" or sSkillLower == "perception" then
				bEffects = true;
				nAddMod = nAddMod - 4;
			end
		elseif EffectManager35E.hasEffectCondition(rSource, "Dazzled") then
			if sSkillLower == "spot" or sSkillLower == "search" or sSkillLower == "perception" then
				bEffects = true;
				nAddMod = nAddMod - 1;
			end
		end
		if EffectManager35E.hasEffectCondition(rSource, "Fascinated") then
			if sSkillLower == "spot" or sSkillLower == "listen" or sSkillLower == "perception" then
				bEffects = true;
				nAddMod = nAddMod - 4;
			end
		end
		-- Exhausted and Fatigued are handled by the effect checks for general ability modifiers

		-- Get ability modifiers
		local nBonusStat, nBonusEffects = ActorManager35E.getAbilityEffectsBonus(rSource, sActionStat);
		if nBonusEffects > 0 then
			bEffects = true;
			nAddMod = nAddMod + nBonusStat;
		end
		
		-- Get negative levels
		local nNegLevelMod, nNegLevelCount = EffectManager35E.getEffectsBonus(rSource, {"NLVL"}, true);
		if nNegLevelCount > 0 then
			bEffects = true;
			nAddMod = nAddMod - nNegLevelMod;
		end

		-- If effects, then add them
		if bEffects then
			for _,vDie in ipairs(aAddDice) do
				if vDie:sub(1,1) == "-" then
					table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
				else
					table.insert(rRoll.aDice, "p" .. vDie:sub(2));
				end
			end
			rRoll.nMod = rRoll.nMod + nAddMod;

			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
			rRoll.sDesc = string.format("%s %s", rRoll.sDesc, EffectManager.buildEffectOutput(sMod));
		end
	end
end
