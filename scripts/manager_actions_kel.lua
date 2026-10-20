--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

-- luacheck: globals initOverrides
-- luacheck: globals onPreModRoll onPreModRollKelADV
-- luacheck: globals onPreResolve onPreResolveKelADV

local _fnOrigOnPreModRoll;
local _fnOrigOnPreResolve;

function onInit()
	initOverrides();
end

function initOverrides()
	_fnOrigOnPreModRoll = GameManager.getMultiKeyFunction("onActionPreModRoll", "");
	GameManager.setMultiKeyFunction("onActionPreModRoll", "", onPreModRoll);
	_fnOrigOnPreResolve = GameManager.getMultiKeyFunction("onActionPreResolve", "");
	GameManager.setMultiKeyFunction("onActionPreResolve", "", onPreResolve);
end

function onPreModRoll(rSource, rTarget, rRoll)
	onPreModRollKelADV(rSource, rTarget, rRoll);

	if _fnOrigOnPreModRoll then
		_fnOrigOnPreModRoll(rSource, rTarget, rRoll);
	end
end
function onPreModRollKelADV(rSource, rTarget, rRoll)
	rRoll.nADVDice = #(rRoll.aDice or {});
	if rRoll.nADVDice == 0 then
		return;
	end

	rRoll.nADV = (rRoll.nADV or 0);

	local bUseModStack = false;
	if rRoll.sType == "init" then
		bUseModStack = true;
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByText(rSource, "ADV");
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByText(rSource, "DIS");
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByTextOrTag(rSource, "ADVINIT");
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByTextOrTag(rSource, "DISINIT");

	elseif rRoll.sType == "attack" then
		bUseModStack = true;
		local tAttackFilter = ActionCore.buildEffectFilter(rRoll);

		local tSrcEffData = { rTarget = rTarget, tFilter = tAttackFilter, tActionTags = rRoll.tActionTags, };
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByText(rSource, "ADV", tSrcEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByText(rSource, "DIS", tSrcEffData);
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByTextOrTag(rSource, "ADVATK", tSrcEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByTextOrTag(rSource, "DISATK", tSrcEffData);

		local tTrgtEffData = { rTarget = rSource, tFilter = tAttackFilter, tActionTags = rRoll.tActionTags };
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByTextOrTag(rTarget, "@ADVATK", tTrgtEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByTextOrTag(rTarget, "@DISATK", tTrgtEffData);

	elseif rRoll.sType == "save" then
		bUseModStack = true;
		local tSaveFilter = ActionCore.buildEffectFilter(rRoll);
		local rSaveSource = ActorManager.resolveActor(rRoll.sSource);

		local tSrcEffData = { rTarget = rSaveSource, tFilter = tSaveFilter, tActionTags = rRoll.tActionTags, };
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByText(rSource, "ADV", tSrcEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByText(rSource, "DIS", tSrcEffData);
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByTextOrTag(rSource, "ADVSAV", tSrcEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByTextOrTag(rSource, "DISSAV", tSrcEffData);
		
		local tTrgtEffData = { rTarget = rSource, tFilter = tAttackFilter, tActionTags = rRoll.tActionTags };
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByTextOrTag(rSaveSource, "@ADVSAV", tTrgtEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByTextOrTag(rSaveSource, "@DISSAV", tTrgtEffData);

	elseif rRoll.sType == "skill" then
		bUseModStack = true;
		local tSaveFilter = ActionCore.buildEffectFilter(rRoll);
		local rSaveSource = ActorManager.resolveActor(rRoll.sSource);

		local tSrcEffData = { rTarget = rSaveSource, tFilter = tSaveFilter, tActionTags = rRoll.tActionTags, };
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByText(rSource, "ADV", tSrcEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByText(rSource, "DIS", tSrcEffData);
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByTextOrTag(rSource, "ADVSKILL", tSrcEffData);
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByTextOrTag(rSource, "DISSKILL", tSrcEffData);
	elseif GameSystem.actions and GameSystem.actions[rRoll.sType] and GameSystem.actions[rRoll.sType].bUseModStack then
		bUseModStack = true;
		rRoll.nADV = rRoll.nADV + EffectManager.getCompsCountByText(rSource, "ADV");
		rRoll.nADV = rRoll.nADV - EffectManager.getCompsCountByText(rSource, "DIS");
	end

	if bUseModStack then
		if ModifierManager.getKey("ADV") then
			rRoll.nADV = rRoll.nADV + 1;
		end
		if ModifierManager.getKey("DISADV") then
			rRoll.nADV = rRoll.nADV - 1;
		end
	end

	if rRoll.nADV == 0 then
		return;
	end

	local i = 1;
	local slot = i + 1;
	while rRoll.aDice[i] do
		table.insert(rRoll.aDice, slot, rRoll.aDice[i]);
		i = i + 2;
		slot = i + 1;
	end
end

function onPreResolve(rSource, rTarget, rRoll)
	onPreResolveKelADV(rSource, rTarget, rRoll);

	if _fnOrigOnPreResolve then
		_fnOrigOnPreResolve(rSource, rTarget, rRoll);
	end
end
function onPreResolveKelADV(_, _, rRoll)
	if #(rRoll.aDice or {}) <= 0 then
		return;
	end

	if (rRoll.nADV or 0) > 0 then
		local i = 1;
		local slot = i + 1;
		local sDropped = "";
		while rRoll.aDice[i] do
			if rRoll.aDice[i].result <= rRoll.aDice[slot].result then
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[i].result));
				table.remove(rRoll.aDice, i);
			else
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[slot].result));
				table.remove(rRoll.aDice, slot);
			end
			rRoll.aDice[i].type = "g" .. rRoll.aDice[i].type:sub(2);
			i = i + 1;
			slot = i + 1;
		end
		rRoll.sDesc = StringManager.append(rRoll.sDesc, string.format("[ADV] [DROPPED %s]", sDropped), " ");
		rRoll.aDice.expr = nil;
		rRoll.nTotal = ActionsManager.total(rRoll);
	elseif (rRoll.nADV or 0) < 0 then
		local i = 1;
		local slot = i + 1;
		local sDropped = "";
		while rRoll.aDice[i] do
			if rRoll.aDice[i].result >= rRoll.aDice[slot].result then
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[i].result));
				table.remove(rRoll.aDice, i);
			else
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[slot].result));
				table.remove(rRoll.aDice, slot);
			end
			rRoll.aDice[i].type = "r" .. rRoll.aDice[i].type:sub(2);
			i = i + 1;
			slot = i+1;
		end
		rRoll.sDesc = StringManager.append(rRoll.sDesc, string.format("[DISADV] [DROPPED %s]", sDropped), " ");
		rRoll.aDice.expr = nil;
		rRoll.nTotal = ActionsManager.total(rRoll);
	end
end
