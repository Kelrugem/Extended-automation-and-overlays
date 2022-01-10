-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	update(true);

	if Session.IsHost then
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
