-- KEL add counter to hasEffect
function hasEffect(rActor, sEffect, rTarget, bTargetedOnly, bIgnoreEffectTargets, rEffectSpell)
	if not sEffect or not rActor then
		return false;
	end
	local sLowerEffect = sEffect:lower();
	
	-- Iterate through each effect
	local aMatch = {};
	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
		local nActive = DB.getValue(v, "isactive", 0);
		if nActive ~= 0 then
			-- Parse each effect label
			local sLabel = DB.getValue(v, "label", "");
			local bTargeted = EffectManager.isTargetedEffect(v);
			-- KEL making conditions work with IFT etc.
			local bIFT = false;
			local aEffectComps = EffectManager.parseEffect(sLabel);

			-- Iterate through each effect component looking for a type match
			local nMatch = 0;
			for kEffectComp, sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = EffectManager35E.parseEffectComp(sEffectComp);
				-- Check conditionals
				-- KEL Adding TAG for SIMMUNE
				if rEffectComp.type == "IF" then
					if not EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "NIF" then
					if EffectManager35E.checkConditional(rActor, v, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "IFT" then
					if not rTarget then
						break;
					end
					if not EffectManager35E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
						break;
					end
					bIFT = true;
				elseif rEffectComp.type == "NIFT" then
					if rActor.aTargets and not rTarget then
						-- if ( #rActor.aTargets[1] > 0 ) and not rTarget then
						break;
						-- end
					end
					if EffectManager35E.checkConditional(rTarget, v, rEffectComp.remainder, rActor) then
						break;
					end
					if rTarget then
						bIFT = true;
					end
				elseif rEffectComp.type == "IFTAG" then
					if not rEffectSpell then
						break;
					elseif not EffectManager35E.checkTagConditional(rActor, v, rEffectComp.remainder, rEffectSpell) then
						break;
					end
				elseif rEffectComp.type == "NIFTAG" then
					if EffectManager35E.checkTagConditional(rActor, v, rEffectComp.remainder, rEffectSpell) then
						break;
					end
				
				-- Check for match
				elseif rEffectComp.original:lower() == sLowerEffect then
					if bTargeted and not bIgnoreEffectTargets then
						if EffectManager.isEffectTarget(v, rTarget) then
							nMatch = kEffectComp;
						end
					elseif bTargetedOnly and bIFT then
						nMatch = kEffectComp;
					elseif not bTargetedOnly then
						nMatch = kEffectComp;
					end
				end
				
			end
			
			-- If matched, then remove one-off effects
			if nMatch > 0 then
				if nActive == 2 then
					DB.setValue(v, "isactive", "number", 1);
				else
					table.insert(aMatch, v);
					local sApply = DB.getValue(v, "apply", "");
					if sApply == "action" then
						EffectManager.notifyExpire(v, 0);
					elseif sApply == "roll" then
						EffectManager.notifyExpire(v, 0, true);
					elseif sApply == "single" then
						EffectManager.notifyExpire(v, nMatch, true);
					end
				end
			end
		end
	end
	
	if #aMatch > 0 then
		return true, #aMatch;
	end
	return false, 0;
end

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
	local aTargeting = OldgetTargeting(rSource, rTarget, sDragType, rRolls);
	-- KEL Adding target informations to rSource, too
	if rSource then
		rSource.aTargets = false;
		if (#aTargeting[1] > 0) then
			rSource.aTargets = true;
		end
	end
	
	return aTargeting;
end

function roll(rSource, vTargets, rRoll, bMultiTarget)
	rRoll.originaldicenumber = #rRoll.aDice or 0;
	if #rRoll.aDice > 0 then
		local bAdvantage, nAdvantage = hasEffect(rSource, "keladvantage", nil, false, false, rRoll.tags);
		local bDisAdvantage, nDisAdvantage = hasEffect(rSource, "keldisadvantage", nil, false, false, rRoll.tags);
		
		if bAdvantage or bDisAdvantage then
			if nAdvantage > nDisAdvantage then
				rRoll.adv = "true";
			elseif nDisAdvantage > nAdvantage then
				rRoll.disadv = "true";
			end
		end
		if ( rRoll.adv == "true" ) then
			local i = 1;
			local slot = i + 1;
			while rRoll.aDice[i] do
				table.insert(rRoll.aDice, slot, rRoll.aDice[i]);
				i = i + 2;
				slot = i+1;
			end
		elseif ( rRoll.disadv == "true" ) then
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
	if #rRoll.aDice > 0 then
		if rRoll.adv == "true" then
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
		elseif rRoll.disadv == "true" then
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
		end
	end
	OldresolveAction(rSource, rTarget, rRoll);
end

function total(rRoll)
	local nTotal = 0;
	local corrector = {};
	local j = 1;
	for _,v in ipairs(rRoll.aDice) do
		-- KEL Removing bUseFGUDiceValues because it is always true for us (otherwise compatibility nasty)
		if v.value then
			corrector[j] = v.value;
		else
			corrector[j] = v.result;
		end
		j = j+1;
	end
	if rRoll.originaldicenumber then
		rRoll.originaldicenumber = tonumber(rRoll.originaldicenumber);
		if #rRoll.aDice > rRoll.originaldicenumber then
			if rRoll.adv == "true" then
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
			elseif rRoll.disadv == "true" then
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