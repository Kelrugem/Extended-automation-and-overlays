-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

-- luacheck: globals TokenManagerKel
-- luacheck: globals clearWounds clearSaves

function onTabletopInit()
    ToolbarManager.registerButton("image_clearwounds",
        {
            sType = "action",
            sIcon = "tool_clearwounds",
            sTooltipRes = "image_tooltip_toolbarclearwounds",
			bHostVisibleOnly = true,
            fnActivate = clearWounds,
        });
    ToolbarManager.registerButton("image_clearsaves",
        {
            sType = "action",
            sIcon = "tool_clearsaves",
            sTooltipRes = "image_tooltip_toolbarclearsaves",
			bHostVisibleOnly = true,
            fnActivate = clearSaves,
        });
end

function clearWounds(c)	
	TokenManagerKel.clearWoundOverlays();
	
	local cImage = WindowManager.callOuterWindowFunction(c.window, "getImage");
	cImage.setFocus();
end

function clearSaves(c)
	TokenManagerKel.clearSaveOverlays();

	local cImage = WindowManager.callOuterWindowFunction(c.window, "getImage");
	cImage.setFocus();
end