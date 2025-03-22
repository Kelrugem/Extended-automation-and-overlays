-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	CombatRecordManager.handleCombatAddInitDnD = handleCombatAddInitDnD;
end

function handleCombatAddInitDnD(tCustom)
	local sOptINIT = OptionsManager.getOption("INIT");
	-- KEL FFOS, only NPCs here
	local nCurrent = DB.getValue("combattracker.round", 0);
	local sOptFFOS = OptionsManager.getOption("FFOS");
	local bHasUncDodge = false;
	if (sOptFFOS == "on") and (nCurrent == 0) then
		local sAbilityname = string.lower(DB.getValue(tCustom.nodeCT, "specialqualities", ""));
		if string.match(sAbilityname, "improved uncanny dodge") or string.match(sAbilityname, "uncanny dodge") then
			bHasUncDodge = true;
		end
	end
	-- END
	local nInit;
	if sOptINIT == "group" then
		if tCustom.nodeCTLastMatch then
			nInit = DB.getValue(tCustom.nodeCTLastMatch, "initresult", 0);
			-- KEL FFOS
			if (sOptFFOS == "on") and (nCurrent == 0) and not bHasUncDodge then
				EffectManager.addEffect("", "", tCustom.nodeCT, { sName = "Flatfooted", nDuration = 1, nInit = nInit, nGMOnly = 1 }, false);
			end
			-- END
		else
			nInit = math.random(20) + DB.getValue(tCustom.nodeCT, "init", 0);
			-- KEL FFOS
			if (sOptFFOS == "on") and (nCurrent == 0) and not bHasUncDodge then
				EffectManager.addEffect("", "", tCustom.nodeCT, { sName = "Flatfooted", nDuration = 1, nInit = nInit, nGMOnly = 1 }, false);
			end
			--END
		end
	elseif sOptINIT == "on" then
		nInit = math.random(20) + DB.getValue(tCustom.nodeCT, "init", 0);
		-- KEL FFOS
		if (sOptFFOS == "on") and (nCurrent == 0) and not bHasUncDodge then
			EffectManager.addEffect("", "", tCustom.nodeCT, { sName = "Flatfooted", nDuration = 1, nInit = nInit, nGMOnly = 1 }, false);
		end
		-- END
	else
		return;
	end

	DB.setValue(tCustom.nodeCT, "initresult", "number", nInit);
end