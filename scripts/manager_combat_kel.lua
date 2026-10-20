--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- luacheck: globals DataCommonKel TokenManagerKel
-- luacheck: globals onNPCPostAdd onNPCPostAddKel
-- luacheck: globals getEntryInitRecord nextActor nextRound

local _fnOrigOnNPCPostAdd;
local _fnOrigGetEntryInitRecord;
local _fnOrigNextActor;
local _fnOrigNextRound;

function onInit()
	_fnOrigOnNPCPostAdd = CombatRecordManager.getRecordTypePostAddCallback("npc");
	CombatRecordManager.setRecordTypePostAddCallback("npc", onNPCPostAdd);

	_fnOrigGetEntryInitRecord = CombatManager2.getEntryInitRecord;
	CombatManager2.getEntryInitRecord = getEntryInitRecord;

	_fnOrigNextActor = CombatManager.nextActor;
	CombatManager.nextActor = nextActor;
	_fnOrigNextRound = CombatManager.nextRound;
	CombatManager.nextRound = nextRound;
end

function onNPCPostAdd(tCustom)
	_fnOrigOnNPCPostAdd(tCustom);
	onNPCPostAddKel(tCustom);
end
function onNPCPostAddKel(tCustom)
	if not tCustom.nodeRecord or not tCustom.nodeCT then
		return;
	end

	local nodeNPC = tCustom.nodeRecord;

	local setTags = SetManager.new();
	local sSpecialQualities = DB.getValue(nodeNPC, "specialqualities", ""):lower();
	local aSQWords = StringManager.parseWords(sSpecialQualities);
	local i = 1;
	while aSQWords[i] do
		if StringManager.isWord(aSQWords[i], "immunity") and StringManager.isWord(aSQWords[i+1], "to") then
			i = i + 1;

			while aSQWords[i+1] do
				if StringManager.isWord(aSQWords[i+1], "and") then
					-- SKIP
				elseif StringManager.isWord(aSQWords[i+2], "traits") then
					if StringManager.isWord(aSQWords[i+1], "construct") then
						SetManager.add(setTags, DataCommonKel.tconstructtraits);
					elseif StringManager.isWord(aSQWords[i+1], "dragon") then
						SetManager.add(setTags, DataCommonKel.tdragontraits);
					elseif StringManager.isWord(aSQWords[i+1], "elemental") then
						SetManager.add(setTags, DataCommonKel.telementaltraits);
					elseif StringManager.isWord(aSQWords[i+1], "ooze") then
						SetManager.add(setTags, DataCommonKel.toozetraits);
					elseif StringManager.isWord(aSQWords[i+1], "plant") then
						SetManager.add(setTags, DataCommonKel.tplanttraits);
					elseif StringManager.isWord(aSQWords[i+1], "undead") then
						SetManager.add(setTags, DataCommonKel.tundeadtraits);
					elseif StringManager.isWord(aSQWords[i+1], "vermin") then
						SetManager.add(setTags, DataCommonKel.tvermintraits);
					end
					-- SKIP+
					i = i + 1;
				-- Skip immunities handled by base code
				elseif StringManager.isWord(aSQWords[i+1], "magic") then
					--
				elseif StringManager.isWord(aSQWords[i+1], "critical") and StringManager.isWord(aSQWords[i+2], "hits") then
					i = i + 1;
				elseif StringManager.isWord(aSQWords[i+1], "precision") and StringManager.isWord(aSQWords[i+2], "damage") then
					i = i + 1;
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.immunetypes) then
					if StringManager.isWord(aSQWords[i+2], "effects") then
						i = i + 1;
					end
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.dmgtypes) and not StringManager.isWord(aSQWords[i+1], DataCommon.specialdmgtypes) then
					--
				elseif StringManager.isWord(aSQWords[i+1], DataCommonKel.iftagcomp) then
					if aSQWords[i+1] == "mind-affecting" then
						aSQWords[i+1] = "mindaffecting";
					end
					SetManager.add(setTags, aSQWords[i+1]);
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
						SetManager.add(setTags, DataCommonKel.tconstructtraits);
					elseif StringManager.isWord(aSQWords[i+1], "dragon") then
						SetManager.add(setTags, DataCommonKel.tdragontraits);
					elseif StringManager.isWord(aSQWords[i+1], "elemental") then
						SetManager.add(setTags, DataCommonKel.telementaltraits);
					elseif StringManager.isWord(aSQWords[i+1], "ooze") then
						SetManager.add(setTags, DataCommonKel.toozetraits);
					elseif StringManager.isWord(aSQWords[i+1], "plant") then
						SetManager.add(setTags, DataCommonKel.tplanttraits);
					elseif StringManager.isWord(aSQWords[i+1], "undead") then
						SetManager.add(setTags, DataCommonKel.tundeadtraits);
					elseif StringManager.isWord(aSQWords[i+1], "vermin") then
						SetManager.add(setTags, DataCommonKel.tvermintraits);
					end
					-- SKIP+
					i = i + 1;
				-- Skip immunities handled by base code
				elseif StringManager.isWord(aSQWords[i+1], "magic") then
					--
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.immunetypes) then
					if StringManager.isWord(aSQWords[i+2], "effects") then
						i = i + 1;
					end
				elseif StringManager.isWord(aSQWords[i+1], DataCommon.dmgtypes) then
					--
				elseif StringManager.isWord(aSQWords[i+1], DataCommonKel.iftagcomp) then
					if aSQWords[i+1] == "mind-affecting" then
						aSQWords[i+1] = "mindaffecting";
					end
					SetManager.add(setTags, aSQWords[i+1]);
				else
					break;
				end

				i = i + 1;
			end
		end

		-- ITERATE SPECIAL QUALITIES DECODE
		i = i + 1;
	end
	if SetManager.count(setTags) > 0 then
		local sEffect = string.format("IF: TAG(%s); IMMUNE: spell", table.concat(setTags:toarray(), ","));
		EffectManager.addEffectByTable(tCustom.nodeCT, { sName = sEffect, nGMOnly = 1 });
	end
end

function getEntryInitRecord(nodeEntry)
	local tInit = _fnOrigGetEntryInitRecord(nodeEntry);
	if not tInit then
		return nil;
	end

	local rActor = ActorManager.resolveActor(nodeEntry);
	tInit.nADV = 0;
	tInit.nADV = tInit.nADV + EffectManager.getCompsCountByText(rActor, "ADV");
	tInit.nADV = tInit.nADV - EffectManager.getCompsCountByText(rActor, "DIS");
	tInit.nADV = tInit.nADV + EffectManager.getCompsCountByTextOrTag(rActor, "ADVINIT");
	tInit.nADV = tInit.nADV - EffectManager.getCompsCountByTextOrTag(rActor, "DISINIT");
	tInit.fnRollRandom = rollRandomInit;
	return tInit;
end
function rollRandomInit(tInit)
	local tSuffix = {};
	if (tInit.nMod or 0) ~= 0 then
		table.insert(tSuffix, string.format("(%+d)", tInit.nMod));
	end

	local nInitResult = math.random(20);
	local tDropped = {};
	if tInit.nADV > 0 then
		while tInit.nADV > 0 do
			local nInitResult2 = math.random(20);
			table.insert(tDropped, math.min(nInitResult, nInitResult2));
			nInitResult = math.max(nInitResult, nInitResult2);
			tInit.nADV = tInit.nADV - 1;
		end
		table.insert(tSuffix, string.format("[ADV] (DROPPED %s)", table.concat(tDropped, ",")));
	elseif tInit.nADV < 0 then
		while tInit.nADV < 0 do
			local nInitResult2 = math.random(20);
			table.insert(tDropped, math.max(nInitResult, nInitResult2));
			nInitResult = math.min(nInitResult, nInitResult2);
			tInit.nADV = tInit.nADV + 1;
		end
		table.insert(tSuffix, string.format("[DIS] (DROPPED %s)", table.concat(tDropped, ",")));
	end
	tInit.sSuffix = table.concat(tSuffix, "\r");

	return nInitResult + (tInit.nMod or 0);
end

function nextActor(bSkipBell, bNoRoundAdvance)
	_fnOrigNextActor(bSkipBell, bNoRoundAdvance);
	TokenManagerKel.clearSaveOverlays();
end
function nextRound(nRounds)
	_fnOrigNextRound(nRounds);
	TokenManagerKel.clearSaveOverlays();
end
