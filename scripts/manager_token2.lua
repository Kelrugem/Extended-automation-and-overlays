-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
-- The idea of a save overlay is motivated by an extension from Ken L and the following is his changed and modified code basically. Thanks him for providing his ideas and extensions to the community :) 


OOB_MSGTYPE_APPLYOVERLAY = "applyoverlay";
OOB_MSGTYPE_APPLYWOUNDS = "applywounds";

function onInit()
	-- KEL For StrainInjury the first line extra
	TokenManager.addDefaultHealthFeatures(getHealthInfo, {"injury"});
	TokenManager.addEffectTagIconSimple("NIFT", "");
	TokenManager.addEffectTagIconSimple("NIF", "");
	TokenManager.addEffectTagIconSimple("IFTAG", "");
	TokenManager.addEffectTagIconSimple("NIFTAG", "");
	-- Overlay
    DB.addHandler("combattracker.list.*.saveclear", "onUpdate", updateSaveOverlay);
    DB.addHandler("combattracker.list.*.death", "onUpdate", updateDeathOverlay);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYOVERLAY, handleApplyOverlay);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYWOUNDS, handleApplyWounds);
end

function getHealthInfo(nodeCT)
	local rActor = ActorManager.resolveActor(nodeCT);
	return ActorHealthManager.getTokenHealthInfo(rActor);
end

function setSaveOverlay(nodeCT, success, erase)
	local sOptSO = OptionsManager.getOption("SO");
	if erase then
		local saveclearNode = nodeCT.createChild("saveclear","number"); 
		if saveclearNode then
			saveclearNode.setValue(success);
		end
	elseif sOptSO == "on" then
		if nodeCT then
			if Session.IsHost then
				local saveclearNode = nodeCT.createChild("saveclear","number"); 
				if saveclearNode then
					if success < getSaveOverlay(nodeCT) then
						saveclearNode.setValue(success); 
					end
				end
			else
				local msgOOB = {};
				msgOOB.type = OOB_MSGTYPE_APPLYOVERLAY;
				local rSource = ActorManager.resolveActor(nodeCT);
				msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
				
				msgOOB.savenumber = success;
				Comm.deliverOOBMessage(msgOOB, "");
			end
		end
	end
end

function handleApplyOverlay(msgOOB)
	local success = tonumber(msgOOB.savenumber);
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local nodeCT = ActorManager.getCTNode(rSource);
	
	if nodeCT then
		local saveclearNode = nodeCT.createChild("saveclear","number"); 
		if saveclearNode then
			if success < getSaveOverlay(nodeCT) then
				saveclearNode.setValue(success); 
			end
		end
	end
end

function getSaveOverlay(nodeCT)
	if nodeCT then
		local saveoverlayNode = nodeCT.getChild("saveclear","number"); 
		if saveoverlayNode then
			return saveoverlayNode.getValue(); 
		end
	end
end

function updateSaveOverlay(nodeField)
	local nodeCT = nodeField.getParent();
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	local success = nodeField.getValue(); 
	local widgetSuccess;

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
		widgetSuccess = tokenCT.findWidget("success1");
		if widgetSuccess then widgetSuccess.destroy() end
		if success == -3 then 
			widgetSuccess = tokenCT.addBitmapWidget(); 
			widgetSuccess.setName("success1"); 
			widgetSuccess.bringToFront(); 
			widgetSuccess.setBitmap("overlay_save_success"); 
			widgetSuccess.setSize(math.floor(wToken*1), math.floor(hToken*1)); 
		elseif success == -2 then
			widgetSuccess = tokenCT.addBitmapWidget(); 
			widgetSuccess.setName("success1"); 
			widgetSuccess.bringToFront(); 
			widgetSuccess.setBitmap("overlay_save_partial"); 
			widgetSuccess.setSize(math.floor(wToken*1), math.floor(hToken*1)); 
		elseif success == -1 then
			widgetSuccess = tokenCT.addBitmapWidget(); 
			widgetSuccess.setName("success1"); 
			widgetSuccess.bringToFront(); 
			widgetSuccess.setBitmap("overlay_save_failure"); 
			widgetSuccess.setSize(math.floor(wToken*1), math.floor(hToken*1)); 
		else
			-- No overlay
		end
	end
end

function setDeathOverlay(nodeCT, death, erase)
	local sOptWO = OptionsManager.getOption("WO");
	if erase then
		local deathNode = nodeCT.createChild("death","number"); 
		if deathNode then
			deathNode.setValue(death);
		end
	elseif sOptWO == "on" then
		if nodeCT then
			if Session.IsHost then
				local deathNode = nodeCT.createChild("death","number"); 
				if deathNode then
					deathNode.setValue(death);
				end
			else
				local msgOOB = {};
				msgOOB.type = OOB_MSGTYPE_APPLYWOUNDS;
				local rSource = ActorManager.resolveActor(nodeCT);
				msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
				
				msgOOB.woundsnumber = death;
				Comm.deliverOOBMessage(msgOOB, "");
			end
		end
	end
end

function handleApplyWounds(msgOOB)
	local death = tonumber(msgOOB.woundsnumber);
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local nodeCT = ActorManager.getCTNode(rSource);
	
	if nodeCT then
		local deathNode = nodeCT.createChild("death","number"); 
		if deathNode then
			deathNode.setValue(death);
		end
	end
end

function updateDeathOverlay(nodeField)
	local nodeCT = nodeField.getParent();
	local tokenCT = CombatManager.getTokenFromCT(nodeCT);
	local deathvalue = nodeField.getValue(); 
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