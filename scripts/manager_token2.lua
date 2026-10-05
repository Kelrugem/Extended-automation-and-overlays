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

function setDeathOverlay(nodeCT, death, erase)
	local sOptWO = OptionsManager.getOption("WO");
	if erase then
		local deathNode = DB.createChild(nodeCT, "death","number"); 
		if deathNode then
			deathNode.setValue(death);
		end
	elseif sOptWO == "on" then
		if nodeCT then
			local rSource = ActorManager.resolveActor(nodeCT);
			-- KEL we have to stop the loop via manager-actor -> Overlay -> EffectManager (bloodied...)
			if not EffectManager35E.hasEffectCondition(rSource, "noblood", "", true) then
				if Session.IsHost then
					local deathNode = DB.createChild(nodeCT, "death","number"); 
					if deathNode then
						deathNode.setValue(death);
					end
				else
					local msgOOB = {};
					msgOOB.type = OOB_MSGTYPE_APPLYWOUNDS;
					msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
					
					msgOOB.woundsnumber = death;
					Comm.deliverOOBMessage(msgOOB, "");
				end
			end
		end
	end
end

function handleWoundOverlay(msgOOB)
	local death = tonumber(msgOOB.woundsnumber);
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local nodeCT = ActorManager.getCTNode(rSource);
	
	if nodeCT then
		local deathNode = DB.createChild(nodeCT, "death","number"); 
		if deathNode then
			deathNode.setValue(death);
		end
	end
end

function updateWoundOverlay(nodeField)
	local nodeCT = DB.getParent(nodeField);
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	local deathvalue = DB.getValue(nodeField); 
	local widgetDeath;

	if tokenCT then
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
		widgetDeath = tokenCT.findWidget("death1");
		if widgetDeath then widgetDeath.destroy() end

		if deathvalue == 1 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_death"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1)); 
		elseif deathvalue == 2 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_dying"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 3 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_dying_stable"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 4 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_critical"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 5 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_heavy"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 6 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_moderate"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 7 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_wounded"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 8 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_disabled"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 9 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_ko"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		elseif deathvalue == 10 then 
			widgetDeath = tokenCT.addBitmapWidget(); 
			widgetDeath.setName("death1"); 
			widgetDeath.bringToFront(); 
			widgetDeath.setBitmap("overlay_staggered"); 
			widgetDeath.setSize(math.floor(wToken*1), math.floor(hToken*1));
		else
			-- No overlay
		end
	end
end