-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	if Session.IsHost then
		registerMenuItem(Interface.getString("menu_rest"), "lockvisibilityon", 7);
		registerMenuItem(Interface.getString("menu_restshort"), "pointer_cone", 7, 8);
		registerMenuItem(Interface.getString("menu_restovernight"), "pointer_circle", 7, 6);
	end

	if not minisheet and Session.IsLocal then
		portrait.setVisible(false);
		localportrait.setVisible(true);
	end
end

function onMenuSelection(selection, subselection)
	if selection == 7 then
		if subselection == 8 then
			local nodeChar = getDatabaseNode();
			ChatManager.Message(Interface.getString("message_restshort"), true, ActorManager.resolveActor(nodeChar));
			-- KEL adding short rest reset
			SpellManager.resetShortSpells(nodeChar);
			-- END
		elseif subselection == 6 then
			local nodeChar = getDatabaseNode();
			ChatManager.Message(Interface.getString("message_restovernight"), true, ActorManager.resolveActor(nodeChar));
			CharManager.rest(nodeChar);
		end
	end
end
