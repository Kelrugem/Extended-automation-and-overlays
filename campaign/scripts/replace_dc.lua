--
-- Please see the license file included with this distribution for
-- attribution and copyright information.
--

-- luacheck: globals ActorManager35E
-- luacheck: globals replacedcstatmod

-- KEL For replacement of DC attribute. We need automated Statupdates :)

function onInit()
	local nodeSpell = getDatabaseNode();

	local nodeCreature = DB.getChild(nodeSpell, ".........");
	if ActorManager.isPC(nodeCreature) then
		DB.addHandler(DB.getPath(nodeCreature, "abilities"), "onChildUpdate", self.onStatUpdate);
	else
		DB.addHandler(DB.getPath(nodeCreature, "strength"), "onUpdate", self.onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "dexterity"), "onUpdate", self.onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "constitution"), "onUpdate", self.onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "intelligence"), "onUpdate", self.onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "wisdom"), "onUpdate", self.onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "charisma"), "onUpdate", self.onStatUpdate);
	end

	local nodeSpellClass = DB.getChild(nodeSpell, ".......");
	if nodeSpellClass then
		DB.addHandler(DB.getPath(nodeSpellClass, "dc.ability"), "onUpdate", self.onStatUpdate);
	end

	self.onStatUpdate();
end
function onClose()
	local nodeSpell = getDatabaseNode();

	local nodeCreature = DB.getChild(nodeSpell, ".........");
	if ActorManager.isPC(nodeCreature) then
		DB.removeHandler(DB.getPath(nodeCreature, "abilities"), "onChildUpdate", self.onStatUpdate);
	else
		DB.removeHandler(DB.getPath(nodeCreature, "strength"), "onUpdate", self.self.onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "dexterity"), "onUpdate", self.onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "constitution"), "onUpdate", self.onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "intelligence"), "onUpdate", self.onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "wisdom"), "onUpdate", self.onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "charisma"), "onUpdate", self.onStatUpdate);
	end

	local nodeSpellClass = DB.getChild(nodeSpell, ".......");
	if nodeSpellClass then
		DB.addHandler(DB.getPath(nodeSpellClass, "dc.ability"), "onUpdate", self.onStatUpdate);
	end
end

function onStatUpdate()
	if not replacedcstatmod then
		return;
	end
	local nodeSpell = getDatabaseNode();

	local sAbility = DB.getValue(nodeSpell, "replacedc.ability", "");
	if sAbility ~= "" then
		local nodeCreature = DB.getChild(nodeSpell, ".........");
		local rActor = ActorManager.resolveActor(nodeCreature);
		local nValue = ActorManager35E.getAbilityBonus(rActor, sAbility);
		replacedcstatmod.setValue(nValue);
	else
		local nValue = DB.getValue(nodeSpell, ".......dc.abilitymod", 0);
		replacedcstatmod.setValue(nValue);
	end
end
