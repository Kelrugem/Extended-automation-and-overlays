-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local _fnOrigGetRoll;

function onInit()
	_fnOrigGetRoll = ActionHealD20.getRoll;
	ActionHealD20.getRoll = getRoll;
end

function getRoll(rActor, rAction)
	local rRoll = _fnOrigGetRoll(rActor, rAction);
	if rRoll then
		-- KEL and bmos adding nonlethal healing
		-- Handle strain damage
		if rAction.subtype == "nl" then
			rRoll.sDesc = rRoll.sDesc .. " [NL]";
		end
		-- END
	end
	return rRoll;
end
