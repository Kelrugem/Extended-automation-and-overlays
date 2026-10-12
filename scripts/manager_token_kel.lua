--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- luacheck: globals OOB_MSGTYPE_APPLYSAVEOVERLAY clearSaveOverlay setSaveOverlay handleSaveOverlay updateSaveOverlay
-- luacheck: globals OOB_MSGTYPE_APPLYWOUNDOVERLAY clearWoundOverlay setWoundOverlay handleWoundOverlay updateWoundOverlay

-- The idea of a save overlay is motivated by an extension from Ken L and the following is his changed and modified code basically.
-- Thanks him for providing his ideas and extensions to the community :)

OOB_MSGTYPE_APPLYSAVEOVERLAY = "applyoverlay";
OOB_MSGTYPE_APPLYWOUNDOVERLAY = "applywounds";

function onInit()
	CombatManager.addCombatantFieldChangeHandler("saveclear", "onUpdate", updateSaveOverlay);
	CombatManager.addCombatantFieldChangeHandler("death", "onUpdate", updateWoundOverlay);

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYSAVEOVERLAY, handleSaveOverlay);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYWOUNDOVERLAY, handleWoundOverlay);
end

function clearSaveOverlays()
	if not Session.IsHost then
		return;
	end

	for _,v in pairs(CombatManager.getCombatantNodes()) do
		DB.setValue(v, "saveclear", "number", 0);
	end
end

function setSaveOverlay(vActor, nSaveOverlay)
	if not OptionsManager.isOption("SO", "on") then
		return;
	end
	local rActor = ActorManager.resolveActor(vActor);
	if not rActor then
		return;
	end

	-- Build OOB message to pass to host
	local msgOOB = {
		type = OOB_MSGTYPE_APPLYSAVEOVERLAY,
		sActorPath = ActorManager.getCTNodeName(rActor),
		nSaveOverlay = nSaveOverlay,
	};
	Comm.deliverOOBMessage(msgOOB, "");
end

function handleSaveOverlay(msgOOB)
	local rActor = ActorManager.resolveActor(msgOOB.sActorPath);
	if not rActor then
		return;
	end
	local nodeCT = ActorManager.getCTNode(rActor);
	if not nodeCT then
		return;
	end
	local nSaveOverlay = tonumber(msgOOB.nSaveOverlay) or 0;
	if nSaveOverlay < DB.getValue(nodeCT, "saveclear", 0) then
		DB.setValue(nodeCT, "saveclear", "number", nSaveOverlay);
	end
end

function updateSaveOverlay(nodeField)
	local nodeCT = DB.getParent(nodeField);
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if not tokenCT then
		return;
	end

	local nSaveOverlay = DB.getValue(nodeField, ".", 0);

	local wgt = tokenCT.findWidget("success_kel");
	if wgt then
		wgt.destroy();
	end
	
	local wToken, hToken = tokenCT.getSize();
	local vImage = ImageManager.getImageControl(tokenCT, false);
	if vImage then
		local gridlength = vImage.getGridSize();
		wToken = (wToken/gridlength)*100;
		hToken = (hToken/gridlength)*100;
	else
		local nDU = GameSystem.getDistanceUnitsPerGrid();
		local nSpace = math.ceil(DB.getValue(nodeCT, "space", nDU) / nDU)*100;
		wToken = nSpace;
		hToken = nSpace;
	end
	
	local sIcon;
	if nSaveOverlay == -3 then
		sIcon = "overlay_save_success";
	elseif nSaveOverlay == -2 then
		sIcon = "overlay_save_partial";
	elseif nSaveOverlay == -1 then
		sIcon = "overlay_save_failure";
	else
		-- No overlay
	end
	if sIcon then
		tokenCT.addBitmapWidget({
			name = "success_kel",
			icon = sIcon,
			w = wToken, h = hToken,
		}).bringToFront();
	end
end

function clearWoundOverlays()
	if not Session.IsHost then
		return;
	end

	for _,v in pairs(CombatManager.getCombatantNodes()) do
		DB.setValue(v, "death", "number", 0);
	end
end

function setWoundOverlay(vActor, nWoundOverlay)
	if not OptionsManager.isOption("WO", "on") then
		return;
	end
	local rActor = ActorManager.resolveActor(vActor);
	if not rActor then
		return;
	end
	if EffectManager.hasText(rActor, "noblood", { bSkipConditionals = true, }) then
		return;
	end

	-- Build OOB message to pass to host
	local msgOOB = {
		type = OOB_MSGTYPE_APPLYWOUNDOVERLAY,
		sActorPath = ActorManager.getCTNodeName(rActor),
		nWoundOverlay = nWoundOverlay,
	};
	Comm.deliverOOBMessage(msgOOB, "");
end

function handleWoundOverlay(msgOOB)
	local rActor = ActorManager.resolveActor(msgOOB.sActorPath);
	if not rActor then
		return;
	end
	local nodeCT = ActorManager.getCTNode(rActor);
	if not nodeCT then
		return;
	end

	local nWoundOverlay = tonumber(msgOOB.nWoundOverlay) or 0;
	DB.setValue(nodeCT, "death", "number", nWoundOverlay);
end

function updateWoundOverlay(nodeField)
	local nodeCT = DB.getParent(nodeField);
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	if not tokenCT then
		return;
	end

	local nWoundOverlay = DB.getValue(nodeField, ".", 0);

	local wgt = tokenCT.findWidget("wound_kel");
	if wgt then
		wgt.destroy();
	end

	local wToken, hToken = tokenCT.getSize();
	local vImage = ImageManager.getImageControl(tokenCT, false);
	if vImage then
		local gridlength = vImage.getGridSize();
		wToken = (wToken/gridlength)*100;
		hToken = (hToken/gridlength)*100;
	else
		local nDU = GameSystem.getDistanceUnitsPerGrid();
		local nSpace = math.ceil(DB.getValue(nodeCT, "space", nDU) / nDU)*100;
		wToken = nSpace;
		hToken = nSpace;
	end

	local sIcon;
	if nWoundOverlay == 1 then
		sIcon = "overlay_death";
	elseif nWoundOverlay == 2 then
		sIcon = "overlay_dying";
	elseif nWoundOverlay == 3 then
		sIcon = "overlay_dying_stable";
	elseif nWoundOverlay == 4 then
		sIcon = "overlay_critical";
	elseif nWoundOverlay == 5 then
		sIcon = "overlay_heavy";
	elseif nWoundOverlay == 6 then
		sIcon = "overlay_moderate";
	elseif nWoundOverlay == 7 then
		sIcon = "overlay_wounded";
	elseif nWoundOverlay == 8 then
		sIcon = "overlay_disabled";
	elseif nWoundOverlay == 9 then
		sIcon = "overlay_ko";
	elseif nWoundOverlay == 10 then
		sIcon = "overlay_staggered";
	else
		-- No overlay
	end
	if sIcon then
		tokenCT.addBitmapWidget({
			name = "wound_kel",
			icon = sIcon,
			w = wToken, h = hToken,
		}).bringToFront();
	end
end