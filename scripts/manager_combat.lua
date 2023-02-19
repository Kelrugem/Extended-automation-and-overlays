-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	OldnextActor = CombatManager.nextActor;
	CombatManager.nextActor = CombatManagerKel.nextActor;
	
	OldnextRound = CombatManager.nextRound;
	CombatManager.nextRound = CombatManagerKel.nextRound;
	
	CombatManager.rollStandardEntryInit = CombatManagerKel.rollStandardEntryInit;
end

function nextActor(bSkipBell, bNoRoundAdvance)
	if not Session.IsHost then
		return;
	end
	
	OldnextActor(bSkipBell, bNoRoundAdvance);
	-- KEL Clear saves
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		TokenManager3.setSaveOverlay(v,0, true);
	end
	-- END
end

function nextRound(nRounds)
	if not Session.IsHost then
		return;
	end
	
	OldnextRound(nRounds);
	-- KEL Clear saves
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		TokenManager3.setSaveOverlay(v,0,true); 
	end
	-- END
end

function rollStandardEntryInit(tInit)
	if not tInit or not tInit.nodeEntry then
		return;
	end
	
	-- KEL FFOS
	local rActor = ActorManager.resolveActor(tInit.nodeEntry);
	local nCurrent = DB.getValue("combattracker.round", 0);
	local sOptFFOS = OptionsManager.getOption("FFOS");
	local bHasUncDodge = false;
	if (sOptFFOS == "on") and (nCurrent == 0) then
		local sSourceType, nodeSource = ActorManager.getTypeAndNode(rActor);
		if sSourceType == "pc" then
			for _,v in ipairs(DB.getChildList(nodeSource, "specialabilitylist")) do
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
	local sClass, sRecord = DB.getValue(tInit.nodeEntry, "link", "", "");
	if sClass == "charsheet" then
		-- KEL FFOS
		local nInitResult = CombatManager.helperRollRandomInit(tInit);
		DB.setValue(tInit.nodeEntry, "initresult", "number", nInitResult);
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", tInit.nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 0 }, false);
			end
		end
		-- END
		return;
	end
	
	-- For NPCs, if NPC init option is not group, then roll unique initiative
	local sOptINIT = OptionsManager.getOption("INIT");
	if sOptINIT ~= "group" then
		-- KEL FFOS
		local nInitResult = CombatManager.helperRollRandomInit(tInit);
		DB.setValue(tInit.nodeEntry, "initresult", "number", nInitResult);
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", tInit.nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
			end
		end
		-- END
		return;
	end

	-- For NPCs with group option enabled
	
	-- Get the entry's database node name and creature name
	local sStripName = CombatManager.stripCreatureNumber(DB.getValue(tInit.nodeEntry, "name", ""));
	if sStripName == "" then
		-- KEL FFOS
		local nInitResult = CombatManager.helperRollRandomInit(tInit);
		DB.setValue(tInit.nodeEntry, "initresult", "number", nInitResult);
		if sOptFFOS == "on" then
			if nCurrent == 0 and not bHasUncDodge then
				EffectManager.addEffect("", "", tInit.nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
			end
		end
		-- END
		return;
	end
		
	-- Iterate through list looking for other creatures with same name
	local nLastInit = nil;
	local sEntryFaction = DB.getValue(tInit.nodeEntry, "friendfoe", "");
	for _,nodeCT in pairs(CombatManager.getCombatantNodes()) do
		if DB.getName(nodeCT) ~= DB.getName(tInit.nodeEntry) then
			if DB.getValue(nodeCT, "friendfoe", "") == sEntryFaction then
				local sTemp = CombatManager.stripCreatureNumber(DB.getValue(nodeCT, "name", ""));
				if sTemp == sStripName then
					local nChildInit = DB.getValue(nodeCT, "initresult", 0);
					if nChildInit ~= -10000 then
						nLastInit = nChildInit;
					end
				end
			end
		end
	end
	
	-- If we found similar creatures, then match the initiative of the last one found; otherwise, roll
	-- KEL FFOS
	local nInitResult = nLastInit or CombatManager.helperRollRandomInit(tInit);
	DB.setValue(tInit.nodeEntry, "initresult", "number", nInitResult);
	if sOptFFOS == "on" then
		if nCurrent == 0 and not bHasUncDodge then
			EffectManager.addEffect("", "", nodeEntry, { sName = "Flatfooted", nDuration = 1, nInit = nInitResult, nGMOnly = 1 }, false);
		end
	end
	-- END
end