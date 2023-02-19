-- KEL For replacement of DC attribute. We need automated Statupdates :)

function onInit()
	onStatUpdate();
	local nodeSpell = getDatabaseNode();
	local nodeSpellClass = DB.getChild(nodeSpell, ".......");
	local nodeCreature = DB.getChild(nodeSpell, ".........");
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
	
	if nodeSpellClass then
		DB.addHandler(DB.getPath(nodeSpellClass, "dc.ability"), "onUpdate", onStatUpdate);
	end
end

function onClose()
	local nodeSpell = getDatabaseNode();
	local nodeSpellClass = DB.getChild(nodeSpell, ".......");
	local nodeCreature = DB.getChild(nodeSpell, ".........");
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
	
	if nodeSpellClass then
		DB.addHandler(DB.getPath(nodeSpellClass, "dc.ability"), "onUpdate", onStatUpdate);
	end
end

function onStatUpdate()
	if replacedcstatmod then
		local nodeSpell = getDatabaseNode();
		local nodeCreature = DB.getChild(nodeSpell, ".........");

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