-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	CombatManager.setCustomSort(CombatManager.sortfuncDnD);

	CombatManager.setCustomAddNPC(addNPC);
	CombatManager.setCustomNPCSpaceReach(getNPCSpaceReach);

	CombatManager.setCustomRoundStart(onRoundStart);
	-- CombatManager.setCustomTurnStart(onTurnStart);
	CombatManager.setCustomTurnEnd(onTurnEnd);
	CombatManager.setCustomCombatReset(resetInit);
end

--
-- TURN FUNCTIONS
--

function onRoundStart(nCurrent)
	if OptionsManager.isOption("HRIR", "on") then
		rollInit();
	end
end

-- function onTurnStart(nodeEntry)
	-- if not nodeEntry then
		-- return;
	-- end
-- end

function onTurnEnd(nodeEntry)
	if not nodeEntry then
		return;
	end
	
	-- Handle beginning of turn changes
	DB.setValue(nodeEntry, "immediate", "number", 0);
	-- KEL
	DB.setValue(nodeEntry, "aoo", "number", 0);
	-- end
	
	-- Check for stabilization (based on option)
	local sOptionHRST = OptionsManager.getOption("HRST");
	if sOptionHRST ~= "off" then
		if (sOptionHRST == "all") or (DB.getValue(nodeEntry, "friendfoe", "") == "friend") then
			local rActor = ActorManager.resolveActor(nodeEntry);
			local sStatus = ActorHealthManager.getHealthStatus(rActor);
			if sStatus == ActorHealthManager.STATUS_DYING then
				if not EffectManager35E.hasEffectCondition(rActor, "Stable") then
					ActionDamage.performStabilizationRoll(rActor);
				end
			end
		end
	end
end

--
-- ADD FUNCTIONS
--

function getNPCSpaceReach(nodeNPC)
	local nSpace = GameSystem.getDistanceUnitsPerGrid();
	local nReach = nSpace;
	
	local sSpaceReach = DB.getValue(nodeNPC, "spacereach", "");
	local sSpace, sReach = string.match(sSpaceReach, "(%d+)%D*/?(%d+)%D*");
	if sSpace then
		nSpace = tonumber(sSpace) or nSpace;
		nReach = tonumber(sReach) or nReach;
	end
	
	return nSpace, nReach;
end
-- KEL For NPC parsing
function tableConcat(origTable, addTable)
	for _,v in pairs(addTable) do
		if not(StringManager.contains(origTable, v)) then
			table.insert(origTable, v)
		end
	end
end
-- END
function addNPC(sClass, nodeNPC, sName)
	local nodeEntry, nodeLastMatch = CombatManager.addNPCHelper(nodeNPC, sName);

	local bPFMode = DataCommon.isPFRPG();
	
	-- KEL for IFTAG SIMMUNE parsing
	local sIftagcomp = {};
	-- END

	-- HP
	local sOptHRNH = OptionsManager.getOption("HRNH");
	local nHP = DB.getValue(nodeNPC, "hp", 0);
	local sHD = StringManager.trim(DB.getValue(nodeNPC, "hd", ""));
	if sOptHRNH == "max" and sHD ~= "" then
		nHP = StringManager.evalDiceString(sHD, true, true);
	elseif sOptHRNH == "random" and sHD ~= "" then
		nHP = math.max(StringManager.evalDiceString(sHD, true), 1);
	end
	DB.setValue(nodeEntry, "hp", "number", nHP);

	-- Defensive properties
	local sAC = DB.getValue(nodeNPC, "ac", "10");
	DB.setValue(nodeEntry, "ac_final", "number", tonumber(string.match(sAC, "^(%d+)")) or 10);
	DB.setValue(nodeEntry, "ac_touch", "number", tonumber(string.match(sAC, "touch (%d+)")) or 10);
	local sFlatFooted = string.match(sAC, "flat[%-–]footed (%d+)");
	if not sFlatFooted then
		sFlatFooted = string.match(sAC, "flatfooted (%d+)");
	end
	DB.setValue(nodeEntry, "ac_flatfooted", "number", tonumber(sFlatFooted) or 10);
	
	-- Handle BAB / Grapple / CM Field
	local sBABGrp = DB.getValue(nodeNPC, "babgrp", "");
	local aSplitBABGrp = StringManager.split(sBABGrp, "/", true);
	
	local sMatch = string.match(sBABGrp, "CMB ([+-]%d+)");
	if sMatch then
		DB.setValue(nodeEntry, "grapple", "number", tonumber(sMatch) or 0);
	else
		if aSplitBABGrp[2] then
			DB.setValue(nodeEntry, "grapple", "number", tonumber(aSplitBABGrp[2]) or 0);
		end
	end

	sMatch = string.match(sBABGrp, "CMD ([+-]?%d+)");
	if sMatch then
		DB.setValue(nodeEntry, "cmd", "number", tonumber(sMatch) or 0);
	else
		if aSplitBABGrp[3] then
			DB.setValue(nodeEntry, "cmd", "number", tonumber(aSplitBABGrp[3]) or 0);
		end
	end

	-- Offensive properties
	local nodeAttacks = nodeEntry.createChild("attacks");
	if nodeAttacks then
		for _,v in pairs(nodeAttacks.getChildren()) do
			v.delete();
		end
		
		local nAttacks = 0;
		
		local sAttack = DB.getValue(nodeNPC, "atk", "");
		if sAttack ~= "" then
			local nodeValue = nodeAttacks.createChild();
			if nodeValue then
				DB.setValue(nodeValue, "value", "string", sAttack);
				nAttacks = nAttacks + 1;
			end
		end
		
		local sFullAttack = DB.getValue(nodeNPC, "fullatk", "");
		if sFullAttack ~= "" then
			nodeValue = nodeAttacks.createChild();
			if nodeValue then
				DB.setValue(nodeValue, "value", "string", sFullAttack);
				nAttacks = nAttacks + 1;
			end
		end
		
		if nAttacks == 0 then
			nodeAttacks.createChild();
		end
	end
	
	-- KEL Add Combat reflexes
	local sFeats = string.lower(DB.getValue(nodeNPC, "feats", ""));
	local aFeats = string.match(sFeats, "combat reflexes");
	if aFeats == "combat reflexes" then
		local aoo = 1;
		local dex = DB.getValue(nodeNPC, "dexterity", 10);
		if (dex > 11) then
			aoo = aoo + math.floor((dex - 10) / 2 );
		end
		DB.setValue(nodeEntry, "aoomax", "number", aoo);
	end
	-- END

	-- Track additional damage types and intrinsic effects
	local aEffects = {};
	local aAddDamageTypes = {};
	
	-- Decode monster type qualities
	local sType = string.lower(DB.getValue(nodeNPC, "type", ""));
	local sCreatureType, sSubTypes = string.match(sType, "([^(]+) %(([^)]+)%)");
	if not sCreatureType then
		sCreatureType = sType;
	end
	local aTypes = StringManager.split(sCreatureType, " ", true);
	local aSubTypes = {};
	if sSubTypes then
		aSubTypes = StringManager.split(sSubTypes, ",", true);
	end

	if StringManager.contains(aSubTypes, "lawful") then
		table.insert(aAddDamageTypes, "lawful");
	end
	if StringManager.contains(aSubTypes, "chaotic") then
		table.insert(aAddDamageTypes, "chaotic");
	end
	if StringManager.contains(aSubTypes, "good") then
		table.insert(aAddDamageTypes, "good");
	end
	if StringManager.contains(aSubTypes, "evil") then
		table.insert(aAddDamageTypes, "evil");
	end
	
	local bImmuneNonlethal = false;
	local bImmuneCritical = false;
	local bImmunePrecision = false;
	-- KEL adding Revert effects
	local bRevert = false;
	-- END
	if bPFMode then
		local bElemental = false;
		if StringManager.contains(aTypes, "construct") then
			table.insert(aEffects, "Construct traits");
			bImmuneNonlethal = true;
			tableConcat(sIftagcomp, DataCommon2.tconstructtraits);
		elseif StringManager.contains(aTypes, "elemental") then
			bElemental = true;
		elseif StringManager.contains(aTypes, "dragon") then
			tableConcat(sIftagcomp, DataCommon2.tdragontraits);
		elseif StringManager.contains(aTypes, "ooze") then
			table.insert(aEffects, "Ooze traits");
			bImmuneCritical = true;
			bImmunePrecision = true;
			tableConcat(sIftagcomp, DataCommon2.toozetraits);
		elseif StringManager.contains(aTypes, "plant") then
			tableConcat(sIftagcomp, DataCommon2.tplanttraits);
		elseif StringManager.contains(aTypes, "undead") then
			table.insert(aEffects, "Undead traits");
			bImmuneNonlethal = true;
			-- KEL
			bRevert = true;
			-- END
			tableConcat(sIftagcomp, DataCommon2.tundeadtraits);
		elseif StringManager.contains(aTypes, "vermin") then
			tableConcat(sIftagcomp, DataCommon2.tvermintraits);
		end
		
		if StringManager.contains(aSubTypes, "aeon") then
			table.insert(aEffects, "Aeon traits");
			bImmuneCritical = true;
		end
		if StringManager.contains(aSubTypes, "elemental") then
			bElemental = true;
		end
		if StringManager.contains(aSubTypes, "incorporeal") then
			bImmunePrecision = true;
		end
		if StringManager.contains(aSubTypes, "swarm") then
			table.insert(aEffects, "Swarm traits");
			bImmuneCritical = true;
		end
		
		if bElemental then
			table.insert(aEffects, "Elemental traits");
			bImmuneCritical = true;
			bImmunePrecision = true;
			tableConcat(sIftagcomp, DataCommon2.telementaltraits);
		end
	else -- KEL Adding precision immunity (if immune to crit then also to precision)
		if StringManager.contains(aTypes, "construct") then
			table.insert(aEffects, "Construct traits");
			bImmuneNonlethal = true;
			bImmuneCritical = true;
			bImmunePrecision = true;
			tableConcat(sIftagcomp, DataCommon2.tconstructtraits);
		elseif StringManager.contains(aTypes, "dragon") then
			tableConcat(sIftagcomp, DataCommon2.tdragontraits);
		elseif StringManager.contains(aTypes, "elemental") then
			table.insert(aEffects, "Elemental traits");
			bImmuneCritical = true;
			bImmunePrecision = true;
			tableConcat(sIftagcomp, DataCommon2.telementaltraits);
		elseif StringManager.contains(aTypes, "ooze") then
			table.insert(aEffects, "Ooze traits");
			bImmuneCritical = true;
			bImmunePrecision = true;
			tableConcat(sIftagcomp, DataCommon2.toozetraits);
		elseif StringManager.contains(aTypes, "plant") then
			table.insert(aEffects, "Plant traits");
			bImmuneCritical = true;
			bImmunePrecision = true;
			tableConcat(sIftagcomp, DataCommon2.tplanttraits);
		elseif StringManager.contains(aTypes, "vermin") then
			tableConcat(sIftagcomp, DataCommon2.tvermintraits);
		elseif StringManager.contains(aTypes, "undead") then
			table.insert(aEffects, "Undead traits");
			bImmuneNonlethal = true;
			bImmuneCritical = true;
			bImmunePrecision = true;
			-- KEL
			bRevert = true;
			-- END
			tableConcat(sIftagcomp, DataCommon2.tundeadtraits);
		end
		if StringManager.contains(aSubTypes, "swarm") then
			table.insert(aEffects, "Swarm traits");
			bImmuneCritical = true;
			bImmunePrecision = true;
		end
	end
	if bImmuneNonlethal then
		table.insert(aEffects, "IMMUNE: nonlethal");
	end
	if bImmuneCritical then
		table.insert(aEffects, "IMMUNE: critical");
	end
	if bImmunePrecision then
		table.insert(aEffects, "IMMUNE: precision");
	end
	-- KEL
	if bRevert then
		table.insert(aEffects, "REVERT: positive");
		table.insert(aEffects, "REVERT: negative");
	end
	-- END

	-- DECODE SPECIAL QUALITIES
	local sSpecialQualities = string.lower(DB.getValue(nodeNPC, "specialqualities", ""));
	
	local aSQWords = StringManager.parseWords(sSpecialQualities);
	local i = 1;
	while aSQWords[i] do
		-- HARDNESS
		if StringManager.isWord(aSQWords[i], "hardness") and StringManager.isNumberString(aSQWords[i+1]) then
			i = i + 1;
			local sHardnessAmount = aSQWords[i];
			if (tonumber(aSQWords[i+1]) or 0) <= 20 then
				table.insert(aEffects, "DR: " .. sHardnessAmount .. " adamantine; RESIST: " .. sHardnessAmount .. " " .. table.concat(DataCommon.energytypes, "; RESIST: " .. sHardnessAmount .. " "));
			else
				table.insert(aEffects, "DR: " .. sHardnessAmount .. " all; RESIST: " .. sHardnessAmount .. " " .. table.concat(DataCommon.energytypes, "; RESIST: " .. sHardnessAmount .. " "));
			end

		-- DAMAGE REDUCTION
		elseif StringManager.isWord(aSQWords[i], "dr") or (StringManager.isWord(aSQWords[i], "damage") and StringManager.isWord(aSQWords[i+1], "reduction")) then
			if aSQWords[i] ~= "dr" then
				i = i + 1;
			end
			
			if StringManager.isNumberString(aSQWords[i+1]) then
				i = i + 1;
				local sDRAmount = aSQWords[i];
				local aDRTypes = {};
				
				while aSQWords[i+1] do
					if StringManager.isWord(aSQWords[i+1], { "and", "or" }) then
						table.insert(aDRTypes, aSQWords[i+1]);
					elseif StringManager.isWord(aSQWords[i+1], { "epic", "magic" }) then
						table.insert(aDRTypes, aSQWords[i+1]);
						table.insert(aAddDamageTypes, aSQWords[i+1]);
					elseif StringManager.isWord(aSQWords[i+1], "cold") and StringManager.isWord(aSQWords[i+2], "iron") then
						table.insert(aDRTypes, "cold iron");
						i = i + 1;
					elseif StringManager.isWord(aSQWords[i+1], DataCommon.dmgtypes) then
						table.insert(aDRTypes, aSQWords[i+1]);
					else
						break;
					end

					i = i + 1;
				end
				
				local sDREffect = "DR: " .. sDRAmount;
				if #aDRTypes > 0 then
					sDREffect = sDREffect .. " " .. table.concat(aDRTypes, " ");
				end
				table.insert(aEffects, sDREffect);
			end

		-- SPELL RESISTANCE
		elseif StringManager.isWord(aSQWords[i], "sr") or (StringManager.isWord(aSQWords[i], "spell") and StringManager.isWord(aSQWords[i+1], "resistance")) then
			if aSQWords[i] ~= "sr" then
				i = i + 1;
			end
			
			if StringManager.isNumberString(aSQWords[i+1]) then
				i = i + 1;
				DB.setValue(nodeEntry, "sr", "number", tonumber(aSQWords[i]) or 0);
			end
		
		-- FAST HEALING
		elseif StringManager.isWord(aSQWords[i], "fast") and StringManager.isWord(aSQWords[i+1], { "healing", "heal" }) then
			i = i + 1;
			
			if StringManager.isNumberString(aSQWords[i+1]) then
				i = i + 1;
				table.insert(aEffects, "FHEAL: " .. aSQWords[i]);
			end
		
		-- REGENERATION
		elseif StringManager.isWord(aSQWords[i], "regeneration") then
			if StringManager.isNumberString(aSQWords[i+1]) then
				i = i + 1;
				local sRegenAmount = aSQWords[i];
				local aRegenTypes = {};
				
				while aSQWords[i+1] do
					if StringManager.isWord(aSQWords[i+1], { "and", "or" }) then
						table.insert(aRegenTypes, aSQWords[i+1]);
					elseif StringManager.isWord(aSQWords[i+1], "cold") and StringManager.isWord(aSQWords[i+2], "iron") then
						table.insert(aRegenTypes, "cold iron");
						i = i + 1;
					elseif StringManager.isWord(aSQWords[i+1], DataCommon.dmgtypes) then
						table.insert(aRegenTypes, aSQWords[i+1]);
					else
						break;
					end

					i = i + 1;
				end
				i = i - 1;
				
				local sRegenEffect = "REGEN: " .. sRegenAmount;
				if #aRegenTypes > 0 then
					sRegenEffect = sRegenEffect .. " " .. table.concat(aRegenTypes, " ");
					EffectManager.addEffect("", "", nodeEntry, { sName = sRegenEffect, nDuration = 0, nGMOnly = 1 }, false);
				else
					table.insert(aEffects, sRegenEffect);
				end
			end
			
		-- RESISTANCE
		elseif StringManager.isWord(aSQWords[i], "resistance") and StringManager.isWord(aSQWords[i+1], "to") then
			i = i + 1;
		
			while aSQWords[i+1] do
				if StringManager.isWord(aSQWords[i+1], "and") then
					-- SKIP
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.energytypes) and StringManager.isNumberString(aSQWords[i+2]) then
					i = i + 1;
					table.insert(aEffects, "RESIST: " .. aSQWords[i+1] .. " " .. aSQWords[i]);
				else
					break;
				end

				i = i + 1;
			end

		elseif StringManager.isWord(aSQWords[i], "resist") then
			while aSQWords[i+1] do
				if StringManager.isWord(aSQWords[i+1], DataCommon.energytypes) and StringManager.isNumberString(aSQWords[i+2]) then
					i = i + 1;
					table.insert(aEffects, "RESIST: " .. aSQWords[i+1] .. " " .. aSQWords[i]);
				elseif not StringManager.isWord(aSQWords[i+1], "and") then
					break;
				end
				
				i = i + 1;
			end
			
		-- VULNERABILITY
		elseif StringManager.isWord(aSQWords[i], {"vulnerability", "vulnerable"}) and StringManager.isWord(aSQWords[i+1], "to") then
			i = i + 1;
		
			while aSQWords[i+1] do
				if StringManager.isWord(aSQWords[i+1], "and") then
					-- SKIP
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.energytypes) then
					table.insert(aEffects, "VULN: " .. aSQWords[i+1]);
				else
					break;
				end

				i = i + 1;
			end
			
		-- IMMUNITY
		elseif StringManager.isWord(aSQWords[i], "immunity") and StringManager.isWord(aSQWords[i+1], "to") then
			i = i + 1;
		
			while aSQWords[i+1] do
				if StringManager.isWord(aSQWords[i+1], "and") then
					-- SKIP
				elseif StringManager.isWord(aSQWords[i+2], "traits") then
					if StringManager.isWord(aSQWords[i+1], "construct") then
						tableConcat(sIftagcomp, DataCommon2.tconstructtraits)
					elseif StringManager.isWord(aSQWords[i+1], "dragon") then
						tableConcat(sIftagcomp, DataCommon2.tdragontraits)
					elseif StringManager.isWord(aSQWords[i+1], "elemental") then
						tableConcat(sIftagcomp, DataCommon2.telementaltraits)
					elseif StringManager.isWord(aSQWords[i+1], "ooze") then
						tableConcat(sIftagcomp, DataCommon2.toozetraits)
					elseif StringManager.isWord(aSQWords[i+1], "plant") then
						tableConcat(sIftagcomp, DataCommon2.tplanttraits)
					elseif StringManager.isWord(aSQWords[i+1], "undead") then
						tableConcat(sIftagcomp, DataCommon2.tundeadtraits)
					elseif StringManager.isWord(aSQWords[i+1], "vermin") then
						tableConcat(sIftagcomp, DataCommon2.tvermintraits)
					end
					-- SKIP+
					i = i + 1;
				-- Add exception for "magic immunity", which is also a damage type
				elseif StringManager.isWord(aSQWords[i+1], "magic") then
					table.insert(aEffects, "IMMUNE: spell");
					-- KEL
					table.insert(aEffects, "SIMMUNE");
					-- END
				elseif StringManager.isWord(aSQWords[i+1], "critical") and StringManager.isWord(aSQWords[i+2], "hits") then
					table.insert(aEffects, "IMMUNE: critical");
					i = i + 1;
				elseif StringManager.isWord(aSQWords[i+1], "precision") and StringManager.isWord(aSQWords[i+2], "damage") then
					table.insert(aEffects, "IMMUNE: precision");
					i = i + 1;
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.immunetypes) then
					table.insert(aEffects, "IMMUNE: " .. aSQWords[i+1]);
					if StringManager.isWord(aSQWords[i+2], "effects") then
						i = i + 1;
					end
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.dmgtypes) and not StringManager.isWord(aSQWords[i+1], DataCommon.specialdmgtypes) then
					table.insert(aEffects, "IMMUNE: " .. aSQWords[i+1]);
				-- KEL
				elseif StringManager.isWord(aSQWords[i+1], DataCommon2.iftagcomp) then
					if aSQWords[i+1] == "mind-affecting" then
						aSQWords[i+1] = "mindaffecting";
					end
					table.insert(sIftagcomp, aSQWords[i+1]);
				-- END
				else
					break;
				end

				i = i + 1;
			end
		elseif StringManager.isWord(aSQWords[i], "immune") then
			while aSQWords[i+1] do
				if StringManager.isWord(aSQWords[i+1], "and") then
					--SKIP
				elseif StringManager.isWord(aSQWords[i+2], "traits") then
					if StringManager.isWord(aSQWords[i+1], "construct") then
						tableConcat(sIftagcomp, DataCommon2.tconstructtraits)
					elseif StringManager.isWord(aSQWords[i+1], "dragon") then
						tableConcat(sIftagcomp, DataCommon2.tdragontraits)
					elseif StringManager.isWord(aSQWords[i+1], "elemental") then
						tableConcat(sIftagcomp, DataCommon2.telementaltraits)
					elseif StringManager.isWord(aSQWords[i+1], "ooze") then
						tableConcat(sIftagcomp, DataCommon2.toozetraits)
					elseif StringManager.isWord(aSQWords[i+1], "plant") then
						tableConcat(sIftagcomp, DataCommon2.tplanttraits)
					elseif StringManager.isWord(aSQWords[i+1], "undead") then
						tableConcat(sIftagcomp, DataCommon2.tundeadtraits)
					elseif StringManager.isWord(aSQWords[i+1], "vermin") then
						tableConcat(sIftagcomp, DataCommon2.tvermintraits)
					end
					-- SKIP+
					i = i + 1;
				-- Add exception for "magic immunity", which is also a damage type
				elseif StringManager.isWord(aSQWords[i+1], "magic") then
					table.insert(aEffects, "IMMUNE: spell");
					-- KEL
					table.insert(aEffects, "SIMMUNE");
					-- END
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.immunetypes) then
					table.insert(aEffects, "IMMUNE: " .. aSQWords[i+1]);
					if StringManager.isWord(aSQWords[i+2], "effects") then
						i = i + 1;
					end
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.dmgtypes) then
					table.insert(aEffects, "IMMUNE: " .. aSQWords[i+1]);
				-- KEL
				elseif StringManager.isWord(aSQWords[i+1], DataCommon2.iftagcomp) then
					if aSQWords[i+1] == "mind-affecting" then
						aSQWords[i+1] = "mindaffecting";
					end
					table.insert(sIftagcomp, aSQWords[i+1]);
				-- END
				else
					break;
				end

				i = i + 1;
			end
			
		-- SPECIAL DEFENSES
		elseif StringManager.isWord(aSQWords[i], "uncanny") and StringManager.isWord(aSQWords[i+1], "dodge") then
			if StringManager.isWord(aSQWords[i-1], "improved") then
				table.insert(aEffects, "Improved Uncanny Dodge");
			else
				table.insert(aEffects, "Uncanny Dodge");
			end
			i = i + 1;
		
		elseif StringManager.isWord(aSQWords[i], "evasion") then
			if StringManager.isWord(aSQWords[i-1], "improved") then
				table.insert(aEffects, "Improved Evasion");
			else
				table.insert(aEffects, "Evasion");
			end
		
		-- TRAITS
		elseif StringManager.isWord(aSQWords[i], "incorporeal") then
			table.insert(aEffects, "Incorporeal");
		elseif StringManager.isWord(aSQWords[i], "blur") then
			table.insert(aEffects, "CONC");
		elseif StringManager.isWord(aSQWords[i], "natural") and StringManager.isWord(aSQWords[i+1], "invisibility") then
			table.insert(aEffects, "Invisible");
		end
	
		-- ITERATE SPECIAL QUALITIES DECODE
		i = i + 1;
	end

	-- FINISH ADDING EXTRA DAMAGE TYPES
	if #aAddDamageTypes > 0 then
		table.insert(aEffects, "DMGTYPE: " .. table.concat(aAddDamageTypes, ","));
	end
	
	-- KEL
	if #sIftagcomp > 0 then
		sTags = table.concat(sIftagcomp, ", ");
		table.insert(aEffects, "IFTAG: " .. sTags);
		table.insert(aEffects, "SIMMUNE");
	end
	-- END
	
	-- ADD DECODED EFFECTS
	if #aEffects > 0 then
		EffectManager.addEffect("", "", nodeEntry, { sName = table.concat(aEffects, "; "), nDuration = 0, nGMOnly = 1 }, false);
	end

	-- Roll initiative and sort
	local sOptINIT = OptionsManager.getOption("INIT");
	-- KEL FFOS, only NPCs here
	local nCurrent = DB.getValue("combattracker.round", 0);
	local sOptFFOS = OptionsManager.getOption("FFOS");
	local bHasUncDodge = false;
	if (sOptFFOS == "on") and (nCurrent == 0) then
		local sAbilityname = string.lower(DB.getValue(nodeEntry, "specialqualities", ""));
		if string.match(sAbilityname, "improved uncanny dodge") or string.match(sAbilityname, "uncanny dodge") then
			bHasUncDodge = true;
		end
	end
	-- END
	-- KEL compatibility with rmilmine
	-- if StringManager.contains(Extension.getExtensions(), "Advanced Effects for 3.5E and Pathfinder") then
		-- EffectManagerAE.updateCharEffects(nodeNPC,nodeEntry);
	-- end
	-- END
	if sOptINIT == "group" then
		if nodeLastMatch then
			local nLastInit = DB.getValue(nodeLastMatch, "initresult", 0);
			DB.setValue(nodeEntry, "initresult", "number", nLastInit);
			-- KEL FFOS
			if (sOptFFOS == "on") and (nCurrent == 0) and not bHasUncDodge then
				EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nLastInit, nGMOnly = 1 }, false);
			end
			-- END
		else
			local nInitResult = math.random(20) + DB.getValue(nodeEntry, "init", 0);
			DB.setValue(nodeEntry, "initresult", "number", nInitResult);
			-- KEL FFOS
			if (sOptFFOS == "on") and (nCurrent == 0) and not bHasUncDodge then
				EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
			end
			--END
		end
	elseif sOptINIT == "on" then
		local nInitResult = math.random(20) + DB.getValue(nodeEntry, "init", 0);
		DB.setValue(nodeEntry, "initresult", "number", nInitResult);
		-- KEL FFOS
		if (sOptFFOS == "on") and (nCurrent == 0) and not bHasUncDodge then
			EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
		end
		-- END
	end

	return nodeEntry;
end

--
-- RESET FUNCTIONS
--

function resetInit()
	function resetCombatantInit(nodeCT)
		DB.setValue(nodeCT, "initresult", "number", 0);
		DB.setValue(nodeCT, "immediate", "number", 0);
		-- KEL
		DB.setValue(nodeEntry, "aoo", "number", 0);
		--End
	end
	CombatManager.callForEachCombatant(resetCombatantInit);
end

function clearExpiringEffects(bShort)
	function checkEffectExpire(nodeEffect, bShort)
		local sLabel = DB.getValue(nodeEffect, "label", "");
		local nDuration = DB.getValue(nodeEffect, "duration", 0);
		local sApply = DB.getValue(nodeEffect, "apply", "");
		
		if nDuration ~= 0 or sApply ~= "" or sLabel == "" then
			if bShort then
				if nDuration > 50 then
					DB.setValue(nodeEffect, "duration", "number", nDuration - 50);
				else
					nodeEffect.delete();
				end
			else
				nodeEffect.delete();
			end
		end
	end
	
	-- KEL !STRAIN-INJURY! --
	for _, vChild in pairs(DB.getChildren(CombatManager.CT_LIST)) do

        -- A short rest clears all strain, which is represented by the 'wounds' field.
        DB.setValue(vChild, "wounds", "number", 0);
	end
	-- END !STRAIN-INJURY! --
	
	CombatManager.callForEachCombatantEffect(checkEffectExpire, bShort);
end

function rest(bShort)
	CombatManager.resetInit();
	clearExpiringEffects(bShort);
	
	if not bShort then
		for _,v in pairs(CombatManager.getCombatantNodes()) do
			local sClass, sRecord = DB.getValue(v, "link", "", "");
			if sClass == "charsheet" and sRecord ~= "" then
				local nodePC = DB.findNode(sRecord);
				if nodePC then
					CharManager.rest(nodePC);
				end
			end
		end
	else -- KEL Adding short rest reset
		for _,v in pairs(CombatManager.getCombatantNodes()) do
			local sClass, sRecord = DB.getValue(v, "link", "", "");
			if sClass == "charsheet" and sRecord ~= "" then
				local nodePC = DB.findNode(sRecord);
				if nodePC then
					SpellManager.resetShortSpells(nodePC);
				end
			end
		end
	end
end

function rollEntryInit(nodeEntry)
	if not nodeEntry then
		return;
	end
	
	-- Start with the base initiative bonus
	local nInit = DB.getValue(nodeEntry, "init", 0);
	
	-- Get any effect modifiers
	local rActor = ActorManager.resolveActor(nodeEntry);
	local bEffects, aEffectDice, nEffectMod = ActionInit.getEffectAdjustments(rActor);
	if bEffects then
		nInit = nInit + StringManager.evalDice(aEffectDice, nEffectMod);
	end
	
	-- KEL FFOS
	local nCurrent = DB.getValue("combattracker.round", 0);
	local sOptFFOS = OptionsManager.getOption("FFOS");
	local bHasUncDodge = false;
	if (sOptFFOS == "on") and (nCurrent == 0) then
		local sSourceType, nodeSource = ActorManager.getTypeAndNode(rActor);
		if sSourceType == "pc" then
			for _,v in pairs(DB.getChildren(nodeSource, "specialabilitylist")) do
				local sAbilityname = string.lower(DB.getValue(v, "name", ""));
				if string.match(sAbilityname, "improved uncanny dodge") or string.match(sAbilityname, "uncanny dodge") then
					bHasUncDodge = true;
				end
			end
		else
			local sAbilityname = string.lower(DB.getValue(nodeSource, "specialqualities", ""));
			if string.match(sAbilityname, "improved uncanny dodge") or string.match(sAbilityname, "uncanny dodge") then
				bHasUncDodge = true;
			end
		end
	end
	-- END
	
	-- For PCs, we always roll unique initiative
	local sClass, sRecord = DB.getValue(vChild, "link", "", "");
	if sClass == "charsheet" then
		local nInitResult = math.random(20) + nInit;
		DB.setValue(nodeEntry, "initresult", "number", nInitResult);
		-- KEL FFOS
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 0 }, false);
			end
		end
		-- END
		return;
	end
	
	-- For NPCs, if NPC init option is not group, then roll unique initiative
	local sOptINIT = OptionsManager.getOption("INIT");
	if sOptINIT ~= "group" then
		local nInitResult = math.random(20) + nInit;
		DB.setValue(nodeEntry, "initresult", "number", nInitResult);
		-- KEL FFOS
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
			end
		end
		-- END
		return;
	end

	-- For NPCs with group option enabled
	
	-- Get the entry's database node name and creature name
	local sStripName = CombatManager.stripCreatureNumber(DB.getValue(nodeEntry, "name", ""));
	if sStripName == "" then
		local nInitResult = math.random(20) + nInit;
		DB.setValue(nodeEntry, "initresult", "number", nInitResult);
		-- KEL FFOS
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
			end
		end
		-- END
		return;
	end
		
	-- Iterate through list looking for other creature's with same name
	local nLastInit = nil;
	local sEntryFaction = DB.getValue(nodeEntry, "friendfoe", "");
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		if v.getName() ~= nodeEntry.getName() then
			if DB.getValue(v, "friendfoe", "") == sEntryFaction then
				local sTemp = CombatManager.stripCreatureNumber(DB.getValue(v, "name", ""));
				if sTemp == sStripName then
					local nChildInit = DB.getValue(v, "initresult", 0);
					if nChildInit ~= -10000 then
						nLastInit = nChildInit;
					end
				end
			end
		end
	end
	
	-- If we found similar creatures, then match the initiative of the last one found
	if nLastInit then
		DB.setValue(nodeEntry, "initresult", "number", nLastInit);
		-- KEL FFOS
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nLastInit, nGMOnly = 1 }, false);
			end
		end
		-- END
	else
		local nInitResult = math.random(20) + nInit;
		DB.setValue(nodeEntry, "initresult", "number", nInitResult);
		-- KEL FFOS
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
			end
		end
		-- END
	end
end

function rollInit(sType)
	CombatManager.rollTypeInit(sType, rollEntryInit);
end

--
-- PARSE CT ATTACK LINE
--

function parseAttackLine(rActor, sLine)
	-- SETUP
	local rAttackRolls = {};
	local rDamageRolls = {};
	local rAttackCombos = {};

	-- Check the anonymous NPC attacks option
	local sOptANPC = OptionsManager.getOption("ANPC");

	-- PARSE 'OR'/'AND' PHRASES
	sLine = sLine:gsub("–", "-");
	local aPhrasesOR, aSkipOR = ActionDamage.decodeAndOrClauses(sLine);

	-- PARSE EACH ATTACK
	local nAttackIndex = 1;
	local nLineIndex = 1;
	local aCurrentCombo = {};
	local nStarts, nEnds, sAll, sAttackCount, sAttackLabel, sAttackModifier, sAttackType, nDamageStart, sDamage, nDamageEnd;
	for kOR, vOR in ipairs(aPhrasesOR) do
			
		for kAND, sAND in ipairs(vOR) do

			-- Look for the right patterns
			nStarts, nEnds, sAll, sAttackCount, sAttackLabel, sAttackModifier, sAttackType, nDamageStart, sDamage, nDamageEnd 
					= string.find(sAND, '((%+?%d*) ?([%w%s,%[%]%(%)%+%-]*) ([%+%-%d][%+%-%d/]+)([^%(]*)%(()([^%)]*)()%))');
			if not nStarts then
				nStarts, nEnds, sAll, sAttackLabel, nDamageStart, sDamage, nDamageEnd 
						= sAND:find('(([%w%s,%[%]%(%)%+%-]*)%(()([^%)]*)()%))');
				if nStarts then
					sAttackCount = "";
					sAttackModifier = "+0";
					sAttackType = "";
				end
			end
			
			-- Make sure we got a match
			if nStarts then
				local rAttack = {};
				rAttack.startpos = nLineIndex + nStarts - 1;
				rAttack.endpos = nLineIndex + nEnds;
				
				local rDamage = {};
				rDamage.startpos = nLineIndex + nDamageStart - 2;
				rDamage.endpos = nLineIndex + nDamageEnd;
				
				-- Check for implicit damage types
				local aImplicitDamageType = {};
				local aLabelWords = StringManager.parseWords(sAttackLabel:lower());
				local i = 1;
				while aLabelWords[i] do
					if aLabelWords[i] == "touch" then
						rAttack.touch = true;
					elseif aLabelWords[i] == "sonic" or aLabelWords[i] == "electricity" then
						table.insert(aImplicitDamageType, aLabelWords[i]);
						break;
					elseif aLabelWords[i] == "adamantine" or aLabelWords[i] == "silver" then
						table.insert(aImplicitDamageType, aLabelWords[i]);
					elseif aLabelWords[i] == "cold" and aLabelWords[i+1] and aLabelWords[i+1] == "iron" then
						table.insert(aImplicitDamageType, "cold iron");
						i = i + 1;
					elseif aLabelWords[i] == "holy" then
						table.insert(aImplicitDamageType, "good");
					elseif aLabelWords[i] == "unholy" then
						table.insert(aImplicitDamageType, "evil");
					elseif aLabelWords[i] == "anarchic" then
						table.insert(aImplicitDamageType, "chaotic");
					elseif aLabelWords[i] == "axiomatic" then
						table.insert(aImplicitDamageType, "lawful");
					else
						if aLabelWords[i]:sub(-1) == "s" then
							aLabelWords[i] = aLabelWords[i]:sub(1, -2);
						end
						if DataCommon.naturaldmgtypes[aLabelWords[i]] then
							table.insert(aImplicitDamageType, DataCommon.naturaldmgtypes[aLabelWords[i]]);
						elseif DataCommon.weapondmgtypes[aLabelWords[i]] then
							if type(DataCommon.weapondmgtypes[aLabelWords[i]]) == "table" then
								if aLabelWords[i-1] and DataCommon.weapondmgtypes[aLabelWords[i]][aLabelWords[i-1]] then
									table.insert(aImplicitDamageType, DataCommon.weapondmgtypes[aLabelWords[i]][aLabelWords[i-1]]);
								elseif DataCommon.weapondmgtypes[aLabelWords[i]]["*"] then
									table.insert(aImplicitDamageType, DataCommon.weapondmgtypes[aLabelWords[i]]["*"]);
								end
							else
								table.insert(aImplicitDamageType, DataCommon.weapondmgtypes[aLabelWords[i]]);
							end
						end
					end
					
					i = i + 1;
				end
				
				-- Clean up the attack count field (i.e. magical weapon bonuses up front, no attack count)
				local bMagicAttack = false;
				local bEpicAttack = false;
				local nAttackCount = 1;
				if string.sub(sAttackCount, 1, 1) == "+" then
					bMagicAttack = true;
					if sOptANPC ~= "on" then
						sAttackLabel = sAttackCount .. " " .. sAttackLabel;
					end
					local nAttackPlus = tonumber(sAttackCount) or 1;
					if nAttackPlus > 5 then
						bEpicAttack = true;
					end
				elseif #sAttackCount then
					nAttackCount = tonumber(sAttackCount) or 1;
					if nAttackCount < 1 then
						nAttackCount = 1;
					end
				end

				-- Capitalize first letter of label
				sAttackLabel = StringManager.capitalize(sAttackLabel);
				
				-- If the anonymize option is on, then remove any label text within parentheses or brackets
				if sOptANPC == "on" then
					-- Strip out label information enclosed in ()
					sAttackLabel = string.gsub(sAttackLabel, "%s?%b()", "");

					-- Strip out label information enclosed in []
					sAttackLabel = string.gsub(sAttackLabel, "%s?%b[]", "");
				end

				rAttack.label = sAttackLabel;
				rAttack.count = nAttackCount;
				rAttack.modifier = sAttackModifier or 0;
				
				rDamage.label = sAttackLabel;
				
				local bRanged = false;
				local aTypeWords = StringManager.parseWords(string.lower(sAttackType));
				for kWord, vWord in pairs(aTypeWords) do
					if vWord == "ranged" then
						bRanged = true;
					elseif vWord == "touch" then
						rAttack.touch = true;
					end
				end
				
				-- Determine attack type
				if bRanged then
					rAttack.range = "R";
					rDamage.range = "R";
					rAttack.stat = "dexterity";
				else
					rAttack.range = "M";
					rDamage.range = "M";
					rAttack.stat = "strength";
				end

				-- Determine critical information
				rAttack.crit = 20;
				nCritStart, nCritEnd, sCritThreshold = string.find(sDamage, "/(%d+)%-20");
				if sCritThreshold then
					rAttack.crit = tonumber(sCritThreshold) or 20;
					if rAttack.crit < 2 or rAttack.crit > 20 then
						rAttack.crit = 20;
					end
				end
				
				-- Determine damage clauses
				rDamage.clauses = {};

				local aClausesDamage = {};
				local nIndexDamage = 1;
				local nStartDamage, nEndDamage;
				while nIndexDamage < #sDamage do
					nStartDamage, nEndDamage = string.find(sDamage, ' plus ', nIndexDamage);
					if nStartDamage then
						table.insert(aClausesDamage, string.sub(sDamage, nIndexDamage, nStartDamage - 1));
						nIndexDamage = nEndDamage;
					else
						table.insert(aClausesDamage, string.sub(sDamage, nIndexDamage));
						nIndexDamage = #sDamage;
					end
				end

				for kClause, sClause in pairs(aClausesDamage) do
					local aDamageAttrib = StringManager.split(sClause, "/", true);
					
					local aWordType = {};
					local sDamageRoll, sDamageTypes = string.match(aDamageAttrib[1], "^([d%d%+%-%s]+)([%w%s,]*)");
					if sDamageRoll then
						if sDamageTypes then
							if string.match(sDamageTypes, " and ") then
								sDamageTypes = string.gsub(sDamageTypes, " and .*$", "");
							end
							table.insert(aWordType, sDamageTypes);
						end
						
						local sCrit;
						for nAttrib = 2, #aDamageAttrib do
							sCrit, sDamageTypes = string.match(aDamageAttrib[nAttrib], "^x(%d)([%w%s,]*)");
							if not sCrit then
								sDamageTypes = string.match(aDamageAttrib[nAttrib], "^%d+%-20%s?([%w%s,]*)");
							end
							
							if sDamageTypes then
								table.insert(aWordType, sDamageTypes);
							end
						end
						
						local aWordDice, nWordMod = StringManager.convertStringToDice(sDamageRoll);
						if #aWordDice > 0 or nWordMod ~= 0 then
							local rDamageClause = { dice = {} };
							for kDie, vDie in ipairs(aWordDice) do
								table.insert(rDamageClause.dice, vDie);
							end
							rDamageClause.modifier = nWordMod;

							if kClause == 1 then
								rDamageClause.mult = 2;
							else
								rDamageClause.mult = 1;
							end
							rDamageClause.mult = tonumber(sCrit) or rDamageClause.mult;
							
							if not bRanged then
								rDamageClause.stat = "strength";
							end

							local aDamageType = ActionDamage.getDamageTypesFromString(table.concat(aWordType, ","));
							if #aDamageType == 0 then
								for kType, sType in ipairs(aImplicitDamageType) do
									table.insert(aDamageType, sType);
								end
							end
							if bMagicAttack then
								table.insert(aDamageType, "magic");
							end
							if bEpicAttack then
								table.insert(aDamageType, "epic");
							end
							rDamageClause.dmgtype = table.concat(aDamageType, ",");
							
							table.insert(rDamage.clauses, rDamageClause);
						end
					end
				end
				
				if #(rDamage.clauses) > 0 then
					if bRanged then
						local nDmgBonus = rDamage.clauses[1].modifier;
						if nDmgBonus > 0 then
							local nStatBonus = ActorManager35E.getAbilityBonus(rActor, "strength");
							if (nDmgBonus >= nStatBonus) then
								rDamage.statmult = 1;
							end
						end
					else
						local nDmgBonus = rDamage.clauses[1].modifier;
						local nStatBonus = ActorManager35E.getAbilityBonus(rActor, "strength");
						
						if (nStatBonus > 0) and (nDmgBonus > 0) then
							if nDmgBonus >= math.floor(nStatBonus * 1.5) then
								rDamage.statmult = 1.5;
							elseif nDmgBonus >= nStatBonus then
								rDamage.statmult = 1;
							else
								rDamage.statmult = 0.5;
							end
						elseif (nStatBonus == 1) and (nDmgBonus == 0) then
							rDamage.statmult = 0.5;
						end
					end
				end

				-- Add to roll list
				table.insert(rAttackRolls, rAttack);
				table.insert(rDamageRolls, rDamage);

				-- Add to combo
				table.insert(aCurrentCombo, nAttackIndex);
				nAttackIndex = nAttackIndex + 1;
			end

			nLineIndex = nLineIndex + #sAND;
			nLineIndex = nLineIndex + aSkipOR[kOR][kAND];
		end

		-- Finish combination
		if #aCurrentCombo > 0 then
			table.insert(rAttackCombos, aCurrentCombo);
			aCurrentCombo = {};
		end
	end
	
	return rAttackRolls, rDamageRolls, rAttackCombos;
end

--
--	XP FUNCTIONS
--

function getCRFromXP(nXP)
	local nCR = 0;
	if nXP > 0 then
		if nXP <= 50 then
			nCR = 0.125;
		elseif nXP <= 65 then
			nCR = 0.166;
		elseif nXP <= 100 then
			nCR = 0.25;
		elseif nXP <= 135 then
			nCR = 0.333;
		elseif nXP <= 200 then
			nCR = 0.5;
		elseif nXP <= 400 then
			nCR = 1;
		elseif nXP <= 600 then
			nCR = 2;
		elseif nXP <= 800 then
			nCR = 3;
		elseif nXP <= 1200 then
			nCR = 4;
		elseif nXP <= 1600 then
			nCR = 5;
		elseif nXP <= 2400 then
			nCR = 6;
		elseif nXP <= 3200 then
			nCR = 7;
		elseif nXP <= 4800 then
			nCR = 8;
		elseif nXP <= 6400 then
			nCR = 9;
		elseif nXP <= 9600 then
			nCR = 10;
		elseif nXP <= 12800 then
			nCR = 11;
		elseif nXP <= 19200 then
			nCR = 12;
		elseif nXP <= 25600 then
			nCR = 13;
		elseif nXP <= 38400 then
			nCR = 14;
		elseif nXP <= 51200 then
			nCR = 15;
		elseif nXP <= 76800 then
			nCR = 16;
		elseif nXP <= 102400 then
			nCR = 17;
		elseif nXP <= 153600 then
			nCR = 18;
		elseif nXP <= 204800 then
			nCR = 19;
		elseif nXP <= 307200 then
			nCR = 20;
		elseif nXP <= 409600 then
			nCR = 21;
		elseif nXP <= 614400 then
			nCR = 22;
		elseif nXP <= 819200 then
			nCR = 23;
		elseif nXP <= 1228800 then
			nCR = 24;
		elseif nXP <= 1638400 then
			nCR = 25;
		elseif nXP <= 2457600 then
			nCR = 26;
		elseif nXP <= 3276800 then
			nCR = 27;
		elseif nXP <= 4915200 then
			nCR = 28;
		elseif nXP <= 6553600 then
			nCR = 29;
		elseif nXP <= 9830400 then
			nCR = 30;
		else
			nCR = 31;
		end
	end
	return nCR;
end

function getXPFromCR(nCR)
	local nXP = 0;
	if nCR > 0 then
		if nCR <= 0.125 then
			nXP = 50;
		elseif nCR <= 0.167 then
			nXP = 65;
		elseif nCR <= 0.25 then
			nXP = 100;
		elseif nCR <= 0.334 then
			nXP = 135;
		elseif nCR <= 0.5 then
			nXP = 200;
		elseif nCR <= 1 then
			nXP = 400;
		elseif nCR <= 2 then
			nXP = 600;
		elseif nCR <= 3 then
			nXP = 800;
		elseif nCR <= 4 then
			nXP = 1200;
		elseif nCR <= 5 then
			nXP = 1600;
		elseif nCR <= 6 then
			nXP = 2400;
		elseif nCR <= 7 then
			nXP = 3200;
		elseif nCR <= 8 then
			nXP = 4800;
		elseif nCR <= 9 then
			nXP = 6400;
		elseif nCR <= 10 then
			nXP = 9600;
		elseif nCR <= 11 then
			nXP = 12800;
		elseif nCR <= 12 then
			nXP = 19200;
		elseif nCR <= 13 then
			nXP = 25600;
		elseif nCR <= 14 then
			nXP = 38400;
		elseif nCR <= 15 then
			nXP = 51200;
		elseif nCR <= 16 then
			nXP = 76800;
		elseif nCR <= 17 then
			nXP = 102400;
		elseif nCR <= 18 then
			nXP = 153600;
		elseif nCR <= 19 then
			nXP = 204800;
		elseif nCR <= 20 then
			nXP = 307200;
		elseif nCR <= 21 then
			nXP = 409600;
		elseif nCR <= 22 then
			nXP = 614400;
		elseif nCR <= 23 then
			nXP = 819200;
		elseif nCR <= 24 then
			nXP = 1228800;
		elseif nCR <= 25 then
			nXP = 1638400;
		elseif nCR <= 26 then
			nXP = 2457600;
		elseif nCR <= 27 then
			nXP = 3276800;
		elseif nCR <= 28 then
			nXP = 4915200;
		elseif nCR <= 29 then
			nXP = 6553600;
		else
			nXP = 9830400;
		end
	end
	return nXP;
end

function calcBattleXP(nodeBattle)
	local bPFMode = DataCommon.isPFRPG();
	
	if bPFMode then
		local sTargetNPCList = LibraryData.getCustomData("battle", "npclist") or "npclist";

		local nXP = 0;
		for _, vNPCItem in pairs(DB.getChildren(nodeBattle, sTargetNPCList)) do
			local sClass, sRecord = DB.getValue(vNPCItem, "link", "", "");
			if sRecord ~= "" then
				local nodeNPC = DB.findNode(sRecord);
				if nodeNPC then
					local nXPNPC = getXPFromCR(DB.getValue(nodeNPC, "cr", 0));
					if nXPNPC >= 0 then
						nXP = nXP + (DB.getValue(vNPCItem, "count", 0) * nXPNPC);
					else
						local sMsg = string.format(Interface.getString("enc_message_refreshxp_missingnpcxp"), DB.getValue(vNPCItem, "name", ""));
						ChatManager.SystemMessage(sMsg);
					end
				else
					local sMsg = string.format(Interface.getString("enc_message_refreshxp_missingnpclink"), DB.getValue(vNPCItem, "name", ""));
					ChatManager.SystemMessage(sMsg);
				end
			end
		end
		
		DB.setValue(nodeBattle, "exp", "number", nXP);
	end
end
	
function calcBattleCR(nodeBattle)
	local bPFMode = DataCommon.isPFRPG();
	
	if bPFMode then
		calcBattleXP(nodeBattle);

		local nXP = DB.getValue(nodeBattle, "exp", 0);
		local nCR = getCRFromXP(nXP);
		DB.setValue(nodeBattle, "level", "number", nCR);
	end
end

--
--	COMBAT ACTION FUNCTIONS
--

function addRightClickDiceToClauses(rRoll)
	if #rRoll.clauses > 0 then
		local nOrigDamageDice = 0;
		for _,vClause in ipairs(rRoll.clauses) do
			nOrigDamageDice = nOrigDamageDice + #vClause.dice;
		end
		if #rRoll.aDice > nOrigDamageDice then
			local v = rRoll.clauses[#rRoll.clauses].dice;
			for i = nOrigDamageDice + 1,#rRoll.aDice do
				if type(rRoll.aDice[i]) == "table" then
					table.insert(rRoll.clauses[1].dice, rRoll.aDice[i].type);
				else
					table.insert(rRoll.clauses[1].dice, rRoll.aDice[i]);
				end
			end
		end
	end
end
