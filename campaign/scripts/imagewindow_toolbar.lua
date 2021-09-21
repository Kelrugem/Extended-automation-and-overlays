-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	update(true);

	if Session.IsHost and UtilityManager.isClientFGU() then
		local bShowLockButton = (parentcontrol.window.getClass() ~= "imagewindow");
		h5.setVisible(bShowLockButton);
		locked.setVisible(bShowLockButton);
	end
end

function getImage()
	return parentcontrol.window.image;
end

function update(bInit)
	local image = getImage();
	local bHasTokens = image.hasTokens();
	local sCursorMode = image.getCursorMode();

	if UtilityManager.isClientFGU() then
		h1.setVisible(true);
		toggle_unmask.updateState(sCursorMode);
		toolbar_draw.onValueChanged();

		h4.setVisible(true);
		toggle_shortcut.setValueByBoolean(image.getShortcutState());
		if Session.IsHost then
			toggle_tokenlock.setVisible(bHasTokens);
			toggle_tokenlock.setValueByBoolean(image.getTokenLockState());
			toggle_preview.setVisible(true);
			toggle_preview.setValueByBoolean(image.getPreviewState());
			-- KEL
			h0.setVisible(bHasTokens);
			toolbar_clear_saves.setVisible(bHasTokens);
			toolbar_clear_wounds.setVisible(bHasTokens);
			-- END
		end
	else
		if Session.IsHost then
			toolbar_draw.setVisibility(true);
			toolbar_draw.onValueChanged();
			-- KEL
			h0.setVisible(bHasTokens);
			toolbar_clear_saves.setVisible(bHasTokens);
			toolbar_clear_wounds.setVisible(bHasTokens);
			-- END
			local bShowGridToggle = image.hasGrid();
			h1.setVisible(bShowGridToggle);
			toggle_grid.setVisible(bShowGridToggle);
			local bShowGridToolbar = false;
			if toggle_grid.getValue() > 0 then
				bShowGridToolbar = bShowGridToggle;
			end
			toolbar_grid.setVisibility(bShowGridToolbar);
		end
	end

	h2.setVisible(bHasTokens);
	toggle_select.setVisible(bHasTokens);
	toggle_select.updateState(sCursorMode);
	h3.setVisible(bHasTokens);
	toggle_targetselect.setVisible(bHasTokens);
	toggle_targetselect.updateState(sCursorMode);
	toolbar_targeting.setVisibility(bHasTokens);
end

function onZoomToFitButtonPressed()
	getImage().zoomToFit();
end

function onDrawToolbarValueChanged()
	local sTool = getImage().getCursorMode();
	if sTool == "draw" then
		toolbar_draw.setActive("paint");
	elseif sTool == "erase" then
		toolbar_draw.setActive("erase");
	elseif not UtilityManager.isClientFGU() and sTool == "unmask" then
		toolbar_draw.setActive("unmask");
	else
		toolbar_draw.setActive("");
	end
end

function onDrawToolbarButtonPressed(sID)
	local image = getImage();
	local sTool = image.getCursorMode();

	if sID == "paint" then
		if sTool ~= "draw" then
			image.setCursorMode("draw");
		else
			image.setCursorMode("");
		end
	elseif sID == "erase" then
		if sTool ~= "erase" then
			image.setCursorMode("erase");
		else
			image.setCursorMode("");
		end
	elseif sID == "unmask" then
		if sTool ~= "unmask" then
			image.setMaskEnabled(true);
			image.setCursorMode("unmask");
		else
			image.setCursorMode("");
		end
	end
end

function onGridToolbarButtonPressed(sID)
	local image = getImage();
	local gridsize = image.getGridSize();
	local ox, oy = image.getGridOffset();
	
	if (sID == "gridleft") then
		ox = ox - 1;
		image.setGridOffset(ox, oy);
	elseif (sID == "gridright") then
		ox = ox + 1;
		image.setGridOffset(ox, oy);
	elseif (sID == "gridup") then
		oy = oy - 1;
		image.setGridOffset(ox, oy);
	elseif (sID == "griddown") then
		oy = oy + 1;
		image.setGridOffset(ox, oy);
	elseif (sID == "gridplus") then
		gridsize = gridsize + 1;
		image.setGridSize(gridsize);
	elseif (sID == "gridminus") then
		gridsize = gridsize - 1;
		image.setGridSize(gridsize);
	end
end

function onSelectButtonPressed()
	local image = getImage();
	
	if image.getCursorMode() == "select" then
		image.setCursorMode();
	else
		image.setCursorMode("select");
	end
end

function onTargetSelectButtonPressed()
	local image = getImage();
	
	if image.getCursorMode() == "target" then
		image.setCursorMode();
	else
		image.setCursorMode("target");
	end
end

function onShortcutButtonPressed()
	local image = getImage();
	
	if image.getShortcutState() then
		image.setShortcutState(false);
	else
		image.setShortcutState(true);
	end
end

function onTokenLockButtonPressed()
	local image = getImage();
	
	if image.getTokenLockState() then
		image.setTokenLockState(false);
	else
		image.setTokenLockState(true);
	end
end

function onPreviewButtonPressed()
	local image = getImage();
	
	if image.getPreviewState() then
		image.setPreviewState(false);
	else
		image.setPreviewState(true);
	end
end

function onTargetingToolbarButtonPressed(sID)
	local image = getImage();

	if sID == "clear" then
		TargetingManager.clearTargets(image);
	elseif sID == "friend" then
		TargetingManager.setFactionTargets(image);
	elseif sID == "foe" then
		TargetingManager.setFactionTargets(image, true);
	end
end
