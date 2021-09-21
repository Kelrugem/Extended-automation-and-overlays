-- KEL For replacement of DC attribute. We need automated Statupdates :)

function onInit()
	onStatUpdate();
	local nodeSpell = getDatabaseNode();
	local nodeSpellClass = DB.getChild(nodeSpell, ".......");
	local nodeCreature = nodeSpell.getChild(".........");
	if ActorManager.isPC(nodeCreature) then
		DB.addHandler(DB.getPath(nodeCreature, "abilities"), "onChildUpdate", onStatUpdate);
	else
		DB.addHandler(DB.getPath(nodeCreature, "strength"), "onUpdate", onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "dexterity"), "onUpdate", onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "constitution"), "onUpdate", onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "intelligence"), "onUpdate", onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "wisdom"), "onUpdate", onStatUpdate);
		DB.addHandler(DB.getPath(nodeCreature, "charisma"), "onUpdate", onStatUpdate);
	end
	-- DB.addHandler(nodeSpellClass.getPath() .. ".dc.ability", "onUpdate", onStatUpdate);
	DB.addHandler(nodeSpellClass.getPath("dc.ability"), "onUpdate", onStatUpdate);
end

function onClose()
	local nodeSpell = getDatabaseNode();
	local nodeSpellClass = DB.getChild(nodeSpell, ".......");
	local nodeCreature = nodeSpell.getChild(".........");
	if ActorManager.isPC(nodeCreature) then
		DB.removeHandler(DB.getPath(nodeCreature, "abilities"), "onChildUpdate", onStatUpdate);
	else
		DB.removeHandler(DB.getPath(nodeCreature, "strength"), "onUpdate", onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "dexterity"), "onUpdate", onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "constitution"), "onUpdate", onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "intelligence"), "onUpdate", onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "wisdom"), "onUpdate", onStatUpdate);
		DB.removeHandler(DB.getPath(nodeCreature, "charisma"), "onUpdate", onStatUpdate);
	end
	DB.addHandler(nodeSpellClass.getPath("dc.ability"), "onUpdate", onStatUpdate);
end

function onStatUpdate()
	if replacedcstatmod then
		local nodeSpell = getDatabaseNode();
		local nodeCreature = nodeSpell.getChild(".........");

		local sAbility = DB.getValue(nodeSpell, "replacedc.ability", "");
		if sAbility ~= "" then
			local rActor = ActorManager.resolveActor(nodeCreature);
			local nValue = ActorManager35E.getAbilityBonus(rActor, sAbility);
			
			replacedcstatmod.setValue(nValue);
		else
			local nValue = DB.getValue(nodeSpell, ".......dc.abilitymod", 0);
			replacedcstatmod.setValue(nValue);
		end
	end
end