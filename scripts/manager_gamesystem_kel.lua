--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	-- GameSystem.actions["fortification"] = { };
	ModifierManager.addModWindowPresets({ { sCategory = "general", tPresets = { "ADV", "DISADV" } } });
	ModifierManager.addKeyExclusionSets({ { "ADV", "DISADV" } });
end
