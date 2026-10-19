-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	CombatManager.setCustomSort(CombatManager.sortfuncDnD);

	CombatManager.setCustomRoundStart(onRoundStart);
	-- CombatManager.setCustomTurnStart(onTurnStart);
	CombatManager.setCustomTurnEnd(onTurnEnd);
	CombatManager.setCustomCombatReset(resetInit);
	
	ActorCommonManager.setDefaultSpaceReachFromActorSizeKey("D20");
	ActorCommonManager.setRecordTypeSpaceReachCallback("charsheet", ActorCommonManager.getSpaceReachFromSizeFieldCore);
	ActorCommonManager.setRecordTypeSpaceReachCallback("npc", ActorCommonManager.getSpaceReachDnD3Legacy);
	CombatRecordManager.setRecordTypePostAddCallback("npc", onNPCPostAdd);
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
				if not EffectManager.hasCondition(rActor, "Stable") then
					ActionDamage.performStabilizationRoll(rActor);
				end
			end
		end
	end
end

--
-- ADD FUNCTIONS
--
-- KEL for NPC parsing
function tableConcat(origTable, addTable)
	for _,v in pairs(addTable) do
		if not(StringManager.contains(origTable, v)) then
			table.insert(origTable, v)
		end
	end
end
-- END
function onNPCPostAdd(tCustom)
	-- Parameter validation
	if not tCustom.nodeRecord or not tCustom.nodeCT then
		return;
	end

	-- Setup
	local bPFMode = DataCommon.isPFRPG();
	local nodeNPC = tCustom.nodeRecord;
	
	-- KEL for IFTAG SIMMUNE parsing
	local sIftagcomp = {};
	-- END
	
	-- HD
	local sHDField = DB.getValue(nodeNPC, "hd", "");
	local nHDFieldSemiColon = sHDField:find(";");
	local sHD, sPostHDHealthProps;
	if nHDFieldSemiColon then
		sHD = StringManager.trim(sHDField:sub(1, nHDFieldSemiColon - 1));
		sPostHDHealthProps = StringManager.trim(sHDField:sub(nHDFieldSemiColon + 1));
	else
		sHD = StringManager.trim(sHDField);
	end
	
	-- HP
	local sOptHRNH = OptionsManager.getOption("HRNH");
	local nHP = DB.getValue(nodeNPC, "hp", 0);
	local sHD = StringManager.trim(DB.getValue(nodeNPC, "hd", ""));
	if sOptHRNH == "max" and sHD ~= "" then
		nHP = StringManager.evalDiceString(sHD, true, true);
	elseif sOptHRNH == "random" and sHD ~= "" then
		nHP = math.max(StringManager.evalDiceString(sHD, true), 1);
	end
	DB.setValue(tCustom.nodeCT, "hp", "number", nHP);

	-- Defensive properties
	local sAC = DB.getValue(nodeNPC, "ac", "10");
	DB.setValue(tCustom.nodeCT, "ac_final", "number", tonumber(string.match(sAC, "^(%d+)")) or 10);
	DB.setValue(tCustom.nodeCT, "ac_touch", "number", tonumber(string.match(sAC, "touch (%d+)")) or 10);
	local sFlatFooted = string.match(sAC, "flat[%-–]footed (%d+)");
	if not sFlatFooted then
		sFlatFooted = string.match(sAC, "flatfooted (%d+)");
	end
	DB.setValue(tCustom.nodeCT, "ac_flatfooted", "number", tonumber(sFlatFooted) or 10);
	
	-- Handle BAB / Grapple / CM Field
	local sBABGrp = DB.getValue(nodeNPC, "babgrp", "");
	local aSplitBABGrp = StringManager.split(sBABGrp, "/", true);
	
	local sMatch = string.match(sBABGrp, "CMB ([+-]%d+)");
	if sMatch then
		DB.setValue(tCustom.nodeCT, "grapple", "number", tonumber(sMatch) or 0);
	else
		if aSplitBABGrp[2] then
			DB.setValue(tCustom.nodeCT, "grapple", "number", tonumber(aSplitBABGrp[2]) or 0);
		end
	end

	sMatch = string.match(sBABGrp, "CMD ([+-]?%d+)");
	if sMatch then
		DB.setValue(tCustom.nodeCT, "cmd", "number", tonumber(sMatch) or 0);
	else
		if aSplitBABGrp[3] then
			DB.setValue(tCustom.nodeCT, "cmd", "number", tonumber(aSplitBABGrp[3]) or 0);
		end
	end

	-- Offensive properties
	local nodeAttacks = DB.createChild(tCustom.nodeCT, "attacks");
	if nodeAttacks then
		DB.deleteChildren(nodeAttacks);
		
		local nAttacks = 0;
		
		local sAttack = DB.getValue(nodeNPC, "atk", "");
		if sAttack ~= "" then
			local nodeValue = DB.createChild(nodeAttacks);
			if nodeValue then
				DB.setValue(nodeValue, "value", "string", sAttack);
				nAttacks = nAttacks + 1;
			end
		end
		
		local sFullAttack = DB.getValue(nodeNPC, "fullatk", "");
		if sFullAttack ~= "" then
			nodeValue = DB.createChild(nodeAttacks);
			if nodeValue then
				DB.setValue(nodeValue, "value", "string", sFullAttack);
				nAttacks = nAttacks + 1;
			end
		end
		
		if nAttacks == 0 then
			DB.createChild(nodeAttacks);
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
		DB.setValue(tCustom.nodeCT, "aoomax", "number", aoo);
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
			tableConcat(sIftagcomp, DataCommon2.tundeadtraits);
			-- KEL
			bRevert = true;
			-- END
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
	if bRevert and (OptionsManager.getOption("REVERT") == "on") then
		table.insert(aEffects, "REVERT: revheal");
		table.insert(aEffects, "REVERT: negative");
	end
	-- END
	
	-- DECODE SPECIAL HEALTH PROPERTIES
	if sPostHDHealthProps then
		local aSQWords = StringManager.parseWords(sPostHDHealthProps:lower());
		local i = 1;
		while aSQWords[i] do
			-- FAST HEALING
			if StringManager.isWord(aSQWords[i], "fast") and StringManager.isWord(aSQWords[i+1], { "healing", "heal" }) then
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
						EffectManager.addEffect("", "", tCustom.nodeCT, { sName = sRegenEffect, nDuration = 0, nGMOnly = 1 }, false);
					else
						table.insert(aEffects, sRegenEffect);
					end
				end
			end

			i = i + 1;
		end
	end

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
				DB.setValue(tCustom.nodeCT, "sr", "number", tonumber(aSQWords[i]) or 0);
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
					EffectManager.addEffect("", "", tCustom.nodeCT, { sName = sRegenEffect, nDuration = 0, nGMOnly = 1 }, false);
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
		local sIftagcompCheck = {};
		local sIftagcompRed = {};

		for _,v in ipairs(sIftagcomp) do
		   if (not sIftagcompCheck[v]) then
			   sIftagcompRed[#sIftagcompRed+1] = v;
			   sIftagcompCheck[v] = true;
		   end
		end
		sTags = table.concat(sIftagcompRed, ", ");
		
		table.insert(aEffects, "IFTAG: " .. sTags);
		table.insert(aEffects, "SIMMUNE");
	end
	-- END
	
	-- ADD DECODED EFFECTS
	if #aEffects > 0 then
		EffectManager.addEffect("", "", tCustom.nodeCT, { sName = table.concat(aEffects, "; "), nDuration = 0, nGMOnly = 1 }, false);
	end

	-- Roll initiative and sort
	CombatRecordManager.handleCombatAddInitDnD(tCustom);
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
		
		if nDuration ~= 0 or sLabel == "" then
			if bShort and (nDuration > 50) then
				DB.setValue(nodeEffect, "duration", "number", nDuration - 50);
			else
				DB.deleteNode(nodeEffect);
			end
		end
	end
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
