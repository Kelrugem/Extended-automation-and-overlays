-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local aFieldMap = {};

function onInit()
	if Session.IsHost then
		DB.addHandler("charsheet.*.classes", "onChildUpdate", linkPCClasses);
		DB.addHandler("charsheet.*.skilllist", "onChildUpdate", linkPCSkills);
		DB.addHandler("charsheet.*.languagelist", "onChildUpdate", linkPCLanguages);
	end
end

function linkPCClasses(nodeClass)
	if not nodeClass then
		return;
	end
	local nodePS = PartyManager.mapChartoPS(nodeClass.getParent());
	if not nodePS then
		return;
	end

	DB.setValue(nodePS, "class", "string", CharManager.getClassLevelSummary(nodeClass.getParent()));
end

function linkPCLanguages(nodeLanguages)
	if not nodeLanguages then
		return;
	end
	local nodePS = PartyManager.mapChartoPS(nodeLanguages.getParent());
	if not nodePS then
		return;
	end
	
	local aLanguages = {};
	
	for _,v in pairs(nodeLanguages.getChildren()) do
		local sName = DB.getValue(v, "name", "");
		if sName ~= "" then
			table.insert(aLanguages, sName);
		end
	end
	table.sort(aLanguages);
	
	local sLanguages = table.concat(aLanguages, ", ");
	DB.setValue(nodePS, "languages", "string", sLanguages);
end

function linkPCSkill(nodeSkill, nodePS, sPSField)
	PartyManager.linkRecordField(nodeSkill, nodePS, "total", "number", sPSField);
end

function linkPCSkills(nodeSkills)
	if not nodeSkills then
		return;
	end
	local nodePS = PartyManager.mapChartoPS(nodeSkills.getParent());
	if not nodePS then
		return;
	end
	
	for _,v in pairs(nodeSkills.getChildren()) do
		local sLabel = DB.getValue(v, "label", ""):lower();

		if sLabel == "spot" then
			linkPCSkill(v, nodePS, "spot");
		elseif sLabel == "listen" then
			linkPCSkill(v, nodePS, "listen");
		elseif sLabel == "search" then
			linkPCSkill(v, nodePS, "search");
		elseif sLabel == "perception" then
			linkPCSkill(v, nodePS, "perception");
		elseif sLabel == "sense motive" then
			linkPCSkill(v, nodePS, "sensemotive");
		
		elseif sLabel == "knowledge" then
			local sSubLabel = DB.getValue(v, "sublabel", ""):lower();
			
			if sSubLabel == "arcana" then
				linkPCSkill(v, nodePS, "arcana");
			elseif sSubLabel == "dungeoneering" then
				linkPCSkill(v, nodePS, "dungeoneering");
			elseif sSubLabel == "local" then
				linkPCSkill(v, nodePS, "klocal");
			elseif sSubLabel == "nature" then
				linkPCSkill(v, nodePS, "nature");
			elseif sSubLabel == "planes" or sSubLabel == "the planes" then
				linkPCSkill(v, nodePS, "planes");
			elseif sSubLabel == "religion" then
				linkPCSkill(v, nodePS, "religion");
			end
		elseif sLabel:sub(1,9) == "knowledge" then
			local sSubLabel = sLabel:sub(10):match("%w[%w%s]*%w");

			if sSubLabel == "arcana" then
				linkPCSkill(v, nodePS, "arcana");
			elseif sSubLabel == "dungeoneering" then
				linkPCSkill(v, nodePS, "dungeoneering");
			elseif sSubLabel == "local" then
				linkPCSkill(v, nodePS, "klocal");
			elseif sSubLabel == "nature" then
				linkPCSkill(v, nodePS, "nature");
			elseif sSubLabel == "planes" or sSubLabel == "the planes" then
				linkPCSkill(v, nodePS, "planes");
			elseif sSubLabel == "religion" then
				linkPCSkill(v, nodePS, "religion");
			end
		
		elseif sLabel == "bluff" then
			linkPCSkill(v, nodePS, "bluff");
		elseif sLabel == "diplomacy" then
			linkPCSkill(v, nodePS, "diplomacy");
		elseif sLabel == "gather information" then
			linkPCSkill(v, nodePS, "gatherinfo");
		elseif sLabel == "intimidate" then
			linkPCSkill(v, nodePS, "intimidate");
		
		elseif sLabel == "acrobatics" then
			linkPCSkill(v, nodePS, "acrobatics");
		elseif sLabel == "climb" then
			linkPCSkill(v, nodePS, "climb");
		elseif sLabel == "heal" then
			linkPCSkill(v, nodePS, "heal");
		elseif sLabel == "jump" then
			linkPCSkill(v, nodePS, "jump");
		elseif sLabel == "survival" then
			linkPCSkill(v, nodePS, "survival");
		
		elseif sLabel == "hide" then
			linkPCSkill(v, nodePS, "hide");
		elseif sLabel == "move silently" then
			linkPCSkill(v, nodePS, "movesilent");
		elseif sLabel == "stealth" then
			linkPCSkill(v, nodePS, "stealth");
		end
	end
end

function linkPCFields(nodePS)
	local sClass, sRecord = DB.getValue(nodePS, "link", "", "");
	if sRecord == "" then
		return;
	end
	local nodeChar = DB.findNode(sRecord);
	if not nodeChar then
		return;
	end
	
	PartyManager.linkRecordField(nodeChar, nodePS, "name", "string");
	PartyManager.linkRecordField(nodeChar, nodePS, "token", "token", "token");

	PartyManager.linkRecordField(nodeChar, nodePS, "race", "string");
	PartyManager.linkRecordField(nodeChar, nodePS, "level", "number");
	PartyManager.linkRecordField(nodeChar, nodePS, "exp", "number");
	PartyManager.linkRecordField(nodeChar, nodePS, "expneeded", "number");

	PartyManager.linkRecordField(nodeChar, nodePS, "senses", "string");
	
	PartyManager.linkRecordField(nodeChar, nodePS, "hp.total", "number", "hptotal");
	PartyManager.linkRecordField(nodeChar, nodePS, "hp.temporary", "number", "hptemp");
	PartyManager.linkRecordField(nodeChar, nodePS, "hp.wounds", "number", "wounds");
	PartyManager.linkRecordField(nodeChar, nodePS, "hp.injury", "number", "injury");
	
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.strength.score", "number", "strength");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.constitution.score", "number", "constitution");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.dexterity.score", "number", "dexterity");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.intelligence.score", "number", "intelligence");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.wisdom.score", "number", "wisdom");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.charisma.score", "number", "charisma");

	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.strength.bonus", "number", "strcheck");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.constitution.bonus", "number", "concheck");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.dexterity.bonus", "number", "dexcheck");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.intelligence.bonus", "number", "intcheck");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.wisdom.bonus", "number", "wischeck");
	PartyManager.linkRecordField(nodeChar, nodePS, "abilities.charisma.bonus", "number", "chacheck");

	PartyManager.linkRecordField(nodeChar, nodePS, "ac.totals.general", "number", "ac");
	PartyManager.linkRecordField(nodeChar, nodePS, "ac.totals.flatfooted", "number", "flatfootedac");
	PartyManager.linkRecordField(nodeChar, nodePS, "ac.totals.touch", "number", "touchac");
	PartyManager.linkRecordField(nodeChar, nodePS, "ac.totals.cmd", "number", "cmd");
	
	PartyManager.linkRecordField(nodeChar, nodePS, "saves.fortitude.total", "number", "fortitude");
	PartyManager.linkRecordField(nodeChar, nodePS, "saves.reflex.total", "number", "reflex");
	PartyManager.linkRecordField(nodeChar, nodePS, "saves.will.total", "number", "will");
	
	PartyManager.linkRecordField(nodeChar, nodePS, "defenses.damagereduction", "string", "dr");
	PartyManager.linkRecordField(nodeChar, nodePS, "defenses.sr.total", "number", "sr");

	linkPCClasses(nodeChar.getChild("classes"));
	linkPCSkills(nodeChar.getChild("skilllist"));
	linkPCLanguages(nodeChar.getChild("languagelist"));
end

--
-- DROP HANDLING
--

function addEncounter(nodeEnc)
	if not nodeEnc then
		return;
	end
	
	local nodePSEnc = DB.createChild("partysheet.encounters");
	DB.copyNode(nodeEnc, nodePSEnc);
end

function addQuest(nodeQuest)
	if not nodeQuest then
		return;
	end
	
	local nodePSQuest = DB.createChild("partysheet.quests");
	DB.copyNode(nodeQuest, nodePSQuest);
end

--
-- XP DISTRIBUTION
--

function awardQuestsToParty(nodeEntry)
	local nXP = 0;
	if nodeEntry then
		if DB.getValue(nodeEntry, "xpawarded", 0) == 0 then
			nXP = DB.getValue(nodeEntry, "xp", 0);
			DB.setValue(nodeEntry, "xpawarded", "number", 1);
		end
	else
		for _,v in pairs(DB.getChildren("partysheet.quests")) do
			if DB.getValue(v, "xpawarded", 0) == 0 then
				nXP = nXP + DB.getValue(v, "xp", 0);
				DB.setValue(v, "xpawarded", "number", 1);
			end
		end
	end
	if nXP ~= 0 then
		awardXP(nXP);
	end
end

function awardEncountersToParty(nodeEntry)
	local nXP = 0;
	if nodeEntry then
		if DB.getValue(nodeEntry, "xpawarded", 0) == 0 then
			nXP = DB.getValue(nodeEntry, "exp", 0);
			DB.setValue(nodeEntry, "xpawarded", "number", 1);
		end
	else
		for _,v in pairs(DB.getChildren("partysheet.encounters")) do
			if DB.getValue(v, "xpawarded", 0) == 0 then
				nXP = nXP + DB.getValue(v, "exp", 0);
				DB.setValue(v, "xpawarded", "number", 1);
			end
		end
	end
	if nXP ~= 0 then
		awardXP(nXP);
	end
end

function awardXP(nXP) 
	-- Determine members of party
	local aParty = {};
	for _,v in pairs(DB.getChildren("partysheet.partyinformation")) do
		local sClass, sRecord = DB.getValue(v, "link");
		if sClass == "charsheet" and sRecord then
			local nodePC = DB.findNode(sRecord);
			if nodePC then
				local sName = DB.getValue(v, "name", "");
				table.insert(aParty, { name = sName, node = nodePC } );
			end
		end
	end

	-- Determine split
	local nAverageSplit;
	if nXP >= #aParty then
		nAverageSplit = math.floor((nXP / #aParty) + 0.5);
	else
		nAverageSplit = 0;
	end
	local nFinalSplit = math.max((nXP - ((#aParty - 1) * nAverageSplit)), 0);
	
	-- Award XP
	for _,v in ipairs(aParty) do
		local nAmount;
		if k == #aParty then
			nAmount = nFinalSplit;
		else
			nAmount = nAverageSplit;
		end
		
		if nAmount > 0 then
			local nNewAmount = DB.getValue(v.node, "exp", 0) + nAmount;
			DB.setValue(v.node, "exp", "number", nNewAmount);
		end

		v.given = nAmount;
	end
	
	-- Output results
	local msg = {font = "msgfont"};
	msg.icon = "xp";
	for _,v in ipairs(aParty) do
		msg.text = "[" .. v.given .. " XP] -> " .. v.name;
		Comm.deliverChatMessage(msg);
	end

	msg.icon = "portrait_gm_token";
	msg.text = Interface.getString("ps_message_xpaward") .. " (" .. nXP .. ")";
	Comm.deliverChatMessage(msg);
end

function awardXPtoPC(nXP, nodePC)
	local nCharXP = DB.getValue(nodePC, "exp", 0);
	nCharXP = nCharXP + nXP;
	DB.setValue(nodePC, "exp", "number", nCharXP);
							
	local msg = {font = "msgfont"};
	msg.icon = "xp";
	msg.text = "[" .. nXP .. " XP] -> " .. DB.getValue(nodePC, "name");
	Comm.deliverChatMessage(msg, "");

	local sOwner = nodePC.getOwner();
	if (sOwner or "") ~= "" then
		Comm.deliverChatMessage(msg, sOwner);
	end
end
