-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	-- Set the displays to what should be shown
	setTargetingVisible();
	setActiveVisible();
	setDefensiveVisible();
	setSpacingVisible();
	setEffectsVisible();

	-- Acquire token reference, if any
	linkToken();
	
	-- Set up the PC links
	onLinkChanged();
	onFactionChanged();
	onHealthChanged();
	
	-- Register the deletion menu item for the host
	registerMenuItem(Interface.getString("list_menu_deleteitem"), "delete", 6);
	registerMenuItem(Interface.getString("list_menu_deleteconfirm"), "delete", 6, 7);
	
	-- Handle PFRPG specific changes
	local bPFMode = DataCommon.isPFRPG();
	if bPFMode then
		label_grapple.setValue(Interface.getString("cmb"));
	else
		label_grapple.setValue(Interface.getString("grp"));
	end
end

function updateDisplay()
	local sFaction = friendfoe.getStringValue();

	if DB.getValue(getDatabaseNode(), "active", 0) == 1 then
		name.setFont("sheetlabel");
		nonid_name.setFont("sheetlabel");
		
		active_spacer_top.setVisible(true);
		active_spacer_bottom.setVisible(true);
		
		if sFaction == "friend" then
			setFrame("ctentrybox_friend_active");
		elseif sFaction == "neutral" then
			setFrame("ctentrybox_neutral_active");
		elseif sFaction == "foe" then
			setFrame("ctentrybox_foe_active");
		else
			setFrame("ctentrybox_active");
		end
	else
		name.setFont("sheettext");
		nonid_name.setFont("sheettext");
		
		active_spacer_top.setVisible(false);
		active_spacer_bottom.setVisible(false);
		
		if sFaction == "friend" then
			setFrame("ctentrybox_friend");
		elseif sFaction == "neutral" then
			setFrame("ctentrybox_neutral");
		elseif sFaction == "foe" then
			setFrame("ctentrybox_foe");
		else
			setFrame("ctentrybox");
		end
	end
end

function linkToken()
	local imageinstance = token.populateFromImageNode(tokenrefnode.getValue(), tokenrefid.getValue());
	if imageinstance then
		TokenManager.linkToken(getDatabaseNode(), imageinstance);
	end
end

function onMenuSelection(selection, subselection)
	if selection == 6 and subselection == 7 then
		delete();
	end
end

function delete()
	local node = getDatabaseNode();
	if not node then
		close();
		return;
	end
	
	-- Remember node name
	local sNode = node.getPath();
	
	-- Clear any effects, so that saves aren't triggered when initiative advanced
	effects.reset(false);
	
	-- Clear NPC wounds, so that stabilization rolls aren't triggered when initiative advanced
	local sClass, sRecord = link.getValue();
	if sClass ~= "charsheet" then
		wounds.setValue(0);
		injury.setValue(0);
	end
	
	-- Move to the next actor, if this CT entry is active
	if DB.getValue(node, "active", 0) == 1 then
		CombatManager.nextActor();
	end

	-- Delete the database node and close the window
	local cList = windowlist;
	node.delete();

	-- Update list information (global subsection toggles)
	cList.onVisibilityToggle();
	cList.onEntrySectionToggle();
end

function onLinkChanged()
	-- If a PC, then set up the links to the char sheet
	local sClass, sRecord = link.getValue();
	if sClass == "charsheet" then
		linkPCFields();
		name.setLine(false);
	end
	onIDChanged();
end

function onIDChanged()
	local nodeRecord = getDatabaseNode();
	local sClass = DB.getValue(nodeRecord, "link", "", "");
	if sClass == "npc" then
		local bID = LibraryData.getIDState("npc", nodeRecord, true);
		name.setVisible(bID);
		nonid_name.setVisible(not bID);
		isidentified.setVisible(true);
	else
		name.setVisible(true);
		nonid_name.setVisible(false);
		isidentified.setVisible(false);
	end
end

function onHealthChanged()
	local rActor = ActorManager.resolveActor(getDatabaseNode());
	local _,sStatus,sColor = ActorHealthManager.getHealthInfo(rActor);
	
	wounds.setColor(sColor);
	injury.setColor(sColor);
	status.setValue(sStatus);
	
	local sClass,_ = link.getValue();
	if sClass ~= "charsheet" then
		idelete.setVisibility((sStatus == ActorHealthManager.STATUS_DYING) or (sStatus == ActorHealthManager.STATUS_DEAD));
	end
end

function onFactionChanged()
	-- Update the entry frame
	updateDisplay();

	-- If not a friend, then show visibility toggle
	if friendfoe.getStringValue() == "friend" then
		tokenvis.setVisible(false);
	else
		tokenvis.setVisible(true);
	end
end

function onVisibilityChanged()
	TokenManager.updateVisibility(getDatabaseNode());
	windowlist.onVisibilityToggle();
end

function onActiveChanged()
	setActiveVisible();
end

function linkPCFields()
	local nodeChar = link.getTargetDatabaseNode();
	if nodeChar then
		name.setLink(nodeChar.createChild("name", "string"), true);
		senses.setLink(nodeChar.createChild("senses", "string"), true);

		hp.setLink(nodeChar.createChild("hp.total", "number"));
		hptemp.setLink(nodeChar.createChild("hp.temporary", "number"));
		wounds.setLink(nodeChar.createChild("hp.wounds", "number"));
        injury.setLink(nodeChar.createChild("hp.injury", "number"));
		
		if DataCommon.isPFRPG() then
			type.addSource(DB.getPath(nodeChar, "alignment"), true);
		else
			alignment.setLink(nodeChar.createChild("alignment", "string"));
		end
		type.addSource(DB.getPath(nodeChar, "size"), true);
		type.addSource(DB.getPath(nodeChar, "race"));

		grapple.setLink(nodeChar.createChild("attackbonus.grapple.total", "number"), true);
		
		ac_final.setLink(nodeChar.createChild("ac.totals.general", "number"), true);
		ac_touch.setLink(nodeChar.createChild("ac.totals.touch", "number"), true);
		ac_flatfooted.setLink(nodeChar.createChild("ac.totals.flatfooted", "number"), true);
		cmd.setLink(nodeChar.createChild("ac.totals.cmd", "number"), true);
		
		fortitudesave.setLink(nodeChar.createChild("saves.fortitude.total", "number"), true);
		reflexsave.setLink(nodeChar.createChild("saves.reflex.total", "number"), true);
		willsave.setLink(nodeChar.createChild("saves.will.total", "number"), true);
		
		sr.setLink(nodeChar.createChild("defenses.sr.total", "number"), true);

		init.setLink(nodeChar.createChild("initiative.total", "number"), true);
	end
end

--
-- SECTION VISIBILITY FUNCTIONS
--

function setTargetingVisible()
	local v = false;
	if activatetargeting.getValue() == 1 then
		v = true;
	end

	targetingicon.setVisible(v);
	
	sub_targeting.setVisible(v);
	
	frame_targeting.setVisible(v);

	target_summary.onTargetsChanged();
end

function setActiveVisible()
	local v = false;
	if activateactive.getValue() == 1 then
		v = true;
	end

	local sClass, sRecord = link.getValue();
	local bNPC = (sClass ~= "charsheet");
	if bNPC and active.getValue() == 1 then
		v = true;
	end
	
	activeicon.setVisible(v);

	immediate.setVisible(v);
	immediatelabel.setVisible(v);
	init.setVisible(v);
	initlabel.setVisible(v);
	grapple.setVisible(v);
	label_grapple.setVisible(v);
	speed.setVisible(v);
	speedlabel.setVisible(v);
	
	spacer_active.setVisible(v);
	
	if bNPC then
		attacks.setVisible(v);
		if v and not attacks.getNextWindow(nil) then
			attacks.createWindow();
		end
		attacks_label.setVisible(v);
	else
		attacks.setVisible(false);
		attacks_label.setVisible(false);
	end
	
	frame_active.setVisible(v);
end

function setDefensiveVisible()
	local v = false;
	if activatedefensive.getValue() == 1 then
		v = true;
	end
	
	local bPFMode = DataCommon.isPFRPG();
	
	defensiveicon.setVisible(v);

	ac_final.setVisible(v);
	ac_final_label.setVisible(v);
	ac_touch.setVisible(v);
	ac_touch_label.setVisible(v);
	ac_flatfooted.setVisible(v);
	ac_ff_label.setVisible(v);
	--KEL adding AoO stuff
	aoo.setVisible(v);
	label_aoo.setVisible(v);
	aoomax.setVisible(v);
	label_aoomax.setVisible(v);
	-- END
	
	cmd.setVisible(v and bPFMode);
	cmd_label.setVisible(v and bPFMode);

	fortitudesave.setVisible(v);
	fortitudelabel.setVisible(v);
	reflexsave.setVisible(v);
	reflexlabel.setVisible(v);
	willsave.setVisible(v);
	willlabel.setVisible(v);
	sr.setVisible(v);
	sr_label.setVisible(v);

	specialqualities.setVisible(v);
	specialqualitieslabel.setVisible(v);
	
	frame_defensive.setVisible(v);
end
	
function setSpacingVisible()
	local v = false;
	if activatespacing.getValue() == 1 then
		v = true;
	end

	spacingicon.setVisible(v);
	
	space.setVisible(v);
	spacelabel.setVisible(v);
	reach.setVisible(v);
	reachlabel.setVisible(v);
	
	frame_spacing.setVisible(v);
end

function setEffectsVisible()
	local v = false;
	if activateeffects.getValue() == 1 then
		v = true;
	end
	
	effecticon.setVisible(v);
	
	effects.setVisible(v);
	effects_iadd.setVisible(v);
	for _,w in pairs(effects.getWindows()) do
		w.idelete.setValue(0);
	end

	frame_effects.setVisible(v);

	effect_summary.onEffectsChanged();
end
