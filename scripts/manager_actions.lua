function onInit()
	OldgetTargeting = ActionsManager.getTargeting;
	ActionsManager.getTargeting = getTargeting;
	
	Oldroll = ActionsManager.roll;
	ActionsManager.roll = roll;
	
	OldresolveAction = ActionsManager.resolveAction;
	ActionsManager.resolveAction = resolveAction;
	
	ActionsManager.total = total;
end

function getTargeting(rSource, rTarget, sDragType, rRolls)
	local tTargetGroups = OldgetTargeting(rSource, rTarget, sDragType, rRolls);
	-- KEL Adding target informations to rSource, too
	if rSource then
		rSource.aTargets = false;
		if (#tTargetGroups[1] > 0) then
			rSource.aTargets = true;
		end
	end
	
	return tTargetGroups;
end

function roll(rSource, vTargets, rRoll, bMultiTarget)
	if rRoll and rRoll.aDice then
		if #(rRoll.aDice) > 0 then
			rRoll.nOriginaldicenumber = #rRoll.aDice;
		else
			rRoll.nOriginaldicenumber = 0;
		end
	else
		rRoll.nOriginaldicenumber = 0;
	end
	if rRoll.nOriginaldicenumber ~= 0 then
		local _, nAdvantage = EffectManager35E.hasEffect(rSource, "keladvantage", nil, false, false, rRoll.tags);
		local _, nDisAdvantage = EffectManager35E.hasEffect(rSource, "keldisadvantage", nil, false, false, rRoll.tags);
		
		rRoll.nAdv = ( rRoll.nAdv or 0 ) + nAdvantage - nDisAdvantage;
		
		if ModifierManager.getKey("ADV") then
			rRoll.nAdv = 1;
		elseif ModifierManager.getKey("DISADV") then
			rRoll.nAdv = -1;
		end
		
		if rRoll.nAdv ~= 0 then
			local i = 1;
			local slot = i + 1;
			while rRoll.aDice[i] do
				table.insert(rRoll.aDice, slot, rRoll.aDice[i]);
				i = i + 2;
				slot = i+1;
			end
		end
	end
	Oldroll(rSource, vTargets, rRoll, bMultiTarget);
end 

function resolveAction(rSource, rTarget, rRoll)
	if rRoll and rRoll.aDice and ( #rRoll.aDice > 0 ) then
		
		rRoll.nAdv = rRoll.nAdv or 0;
		
		if rRoll.nAdv > 0 then
			local i = 1;
			local slot = i+1;
			local sDropped = "";
			while rRoll.aDice[i] do
				if rRoll.aDice[i].result <= rRoll.aDice[slot].result then
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[i].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[i].result
					end
					table.remove(rRoll.aDice, i);
				else
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[slot].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[slot].result
					end
					table.remove(rRoll.aDice, slot);
				end
				rRoll.aDice[i].type = "g" .. string.sub(rRoll.aDice[i].type, 2);
				i = i + 1;
				slot = i+1;
			end
			rRoll.sDesc = rRoll.sDesc .. " [ADV]" .. " [DROPPED " .. sDropped .. "]";
			rRoll.aDice.expr = nil;
		elseif rRoll.nAdv < 0 then
			local i = 1;
			local slot = i+1;
			local sDropped = "";
			while rRoll.aDice[i] do
				if rRoll.aDice[i].result >= rRoll.aDice[slot].result then
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[i].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[i].result
					end
					table.remove(rRoll.aDice, i);
				else
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[slot].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[slot].result
					end
					table.remove(rRoll.aDice, slot);
				end
				rRoll.aDice[i].type = "r" .. string.sub(rRoll.aDice[i].type, 2);
				i = i + 1;
				slot = i+1;
			end
			rRoll.sDesc = rRoll.sDesc .. " [DISADV]" .. " [DROPPED " .. sDropped .. "]";
			rRoll.aDice.expr = nil;
		end
	end
	OldresolveAction(rSource, rTarget, rRoll);
end

function total(rRoll)
	if Utility.getDiceTotal then
		return Utility.getDiceTotal(rRoll.aDice) + rRoll.nMod;
	end
	
	local nTotal = 0;
	local corrector = {};
	local j = 1;
	for _,v in ipairs(rRoll.aDice) do
		if not v.dropped then
			if v.value then
				corrector[j] = v.value;
			else
				corrector[j] = v.result;
			end
			j = j+1;
		end
	end
	if rRoll.nOriginaldicenumber then
		if rRoll.aDice and ( #rRoll.aDice > rRoll.nOriginaldicenumber ) then
		
			rRoll.nAdv = rRoll.nAdv or 0;
			
			if rRoll.nAdv > 0 then
				local i = 1;
				local slot = i+1;
				while corrector[i] do
					if corrector[i] <= corrector[slot] then
						table.remove(corrector, i);
					else
						table.remove(corrector, slot);
					end
					i = i + 1;
					slot = i+1;
				end
			elseif rRoll.nAdv < 0 then
				local i = 1;
				local slot = i+1;
				while corrector[i] do
					if corrector[i] >= corrector[slot] then
						table.remove(corrector, i);
					else
						table.remove(corrector, slot);
					end
					i = i + 1;
					slot = i+1;
				end
			end
		end
	end
	for i = 1, #corrector do
		nTotal = nTotal + corrector[i];
	end
	nTotal = nTotal + rRoll.nMod;
	
	return nTotal;
end