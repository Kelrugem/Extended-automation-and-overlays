--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- luacheck: globals ActorManager35E SpellManager SpellManagerAC
-- luacheck: globals resetSpells resetShortSpells resetPrepared
-- luacheck: globals getActionAbilityBonus
-- luacheck: globals addSpellCastAction getSpellAction

local _fnOrigAddSpellCastAction;
local _fnOrigGetSpellAction;
local _fnOrigGetActionHealText;

local tSpellsets = { "spellset" };

-- Compatiblity check for Advanced Charsheet and several spellsets
function onInit()
	SpellManager.resetSpells = resetSpells;
	SpellManager.resetPrepared = resetPrepared;

	SpellManager.getActionAbilityBonus = getActionAbilityBonus;
	
	-- SpellManager.onSpellAction = onSpellAction;

	_fnOrigGetPowerTags = SpellManager.getPowerTags;
	SpellManager.getPowerTags = getPowerTags;

	_fnOrigAddSpellCastAction = SpellManager.addSpellCastAction;
	SpellManager.addSpellCastAction = addSpellCastAction;

	_fnOrigGetSpellAction = SpellManager.getSpellAction;
	SpellManager.getSpellAction = getSpellAction;
	
	_fnOrigGetActionHealText = SpellManager.getActionHealText;
	SpellManager.getActionHealText = getActionHealText;

	if SpellManagerAC then
		tSpellsets = { "spellset", "weaponspellset", "itemspellset", "otherspellset" };
	end
end

-- KEL adding nomnom and short rest reset (also some change in manager_combat2 stored in _combat3)
function resetSpells(nodeCaster)
	for _,sSpellset in ipairs(tSpellsets) do
		for _,nodeSpellClass in ipairs(DB.getChildList(nodeCaster, sSpellset)) do
			DB.setValue(nodeSpellClass, "pointsused", "number", 0);

			for _,nodeLevel in ipairs(DB.getChildList(nodeSpellClass, "levels")) do
				for _,nodeSpell in ipairs(DB.getChildList(nodeLevel, "spells")) do
					-- KEL Beware the actions of one spell contain all actions, also damage and other casts and so on
					local bSleep = true;
					for _,nodeAction in ipairs(DB.getChildList(nodeSpell, "actions")) do
						if DB.getValue(nodeAction, "usereset", "") == "consumable" then
							bSleep = false;
						end
					end
					if bSleep then
						DB.setValue(nodeSpell, "cast", "number", 0);
					end
				end
			end
		end
	end
end

function resetShortSpells(rActor)
	local nodeCaster = ActorManager.getCreatureNode(rActor);
	if not nodeCaster then
		return;
	end
	for _,sSpellset in ipairs(tSpellsets) do
		for _,nodeSpellClass in ipairs(DB.getChildList(nodeCaster, sSpellset)) do
			for _,nodeLevel in ipairs(DB.getChildList(nodeSpellClass, "levels")) do
				for _,nodeSpell in ipairs(DB.getChildList(nodeLevel, "spells")) do
					-- KEL Beware the actions of one spell contain all actions, also damage and other casts and so on
					local bSleep = false;
					for _,nodeAction in ipairs(DB.getChildList(nodeSpell, "actions")) do
						if DB.getValue(nodeAction, "usereset", "") == "shortrest" then
							bSleep = true;
						end
					end
					if bSleep then
						DB.setValue(nodeSpell, "cast", "number", 0);
					end
				end
			end
		end
	end
end

-- END

-- Iterate through each spell to reset, KEL add compatibility tSpellsets
function resetPrepared(nodeCaster)
	for _,sSpellset in ipairs(tSpellsets) do
		for _,nodeSpellClass in ipairs(DB.getChildList(nodeCaster, sSpellset)) do
			for _,nodeLevel in ipairs(DB.getChildList(nodeSpellClass, "levels")) do
				for _,nodeSpell in ipairs(DB.getChildList(nodeLevel, "spells")) do
					DB.setValue(nodeSpell, "prepared", "number", 0);
				end
			end
		end
	end
end

-- KEL Adding extra tags
function getPowerTags(nodePower)
	if not nodePower then
		return {};
	end
	
	local tPowerTags = _fnOrigGetPowerTags(nodePower);
	
	local sSave = DB.getValue(nodePower, "save", ""):lower();
	local sSR = DB.getValue(nodePower, "sr", ""):lower();
	
	if sSave:match("harmless") or sSR:match("harmless") then
		table.insert(tPowerTags, "harmless");
	end
	if sSave:match("object") or sSR:match("object") then
		table.insert(tPowerTags, "object");
	end
	if sSave:match("disbelief") then
		table.insert(tPowerTags, "disbelief");
	end
	
	return tPowerTags;
end

function getActionAbilityBonus(nodeAction)
	local nodeSpellClass = DB.getChild(nodeAction, ".......");
	-- KEL comp with Zarestia
	if not nodeSpellClass then
		return 0;
	end
	-- KEL Replace DC
	local sAbility = DB.getValue(nodeSpellClass, "dc.ability", "");
	local sReplace = DB.getValue(nodeAction, "replacedc.ability", "");
	if sReplace ~= "" then
		sAbility = sReplace;
	end
	-- END
	local rActor = ActorManager.resolveActor(DB.getChild(nodeSpellClass, "..."));
	return ActorManager35E.getAbilityBonus(rActor, sAbility);
end

function getActionHealText(nodeAction)
	local sHeal = _fnOrigGetActionHealText(nodeAction);
	
	-- KEL: bmos adding nonlethal healing
	if DB.getValue(nodeAction, "healtype", "") == "nl" then
		sHeal = sHeal .. " nonlethal";
	end
	
	return sHeal;
end
-- KEL Replace DC
function addSpellCastAction(nodeSpell)
	local nodeAction = _fnOrigAddSpellCastAction(nodeSpell);
	if not nodeAction then
		return;
	end

	DB.setValue(nodeAction, "replacedcstatmod", "number", DB.getValue(nodeAction, ".......dc.abilitymod", 0));
end
-- KEL CL and replace DC
function getSpellAction(rActor, nodeAction, sSubRoll)
	local tPowerTags = SpellManager.getPowerTags(DB.getChild(nodeAction, "..."));

	local nCLMod = EffectManager.getBonusMod(rActor, "CL", { tActionTags = tPowerTags });
	local nOrigCL = DB.getValue(nodeAction, ".......cl", 0)
	if nCLMod ~= 0 then
		DB.setValue(nodeAction, ".......cl", "number", nOrigCL + nCLMod);
	end

	local rAction = _fnOrigGetSpellAction(rActor, nodeAction, sSubRoll);

	if nCLMod ~= 0 then
		DB.setValue(nodeAction, ".......cl", "number", nOrigCL);
	end

	if not rAction then
		return;
	end
	
	-- Save overlay for miss chances
	rAction.spell = true;
	
	if rAction.type == "cast" then
		local sReplace = DB.getValue(nodeAction, "replacedc.ability", "");
		if sReplace ~= "" then
			rAction.dcstat = sReplace;
		end
	end
	
	-- KEL adding ranged descriptors of the cast action
	if rAction.type == "damage" then
		local rFirstCastAction = SpellManager.getFirstCastAction(nodeAction);
		if rFirstCastAction.range and not rAction.range then
			rAction.range = rCastAction.range;
		end
	end

	return rAction;
end

-- KEL get first cast action to extract range, etc
function getFirstCastAction(nodeAction)
	local rCastAction = {};
	-- KEL If multiple cast actions: Important that all cast actions have the same tags? Also adding ranges
	local nodeSpellActions = DB.getChildList(nodeAction, "..")	
	for _, v in ipairs(nodeSpellActions) do
		if DB.getValue(v, "type") == "cast" then
			rCastAction = SpellManager.getSpellAction(rActor, v);
			break;
		end
	end
	return rCastAction;
end
-- END