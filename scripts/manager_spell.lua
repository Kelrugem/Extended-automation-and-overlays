-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

-- Reset power points and individual spells cast
-- KEL adding nomnom and short rest reset (also some change in manager_combat2 stored in _combat3)
function resetSpells(nodeCaster)
	for _,nodeSpellClass in pairs(DB.getChildren(nodeCaster, "spellset")) do
		DB.setValue(nodeSpellClass, "pointsused", "number", 0);
		
		for _,nodeLevel in pairs(DB.getChildren(nodeSpellClass, "levels")) do
			for _,nodeSpell in pairs(DB.getChildren(nodeLevel, "spells")) do
				local sleep = true;
				-- KEL Beware the actions of one spell contain all actions, also damage and over casts and so on
				for _,nodeAction in pairs(DB.getChildren(nodeSpell, "actions")) do
					local resetdef = DB.getValue(nodeAction, "usereset", "");
					if resetdef == "consumable" then
						sleep = false;
					end
				end
				if sleep then
					DB.setValue(nodeSpell, "cast", "number", 0);
				end
			end
		end
	end
end

function resetShortSpells(nodeCaster)
	for _,nodeSpellClass in pairs(DB.getChildren(nodeCaster, "spellset")) do
		-- DB.setValue(nodeSpellClass, "pointsused", "number", 0);
		
		for _,nodeLevel in pairs(DB.getChildren(nodeSpellClass, "levels")) do
			for _,nodeSpell in pairs(DB.getChildren(nodeLevel, "spells")) do
				local sleep = false;
				-- KEL Beware the actions of one spell contain all actions, also damage and other casts and so on
				for _,nodeAction in pairs(DB.getChildren(nodeSpell, "actions")) do
					local resetdef = DB.getValue(nodeAction, "usereset", "");
					if resetdef == "shortrest" then
						sleep = true;
					end
				end
				if sleep then
					DB.setValue(nodeSpell, "cast", "number", 0);
				end
			end
		end
	end
end

-- END

-- Iterate through each spell to reset
function resetPrepared(nodeCaster)
	for _,nodeSpellClass in pairs(DB.getChildren(nodeCaster, "spellset")) do
		for _,nodeLevel in pairs(DB.getChildren(nodeSpellClass, "levels")) do
			for _,nodeSpell in pairs(DB.getChildren(nodeLevel, "spells")) do
				DB.setValue(nodeSpell, "prepared", "number", 0);
			end
		end
	end
end

function convertSpellDescToFormattedText(nodeSpell)
	local nodeDesc = nodeSpell.getChild("description");
	if nodeDesc then
		local sDescType = nodeDesc.getType();
		if sDescType == "string" then
			local sValue = "<p>" .. nodeDesc.getValue() .. "</p>";
			sValue = sValue:gsub("\r", "</p><p>");

			local nodeLinkedSpells = nodeSpell.getChild("linkedspells");
			if nodeLinkedSpells then
				if nodeLinkedSpells.getChildCount() > 0 then
					sValue = sValue .. "<linklist>";
					for _,v in pairs(nodeLinkedSpells.getChildren()) do
						local sLinkName = DB.getValue(v, "linkedname", "");
						local sLinkClass, sLinkRecord = DB.getValue(v, "link", "", "");
						sValue = sValue .. "<link class=\"" .. sLinkClass .. "\" recordname=\"" .. sLinkRecord .. "\">" .. sLinkName .. "</link>";
					end
					sValue = sValue .. "</linklist>";
				end
			end

			nodeDesc.delete();
			DB.setValue(nodeSpell, "description", "formattedtext", sValue);
		end
	end
end

function convertSpellDescToString(nodeSpell)
	local nodeDesc = nodeSpell.getChild("description");
	if nodeDesc then
		local sDescType = nodeDesc.getType();
		if sDescType == "formattedtext" then
			local sDesc = nodeDesc.getText();
			local sValue = nodeDesc.getValue();

			nodeDesc.delete();
			DB.setValue(nodeSpell, "description", "string", sDesc);
			
			local nodeLinkedSpells = nodeSpell.createChild("linkedspells");
			if nodeLinkedSpells then
				local nIndex = 1;
				local nLinkStartB, nLinkStartE, sClass, sRecord = string.find(sValue, "<link class=\"([^\"]*)\" recordname=\"([^\"]*)\">", nIndex);
				while nLinkStartB and sClass and sRecord do
					local nLinkEndB, nLinkEndE = string.find(sValue, "</link>", nLinkStartE + 1);
					
					if nLinkEndB then
						local sText = string.sub(sValue, nLinkStartE + 1, nLinkEndB - 1);
						
						local nodeLink = nodeLinkedSpells.createChild();
						if nodeLink then
							DB.setValue(nodeLink, "link", "windowreference", sClass, sRecord);
							DB.setValue(nodeLink, "linkedname", "string", sText);
						end
						
						nIndex = nLinkEndE + 1;
						nLinkStartB, nLinkStartE, sClass, sRecord = string.find(sValue, "<link class=\"([^\"]*)\" recordname=\"([^\"]*)\">", nIndex);
					else
						nLinkStartB = nil;
					end
				end
			end
		end
	end
end

function addSpell(nodeSource, nodeSpellClass, nLevel)
	-- Validate
	if not nodeSource or not nodeSpellClass or not nLevel then
		return nil;
	end
	
	-- Create the new spell entry
	local nodeTargetLevelSpells = nodeSpellClass.getChild("levels.level" .. nLevel .. ".spells");
	if not nodeTargetLevelSpells then
		return nil;
	end
	local nodeNewSpell = nodeTargetLevelSpells.createChild();
	-- KEL Hier eventuell schon ansetzen für tagparser?
	if not nodeNewSpell then
		return nil;
	end
	
	-- Copy the spell details over
	DB.copyNode(nodeSource, nodeNewSpell);
	
	-- Convert the description field from module data
	local nodeNewSpellDesc = nodeNewSpell.getChild("description");
	convertSpellDescToString(nodeNewSpell);
	nodeNewSpellDesc = nodeNewSpell.getChild("description");

	local nodeParent = nodeTargetLevelSpells.getParent();
	if nodeParent then
		-- Set the default cost for points casters
		local nCost = tonumber(string.sub(nodeParent.getName(), -1)) or 0;
		if nCost > 0 then
			nCost = ((nCost - 1) * 2) + 1;
		end
		DB.setValue(nodeNewSpell, "cost", "number", nCost);

		-- If spell level not visible, then make it so.
		local sAvailablePath = "....available" .. nodeParent.getName();
		local nAvailable = DB.getValue(nodeTargetLevelSpells, sAvailablePath, 1);
		if nAvailable <= 0 then
			DB.setValue(nodeTargetLevelSpells, sAvailablePath, "number", 1);
		end
	end
	
	-- Parse spell details to create actions
	-- KEL Here tag parsing separate such that it is always parsed? Ursprüngliche tags mitnehmen? Mit Option?
	if DB.getChildCount(nodeNewSpell, "actions") == 0 then
		parseSpell(nodeNewSpell);
	else
		local nodeActions = nodeNewSpell.createChild("actions");
		if nodeActions then
			local nodeAction = nodeActions.getChildren();
			if nodeAction then
				for k, v in pairs(nodeAction) do
					if DB.getValue(v, "type") == "cast" then
						addTags(nodeNewSpell, v);
					end
				end
			end
		end
	end
	
	return nodeNewSpell;
end

--KEL use this function later in parseSpell, too. But now in test mode, so, not used there yet
function addTags(nodeSpell, nodeAction)
	local sSchool = DB.getValue(nodeSpell, "school", ""):lower();
	local tagnames = StringManager.parseWords(sSchool);
	local tags = DB.getValue(nodeAction, "othertags", "");
	local tagslist = StringManager.parseWords(tags);
	local i = 1;
	local semicolon = "; ";
	
	local sSave = DB.getValue(nodeSpell, "save", ""):lower();
	local sSR = DB.getValue(nodeSpell, "sr", ""):lower();
	
	if sSchool:match("^abjuration") then
		DB.setValue(nodeAction, "school", "string", "abjuration");
	elseif sSchool:match("^conjuration") then
		DB.setValue(nodeAction, "school", "string", "conjuration");
	elseif sSchool:match("^divination") then
		DB.setValue(nodeAction, "school", "string", "divination");	
	elseif sSchool:match("^enchantment") then
		DB.setValue(nodeAction, "school", "string", "enchantment");
	elseif sSchool:match("^evocation") then
		DB.setValue(nodeAction, "school", "string", "evocation");
	elseif sSchool:match("^illusion") then
		DB.setValue(nodeAction, "school", "string", "illusion");
	elseif sSchool:match("^necromancy") then
		DB.setValue(nodeAction, "school", "string", "necromancy");
	elseif sSchool:match("^transmutation") then
		DB.setValue(nodeAction, "school", "string", "transmutation");
	elseif sSchool:match("^universal") then
		DB.setValue(nodeAction, "school", "string", "universal");
	end
	-- KEL security space since I do not know how people write there tags
	if tags ~= "" then
		tags = tags .. " ";
	end
	
	while tagnames[i] do
		if not StringManager.isWord(tagnames[i], "abjuration") and not StringManager.isWord(tagnames[i], "conjuration") and not StringManager.isWord(tagnames[i], "divination") and not StringManager.isWord(tagnames[i], "enchantment") and not StringManager.isWord(tagnames[i], "evocation") and not StringManager.isWord(tagnames[i], "illusion") and not StringManager.isWord(tagnames[i], "necromancy") and not StringManager.isWord(tagnames[i], "transmutation") and not StringManager.isWord(tagnames[i], "universal") and not StringManager.isWord(tagnames[i], "language-dependent") and not StringManager.isWord(tagnames[i], "mind-affecting") then
			if not StringManager.contains(tagslist, tagnames[i]) then
				tags = tags .. tagnames[i] .. semicolon;
			end
		end
		
		if StringManager.isWord(tagnames[i], "language-dependent") then
			if not StringManager.contains(tagslist, tagnames[i]) then
				tags = tags .. "languagedependent" .. semicolon;
			end
		end
		
		if StringManager.isWord(tagnames[i], "mind-affecting") then
			if not StringManager.contains(tagslist, tagnames[i]) then
				tags = tags .. "mindaffecting" .. semicolon;
			end
		end
		
		i = i + 1;
	end
	
	local nLevel = DB.getValue(nodeAction, ".....level", 0);
	
	if nLevel == 0 then
		if not StringManager.contains(tagslist, "zero") then
			tags = tags .. "zero" .. semicolon;
		end
	elseif nLevel == 1 then
		if not StringManager.contains(tagslist, "one") then
			tags = tags .. "one" .. semicolon;
		end
	elseif nLevel == 2 and not StringManager.contains(tagslist, "two") then
		tags = tags .. "two" .. semicolon;
	elseif nLevel == 3 and not StringManager.contains(tagslist, "three") then
		tags = tags .. "three" .. semicolon;
	elseif nLevel == 4 and not StringManager.contains(tagslist, "four") then
		tags = tags .. "four" .. semicolon;
	elseif nLevel == 5 and not StringManager.contains(tagslist, "five") then
		tags = tags .. "five" .. semicolon;
	elseif nLevel == 6 and not StringManager.contains(tagslist, "six") then
		tags = tags .. "six" .. semicolon;
	elseif nLevel == 7 and not StringManager.contains(tagslist, "seven") then
		tags = tags .. "seven" .. semicolon;
	elseif nLevel == 8 and not StringManager.contains(tagslist, "eight") then
		tags = tags .. "eight" .. semicolon;
	elseif nLevel == 9 and not StringManager.contains(tagslist, "nine") then
		tags = tags .. "nine" .. semicolon;
	end
	
	if DB.getValue(nodeAction, "stype", "") == "" then
		DB.setValue(nodeAction, "stype", "string", "spell");
	end
	
	if sSave:match("harmless") or sSR:match("harmless") then
		if not StringManager.contains(tagslist, "harmless") then
			tags = tags .. "harmless" .. semicolon;
		end
	end
	if sSave:match("object") or sSR:match("object")  and not StringManager.contains(tagslist, "object") then
		tags = tags .. "object" .. semicolon;
	end
	if sSave:match("disbelief")  and not StringManager.contains(tagslist, "disbelief") then
		tags = tags .. "disbelief" .. semicolon;
	end
	
	DB.setValue(nodeAction, "othertags", "string", tags);
end
-- END

function addSpellCastAction(nodeSpell)
	local nodeActions = nodeSpell.createChild("actions");
	if not nodeActions then
		return nil;
	end
	local nodeAction = nodeActions.createChild();
	if not nodeAction then
		return nil;
	end

	DB.setValue(nodeAction, "type", "string", "cast");
	
	-- KEL Automatic parsing for spell tags
	
	local sSchool = DB.getValue(nodeSpell, "school", ""):lower();
	
	if sSchool:match("^abjuration") then
		DB.setValue(nodeAction, "school", "string", "abjuration");
	elseif sSchool:match("^conjuration") then
		DB.setValue(nodeAction, "school", "string", "conjuration");
	elseif sSchool:match("^divination") then
		DB.setValue(nodeAction, "school", "string", "divination");	
	elseif sSchool:match("^enchantment") then
		DB.setValue(nodeAction, "school", "string", "enchantment");
	elseif sSchool:match("^evocation") then
		DB.setValue(nodeAction, "school", "string", "evocation");
	elseif sSchool:match("^illusion") then
		DB.setValue(nodeAction, "school", "string", "illusion");
	elseif sSchool:match("^necromancy") then
		DB.setValue(nodeAction, "school", "string", "necromancy");
	elseif sSchool:match("^transmutation") then
		DB.setValue(nodeAction, "school", "string", "transmutation");
	elseif sSchool:match("^universal") then
		DB.setValue(nodeAction, "school", "string", "universal");
	end
	-- KEL Replace stat is the one of the spell class, so "replace" :) So take its value if it's there
	DB.setValue(nodeAction, "replacedcstatmod", "number", DB.getValue(nodeAction, ".......dc.abilitymod", 0));
	
	-- Defining tagnames in the last line
	local tagnames = StringManager.parseWords(sSchool);
	local tags = "";
	local i = 1;
	local semicolon = "; ";
	
	while tagnames[i] do
		if not StringManager.isWord(tagnames[i], "abjuration") and not StringManager.isWord(tagnames[i], "conjuration") and not StringManager.isWord(tagnames[i], "divination") and not StringManager.isWord(tagnames[i], "enchantment") and not StringManager.isWord(tagnames[i], "evocation") and not StringManager.isWord(tagnames[i], "illusion") and not StringManager.isWord(tagnames[i], "necromancy") and not StringManager.isWord(tagnames[i], "transmutation") and not StringManager.isWord(tagnames[i], "universal") and not StringManager.isWord(tagnames[i], "language-dependent") and not StringManager.isWord(tagnames[i], "mind-affecting") then
			tags = tags .. tagnames[i] .. semicolon;
		end
		
		if StringManager.isWord(tagnames[i], "language-dependent") then
			tags = tags .. "languagedependent" .. semicolon;
		end
		
		if StringManager.isWord(tagnames[i], "mind-affecting") then
			tags = tags .. "mindaffecting" .. semicolon;
		end
		
		i = i + 1;
	end
	
	local nLevel = DB.getValue(nodeAction, ".....level", 0);
	
	if nLevel == 0 then
		tags = tags .. "zero" .. semicolon;
	elseif nLevel == 1 then
		tags = tags .. "one" .. semicolon;
	elseif nLevel == 2 then
		tags = tags .. "two" .. semicolon;
	elseif nLevel == 3 then
		tags = tags .. "three" .. semicolon;
	elseif nLevel == 4 then
		tags = tags .. "four" .. semicolon;
	elseif nLevel == 5 then
		tags = tags .. "five" .. semicolon;
	elseif nLevel == 6 then
		tags = tags .. "six" .. semicolon;
	elseif nLevel == 7 then
		tags = tags .. "seven" .. semicolon;
	elseif nLevel == 8 then
		tags = tags .. "eight" .. semicolon;
	elseif nLevel == 9 then
		tags = tags .. "nine" .. semicolon;
	end
	
	DB.setValue(nodeAction, "stype", "string", "spell");
	
	-- End
	
	local sSave = DB.getValue(nodeSpell, "save", ""):lower();
	
	if not sSave:match("harmless") then
		if sSave:match("^fortitude ") then
			DB.setValue(nodeAction, "savetype", "string", "fortitude");
		elseif sSave:match("^reflex ") then
			DB.setValue(nodeAction, "savetype", "string", "reflex");
		elseif sSave:match("^will ") then
			DB.setValue(nodeAction, "savetype", "string", "will");
		end
		if sSave:match("half") then
			DB.setValue(nodeAction, "onmissdamage", "string", "half");
		end
	end
	
	local sSR = DB.getValue(nodeSpell, "sr", ""):lower();
	if sSR:match("harmless") or sSR:match("^no") then
		DB.setValue(nodeAction, "srnotallowed", "number", 1);
	end
	
	-- KEL Add harmless and object as tag
	if sSave:match("harmless") or sSR:match("harmless") then
		tags = tags .. "harmless" .. semicolon;
	end
	if sSave:match("object") or sSR:match("object") then
		tags = tags .. "object" .. semicolon;
	end
	if sSave:match("disbelief") then
		tags = tags .. "disbelief" .. semicolon;
	end
	-- END
	
	-- KEL Adding tags
	DB.setValue(nodeAction, "othertags", "string", tags);
	-- END
	
	local sDesc = DB.getValue(nodeSpell, "description", ""):lower();
	if sDesc:match("ranged touch attack") then
		DB.setValue(nodeAction, "atktype", "string", "rtouch");
	elseif sDesc:match("melee touch attack") then
		DB.setValue(nodeAction, "atktype", "string", "mtouch");
	elseif sDesc:match("normal ranged attack") then
		DB.setValue(nodeAction, "atktype", "string", "ranged");
	end
	
	-- Check for custom DC in the spell name
	local sDC = DB.getValue(nodeSpell, "name", ""):lower():match("%(dc (%d+)%)");
	if sDC then
		local nCustomDC = tonumber(sDC) or 0;
		if nCustomDC > 0 then
			local nDC = getActionSaveDC(nodeAction);
			if nDC ~= nCustomDC then
				DB.setValue(nodeAction, "savedctype", "string", "fixed");
				DB.setValue(nodeAction, "savedcmod", "number", nCustomDC);
			end
		end
	end
end

function parseSpell(nodeSpell)
	-- CLean out old actions
	local nodeActions = nodeSpell.createChild("actions");
	for k, v in pairs(nodeActions.getChildren()) do
		v.delete();
	end
	
	-- Always create a cast action
	addSpellCastAction(nodeSpell);
	
	-- Get the description minos some problem characters and in lowercase
	local sDesc = string.lower(DB.getValue(nodeSpell, "description", ""));
	sDesc = string.gsub(sDesc, "’", "'");
	sDesc = string.gsub(sDesc, "–", "-");
	
	local aWords = StringManager.parseWords(sDesc);
	
	-- Damage/Heal setup
	local aDamages = {};
	local aHeals = {};

  	local i = 1;
  	while aWords[i] do
		-- Main trigger ("damage")
		if StringManager.isWord(aWords[i], "damage") then
			local j = i - 1;

			-- Get damage type
			local sDamageType = "";
			if j > 0 and StringManager.isWord(aWords[j], DataCommon.dmgtypes) then
				sDamageType = aWords[j];
				j = j - 1;
			end
			
			-- Skip "of"
			if StringManager.isWord(aWords[j], "of") then
				j = j - 1;
			end
			
			-- Get heal or damage
			local sRollType = nil;
			local sRollDice = nil;
			if StringManager.isWord(aWords[j], { "points", "point" }) then
				j = j - 1;
				
				-- Skip "hit"
				if StringManager.isWord(aWords[j], "hit") then
					j = j - 1;
				end
				
				if StringManager.isDiceString(aWords[j]) then
					sRollDice = aWords[j];

					j = j - 1;
					if StringManager.isWord(aWords[j], { "deal", "deals", "take", "takes", "dealt", "dealing", "taking", "causes" }) then
						sRollType = "damage";
					elseif StringManager.isWord(aWords[j], { "cure", "cures" }) then
						sRollType = "heal";
					elseif StringManager.isWord(aWords[j], { "damage", "and", "or" }) then
						sRollType = "damage";
					elseif StringManager.isWord(aWords[j], { "yellow", "orange", "red" }) then
						sRollType = "damage";
					end
				end
				
			end
			
			-- If we have a roll
			if sRollType and sRollDice then
				local k = i + 1;
				local bScaling = false;
				local bPointMode = false;
				local bHalfLevel = false;
				local sMaxRollDice = nil;
				
				if StringManager.isWord(aWords[k], "+1") and StringManager.isWord(aWords[k+1], "point") then
					bPointMode = true;
					k = k + 2;
				elseif StringManager.isWord(aWords[k], "+") and StringManager.isWord(aWords[k+1], "1") and StringManager.isWord(aWords[k+2], "point") then
					bPointMode = true;
					k = k + 3;
				end
				
				if StringManager.isWord(aWords[k], "per") then
					k = k + 1;
					if StringManager.isWord(aWords[k], "two") then
						k = k + 1;
						bHalfLevel = true;
					end
					if StringManager.isWord(aWords[k], "caster") then
						k = k + 1;
					end
					if StringManager.isWord(aWords[k], { "level", "levels" }) then
						k = k + 1;
						bScaling = true;
						
						if StringManager.isWord(aWords[k], "of") and StringManager.isWord(aWords[k+1], "the") and StringManager.isWord(aWords[k+2], "caster") then 
							k = k + 3;
						end
						
						if StringManager.isWord(aWords[k], "maximum") then
							sMaxRollDice = aWords[k + 1];
						elseif StringManager.isWord(aWords[k], "to") and
								StringManager.isWord(aWords[k+1], "a") and
								StringManager.isWord(aWords[k+2], "maximum") and
								StringManager.isWord(aWords[k+3], "of") then
							sMaxRollDice = aWords[k + 4];
						end
					end
				end
				
				local rRoll = {};
				rRoll.aDice, rRoll.nMod = StringManager.convertStringToDice(sRollDice);
				rRoll.sType = sDamageType;
				if bScaling then
					local sMult;
					if bHalfLevel then
						sMult = "halfcl";
					else
						sMult = "cl";
					end
					
					if bPointMode or #(rRoll.aDice) == 0 then
						rRoll.sModStat = sMult;
					else
						rRoll.sDiceStat = sMult;
					end
					
					if sMaxRollDice then
						local aMaxDice, nMaxMod = StringManager.convertStringToDice(sMaxRollDice);
						if bPointMode then
							rRoll.nMaxStat = nMaxMod;
						elseif #(rRoll.aDice) > 0 then
							rRoll.nMaxStat = math.floor(#aMaxDice / #(rRoll.aDice))
						else
							rRoll.nMaxStat = math.floor(nMaxMod / rRoll.nMod);
						end
					end
				end
				
				if sRollType == "heal" then
					table.insert(aHeals, rRoll);
				else
					table.insert(aDamages, rRoll);
				end
			end
		end
			
		-- Increment word counter
		i = i + 1;
	end	

	-- Add the Damage and Heal rolls
	for i = 1, #aDamages do
		local rRoll = aDamages[i];
		local nodeAction = DB.createChild(nodeActions);
		
		DB.setValue(nodeAction, "type", "string", "damage");
		
		local nodeDmgList = DB.createChild(nodeAction, "damagelist");
		local nodeDmgEntry = DB.createChild(nodeDmgList);

		DB.setValue(nodeDmgEntry, "dice", "dice", rRoll.aDice);
		if rRoll.sDiceStat then
			DB.setValue(nodeDmgEntry, "dicestat", "string", rRoll.sDiceStat);
			if rRoll.nMaxStat then
				DB.setValue(nodeDmgEntry, "dicestatmax", "number", rRoll.nMaxStat);
			end
		end
		
		if rRoll.sModStat then
			DB.setValue(nodeDmgEntry, "stat", "string", rRoll.sModStat);
			DB.setValue(nodeDmgEntry, "statmult", "number", 1);
			if rRoll.nMaxStat then
				DB.setValue(nodeDmgEntry, "statmax", "number", rRoll.nMaxStat);
			end
		else
			DB.setValue(nodeDmgEntry, "bonus", "number", rRoll.nMod);
		end
		
		DB.setValue(nodeDmgEntry, "type", "string", rRoll.sType);
	end
	for i = 1, #aHeals do
		local rRoll = aHeals[i];
		local nodeAction = nodeActions.createChild();
		
		DB.setValue(nodeAction, "type", "string", "heal");
		
		local nodeHealList = DB.createChild(nodeAction, "heallist");
		local nodeHealEntry = DB.createChild(nodeHealList);

		DB.setValue(nodeHealEntry, "dice", "dice", rRoll.aDice);
		if rRoll.sDiceStat then
			DB.setValue(nodeHealEntry, "dicestat", "string", rRoll.sDiceStat);
			if rRoll.nMaxStat then
				DB.setValue(nodeHealEntry, "dicestatmax", "number", rRoll.nMaxStat);
			end
		end
		
		if rRoll.sModStat then
			DB.setValue(nodeHealEntry, "stat", "string", rRoll.sModStat);
			DB.setValue(nodeHealEntry, "statmult", "number", 1);
			if rRoll.nMaxStat then
				DB.setValue(nodeHealEntry, "statmax", "number", rRoll.nMaxStat);
			end
		else
			DB.setValue(nodeHealEntry, "bonus", "number", rRoll.nMod);
		end
	end
	
	-- Effects setup
	local aEffects = {};

  	i = 1;
  	while aWords[i] do
		if StringManager.isWord(aWords[i], DataCommon.spelleffects) then
			local k = i;
			while StringManager.isWord(aWords[k + 1], DataCommon.spelleffects) or StringManager.isWord(aWords[k + 1], "and") do
				k = k + 1;
			end
			
			local bValidEffect = false;
			local j = i - 1;
			if StringManager.isWord(aWords[j], { "immediately", "only" }) then
				j = j - 1;
			end
			if StringManager.isWord(aWords[j], { "is", "are" }) then
				if not StringManager.isWord(aWords[j - 1], { "beams", "power", "that" }) then
					bValidEffect = true;
				end
			elseif StringManager.isWord(aWords[j], { "become", "becomes" }) then
				if not StringManager.isWord(aWords[j - 1], { "not", "never" }) then
					bValidEffect = true;
				end
			elseif StringManager.isWord(aWords[j], "being") then
				if not StringManager.isWord(aWords[j - 1], "as") then
					bValidEffect = true;
				end
			elseif StringManager.isWord(aWords[j], { "be", "and", "or", "then", "remains", "subject" }) then
				bValidEffect = true;
			end

			if bValidEffect then
				local rEffect = {};
				
				local aEffectWords = {};
				for z = i, k do
					if aWords[z] ~= "and" then
						local sWord = StringManager.capitalize(aWords[z]);
						table.insert(aEffectWords, sWord);
					end
				end
				
				rEffect.sName = table.concat(aEffectWords, "; ");
				
				local m = k + 1;
				if StringManager.isWord(aWords[m], "as") and
						StringManager.isWord(aWords[m + 1], "by") and
						StringManager.isWord(aWords[m + 2], "the") and
						StringManager.isWord(aWords[m + 4], "spell") then
					m = m + 5;
				end
				if StringManager.isWord(aWords[m], "for") then
					m = m + 1;
					
					if StringManager.isDiceString(aWords[m]) then
						local sDiceMod = aWords[m];
						m = m + 1;
						
						local sUnits = nil;
						if StringManager.isWord(aWords[m], { "round", "rounds" }) then
							sUnits = "";
						elseif StringManager.isWord(aWords[m], { "minute", "minutes" }) then
							sUnits = "minute";
						elseif StringManager.isWord(aWords[m], { "hour", "hours" }) then
							sUnits = "hour";
						elseif StringManager.isWord(aWords[m], { "day", "days" }) then
							sUnits = "day";
						end
						m = m + 1;
						
						if sUnits then
							rEffect.aDice, rEffect.nMod = StringManager.convertStringToDice(sDiceMod);
							
							if StringManager.isWord(aWords[m], "per") and
									StringManager.isWord(aWords[m + 1], "caster") and
									StringManager.isWord(aWords[m + 2], "level") then
								rEffect.bCLMult = true;
							end

							rEffect.sUnits = sUnits;
						end
					end
				end
				
				table.insert(aEffects, rEffect);
			end

			i = k;
			
		elseif StringManager.isWord(aWords[i], { "daze", "dazes" }) and 
				StringManager.isWord(aWords[i+1], "one") and 
				StringManager.isWord(aWords[i+2], "living") and
				StringManager.isWord(aWords[i+3], "creature") then
			
			local rEffect = {};
			rEffect.sName = "Dazed";
			
			table.insert(aEffects, rEffect);

			i = i + 3;
		end
		
		-- Increment word counter
		i = i + 1;
	end
	
	-- Remove duplicates
	local aFinalEffects = {};
	for i = 1, #aEffects do
		local bFirstUnique = true;
		for j = i - 1, 1, -1 do
			if aEffects[i].sName == aEffects[j].sName then
				bFirstUnique = false;
				break;
			end
		end
		if bFirstUnique then
			table.insert(aFinalEffects, aEffects[i]);
		end
	end
	
	-- Add the Effects
	for i = 1, #aFinalEffects do
		local rRoll = aFinalEffects[i];
		local nodeAction = nodeActions.createChild();
		
		DB.setValue(nodeAction, "type", "string", "effect");
		DB.setValue(nodeAction, "label", "string", rRoll.sName);
		
		-- If duration is specified in the spell description
		if rRoll.sUnits then
			DB.setValue(nodeAction, "durdice", "dice", rRoll.aDice);
			DB.setValue(nodeAction, "durunit", "string", rRoll.sUnits);
			
			if rRoll.bCLMult then
				DB.setValue(nodeAction, "durmult", "number", rRoll.nMod);
			else
				DB.setValue(nodeAction, "durmod", "number", rRoll.nMod);
			end

		-- Otherwise, use the spell duration (if available), or permanent (if not)
		else
			local sSpellDur = DB.getValue(nodeAction, "...duration", "");
			local aDurWords = StringManager.parseWords(sSpellDur);
			
			i = 1;
			if StringManager.isNumberString(aDurWords[i]) then
				local nSpellDur = tonumber(aDurWords[i]);
				i = i + 1;
				
				local sUnits = nil;
				if StringManager.isWord(aDurWords[i], { "round", "rounds" }) then
					sUnits = "";
				elseif StringManager.isWord(aDurWords[i], { "min", "minute", "minutes" }) then
					sUnits = "minute";
				elseif StringManager.isWord(aDurWords[i], { "hour", "hours" }) then
					sUnits = "hour";
				elseif StringManager.isWord(aDurWords[i], { "day", "days" }) then
					sUnits = "day";
				end
				
				if sUnits then
					i = i + 1;
					
					local nMult = 1;
					if StringManager.isWord(aDurWords[i], "per") then
						i = i + 1;
						if StringManager.isWord(aDurWords[i], "two") then
							nMult = 0.5;
							i = i + 1;
						elseif StringManager.isWord(aDurWords[i], "three") then
							nMult = 0.34;
							i = i + 1;
						end
					end
					
					local bUseCL = false;
					if StringManager.isWord(aDurWords[i], { "level", "levels" }) then
						bUseCL = true;
					end
					
					if bUseCL then
						local nFinalDur = math.max(math.floor(nSpellDur * nMult), nMult);
						DB.setValue(nodeAction, "durmult", "number", nFinalDur);
					else
						DB.setValue(nodeAction, "durmod", "number", nSpellDur);
					end
					DB.setValue(nodeAction, "durunit", "string", sUnits);
				end
			end
		end
	end
end

function updateSpellClassCounts(nodeSpellClass)
	local sCasterType = DB.getValue(nodeSpellClass, "castertype", "");
	if sCasterType == "points" then
		return;
	end
	
	for _,vLevel in pairs(DB.getChildren(nodeSpellClass, "levels")) do
		-- Calculate spell statistics
		local nTotalCast = 0;
		local nTotalPrepared = 0;
		local nMaxPrepared = 0;
		local nSpells = 0;
		
		for _,vSpell in pairs(DB.getChildren(vLevel, "spells")) do
			nSpells = nSpells + 1;
			
			local nCast = DB.getValue(vSpell, "cast", 0);
			nTotalCast = nTotalCast + nCast;
			
			local nPrepared = 0;
			if sCasterType ~= "spontaneous" then
				nPrepared = DB.getValue(vSpell, "prepared", 0);
				nTotalPrepared = nTotalPrepared + nPrepared;
				if nPrepared > nMaxPrepared then
					nMaxPrepared = nPrepared;
				end
			end
		end
		
		DB.setValue(vLevel, "totalcast", "number", nTotalCast);
		DB.setValue(vLevel, "totalprepared", "number", nTotalPrepared);
		DB.setValue(vLevel, "maxprepared", "number", nMaxPrepared);
	end
end

function getSpellActionOutputOrder(nodeAction)
	if not nodeAction then
		return 1;
	end
	local nodeActionList = nodeAction.getParent();
	if not nodeActionList then
		return 1;
	end
	
	-- First, pull some ability attributes
	local sType = DB.getValue(nodeAction, "type", "");
	local nOrder = DB.getValue(nodeAction, "order", 0);
	
	-- Iterate through list node
	local nOutputOrder = 1;
	for k, v in pairs(nodeActionList.getChildren()) do
		if DB.getValue(v, "type", "") == sType then
			if DB.getValue(v, "order", 0) < nOrder then
				nOutputOrder = nOutputOrder + 1;
			end
		end
	end
	
	return nOutputOrder;
end

function getSpellAction(rActor, nodeAction, sSubRoll)
	if not nodeAction then
		return;
	end
	
	local sType = DB.getValue(nodeAction, "type", "");
	
	local rAction = {};
	rAction.type = sType;
	rAction.label = DB.getValue(nodeAction, "...name", "");
	rAction.order = getSpellActionOutputOrder(nodeAction);
	-- KEL Save versus tags new variables and replace attribute
	rAction.school = DB.getValue(nodeAction, "school", "");
	rAction.stype = DB.getValue(nodeAction, "stype", "");
	rAction.tags = DB.getValue(nodeAction, "othertags", "");
	rAction.replace = DB.getValue(nodeAction, "replacedc.ability", "");
	-- Save overlay
	rAction.spell = true;
	-- END of new variables
	
	if sType == "cast" then
		rAction.subtype = sSubRoll;
		rAction.onmissdamage = DB.getValue(nodeAction, "onmissdamage", "");
		
		local sAttackType = DB.getValue(nodeAction, "atktype", "");
		if sAttackType ~= "" then
			if sAttackType == "mtouch" then
				rAction.range = "M";
				rAction.touch = true;
			elseif sAttackType == "rtouch" then
				rAction.range = "R";
				rAction.touch = true;
			elseif sAttackType == "ranged" then
				rAction.range = "R";
			elseif sAttackType == "cm" then
				rAction.range = "M";
				rAction.cm = true;
			else
				rAction.range = "M";
			end
			
			if rAction.cm then
				rAction.modifier = ActorManager35E.getAbilityScore(rActor, "cmb") + DB.getValue(nodeAction, "atkmod", 0);
			else
				rAction.modifier = ActorManager35E.getAbilityScore(rActor, "bab") + DB.getValue(nodeAction, "atkmod", 0);
			end
			rAction.modifier = DB.getValue(nodeAction, "atkmod", 0);
			rAction.crit = 20;

			local sNodeType, nodeActor = ActorManager.getTypeAndNode(rActor);
			if sNodeType == "pc" then
				if rAction.range == "R" then
					rAction.stat = DB.getValue(nodeActor, "attackbonus.ranged.ability", "");
					if rAction.stat == "" then
						rAction.stat = "dexterity";
					end
					rAction.modifier = rAction.modifier + DB.getValue(nodeActor, "attackbonus.ranged.size", 0) + DB.getValue(nodeActor, "attackbonus.ranged.misc", 0);
				else
					if rAction.cm then
						rAction.stat = DB.getValue(nodeActor, "attackbonus.grapple.ability", "");
						if rAction.stat == "" then
							rAction.stat = "strength";
						end
						rAction.modifier = rAction.modifier + DB.getValue(nodeActor, "attackbonus.grapple.size", 0) + DB.getValue(nodeActor, "attackbonus.grapple.misc", 0);
					else
						rAction.stat = DB.getValue(nodeActor, "attackbonus.melee.ability", "");
						if rAction.stat == "" then
							rAction.stat = "strength";
						end
						rAction.modifier = rAction.modifier + DB.getValue(nodeActor, "attackbonus.melee.size", 0) + DB.getValue(nodeActor, "attackbonus.melee.misc", 0);
					end
				end
				rAction.modifier = rAction.modifier + ActorManager35E.getAbilityScore(rActor, "bab") + ActorManager35E.getAbilityBonus(rActor, rAction.stat);
			else
				if rAction.range == "R" then
					rAction.stat = "dexterity";
				else
					rAction.stat = "strength";
				end
				if rAction.cm then
					rAction.modifier = rAction.modifier + ActorManager35E.getAbilityScore(rActor, "cmb");
				else
					rAction.modifier = rAction.modifier + ActorManager35E.getAbilityScore(rActor, "bab") + ActorManager35E.getAbilityBonus(rActor, rAction.stat);
				end
			end
		end
		
		rAction.clc = SpellManager.getActionCLC(nodeAction);
		rAction.sr = "yes";
		
		if (DB.getValue(nodeAction, "srnotallowed", 0) == 1) then
			rAction.sr = "no";
		end
		
		rAction.dcstat = DB.getValue(nodeAction, ".......dc.ability", "");
		-- KEL replacing attribute when needed
		if rAction.replace ~= "" then
			rAction.dcstat = rAction.replace;
		end
		-- END
		local sSaveType = DB.getValue(nodeAction, "savetype", "");
		if sSaveType ~= "" then
			rAction.save = sSaveType;
			rAction.savemod = SpellManager.getActionSaveDC(nodeAction);
		else
			rAction.save = "";
			rAction.savemod = 0;
		end
		
	elseif sType == "damage" then
		rAction.clauses = getActionDamage(rActor, nodeAction);
		
		rAction.meta = DB.getValue(nodeAction, "meta", "");

		rAction.bSpellDamage = (DB.getValue(nodeAction, "dmgnotspell", 0) == 0);
		if rAction.bSpellDamage then
			for _,vClause in ipairs(rAction.clauses) do
				if not vClause.dmgtype or vClause.dmgtype == "" then
					vClause.dmgtype = "spell";
				else
					vClause.dmgtype = vClause.dmgtype .. ",spell";
				end
			end
		end
		
	elseif sType == "heal" then
		rAction.clauses = getActionHeal(rActor, nodeAction);

		rAction.subtype = DB.getValue(nodeAction, "healtype", "");
		rAction.meta = DB.getValue(nodeAction, "meta", "");
	
	elseif sType == "effect" then
		local nodeSpellClass = DB.getChild(nodeAction, ".......");
		rAction.sName = EffectManager35E.evalEffect(rActor, DB.getValue(nodeAction, "label", ""), nodeSpellClass);

		rAction.sApply = DB.getValue(nodeAction, "apply", "");
		rAction.sTargeting = DB.getValue(nodeAction, "targeting", "");
		
		rAction.aDice, rAction.nDuration = getActionEffectDuration(rActor, nodeAction);

		rAction.sUnits = DB.getValue(nodeAction, "durunit", "");
	end
	
	return rAction;
end

function onSpellAction(draginfo, nodeAction, sSubRoll)
	if not nodeAction then
		return;
	end
	local rActor = ActorManager.resolveActor(nodeAction.getChild("........."));
	if not rActor then
		return;
	end
	-- KEL CL effect
	local nodeSpell = DB.getChild(nodeAction, "...");
	local nodeActions = nodeSpell.createChild("actions");
	local tag = "";
	local range = "";
	-- KEL If multiple cast actions: Important that all cast actions have the same tags? Also adding ranges
	if nodeActions then
		local OthernodeAction = nodeActions.getChildren();
		if OthernodeAction then
			for k, v in pairs(OthernodeAction) do
				if DB.getValue(v, "type") == "cast" then
					rCastAction = SpellManager.getSpellAction(rActor, v);
					tag = SpellManager.getTagsFromAction(rCastAction);
					range = rCastAction.range;
					break;
				end
			end
		end
	end
	local aAddDice, nAddMod, nEffectCount = EffectManager35E.getEffectsBonus(rActor, "CL", false, nil, nil, false, tag);
	local nClMod = 0;
	if nEffectCount > 0 then
		nClMod = StringManager.evalDice(aAddDice, nAddMod);
	end
	-- local originalCl = DB.getValue(nodeAction, ".......cl", 0);
	local nodeSpellClass = DB.getChild(nodeAction, ".......");
	local originalCl = DB.getValue(nodeSpellClass, "cl", 0)
	local NewCL = originalCl + nClMod;
	DB.setValue(nodeSpellClass, "cl", "number", NewCL);
	--END
	local rAction = getSpellAction(rActor, nodeAction, sSubRoll);
	-- KEL Reset CL to original value
	DB.setValue(nodeSpellClass, "cl", "number", originalCl);
	-- END
	
	local rRolls = {};
	local rCustom = nil;
	if rAction.type == "cast" then
		-- KEL Use Cast-specific tags (?)
		local tagsSpec = SpellManager.getTagsFromAction(rAction);
		if not rAction.subtype then
			table.insert(rRolls, ActionSpell.getSpellCastRoll(rActor, rAction, tagsSpec));
		end
		
		if not rAction.subtype or rAction.subtype == "atk" then
			if rAction.range then
				-- KEL add tag in getRoll itself, since that is need for IFTAG-KEEN; similar for following getRoll
				local rRoll = ActionAttack.getRoll(rActor, rAction, tagsSpec);
				table.insert(rRolls, rRoll);
			end
		end

		if not rAction.subtype or rAction.subtype == "clc" then
			local rRoll = ActionSpell.getCLCRoll(rActor, rAction, tagsSpec);
			if not rAction.subtype then
				rRoll.sType = "castclc";
				rRoll.aDice = {};
			end
			table.insert(rRolls, rRoll);
		end

		if not rAction.subtype or rAction.subtype == "save" then
			if rAction.save and rAction.save ~= "" then
				local rRoll = ActionSpell.getSaveVsRoll(rActor, rAction, tagsSpec);
				if not rAction.subtype then
					rRoll.sType = "castsave";
				end
				table.insert(rRolls, rRoll);
			end
		end
		
	elseif rAction.type == "damage" then
		-- KEL add range and tag stuff to spells
		if range ~= "" then
			rAction.range = range;
		end
		
		local rRoll = ActionDamage.getRoll(rActor, rAction, tag);
		-- END
		if rAction.bSpellDamage then
			rRoll.sType = "spdamage";
		else
			rRoll.sType = "damage";
		end
		
		table.insert(rRolls, rRoll);
		
	elseif rAction.type == "heal" then
		-- KEL add tags
		local rRoll = ActionHeal.getRoll(rActor, rAction, tag);
		-- END
		table.insert(rRolls, rRoll);

	elseif rAction.type == "effect" then
		local rRoll;
		rRoll = ActionEffect.getRoll(draginfo, rActor, rAction);
		if rRoll then
			-- KEL adding tags, just in case :)
			if tag then
				rRoll.tags = tag;
			end
			-- END
			table.insert(rRolls, rRoll);
		end
	end
	
	if #rRolls > 0 then
		ActionsManager.performMultiAction(draginfo, rActor, rRolls[1].sType, rRolls);
	end
end

-- KEL Getting tags from rAction
function getTagsFromAction(rAction)
	local tags = "";
	local semicolon = ";";
	
	if not rAction then
		return nil;
	elseif not rAction.tags then
		return nil;
	end
	
	tags = rAction.stype .. semicolon .. rAction.school .. semicolon .. rAction.tags;
	
	local tagshelp = StringManager.parseWords(tags);
	if not tagshelp[1] then
		return nil;
	end
	
	return tags;
end
--END

function getActionAbilityBonus(nodeAction)
	local nodeSpellClass = nodeAction.getChild(".......");
	local nodeCreature = nodeSpellClass.getChild("...");

	local sAbility = DB.getValue(nodeSpellClass, "dc.ability", "");

	local rActor = ActorManager.resolveActor(nodeCreature);
	local nStat = ActorManager35E.getAbilityBonus(rActor, sAbility);
	
	-- KEL replace DC if necessary; use getAbilityBonus to have the DC update when ability changes because replacedc.abilitymod does only get updated when save definition window is opened
	local sReplAbil = DB.getValue(nodeAction, "replacedc.ability", "");
	if sReplAbil ~= "" then
		-- nStat = DB.getValue(nodeAction, "replacedc.abilitymod", 0);
		nStat = ActorManager35E.getAbilityBonus(rActor, sReplAbil);
	end
	-- END
	
	return nStat;
end

function getActionCLC(nodeAction)
	local nStat = DB.getValue(nodeAction, ".......cl", 0);
	local nPen = DB.getValue(nodeAction, ".......sp", 0);
	local nMod = DB.getValue(nodeAction, "clcmod", 0);
	
	return nStat + nPen + nMod;
end

function getActionSaveDC(nodeAction)
	local nTotal;
	
	if DB.getValue(nodeAction, "savedctype", "") == "fixed" then
		nTotal = DB.getValue(nodeAction, "savedcmod", 0);
    elseif DB.getValue(nodeAction, "savedctype", "") == "casterlevel" then
		local nClassStat = getActionAbilityBonus(nodeAction);
		local nClassMisc = DB.getValue(nodeAction, ".......dc.misc", 0);
        local nCasterLevel = math.floor(DB.getValue(nodeAction, ".......cl", 0)/2);
        local nMod = DB.getValue(nodeAction, "savedcmod", 0);

        nTotal = 10 + nClassStat + nClassMisc + nCasterLevel + nMod;
	else
		local nClassStat = getActionAbilityBonus(nodeAction);
		local nClassMisc = DB.getValue(nodeAction, ".......dc.misc", 0);
		local nSpellLevel = DB.getValue(nodeAction, ".....level", 0);
		local nMod = DB.getValue(nodeAction, "savedcmod", 0);
		
		nTotal = 10 + nClassStat + nClassMisc + nSpellLevel + nMod;
	end
	
	return nTotal;
end
-- KEL Adding new CL and LVL mods
function getActionMod(rActor, nodeAction, sStat, nStatMax)
	local nStat;
	
	if sStat == "" then
		nStat = 0;
	elseif sStat == "cl" or sStat == "halfcl" or sStat == "oddcl" or sStat =="thirdcl" then
		nStat = DB.getValue(nodeAction, ".......cl", 0);
		if sStat == "halfcl" then
			nStat = math.floor((nStat + 0.5) / 2);
		elseif sStat == "oddcl" then
			nStat = math.floor((nStat + 1.5) / 2);
		elseif sStat == "thirdcl" then
			nStat = math.floor(nStat / 3);
		end
	-- elseif sStat == "totallvl" then
		-- nStat = ActorManager35E.getAbilityBonus(rActor, "level");
	else
		nStat = ActorManager35E.getAbilityBonus(rActor, sStat);
	end
	
	if nStat > 0 and nStatMax and nStatMax > 0 then
		nStat = math.max(math.min(nStat, nStatMax), 0);
	end
	
	return nStat;
end
-- END
function getActionDamage(rActor, nodeAction)
	if not nodeAction then
		return {};
	end
	
	local clauses = {};
	local aDamageNodes = UtilityManager.getSortedTable(DB.getChildren(nodeAction, "damagelist"));
	for _,v in ipairs(aDamageNodes) do
		local aDmgDice = DB.getValue(v, "dice", {});
		if #aDmgDice > 0 then
			local sDiceStat = DB.getValue(v, "dicestat", "");
			local nDiceStatMax = DB.getValue(v, "dicestatmax", 0);
			
			local nDiceMult = math.max(getActionMod(rActor, nodeAction, sDiceStat, nDiceStatMax), 1);
			if nDiceMult > 1 then
				local nCopy = #aDmgDice;
				for i = 2, nDiceMult do
					for j = 1, nCopy do
						table.insert(aDmgDice, aDmgDice[j]);
					end
				end
			end
		end
		
		local nDmgMod = DB.getValue(v, "bonus", 0);

		local sDmgStat = DB.getValue(v, "stat", "");
		local nDmgStatMult = 1;
		local nDmgStatMax = 0;
		if sDmgStat ~= "" then
			nDmgStatMult = math.max(DB.getValue(v, "statmult", 1), 0.5);
			nDmgStatMax = math.max(DB.getValue(v, "statmax", 0), 0);
			
			local nDmgStat = getActionMod(rActor, nodeAction, sDmgStat, nDmgStatMax);
			nDmgMod = nDmgMod + math.floor(nDmgStat * nDmgStatMult);
		end

		local aDamageTypes = ActionDamage.getDamageTypesFromString(DB.getValue(v, "type", ""));
		local sDmgType = table.concat(aDamageTypes, ",");
		
		table.insert(clauses, { dice = aDmgDice, modifier = nDmgMod, mult = 2, stat = sDmgStat, statmax = nDmgStatMax, statmult = nDmgStatMult, dmgtype = sDmgType });
	end

	return clauses;
end

function getActionHeal(rActor, nodeAction)
	if not nodeAction then
		return {};
	end
	
	local clauses = {};
	local aDamageNodes = UtilityManager.getSortedTable(DB.getChildren(nodeAction, "heallist"));
	for _,v in ipairs(aDamageNodes) do
		local aDice = DB.getValue(v, "dice", {});
		if #aDice > 0 then
			local sDiceStat = DB.getValue(v, "dicestat", "");
			local nDiceStatMax = DB.getValue(v, "dicestatmax", 0);
			
			local nDiceMult = math.max(getActionMod(rActor, nodeAction, sDiceStat, nDiceStatMax), 1);
			if nDiceMult > 1 then
				local nCopy = #aDice;
				for i = 2, nDiceMult do
					for j = 1, nCopy do
						table.insert(aDice, aDice[j]);
					end
				end
			end
		end
		
		local nMod = DB.getValue(v, "bonus", 0);

		local sStat = DB.getValue(v, "stat", "");
		local nStatMult = 1;
		local nStatMax = 0;
		if sStat ~= "" then
			nStatMult = math.max(DB.getValue(v, "statmult", 1), 0.5);
			nStatMax = math.max(DB.getValue(v, "statmax", 0), 0);
			
			local nStat = getActionMod(rActor, nodeAction, sStat, nStatMax);
			nMod = nMod + math.floor(nStat * nStatMult);
		end

		table.insert(clauses, { dice = aDice, modifier = nMod, mult = 2, stat = sStat, statmax = nStatMax, statmult = nStatMult });
	end

	return clauses;
end

function getActionEffectDuration(rActor, nodeAction)
	if not nodeAction then
		return {}, 0;
	end
	
	local aDice = DB.getValue(nodeAction, "durdice", {});
	if #aDice > 0 then
		local sDiceStat = DB.getValue(nodeAction, "durdicestat", "");
		local nDiceStatMax = DB.getValue(nodeAction, "durdicestatmax", 0);
		
		local nDiceMult = math.max(getActionMod(rActor, nodeAction, sDiceStat, nDiceStatMax), 1);
		if nDiceMult > 1 then
			local nCopy = #aDice;
			for i = 2, nDiceMult do
				for j = 1, nCopy do
					table.insert(aDice, aDice[j]);
				end
			end
		end
	end
	
	local nMod = DB.getValue(nodeAction, "durmod", 0);
	
	local sStat = DB.getValue(nodeAction, "durstat", "");
	local nStatMult = 1;
	local nStatMax = 0;
	if sStat ~= "" then
		nStatMult = math.max(DB.getValue(nodeAction, "durmult", 1), 1);
		nStatMax = math.max(DB.getValue(nodeAction, "dmaxstat", 0), 0);
		
		local nStat = getActionMod(rActor, nodeAction, sStat, nStatMax);
		nMod = nMod + math.floor(nStat * nStatMult);
	end

	return aDice, nMod;
end

--
-- DISPLAY FUNCTIONS
--

function getActionAttackText(nodeAction)
	local sAttack = "";
	
	local sAttackType = DB.getValue(nodeAction, "atktype", "");
	local nAttackMod = DB.getValue(nodeAction, "atkmod", 0);
	if sAttackType == "melee" then
		sAttack = Interface.getString("power_label_atktypemelee");
	elseif sAttackType == "ranged" then
		sAttack = Interface.getString("power_label_atktyperanged");
	elseif sAttackType == "mtouch" then
		sAttack = Interface.getString("power_label_atktypemtouch");
	elseif sAttackType == "rtouch" then
		sAttack = Interface.getString("power_label_atktypertouch");
	elseif sAttackType == "cm" then
		sAttack = Interface.getString("power_label_atktypegrapple");
	end
	if sAttack ~= "" and nAttackMod ~= 0 then
		sAttack = sAttack .. " + " .. nAttackMod;
	end
	
	return sAttack;
end

function getActionSaveText(nodeAction)
	local sSave = "";

	local sSaveType = DB.getValue(nodeAction, "savetype", "");
	local nDC = SpellManager.getActionSaveDC(nodeAction);

	if sSaveType ~= "" and nDC ~= 0 then
		if sSaveType == "fortitude" then
			sSave = Interface.getString("power_label_savetypefort");
		elseif sSaveType == "reflex" then
			sSave = Interface.getString("power_label_savetyperef");
		elseif sSaveType == "will" then
			sSave = Interface.getString("power_label_savetypewill");
		end
		
		sSave = string.format("%s DC %d", sSave, nDC);
		if DB.getValue(nodeAction, "onmissdamage", "") == "half" then
			sSave = sSave .. " (H)";
		end
	end
	
	return sSave;
end

function getActionDamageText(nodeAction)
	local nodeActor = nodeAction.getChild(".........")
	local rActor = ActorManager.resolveActor(nodeActor);

	local clauses = SpellManager.getActionDamage(rActor, nodeAction);
	
	local aOutput = {};
	local aDamage = ActionDamage.getDamageStrings(clauses);
	for _,rDamage in ipairs(aDamage) do
		local sDice = StringManager.convertDiceToString(rDamage.aDice, rDamage.nMod);
		if sDice ~= "" then
			if rDamage.sType ~= "" then
				table.insert(aOutput, string.format("%s %s", sDice, rDamage.sType));
			else
				table.insert(aOutput, sDice);
			end
		end
	end
	local sDamage = table.concat(aOutput, " + ");
	
	local sMeta = DB.getValue(nodeAction, "meta", "");
	if sMeta == "empower" then
		sDamage = sDamage .. " [E]";
	elseif sMeta == "maximize" then
		sDamage = sDamage .. " [M]";
	end
	
	return sDamage;
end

function getActionHealText(nodeAction)
	local nodeActor = nodeAction.getChild(".........")
	local rActor = ActorManager.resolveActor(nodeActor);

	local clauses = SpellManager.getActionHeal(rActor, nodeAction);
	
	local aHealDice = {};
	local nHealMod = 0;
	for _,vClause in ipairs(clauses) do
		for _,vDie in ipairs(vClause.dice) do
			table.insert(aHealDice, vDie);
		end
		nHealMod = nHealMod + vClause.modifier;
	end

	local sHeal = StringManager.convertDiceToString(aHealDice, nHealMod);
	if DB.getValue(nodeAction, "healtype", "") == "temp" then
		sHeal = sHeal .. " temporary";
	end
	
	local sMeta = DB.getValue(nodeAction, "meta", "");
	if sMeta == "empower" then
		sHeal = sHeal .. " [E]";
	elseif sMeta == "maximize" then
		sHeal = sHeal .. " [M]";
	end
	
	return sHeal;
end

function getActionEffectDurationText(nodeAction)
	local nodeActor = nodeAction.getChild(".........")
	local rActor = ActorManager.resolveActor(nodeActor);

	local aDice, nMod = getActionEffectDuration(rActor, nodeAction);

	local sDuration = StringManager.convertDiceToString(aDice, nMod);
	
	local sUnits = DB.getValue(nodeAction, "durunit", "");
	if sDuration ~= "" then
		if sUnits == "minute" then
			sDuration = sDuration .. " min";
		elseif sUnits == "hour" then
			sDuration = sDuration .. " hr";
		elseif sUnits == "day" then
			sDuration = sDuration .. " dy";
		else
			sDuration = sDuration .. " rd";
		end
	end
	
	return sDuration;
end
