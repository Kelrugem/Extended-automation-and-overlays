-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	OldnextActor = CombatManager.nextActor;
	CombatManager.nextActor = nextActor;
	
	OldnextRound = CombatManager.nextRound;
	CombatManager.nextRound = nextRound;
end

function nextActor(bSkipBell, bNoRoundAdvance)
	if not Session.IsHost then
		return;
	end
	
	OldnextActor(bSkipBell, bNoRoundAdvance);
	-- KEL Clear saves
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		TokenManager3.setSaveOverlay(v,0, true); 
	end
	-- END
end

function nextRound(nRounds)
	if not Session.IsHost then
		return;
	end
	
	OldnextRound(nRounds);
	-- KEL Clear saves
	for _,v in pairs(CombatManager.getCombatantNodes()) do
		TokenManager3.setSaveOverlay(v,0,true); 
	end
	-- END
end